import argparse
from copy import deepcopy
import itertools
import json
from pathlib import Path
import uuid


ROOT = Path(__file__).resolve().parent
TITLE = "LangSmith Self-Hosted"
DESCRIPTION = "Operational dashboards for your own LangSmith deployment. Each component requires its documented telemetry collection. Filters select data, not access rights."


def local_path(relative):
    path = (ROOT / relative).resolve()
    path.relative_to(ROOT.parent)
    return path


def load_source(component, backend):
    if component not in ("smithdb",) or backend not in ("datadog", "grafana"):
        raise ValueError("Unknown dashboard source")
    path = local_path(f"components/{component}/{backend}.json")
    if path.stat().st_size > 4_000_000:
        raise ValueError("Dashboard source exceeds size limit")
    return json.loads(path.read_text())


def merge_variables(existing, incoming):
    for variable in incoming:
        name = variable.get("name", variable.get("spec", {}).get("name"))
        previous = next(
            (
                item
                for item in existing
                if item.get("name", item.get("spec", {}).get("name")) == name
            ),
            None,
        )
        if previous is not None and previous != variable:
            raise ValueError(f"Conflicting template variable: {name}")
        if previous is None:
            existing.append(deepcopy(variable))


def assign_widget_ids(widgets, ids, depth=0):
    if depth > 4 or len(widgets) > 1000:
        raise ValueError("Unexpected widget structure")
    for widget in widgets:
        widget["id"] = next(ids)
        assign_widget_ids(widget["definition"].get("widgets", []), ids, depth + 1)


def datadog_dashboard(components):
    dashboard = {
        "title": TITLE,
        "description": DESCRIPTION,
        "layout_type": "ordered",
        "reflow_type": "fixed",
        "template_variables": [],
        "widgets": [],
        "tabs": [],
    }
    for index, (name, source) in enumerate(components):
        widgets = deepcopy(source["widgets"])
        assign_widget_ids(widgets, itertools.count((index + 1) * 10000))
        merge_variables(dashboard["template_variables"], source["template_variables"])
        dashboard["widgets"].extend(widgets)
        dashboard["tabs"].append(
            {
                "id": str(
                    uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        "https://github.com/langchain-ai/helm/langsmith-observability/"
                        + name.lower(),
                    )
                ),
                "name": name,
                "widget_ids": [item["id"] for item in widgets],
            }
        )
    return dashboard


def data_query(query, datasource):
    return {
        "kind": "DataQuery",
        "group": datasource.get("type", "prometheus"),
        "version": "v0",
        "datasource": {"name": datasource.get("uid", "${datasource}")},
        "spec": deepcopy(query),
    }


def grafana_variable(variable):
    hide = ("dontHide", "hideLabel", "hideVariable")[variable.get("hide", 0)]
    refresh = ("never", "onDashboardLoad", "onTimeRangeChanged")[
        variable.get("refresh", 0)
    ]
    spec = {
        "name": variable["name"],
        "current": deepcopy(variable.get("current") or {"text": "", "value": ""}),
        "label": variable.get("label", variable["name"]),
        "hide": hide,
        "skipUrlSync": variable.get("skipUrlSync", False),
    }
    if variable["type"] == "textbox":
        return {
            "kind": "TextVariable",
            "spec": {**spec, "query": variable.get("query", "")},
        }
    spec.update(
        {
            "refresh": refresh,
            "regex": variable.get("regex", ""),
            "options": deepcopy(variable.get("options", [])),
            "multi": variable.get("multi", False),
            "includeAll": variable.get("includeAll", False),
            "allowCustomValue": True,
        }
    )
    if "allValue" in variable:
        spec["allValue"] = variable["allValue"]
    if variable["type"] == "datasource":
        return {
            "kind": "DatasourceVariable",
            "spec": {**spec, "pluginId": variable["query"]},
        }
    if variable["type"] != "query":
        raise ValueError("Unsupported variable type: " + variable["type"])
    sorts = (
        "disabled",
        "alphabeticalAsc",
        "alphabeticalDesc",
        "numericalAsc",
        "numericalDesc",
        "alphabeticalCaseInsensitiveAsc",
        "alphabeticalCaseInsensitiveDesc",
        "naturalAsc",
        "naturalDesc",
    )
    query = variable["query"]
    if isinstance(query, str):
        query = {"query": query}
    spec.update(
        {
            "query": data_query(query, variable.get("datasource", {})),
            "definition": variable.get("definition", ""),
            "sort": sorts[variable.get("sort", 0)],
        }
    )
    return {"kind": "QueryVariable", "spec": spec}


def grafana_panel(panel, panel_id):
    allowed = {
        "type",
        "id",
        "title",
        "description",
        "datasource",
        "gridPos",
        "fieldConfig",
        "options",
        "targets",
        "transparent",
        "links",
        "pluginVersion",
        "transformations",
        "timeFrom",
        "timeShift",
        "hideTimeOverride",
        "interval",
        "maxDataPoints",
    }
    if set(panel) - allowed:
        raise ValueError(
            "Unsupported panel fields: " + str(sorted(set(panel) - allowed))
        )
    queries = []
    for target in panel.get("targets", []):
        query = {
            key: value
            for key, value in target.items()
            if key not in ("datasource", "hide", "refId")
        }
        queries.append(
            {
                "kind": "PanelQuery",
                "spec": {
                    "refId": target["refId"],
                    "hidden": target.get("hide", False),
                    "query": data_query(
                        query, target.get("datasource", panel.get("datasource", {}))
                    ),
                },
            }
        )
    transformations = [
        {"kind": item["id"], "spec": deepcopy(item)}
        for item in panel.get("transformations", [])
    ]
    options = {
        name: panel[name]
        for name in (
            "timeFrom",
            "timeShift",
            "hideTimeOverride",
            "interval",
            "maxDataPoints",
        )
        if name in panel
    }
    return {
        "kind": "Panel",
        "spec": {
            "id": panel_id,
            "title": panel.get("title", ""),
            "description": panel.get("description", ""),
            "links": deepcopy(panel.get("links", [])),
            "transparent": panel.get("transparent", False),
            "data": {
                "kind": "QueryGroup",
                "spec": {
                    "queries": queries,
                    "transformations": transformations,
                    "queryOptions": options,
                },
            },
            "vizConfig": {
                "kind": "VizConfig",
                "group": panel["type"],
                "version": panel.get("pluginVersion", ""),
                "spec": {
                    "options": deepcopy(panel.get("options", {})),
                    "fieldConfig": deepcopy(
                        panel.get("fieldConfig", {"defaults": {}, "overrides": []})
                    ),
                },
            },
        },
    }


