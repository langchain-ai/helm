from copy import deepcopy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
import uuid

from generate_dashboards import (
    build_dashboards,
    datadog_dashboard,
    grafana_dashboard,
    load_source,
    local_path,
    merge_variables,
)


def widgets(items):
    for item in items:
        yield item
        yield from widgets(item["definition"].get("widgets", []))


def without_ids(value):
    if isinstance(value, list):
        return [without_ids(item) for item in value]
    if isinstance(value, dict):
        return {key: without_ids(item) for key, item in value.items() if key != "id"}
    return value


class DashboardTests(unittest.TestCase):
    def test_datadog_preserves_smithdb_widgets_and_filters(self):
        source = load_source("smithdb", "datadog")
        actual = build_dashboards()["datadog-dashboard.json"]
        smithdb_ids = actual["tabs"][0]["widget_ids"]
        smithdb_widgets = [
            item for item in actual["widgets"] if item["id"] in smithdb_ids
        ]
        expected = json.loads(
            json.dumps(source["widgets"]).replace(
                "$cluster", "cluster_name:$cluster.value"
            )
        )
        self.assertEqual(without_ids(smithdb_widgets), without_ids(expected))
        for variable in source["template_variables"]:
            self.assertIn(variable, actual["template_variables"])
        self.assertEqual(actual["tabs"][0]["name"], "SmithDB")
        uuid.UUID(actual["tabs"][0]["id"])
        self.assertEqual(
            actual["tabs"][0]["widget_ids"], [item["id"] for item in smithdb_widgets]
        )
        ids = [item["id"] for item in widgets(actual["widgets"])]
        self.assertEqual(len(ids), len(set(ids)))

    def test_custom_smithdb_prefix_changes_only_metric_names_and_prefix_note(self):
        baseline = build_dashboards()
        self.assertEqual(baseline, build_dashboards("smithdb."))
        source = load_source("smithdb", "datadog")
        for prefix in ("custom_smithdb.", "company.metrics.smithdb.", ""):
            with self.subTest(prefix=prefix):
                actual = build_dashboards(prefix)
                self.assertEqual(
                    actual["grafana-dashboard.json"], baseline["grafana-dashboard.json"]
                )
                normalized = deepcopy(actual["datadog-dashboard.json"])
                changed = 0
                for before, after in zip(
                    widgets(baseline["datadog-dashboard.json"]["widgets"]),
                    widgets(normalized["widgets"]),
                ):
                    old = before["definition"]
                    new = after["definition"]
                    if (
                        old["type"] == "note"
                        and "Metrics are queried under the `smithdb.` prefix."
                        in old.get("content", "")
                    ):
                        self.assertIn(
                            f"`{prefix}`" if prefix else "without a prefix",
                            new["content"],
                        )
                        new["content"] = old["content"]
                    for old_request, new_request in zip(
                        old.get("requests", []), new.get("requests", [])
                    ):
                        for old_query, new_query in zip(
                            old_request.get("queries", []),
                            new_request.get("queries", []),
                        ):
                            if old_query["data_source"] != "metrics":
                                continue
                            head, tail = old_query["query"].split("{", 1)
                            aggregation, metric = head.split(":", 1)
                            if not metric.startswith("smithdb."):
                                continue
                            new_head, new_tail = new_query["query"].split("{", 1)
                            self.assertEqual(
                                new_head,
                                aggregation + ":" + prefix + metric[len("smithdb.") :],
                            )
                            self.assertEqual(new_tail, tail)
                            new_query["query"] = old_query["query"]
                            changed += 1
                self.assertGreater(changed, 0)
                self.assertEqual(normalized, baseline["datadog-dashboard.json"])
        self.assertEqual(load_source("smithdb", "datadog"), source)

    def test_datadog_shares_cluster_without_changing_query_tag_keys(self):
        components = []
        for prefix in ("cluster_name", "kube_cluster_name"):
            components.append(
                (
                    prefix,
                    {
                        "template_variables": [
                            {"name": "cluster", "prefix": prefix, "default": "*"}
                        ],
                        "widgets": [
                            {
                                "definition": {
                                    "type": "note",
                                    "content": "$cluster $cluster.value $cluster_name",
                                }
                            }
                        ],
                    },
                )
            )
        dashboard = datadog_dashboard(components)
        self.assertEqual(len(dashboard["template_variables"]), 1)
        self.assertEqual(
            [item["definition"]["content"] for item in dashboard["widgets"]],
            [
                "cluster_name:$cluster.value $cluster.value $cluster_name",
                "kube_cluster_name:$cluster.value $cluster.value $cluster_name",
            ],
        )
        self.assertEqual(
            components[1][1]["template_variables"][0]["prefix"], "kube_cluster_name"
        )
        components[1][1]["template_variables"][0]["default"] = "different-default"
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            datadog_dashboard(components)

    def test_tab_composition_keeps_existing_component_stable(self):
        source = load_source("smithdb", "datadog")
        single = datadog_dashboard([("SmithDB", source)])
        combined = datadog_dashboard([("SmithDB", source), ("Example", source)])
        self.assertEqual(single["tabs"][0], combined["tabs"][0])
        self.assertEqual(
            single["widgets"], combined["widgets"][: len(single["widgets"])]
        )
        ids = [item["id"] for item in widgets(combined["widgets"])]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(source, load_source("smithdb", "datadog"))

    def test_grafana_preserves_queries_and_visualization_semantics(self):
        source = load_source("smithdb", "grafana")
        actual = build_dashboards()["grafana-dashboard.json"]["spec"]
        old_panels = [panel for panel in source["panels"] if panel["type"] != "row"]
        panels = [
            value
            for key, value in actual["elements"].items()
            if key.startswith("smithdb-")
        ]
        self.assertEqual(len(old_panels), len(panels))
        for old, new in zip(old_panels, panels):
            panel = new["spec"]
            self.assertEqual(panel["title"], old.get("title", ""))
            self.assertEqual(panel["vizConfig"]["group"], old["type"])
            self.assertEqual(
                panel["vizConfig"]["spec"]["options"], old.get("options", {})
            )
            self.assertEqual(
                panel["vizConfig"]["spec"]["fieldConfig"],
                old.get("fieldConfig", {"defaults": {}, "overrides": []}),
            )
            queries = panel["data"]["spec"]["queries"]
            self.assertEqual(len(queries), len(old.get("targets", [])))
            for target, query in zip(old.get("targets", []), queries):
                self.assertEqual(query["spec"]["query"]["spec"]["expr"], target["expr"])
                self.assertEqual(query["spec"]["refId"], target["refId"])
        tab = actual["layout"]["spec"]["tabs"][0]
        self.assertEqual(tab["spec"]["title"], "SmithDB")
        references = [
            item["spec"]["element"]["name"]
            for row in tab["spec"]["layout"]["spec"]["rows"]
            for item in row["spec"]["layout"]["spec"]["items"]
        ]
        self.assertEqual(
            set(references),
            {key for key in actual["elements"] if key.startswith("smithdb-")},
        )
        self.assertEqual(len(references), len(panels))
        for variable, new in zip(source["templating"]["list"], actual["variables"]):
            self.assertEqual(variable["name"], new["spec"]["name"])
            if variable["type"] == "query":
                self.assertEqual(variable["multi"], new["spec"]["multi"])
                self.assertEqual(variable["allValue"], new["spec"]["allValue"])
                self.assertIn(
                    "sys_jemalloc_resident_bytes", new["spec"]["query"]["spec"]["query"]
                )

    def test_generation_is_self_contained_without_legacy_downloads(self):
        with tempfile.TemporaryDirectory(prefix="langsmith-dashboards-") as directory:
            bundle = Path(directory) / "bundle"
            shutil.copytree(
                local_path("components"),
                bundle / "components",
                ignore=shutil.ignore_patterns("__pycache__"),
            )
            script = bundle / "generate_dashboards.py"
            shutil.copyfile(local_path("generate_dashboards.py"), script)
            component = bundle / "components/smithdb/datadog.json"
            original_source = component.read_bytes()
            for prefix in ("custom_smithdb.", "", "smithdb."):
                for check in ([], ["--check"]):
                    result = subprocess.run(
                        [
                            sys.executable,
                            str(script),
                            "--smithdb-metrics-prefix",
                            prefix,
                            *check,
                        ],
                        cwd=directory,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                for name, expected in build_dashboards(prefix).items():
                    self.assertEqual(json.loads((bundle / name).read_text()), expected)
            original_outputs = {
                name: (bundle / name).read_bytes() for name in build_dashboards()
            }
            for prefix in (
                "custom",
                ".custom.",
                "9custom.",
                "custom..metrics.",
                "custom,{env:prod}.",
                "custom\nmetrics.",
                "a" * 101 + ".",
            ):
                result = subprocess.run(
                    [sys.executable, str(script), "--smithdb-metrics-prefix", prefix],
                    cwd=directory,
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("--smithdb-metrics-prefix", result.stderr)
                for name, data in original_outputs.items():
                    self.assertEqual((bundle / name).read_bytes(), data)
            mismatch = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--smithdb-metrics-prefix",
                    "custom_smithdb.",
                    "--check",
                ],
                cwd=directory,
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertNotEqual(mismatch.returncode, 0)
            self.assertEqual(component.read_bytes(), original_source)
            self.assertFalse((Path(directory) / "smithdb-observability").exists())

    def test_exports_are_reproducible_and_account_neutral(self):
        self.assertEqual(build_dashboards(), build_dashboards())
        serialized = json.dumps(build_dashboards())
        for forbidden in (
            "author_handle",
            "resourceVersion",
            "restricted_roles",
            "notify_list",
            "langchain-us",
            "env:dev",
            "npa-mnm-pr5",
            "/private/tmp",
            "inf-3003-preview",
        ):
            self.assertNotIn(forbidden, serialized)
        self.assertEqual(
            build_dashboards()["grafana-dashboard.json"]["metadata"],
            {"name": "langsmith-self-hosted"},
        )

    def test_conflicting_filters_are_rejected(self):
        variables = [{"name": "cluster", "prefix": "cluster_name"}]
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            merge_variables(
                variables, [{"name": "cluster", "prefix": "kube_cluster_name"}]
            )

    def test_unknown_layouts_are_not_silently_lost(self):
        source = load_source("smithdb", "grafana")
        source["panels"][0]["repeat"] = "namespace"
        with self.assertRaisesRegex(ValueError, "Unsupported panel fields"):
            grafana_dashboard([("SmithDB", source)])
        source = deepcopy(source)
        source["panels"][0].pop("repeat")
        source["panels"][1]["panels"] = [{}]
        with self.assertRaisesRegex(ValueError, "Nested Classic"):
            grafana_dashboard([("SmithDB", source)])

    def test_sandbox_filters_do_not_change_smithdb_scope(self):
        actual = build_dashboards()["datadog-dashboard.json"]
        self.assertEqual(
            [tab["name"] for tab in actual["tabs"]], ["SmithDB", "Sandboxes"]
        )
        variables = {
            item["name"]: item["prefix"] for item in actual["template_variables"]
        }
        self.assertEqual(variables["cluster"], "cluster_name")
        self.assertEqual(variables["namespace"], "kube_namespace")
        self.assertNotIn("sandbox_cluster", variables)
        self.assertNotIn("sandbox_namespace", variables)
        self.assertEqual(len(variables), len(actual["template_variables"]))
        ids = actual["tabs"][1]["widget_ids"]
        data = [widget for widget in widgets(actual["widgets"]) if widget["id"] in ids]
        text = json.dumps(data)
        self.assertIn("kube_cluster_name:$cluster.value", text)
        self.assertIn("$namespace", text)
        for widget in widgets(data):
            for request in widget["definition"].get("requests", []):
                for query in request.get("queries", []):
                    if any(
                        metric in query["query"]
                        for metric in ("trace.http.", "gcp.storage.", "aws.s3.")
                    ):
                        self.assertNotIn("$cluster", query["query"])
                        self.assertNotIn("$namespace", query["query"])

    def test_dashboard_downloads_do_not_inflate_helm_release_storage(self):
        chart = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="langsmith-chart-") as directory:
            subprocess.run(
                ["helm", "package", str(chart), "--destination", directory],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30,
            )
            packages = list(Path(directory).glob("*.tgz"))
            self.assertEqual(len(packages), 1)
            with tarfile.open(packages[0], "r:gz") as archive:
                names = archive.getnames()
            self.assertIn("langsmith/Chart.yaml", names)
            self.assertTrue(
                any(name.startswith("langsmith/templates/") for name in names)
            )
            self.assertFalse(
                any(
                    name.startswith("langsmith/examples/smithdb-observability/")
                    for name in names
                )
            )
            self.assertFalse(
                any(
                    name.startswith("langsmith/examples/langsmith-observability/")
                    for name in names
                )
            )

    def test_inputs_and_output_paths_are_bounded(self):
        with self.assertRaises(ValueError):
            load_source("../../outside", "grafana")
        for path in ("../outside.json", "../../../../outside.json"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                local_path(path)


if __name__ == "__main__":
    unittest.main()
