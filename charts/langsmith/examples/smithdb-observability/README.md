# SmithDB observability has moved

Use the [LangSmith observability bundle](../langsmith-observability/README.md) for dashboard imports, collection settings, and update guidance. This directory retains only this signpost; its former JSON and YAML downloads have moved to the unified bundle.

| Download | New location |
| --- | --- |
| Unified Datadog dashboard | [datadog-dashboard.json](../langsmith-observability/datadog-dashboard.json) |
| Unified Grafana 13+ dashboard | [grafana-dashboard.json](../langsmith-observability/grafana-dashboard.json) |
| Standalone SmithDB Grafana dashboard (Classic format) | [components/smithdb/grafana.json](../langsmith-observability/components/smithdb/grafana.json) |
| Datadog collection values | [components/smithdb/datadog-values.yaml](../langsmith-observability/components/smithdb/datadog-values.yaml) |
| Prometheus collection values | [components/smithdb/prometheus-values.yaml](../langsmith-observability/components/smithdb/prometheus-values.yaml) |

Update bookmarks and automation that use the old file URLs. This README does not redirect file downloads. Dashboards already imported into your monitoring instance are unaffected.

Download these assets from the repository, not the Helm chart archive. For metric meanings, see the [SmithDB metrics reference](https://docs.langchain.com/langsmith/self-host-smithdb-metrics).
