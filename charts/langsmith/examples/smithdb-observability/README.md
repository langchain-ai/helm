# SmithDB observability

Datadog and Grafana dashboards for SmithDB on self-hosted LangSmith. For what each metric means, see the [SmithDB metrics reference](https://docs.langchain.com/langsmith/self-host-smithdb-metrics).

| Stack | Dashboard | Values |
| --- | --- | --- |
| Datadog | `datadog-dashboard.json` | `datadog-values.yaml` (Autodiscovery annotations) |
| Prometheus and Grafana | `grafana-dashboard.json` | `prometheus-values.yaml` (scrape annotations) |

## Set up

1. Apply the values file for your stack with your existing values:

   ```bash
   helm upgrade langsmith langchain/langsmith --version <version> -n <namespace> -f values.yaml -f datadog-values.yaml
   ```

2. Import the dashboard:
   - **Datadog**: Create a dashboard, open its settings, select **Import dashboard JSON**, and select `datadog-dashboard.json`.
   - **Grafana**: Go to **Dashboards** > **New** > **Import**, upload `grafana-dashboard.json`, and select your Prometheus data source.

Both values files also scrape the LangSmith ingest queue (port 1989) and platform-backend (port 1986), which serve the `langsmith_*` metrics.

## Metric names

The Datadog dashboard expects the check settings in `datadog-values.yaml`:

- `namespace: smithdb` prefixes SmithDB metrics with `smithdb.`. LangSmith `langsmith_*` metrics have no prefix.
- `histogram_buckets_as_distributions` and `collect_counters_with_distributions` send histograms as distributions with `.count` and `.sum`.

The Grafana dashboard uses metric names as exposed on `/metrics`, and filters on a `namespace` label.

If you collect these metrics another way, names can differ. For Datadog, replace `smithdb.` in the dashboard JSON with your prefix before importing. The Datadog **Errors** group queries logs with `service:smithdb*`.
