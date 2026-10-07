SCOPE = "$env,$cluster,$namespace"
API = "$env,$api_service"
PUBLIC_API = API + ",resource_name:*_/v2/sandboxes/*,!resource_name:*/internal/*"
HTTP_API = (
    PUBLIC_API
    + ",!resource_name:*/ws,!resource_name:*/tunnel*,!resource_name:*/execute/stream/*,!resource_name:*/services/*"
)
INTERNAL_API = API + ",resource_name:*_/v2/sandboxes/internal/*"
HOST = "langsmith_sandbox_host"
POOL = "langsmith_sandbox_host_pool"
EGRESS = "langsmith_sandbox_egress_proxy"
DNS = "langsmith_sandbox_egress_dns"
SECTION_ROWS = {
    "Fleet and capacity": ((6, 6), (6, 6), (6, 6), (8, 4)),
    "Sandbox API (public v2, optional APM)": (
        (4, 8),
        (8, 4),
        (8, 4),
        (8, 4),
        (12,),
        (4, 4, 4),
        (4, 8),
        (12,),
        (12,),
        (6, 6),
    ),
    "Exec (API metrics optional)": ((4, 4, 4), (6, 6), (6, 6), (4, 4, 4), (6, 6)),
    "Lifecycle operations": (
        (6, 6),
        (6, 6),
        (12,),
        (6, 6),
        (6, 6),
        (4, 4, 4),
        (4, 4, 4),
        (4, 4, 4),
        (6, 6),
    ),
    "Boot path": ((4, 4, 4), (4, 4, 4), (6, 6)),
    "Guest runtime and data path": ((4, 8), (6, 6), (4, 4, 4), (6, 6), (6, 6)),
    "Guest resources": ((4, 4, 4), (6, 6), (8, 4)),
    "Egress proxy and DNS": ((4, 4, 4), (6, 6), (6, 6)),
    "JuiceFS storage (optional mount metrics)": ((4, 4, 4),),
    "JuiceFS metadata and cache (optional mount metrics)": (
        (8, 4),
        (8, 4),
        (6, 6),
        (6, 6),
        (6, 6),
    ),
    "Health and failure counters": ((4, 8), (6, 6)),
    "Runtime reporting (internal APM)": ((6, 6), (4, 8), (4, 8)),
    "Object storage (optional cloud integration)": ((6, 6), (6, 6)),
}


def query(name, aggregation="sum", scope=SCOPE, by="", rollup=""):
    return f"{aggregation}:{name}{{{scope}}}" + (f" by {{{by}}}" if by else "") + rollup


def number_format(unit):
    if unit in ("millisecond", "second"):
        value = {"type": "canonical_unit", "unit_name": unit}
        return {"unit": value, "unit_scale": value.copy()}
    if unit in ("percent", "byte", "byte/second"):
        value = {"type": "canonical_unit", "unit_name": unit.split("/")[0]}
        if unit == "byte/second":
            value["per_unit_name"] = "second"
        return {"unit": value}
    return {"unit": {"type": "custom_unit_label", "label": unit}}


def request(expression, queries, alias=None, unit=None, display="line", labels=None):
    formula = {"formula": expression}
    if alias:
        formula["alias"] = alias
    if unit:
        formula["number_format"] = number_format(unit)
    value = {
        "formulas": [formula],
        "queries": [
            {"data_source": "metrics", "name": name, "query": value}
            for name, value in queries.items()
        ],
        "response_format": "timeseries",
        "display_type": display,
    }
    if labels is True or (labels is None and display == "line"):
        value["style"] = {"has_value_labels": True}
    return value


def metric(value, alias=None, unit=None, display="line", labels=None):
    return request("q", {"q": value}, alias, unit, display, labels)


def mean(
    name,
    scope=SCOPE,
    by="",
    milliseconds=True,
    alias="Mean duration",
    unit=None,
    display="line",
    labels=None,
):
    return request(
        "1000 * total / samples" if milliseconds else "total / samples",
        {
            "total": query(name + ".sum", scope=scope, by=by, rollup=".as_count()"),
            "samples": query(name + ".count", scope=scope, by=by, rollup=".as_count()"),
        },
        alias,
        unit or ("millisecond" if milliseconds else "second"),
        display,
        labels,
    )


def series(title, *requests, markers=None):
    definition = {
        "type": "timeseries",
        "title": title,
        "requests": list(requests),
        "show_legend": True,
        "legend_layout": "vertical",
        "legend_size": "4",
        "legend_columns": ["value", "avg", "max"],
        "yaxis": {"min": "0"},
    }
    if markers:
        definition["markers"] = markers
    return {"definition": definition}


def scalar(title, value, aggregation="sum", custom_unit=None, live=False):
    value.pop("display_type", None)
    value.pop("style", None)
    value["response_format"] = "scalar"
    value["aggregator"] = aggregation
    for query in value["queries"]:
        query["aggregator"] = aggregation
    definition = {
        "type": "query_value",
        "title": title,
        "requests": [value],
        "autoscale": True,
        "precision": 0,
    }
    if custom_unit:
        definition["custom_unit"] = custom_unit
    if live:
        definition["time"] = {"live_span": "5m"}
    return {"definition": definition}


def toplist(title, value, aggregation="sum", limit=20, live=False):
    value.pop("display_type", None)
    value.pop("style", None)
    value["response_format"] = "scalar"
    for query in value["queries"]:
        query["aggregator"] = aggregation
    value["formulas"][0]["limit"] = {"count": limit, "order": "desc"}
    definition = {"type": "toplist", "title": title, "requests": [value]}
    if live:
        definition["time"] = {"live_span": "5m"}
    return {"definition": definition}


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


