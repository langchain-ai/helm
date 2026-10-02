import argparse
import json
from pathlib import Path


SCOPE = "$env,$cluster,$namespace"
HOST = "langsmith_sandbox_host"
POOL = "langsmith_sandbox_host_pool"
EGRESS = "langsmith_sandbox_egress_proxy"
DNS = "langsmith_sandbox_egress_dns"
API = "$env,$api_service"
ROUTES = API + ",resource_name:*sandboxes*"
CREATE = API + ",resource_name:post_/v2/sandboxes/boxes"


def query(name, aggregation="sum", scope=SCOPE, by="", rollup=""):
    return f"{aggregation}:{name}{{{scope}}}" + (f" by {{{by}}}" if by else "") + rollup


def request(expression, queries, alias=None):
    formula = {"formula": expression}
    if alias:
        formula["alias"] = alias
    return {
        "formulas": [formula],
        "queries": [
            {"data_source": "metrics", "name": name, "query": value}
            for name, value in queries.items()
        ],
        "response_format": "timeseries",
        "display_type": "line",
    }


def metric(value, alias=None):
    return request("q", {"q": value}, alias)


def mean(name, scope=SCOPE, by="", milliseconds=True):
    return request(
        "1000 * total / samples" if milliseconds else "total / samples",
        {
            "total": query(name + ".sum", scope=scope, by=by, rollup=".as_count()"),
            "samples": query(name + ".count", scope=scope, by=by, rollup=".as_count()"),
        },
    )


def series(title, *requests):
    return {
        "definition": {
            "type": "timeseries",
            "title": title,
            "requests": list(requests),
            "show_legend": True,
            "legend_layout": "auto",
        }
    }


def rate(title, name, by="", scope=SCOPE):
    return series(
        title, metric(query(name + ".count", scope=scope, by=by, rollup=".as_rate()"))
    )


def gauge(title, name, aggregation="sum", by=""):
    return series(title, metric(query(name, aggregation=aggregation, by=by)))


def note(content):
    return {
        "definition": {
            "type": "note",
            "content": content,
            "background_color": "transparent",
            "font_size": "14",
            "text_align": "left",
            "has_padding": True,
        }
    }


def group(title, widgets):
    return {
        "definition": {
            "type": "group",
            "title": title,
            "layout_type": "ordered",
            "widgets": widgets,
        }
    }


