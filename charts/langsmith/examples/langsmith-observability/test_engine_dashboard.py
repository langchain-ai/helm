import json
import re
import unittest

from generate_dashboards import build_dashboards, local_path


def widgets(items):
    for item in items:
        yield item
        yield from widgets(item["definition"].get("widgets", []))


def checks(path):
    """Map each Autodiscovery container to its OpenMetrics instances."""
    lines = local_path(path).read_text().splitlines()
    found = {}
    for index, line in enumerate(lines):
        match = re.fullmatch(r"\s*ad\.datadoghq\.com/([\w-]+)\.checks: \|", line)
        if not match:
            continue
        body = lines[index + 1 :]
        indent = len(body[0]) - len(body[0].lstrip())
        block = []
        for item in body:
            if item.strip() and len(item) - len(item.lstrip()) < indent:
                break
            block.append(item)
        found[match[1]] = json.loads("\n".join(block))["openmetrics"]["instances"]
    return found


def collected(name, instances):
    base = name.removesuffix(".count")
    return any(
        re.fullmatch(pattern, base)
        for instance in instances
        for pattern in instance["metrics"]
    )


class EngineDashboardTests(unittest.TestCase):
    def setUp(self):
        dashboard = build_dashboards()["datadog-dashboard.json"]
        tab = next(tab for tab in dashboard["tabs"] if tab["name"] == "Engine")
        self.widgets = [
            widget
            for widget in widgets(dashboard["widgets"])
            if widget["id"] in tab["widget_ids"]
        ]
        self.widgets = list(widgets(self.widgets))
        self.queries = [
            query["query"]
            for widget in self.widgets
            for request in widget["definition"].get("requests", [])
            for query in request["queries"]
        ]
        self.variables = {
            item["name"]: item["prefix"] for item in dashboard["template_variables"]
        }

    def test_every_queried_metric_is_collected_by_the_engine_values(self):
        engine = checks("components/engine/datadog-values.yaml")
        instances = [item for values in engine.values() for item in values]
        self.assertTrue(self.queries)
        for query in self.queries:
            name = re.match(r"[\w.]+:([\w.]+)\{", query)[1]
            if name.startswith("kubernetes."):
                continue
            with self.subTest(metric=name):
                self.assertTrue(collected(name, instances))

    def test_engine_values_keep_smithdb_metrics_on_shared_checks(self):
        smithdb = checks("components/smithdb/datadog-values.yaml")
        engine = checks("components/engine/datadog-values.yaml")
        for container in ("platform-backend", "ingest-queue"):
            with self.subTest(container=container):
                before, after = smithdb[container][0], engine[container][0]
                self.assertEqual(
                    before["openmetrics_endpoint"], after["openmetrics_endpoint"]
                )
                self.assertLessEqual(set(before["metrics"]), set(after["metrics"]))
                for key, value in before.items():
                    if key != "metrics":
                        self.assertEqual(after.get(key), value)

    def test_queries_use_shared_filters(self):
        self.assertEqual(self.variables["cluster"], "cluster_name")
        self.assertEqual(self.variables["namespace"], "kube_namespace")
        self.assertEqual(self.variables["engine_deployment"], "kube_deployment")
        for query in self.queries:
            with self.subTest(query=query):
                self.assertIn("kube_cluster_name:$cluster.value", query)
                self.assertIn("$namespace", query)
                self.assertNotIn("tenant_id", query)
            if query.split(":", 1)[1].startswith(("lg_api_", "kubernetes.")):
                self.assertIn("$engine_deployment", query)


if __name__ == "__main__":
    unittest.main()
