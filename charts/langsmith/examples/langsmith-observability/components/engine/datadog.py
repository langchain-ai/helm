from components.sandboxes.datadog import (
    group,
    layout,
    metric,
    note,
    query,
    request,
    scalar,
    series,
)

SCOPE = "$env,$cluster,$namespace"
AGENT = SCOPE + ",$engine_deployment"
SCANS = "langsmith_issues_agent_main_runs_finished.count"
COUNT = ".as_count()"
SECTION_ROWS = {
    "Scans": ((4, 4, 4), (6, 6), (6, 6), (6, 6)),
    "Agent server (shared with Insights)": ((6, 6), (6, 6), (12,)),
    "Pods": ((6, 6), (12,)),
    "Usage recording and upload": ((4, 8), (6, 6), (12,)),
}


def counter(name, scope=SCOPE, by="", alias=None, unit=None):
    return metric(
        query(name, scope=scope, by=by, rollup=COUNT),
        alias=alias,
        unit=unit,
        display="bars",
    )


def section_scans():
    return [
        note(
            "Engine scans as recorded by platform-backend when each scan finishes. Success counts scans that ended with `status:success`, including scans that found nothing to file. Fix, validation and investigation runs are not counted. Skips happen in the ingest-queue worker before a scan is dispatched."
        ),
        scalar(
            "Scan success rate",
            request(
                "100 * ok / total",
                {
                    "ok": query(SCANS, scope=SCOPE + ",status:success", rollup=COUNT),
                    "total": query(SCANS, rollup=COUNT),
                },
                alias="Scan success rate",
                unit="percent",
            ),
        ),
        scalar(
            "Finished scans",
            metric(query(SCANS, rollup=COUNT), alias="Finished scans", unit="scans"),
        ),
        scalar(
            "Unsuccessful scans",
            metric(
                query(SCANS, scope=SCOPE + ",!status:success", rollup=COUNT),
                alias="Unsuccessful scans",
                unit="scans",
            ),
        ),
        series(
            "Finished scans by status",
            counter(SCANS, by="status", unit="scans"),
        ),
        series(
            "Unsuccessful scans by status and failure",
            counter(
                SCANS,
                scope=SCOPE + ",!status:success",
                by="status,failure",
                unit="scans",
            ),
        ),
        series(
            "Scans skipped before dispatch",
            counter(
                "langsmith_issues_agent_no_plan_skipped.count",
                alias="no active plan",
                unit="scans",
            ),
            counter(
                "langsmith_issues_agent_lcu_spend_limit_exceeded.count",
                alias="spend limit reached",
                unit="scans",
            ),
            counter(
                "langsmith_issues_agent_tenant_cap_exceeded.count",
                alias="workspace concurrency cap",
                unit="scans",
            ),
        ),
        series(
            "Oldest run awaiting its completion callback",
            metric(
                query(
                    "langsmith_issues_agent_thread_status_oldest_pending_age_seconds",
                    aggregation="max",
                ),
                alias="Oldest pending run age",
                unit="second",
            ),
        ),
        series(
            "Runs awaiting completion callback",
            metric(
                query(
                    "langsmith_issues_agent_thread_status_pending_rows",
                    aggregation="max",
                ),
                alias="Pending runs",
                unit="runs",
            ),
        ),
        series(
            "Issue filing attempts by outcome",
            counter(
                "langsmith_issues_agent_create_issue_calls.count",
                by="outcome",
                unit="calls",
            ),
        ),
    ]


def section_agent_server():
    return [
        note(
            "The Engine and Insights share one agent server, so these panels include Insights runs when Insights is enabled. Run outcome and latency panels need `EXPOSE_INTERNAL_METRICS_PROMETHEUS=true` in `engineInsightsAgent.queue.deployment.extraEnv`; see the README."
        ),
        series(
            "Queue workers: active vs max",
            metric(
                query("lg_api_workers_active", scope=AGENT),
                alias="active",
                unit="workers",
            ),
            metric(
                query("lg_api_workers_max", scope=AGENT),
                alias="max",
                unit="workers",
            ),
        ),
        series(
            "Runs: pending vs running",
            metric(
                query("lg_api_num_pending_runs", aggregation="max", scope=AGENT),
                alias="pending",
                unit="runs",
            ),
            metric(
                query("lg_api_num_running_runs", aggregation="max", scope=AGENT),
                alias="running",
                unit="runs",
            ),
        ),
        series(
            "Run outcomes",
            counter(
                "lg_api_run_success_counter.count",
                scope=AGENT,
                alias="succeeded",
                unit="runs",
            ),
            counter(
                "lg_api_run_failed_after_retry_counter.count",
                scope=AGENT,
                alias="failed after retries",
                unit="runs",
            ),
        ),
        series(
            "Run execution time",
            metric(
                query("lg_api_run_execution_latency", aggregation="p50", scope=AGENT),
                alias="p50",
                unit="millisecond",
            ),
            metric(
                query("lg_api_run_execution_latency", aggregation="p95", scope=AGENT),
                alias="p95",
                unit="millisecond",
            ),
        ),
        series(
            "Run queue wait (first attempt)",
            metric(
                query(
                    "lg_api_run_queue_wait_time_1st_attempt",
                    aggregation="p50",
                    scope=AGENT,
                ),
                alias="p50",
                unit="millisecond",
            ),
            metric(
                query(
                    "lg_api_run_queue_wait_time_1st_attempt",
                    aggregation="p95",
                    scope=AGENT,
                ),
                alias="p95",
                unit="millisecond",
            ),
        ),
    ]


