# SmithDB observability

Datadog dashboard for SmithDB on self-hosted LangSmith. For what each metric means, see the [SmithDB metrics reference](https://docs.langchain.com/langsmith/self-host-smithdb-metrics).

- `datadog-dashboard.json`: the dashboard.
- `datadog-values.yaml`: Autodiscovery annotations that collect the metrics it queries.

## Set up

1. Apply the annotations with your existing values:

   ```bash
   helm upgrade langsmith langchain/langsmith --version <version> -n <namespace> -f values.yaml -f datadog-values.yaml
   ```

2. In Datadog, create a dashboard, open its settings, select **Import dashboard JSON**, and select `datadog-dashboard.json`.

## Metric names

The dashboard expects the check settings in `datadog-values.yaml`:

- `namespace: smithdb` prefixes SmithDB metrics with `smithdb.`. LangSmith `langsmith_*` metrics have no prefix.
- `histogram_buckets_as_distributions` and `collect_counters_with_distributions` send histograms as distributions with `.count` and `.sum`.

If you collect these metrics another way, names can differ. To use another prefix, replace `smithdb.` in the dashboard JSON before importing.

The **Errors** group queries logs with `service:smithdb*`.
