import json
import re
import unittest

from datadog import build_dashboard, layout


def definitions(widgets):
    for widget in widgets:
        definition = widget["definition"]
        yield definition
        yield from definitions(definition.get("widgets", []))


class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.dashboard = build_dashboard()
        self.definitions = list(definitions(self.dashboard["widgets"]))
        self.queries = [
            query["query"]
            for definition in self.definitions
            for request in definition.get("requests", [])
            for query in request["queries"]
        ]

    def test_sections_use_native_header_colors_and_visible_titles(self):
        groups = [item for item in self.definitions if item["type"] == "group"]
        colors = set()
        for group in groups:
            self.assertTrue(group["show_title"])
            self.assertTrue(group["title"])
            self.assertIn(
                group.get("background_color"),
                {"gray", "purple", "blue", "green", "orange", "pink"},
            )
            colors.add(group["background_color"])
        self.assertGreater(len(colors), 1)

    def test_import_has_no_account_metadata_or_tenant_breakdowns(self):
        self.assertEqual(
            set(self.dashboard),
            {
                "title",
                "description",
                "layout_type",
                "reflow_type",
                "template_variables",
                "widgets",
            },
        )
        serialized = json.dumps(self.dashboard)
        for forbidden in (
            "tenant_id",
            "sandbox_id}",
            "author_handle",
            "notify_list",
            "restricted_roles",
            "custom_links",
            "env:dev",
            "kube_namespace:sandbox",
            "service:platform-backend",
            "langsmith-sandbox-us",
            "langchain-dev",
            "langchain-us",
            "inf-3003-preview",
            "npa-mnm-pr5",
            "TEMP INF",
            "/private/tmp",
        ):
            self.assertNotIn(forbidden, serialized)
        self.assertFalse(any("id" in definition for definition in self.definitions))

    def test_queries_resolve_declared_variables_and_formula_inputs(self):
        declared = {
            variable["name"] for variable in self.dashboard["template_variables"]
        }
        referenced = set()
        for definition in self.definitions:
            for request in definition.get("requests", []):
                names = {query["name"] for query in request["queries"]}
                for query in request["queries"]:
                    self.assertEqual(query["data_source"], "metrics")
                    referenced.update(re.findall(r"\$(\w+)", query["query"]))
                for formula in request["formulas"]:
                    self.assertLessEqual(
                        set(re.findall(r"[a-zA-Z_]\w*", formula["formula"])), names
                    )
        self.assertEqual(referenced, declared)

    def test_host_and_juicefs_queries_are_scoped_to_installation(self):
        host_queries = [
            query
            for query in self.queries
            if ":langsmith_" in query or ":juicefs_" in query
        ]
        self.assertTrue(host_queries)
        for query in host_queries:
            self.assertIn("{$env,$cluster,$namespace", query)
        defaults = {
            variable["name"]: variable["default"]
            for variable in self.dashboard["template_variables"]
        }
        for variable in ("env", "cluster", "namespace"):
            self.assertEqual(defaults[variable], "*")

    def test_apm_uses_service_filter_without_host_only_tags(self):
        queries = [query for query in self.queries if ":trace." in query]
        self.assertTrue(queries)
        for query in queries:
            self.assertIn("$api_service", query)
            self.assertIn("$env", query)
            self.assertNotIn("$cluster", query)
            self.assertNotIn("$namespace", query)

    def test_cloud_storage_requires_explicit_bucket_selection(self):
        defaults = {
            variable["name"]: variable["default"]
            for variable in self.dashboard["template_variables"]
        }
        for provider, variable in (("gcp", "gcs_bucket"), ("aws", "s3_bucket")):
            self.assertNotIn("*", defaults[variable])
            queries = [query for query in self.queries if f":{provider}." in query]
            self.assertTrue(queries)
            for query in queries:
                self.assertIn("{$" + variable + "}", query)
                self.assertNotIn("$env", query)
                self.assertNotIn("$cluster", query)
                self.assertNotIn("$namespace", query)

    def test_public_api_and_internal_reporting_are_separate(self):
        public = []
        internal = []
        for group in self.dashboard["widgets"]:
            definition = group["definition"]
            if definition["type"] != "group":
                continue
            for panel in definition["widgets"]:
                for request in panel["definition"].get("requests", []):
                    for query in request["queries"]:
                        text = query["query"]
                        if ":trace.http.request" not in text:
                            continue
                        if definition["title"].startswith("Runtime reporting"):
                            internal.append(text)
                            self.assertIn(
                                "resource_name:*_/v2/sandboxes/internal/*", text
                            )
                        else:
                            public.append(text)
                            self.assertIn("resource_name:*_/v2/sandboxes/*", text)
                            self.assertIn("!resource_name:*/internal/*", text)
        self.assertTrue(public)
        self.assertTrue(internal)

    def test_non_streaming_latency_excludes_long_lived_connections(self):
        panels = [
            item
            for item in self.definitions
            if item.get("title", "").startswith(
                ("Public HTTP request latency", "Slowest public HTTP endpoints")
            )
        ]
        self.assertEqual(len(panels), 2)
        for panel in panels:
            for request in panel["requests"]:
                for query in request["queries"]:
                    for exclusion in (
                        "!resource_name:*/ws",
                        "!resource_name:*/tunnel*",
                        "!resource_name:*/execute/stream/*",
                        "!resource_name:*/services/*",
                    ):
                        self.assertIn(exclusion, query["query"])

    def test_live_snapshots_and_rankings_use_explicit_reductions(self):
        snapshots = []
        for item in self.definitions:
            for request in item.get("requests", []):
                for query in request["queries"]:
                    text = query["query"]
                    if item["type"] == "toplist":
                        expected = (
                            "percentile"
                            if text.startswith("p95:")
                            else "last"
                            if "_live_sandboxes{" in text
                            else "sum"
                        )
                        self.assertEqual(query["aggregator"], expected)
                    if (
                        "_pool_ready_hosts{" in text
                        or "_pool_desired_replicas{" in text
                    ):
                        self.assertTrue(text.startswith("max:"))
                        self.assertTrue(text.endswith(".fill(null)"))
            if "time" in item:
                snapshots.append(item)
                self.assertEqual(item["time"], {"live_span": "5m"})
                for request in item["requests"]:
                    for query in request["queries"]:
                        self.assertEqual(query["aggregator"], "last")
                        self.assertNotIn("default_zero", query["query"])
        self.assertEqual(
            {item["title"] for item in snapshots},
            {"Live sandboxes", "Ready hosts", "Live sandboxes by host"},
        )

    def test_unknown_stage_errors_have_an_explicit_total(self):
        panel = next(
            item
            for item in self.definitions
            if item.get("title") == "Failures without stage (total)"
        )
        for request in panel["requests"]:
            for query in request["queries"]:
                self.assertEqual(query["aggregator"], "sum")
                self.assertIn(",outcome:error,failed_stage:", query["query"])

    def test_units_and_legends_are_explicit(self):
        for item in self.definitions:
            if item["type"] == "timeseries":
                self.assertEqual(item["legend_layout"], "vertical")
                self.assertEqual(item["legend_columns"], ["value", "avg", "max"])
            for request in item.get("requests", []):
                for formula in request["formulas"]:
                    unit = formula.get("number_format", {}).get("unit", {})
                    if "%" in item.get("title", ""):
                        self.assertEqual(
                            unit, {"type": "canonical_unit", "unit_name": "percent"}
                        )
                    if item.get("title") in ("GCS object count", "S3 object count"):
                        self.assertEqual(unit.get("label"), "objects")
                    if item.get("title") == "Guest CPU cores in use vs committed":
                        self.assertEqual(unit.get("label"), "cores")

    def test_mixed_width_layout_bounds_and_api_order(self):
        self.assertEqual(self.dashboard["reflow_type"], "fixed")
        groups = [
            item
            for item in self.dashboard["widgets"]
            if item["definition"]["type"] == "group"
        ]
        self.assertTrue(groups[0]["definition"]["title"].startswith("Fleet"))
        self.assertTrue(groups[1]["definition"]["title"].startswith("Sandbox API"))
        self.assertTrue(groups[2]["definition"]["title"].startswith("Exec"))
        widths = set()
        for group in groups:
            widgets = group["definition"]["widgets"]
            rows = {}
            for index, widget in enumerate(widgets):
                self.assertNotIn("id", widget)
                a = widget["layout"]
                self.assertGreaterEqual(a["x"], 0)
                self.assertGreaterEqual(a["y"], 0)
                self.assertGreater(a["height"], 0)
                self.assertIn(a["width"], (3, 4, 6, 8, 12))
                self.assertLessEqual(a["x"] + a["width"], 12)
                self.assertLessEqual(
                    a["y"] + a["height"], group["layout"]["height"] - 1
                )
                rows[a["y"]] = rows.get(a["y"], 0) + a["width"]
                if widget["definition"]["type"] != "note":
                    widths.add(a["width"])
                for other in widgets[index + 1 :]:
                    b = other["layout"]
                    overlaps = (
                        a["x"] < b["x"] + b["width"]
                        and b["x"] < a["x"] + a["width"]
                        and a["y"] < b["y"] + b["height"]
                        and b["y"] < a["y"] + a["height"]
                    )
                    self.assertFalse(overlaps)
            self.assertTrue(all(width == 12 for width in rows.values()))
        self.assertTrue({3, 4, 6, 8, 12}.issubset(widths))

    def test_filtered_rows_reflow_without_changing_panels(self):
        panels = [
            {
                "definition": {"type": "timeseries", "title": title},
                "layout": {"x": index * 4, "y": 8, "width": 4, "height": 4},
            }
            for index, title in enumerate(("A", "B", "C"))
        ]
        retained = panels[:2]
        self.assertEqual(layout(retained), 4)
        self.assertEqual(
            [item["layout"] for item in retained],
            [
                {"x": 0, "y": 0, "width": 6, "height": 4},
                {"x": 6, "y": 0, "width": 6, "height": 4},
            ],
        )
        self.assertEqual([item["definition"]["title"] for item in retained], ["A", "B"])

    def test_invalid_row_plans_are_rejected(self):
        for rows in (((6,),), ((0, 12),), ((4, 4, 4),), (("wide",),)):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                layout([{"definition": {"type": "timeseries"}}], rows)


if __name__ == "__main__":
    unittest.main()
