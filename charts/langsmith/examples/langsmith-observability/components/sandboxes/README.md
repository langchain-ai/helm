# Sandbox observability

Import the [unified Datadog dashboard](../../datadog-dashboard.json) into the organization that receives your self-hosted telemetry, then open its Sandboxes tab. The [unified Grafana dashboard](../../grafana-dashboard.json) provides a Prometheus-backed Sandboxes tab; see the Grafana setup below. It covers host capacity, lifecycle operations, boot latency, guest resources, execution, networking, and host health. APM, JuiceFS mount metrics, and cloud storage metrics are optional sections with separate collection requirements.

The dashboard contains queries, not telemetry or access to a hosted dashboard. Its filters are not access controls. Use your Datadog organization's permissions to control who can view your data.

## Requirements

- An existing self-hosted sandbox deployment using the `sandbox-host` Firecracker runtime. These values require the chart's `sandboxes.sandboxHost.deployment.podAnnotations` setting. Check the values schema for your installed chart version; do not upgrade the runtime just to import the dashboard. Metrics vary by runtime version, so older hosts may not emit every series.
- Datadog Agent with Kubernetes Autodiscovery and the [OpenMetrics integration](https://docs.datadoghq.com/integrations/openmetrics/). Use Agent 7.36 or later for the Autodiscovery v2 `checks` annotation. Configure your own Datadog site and credentials through your existing Agent installation, not these files.
- An Agent on the sandbox nodes. If those nodes use the chart's default `sandbox.langsmith.com/host=true:NoSchedule` taint, add the matching toleration to your existing Agent configuration without discarding other tolerations.
- Private Agent connectivity to the existing `sandbox-host` listener on port `19190`. Do not expose this listener through a public Service or ingress. The host uses the node network; node firewall rules must restrict access appropriately.
- Permission to import a dashboard in your Datadog organization and to update your LangSmith Helm release.

## Collect host metrics

1. Download the [unified dashboard](../../datadog-dashboard.json) and `datadog-values.yaml` from this directory. The values file adds one OpenMetrics check on each sandbox-host pod. It does not install Datadog, enable sandboxes, change credentials, or create network resources.
2. Merge the check into your existing Autodiscovery configuration if the annotation already exists. A Helm string value replaces the whole annotation, not individual JSON instances. Avoid scraping port `19190` a second time through another OpenMetrics check or Prometheus Autodiscovery rule.
3. Apply the values alongside your existing release values, using the same chart version you currently run:

   ```bash
   helm upgrade <release> langchain/langsmith --version <installed-chart-version> \
     --namespace <namespace> -f values.yaml -f datadog-values.yaml
   ```

   Changing pod annotations rolls sandbox-host pods and suspends their running sandboxes. Schedule the update in a maintenance window. If you use GitOps or another release manager, merge the values through that system rather than running a separate Helm upgrade.
4. Check the Agent's OpenMetrics status for scrape errors. Confirm that `langsmith_sandbox_host_live_sandboxes` and `langsmith_sandbox_host_juicefs_mount_ready` reach Datadog before using the dashboard to diagnose failures.

The collection example uses no metric namespace prefix. Counters appear with `.count` instead of `_total`. Histograms retain `.sum` and `.count` because `collect_counters_with_distributions` is enabled. Mean latency widgets divide these series; host histograms are not presented as percentile estimates. The integration also submits histogram distributions. Review custom-metric usage and label cardinality in your Datadog plan.

## Import and filter

Create a dashboard in Datadog and use its JSON import action to import `datadog-dashboard.json`.

| Variable | Tag | Applies to |
| --- | --- | --- |
| `env` | `env` | Host, JuiceFS, and APM metrics |
| `cluster` | `kube_cluster_name:$cluster.value` | Host and JuiceFS metrics; selection shared with SmithDB |
| `namespace` | `kube_namespace` | Host and JuiceFS metrics; selection shared with SmithDB |
| `api_service` | `service` | Optional APM metrics; defaults to `platform-backend` |
| `gcs_bucket` | `bucket_name` | Optional GCS metrics |
| `s3_bucket` | `bucketname` | Optional S3 metrics |

Host filters start at `*`. Select one environment, cluster, and namespace before reading pool counts; those counts describe one pool, not a multi-pool total. The example explicitly attaches `kube_namespace` through Autodiscovery. Configure the Agent's cluster name and environment tags, then select your installation's values. The shared cluster picker discovers values from `cluster_name` by default. If your account exposes only `kube_cluster_name`, change the picker's prefix to that key; explicit query keys remain unchanged. Both tag keys must use the same cluster-name values. If your Sandbox metrics use a different tag key, change their explicit query filters and group-by clauses as well. You can select both component namespaces when they differ, but pool counts still require one selected Sandbox pool. API and bucket selectors follow the shared deployment filters. Datadog places overflow controls in its additional-variable menu.

Select exactly one `api_service` that emits your sandbox API spans. Selecting all services can count the same request more than once. APM widgets intentionally ignore the host cluster and namespace filters. In a shared Datadog organization, use an environment/service combination that identifies the intended deployment.

## Read the panels

The dashboard uses curated mixed-width rows, with fleet, public API, and execution panels near the top. Compact trends share three-panel rows. Dense charts and storage comparisons use half-width panels, while long-label rankings receive two-thirds or full width. The grid supports up to four headline cards per row; existing headline cards remain paired where the section has only two. Notes span the row.

- **Fleet snapshots:** Live sandbox counts, ready-host counts, and the host ranking use five-minute windows, shown by the `5m` badge. Per-host samples align for up to 60 seconds. Ready/desired pool counts use `max` without interpolation so successive leaders do not add together. These counts require one selected cluster and namespace.
- **Historical views:** Other charts and totals follow the dashboard's selected range. Request and operation rankings show totals. The public HTTP latency ranking uses the whole-window p95 rather than averaging interval percentiles.
- **Failure attribution:** Operation error totals include errors without a stage label. The separate unstaged-error total preserves these failures when the recorded-stage ranking has no data.
- **Legend statistics:** `AVG` and `MAX` summarize plotted buckets, not event-weighted statistics over the entire selected range. Host histograms show mean durations; their charts are not percentile estimates.

## Add optional telemetry

### JuiceFS mount metrics

The `juicefs_*` metrics come from the mount process, not the host's `19190/metrics` endpoint. The optional `datadog-juicefs-values.yaml` collects both endpoints and replaces `datadog-values.yaml`.

Before applying it, confirm that the mount's `/metrics` listener is reachable by the Agent on the sandbox node's private address, port `9567`. JuiceFS defaults to loopback, and this example does not change the listener. If you configure its `--metrics` mount option, restrict it to the intended private network and retain all existing `sandboxes.juicefs.hostMount.mountOptions`. Helm replaces that list rather than appending to it. A listener change also requires a host rollout. Do not open the metrics port to the internet or untrusted workloads.

For a different address, port, or an externally managed mount, configure the check on the actual mount process instead. Do not collect the same mount from both locations.

`juicefs_used_space` measures apparent filesystem size. Sparse disk images and copy-on-write clones make this different from physical object storage consumption; no fixed ratio applies.

### API and execution traces

The API widgets use Datadog APM metrics named `trace.http.request`, `trace.http.request.hits`, and `trace.http.request.errors`, not application Prometheus metrics. Configure your existing tracing pipeline using [Export LangSmith telemetry](https://docs.langchain.com/langsmith/export-backend).

Public API panels cover `/v2/sandboxes` routes and exclude internal reporting endpoints. Internal reporting has its own optional section. HTTP latency and endpoint latency rankings exclude WebSocket, streaming execution, tunnel, and service-proxy traffic; separate panels show those durations in seconds. APM request errors and HTTP 5xx responses remain separate signals.

Check metric names, service names, and `resource_name` tags in your account. OTLP instrumentation can generate different names; adapt the APM queries if needed. Scraping host metrics alone does not populate the API widgets. Host-side command counts and duration remain available without APM.

### Object storage

Enable the appropriate Datadog AWS or GCP integration for your own account. Set `s3_bucket` or `gcs_bucket` to the exact bucket used by your JuiceFS volume. Their defaults are placeholders rather than wildcard bucket selectors. Cloud widgets ignore environment and Kubernetes filters because those tags may not exist on provider metrics.

Remove unused provider widgets. Azure Blob Storage requires a separate provider-specific dashboard query; the host and JuiceFS sections do not depend on the object storage provider.

## Interpret missing data

- Check a continuously exported gauge and the Agent's scrape status first. Missing data is not proof of a healthy system.
- Failure counters may have no series until an event occurs. A process that exits before the next scrape can also lose its final counter increment; use logs when investigating a host exit.
- Pool gauges come from the elected host leader. Ready-host and CPU-capacity observations remain available with autoscaling disabled. The desired-replica target updates only when scaling is active; do not interpret it as the configured replica count in a fixed-replica deployment.
- Empty optional sections usually indicate a missing integration, a filter mismatch, or a different metric name. Check those before changing the runtime.
- A WebSocket execution duration is connection lifetime, not command execution latency.

## Grafana and Prometheus

Use Grafana 13 or later with an existing Prometheus data source. The Sandbox tab includes every host and JuiceFS diagnostic panel from the Datadog component, but excludes APM/API and cloud-provider bucket panels. HTTP tracing error flags and provider metrics require other integrations; no substitute metric names are assumed.

1. Merge the `scrape_configs` entries from [host-scrape.yaml](prometheus/host-scrape.yaml) into your existing Prometheus configuration. This is Prometheus configuration, not Helm values. Replace the namespace and cluster placeholders. Prometheus needs existing pod-discovery access in that namespace and private connectivity to port `19190`.
2. Remove duplicate jobs targeting the same host listener. Discovery keeps the `sandbox-host` container and its declared `19190` port so additional container ports do not create duplicate targets. Target labels provide `namespace`, `cluster`, `pod`, and `instance`; host metrics do not contain host identity themselves.
3. Optionally add [juicefs-scrape.yaml](prometheus/juicefs-scrape.yaml) after confirming private connectivity to the mount's port `9567`. It reuses host-pod discovery but changes the target port. The job does not change the mount listener or its bind address. Configure externally managed mounts separately, and do not collect them twice.
4. Import the Grafana JSON and select the shared Data source and Namespace(s), plus Sandbox cluster. Select both component namespaces if they differ, while keeping only one Sandbox pool selected. The `sandbox_job` and `juicefs_job` variables default to All and are hidden from the normal header; edit or unhide them in variable settings if collection jobs need disambiguation. The supplied scrape jobs use Prometheus text format so JuiceFS's unsuffixed counter names remain consistent. The configuration and queries are validated with Prometheus 3.5.0; check support for `scrape_protocols` in older versions.

Counters use `rate` or `increase` before aggregation to handle per-process resets. Rankings and error totals use `increase` over the selected range; counts can be fractional because Prometheus extrapolates scrape boundaries. Time-series count panels show rolling increases over `$__rate_interval`, not disjoint Datadog buckets. Histogram means divide matching sum/count increases. No additional host percentile estimates are introduced.

Snapshot panels have a five-minute panel range and evaluate gauges at its end, requiring a sample within 60 seconds. Ready/desired pool gauges use `max` rather than summing leader reports. Missing and zero-denominator results are not filled with zero. These rules preserve the diagnostic intent but do not imply identical values from two differently sampled monitoring backends.

## Maintain the definition

`datadog.py` is the public, curated source for the Sandbox panels. The bundle's `generate_dashboards.py` composes the unified JSON. It has no external dependencies and does not read a Datadog export, credentials, or a private repository. Update metric definitions here and regenerate the artifact rather than publishing a raw dashboard API response. Keep author metadata, account IDs, tenant rankings, private links, and deployment-specific filters out of the public definition.

From the repository root:

```bash
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py
python3 charts/langsmith/examples/langsmith-observability/generate_dashboards.py --check
python3 -m unittest discover -s charts/langsmith/examples/langsmith-observability/components/sandboxes -p 'test_*.py'
helm unittest -f 'tests/sandbox_observability_test.yaml' charts/langsmith
```

The generator check verifies the committed JSON matches its source. Unit tests cover query variables, formula inputs, data-source scoping, and account-neutral metadata. Helm tests cover the rendered pod annotations and ensure the monitoring overlay does not enable sandboxes or alter mount options.
