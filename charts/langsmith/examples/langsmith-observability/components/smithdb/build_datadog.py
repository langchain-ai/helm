"""Builds the SmithDB tab of the LangSmith Self-Hosted Datadog dashboard (datadog.json in this folder).

Run without arguments to regenerate datadog.json, with --check to verify that it is up to date,
or with --output PATH to write the same dashboard elsewhere, for example to import it on its own.
Tooltips live in datadog_tooltips.json. generate_dashboards.py combines this tab with the Sandboxes tab.
"""
import argparse, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "datadog.json"
F = "$env,$cluster,$namespace"
DOCS = "https://docs.langchain.com/langsmith/self-host-smithdb-metrics"
ALERTS = "https://docs.langchain.com/langsmith/self-host-smithdb-alerts"
# last attempt per ingest task type (smith-go: MaxRetry 12, feedback mutations MaxRetry 25)
RUN_TASKS = "task IN (persist_run_or_parent,persist_batched_runs,upgrade_batched_runs,otel_rootless_topology)"
FB_BATCH = "task:persist_batched_feedbacks"
FB_MUT = "task IN (smithdb_feedback_mutation,coalesced_smithdb_feedbacks)"
# series labels for the remaining-attempts charts: 0 left means the last attempt failed
LEFT = {0: "0 left (lost)", 1: "1 attempt left", 2: "2 attempts left", 3: "3 attempts left"}

RED = [{"comparator": ">", "value": 0, "palette": "white_on_red"},
       {"comparator": "<=", "value": 0, "palette": "white_on_green"}]
def thresholds(yellow, red):
    return [{"comparator": ">=", "value": red, "palette": "white_on_red"},
            {"comparator": ">=", "value": yellow, "palette": "white_on_yellow"},
            {"comparator": "<", "value": yellow, "palette": "white_on_green"}]

def mq(name, query, aggregator=None):
    q = {"data_source": "metrics", "name": name, "query": query}
    if aggregator: q["aggregator"] = aggregator
    return q
def lq(name, search):
    return {"data_source": "logs", "name": name, "indexes": ["*"], "compute": {"aggregation": "count"},
            "group_by": [], "search": {"query": search}}
def fm(formula, alias=None, unit=None):
    f = {"formula": formula}
    if alias: f["alias"] = alias
    if unit: f["number_format"] = {"unit": {"type": "canonical_unit", "unit_name": unit}}
    return f

def note(md):
    return {"definition": {"type": "note", "content": md, "background_color": "transparent", "font_size": "14",
                           "text_align": "left", "vertical_align": "top", "show_tick": False, "has_padding": True}}
def qv(title, queries, formula, cond, unit=None, precision=0):
    f = fm(formula, unit=unit)
    return {"definition": {"type": "query_value", "title": title, "title_align": "left", "title_size": "16",
            "precision": precision, "autoscale": True,
            "requests": [{"response_format": "scalar", "queries": queries, "formulas": [f], "conditional_formats": cond}]}}
def toplist(title, queries, formula, cond=None, unit=None, limit=5):
    f = fm(formula, unit=unit); f["limit"] = {"count": limit, "order": "desc"}
    if cond: f["conditional_formats"] = cond  # formula-based toplists take colours on the formula
    r = {"response_format": "scalar", "queries": queries, "formulas": [f]}
    return {"definition": {"type": "toplist", "title": title, "title_align": "left", "title_size": "16", "requests": [r]}}
def ts(title, series, display="line", markers=None, legend=True):
    """series: list of (queries, formulas, display_or_None, right_axis)"""
    reqs = []
    for s in series:
        queries, formulas = s[0], s[1]
        disp = s[2] if len(s) > 2 and s[2] else display
        r = {"response_format": "timeseries", "queries": queries, "formulas": formulas, "display_type": disp,
             "style": {"palette": "dog_classic", "line_type": "solid", "line_width": "normal"}}
        if len(s) > 3 and s[3]: r["on_right_yaxis"] = True
        if len(s) > 4 and s[4]: r["style"].update(s[4])
        reqs.append(r)
    # No bars: at long time ranges, one bar covers a whole rollup interval and becomes too wide.
    # Former bar series become lines; counts are zero-filled so sparse events draw a line at 0, not loose dots.
    mixed = any(r["display_type"] == "bars" for r in reqs) and any(r["display_type"] != "bars" for r in reqs)
    for r in reqs:
        if r["display_type"] != "bars": continue
        r["display_type"] = "line"
        if mixed and r["style"]["palette"] == "dog_classic": r["style"]["palette"] = "orange"
        for f in r["formulas"]:
            if not f["formula"].startswith("default_zero(") and "top(" not in f["formula"]:
                f["formula"] = f"default_zero({f['formula']})"
    d = {"type": "timeseries", "title": title, "title_align": "left", "title_size": "16", "show_legend": legend,
         "legend_layout": "auto", "legend_columns": ["avg", "max", "value"], "requests": reqs}
    if markers: d["markers"] = markers
    return {"definition": d}
def stacked_bars(widget):
    """Exception to the no-bars rule: stacked bars by one tag, as in the Ingestion Vitals dashboard."""
    d = widget["definition"]
    for r in d["requests"]:
        r["display_type"] = "bars"
        r["style"].update({"palette": "warm", "order_by": "values"})
    d["legend_layout"] = "vertical"; d["legend_columns"] = ["avg", "sum", "max", "value"]
    return widget
def per_second(widget):
    """count:<distribution>.as_rate() has no unit in Datadog; label it as a rate explicitly."""
    for r in widget["definition"]["requests"]:
        for f in r["formulas"]:
            f["number_format"] = {"unit": {"type": "custom_unit_label", "label": "/s"}}
    return widget
def marker(y, label, kind="warning dashed"):
    return {"value": f"y = {y}", "display_type": kind, "label": label}

