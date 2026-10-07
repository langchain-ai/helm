# LangSmith observability

Import one LangSmith Self-Hosted dashboard into your own Datadog or Grafana instance. Component tabs keep operational views together without requiring every telemetry integration. The dashboard contains queries, not telemetry or access to hosted monitoring. Filters are not access controls.

## Downloads

Download these files from the repository, not the Helm chart archive. The unified example bundle is excluded from chart packaging so dashboard source and JSON do not inflate Helm's release Secret. Generation and query checks still run against the repository files.

| Platform | Dashboard | Requirement |
| --- | --- | --- |
| Datadog | [datadog-dashboard.json](datadog-dashboard.json) | Datadog dashboard tabs and the component's collection settings |
| Grafana | [grafana-dashboard.json](grafana-dashboard.json) | Grafana 13 or later, with a Prometheus data source; V2 dashboard resource format |

The SmithDB tab covers ingestion, queries, compaction, storage, memory, and the LangSmith ingestion path. For metric definitions, see the [SmithDB metrics reference](https://docs.langchain.com/langsmith/self-host-smithdb-metrics).

## Collect component metrics

Apply collection settings only for the components you operate. These examples do not install Datadog, Prometheus, Grafana, or the monitored components. Merge with your existing annotations and scrape jobs to avoid duplicate collection; schedule any pod rollout through your normal release process.

| Component | Datadog | Prometheus |
| --- | --- | --- |
| SmithDB | [Autodiscovery values](components/smithdb/datadog-values.yaml) | [Scrape annotations](components/smithdb/prometheus-values.yaml) |

SmithDB's examples also collect LangSmith ingest-queue metrics on port `1989` and platform-backend queue metrics on port `1986`. Keep metrics listeners private. Prometheus must already discover the supplied annotations and attach the `namespace` label. The Datadog example uses the `smithdb.` metric prefix; the Grafana queries use raw Prometheus names. Datadog's SmithDB error panels additionally require logs matching `service:smithdb*`.

## Import and filter

- **Datadog:** Import the JSON into a new dashboard using its JSON import action. Select `env`, `cluster`, and `namespace`. The SmithDB cluster filter uses the `cluster_name` tag; namespace uses `kube_namespace`. Configure your collection tags or adjust the filter prefixes to match your account.
- **Grafana:** Import the V2 resource JSON into Grafana 13 or later. Select the Prometheus data source and namespace. Groupings and panels live inside the SmithDB tab.

Missing data can indicate absent collection, incompatible metric names, or filter mismatches. Check scraper health and a continuously emitted metric before interpreting an empty error panel.

## Update an existing installation

Back up the existing dashboard before importing a replacement. Datadog JSON import replaces dashboard content, including local customizations. Grafana's unified dashboard has a different UID from the legacy SmithDB dashboard, so importing it does not intentionally replace the legacy dashboard. Review the import destination before saving.

The [legacy SmithDB downloads](../smithdb-observability/README.md) remain available with their existing contents and filenames. In particular, the Classic Grafana export remains available for installations that cannot use the new tabbed format. The deprecated `langsmith-observability` Helm chart is unrelated to this example bundle and is not required.

## Maintain the definitions

Edit component sources under `components/`. `generate_dashboards.py` composes the unified artifacts and refreshes legacy SmithDB compatibility files. Widget and tab identifiers are generated locally and deterministically; they are not copied from a Datadog account. The generator runs offline with Python's standard library and accepts no dashboard export, URL, or credentials.

From the repository root:

```bash
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py --check
python3 -m unittest discover -s charts/langsmith/examples/langsmith-observability -p 'test_*.py'
```

Tests verify metric queries and visualization settings survive composition, tab references resolve, incompatible filter definitions are rejected, and legacy downloads remain unchanged.