def group(title, widgets, color):
    return {
        "definition": {
            "type": "group",
            "title": title,
            "background_color": color,
            "layout_type": "ordered",
            "show_title": True,
            "widgets": widgets,
        }
    }


def layout(widgets, rows=None):
    allowed = (3, 4, 6, 8, 12)
    if rows is not None:
        panels = [item for item in widgets if item["definition"]["type"] != "note"]
        if sum(len(row) for row in rows) != len(panels):
            raise ValueError("Section row plan must include every data panel")
        if any(
            any(type(width) is not int or width not in allowed for width in row)
            or sum(row) != 12
            for row in rows
        ):
            raise ValueError("Section rows must fill the 12-column grid")
        planned = [
            [(item, 12)] for item in widgets if item["definition"]["type"] == "note"
        ]
        offset = 0
        for widths in rows:
            planned.append(list(zip(panels[offset : offset + len(widths)], widths)))
            offset += len(widths)
    else:
        retained = {}
        for item in widgets:
            position = item["layout"]
            retained.setdefault(position["y"], []).append((item, position["width"]))
        planned = [retained[y] for y in sorted(retained)]
    heights = {"note": 2, "query_value": 2, "timeseries": 4, "toplist": 5}
    y = 0
    for row in planned:
        if any(type(width) is not int or width not in allowed for _, width in row):
            raise ValueError("Unsupported panel width")
        total = sum(width for _, width in row)
        if not total or any(12 * width % total for _, width in row):
            raise ValueError("Retained panels must fit an integral grid")
        height = max(heights[item["definition"]["type"]] for item, _ in row)
        x = 0
        for item, width in row:
            width = 12 * width // total
            item["layout"] = {"x": x, "y": y, "width": width, "height": height}
            x += width
        y += height
    return y


def section_fleet_and_capacity():
    return [
        note(
            "Snapshots use 5m; trends use the dashboard range. Per-host samples align for up to 60s. Ready/desired counts use max with interpolation off to avoid adding leader reports: select one cluster/namespace, not a multi-pool total. Missing data is unknown, not zero. Commitment is assigned capacity; desired replicas update only while scaling is active."
        ),
        scalar(
            "Live sandboxes",
            metric(
                query(HOST + "_live_sandboxes", rollup=".fill(last,60)"),
                alias="Live sandboxes",
                unit="sandboxes",
            ),
            aggregation="last",
            live=True,
        ),
        scalar(
            "Ready hosts",
            metric(
                query(POOL + "_ready_hosts", aggregation="max", rollup=".fill(null)"),
                alias="Ready hosts",
                unit="hosts",
            ),
            aggregation="last",
            live=True,
        ),
        series(
            "Live sandboxes by cluster",
            metric(
                query(HOST + "_live_sandboxes", by="kube_cluster_name"),
                alias="Live sandboxes",
                unit="sandboxes",
                display="area",
            ),
        ),
        series(
            "Host pool: ready vs desired replicas",
            metric(
                query(POOL + "_ready_hosts", aggregation="max", rollup=".fill(null)"),
                alias="ready",
                unit="hosts",
            ),
            metric(
                query(
                    POOL + "_desired_replicas", aggregation="max", rollup=".fill(null)"
                ),
                alias="desired",
                unit="hosts",
            ),
        ),
        series(
            "Pool vCPU commitment % (assigned / capacity)",
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
                alias="Pool vCPU commitment",
                unit="percent",
            ),
            markers=[
                {
                    "display_type": "error dashed",
                    "label": "100% committed capacity",
                    "value": "y = 100",
                }
            ],
        ),
        series(
            "Fleet memory commitment % (assigned / capacity)",
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
                alias="Fleet memory commitment",
                unit="percent",
            ),
            markers=[
                {
                    "display_type": "error dashed",
                    "label": "100% committed capacity",
                    "value": "y = 100",
                }
            ],
        ),
        toplist(
            "Live sandboxes by host",
            metric(
                query(
                    HOST + "_live_sandboxes",
                    aggregation="avg",
                    by="host",
                    rollup=".fill(last,60)",
                ),
                alias="Live sandboxes",
                unit="sandboxes",
            ),
            aggregation="last",
            limit=20,
            live=True,
        ),
        series(
            "Rollout: hosts per build",
            metric(
                query(HOST + "_build_info", by="version"),
                alias="Rollout: hosts per build",
                unit="hosts",
                display="area",
            ),
        ),
    ]


