import ast
from functools import lru_cache
import json
import re

from components.sandboxes.datadog import build_dashboard as datadog_source
from components.sandboxes.datadog import layout


PREFIXES = ("langsmith_sandbox_", "juicefs_")
JUICEFS_COUNTERS = {
    "juicefs_meta_ops": "juicefs_meta_ops_total",
    "juicefs_meta_ops_duration_seconds": "juicefs_meta_ops_duration_seconds",
    "juicefs_transaction_restart": "juicefs_transaction_restart",
    "juicefs_object_request_errors": "juicefs_object_request_errors",
    "juicefs_blockcache_hits": "juicefs_blockcache_hits",
    "juicefs_blockcache_miss": "juicefs_blockcache_miss",
}
UNITS = {"percent": "percent", "millisecond": "ms", "second": "s", "byte": "bytes"}
COVERAGE = "Prometheus host and optional JuiceFS metrics only; API/APM and provider bucket metrics are not included. Data source and Namespace(s) apply to both tabs; Sandbox cluster applies only here. Select one Sandbox pool for capacity counts. Snapshot gauges require a sample within 60s; trends follow the dashboard range. Empty data is unknown, not zero."


def supported(panel):
    queries = [
        query["query"]
        for request in panel.get("requests", [])
        for query in request["queries"]
    ]
    return bool(queries) and all(
        query.split(":", 1)[1].startswith(PREFIXES) for query in queries
    )


@lru_cache(maxsize=1)
def histogram_names():
    return {
        query["query"].split(":", 1)[1].split("{", 1)[0][:-4]
        for group in datadog_source()["widgets"]
        for item in group["definition"].get("widgets", [])
        for request in item["definition"].get("requests", [])
        for query in request["queries"]
        if ".sum{" in query["query"]
    }


def prometheus_name(name):
    if not name.startswith(PREFIXES):
        raise ValueError("Metric family is not available in Prometheus")
    if name.endswith(".sum"):
        return name[:-4] + "_sum"
    if not name.endswith(".count"):
        return name
    base = name[:-6]
    if base in histogram_names():
        return base + "_count"
    if base.startswith("juicefs_"):
        return JUICEFS_COUNTERS[base]
    return base + "_total"


def labels(scope, juicefs=False):
    result = [
        'namespace=~"${namespace:regex}"',
        'cluster=~"${sandbox_cluster:regex}"',
        'job=~"${juicefs_job:regex}"' if juicefs else 'job=~"${sandbox_job:regex}"',
    ]
    for item in scope.split(","):
        if item in ("$env", "$cluster", "$namespace"):
            continue
        match = re.fullmatch(r"(!?)([a-zA-Z_]\w*):(.*)", item)
        if not match:
            raise ValueError("Unsupported metric filter: " + item)
        negate, key, value = match.groups()
        if key in ("tenant_id", "sandbox_id"):
            raise ValueError("Raw identity filters are not supported")
        wildcard = "*" in value
        operator = ("!~" if negate else "=~") if wildcard else ("!=" if negate else "=")
        if wildcard:
            value = re.escape(value).replace(r"\*", ".*")
        result.append(key + operator + json.dumps(value))
    return ",".join(result)


def prom_query(text, totals=False, snapshot=False):
    match = re.fullmatch(
        r"(sum|avg|max|min):([a-zA-Z0-9_.]+)\{([^{}]*)\}(?: by \{([a-zA-Z0-9_,]+)\})?(.*)",
        text,
    )
    if not match:
        raise ValueError("Unsupported metric expression")
    aggregate, name, scope, group, suffix = match.groups()
    if suffix not in ("", ".as_count()", ".as_rate()", ".fill(null)", ".fill(last,60)"):
        raise ValueError("Unsupported metric modifier")
    expression = (
        prometheus_name(name) + "{" + labels(scope, name.startswith("juicefs_")) + "}"
    )
    if suffix in (".as_rate()", ".as_count()"):
        function = "increase" if totals or suffix == ".as_count()" else "rate"
        interval = "$__range" if totals else "$__rate_interval"
        expression = f"{function}({expression}[{interval}])"
    elif snapshot or name in (
        "langsmith_sandbox_host_pool_ready_hosts",
        "langsmith_sandbox_host_pool_desired_replicas",
    ):
        expression = "last_over_time(" + expression + "[60s])"
    groups = [
        "cluster"
        if label == "kube_cluster_name"
        else "instance"
        if label == "host"
        else label
        for label in (group or "").split(",")
        if label
    ]
    if set(groups) & {"tenant_id", "sandbox_id"}:
        raise ValueError("Raw identity grouping is not supported")
    return aggregate + (
        " by (" + ",".join(groups) + ")" if groups else ""
    ) + "(" + expression + ")", groups


