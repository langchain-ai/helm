import unittest

from generate_dashboards import build_dashboards

from components.sandboxes.datadog import build_dashboard as datadog_source
from components.sandboxes.grafana import (
    build_dashboard,
    formula,
    prom_query,
    prometheus_name,
    supported,
)


class GrafanaSandboxTests(unittest.TestCase):
    def test_every_host_and_juicefs_panel_is_retained(self):
        expected = [
            panel["definition"]["title"]
            for group in datadog_source()["widgets"]
            for panel in group["definition"].get("widgets", [])
            if supported(panel["definition"])
        ]
        panels = [
            panel
            for panel in build_dashboard()["panels"]
            if panel["type"] not in ("row", "text")
        ]
        self.assertEqual([panel["title"] for panel in panels], expected)
        self.assertGreater(len(panels), 70)
        for panel in panels:
            self.assertIn(panel["gridPos"]["w"], (6, 8, 12, 16, 24))
            self.assertLessEqual(panel["gridPos"]["x"] + panel["gridPos"]["w"], 24)
            for target in panel["targets"]:
                self.assertIn('namespace=~"${namespace:regex}"', target["expr"])
                self.assertIn('cluster=~"${sandbox_cluster:regex}"', target["expr"])
                self.assertNotIn("trace.http", target["expr"])
                self.assertNotIn("tenant_id", target["expr"])

    def test_mixed_width_rows_fill_the_grid_without_overlaps(self):
        panels = build_dashboard()["panels"]
        widths = set()
        rows = {}
        for index, panel in enumerate(panels):
            a = panel["gridPos"]
            self.assertGreaterEqual(a["x"], 0)
            self.assertGreaterEqual(a["y"], 0)
            self.assertGreater(a["h"], 0)
            rows[a["y"]] = rows.get(a["y"], 0) + a["w"]
            if panel["type"] not in ("row", "text"):
                widths.add(a["w"])
            for other in panels[index + 1 :]:
                b = other["gridPos"]
                self.assertFalse(
                    a["x"] < b["x"] + b["w"]
                    and b["x"] < a["x"] + a["w"]
                    and a["y"] < b["y"] + b["h"]
                    and b["y"] < a["y"] + a["h"]
                )
        self.assertTrue(all(width == 24 for width in rows.values()))
        self.assertTrue({8, 12, 16, 24}.issubset(widths))

    def test_raw_metric_names_distinguish_counters_from_histograms(self):
        cases = {
            "langsmith_sandbox_host_operations.count": "langsmith_sandbox_host_operations_total",
            "langsmith_sandbox_host_operation_duration_seconds.count": "langsmith_sandbox_host_operation_duration_seconds_count",
            "langsmith_sandbox_host_free_page_hint_reclaimed_bytes.sum": "langsmith_sandbox_host_free_page_hint_reclaimed_bytes_sum",
            "juicefs_meta_ops.count": "juicefs_meta_ops_total",
            "juicefs_meta_ops_duration_seconds.count": "juicefs_meta_ops_duration_seconds",
            "juicefs_blockcache_hits.count": "juicefs_blockcache_hits",
            "juicefs_transaction_restart.count": "juicefs_transaction_restart",
        }
        for source, expected in cases.items():
            with self.subTest(metric=source):
                self.assertEqual(prometheus_name(source), expected)

    def test_counters_handle_resets_before_aggregation(self):
        query, _ = prom_query(
            "sum:langsmith_sandbox_host_operations.count{$env,$cluster,$namespace}.as_count()",
            totals=True,
        )
        self.assertTrue(query.startswith("sum(increase("))
        self.assertIn("[$__range]", query)
        rate, _ = prom_query(
            "sum:langsmith_sandbox_host_operations.count{$env,$cluster,$namespace} by {outcome}.as_rate()"
        )
        self.assertTrue(rate.startswith("sum by (outcome)(rate("))

    def test_snapshots_reject_old_series_without_zero_filling(self):
        query, _ = prom_query(
            "avg:langsmith_sandbox_host_live_sandboxes{$env,$cluster,$namespace} by {host}.fill(last,60)",
            snapshot=True,
        )
        self.assertIn("by (instance)(last_over_time(", query)
        self.assertIn("[60s]", query)
        self.assertNotIn("or vector(0)", query)

    def test_empty_failure_stage_is_not_dropped(self):
        query, _ = prom_query(
            "sum:langsmith_sandbox_host_operations.count{$env,$cluster,$namespace,outcome:error,failed_stage:}.as_count()",
            totals=True,
        )
        self.assertIn('failed_stage=""', query)
        self.assertIn('outcome="error"', query)

    def test_only_arithmetic_formulas_are_accepted(self):
        self.assertEqual(
            formula("100 * a / b", {"a": "sum(a)", "b": "sum(b)"}),
            "((100 * (sum(a))) / (sum(b)))",
        )
        for expression in ("f(a)", "a.attr", "a[0]", "unknown", "[a]", "a ** 2"):
            with self.subTest(expression=expression), self.assertRaises(ValueError):
                formula(expression, {"a": "safe"})
        with self.assertRaises(ValueError):
            prom_query("sum:trace.http.request.hits{*}.as_count()")

    def test_shared_context_and_advanced_jobs(self):
        spec = build_dashboards()["grafana-dashboard.json"]["spec"]
        variables = {item["spec"]["name"]: item["spec"] for item in spec["variables"]}
        self.assertEqual(
            [
                name
                for name, variable in variables.items()
                if variable["hide"] != "hideVariable"
            ],
            ["datasource", "namespace", "sandbox_cluster"],
        )
        self.assertTrue(variables["namespace"]["multi"])
        self.assertIn(
            "langsmith_sandbox_host_live_sandboxes",
            variables["namespace"]["query"]["spec"]["query"],
        )
        self.assertIn(
            "sys_jemalloc_resident_bytes",
            variables["namespace"]["query"]["spec"]["query"],
        )
        for name in ("sandbox_job", "juicefs_job"):
            self.assertEqual(variables[name]["hide"], "hideVariable")
        for element in spec["elements"].values():
            for query in element["spec"]["data"]["spec"]["queries"]:
                self.assertEqual(
                    query["spec"]["query"]["datasource"]["name"], "${datasource}"
                )
                expression = query["spec"]["query"]["spec"]["expr"]
                self.assertNotIn("sandbox_namespace", expression)
                self.assertIn("namespace", expression)

    def test_all_filters_use_a_real_all_value(self):
        for variable in build_dashboard()["templating"]["list"]:
            if variable["type"] == "query":
                self.assertTrue(variable["includeAll"])
                self.assertEqual(variable["allValue"], ".*")
                self.assertEqual(variable["current"]["value"], "$__all")


if __name__ == "__main__":
    unittest.main()