def section_sandbox_api_public_v2_optional_apm():
    return [
        note(
            "Optional APM for public /v2/sandboxes routes. Internal reporting is separate. HTTP latency/rankings exclude streaming, tunnels and service proxy traffic. Only env and api_service filter APM; select exactly one API service. Metric/resource names can differ with instrumentation. 499 means a disconnected client."
        ),
        series(
            "Requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API,
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Requests",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "APM request errors by endpoint",
            metric(
                query(
                    "trace.http.request.errors",
                    scope=PUBLIC_API,
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="APM request errors",
                unit="errors",
                display="bars",
            ),
        ),
        series(
            "HTTP 5xx by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:5*",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="HTTP 5xx",
                unit="requests",
                display="bars",
                labels=True,
            ),
        ),
        series(
            "5xx by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:5*",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="5xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "4xx by endpoint (excluding 404 and 499)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",http.status_code:4*,!http.status_code:404,!http.status_code:499",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="4xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "4xx by status code (excluding 404)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:4*,!http.status_code:404",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="4xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "404 by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:404",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="404",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Notable 4xx codes",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:403",
                    rollup=".as_count()",
                ),
                alias="403 forbidden",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:409",
                    rollup=".as_count()",
                ),
                alias="409 conflict",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:429",
                    rollup=".as_count()",
                ),
                alias="429 rate limited",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:401",
                    rollup=".as_count()",
                ),
                alias="401 unauthorized",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",http.status_code:499",
                    rollup=".as_count()",
                ),
                alias="499 client hung up",
                unit="requests",
            ),
        ),
        toplist(
            "Endpoints returning 4xx (excluding 404 and 499)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",http.status_code:4*,!http.status_code:404,!http.status_code:499",
                    by="resource_name,http.status_code",
                    rollup=".as_count()",
                ),
                alias="Endpoints returning 4xx",
                unit="requests",
            ),
            aggregation="sum",
            limit=20,
        ),
        series(
            "Create box: 4xx by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes,http.status_code:4*",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Create box: 4xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Create box: rejections",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes,http.status_code:429",
                    rollup=".as_count()",
                ),
                alias="429 rate limited",
                unit="requests",
                display="bars",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes,http.status_code:503",
                    rollup=".as_count()",
                ),
                alias="503 no hosts",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Create box: requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",resource_name:post_/v2/sandboxes/boxes",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Create box: requests",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Public HTTP request latency (ms; non-streaming)",
            request(
                "1000 * q",
                {"q": query("trace.http.request", aggregation="p50", scope=HTTP_API)},
                alias="p50",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {"q": query("trace.http.request", aggregation="p95", scope=HTTP_API)},
                alias="p95",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {"q": query("trace.http.request", aggregation="p99", scope=HTTP_API)},
                alias="p99",
                unit="millisecond",
            ),
        ),
        toplist(
            "Busiest public endpoints (total requests)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API,
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Busiest public endpoints",
                unit="requests",
            ),
            aggregation="sum",
            limit=15,
        ),
        toplist(
            "Non-2xx public responses (total)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",!http.status_code:2*",
                    by="resource_name,http.status_code",
                    rollup=".as_count()",
                ),
                alias="Non-2xx public responses",
                unit="requests",
            ),
            aggregation="sum",
            limit=20,
        ),
        toplist(
            "Slowest public HTTP endpoints (window p95, ms)",
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request",
                        aggregation="p95",
                        scope=HTTP_API,
                        by="resource_name",
                    )
                },
                alias="p95",
                unit="millisecond",
            ),
            aggregation="percentile",
            limit=15,
        ),
        series(
            "Lifecycle endpoints: requests",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",resource_name:post_/v2/sandboxes/boxes",
                    rollup=".as_count()",
                ),
                alias="create box",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",resource_name:get_/v2/sandboxes/boxes",
                    rollup=".as_count()",
                ),
                alias="list boxes",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API + ",resource_name:get_/v2/sandboxes/boxes/_name",
                    rollup=".as_count()",
                ),
                alias="get box",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes/_name_/start",
                    rollup=".as_count()",
                ),
                alias="start",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes/_name_/stop",
                    rollup=".as_count()",
                ),
                alias="stop",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:delete_/v2/sandboxes/boxes/_name",
                    rollup=".as_count()",
                ),
                alias="delete",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/_sandbox_id_/upload",
                    rollup=".as_count()",
                ),
                alias="upload",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/download",
                    rollup=".as_count()",
                ),
                alias="download",
                unit="requests",
            ),
        ),
        series(
            "Lifecycle endpoints: non-2xx",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="create box",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/boxes,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="list boxes",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/boxes/_name,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="get box",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes/_name_/start,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="start",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/boxes/_name_/stop,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="stop",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:delete_/v2/sandboxes/boxes/_name,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="delete",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/_sandbox_id_/upload,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="upload",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/download,!http.status_code:2*",
                    rollup=".as_count()",
                ),
                alias="download",
                unit="requests",
            ),
        ),
    ]