def resources(label, patterns, hpa=True, throttling=True, memory=False):
    """Kubernetes resource charts for one component. patterns: kube_deployment wildcards."""
    def pairs(metric_a, metric_b, by, agg="max"):
        qs, i = [], 0
        for pat in patterns:
            qs.append((mq(f"a{i}", f"{agg}:{metric_a}{{{F},kube_deployment:{pat}}} by {{{by}}}"),
                       mq(f"b{i}", f"{agg}:{metric_b}{{{F},kube_deployment:{pat}}} by {{{by}}}"), i)); i += 1
        return qs
    out = []
    if throttling:
        # left: fullest pod's CPU use as % of its limit (usage in nanocores, limit in cores; one limit per Deployment)
        # right, orange: throttled share of CPU periods across all pods, which catches bursts that the average hides
        cpu = pairs("kubernetes.cpu.usage.total", "kubernetes.cpu.limits", "kube_deployment")
        thr = pairs("kubernetes.cpu.cfs.throttled.periods", "kubernetes.cpu.cfs.periods", "kube_deployment", agg="sum")
        out.append(ts(f"{label}: CPU, % of limit, and throttling",
                      [([dict(a, name=f"c{i}"), dict(b, name=f"k{i}")], [fm(f"100 * c{i} / (k{i} * 1000000000)", "CPU, % of limit (fullest pod)", "percent")], "line")
                       for a, b, i in cpu]
                      + [([dict(a, name=f"t{i}"), dict(b, name=f"u{i}")], [fm(f"100 * t{i} / u{i}", "Throttled, % of periods (all pods)", "percent")], "line", True, {"palette": "orange"})
                         for a, b, i in thr], markers=[marker(80, "80% warning")]))
    if memory:
        # all pods of a Deployment share one memory limit, so max(working set) / max(limit) is the fullest pod, as one continuous line
        mem = pairs("kubernetes.memory.working_set", "kubernetes.memory.limits", "kube_deployment")
        out.append(ts(f"{label}: memory, % of limit (fullest pod)",
                      [([dict(a, name=f"w{i}"), dict(b, name=f"l{i}")], [fm(f"100 * w{i} / l{i}", "Memory, % of limit", "percent")], "line")
                       for a, b, i in mem], markers=[marker(80, "80% warning")]))
    rq = []
    for i, pat in enumerate(patterns):
        rq.append(([mq(f"r{i}", f"sum:kubernetes.containers.restarts{{{F},kube_deployment:{pat}}} by {{kube_deployment}}")],
                   [fm(f"clamp_min(diff(r{i}), 0)", "Restarts")], "bars"))
        rq.append(([mq(f"o{i}", f"sum:kubernetes.containers.last_state.terminated{{{F},kube_deployment:{pat},reason:oomkilled}} by {{kube_deployment}}")],
                   [fm(f"o{i}", "Containers last stopped by OOM kill")], "line", True))
    out.append(ts(f"{label}: restarts and OOM kills", rq))
    rep = []
    if hpa:
        for i, pat in enumerate(patterns):
            rep.append(([mq(f"h{i}", f"max:kubernetes_state.hpa.current_replicas{{{F},horizontalpodautoscaler:{pat}}} by {{horizontalpodautoscaler}}"),
                         mq(f"m{i}", f"max:kubernetes_state.hpa.max_replicas{{{F},horizontalpodautoscaler:{pat}}} by {{horizontalpodautoscaler}}")],
                        [fm(f"100 * h{i} / m{i}", "Autoscaler use, % of max", "percent")], "line"))
        for i, pat in enumerate(patterns):
            rep.append(([mq(f"d{i}", f"max:kubernetes_state.deployment.replicas_desired{{{F},kube_deployment:{pat}}} by {{kube_deployment}}"),
                         mq(f"v{i}", f"max:kubernetes_state.deployment.replicas_available{{{F},kube_deployment:{pat}}} by {{kube_deployment}}")],
                        [fm(f"default_zero(clamp_min(d{i} - v{i}, 0))", "Unavailable replicas")], "bars", True, {"palette": "orange"}))
        out.append(ts(f"{label}: autoscaler use and unavailable replicas", rep, markers=[marker(100, "At autoscaler max", "error dashed")]))
    else:
        for i, pat in enumerate(patterns):
            rep.append(([mq(f"d{i}", f"max:kubernetes_state.deployment.replicas_desired{{{F},kube_deployment:{pat}}} by {{kube_deployment}}"),
                         mq(f"v{i}", f"max:kubernetes_state.deployment.replicas_available{{{F},kube_deployment:{pat}}} by {{kube_deployment}}")],
                        [fm(f"d{i}", "Desired"), fm(f"v{i}", "Available")], "line"))
        out.append(ts(f"{label}: replicas", rep))
    return out

SERVICE_HDR = "#### Service metrics\nWhat the component reports about its own work: backlogs, latency, errors."
INFRA_HDR = "#### Infrastructure\nKubernetes signals of the component's pods: CPU use and throttling, memory use for the SmithDB data components, restarts and OOM kills, and replicas."

def subheader(md):
    n = note(md); n["definition"]["background_color"] = "white"; n["definition"]["vertical_align"] = "center"
    return n