def section_pods():
    return [
        note(
            "Kubernetes metrics from the Datadog Agent for the Engine api-server and queue deployments, selected by `engine_deployment`."
        ),
        series(
            "CPU usage by deployment",
            request(
                "usage / 1000000000",
                {
                    "usage": query(
                        "kubernetes.cpu.usage.total", scope=AGENT, by="kube_deployment"
                    )
                },
                alias="CPU",
                unit="cores",
            ),
        ),
        series(
            "Memory working set by deployment",
            metric(
                query(
                    "kubernetes.memory.working_set", scope=AGENT, by="kube_deployment"
                ),
                alias="Working set",
                unit="byte",
            ),
            metric(
                query("kubernetes.memory.limits", scope=AGENT, by="kube_deployment"),
                alias="Limit",
                unit="byte",
            ),
        ),
        series(
            "Container restarts of running pods, by deployment",
            metric(
                query(
                    "kubernetes.containers.restarts",
                    scope=AGENT,
                    by="kube_deployment",
                ),
                alias="Restarts",
                unit="restarts",
            ),
        ),
    ]


def section_usage():
    tokens = "langsmith_engine_usage_tokens.count"
    return [
        note(
            "The Engine reports each model call's token usage to platform-backend; the ingest-queue worker aggregates it and uploads it to LangSmith Intelligence. Upload panels stay empty on air-gapped installs, which export usage from Settings > Usage export instead."
        ),
        scalar(
            "Prompt cache hit rate",
            request(
                "100 * cached / (cached + uncached + written)",
                {
                    "cached": query(
                        tokens, scope=SCOPE + ",token_type:cache_read", rollup=COUNT
                    ),
                    "uncached": query(
                        tokens, scope=SCOPE + ",token_type:input", rollup=COUNT
                    ),
                    "written": query(
                        tokens, scope=SCOPE + ",token_type:cache_creation", rollup=COUNT
                    ),
                },
                alias="Cache hit rate",
                unit="percent",
            ),
        ),
        series(
            "Input tokens by type and provider",
            counter(tokens, by="token_type,provider", unit="tokens"),
        ),
        series(
            "Usage reports rejected or not stored",
            counter(
                "langsmith_issues_agent_usage_request_rejections.count",
                by="reason",
                unit="reports",
            ),
            counter(
                "langsmith_issues_agent_usage_bucket_write_errors.count",
                alias="storage write errors",
                unit="reports",
            ),
        ),
        series(
            "Usage aggregation failures",
            counter(
                "langsmith_issues_agent_usage_sweep_failures.count",
                alias="sweep failures",
                unit="failures",
            ),
            counter(
                "langsmith_issues_agent_usage_insert_failures.count",
                alias="insert failures",
                unit="failures",
            ),
        ),
        series(
            "Upload to LangSmith Intelligence",
            counter(
                "langsmith_engine_lsi_usage_rows_sent.count",
                alias="rows sent",
                unit="rows",
            ),
            counter(
                "langsmith_engine_lsi_usage_batches_failed.count",
                alias="batches failed",
                unit="batches",
            ),
            counter(
                "langsmith_engine_lsi_usage_license_rejected.count",
                alias="license rejected",
                unit="uploads",
            ),
        ),
    ]


def build_dashboard():
    widgets = [
        note(
            "Import into your own Datadog organization. Requires the Engine collection values in the accompanying README. Missing data means no samples were collected, not zero."
        ),
        group("Scans", section_scans(), "blue"),
        group("Agent server (shared with Insights)", section_agent_server(), "purple"),
        group("Pods", section_pods(), "gray"),
        group("Usage recording and upload", section_usage(), "green"),
    ]
    y = 0
    for widget in widgets:
        definition = widget["definition"]
        height = (
            layout(definition["widgets"], SECTION_ROWS[definition["title"]]) + 1
            if definition["type"] == "group"
            else 2
        )
        widget["layout"] = {"x": 0, "y": y, "width": 12, "height": height}
        y += height
    return {
        "title": "Self-hosted Engine Vitals",
        "description": "Engine scan outcomes, agent server capacity, pod resources and usage reporting. Import into your own Datadog organization.",
        "layout_type": "ordered",
        "reflow_type": "fixed",
        "template_variables": [
            {"name": name, "prefix": prefix, "available_values": [], "default": default}
            for name, prefix, default in (
                ("env", "env", "*"),
                ("cluster", "kube_cluster_name", "*"),
                ("namespace", "kube_namespace", "*"),
                ("engine_deployment", "kube_deployment", "*standalone-insights*"),
            )
        ],
        "widgets": widgets,
    }