def section_exec_api_metrics_optional():
    return [
        note(
            "Compare API transport behavior with host-side command execution. API charts require APM; host command charts use the host scrape. WebSocket duration measures connection lifetime, not command runtime. Host and API filters apply to their respective sources."
        ),
        series(
            "Exec requests by transport",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                    rollup=".as_count()",
                ),
                alias="http",
                unit="requests",
            ),
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/execute/ws",
                    rollup=".as_count()",
                ),
                alias="websocket",
                unit="requests",
            ),
        ),
        series(
            "Exec HTTP: requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Exec HTTP: requests",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Exec WebSocket: requests by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/execute/ws",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Exec WebSocket: requests",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Exec HTTP latency (ms)",
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request",
                        aggregation="p50",
                        scope=PUBLIC_API
                        + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                    )
                },
                alias="p50",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request",
                        aggregation="p95",
                        scope=PUBLIC_API
                        + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                    )
                },
                alias="p95",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request",
                        aggregation="p99",
                        scope=PUBLIC_API
                        + ",resource_name:post_/v2/sandboxes/_sandbox_id_/execute",
                    )
                },
                alias="p99",
                unit="millisecond",
            ),
        ),
        series(
            "Exec WebSocket connection lifetime (s)",
            metric(
                query(
                    "trace.http.request",
                    aggregation="p50",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/execute/ws",
                ),
                alias="p50",
                unit="second",
            ),
            metric(
                query(
                    "trace.http.request",
                    aggregation="p95",
                    scope=PUBLIC_API
                    + ",resource_name:get_/v2/sandboxes/_sandbox_id_/execute/ws",
                ),
                alias="p95",
                unit="second",
            ),
        ),
        series(
            "Exec APM request errors by endpoint",
            metric(
                query(
                    "trace.http.request.errors",
                    scope=PUBLIC_API + ",resource_name:*_/v2/sandboxes/*/execute*",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Exec APM request errors",
                unit="errors",
                display="bars",
            ),
        ),
        series(
            "Exec HTTP 5xx by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",http.status_code:5*,resource_name:*_/v2/sandboxes/*/execute*",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Exec HTTP 5xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Exec 4xx by status code",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=PUBLIC_API
                    + ",http.status_code:4*,resource_name:*_/v2/sandboxes/*/execute*",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Exec 4xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Commands run on host, by class",
            metric(
                query(
                    HOST + "_exec_commands.count",
                    by="command_class",
                    rollup=".as_count()",
                ),
                alias="Commands run on host,",
                unit="commands",
                display="bars",
            ),
        ),
        series(
            "Commands run on host, by transport",
            metric(
                query(
                    HOST + "_exec_commands.count", by="transport", rollup=".as_count()"
                ),
                alias="Commands run on host,",
                unit="commands",
                display="bars",
            ),
        ),
        series(
            "Command runtime on host (mean ms) by class",
            mean(HOST + "_exec_command_duration_seconds", by="command_class"),
        ),
        series(
            "API streaming/tunnel lifetime (p95, s)",
            metric(
                query(
                    "trace.http.request",
                    aggregation="p95",
                    scope=PUBLIC_API + ",resource_name:*/execute/stream/*",
                    by="resource_name",
                ),
                alias="SSE execution",
                unit="second",
            ),
            metric(
                query(
                    "trace.http.request",
                    aggregation="p95",
                    scope=PUBLIC_API + ",resource_name:*/tunnel*",
                    by="resource_name",
                ),
                alias="Tunnel",
                unit="second",
            ),
        ),
    ]


def section_lifecycle_operations():
    return [
        note(
            "Error totals include operations without a recorded stage; the dedicated card keeps those failures visible. Stage rankings include outcome:error only. Non-ok outcomes also show cancellations/deadlines. Host duration charts show interval means, not percentiles."
        ),
        scalar(
            "Operation errors (total)",
            metric(
                query(
                    HOST + "_operations.count",
                    scope=SCOPE + ",outcome:error",
                    rollup=".as_count()",
                ),
                alias="Operation errors",
                unit="errors",
            ),
            aggregation="sum",
            custom_unit="errors",
        ),
        scalar(
            "Failures without stage (total)",
            metric(
                query(
                    HOST + "_operations.count",
                    scope=SCOPE + ",outcome:error,failed_stage:",
                    rollup=".as_count()",
                ),
                alias="Failures without stage",
                unit="errors",
            ),
            aggregation="sum",
            custom_unit="errors",
        ),
        series(
            "Operations/s by operation",
            metric(
                query(HOST + "_operations.count", by="operation", rollup=".as_rate()"),
                alias="Operations/s",
                unit="operations/s",
                display="bars",
            ),
        ),
        series(
            "Operations/s by outcome",
            metric(
                query(HOST + "_operations.count", by="outcome", rollup=".as_rate()"),
                alias="Operations/s",
                unit="operations/s",
                display="bars",
            ),
        ),
        series(
            "Operation error rate % by operation (outcome:error only)",
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
                alias="Operation error rate",
                unit="percent",
            ),
        ),
        toplist(
            "Operation errors by recorded stage (total)",
            metric(
                query(
                    HOST + "_operations.count",
                    scope=SCOPE + ",!failed_stage:,outcome:error",
                    by="failed_stage,operation",
                    rollup=".as_count()",
                ),
                alias="Operation errors",
                unit="errors",
            ),
            aggregation="sum",
            limit=10,
        ),
        toplist(
            "Non-ok outcomes",
            metric(
                query(
                    HOST + "_operations.count",
                    scope=SCOPE + ",!outcome:ok",
                    by="operation,outcome",
                    rollup=".as_count()",
                ),
                alias="Non-ok outcomes",
                unit="operations",
            ),
            aggregation="sum",
            limit=10,
        ),
        series(
            "Ref lock contention/s by operation (concurrent same-sandbox ops)",
            metric(
                query(
                    HOST + "_ref_lock_contention.count",
                    by="operation",
                    rollup=".as_rate()",
                ),
                alias="Ref lock contention/s",
                unit="events/s",
            ),
        ),
        series(
            "Ref lock wait (mean ms) by operation",
            mean(HOST + "_ref_lock_wait_seconds", by="operation"),
        ),
        series(
            "create: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:create",
                by="outcome",
            ),
        ),
        series(
            "start: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:start",
                by="outcome",
            ),
        ),
        series(
            "stop_suspend: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:stop_suspend",
                by="outcome",
            ),
        ),
        series(
            "stop_discard: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:stop_discard",
                by="outcome",
            ),
        ),
        series(
            "delete: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:delete",
                by="outcome",
            ),
        ),
        series(
            "snapshot: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:snapshot",
                by="outcome",
            ),
        ),
        series(
            "export: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:export",
                by="outcome",
            ),
        ),
        series(
            "build: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:build",
                by="outcome",
            ),
        ),
        series(
            "reboot: mean duration (ms) by outcome",
            mean(
                HOST + "_operation_duration_seconds",
                scope=SCOPE + ",operation:reboot",
                by="outcome",
            ),
        ),
        series(
            "Stage duration (mean ms) by stage — create",
            mean(
                HOST + "_stage_duration_seconds",
                scope=SCOPE + ",operation:create",
                by="stage",
            ),
        ),
        series(
            "Stage duration (mean ms) by stage — start",
            mean(
                HOST + "_stage_duration_seconds",
                scope=SCOPE + ",operation:start",
                by="stage",
            ),
        ),
    ]


