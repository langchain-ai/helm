from copy import deepcopy
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import uuid

from generate_dashboards import (
    artifacts,
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
        self.assertEqual(without_ids(smithdb_widgets), without_ids(source["widgets"]))
        for variable in source["template_variables"]:
            self.assertIn(variable, actual["template_variables"])
        self.assertEqual(actual["tabs"][0]["name"], "SmithDB")
        uuid.UUID(actual["tabs"][0]["id"])
        self.assertEqual(
            actual["tabs"][0]["widget_ids"], [item["id"] for item in smithdb_widgets]
        )
        ids = [item["id"] for item in widgets(actual["widgets"])]
        self.assertEqual(len(ids), len(set(ids)))

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
        panels = list(actual["elements"].values())
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
        self.assertEqual(set(references), set(actual["elements"]))
        self.assertEqual(len(references), len(actual["elements"]))
        for variable, new in zip(source["templating"]["list"], actual["variables"]):
            self.assertEqual(variable["name"], new["spec"]["name"])
            if variable["type"] == "query":
                self.assertEqual(variable["query"], new["spec"]["query"]["spec"])

    def test_legacy_downloads_are_identical_to_component_sources(self):
        outputs = artifacts()
        for backend in ("datadog", "grafana"):
            self.assertEqual(
                outputs[
                    local_path(f"../smithdb-observability/{backend}-dashboard.json")
                ],
                local_path(f"components/smithdb/{backend}.json").read_text(),
            )
        for name in ("datadog-values.yaml", "prometheus-values.yaml"):
            self.assertEqual(
                outputs[local_path("../smithdb-observability/" + name)],
                local_path("components/smithdb/" + name).read_text(),
            )

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
        self.assertEqual(variables["sandbox_cluster"], "kube_cluster_name")
        self.assertEqual(variables["sandbox_namespace"], "kube_namespace")
        ids = actual["tabs"][1]["widget_ids"]
        data = [widget for widget in widgets(actual["widgets"]) if widget["id"] in ids]
        text = json.dumps(data)
        self.assertIn("$sandbox_cluster", text)
        self.assertNotIn("$cluster", text)
        self.assertNotIn("$namespace", text)

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
            self.assertIn(
                "langsmith/examples/smithdb-observability/grafana-dashboard.json", names
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
        with self.assertRaises(ValueError):
            local_path("../../../../outside.json")


if __name__ == "__main__":
    unittest.main()