def build_dashboard():
    fleet = [
        note(
            "Pool gauges are emitted by the elected host leader. Ready-host and CPU-capacity observations remain available with autoscaling disabled; the desired-replica target is updated only when scaling is active. Commitment is assigned capacity, not measured utilization."
        ),
        gauge(
            "Live sandboxes by cluster",
            HOST + "_live_sandboxes",
            by="kube_cluster_name",
        ),
        series(
            "Host pool: ready vs desired replicas",
            metric(query(POOL + "_ready_hosts"), "ready"),
            metric(query(POOL + "_desired_replicas"), "desired"),
        ),
        series(
            "Pool CPU commitment (%)",
            request(
                "100 * assigned / capacity",
                {
                    "assigned": query(
                        POOL + "_assigned_cpu_millicores", by="kube_cluster_name"
                    ),
                    "capacity": query(
                        POOL + "_capacity_cpu_millicores", by="kube_cluster_name"
                    ),
                },
            ),
        ),
        series(
            "Host memory commitment (%)",
            request(
                "100 * assigned / capacity",
                {
                    "assigned": query(
                        HOST + "_assigned_memory_mib", by="kube_cluster_name"
                    ),
                    "capacity": query(
                        HOST + "_capacity_memory_mib", by="kube_cluster_name"
                    ),
                },
            ),
        ),
        gauge(
            "Live sandboxes by host",
            HOST + "_live_sandboxes",
            aggregation="avg",
            by="host",
        ),
        gauge("Hosts per build", HOST + "_build_info", by="version"),
    ]
    lifecycle = [
        rate("Operations/s by operation", HOST + "_operations", by="operation"),
        rate("Operations/s by outcome", HOST + "_operations", by="outcome"),
        series(
            "Operation error rate (%)",
            request(
                "100 * errors / total",
                {
                    "errors": query(
                        HOST + "_operations.count",
                        scope=SCOPE + ",outcome:error",
                        by="operation",
                        rollup=".as_count()",
                    ),
                    "total": query(
                        HOST + "_operations.count", by="operation", rollup=".as_count()"
                    ),
                },
            ),
        ),
        rate(
            "Failures by stage and operation",
            HOST + "_operations",
            by="failed_stage,operation",
            scope=SCOPE + ",!failed_stage:",
        ),
        rate(
            "Reference lock contention/s", HOST + "_ref_lock_contention", by="operation"
        ),
        series(
            "Reference lock wait (mean ms)",
            mean(HOST + "_ref_lock_wait_seconds", by="operation"),
        ),
    ]
    for operation in (
        "create",
        "start",
        "stop_suspend",
        "stop_discard",
        "delete",
        "snapshot",
        "export",
        "build",
        "reboot",
    ):
        lifecycle.append(
            series(
                f"{operation}: mean duration (ms)",
                mean(
                    HOST + "_operation_duration_seconds",
                    SCOPE + f",operation:{operation}",
                    "outcome",
                ),
            )
        )
    for operation in ("create", "start"):
        lifecycle.append(
            series(
                f"{operation}: stage duration (mean ms)",
                mean(
                    HOST + "_stage_duration_seconds",
                    SCOPE + f",operation:{operation}",
                    "stage",
                ),
            )
        )
    boot = [
        rate("Boots/s by memory source", HOST + "_boot_mode", by="mode"),
        series(
            "Warm-image hit rate (%)",
            request(
                "100 * warm / boots",
                {
                    "warm": query(
                        HOST + "_boot_mode.count",
                        scope=SCOPE + ",mode:zygote",
                        rollup=".as_count()",
                    ),
                    "boots": query(HOST + "_boot_mode.count", rollup=".as_count()"),
                },
            ),
        ),
        rate(
            "Warm-image captures/s by outcome", HOST + "_zygote_capture", by="outcome"
        ),
        series(
            "Warm-image capture duration (mean ms)",
            mean(HOST + "_zygote_capture_duration_seconds"),
        ),
        series(
            "Startup provisioning (mean ms)",
            mean(
                HOST + "_startup_provision_duration_seconds",
                SCOPE + ",outcome:ok",
                "step",
            ),
        ),
        rate(
            "Startup provisioning errors/s",
            HOST + "_startup_provision_duration_seconds",
            by="step",
            scope=SCOPE + ",outcome:error",
        ),
        series(
            "Clone slot wait (mean ms)",
            mean(HOST + "_clone_slot_wait_seconds", by="clone_type"),
        ),
        series(
            "Host boot to ready (mean ms)",
            mean(HOST + "_boot_to_ready_seconds", by="kube_cluster_name"),
        ),
    ]
    guest = [
        rate("Guest proxy requests/s", HOST + "_guest_requests", by="status"),
        series(
            "Guest request duration (mean ms)",
            mean(HOST + "_guest_request_duration_seconds", by="route"),
        ),
        gauge(
            "Guest requests in flight",
            HOST + "_guest_requests_in_flight",
            by="kube_cluster_name",
        ),
        rate("Guest request rejects/s", HOST + "_guest_request_rejects", by="reason"),
        rate("No-target requests/s", HOST + "_guest_no_target", by="route"),
        rate("Inter-host forwards/s", HOST + "_forward"),
        rate("Inter-host forward failures/s", HOST + "_forward_failures", by="reason"),
        rate("Idle stops/s", HOST + "_idle_stops"),
        rate("Firecracker exits/s", HOST + "_vm_exits", by="reason"),
        series(
            "VM lifetime (mean s)",
            mean(HOST + "_vm_lifetime_seconds", by="outcome", milliseconds=False),
        ),
    ]
    resources = [
        series(
            "Guest CPU cores in use vs committed",
            metric(
                query(HOST + "_sandbox_cpu_seconds.count", rollup=".as_rate()"),
                "in use",
            ),
            request(
                "assigned / 1000",
                {"assigned": query(HOST + "_assigned_cpu_millicores")},
                "committed",
            ),
        ),
        series(
            "CPU throttled vs pressure-stalled (seconds/s)",
            metric(
                query(
                    HOST + "_sandbox_cpu_throttled_seconds.count", rollup=".as_rate()"
                ),
                "throttled",
            ),
            metric(
                query(HOST + "_sandbox_cpu_stall_seconds.count", rollup=".as_rate()"),
                "pressure stall",
            ),
        ),
        series(
            "Guest memory (bytes)",
            metric(query(HOST + "_sandbox_memory_rss_bytes"), "resident"),
            metric(query(HOST + "_sandbox_memory_returned_bytes"), "returned to host"),
        ),
        series(
            "Free-page-hint reclaim (bytes/s)",
            metric(
                query(HOST + "_free_page_hint_reclaimed_bytes.sum", rollup=".as_rate()")
            ),
        ),
        series(
            "Guest network throughput (bytes/s)",
            metric(
                query(
                    HOST + "_sandbox_network_receive_bytes.count", rollup=".as_rate()"
                ),
                "receive",
            ),
            metric(
                query(
                    HOST + "_sandbox_network_transmit_bytes.count", rollup=".as_rate()"
                ),
                "transmit",
            ),
        ),
        rate(
            "Dropped packets/s",
            HOST + "_sandbox_network_dropped_packets",
            by="direction",
        ),
    ]
    egress = [
        rate("Egress requests/s", EGRESS + "_requests", by="path"),
        rate("Blocked egress/s", EGRESS + "_blocked", by="reason"),
        series(
            "Egress fault rate (%, excluding allowlist denials)",
            request(
                "100 * faults / total",
                {
                    "faults": query(
                        EGRESS + "_blocked.count",
                        scope=SCOPE + ",!reason:access_denied",
                        rollup=".as_count()",
                    ),
                    "total": query(EGRESS + "_requests.count", rollup=".as_count()"),
                },
            ),
        ),
        rate("Egress upstream failures/s", EGRESS + "_upstream_failures", by="reason"),
        rate("Egress throughput (bytes/s)", EGRESS + "_bytes", by="path,direction"),
        series(
            "Inspected upstream time to headers (mean ms)",
            mean(EGRESS + "_mitm_upstream_duration_seconds"),
        ),
        rate("DNS queries/s", DNS + "_queries", by="rcode"),
    ]
    health = [
        note(
            "An empty failure series can mean no events, an unsupported metric, or missing collection. Check live-sandbox and mount-ready gauges before interpreting missing data. Failures immediately before process exit may not be scraped."
        ),
        gauge(
            "Lease staleness (s), maximum across hosts",
            HOST + "_lease_stale_seconds",
            aggregation="max",
            by="kube_cluster_name",
        ),
        gauge(
            "JuiceFS mount ready (1 = ready)",
            HOST + "_juicefs_mount_ready",
            aggregation="min",
            by="kube_cluster_name",
        ),
        rate("Leader transitions/s", HOST + "_leader_transitions", by="event"),
    ]
    for name in (
        "lease_renew_failures",
        "boot_failure_memory_invalidation",
        "zygote_unusable_fallback",
        "clone_slot_abandoned",
        "guestd_recycle",
        "forward_failures",
        "sandbox_memory_sample_failures",
        "sandbox_network_sample_failures",
        "guest_log_dropped_entries",
    ):
        health.append(
            series(
                name.replace("_", " ") + " (count)",
                metric(query(HOST + "_" + name + ".count", rollup=".as_count()")),
            )
        )
    api = [
        note(
            "Optional: requires Datadog APM trace.http.request metrics for your API service. Select exactly one api_service to avoid double counting. Only env and api_service filter this group; host cluster and namespace filters do not apply. OTLP span names can produce different metric/resource names; adapt queries to the names in your account."
        ),
        series(
            "API requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=ROUTES,
                    by="http.status_code",
                    rollup=".as_count()",
                )
            ),
        ),
        series(
            "API 5xx by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=ROUTES + ",http.status_code:5*",
                    by="resource_name",
                    rollup=".as_count()",
                )
            ),
        ),
        series(
            "API 4xx by endpoint (excluding 404 and client disconnects)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=ROUTES
                    + ",http.status_code:4*,!http.status_code:404,!http.status_code:499",
                    by="resource_name",
                    rollup=".as_count()",
                )
            ),
        ),
        series(
            "Create sandbox requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=CREATE,
                    by="http.status_code",
                    rollup=".as_count()",
                )
            ),
        ),
        series(
            "API request latency (ms)",
            *[
                request(
                    "1000 * q",
                    {
                        "q": query(
                            "trace.http.request", aggregation=percentile, scope=ROUTES
                        )
                    },
                    percentile,
                )
                for percentile in ("p50", "p95", "p99")
            ],
        ),
    ]
    execution = [
        note(
            "Host command metrics use the host scrape and host filters. API execution metrics are optional APM data and use only env and api_service. WebSocket duration measures connection lifetime, not command latency."
        ),
        rate("Commands/s by class", HOST + "_exec_commands", by="command_class"),
        rate("Commands/s by transport", HOST + "_exec_commands", by="transport"),
        series(
            "Command runtime (mean ms)",
            mean(HOST + "_exec_command_duration_seconds", by="command_class"),
        ),
        series(
            "API exec requests by transport",
            *[
                metric(
                    query(
                        "trace.http.request.hits",
                        scope=API + ",resource_name:" + resource,
                        rollup=".as_count()",
                    ),
                    transport,
                )
                for transport, resource in (
                    ("http", "post_/v2/sandboxes/_sandbox_id_/execute"),
                    ("websocket", "get_/v2/sandboxes/_sandbox_id_/execute/ws"),
                )
            ],
        ),
        series(
            "API exec HTTP latency (ms)",
            *[
                request(
                    "1000 * q",
                    {
                        "q": query(
                            "trace.http.request",
                            aggregation=percentile,
                            scope=API
                            + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                        )
                    },
                    percentile,
                )
                for percentile in ("p50", "p95", "p99")
            ],
        ),
        series(
            "API exec WebSocket lifetime (s)",
            metric(
                query(
                    "trace.http.request",
                    aggregation="p95",
                    scope=API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/execute/ws",
                )
            ),
        ),
    ]
    juicefs = [
        note(
            "Optional: scrape the JuiceFS mount's own /metrics endpoint in addition to sandbox-host. The host /metrics endpoint does not export juicefs_* metrics. Used space is logical/apparent size, not physical object storage consumption; copy-on-write files and sparse images make these different."
        ),
        gauge(
            "JuiceFS logical used space (bytes)",
            "juicefs_used_space",
            aggregation="avg",
            by="kube_cluster_name",
        ),
        gauge(
            "JuiceFS inodes used",
            "juicefs_used_inodes",
            aggregation="avg",
            by="kube_cluster_name",
        ),
        rate("Metadata operations/s", "juicefs_meta_ops", by="method"),
        series(
            "Metadata operation latency (mean ms)",
            mean(
                "juicefs_meta_ops_durations_histogram_seconds", by="kube_cluster_name"
            ),
        ),
        series(
            "Metadata operation latency by method (mean ms)",
            request(
                "1000 * seconds / ops",
                {
                    "seconds": query(
                        "juicefs_meta_ops_duration_seconds.count",
                        by="method",
                        rollup=".as_count()",
                    ),
                    "ops": query(
                        "juicefs_meta_ops.count", by="method", rollup=".as_count()"
                    ),
                },
            ),
        ),
        series(
            "Redis transaction latency (mean ms)",
            mean(
                "juicefs_transaction_durations_histogram_seconds",
                by="kube_cluster_name",
            ),
        ),
        rate(
            "Redis transaction restarts/s", "juicefs_transaction_restart", by="method"
        ),
        rate("Object store request errors/s", "juicefs_object_request_errors"),
        series(
            "Object store latency (mean ms)",
            mean(
                "juicefs_object_request_durations_histogram_seconds",
                by="kube_cluster_name",
            ),
        ),
        gauge(
            "Staging backlog (bytes)", "juicefs_staging_block_bytes", aggregation="avg"
        ),
        series(
            "Block cache hit rate (%)",
            request(
                "100 * hits / (hits + misses)",
                {
                    "hits": query(
                        "juicefs_blockcache_hits.count", rollup=".as_count()"
                    ),
                    "misses": query(
                        "juicefs_blockcache_miss.count", rollup=".as_count()"
                    ),
                },
            ),
        ),
    ]
    storage = [
        note(
            "Optional: requires the Datadog AWS or GCP storage integration. Replace gcs_bucket or s3_bucket with the exact bucket name. These queries ignore env, cluster, and namespace because cloud metrics need not carry Kubernetes tags. The placeholder defaults intentionally select no bucket. Remove unused provider widgets; Azure Blob Storage is not covered by these queries."
        ),
        series(
            "GCS stored bytes",
            metric(
                query(
                    "gcp.storage.storage.total_bytes",
                    aggregation="avg",
                    scope="$gcs_bucket",
                    by="bucket_name",
                )
            ),
        ),
        series(
            "GCS object count",
            metric(
                query(
                    "gcp.storage.storage.object_count",
                    aggregation="avg",
                    scope="$gcs_bucket",
                    by="bucket_name",
                )
            ),
        ),
        series(
            "S3 stored bytes",
            metric(
                query(
                    "aws.s3.bucket_size_bytes",
                    aggregation="avg",
                    scope="$s3_bucket",
                    by="bucketname",
                )
            ),
        ),
        series(
            "S3 object count",
            metric(
                query(
                    "aws.s3.number_of_objects",
                    aggregation="avg",
                    scope="$s3_bucket",
                    by="bucketname",
                )
            ),
        ),
    ]
    return {
        "title": "Self-hosted Sandbox Vitals",
        "description": "Sandbox host capacity, lifecycle, execution, resources, networking, and health. APM, JuiceFS, and cloud storage sections require their own telemetry collection. Import into your own Datadog organization.",
        "layout_type": "ordered",
        "reflow_type": "auto",
        "template_variables": [
            {"name": name, "prefix": prefix, "available_values": [], "default": default}
            for name, prefix, default in (
                ("env", "env", "*"),
                ("cluster", "kube_cluster_name", "*"),
                ("namespace", "kube_namespace", "*"),
                ("api_service", "service", "platform-backend"),
                ("gcs_bucket", "bucket_name", "replace-with-bucket-name"),
                ("s3_bucket", "bucketname", "replace-with-bucket-name"),
            )
        ],
        "widgets": [
            note(
                "Import this dashboard into the Datadog organization that receives your own deployment's telemetry. Filters select data; they are not access controls. Select your env, cluster, and namespace after import. Wildcard defaults also work when those tags are absent. Configure their prefixes to match your collector. Collection configuration and compatibility requirements are in the accompanying README. Optional sections can remain empty until their integrations are configured."
            ),
            group("Fleet and capacity", fleet),
            group("Lifecycle operations", lifecycle),
            group("Boot path", boot),
            group("Guest runtime and data path", guest),
            group("Guest resources", resources),
            group("Egress proxy and DNS", egress),
            group("Health", health),
            group("Exec (API metrics optional)", execution),
            group("Sandbox API (optional APM)", api),
            group("JuiceFS (optional mount metrics)", juicefs),
            group("Object storage (optional cloud integration)", storage),
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).with_name("datadog-dashboard.json")
    rendered = json.dumps(build_dashboard(), indent=2) + "\n"
    if args.check:
        if not path.exists() or path.read_text() != rendered:
            raise SystemExit(
                "Regenerate datadog-dashboard.json with generate_dashboard.py"
            )
    else:
        path.write_text(rendered)


if __name__ == "__main__":
    main()