def section_boot_path():
    return [
        note(
            "Distinguish warm-image restores from cold boots, then inspect provisioning stages and clone-slot waits. Zygote means a reusable warm VM image. Host boot readiness includes startup work, not just guest boot time."
        ),
        series(
            "Boots/s by memory source",
            metric(
                query(HOST + "_boot_mode.count", by="mode", rollup=".as_rate()"),
                alias="Boots/s",
                unit="boots/s",
                display="bars",
            ),
        ),
        series(
            "Zygote hit rate % (boots served from a warm image)",
            request(
                "100 * zygote / boots",
                {
                    "zygote": query(
                        HOST + "_boot_mode.count",
                        scope=SCOPE + ",mode:zygote",
                        rollup=".as_count()",
                    ),
                    "boots": query(HOST + "_boot_mode.count", rollup=".as_count()"),
                },
                alias="Zygote hit rate",
                unit="percent",
            ),
        ),
        series(
            "Zygote capture/s by outcome",
            metric(
                query(
                    HOST + "_zygote_capture.count", by="outcome", rollup=".as_rate()"
                ),
                alias="Zygote capture/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "Zygote capture duration (mean ms)",
            mean(HOST + "_zygote_capture_duration_seconds"),
        ),
        series(
            "Startup provision (mean ms) by step",
            mean(
                HOST + "_startup_provision_duration_seconds",
                scope=SCOPE + ",outcome:ok",
                by="step",
            ),
        ),
        series(
            "Startup provision errors/s by step",
            metric(
                query(
                    HOST + "_startup_provision_duration_seconds.count",
                    scope=SCOPE + ",outcome:error",
                    by="step",
                    rollup=".as_rate()",
                ),
                alias="Startup provision errors/s",
                unit="events/s",
            ),
        ),
        series(
            "JuiceFS clone slot wait (mean ms) by clone type",
            mean(HOST + "_clone_slot_wait_seconds", by="clone_type"),
        ),
        series(
            "Host boot to ready (mean ms)",
            mean(HOST + "_boot_to_ready_seconds", by="kube_cluster_name"),
        ),
    ]


def section_guest_runtime_and_data_path():
    return [
        note(
            "Short-request latency excludes WebSocket, SSE, tunnels and service proxy traffic. Their durations are shown separately in seconds; service proxy metrics mix ordinary HTTP and upgrades. VM lifetime ends on suspend/restart and is not the sandbox's total lifetime."
        ),
        series(
            "Guest proxy requests/s by status class",
            metric(
                query(HOST + "_guest_requests.count", by="status", rollup=".as_rate()"),
                alias="Guest proxy requests/s",
                unit="requests/s",
                display="bars",
            ),
        ),
        toplist(
            "Guest proxy requests by route",
            metric(
                query(HOST + "_guest_requests.count", by="route", rollup=".as_count()"),
                alias="Guest proxy requests",
                unit="requests",
            ),
            aggregation="sum",
            limit=10,
        ),
        series(
            "Guest request duration (mean ms), non-streaming",
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE
                + ",!route:execute/ws,!route:tunnel,!route:execute/stream/*,!route:service",
                by="route",
            ),
        ),
        series(
            "Guest streaming/service durations (mean s)",
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE + ",route:execute/ws",
                by="route",
                alias="Exec WebSocket",
                milliseconds=False,
            ),
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE + ",route:execute/stream/start",
                by="route",
                alias="SSE start",
                milliseconds=False,
            ),
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE + ",route:execute/stream/resume",
                by="route",
                alias="SSE resume",
                milliseconds=False,
            ),
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE + ",route:tunnel",
                by="route",
                alias="Tunnel",
                milliseconds=False,
            ),
            mean(
                HOST + "_guest_request_duration_seconds",
                scope=SCOPE + ",route:service",
                by="route",
                alias="Service proxy",
                milliseconds=False,
            ),
        ),
        series(
            "Guest requests in flight",
            metric(
                query(HOST + "_guest_requests_in_flight", by="kube_cluster_name"),
                alias="Guest requests in flight",
                unit="requests",
            ),
        ),
        series(
            "Guest request rejects/s by reason",
            metric(
                query(
                    HOST + "_guest_request_rejects.count",
                    by="reason",
                    rollup=".as_rate()",
                ),
                alias="Guest request rejects/s",
                unit="events/s",
            ),
        ),
        series(
            "No-target requests/s by route (sandbox moved or suspended)",
            metric(
                query(HOST + "_guest_no_target.count", by="route", rollup=".as_rate()"),
                alias="No-target requests/s",
                unit="events/s",
            ),
        ),
        series(
            "Inter-host forwards/s vs failures/s",
            metric(
                query(HOST + "_forward.count", rollup=".as_rate()"),
                alias="forwarded",
                unit="events/s",
            ),
            metric(
                query(
                    HOST + "_forward_failures.count", by="reason", rollup=".as_rate()"
                ),
                alias="Inter-host forwards/s vs failures/s",
                unit="events/s",
            ),
        ),
        series(
            "Stops/s: idle watcher vs joined-in-progress",
            metric(
                query(HOST + "_idle_stops.count", rollup=".as_rate()"),
                alias="idle TTL",
                unit="events/s",
            ),
            metric(
                query(HOST + "_joined_stops.count", by="mode", rollup=".as_rate()"),
                alias="Stops/s: idle watcher vs joined-in-progress",
                unit="events/s",
            ),
        ),
        series(
            "Firecracker exits/s by reason",
            metric(
                query(HOST + "_vm_exits.count", by="reason", rollup=".as_rate()"),
                alias="Firecracker exits/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "VM lifetime (mean s) by outcome",
            mean(
                HOST + "_vm_lifetime_seconds",
                by="outcome",
                alias="Duration",
                milliseconds=False,
            ),
        ),
    ]


