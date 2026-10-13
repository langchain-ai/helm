import json

from components.sandboxes.grafana import build_dashboard, prom_query


def concrete(query, namespace="unit"):
    values = {
        "sandbox_cluster": "unit",
        "namespace": namespace,
        "sandbox_job": "langsmith-sandbox-host",
        "juicefs_job": "langsmith-sandbox-juicefs",
    }
    for name, value in values.items():
        query = query.replace("${" + name + ":regex}", value)
    return query.replace("$__rate_interval", "1m").replace("$__range", "5m")


def cases():
    queries = {
        concrete(target["expr"])
        for panel in build_dashboard()["panels"]
        for target in panel.get("targets", [])
    }
    empty = {
        "name": "All generated queries parse and missing metrics remain unknown",
        "interval": "1m",
        "promql_expr_test": [
            {"expr": expr, "eval_time": "5m", "exp_samples": []}
            for expr in sorted(queries)
        ],
    }
    scope = '{cluster="unit",namespace="unit",job="langsmith-sandbox-host"'
    total, _ = prom_query(
        "sum:langsmith_sandbox_host_operations.count{$env,$cluster,$namespace}.as_count()",
        totals=True,
    )
    unstaged, _ = prom_query(
        "sum:langsmith_sandbox_host_operations.count{$env,$cluster,$namespace,outcome:error,failed_stage:}.as_count()",
        totals=True,
    )
    live, _ = prom_query(
        "sum:langsmith_sandbox_host_live_sandboxes{$env,$cluster,$namespace}.fill(last,60)",
        snapshot=True,
    )
    ready, _ = prom_query(
        "max:langsmith_sandbox_host_pool_ready_hosts{$env,$cluster,$namespace}.fill(null)",
        snapshot=True,
    )
    behavior = {
        "name": "Counter resets, absent stages, stale hosts and leader handoffs",
        "interval": "1m",
        "input_series": [
            {
                "series": "langsmith_sandbox_host_operations_total"
                + scope
                + ',instance="a",outcome="error",failed_stage=""}',
                "values": "0 1 2 3 4 5",
            },
            {
                "series": "langsmith_sandbox_host_operations_total"
                + scope
                + ',instance="b",outcome="error"}',
                "values": "0 1 2 0 1 2",
            },
            {
                "series": "langsmith_sandbox_host_operations_total"
                + scope
                + ',instance="c",outcome="ok",failed_stage=""}',
                "values": "0 1 2 3 4 5",
            },
            {
                "series": "langsmith_sandbox_host_live_sandboxes"
                + scope
                + ',instance="gone"}',
                "values": "9 _ _",
            },
            {
                "series": "langsmith_sandbox_host_live_sandboxes"
                + scope
                + ',instance="fresh"}',
                "values": "2 2 2",
            },
            {
                "series": "langsmith_sandbox_host_pool_ready_hosts"
                + scope
                + ',instance="old-leader"}',
                "values": "3 _ _",
            },
            {
                "series": "langsmith_sandbox_host_pool_ready_hosts"
                + scope
                + ',instance="new-leader"}',
                "values": "_ 2 2",
            },
        ],
        "promql_expr_test": [
            {
                "expr": concrete(total),
                "eval_time": "5m",
                "exp_samples": [{"labels": "{}", "value": 13.75}],
            },
            {
                "expr": concrete(unstaged),
                "eval_time": "5m",
                "exp_samples": [{"labels": "{}", "value": 8.75}],
            },
            {
                "expr": concrete(live),
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 2}],
            },
            {
                "expr": concrete(ready),
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 2}],
            },
        ],
    }
    shared = {
        "name": "Shared namespaces include both components without dropping Sandbox cluster scope",
        "interval": "1m",
        "input_series": [
            {
                "series": "langsmith_sandbox_host_live_sandboxes"
                + scope
                + ',instance="selected"}',
                "values": "8 8 8",
            },
            {
                "series": 'langsmith_sandbox_host_live_sandboxes{cluster="other",namespace="unit",job="langsmith-sandbox-host"}',
                "values": "80 80 80",
            },
            {
                "series": 'ingest_pending_segment_entry_count{namespace="unit"}',
                "values": "12 12 12",
            },
            {
                "series": 'ingest_pending_segment_entry_count{namespace="smithdb"}',
                "values": "42 42 42",
            },
            {
                "series": 'ingest_pending_segment_entry_count{namespace="unselected"}',
                "values": "999 999 999",
            },
        ],
        "promql_expr_test": [
            {
                "expr": concrete(live),
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 8}],
            },
            {
                "expr": concrete(live, "unit|smithdb"),
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 8}],
            },
            {"expr": concrete(live, "missing"), "eval_time": "2m", "exp_samples": []},
            {
                "expr": 'sum(ingest_pending_segment_entry_count{namespace=~"unit"})',
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 12}],
            },
            {
                "expr": 'sum(ingest_pending_segment_entry_count{namespace=~"unit|smithdb"})',
                "eval_time": "2m",
                "exp_samples": [{"labels": "{}", "value": 54}],
            },
        ],
    }
    return {
        "rule_files": [],
        "evaluation_interval": "1m",
        "tests": [empty, behavior, shared],
    }


if __name__ == "__main__":
    print(json.dumps(cases(), indent=2))