def grafana_rows(source, name, elements, ids):
    rows = []
    current = None
    offset = 0
    for panel in source["panels"]:
        if panel["type"] == "row":
            if panel.get("panels"):
                raise ValueError("Nested Classic panels require an explicit migration")
            current = {
                "kind": "RowsLayoutRow",
                "spec": {
                    "title": panel.get("title", ""),
                    "collapse": panel.get("collapsed", False),
                    "layout": {"kind": "GridLayout", "spec": {"items": []}},
                },
            }
            rows.append(current)
            offset = panel["gridPos"]["y"] + panel["gridPos"]["h"]
            continue
        if current is None:
            current = {
                "kind": "RowsLayoutRow",
                "spec": {
                    "hideHeader": True,
                    "layout": {"kind": "GridLayout", "spec": {"items": []}},
                },
            }
            rows.append(current)
        panel_id = next(ids)
        key = name.lower() + "-" + str(panel_id)
        elements[key] = grafana_panel(panel, panel_id)
        pos = panel["gridPos"]
        current["spec"]["layout"]["spec"]["items"].append(
            {
                "kind": "GridLayoutItem",
                "spec": {
                    "x": pos["x"],
                    "y": max(0, pos["y"] - offset),
                    "width": pos["w"],
                    "height": pos["h"],
                    "element": {"kind": "ElementReference", "name": key},
                },
            }
        )
    return {"kind": "RowsLayout", "spec": {"rows": rows}}


def grafana_dashboard(components):
    spec = {
        "title": TITLE,
        "description": DESCRIPTION,
        "annotations": [],
        "cursorSync": "Crosshair",
        "editable": True,
        "elements": {},
        "layout": {"kind": "TabsLayout", "spec": {"tabs": []}},
        "links": [],
        "preload": False,
        "tags": ["langsmith"],
        "timeSettings": {
            "timezone": "browser",
            "from": "now-6h",
            "to": "now",
            "autoRefresh": "1m",
            "autoRefreshIntervals": ["30s", "1m", "5m", "15m", "1h"],
            "hideTimepicker": False,
            "fiscalYearStartMonth": 0,
        },
        "variables": [],
    }
    for index, (name, source) in enumerate(components):
        if source.get("annotations", {}).get("list") or source.get("links"):
            raise ValueError(
                "Annotations and dashboard links require an explicit migration"
            )
        merge_variables(
            spec["variables"],
            [grafana_variable(item) for item in source["templating"]["list"]],
        )
        layout = grafana_rows(
            source, name, spec["elements"], itertools.count((index + 1) * 10000)
        )
        spec["layout"]["spec"]["tabs"].append(
            {"kind": "TabsLayoutTab", "spec": {"title": name, "layout": layout}}
        )
    return {
        "apiVersion": "dashboard.grafana.app/v2beta1",
        "kind": "Dashboard",
        "metadata": {"name": "langsmith-self-hosted"},
        "spec": spec,
    }


def sandbox_datadog():
    from components.sandboxes.datadog import build_dashboard

    source = build_dashboard()

    def rename(value):
        if isinstance(value, dict):
            return {key: rename(item) for key, item in value.items()}
        if isinstance(value, list):
            return [rename(item) for item in value]
        if isinstance(value, str):
            return value.replace("$cluster", "$sandbox_cluster").replace(
                "$namespace", "$sandbox_namespace"
            )
        return value

    source["widgets"] = rename(source["widgets"])
    for variable in source["template_variables"]:
        if variable["name"] in ("cluster", "namespace"):
            variable["name"] = "sandbox_" + variable["name"]
    return source


def build_dashboards():
    return {
        "datadog-dashboard.json": datadog_dashboard(
            [
                ("SmithDB", load_source("smithdb", "datadog")),
                ("Sandboxes", sandbox_datadog()),
            ]
        ),
        "grafana-dashboard.json": grafana_dashboard(
            [("SmithDB", load_source("smithdb", "grafana"))]
        ),
    }


def artifacts():
    result = {
        local_path(name): json.dumps(value, indent=2) + "\n"
        for name, value in build_dashboards().items()
    }
    for backend in ("datadog", "grafana"):
        result[local_path(f"../smithdb-observability/{backend}-dashboard.json")] = (
            local_path(f"components/smithdb/{backend}.json").read_text()
        )
    for name in ("datadog-values.yaml", "prometheus-values.yaml"):
        result[local_path("../smithdb-observability/" + name)] = local_path(
            "components/smithdb/" + name
        ).read_text()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for path, text in artifacts().items():
        if args.check:
            if not path.exists() or path.read_text() != text:
                raise SystemExit(
                    "Regenerate dashboard artifacts: "
                    + str(path.relative_to(ROOT.parent))
                )
        else:
            path.write_text(text)


if __name__ == "__main__":
    main()