def section_guest_resources():
    return [
        note(
            "Guest resource totals across the selected hosts. CPU in use can exceed committed CPU during permitted bursts. Free-page-hint bytes and hint-round frequency use separate panels because they have different units."
        ),
        series(
            "Guest CPU cores in use vs committed",
            metric(
                query(HOST + "_sandbox_cpu_seconds.count", rollup=".as_rate()"),
                alias="cores in use",
                unit="cores",
                display="area",
            ),
            request(
                "assigned / 1000",
                {"assigned": query(HOST + "_assigned_cpu_millicores")},
                alias="cores committed",
                unit="cores",
            ),
        ),
        series(
            "CPU throttled vs pressure-stalled (seconds/s)",
            metric(
                query(
                    HOST + "_sandbox_cpu_throttled_seconds.count", rollup=".as_rate()"
                ),
                alias="throttled (burst limiter)",
                unit="s/s",
            ),
            metric(
                query(HOST + "_sandbox_cpu_stall_seconds.count", rollup=".as_rate()"),
                alias="PSI stall",
                unit="s/s",
            ),
        ),
        series(
            "Guest memory: resident vs returned to host",
            metric(
                query(HOST + "_sandbox_memory_rss_bytes"),
                alias="RSS",
                unit="byte",
                display="area",
            ),
            metric(
                query(HOST + "_sandbox_memory_returned_bytes"),
                alias="ballooned back",
                unit="byte",
            ),
        ),
        series(
            "Free-page-hint reclaim (bytes/s)",
            metric(
                query(
                    HOST + "_free_page_hint_reclaimed_bytes.sum", rollup=".as_rate()"
                ),
                alias="bytes reclaimed/s",
                unit="byte/second",
            ),
        ),
        series(
            "Free-page-hint rounds/s",
            metric(
                query(
                    HOST + "_free_page_hint_reclaimed_bytes.count", rollup=".as_rate()"
                ),
                alias="hint rounds/s",
                unit="rounds/s",
            ),
        ),
        series(
            "Guest tap throughput (bytes/s)",
            metric(
                query(
                    HOST + "_sandbox_network_receive_bytes.count", rollup=".as_rate()"
                ),
                alias="receive (into guest)",
                unit="byte/second",
            ),
            metric(
                query(
                    HOST + "_sandbox_network_transmit_bytes.count", rollup=".as_rate()"
                ),
                alias="transmit (out of guest)",
                unit="byte/second",
            ),
        ),
        series(
            "Tap dropped packets/s by direction",
            metric(
                query(
                    HOST + "_sandbox_network_dropped_packets.count",
                    by="direction",
                    rollup=".as_rate()",
                ),
                alias="Tap dropped packets/s",
                unit="packets/s",
            ),
        ),
    ]


