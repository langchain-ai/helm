# LangSmith observability

Import one LangSmith Self-Hosted dashboard into your own Datadog or Grafana instance. Component tabs keep operational views together without requiring every telemetry integration. The dashboard contains queries, not telemetry or access to hosted monitoring. Filters are not access controls.

## Downloads

Download these files from the repository, not the Helm chart archive. The unified example bundle is excluded from chart packaging so dashboard source and JSON do not inflate Helm's release Secret. Generation and query checks still run against the repository files.

| Platform | Dashboard | Requirement |
| --- | --- | --- |
| Datadog | [datadog-dashboard.json](datadog-dashboard.json) | Datadog dashboard tabs and the component's collection settings |
| Grafana | [grafana-dashboard.json](grafana-dashboard.json) | Grafana 13 or later, with a Prometheus data source; V2 dashboard resource format |
| Grafana (SmithDB only) | [components/smithdb/grafana.json](components/smithdb/grafana.json) | Existing standalone Classic-format dashboard for installations without native tabs |

The SmithDB tab covers ingestion, queries, compaction, storage, memory, and the LangSmith ingestion path. For metric definitions, see the [SmithDB metrics reference](https://docs.langchain.com/langsmith/self-host-smithdb-metrics).

The Datadog Sandboxes tab adds host capacity, lifecycle, execution, resources, networking, health, and optional APM, JuiceFS, and cloud storage panels. See the [Sandbox collection guide](components/sandboxes/README.md). Both tabs share `env`, `cluster`, and `namespace`. Cluster queries retain their original tag keys: `cluster_name` for SmithDB and `kube_cluster_name` for Sandbox hosts and JuiceFS. Both use `kube_namespace` for namespace. APM uses only `env` and `api_service`; cloud panels use their bucket selectors. Select one Sandbox cluster and namespace for pool counts. Grafana Sandbox coverage is not included in this layer.

## Collect component metrics

Apply collection settings only for the components you operate. These examples do not install Datadog, Prometheus, Grafana, or the monitored components. Merge with your existing annotations and scrape jobs to avoid duplicate collection; schedule any pod rollout through your normal release process.

| Component | Datadog | Prometheus |
| --- | --- | --- |
| SmithDB | [Autodiscovery values](components/smithdb/datadog-values.yaml) | [Scrape annotations](components/smithdb/prometheus-values.yaml) |
| Sandboxes | [Host values](components/sandboxes/datadog-values.yaml), or [host and JuiceFS values](components/sandboxes/datadog-juicefs-values.yaml) | See component availability above. |

SmithDB's examples also collect LangSmith ingest-queue metrics on port `1989` and platform-backend queue metrics on port `1986`. Keep metrics listeners private. Prometheus must already discover the supplied annotations and attach the `namespace` label. The Datadog example uses the `smithdb.` metric prefix; the Grafana queries use raw Prometheus names. Datadog's SmithDB error panels additionally require logs matching `service:smithdb*`.

## Import and filter

- **Datadog:** Import the JSON into a new dashboard using its JSON import action. Select `env`, `cluster`, and `namespace`. The cluster picker discovers values from `cluster_name`; queries use `$cluster.value` with their component's explicit tag key. You can change the picker's tag key without retagging metrics or changing those query keys, provided the selected cluster names match. Namespace uses `kube_namespace`.
- **Grafana:** Import the V2 resource JSON into Grafana 13 or later. Select the Prometheus data source and namespace. Groupings and panels live inside the SmithDB tab.

Missing data can indicate absent collection, incompatible metric names, or filter mismatches. Check scraper health and a continuously emitted metric before interpreting an empty error panel.

## Update an existing installation

Back up the existing dashboard before importing a replacement. Datadog JSON import replaces dashboard content, including local customizations. Grafana's unified dashboard has a different UID from the legacy SmithDB dashboard, so importing it does not intentionally replace the legacy dashboard. Review the import destination before saving.

The former `smithdb-observability/` directory now contains only a [signpost to this bundle](../smithdb-observability/README.md). Its duplicate JSON and YAML files have been removed; update bookmarks and automation to the new paths. The unchanged [standalone SmithDB Grafana JSON](components/smithdb/grafana.json) remains available in Classic format for installations without native tabs. This file contains SmithDB panels only. The deprecated `langsmith-observability` Helm chart is unrelated to this example bundle and is not required.

## Maintain the definitions

Edit component sources under `components/`. `generate_dashboards.py` produces only the two unified dashboard JSON files in this directory. Widget and tab identifiers are generated locally and deterministically; they are not copied from a Datadog account. The generator runs offline with Python's standard library and accepts no dashboard export, URL, or credentials.

From the repository root:

```bash
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py --check
python3 -m unittest discover -s charts/langsmith/examples/langsmith-observability -p 'test_*.py'
```

Tests verify metric queries and visualization settings survive composition, tab references resolve, incompatible filter definitions are rejected, and generation is self-contained within the bundle.
