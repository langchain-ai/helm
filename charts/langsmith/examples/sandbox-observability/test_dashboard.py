import json
import re
import unittest

from generate_dashboard import build_dashboard


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


if __name__ == "__main__":
    unittest.main()