def section_egress_proxy_and_dns():
    return [
        note(
            "Separate allowlist enforcement from proxy faults. access_denied is an expected policy denial and is excluded from the fault-rate percentage. DNS response codes can help explain guest network failures. Tenant rankings are intentionally omitted."
        ),
        series(
            "Egress requests/s by path",
            metric(
                query(EGRESS + "_requests.count", by="path", rollup=".as_rate()"),
                alias="Egress requests/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "Egress blocked/s by reason",
            metric(
                query(EGRESS + "_blocked.count", by="reason", rollup=".as_rate()"),
                alias="Egress blocked/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "Egress block rate % (excluding allowlist denials)",
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
                alias="Egress block rate",
                unit="percent",
            ),
        ),
        series(
            "Egress upstream failures/s by reason",
            metric(
                query(
                    EGRESS + "_upstream_failures.count",
                    by="reason",
                    rollup=".as_rate()",
                ),
                alias="Egress upstream failures/s",
                unit="events/s",
            ),
        ),
        series(
            "Egress bytes/s by path and direction",
            metric(
                query(
                    EGRESS + "_bytes.count", by="path,direction", rollup=".as_rate()"
                ),
                alias="Egress bytes/s",
                unit="byte/second",
                display="area",
            ),
        ),
        series(
            "MITM upstream time-to-headers (mean ms)",
            mean(EGRESS + "_mitm_upstream_duration_seconds"),
        ),
        series(
            "DNS queries/s by rcode",
            metric(
                query(DNS + "_queries.count", by="rcode", rollup=".as_rate()"),
                alias="DNS queries/s",
                unit="queries/s",
                display="bars",
            ),
        ),
    ]


def section_juicefs_storage_optional_mount_metrics():
    return [
        note(
            "JuiceFS logical space/inodes require the mount's separate metrics scrape. Logical space includes apparent sparse and copy-on-write file sizes; no fixed ratio to physical bucket bytes applies. Host mount readiness uses the host scrape."
        ),
        series(
            "JuiceFS logical used space (apparent, not stored)",
            metric(
                query("juicefs_used_space", aggregation="avg", by="kube_cluster_name"),
                alias="JuiceFS logical used space",
                unit="byte",
            ),
        ),
        series(
            "JuiceFS inodes used",
            metric(
                query("juicefs_used_inodes", aggregation="avg", by="kube_cluster_name"),
                alias="JuiceFS inodes used",
                unit="inodes",
            ),
        ),
        series(
            "JuiceFS mount ready (min across hosts)",
            metric(
                query(
                    HOST + "_juicefs_mount_ready",
                    aggregation="min",
                    by="kube_cluster_name",
                ),
                alias="JuiceFS mount ready",
            ),
        ),
    ]


def section_juicefs_metadata_and_cache_optional_mount_metrics():
    return [
        note(
            "Optional mount metrics: metadata and Redis latency, retries, object-store performance, and cache behavior. Staging blocks and staging bytes are split so unlike units do not share an axis."
        ),
        series(
            "Meta ops/s by method",
            metric(
                query("juicefs_meta_ops.count", by="method", rollup=".as_rate()"),
                alias="Meta ops/s",
                unit="ops/s",
                display="bars",
            ),
        ),
        series(
            "Meta op latency (mean ms)",
            mean(
                "juicefs_meta_ops_durations_histogram_seconds", by="kube_cluster_name"
            ),
        ),
        series(
            "Meta op latency (mean ms) by method",
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
                alias="Mean duration",
                unit="millisecond",
            ),
        ),
        series(
            "Redis transaction latency (mean ms)",
            mean(
                "juicefs_transaction_durations_histogram_seconds",
                by="kube_cluster_name",
            ),
        ),
        series(
            "Redis transaction restarts/s by method",
            metric(
                query(
                    "juicefs_transaction_restart.count",
                    by="method",
                    rollup=".as_rate()",
                ),
                alias="Redis transaction restarts/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "Object store request errors/s",
            metric(
                query("juicefs_object_request_errors.count", rollup=".as_rate()"),
                alias="Object store request errors/s",
                unit="events/s",
            ),
        ),
        series(
            "Object store latency (mean ms)",
            mean(
                "juicefs_object_request_durations_histogram_seconds",
                by="kube_cluster_name",
            ),
        ),
        series(
            "Staging backlog (blocks)",
            metric(
                query("juicefs_staging_blocks", aggregation="avg"),
                alias="blocks pending",
                unit="blocks",
            ),
        ),
        series(
            "Staging backlog (bytes)",
            metric(
                query("juicefs_staging_block_bytes", aggregation="avg"),
                alias="bytes pending",
                unit="byte",
            ),
        ),
        series(
            "Block cache hit rate %",
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
                alias="Block cache hit rate",
                unit="percent",
            ),
        ),
    ]


def section_health_and_failure_counters():
    return [
        note(
            "Correlate failure counters with lease staleness, mount health, and logs. Empty counters can mean no events, missing collection, or a process exit before a scrape. Lease markers show four missed 15-second renewals and the current five-minute self-fence window."
        ),
        series(
            "Lease staleness (s), max across hosts",
            metric(
                query(
                    HOST + "_lease_stale_seconds",
                    aggregation="max",
                    by="kube_cluster_name",
                ),
                alias="Lease staleness",
                unit="second",
            ),
            markers=[
                {
                    "display_type": "error dashed",
                    "label": "self-fence",
                    "value": "y = 300",
                },
                {
                    "display_type": "warning dashed",
                    "label": "4 missed renewals",
                    "value": "y = 60",
                },
            ],
        ),
        series(
            "Failure counts by cause",
            metric(
                query(HOST + "_lease_renew_failures.count", rollup=".as_count()"),
                alias="lease renew",
                unit="events",
            ),
            metric(
                query(
                    HOST + "_boot_failure_memory_invalidation.count",
                    rollup=".as_count()",
                ),
                alias="boot memory invalidation",
                unit="events",
            ),
            metric(
                query(HOST + "_zygote_unusable_fallback.count", rollup=".as_count()"),
                alias="zygote unusable",
                unit="events",
            ),
            metric(
                query(HOST + "_clone_slot_abandoned.count", rollup=".as_count()"),
                alias="clone slot abandoned",
                unit="events",
            ),
            metric(
                query(HOST + "_guestd_recycle.count", rollup=".as_count()"),
                alias="guestd recycle",
                unit="events",
            ),
            metric(
                query(HOST + "_forward_failures.count", rollup=".as_count()"),
                alias="host forward",
                unit="events",
            ),
            metric(
                query(
                    HOST + "_sandbox_memory_sample_failures.count", rollup=".as_count()"
                ),
                alias="memory sample",
                unit="events",
            ),
            metric(
                query(
                    HOST + "_sandbox_network_sample_failures.count",
                    rollup=".as_count()",
                ),
                alias="network sample",
                unit="events",
            ),
            metric(
                query(HOST + "_guest_log_dropped_entries.count", rollup=".as_count()"),
                alias="guest log dropped",
                unit="events",
            ),
        ),
        series(
            "Leader transitions/s by event",
            metric(
                query(
                    HOST + "_leader_transitions.count", by="event", rollup=".as_rate()"
                ),
                alias="Leader transitions/s",
                unit="events/s",
                display="bars",
            ),
        ),
        series(
            "Autoscaler window seeded/s (leader failover mid-drain)",
            metric(
                query(POOL + "_window_seeded.count", rollup=".as_rate()"),
                alias="Autoscaler window seeded/s",
                unit="events/s",
            ),
        ),
    ]