def formula(expression, queries):
    tree = ast.parse(expression, mode="eval")
    if len(list(ast.walk(tree))) > 100:
        raise ValueError("Formula exceeds complexity limit")
    operators = {ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/"}

    def render(node):
        if isinstance(node, ast.Name) and node.id in queries:
            return "(" + queries[node.id] + ")"
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            return str(node.value)
        if isinstance(node, ast.BinOp) and type(node.op) in operators:
            return (
                "("
                + render(node.left)
                + " "
                + operators[type(node.op)]
                + " "
                + render(node.right)
                + ")"
            )
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            return ("-" if isinstance(node.op, ast.USub) else "+") + render(
                node.operand
            )
        raise ValueError("Unsupported formula operation")

    return render(tree.body)


def unit(request):
    data = request["formulas"][0].get("number_format", {}).get("unit", {})
    if data.get("per_unit_name") == "second" and data.get("unit_name") == "byte":
        return "Bps"
    if data.get("unit_name") in UNITS:
        return UNITS[data["unit_name"]]
    return "suffix: " + data["label"] if data.get("label") else "short"


def convert_panel(definition, panel_id, position):
    kind = definition["type"]
    instant = kind in ("query_value", "toplist")
    snapshot = bool(definition.get("time"))
    targets = []
    overrides = []
    for index, request in enumerate(definition["requests"]):
        queries = {}
        group = []
        for query in request["queries"]:
            queries[query["name"]], group = prom_query(
                query["query"], totals=instant and not snapshot, snapshot=snapshot
            )
        expression = formula(request["formulas"][0]["formula"], queries)
        if kind == "toplist":
            expression = (
                f"topk({request['formulas'][0]['limit']['count']}, {expression})"
            )
        alias = request["formulas"][0].get("alias", "")
        legend = (alias + " " if alias else "") + " ".join(
            "{{" + label + "}}" for label in group
        )
        targets.append(
            {
                "refId": chr(65 + index),
                "expr": expression,
                "legendFormat": legend.strip() or "__auto",
                "instant": instant,
                "range": not instant,
                "datasource": {"type": "prometheus", "uid": "${datasource}"},
            }
        )
        overrides.append(
            {
                "matcher": {"id": "byFrameRefID", "options": chr(65 + index)},
                "properties": [{"id": "unit", "value": unit(request)}],
            }
        )
    thresholds = [{"color": "green", "value": None}]
    for marker in definition.get("markers", []):
        thresholds.append(
            {
                "color": "red"
                if marker["display_type"].startswith("error")
                else "orange",
                "value": float(marker["value"].split("=")[1]),
            }
        )
    thresholds[1:] = sorted(thresholds[1:], key=lambda item: item["value"])
    display = definition["requests"][0].get("display_type", "line")
    defaults = {
        "unit": unit(definition["requests"][0]),
        "min": 0,
        "thresholds": {"mode": "absolute", "steps": thresholds},
        "custom": {
            "drawStyle": "bars" if display == "bars" else "line",
            "fillOpacity": 40 if display in ("bars", "area") else 0,
            "lineWidth": 1,
            "thresholdsStyle": {"mode": "line"},
        },
    }
    options = {
        "legend": {
            "displayMode": "table",
            "placement": "bottom",
            "calcs": ["lastNotNull", "mean", "max"],
        },
        "tooltip": {"mode": "multi"},
    }
    if instant:
        options = {
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "orientation": "horizontal",
            "displayMode": "gradient",
            "colorMode": "value",
            "graphMode": "none",
        }
    result = {
        "id": panel_id,
        "type": "stat"
        if kind == "query_value"
        else "bargauge"
        if kind == "toplist"
        else "timeseries",
        "title": definition["title"],
        "gridPos": position,
        "datasource": {"type": "prometheus", "uid": "${datasource}"},
        "targets": targets,
        "fieldConfig": {"defaults": defaults, "overrides": overrides},
        "options": options,
    }
    if snapshot:
        result["timeFrom"] = "5m"
        result["description"] = (
            "Snapshot at the selected evaluation time; requires samples within 60 seconds. Missing data remains unknown."
        )
    return result


def build_dashboard():
    panels = [
        {
            "id": 1,
            "type": "text",
            "title": "Collection and coverage",
            "gridPos": {"x": 0, "y": 0, "w": 24, "h": 4},
            "options": {"mode": "markdown", "content": COVERAGE},
        }
    ]
    y = 4
    panel_id = 2
    for group in datadog_source()["widgets"]:
        definition = group["definition"]
        selected = [
            item
            for item in definition.get("widgets", [])
            if supported(item["definition"])
        ]
        if not selected:
            continue
        title = definition["title"].replace(
            "Exec (API metrics optional)", "Host-side execution"
        )
        panels.append(
            {
                "id": panel_id,
                "type": "row",
                "title": title,
                "collapsed": False,
                "gridPos": {"x": 0, "y": y, "w": 24, "h": 1},
                "panels": [],
            }
        )
        panel_id += 1
        y += 1
        height = layout(selected)
        for panel in selected:
            position = panel["layout"]
            grid = {
                "x": position["x"] * 2,
                "y": y + position["y"] * 2,
                "w": position["width"] * 2,
                "h": position["height"] * 2,
            }
            panels.append(convert_panel(panel["definition"], panel_id, grid))
            panel_id += 1
        y += height * 2
    variables = []
    for name, label, metric, tag in (
        (
            "sandbox_cluster",
            "Sandbox cluster",
            "langsmith_sandbox_host_live_sandboxes",
            "cluster",
        ),
        (
            "sandbox_job",
            "Sandbox host job",
            "langsmith_sandbox_host_live_sandboxes",
            "job",
        ),
        ("juicefs_job", "JuiceFS job", "juicefs_used_space", "job"),
    ):
        variables.append(
            {
                "type": "query",
                "name": name,
                "label": label,
                "datasource": {"type": "prometheus", "uid": "${datasource}"},
                "query": {"query": f"label_values({metric}, {tag})", "refId": name},
                "refresh": 1,
                "hide": 0 if name == "sandbox_cluster" else 2,
                "includeAll": True,
                "allValue": ".*",
                "multi": False,
                "current": {"text": "All", "value": "$__all"},
            }
        )
    return {
        "title": "Sandboxes",
        "panels": panels,
        "templating": {"list": variables},
        "annotations": {"list": []},
        "links": [],
    }