def group(title, color, intro, widgets, cols=3, h=3, note_h=1, infra=None, infra_titles=None, infra_hdr=INFRA_HDR):
    """widgets: service metrics. infra: list of (header_md, widgets) blocks. infra_titles: titles to move from widgets into one infra block."""
    infra = list(infra or [])
    if infra_titles:
        moved = [w for w in widgets if w["definition"].get("title") in infra_titles]
        assert len(moved) == len(infra_titles), f"infra_titles not found in {title}"
        widgets = [w for w in widgets if w not in moved]
        infra.insert(0, (infra_hdr, moved))
    blocks = ([(SERVICE_HDR if widgets else None, widgets)] if widgets else []) + infra if infra else [(None, widgets)]
    lay, y = [], 0
    if intro:
        n = note(intro); n["layout"] = {"x": 0, "y": 0, "width": 12, "height": note_h}; lay.append(n); y = note_h
    for blk in blocks:
        hdr, ws = blk[0], blk[1]
        bcols = blk[2] if len(blk) > 2 else (4 if len(ws) == 4 else cols)
        w = 12 // bcols
        if hdr:
            sh = subheader(hdr); sh["layout"] = {"x": 0, "y": y, "width": 12, "height": 1}; lay.append(sh); y += 1
        for i, wd in enumerate(ws):
            wd["layout"] = {"x": (i % bcols) * w, "y": y + (i // bcols) * h, "width": w, "height": h}
            lay.append(wd)
        if ws:
            y += ((len(ws) - 1) // bcols + 1) * h
    return {"definition": {"type": "group", "title": title, "background_color": color, "show_title": True,
                           "layout_type": "ordered", "widgets": lay}}

# ---------------- Shared query pieces ----------------
# Resource selectors: template variables without a fixed tag key. The customer selects one tag of the resource,
# for example cluster_id:<name>; queries of the other providers then match nothing and stay empty.
REDIS_AGENT = EC = MS_MEM = MSC = "$redis"
DB = "$metastore"
# All SmithDB Deployments. smithdb-migration is excluded: it normally has no pods. In the Helm chart the migration
# is a Job, so the exclusion only matters for installations that run it as a Deployment.
SMITHDB_DEPLOYS = "kube_deployment:*smithdb*,!kube_deployment:*smithdb-migration*"
READS = "path:/query.queryservice/*,!path:/query.queryservice/ingestfeedback,!path:/query.queryservice/deleteruns"
SERVER_ERR = "status IN (error,timeout,2,4,8,13,14,15)"  # server-side failures: gRPC codes, and SmithDB's error/timeout statuses (metrics_layer.rs)
WRITES = "kube_deployment:*smithdb-ingestion*,path:/ingestion.ingestionservice/*,type:grpc"

def guarded(formula, guard="g"):
    """Return 'No data' instead of 0 when the guard query has no data."""
    return f"({formula}) / (0 * {guard} + 1)"

# ---------------- Health overview ----------------
def load_series(query, alias, unit=None, by_query=None, display="line"):
    """One request: the grouped query if given, otherwise the total."""
    cur = by_query or query
    return [([mq("c", cur)], [fm("c", alias if not by_query else None, unit)], display)]

load_tiles = [
  per_second(qv("Runs stored per second", [mq("q1", f"count:langsmith_ingestion_e2e_latency_seconds{{{F},store:smithdb}}.as_rate()", "avg")], "q1", [])),
  qv("Query requests per second", [mq("q1", f"sum:smithdb.server_requests_duration.count{{{F},{READS}}}.as_rate()", "avg")], "q1", []),
]
# same pods as Alert 13: SmithDB components (without the migration) and the ingest queue, in one query
RESTART_Q = (f"default_zero(clamp_min(diff(sum:kubernetes.containers.restarts{{{F},"
             f"(kube_deployment:*smithdb* OR kube_deployment:*ingest-queue*),!kube_deployment:*smithdb-migration*}}),0))")
health_tiles = [
  qv("Data loss signals (should be 0)", [
      mq("q1", f"sum:redis.keys.evicted{{{REDIS_AGENT}}}.as_count()", "sum"),
      mq("q2", f"sum:aws.elasticache.evictions{{{EC}}}.as_count()", "sum"),
      mq("q3", f"sum:gcp.redis.stats.evicted_keys{{{MS_MEM}}}.as_count()", "sum"),
      mq("q5", f"sum:gcp.redis.cluster.stats.total_evicted_keys_count{{{MSC}}}.as_count()", "sum"),
      mq("q4", f"sum:langsmith_ingest_task_failures.count{{{F},{RUN_TASKS},attempt:12}}.as_count()", "sum"),
      mq("q6", f"sum:langsmith_ingest_task_failures.count{{{F},{FB_BATCH},attempt:12}}.as_count()", "sum"),
      mq("q7", f"sum:langsmith_ingest_task_failures.count{{{F},{FB_MUT},attempt:25}}.as_count()", "sum"),
      mq("g", f"max:langsmith_asynq_ingestion_queue_retry{{{F}}}", "max")],
     guarded("default_zero(q1) + default_zero(q2) + default_zero(q3) + default_zero(q5) + default_zero(q4) + default_zero(q6) + default_zero(q7)"), RED),
  # persist_batched_feedbacks does not count its losses while the run is not ingested; attempt 11 is its last counted signal (Alert 2 warning)
  qv("Feedback at risk (should be 0)", [
      mq("q1", f"sum:langsmith_ingest_task_failures.count{{{F},{FB_BATCH},attempt:11}}.as_count()", "sum"),
      mq("g", f"max:langsmith_asynq_ingestion_queue_retry{{{F}}}", "max")],
     guarded("default_zero(q1)"),
     [{"comparator": ">", "value": 0, "palette": "white_on_yellow"}, {"comparator": "<=", "value": 0, "palette": "white_on_green"}]),
  qv("Oldest waiting ingestion task", [mq("q1", f"max:langsmith_asynq_queue_latency_seconds{{{F},queue:ingestion*}}", "max")],
     "q1", thresholds(600, 1800), unit="second"),
  qv("Ingestion tasks waiting for retry", [mq("q1", f"max:langsmith_asynq_ingestion_queue_retry{{{F}}}", "last")],
     "q1", thresholds(100, 1000)),
  qv("SmithDB write error rate", [
      mq("q1", f"sum:smithdb.server_requests_duration.count{{{F},{WRITES},!status:0}}.as_count()", "sum"),
      mq("q2", f"sum:smithdb.server_requests_duration.count{{{F},{WRITES}}}.as_count()", "sum")],
     "100 * default_zero(q1) / q2", thresholds(1, 5), unit="percent", precision=2),
  # one value per pool; top(..., 1, 'max', 'desc') keeps only the worst pool, so a query value tile can show it (monitor 5 alerts per pool)
  qv("Query error rate, worst pool", [
      mq("q1", f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/*,{SERVER_ERR}}} by {{kube_deployment}}.as_count()", "sum"),
      mq("q2", f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/*}} by {{kube_deployment}}.as_count()", "sum")],
     "top(100 * default_zero(q1) / q2, 1, 'max', 'desc')", thresholds(5, 10), unit="percent", precision=1),
  # Alert 10 has only a critical level: red at 1,000 (the monitor also requires 2 hours above it)
  qv("Pending compaction jobs", [mq("q1", f"sum:smithdb.compaction_queue_job_count{{{F},status:pending}}", "last")],
     "q1", [{"comparator": ">=", "value": 1000, "palette": "white_on_red"}, {"comparator": "<", "value": 1000, "palette": "white_on_green"}]),
  {"definition": {"type": "query_value", "title": "Container restarts", "title_align": "left", "title_size": "16",
     "precision": 0, "autoscale": True,
     # Alert 13: warning at 1 restart, critical at 3 (the alert counts each pod over 30 minutes; the tile sums the selected time range)
     "requests": [{"q": RESTART_Q, "aggregator": "sum", "conditional_formats": thresholds(1, 3)}]}},
  qv("Redis memory, % of limit", [
      mq("u", f"max:redis.mem.used{{{REDIS_AGENT}}}", "max"),
      mq("x", f"max:redis.mem.maxmemory{{{REDIS_AGENT}}}", "max"),
      mq("e", f"max:aws.elasticache.database_memory_usage_percentage{{{EC}}}", "max"),
      mq("m", f"max:gcp.redis.stats.memory.usage_ratio{{{MS_MEM}}}", "max"),
      mq("c", f"max:gcp.redis.cluster.memory.maximum_utilization{{{MSC}}}", "max")],
     # highest value of the selected provider; "No data" when no source matches the selection
     "max(max(default_zero(100 * u / x), default_zero(e)), max(default_zero(100 * m), default_zero(100 * c))) / (u * 0 + e * 0 + m * 0 + c * 0 + 1)",
     thresholds(80, 90), unit="percent"),
  qv("Metastore connections, % of max", [mq("q1", f"max:postgresql.percent_usage_connections{{{DB}}}", "max")],
     "100 * q1", thresholds(80, 90), unit="percent"),
  # matches JSON logs (backtrace attribute) and plain-text logs ("thread panicked"); the excluded message double-counts another failure
  qv("SmithDB panics", [lq("q1", "kube_deployment:*smithdb* (@backtrace:* OR \"thread panicked\") -\"Runtime dropped task without completing it\" $env $cluster $namespace")],
     "q1", thresholds(1, 4)),
  qv("Fewest available pods in a SmithDB component",
     [mq("q1", f"min:kubernetes_state.deployment.replicas_available{{{F},{SMITHDB_DEPLOYS}}}", "last")], "q1",
     [{"comparator": "<", "value": 1, "palette": "white_on_red"}, {"comparator": ">=", "value": 1, "palette": "white_on_green"}]),
]
# Display order of the health tiles (set in the Datadog UI on 2026-11-20)
HEALTH_ORDER = ["Data loss signals (should be 0)", "Feedback at risk (should be 0)", "Oldest waiting ingestion task", "Ingestion tasks waiting for retry", "SmithDB write error rate",
                "Query error rate, worst pool", "Pending compaction jobs", "Metastore connections, % of max", "Redis memory, % of limit",
                "Fewest available pods in a SmithDB component", "Container restarts", "SmithDB panics"]
assert sorted(HEALTH_ORDER) == sorted(w["definition"]["title"] for w in health_tiles), "HEALTH_ORDER does not match the health tiles"
health_tiles.sort(key=lambda w: HEALTH_ORDER.index(w["definition"]["title"]))
# tile -> (what to open, monitor hint); used to complete the tile tooltips. Numbers, windows, and anchors match the Recommended SmithDB alerts page.
TILE_INFO = {
  "Data loss signals (should be 0)": ("the Data loss section",
      f"Matches [Alerts 1]({ALERTS}#1-runs-are-lost) and [2]({ALERTS}#2-feedback-is-lost). For a monitor, use the Redis evictions over the last 5 minutes, and the last-attempt failures over the last 15 minutes: attempt 12 for run tasks and `persist_batched_feedbacks`, attempt 25 for the feedback mutation tasks. Also warn on attempt 11 of `persist_batched_feedbacks`, because this task does not count all of its losses."),
  "Feedback at risk (should be 0)": ("the Data loss section",
      f"Matches the warning in [Alert 2]({ALERTS}#2-feedback-is-lost). For a monitor, use the same query over the last 15 minutes."),
  "Oldest waiting ingestion task": ("the LangSmith ingestion section",
      f"Matches [Alert 3]({ALERTS}#3-the-ingestion-backlog-gets-old). For a monitor, use the same query over the last 10 minutes."),
  "Ingestion tasks waiting for retry": ("the LangSmith ingestion section",
      f"Matches [Alert 3]({ALERTS}#3-the-ingestion-backlog-gets-old). For a monitor, use the same query, and alert when it stays above the threshold for the last 30 minutes."),
  "SmithDB write error rate": ("the SmithDB ingestion section",
      f"Matches [Alert 5]({ALERTS}#5-writes-fail). For a monitor, use the same query over the last 15 minutes, and also require at least 50 failed calls."),
  "Query error rate, worst pool": ("the SmithDB query section",
      f"Matches [Alert 6]({ALERTS}#6-queries-fail). For a monitor, use the same query over the last 15 minutes, and alert for each pool."),
  "Pending compaction jobs": ("the SmithDB compaction section",
      f"Matches [Alert 10]({ALERTS}#10-compaction-falls-behind). For a monitor, alert when the value stays above 1,000 for the last 2 hours."),
  "Container restarts": ("the Infrastructure block of each section",
      f"Matches [Alert 13]({ALERTS}#13-pods-restart-often). For a monitor, count the restarts of each pod over the last 30 minutes: warning at 1, critical at 3."),
  "Redis memory, % of limit": ("the Redis section",
      f"Matches [Alert 4]({ALERTS}#4-redis-is-almost-full). For a monitor, use the same query over the last 10 minutes."),
  "Metastore connections, % of max": ("the SmithDB metastore (PostgreSQL) section",
      f"Matches [Alert 7]({ALERTS}#7-the-metastore-is-saturated). For a monitor, use the same query over the last 5 minutes."),
  "SmithDB panics": ("the Log Explorer with the same search",
      f"Matches [Alert 14]({ALERTS}#14-smithdb-panics). For a monitor, count the same log lines for each kube_deployment over the last 15 minutes: warning at 1, critical above 3."),
  "Fewest available pods in a SmithDB component": ("the Infrastructure block of the component",
      f"Matches [Alert 12]({ALERTS}#12-a-component-has-no-pods). For a monitor, use the same query by kube_deployment over the last 10 minutes, and notify on no data."),
}
overview = group("Is everything healthy?", "vivid_green",
 "Green: no action. Yellow: examine soon. Red: act now. The tooltip of each tile gives its thresholds and the section to open. "
 "A tile that shows **No data** does not get the data it needs. The thresholds are starting values. Adjust them to your traffic. "
 f"[Recommended SmithDB alerts]({ALERTS}) · [SmithDB metrics reference]({DOCS})",
 [], infra=[("#### Load\nThe work that reaches the system now. The Workload section shows the trends.", load_tiles, 2),
            ("#### Health\nEach tile turns yellow or red when its signal needs action.", health_tiles, 4)], cols=3, h=2)

# ---------------- Workload ----------------
workload = group("Workload", "vivid_purple",
 "The work that reaches the system: runs and feedback that come in, and queries from users and automations. "
 "Use this section as context. A change in a backlog or in latency means more when you know whether the load changed. "
 "A sudden drop in runs stored while clients still send runs is an important alarm.", [],
 infra=[
  ("#### Writes\nRuns and feedback that come in.", [
    per_second(ts("Runs stored per second, over time", load_series(
        f"count:langsmith_ingestion_e2e_latency_seconds{{{F},store:smithdb}}.as_rate()", "Runs stored"))),
    ts("Feedback writes per second", load_series(
        f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/ingestfeedback}}.as_rate()", "Feedback write requests")),
  ], 3),
  ("#### Reads\nQueries from the UI, the API, and automations. The chart by type also shows feedback writes (`ingestfeedback`) and deletes (`deleteruns`). The other charts count reads only.", [
    ts("Query requests per second, by pool", load_series(
        f"sum:smithdb.server_requests_duration.count{{{F},{READS}}}.as_rate()", "Query requests",
        by_query=f"sum:smithdb.server_requests_duration.count{{{F},{READS}}} by {{kube_deployment}}.as_rate()")),
    ts("Query requests per second, by type (top 10)", [
        ([mq("q1", f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/*}} by {{path}}.as_rate()")],
         [fm("top(q1, 10, 'mean', 'desc')")], "area")]),
  ], 3),
 ], cols=3, h=3, note_h=1)

# ---------------- Data loss ----------------
dataloss = group("Data loss", "red",
 "These charts show runs and feedback that are lost, or that will be lost soon. "
 "**Evictions:** Redis keeps run data for 6 hours, also after ingestion. An eviction can remove data that SmithDB has not stored yet. "
 "**Failures by remaining attempts** show tasks that are close to their last attempt. **0 left** means lost. Failures with attempts left are a warning. Run tasks have 12 retries. Feedback mutation tasks have 25. "
 "`persist_batched_feedbacks` does not count all of its losses: see the tooltip of the feedback chart. "
 "**Dropped by project trace limit** is not a failure: LangSmith drops these runs on purpose when a project exceeds its monthly trace limit. Use it to explain missing traces.", [
  ts("Redis evicted keys", [([mq("q1", f"sum:redis.keys.evicted{{{REDIS_AGENT}}} by {{redis_host}}.as_count()"),
                              mq("q2", f"sum:aws.elasticache.evictions{{{EC}}} by {{cacheclusterid}}.as_count()"),
                              mq("q3", f"sum:gcp.redis.stats.evicted_keys{{{MS_MEM}}} by {{instance_id}}.as_count()"),
                              mq("q4", f"sum:gcp.redis.cluster.stats.total_evicted_keys_count{{{MSC}}} by {{cluster_id}}.as_count()")],
                             [fm("q1", "Redis integration"), fm("q2", "ElastiCache"), fm("q3", "Memorystore"), fm("q4", "Memorystore Cluster")])], display="bars"),
  stacked_bars(ts("Run task failures by remaining attempts", [(
      [mq(f"r{k}", f"sum:langsmith_ingest_task_failures.count{{{F},{RUN_TASKS},attempt:{12 - k}}}.as_count()") for k in range(3, -1, -1)],
      [fm(f"default_zero(r{k})", LEFT[k]) for k in range(3, -1, -1)])])),
  stacked_bars(ts("Feedback task failures by remaining attempts", [(
      [mq(f"a{k}", f"sum:langsmith_ingest_task_failures.count{{{F},{FB_BATCH},attempt:{12 - k}}}.as_count()") for k in range(3, -1, -1)]
      + [mq(f"b{k}", f"sum:langsmith_ingest_task_failures.count{{{F},{FB_MUT},attempt:{25 - k}}}.as_count()") for k in range(3, -1, -1)],
      [fm(f"default_zero(a{k}) + default_zero(b{k})", LEFT[k]) for k in range(3, -1, -1)])])),
  ts("Runs dropped by project trace limit", [([mq("q1", f"sum:langsmith_runs_dropped_per_project_limit.count{{{F}}} by {{reason}}.as_count()")],
                                              [fm("q1")])], display="bars"),
 ], cols=3, h=3, note_h=2)

# ---------------- LangSmith ingestion ----------------
INGEST_PATH = ["*platform-backend*", "*ingest-queue*"]
ingestion = group("LangSmith ingestion (platform backend and ingest queue)", "purple",
 "The platform backend receives runs and puts them in Redis queues. Ingest queue workers take the tasks and write the runs to SmithDB. "
 "A backlog grows here before data expires: run data in Redis expires after 6 hours by default (Helm value `config.settings.redisRunsExpirySeconds`). "
 "If **Queue wait** increases and **Store write** stays stable, add ingest queue workers. If Store write increases, examine the SmithDB ingestion section.", [
  ts("Oldest waiting task by queue", [([mq("q1", f"max:langsmith_asynq_queue_latency_seconds{{{F}}} by {{queue}}")],
                                       [fm("top(q1, 8, 'max', 'desc')", unit="second")])],
     markers=[marker(600, "10 min warning"), marker(1800, "30 min critical", "error dashed")]),
  ts("Ingestion queue: pending vs retry", [([mq("q1", f"max:langsmith_asynq_ingestion_queue_pending{{{F}}}"),
                                             mq("q2", f"max:langsmith_asynq_ingestion_queue_retry{{{F}}}")],
                                            [fm("q1", "Pending"), fm("q2", "Retry")])],
     markers=[marker(100, "Retry 100 warning"), marker(1000, "Retry 1,000 critical", "error dashed")]),
  ts("Feedback queue: pending vs retry", [([mq("q1", f"max:langsmith_asynq_feedback_queue_pending{{{F}}}"),
                                            mq("q2", f"max:langsmith_asynq_feedback_queue_retry{{{F}}}")],
                                           [fm("q1", "Pending"), fm("q2", "Retry")])]),
  ts("End-to-end ingestion latency p95", [([mq("q1", f"p95:langsmith_ingestion_e2e_latency_seconds{{{F},store:smithdb}}")],
                                           [fm("q1", "End-to-end latency p95", "second")])]),
  ts("Queue wait vs store write p95", [([mq("q1", f"p95:langsmith_ingestion_api_to_worker_latency_seconds{{{F},store:smithdb}}"),
                                         mq("q2", f"p95:langsmith_ingestion_worker_to_store_latency_seconds{{{F},store:smithdb}}")],
                                        [fm("q1", "Queue wait (API to worker)", "second"), fm("q2", "Store write (worker to SmithDB)", "second")])]),
 ], infra=[(INFRA_HDR, resources("Ingest path", INGEST_PATH))], cols=3, h=3, note_h=1)

# ---------------- SmithDB ingestion ----------------
smithdb_ingestion = group("SmithDB ingestion", "violet",
 "SmithDB ingestion keeps runs in memory for a short time. Then it writes them to object storage as segments (data files), "
 "and records the metadata of each segment in the metastore. If batch latency is high, examine the Object storage and SmithDB metastore sections.", [
  ts("SmithDB batch latency and flush failures", [([mq("q3", f"p50:smithdb.ingest_batch_latency{{{F}}}"),
                                                    mq("q1", f"p99:smithdb.ingest_batch_latency{{{F}}}")],
                                                   [fm("q3", "Batch latency p50", "second"), fm("q1", "Batch latency p99", "second")], "line"),
                                                      ([mq("q2", f"sum:smithdb.ingest_flush_count.count{{{F},status:failure}}.as_count()")],
                                                       [fm("default_zero(q2)", "Flush failures")], "line", True, {"palette": "orange"})],
     markers=[marker(1.6, "p50 1.6 s warning"), marker(2, "p50 2 s critical", "error dashed")]),
  ts("SmithDB write error rate", [([mq("e", f"sum:smithdb.server_requests_duration.count{{{F},{WRITES},!status:0}}.as_count()"),
                                    mq("a", f"sum:smithdb.server_requests_duration.count{{{F},{WRITES}}}.as_count()")],
                                   [fm("100 * default_zero(e) / a", "Failed write calls, %", "percent")])],
     markers=[marker(1, "1% warning"), marker(5, "5% critical", "error dashed")]),
 ], infra=[(INFRA_HDR, resources("SmithDB ingestion", ["*smithdb-ingestion*"], memory=True))], cols=3, h=3, note_h=1)

# ---------------- Query ----------------
query = group("SmithDB query", "blue",
 "The SmithDB query pools serve the reads of the UI, the API, and automations. The mutations pool also writes feedback and deletes runs. "
 "Rejected queries fail for users. An admission rejection means that a query pod is out of memory. "
 "A fanout rejection means that compaction is late, or that the time range is too wide. A fanout that increases shows early that compaction is late. "
 "Each pool (query, stats-query, run-rules, mutations) scales independently.", [
  ts("Query latency p95 by pool", [([mq("q1", f"p95:smithdb.server_requests_duration{{{F},{READS}}} by {{kube_deployment}}")],
                                    [fm("q1", unit="second")])],
     markers=[marker(10, "10 s warning"), marker(20, "20 s critical", "error dashed")]),
  ts("Query error rate by pool", [([mq("q1", f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/*,{SERVER_ERR}}} by {{kube_deployment}}.as_count()"),
                                    mq("q2", f"sum:smithdb.server_requests_duration.count{{{F},path:/query.queryservice/*}} by {{kube_deployment}}.as_count()")],
                                   [fm("100 * default_zero(q1) / q2", unit="percent")])],
     markers=[marker(5, "5% warning"), marker(10, "10% critical", "error dashed")]),
  ts("Failed queries by cause", [([mq("q1", f"sum:smithdb.query_admission_queue_rejections.count{{{F}}}.as_count()"),
                                   mq("q2", f"sum:smithdb.query_fanout_limit_exceeded.count{{{F}}}.as_count()"),
                                   mq("q3", f"sum:smithdb.operation_memory_limit_exceeded.count{{{F}}}.as_count()")],
                                  [fm("q1", "Admission queue full"), fm("q2", "Fanout limit"), fm("q3", "Operation memory limit")])], display="bars"),
  ts("Admission queue length by pool", [([mq("q1", f"max:smithdb.query_admission_queue_length{{{F}}} by {{kube_deployment}}")], [fm("q1")])]),
  ts("Scan fanout p99", [([mq("q1", f"p99:smithdb.query_fanout_partitions{{{F}}}")], [fm("q1", "Scan partitions per query p99")])],
     markers=[marker(10000, "Rejection limit", "error dashed")]),
 ], infra=[(INFRA_HDR, resources("Query pools", ["*smithdb*query*", "*smithdb-run-rules*", "*smithdb-mutations*"], memory=True))], cols=3, h=3, note_h=1)

# ---------------- Compaction ----------------
compaction = group("SmithDB compaction", "orange",
 "Compaction merges small segments into larger segments, and applies deletes and retention. If compaction is late, queries become slower and storage grows. "
 "If running jobs stay at 0 while jobs are pending, compaction has stopped. If pending jobs stay high for hours, there are too few workers.", [
  ts("Compaction jobs: pending vs running", [([mq("q1", f"sum:smithdb.compaction_queue_job_count{{{F},status:pending}}"),
                                   mq("q2", f"sum:smithdb.compaction_worker_running_tasks{{{F}}}")],
                                  [fm("q1", "Pending"), fm("q2", "Running")])],
     markers=[marker(1000, "Pending 1,000 critical (2 h)", "error dashed")]),
  ts("Compaction failure rate by job kind", [([mq("q1", f"sum:smithdb.compaction_job_completion.count{{{F},job_kind:*_compaction,status:failure}} by {{job_kind}}.as_count()"),
                                    mq("q2", f"sum:smithdb.compaction_job_completion.count{{{F},job_kind:*_compaction}} by {{job_kind}}.as_count()")],
                                   [fm("100 * default_zero(q1) / q2", unit="percent")])],
     markers=[marker(20, "20% warning"), marker(50, "50% critical", "error dashed")]),
 ], infra=[("#### Infrastructure: compaction workers\nKubernetes signals of the worker pods: CPU use and throttling, memory use, restarts and OOM kills, and replicas.",
              resources("Compaction workers", ["*smithdb-compaction-worker*"], memory=True))], cols=3, h=3, note_h=1)
# no block for the compaction scheduler: one small pod; the pods and restarts tiles (Alerts 12, 13) and Alert 11 cover it

# ---------------- SmithDB cluster manager ----------------
clustermgr = group("SmithDB cluster manager", "gray",
 "The cluster manager sends the runs of one project to the same ingestion pod, and the queries of one workspace to the same query pod. "
 "If it is not available, requests go to any pod. Nothing fails, but load increases.",
 [], infra=[(INFRA_HDR, resources("Cluster manager", ["*smithdb-cluster*manager*"], hpa=False))], cols=4, h=3, note_h=1)

# ---------------- Redis ----------------
redis = group("Redis", "yellow",
 "Redis holds the ingestion queues and 6 hours of run data. The expected `maxmemory-policy` is `volatile-lru`: when memory reaches `maxmemory`, Redis evicts keys that have an expiry time, such as run data, and runs can be lost. "
 "Select your Redis with the **redis** variable, for example `cluster_id:<name>` (Memorystore for Redis Cluster), `cacheclusterid:<node>` (ElastiCache), `instance_id:<id>` (Memorystore), or `redis_host:<host>` (Datadog Redis integration).", [
  ts("Redis memory, % of limit", [([mq("u", f"max:redis.mem.used{{{REDIS_AGENT}}} by {{redis_host}}"),
                                    mq("x", f"max:redis.mem.maxmemory{{{REDIS_AGENT}}} by {{redis_host}}"),
                                    mq("q1", f"max:aws.elasticache.database_memory_usage_percentage{{{EC}}} by {{cacheclusterid}}"),
                                    mq("q2", f"max:gcp.redis.stats.memory.usage_ratio{{{MS_MEM}}} by {{instance_id}}"),
                                    mq("q3", f"max:gcp.redis.cluster.memory.maximum_utilization{{{MSC}}} by {{cluster_id}}")],
                                   [fm("100 * u / x", "Redis integration (used / maxmemory)", "percent"), fm("q1", "ElastiCache", "percent"),
                                    fm("100 * q2", "Memorystore", "percent"), fm("100 * q3", "Memorystore Cluster (fullest node)", "percent")])],
     markers=[marker(80, "80% warning"), marker(90, "90% critical", "error dashed")]),
  ts("Redis CPU", [([mq("q2", f"max:aws.elasticache.engine_cpuutilization{{{EC}}}"),
                     mq("q3", f"sum:gcp.redis.stats.cpu_utilization{{{MS_MEM},relationship:parent}} by {{instance_id}}"),
                     mq("q4", f"max:gcp.redis.cluster.cpu.maximum_utilization{{{MSC}}} by {{cluster_id}}")],
                    [fm("q2", "ElastiCache engine, %", "percent"),
                     fm("100 * q3", "Memorystore, % of one core", "percent"), fm("100 * q4", "Memorystore Cluster, % of node CPU (busiest node)", "percent")])],
     markers=[marker(90, "90% warning")]),
  ts("LangSmith Redis client errors", [([mq("q1", f"sum:langsmith_redis_errors.count{{{F},error_type IN (timeout,network,err)}} by {{error_type}}.as_count()")],
                                        [fm("q1")])], display="bars"),
 ], cols=3, h=3, note_h=1)  # external dependency: no Service metrics / Infrastructure split

# ---------------- SmithDB metastore ----------------
MS_HOST = MS_RDS = MS_GCP = DB
pg = group("SmithDB metastore (PostgreSQL)", "pink",
 "The metastore records the metadata of every segment that SmithDB writes, and stores new feedback until compaction moves it. "
 "If it is slow, ingestion becomes slower. If connections or storage run out, SmithDB writes fail. "
 "Select your database with the **metastore** variable, "
 "for example `dbclusteridentifier:<name>` (Aurora), `dbinstanceidentifier:<name>` (RDS), `database_id:<project>:<name>` (Cloud SQL), `cluster_id:<name>` (AlloyDB), `name:<server>` (Azure Database for PostgreSQL), or `host:<host>` (Datadog PostgreSQL integration). "
 "On Google Cloud, the PostgreSQL integration does not add the `database_id` or `cluster_id` tag. "
 "Add the tag to the `tags` of the PostgreSQL check, so that the % of max_connections line and the Metastore connections, % of max tile also show data.", [
  ts("Metastore connections", [([mq("q1", f"max:postgresql.percent_usage_connections{{{MS_HOST}}} by {{host}}")],
                      [fm("100 * q1", "% of max_connections", "percent")], "line"),
                     ([mq("q2", f"max:aws.rds.database_connections{{{MS_RDS}}} by {{dbinstanceidentifier}}"),
                       mq("q3", f"max:gcp.cloudsql.database.postgresql.num_backends{{{MS_GCP}}} by {{database_id}}"),
                       mq("q4", f"max:gcp.alloydb.instance.postgres.total_connections{{{MS_GCP}}} by {{instance_id}}"),
                       mq("q5", f"max:azure.dbforpostgresql_flexibleservers.active_connections{{{DB}}} by {{name}}")],
                      [fm("q2", "RDS connections"), fm("q3", "Cloud SQL connections"), fm("q4", "AlloyDB connections"),
                       fm("q5", "Azure connections")], "line", True, {"palette": "orange"})],
     markers=[marker(80, "80% warning"), marker(90, "90% critical", "error dashed")]),
  ts("Metastore CPU", [([mq("q1", f"max:aws.rds.cpuutilization{{{MS_RDS}}} by {{dbinstanceidentifier}}"),
               mq("q2", f"max:gcp.cloudsql.database.cpu.utilization{{{MS_GCP}}} by {{database_id}}"),
               mq("q3", f"max:gcp.alloydb.instance.cpu.maximum_utilization{{{MS_GCP}}} by {{instance_id}}"),
               mq("q4", f"max:azure.dbforpostgresql_flexibleservers.cpu_percent{{{DB}}} by {{name}}")],
              # AlloyDB reports a fraction, although its metadata says 0-100; Azure reports 0-100
              [fm("q1", "RDS CPU", "percent"), fm("100 * q2", "Cloud SQL CPU", "percent"), fm("100 * q3", "AlloyDB CPU (busiest node)", "percent"),
               fm("q4", "Azure CPU", "percent")])],
     markers=[marker(60, "60% warning"), marker(80, "80% critical", "error dashed")]),
  ts("Metastore memory", [([mq("q1", f"min:aws.rds.freeable_memory{{{MS_RDS}}} by {{dbinstanceidentifier}}"),
                  mq("q3", f"min:gcp.alloydb.instance.memory.min_available_memory{{{MS_GCP}}} by {{instance_id}}")],
                 [fm("q1", "RDS freeable memory", "byte"), fm("q3", "AlloyDB available memory (lowest node)", "byte")], "line"),
                ([mq("q2", f"max:gcp.cloudsql.database.memory.utilization{{{MS_GCP}}} by {{database_id}}")],
                 [fm("100 * q2", "Cloud SQL memory used", "percent")], "line", True, {"palette": "orange"}),
                ([mq("q4", f"max:azure.dbforpostgresql_flexibleservers.memory_percent{{{DB}}} by {{name}}")],
                 [fm("q4", "Azure memory used", "percent")], "line", True, {"palette": "orange"})]),
  ts("Metastore storage", [([mq("q2", f"max:gcp.cloudsql.database.disk.utilization{{{MS_GCP}}} by {{database_id}}")],
                  [fm("100 * q2", "Cloud SQL disk used", "percent")], "line"),
                 ([mq("q6", f"max:azure.dbforpostgresql_flexibleservers.storage_percent{{{DB}}} by {{name}}")],
                  [fm("q6", "Azure storage used", "percent")], "line"),
                 ([mq("q1", f"min:aws.rds.free_storage_space{{{MS_RDS}}} by {{dbinstanceidentifier}}"),
                   mq("q3", f"min:aws.rds.free_local_storage{{{MS_RDS}}} by {{dbinstanceidentifier}}"),
                   mq("q4", f"max:aws.rds.volume_bytes_used{{{DB}}} by {{dbclusteridentifier}}"),
                   mq("q5", f"max:gcp.alloydb.cluster.storage.usage{{{MS_GCP}}} by {{cluster_id}}")],
                  [fm("q1", "RDS free storage", "byte"), fm("q3", "Aurora free local storage", "byte"),
                   fm("q4", "Aurora cluster volume used", "byte"), fm("q5", "AlloyDB storage used", "byte")], "line", True, {"palette": "orange"})],
     markers=[marker(85, "85% critical", "error dashed")]),
 ], cols=3, h=3, note_h=2)  # external dependency: no Service metrics / Infrastructure split

# ---------------- Object storage ----------------
objs = group("Object storage", "vivid_blue",
 "Durable storage for SmithDB. Put errors make flushes fail, and tasks retry. Get errors make queries fail. "
 "A low, steady rate of get errors can be normal. Act on changes.", [
  ts("Object storage error rate by operation", [([mq("q1", f"sum:smithdb.object_store_op_duration.count{{{F},result:error}} by {{op}}.as_count()"),
                                   mq("q2", f"sum:smithdb.object_store_op_duration.count{{{F}}} by {{op}}.as_count()")],
                                  [fm("100 * default_zero(q1) / q2", unit="percent")])]),
  ts("Object storage latency p99 by operation", [([mq("q1", f"p99:smithdb.object_store_op_duration{{{F}}} by {{op}}")], [fm("q1", unit="second")])]),
 ], cols=3, h=3, note_h=1)

OBS_DOCS = "https://docs.langchain.com/langsmith/self-host-observability-dashboards"
VERSION = "2026-11-25"  # change for every release of the dashboard file
header = note(
 "## LangSmith self-hosted health\n"
 f"This dashboard answers one question: **are all components healthy?** It is for SmithDB in cluster mode (`smithdb.topology: cluster`, the default). "
 f"**Version {VERSION}.** To update, import the newest version into this dashboard (Configure, Import dashboard JSON).\n\n"
 "**Use it.** Select your installation with **env**, **cluster**, and **namespace**. Then select your resources with **redis** and **metastore**. "
 "Each takes one tag of the resource, for example `cluster_id:<name>` for Memorystore for Redis Cluster, `cacheclusterid:<node>` for ElastiCache, "
 "`dbclusteridentifier:<name>` for Aurora, or `database_id:<project>:<name>` for Cloud SQL. "
 "The lines of the other cloud providers then stay empty, and resources of other applications are not shown. Start with the tiles at the top. **Load** shows the work that comes in. "
 "**Health** turns yellow or red when an area needs attention. Open the section that the tile names. Each component section shows **Service metrics** first, "
 "and **Infrastructure** below. The info icon of each chart tells what it measures, why it matters, what to do, and which data it needs. Dashed lines mark thresholds: yellow for a warning, red for critical or a hard limit.\n\n"
 f"**Collect the data** ([guide]({OBS_DOCS})). SmithDB metrics are queried under the `smithdb.` prefix. Configure your collector to match. `langsmith_*` metrics carry no prefix. "
 "Optional: one line of *Failed queries by cause* uses a SmithDB metric that the Helm chart does not export by default. "
 "To fill it, set `SMITHDB_<COMPONENT>__METRICS__MODE` to `all`, for example in `smithdb.commonEnv`. Its tooltip says so. "
 "The example configuration also collects the LangSmith metrics that this dashboard needs, from the platform backend and the ingest queue. "
 "If you use your own configuration, add them to the OpenMetrics `metrics` list of these services. The tooltips name them. "
 "Infrastructure charts need the Kubernetes integration. Redis and metastore charts need the Redis, PostgreSQL, or cloud provider integrations.\n\n"
 "**Alerts and diagnosis.** [Recommended SmithDB alerts](https://docs.langchain.com/langsmith/self-host-smithdb-alerts) gives the monitor conditions. Each Health tile and each section links to its alerts. "
 "[Diagnose common SmithDB issues](https://docs.langchain.com/langsmith/self-host-smithdb-common-issues) explains causes and fixes.\n\n"
 "**How SmithDB works.** The [SmithDB guide](https://docs.langchain.com/langsmith/self-host-smithdb) explains the components and how data moves between them.")
header["layout"] = {"x": 0, "y": 0, "width": 12, "height": 5}

widgets = [header, overview, workload, dataloss, ingestion, smithdb_ingestion, query, compaction, clustermgr, redis, pg, objs]
# section -> alerts on the Recommended SmithDB alerts page; appended to the intro note of the section
ALERT_SLUGS = {1: "runs-are-lost", 2: "feedback-is-lost", 3: "the-ingestion-backlog-gets-old", 4: "redis-is-almost-full",
               5: "writes-fail", 6: "queries-fail", 7: "the-metastore-is-saturated", 8: "writes-are-slow", 9: "queries-are-slow",
               10: "compaction-falls-behind", 11: "compaction-stops-or-fails", 12: "a-component-has-no-pods",
               13: "pods-restart-often", 14: "smithdb-panics"}
SECTION_ALERTS = {"Data loss": [1, 2], "LangSmith ingestion (platform backend and ingest queue)": [3, 13],
                  "SmithDB ingestion": [5, 8, 12, 13], "SmithDB query": [6, 9, 12, 13], "SmithDB compaction": [10, 11, 12, 13],
                  "SmithDB cluster manager": [12, 13], "Redis": [1, 4], "SmithDB metastore (PostgreSQL)": [7]}
assert set(SECTION_ALERTS) <= {g["definition"].get("title") for g in widgets}, "SECTION_ALERTS names an unknown section"
for g in widgets:
    nums = SECTION_ALERTS.get(g["definition"].get("title"))
    if not nums: continue
    intro = next(w["definition"] for w in g["definition"]["widgets"] if w["definition"]["type"] == "note")
    intro["content"] += " **Alerts:** " + ", ".join(f"[{n}]({ALERTS}#{n}-{ALERT_SLUGS[n]})" for n in nums) + "."
y = 5
for g in widgets[1:]:
    rows = max(w["layout"]["y"] + w["layout"]["height"] for w in g["definition"]["widgets"])
    g["layout"] = {"x": 0, "y": y, "width": 12, "height": rows + 1}
    y += rows + 1

# Metrics that the example Datadog configuration in the Helm chart collects from LangSmith.
LS_DEFAULT = set()  # the example Datadog configuration collects every LangSmith metric that this dashboard uses
FAMILIES = [  # (prefixes, name); members of one family are alternatives
    ({"redis.": "the Redis integration", "aws.elasticache.": "the ElastiCache integration", "gcp.redis.": "the Memorystore integration",
      "gcp.redis.cluster.": "the Memorystore for Redis Cluster integration"}),
    ({"postgresql.": "the PostgreSQL integration", "aws.rds.": "the RDS integration", "gcp.cloudsql.": "the Cloud SQL integration",
      "gcp.alloydb.": "the AlloyDB metrics of the Google Cloud integration",
      "azure.dbforpostgresql_flexibleservers.": "the Azure Database for PostgreSQL integration"}),
    ({"aws.s3.": "the AWS integration (S3 metrics)", "gcp.storage.": "the GCP integration (Cloud Storage metrics)"}),
    ({"kubernetes.": "the Datadog Kubernetes integration (kubelet and kube-state-metrics)", "kubernetes_state.": "the Datadog Kubernetes integration (kubelet and kube-state-metrics)"}),
]
# SmithDB metrics that are not in the critical export set (smithdb-common/src/metrics_export.rs)
NON_CRITICAL = {"ingest_payload_bytes", "metastore_batch_flush_duration", "operation_memory_limit_exceeded",
                "query_execution_object_store_bytes", "query_segments_accessed_bytes", "query_time_range_seconds"}
REQ_OVERRIDE = {
  "Redis CPU": "The ElastiCache, Memorystore, or Memorystore for Redis Cluster integration.",
  "SmithDB panics": "SmithDB log collection. With JSON logs, parse them so that `backtrace` is a log attribute. Plain-text logs match on `thread panicked`.",
  "Container restarts": "The Datadog Kubernetes integration (kubelet and kube-state-metrics). This tile shows 0, not No data, if the integration is missing.",
}
def fmt_value(v, u):
    """Threshold for the tile text: minutes from 60 s up, thousands separators."""
    if u == "second" and v >= 60:
        m = v / 60
        return f"{m:,g} minute" + ("" if m == 1 else "s")
    return f"{v:,g}" + {"percent": "%", "second": " s"}.get(u, "")
def tile_colors(defn):
    reqs = defn.get("requests", [])
    cond = (reqs[0].get("conditional_formats") or (reqs[0].get("formulas") or [{}])[0].get("conditional_formats")) if reqs else None
    if not cond: return ""
    f = (reqs[0].get("formulas") or [{}])[0]
    u = f.get("number_format", {}).get("unit", {}).get("unit_name")
    vals = {c["palette"]: c["value"] for c in cond}
    if "white_on_yellow" in vals and "white_on_red" not in vals:
        return "Green: 0. Yellow: above 0."
    if "white_on_yellow" in vals:
        y, r = fmt_value(vals["white_on_yellow"], u), fmt_value(vals["white_on_red"], u)
        return f"Green: below {y}. Yellow: {y} or more. Red: {r} or more."
    if cond[0]["comparator"] == "<":
        v = fmt_value(cond[0]["value"], u)
        return f"Red: below {v}. Green: {v} or more."
    if cond[0]["comparator"] == ">=":
        v = fmt_value(cond[0]["value"], u)
        return f"Green: below {v}. Red: {v} or more."
    return "Green: 0. Red: above 0."
def requirements(defn):
    queries = []
    for r in defn.get("requests", []):
        if "q" in r: queries.append(r["q"])
        for q in r.get("queries", []):
            queries.append("LOGS" if q["data_source"] == "logs" else q["query"])
    names = set(re.findall(r"[a-z0-9]+:([a-zA-Z_][a-zA-Z0-9_.]*)\{", " ".join(queries)))
    parts = []
    ls = sorted({re.sub(r"\.count$", "", n) for n in names if n.startswith("langsmith_")} - LS_DEFAULT)
    if ls:
        parts.append("LangSmith metrics from the platform backend or the ingest queue (" + ", ".join(f"`{n}`" for n in ls) +
                     "). The example Datadog configuration collects them")
    for fam in FAMILIES:
        found = []
        for pre, label in fam.items():
            longer = [p2 for p2 in fam if p2 != pre and p2.startswith(pre)]
            if any(n.startswith(pre) and not any(n.startswith(p2) for p2 in longer) for n in names) and label not in found: found.append(label)
        if len(found) == 1: parts.append(found[0])
        elif found: parts.append("one of " + ", ".join(found[:-1]) + ", or " + found[-1])
    not_critical = sorted({re.sub(r"\.(count|sum)$", "", n).removeprefix("smithdb.") for n in names if n.startswith("smithdb.")} & NON_CRITICAL)
    if not_critical:
        parts.append("SmithDB metrics mode `all` for " + ", ".join(f"`{n}`" for n in not_critical) +
                     ". The Helm chart sets `SMITHDB_<COMPONENT>__METRICS__MODE` to `critical` by default. Set it to `all`, for example in `smithdb.commonEnv`")
    if "LOGS" in queries: parts.append("log collection from the ingest queue workers. Parse the JSON logs, so that `job_attempts` is a log attribute")
    if defn.get("title") in REQ_OVERRIDE: return REQ_OVERRIDE[defn["title"]]
    return " ".join(x[0].upper() + x[1:] + "." for x in parts)

TOOLTIPS = json.loads((HERE / "datadog_tooltips.json").read_text())
TILE_TYPES = ("query_value", "toplist")
def tooltip_key(d):
    """A tile with the same title as its chart has its own entry, "tile:<title>"."""
    k = f"tile:{d['title']}"
    return k if d["type"] in TILE_TYPES and k in TOOLTIPS else d["title"]
missing, used = [], set()
for g in widgets[1:]:
    for w in g["definition"]["widgets"]:
        d = w["definition"]
        if d["type"] == "note": continue
        key = tooltip_key(d); used.add(key)
        t = TOOLTIPS.get(key)
        if not t: missing.append(key); continue
        d["description"] = f"**What it measures:** {t[0]}\n\n**Why it matters:** {t[1]}\n\n**What to do:** {t[2]}"
        if d["type"] in TILE_TYPES and d["title"] in TILE_INFO:
            sec, mon = TILE_INFO[d["title"]]
            d["description"] += f"\n\n**Tile:** {tile_colors(d)} Open {sec}. {mon}"
        req = requirements(d)
        if req: d["description"] += f"\n\n**Requires:** {req}"
if missing: sys.exit(f"missing tooltips: {missing}")
unused = set(TOOLTIPS) - used
if unused: sys.exit(f"unused tooltips: {sorted(unused)}")

dash = {
  "title": "LangSmith Self-Hosted Health",
  "description": f"Operator view of a self-hosted LangSmith installation with SmithDB: data loss, backlogs, failures, and infrastructure saturation. Version {VERSION}.",
  "layout_type": "ordered", "reflow_type": "fixed",
  "template_variables": [
    {"name": "env", "prefix": "env", "default": "*", "available_values": []},
    {"name": "cluster", "prefix": "cluster_name", "default": "*", "available_values": []},
    {"name": "namespace", "prefix": "kube_namespace", "default": "*", "available_values": []},
    {"name": "redis", "prefix": None, "default": "redis:select-your-redis", "available_values": []},
    {"name": "metastore", "prefix": None, "default": "metastore:select-your-database", "available_values": []},
  ],
  "widgets": widgets,
}
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("--check", action="store_true", help="fail if datadog.json is not up to date")
parser.add_argument("--output", type=Path, default=OUT, help="where to write the dashboard (default: datadog.json)")
args = parser.parse_args()
text = json.dumps(dash, indent=2) + "\n"
if args.check:
    if not OUT.exists() or OUT.read_text() != text: sys.exit("Regenerate components/smithdb/datadog.json with build_datadog.py")
    sys.exit(0)
args.output.write_text(text)
n = sum(len(g["definition"].get("widgets", [])) for g in widgets[1:])
print(f"wrote {args.output} ({n} widgets in {len(widgets)-1} groups)")