def section_runtime_reporting_internal_apm():
    return [
        note(
            "Optional APM for internal /v2/sandboxes reporting and host-observation endpoints, excluded from public API traffic and latency. Select one API service. Only env and api_service filter these panels; host cluster/namespace filters do not apply."
        ),
        series(
            "Internal reporting requests by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=INTERNAL_API,
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Internal reporting requests",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Internal reporting HTTP 5xx by endpoint",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=INTERNAL_API + ",http.status_code:5*",
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Internal reporting HTTP 5xx",
                unit="requests",
                display="bars",
                labels=True,
            ),
        ),
        series(
            "Internal reporting HTTP 4xx by status",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=INTERNAL_API + ",http.status_code:4*",
                    by="http.status_code",
                    rollup=".as_count()",
                ),
                alias="Internal reporting HTTP 4xx",
                unit="requests",
                display="bars",
            ),
        ),
        series(
            "Internal reporting APM errors by endpoint",
            metric(
                query(
                    "trace.http.request.errors",
                    scope=INTERNAL_API,
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Internal reporting APM errors",
                unit="errors",
                display="bars",
            ),
        ),
        series(
            "Internal reporting latency (ms)",
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request", aggregation="p50", scope=INTERNAL_API
                    )
                },
                alias="p50",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request", aggregation="p95", scope=INTERNAL_API
                    )
                },
                alias="p95",
                unit="millisecond",
            ),
            request(
                "1000 * q",
                {
                    "q": query(
                        "trace.http.request", aggregation="p99", scope=INTERNAL_API
                    )
                },
                alias="p99",
                unit="millisecond",
            ),
        ),
        toplist(
            "Busiest internal endpoints (total requests)",
            metric(
                query(
                    "trace.http.request.hits",
                    scope=INTERNAL_API,
                    by="resource_name",
                    rollup=".as_count()",
                ),
                alias="Busiest internal endpoints",
                unit="requests",
            ),
            aggregation="sum",
            limit=15,
        ),
    ]


def section_object_storage_optional_cloud_integration():
    return [
        note(
            "Optional AWS/GCP integrations measure physical bucket storage, independently of host and APM filters. Select exact gcs_bucket and s3_bucket names; placeholder defaults match no buckets. Remove unused provider panels. Azure Blob Storage requires provider-specific queries."
        ),
        series(
            "GCS stored bytes",
            metric(
                query(
                    "gcp.storage.storage.total_bytes",
                    aggregation="avg",
                    scope="$gcs_bucket",
                    by="bucket_name",
                ),
                alias="GCS stored bytes",
                unit="byte",
                display="area",
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
                ),
                alias="S3 stored bytes",
                unit="byte",
                display="area",
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
                ),
                alias="GCS object count",
                unit="objects",
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
                ),
                alias="S3 object count",
                unit="objects",
            ),
        ),
    ]


def build_dashboard():
    widgets = [
        note(
            "Import into your own Datadog organization and select one env, cluster and namespace for pool counts. Filters select data, not access rights. Fleet snapshots use 5m; other charts and totals follow the dashboard range. HTTP ranking uses whole-window p95. Legend AVG/MAX summarize plotted buckets. See the accompanying README for collection and optional integrations."
        ),
        group("Fleet and capacity", section_fleet_and_capacity(), "gray"),
        group(
            "Sandbox API (public v2, optional APM)",
            section_sandbox_api_public_v2_optional_apm(),
            "purple",
        ),
        group(
            "Exec (API metrics optional)", section_exec_api_metrics_optional(), "green"
        ),
        group("Lifecycle operations", section_lifecycle_operations(), "blue"),
        group("Boot path", section_boot_path(), "orange"),
        group(
            "Guest runtime and data path",
            section_guest_runtime_and_data_path(),
            "purple",
        ),
        group("Guest resources", section_guest_resources(), "green"),
        group("Egress proxy and DNS", section_egress_proxy_and_dns(), "orange"),
        group(
            "JuiceFS storage (optional mount metrics)",
            section_juicefs_storage_optional_mount_metrics(),
            "blue",
        ),
        group(
            "JuiceFS metadata and cache (optional mount metrics)",
            section_juicefs_metadata_and_cache_optional_mount_metrics(),
            "blue",
        ),
        group(
            "Health and failure counters", section_health_and_failure_counters(), "pink"
        ),
        group(
            "Runtime reporting (internal APM)",
            section_runtime_reporting_internal_apm(),
            "purple",
        ),
        group(
            "Object storage (optional cloud integration)",
            section_object_storage_optional_cloud_integration(),
            "gray",
        ),
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
        "title": "Self-hosted Sandbox Vitals",
        "description": "Sandbox capacity, public API and execution, lifecycle, runtime, resources, networking, storage and health. Import into your own Datadog organization. Optional APM, JuiceFS and cloud sections require their own collection. Select one cluster and namespace for pool counts.",
        "layout_type": "ordered",
        "reflow_type": "fixed",
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
        "widgets": widgets,
    }
