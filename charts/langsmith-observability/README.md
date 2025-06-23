# langsmith-observability

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the observability stack for LangSmith.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | minio | 16.0.10 |
| https://grafana.github.io/helm-charts | grafana | 9.2.6 |
| https://grafana.github.io/helm-charts | loki | 6.30.1 |
| https://grafana.github.io/helm-charts | mimir(mimir-distributed) | 5.7.0 |
| https://grafana.github.io/helm-charts | tempo(tempo-distributed) | 1.41.1 |
| https://prometheus-community.github.io/helm-charts | kubestatemetrics(kube-state-metrics) | 5.37.0 |
| https://prometheus-community.github.io/helm-charts | nginxexporter(prometheus-nginx-exporter) | 1.6.0 |
| https://prometheus-community.github.io/helm-charts | postgresexporter(prometheus-postgres-exporter) | 6.10.2 |
| https://prometheus-community.github.io/helm-charts | redisexporter(prometheus-redis-exporter) | 6.11.0 |

## Documentation
For information on how to use this chart and how to deploy the full LangSmith Observability stack, please refer to the [documentation](https://docs.smith.langchain.com/self_hosting/observability).

NOTE: For any values in dependencies (Loki, Mimir, Tempo, etc.), you can update the values as you see fit. Only a small set of
values are listed in the `values.yaml` and this `README`. Refer to the `values.yaml` files listed next to each dependency header for additional values.

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| langSmithReleaseName | string | `"langsmith"` |  |
| langsmithNamespace | string | `"langsmith"` |  |

## Grafana

Values for Grafana: `https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| grafana.dashboardProviders."dashboardproviders.yaml".apiVersion | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name | string | `"default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path | string | `"/var/lib/grafana/dashboards/default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type | string | `"file"` |  |
| grafana.dashboardsConfigMaps.default | string | `"langsmith-grafana-dashboards"` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].isDefault | bool | `false` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"Loki"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[0].uid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://{{ .Release.Name }}-loki-gateway"` |  |
| grafana.datasources."datasources.yaml".datasources[1].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[1].name | string | `"Mimir"` |  |
| grafana.datasources."datasources.yaml".datasources[1].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[1].uid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[1].url | string | `"http://{{ .Release.Name }}-mimir-nginx/prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[2].isDefault | bool | `false` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.lokiSearch.datasourceUid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.serviceMap.datasourceUid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.tracesToLogsV2.datasourceUid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.tracesToMetrics.datasourceUid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[2].name | string | `"Tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].type | string | `"tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].uid | string | `"tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].url | string | `"http://{{ .Release.Name }}-tempo-query-frontend-discovery:3200"` |  |
| grafana.enabled | bool | `false` |  |

## Kube State Metrics

Values for Kube State Metrics: `https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| kubestatemetrics.enabled | bool | `false` |  |
| kubestatemetrics.namespaces | string | `"romain"` |  |
| kubestatemetrics.resources.limits.cpu | string | `"250m"` |  |
| kubestatemetrics.resources.limits.memory | string | `"500Mi"` |  |
| kubestatemetrics.resources.requests.cpu | string | `"100m"` |  |
| kubestatemetrics.resources.requests.memory | string | `"250Mi"` |  |
| kubestatemetrics.service.port | int | `8080` |  |
| kubestatemetrics.service.type | string | `"ClusterIP"` |  |

## Loki

Values for Loki: `https://github.com/grafana/loki/blob/main/production/helm/loki/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| loki.backend.replicas | int | `0` |  |
| loki.bloomBuilder.replicas | int | `0` |  |
| loki.bloomGateway.replicas | int | `0` |  |
| loki.bloomPlanner.replicas | int | `0` |  |
| loki.compactor.replicas | int | `1` |  |
| loki.deploymentMode | string | `"Distributed"` |  |
| loki.distributor.maxUnavailable | int | `2` |  |
| loki.distributor.replicas | int | `3` |  |
| loki.enabled | bool | `false` |  |
| loki.indexGateway.maxUnavailable | int | `1` |  |
| loki.indexGateway.replicas | int | `2` |  |
| loki.ingester.replicas | int | `3` |  |
| loki.loki.auth_enabled | bool | `false` |  |
| loki.loki.ingester.chunk_encoding | string | `"snappy"` |  |
| loki.loki.querier.max_concurrent | int | `4` |  |
| loki.loki.schemaConfig.configs[0].from | string | `"2024-04-01"` |  |
| loki.loki.schemaConfig.configs[0].index.period | string | `"24h"` |  |
| loki.loki.schemaConfig.configs[0].index.prefix | string | `"loki_index_"` |  |
| loki.loki.schemaConfig.configs[0].object_store | string | `"s3"` |  |
| loki.loki.schemaConfig.configs[0].schema | string | `"v13"` |  |
| loki.loki.schemaConfig.configs[0].store | string | `"tsdb"` |  |
| loki.loki.storage.bucketNames.chunks | string | `"langsmith-lgtm-stack"` |  |
| loki.loki.storage.bucketNames.ruler | string | `"langsmith-lgtm-stack"` |  |
| loki.loki.storage.s3.accessKeyId | string | `"admin"` |  |
| loki.loki.storage.s3.endpoint | string | `"{{ .Release.Name }}-minio.{{ .Release.Namespace }}.svc.cluster.local:9000"` |  |
| loki.loki.storage.s3.insecure | bool | `true` |  |
| loki.loki.storage.s3.s3ForcePathStyle | bool | `true` |  |
| loki.loki.storage.s3.secretAccessKey | string | `"admin_password"` |  |
| loki.loki.storage.type | string | `"s3"` |  |
| loki.loki.storage_config.aws.bucketnames | string | `"langsmith-lgtm-stack"` |  |
| loki.loki.storage_config.aws.region | string | `"us-west-2"` |  |
| loki.loki.storage_config.aws.s3forcepathstyle | bool | `true` |  |
| loki.loki.storage_config.object_prefix | string | `"loki"` |  |
| loki.lokiCanary.enabled | bool | `false` |  |
| loki.querier.maxUnavailable | int | `2` |  |
| loki.querier.replicas | int | `3` |  |
| loki.queryFrontend.maxUnavailable | int | `1` |  |
| loki.queryFrontend.replicas | int | `2` |  |
| loki.queryScheduler.replicas | int | `2` |  |
| loki.read.replicas | int | `0` |  |
| loki.singleBinary.replicas | int | `0` |  |
| loki.test.enabled | bool | `false` |  |
| loki.write.replicas | int | `0` |  |

## Mimir

Values for Mimir: `https://github.com/grafana/helm-charts/blob/main/charts/mimir/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| mimir.enabled | bool | `false` |  |
| mimir.mimir.structuredConfig.alertmanager_storage.storage_prefix | string | `"mimirAlertmanager"` |  |
| mimir.mimir.structuredConfig.blocks_storage.storage_prefix | string | `"mimirBlocks"` |  |
| mimir.mimir.structuredConfig.common.storage.backend | string | `"s3"` |  |
| mimir.mimir.structuredConfig.common.storage.s3.access_key_id | string | `"admin"` |  |
| mimir.mimir.structuredConfig.common.storage.s3.bucket_name | string | `"langsmith-lgtm-stack"` |  |
| mimir.mimir.structuredConfig.common.storage.s3.endpoint | string | `"{{ .Release.Name }}-minio.{{ .Release.Namespace }}.svc.cluster.local:9000"` |  |
| mimir.mimir.structuredConfig.common.storage.s3.insecure | bool | `true` |  |
| mimir.mimir.structuredConfig.common.storage.s3.secret_access_key | string | `"admin_password"` |  |
| mimir.mimir.structuredConfig.ruler_storage.storage_prefix | string | `"mimirRuler"` |  |
| mimir.minio.enabled | bool | `false` |  |

## Minio

Values for Minio: `https://github.com/bitnami/charts/blob/main/bitnami/minio/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| minio.auth.rootPassword | string | `"admin_password"` |  |
| minio.auth.rootUser | string | `"admin"` |  |
| minio.defaultBuckets | string | `"langsmith-lgtm-stack"` |  |
| minio.enabled | bool | `false` |  |
| minio.mode | string | `"standalone"` |  |
| minio.persistence.enabled | bool | `true` |  |
| minio.persistence.size | string | `"10Gi"` |  |
| minio.readinessProbe.enabled | bool | `false` |  |
| minio.replicas | int | `1` |  |

## Nginx Exporter

Values for Nginx Exporter: `https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-nginx-exporter/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| nginxexporter.enabled | bool | `false` |  |
| nginxexporter.nginxServer | string | `"http://langsmith-frontend.romain.svc.cluster.local:80/nginx_status"` |  |
| nginxexporter.service.port | int | `9113` |  |
| nginxexporter.service.type | string | `"ClusterIP"` |  |

## OTEL Collector

Values for OTEL Collector: `https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector-contrib/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| otelCollector.image.repository | string | `"otel/opentelemetry-collector-contrib"` |  |
| otelCollector.image.tag | string | `"0.123.0"` |  |
| otelCollector.logs.enabled | bool | `false` |  |
| otelCollector.metrics.enabled | bool | `false` |  |
| otelCollector.serviceAccounts[0] | string | `"langsmith-ace-backend"` |  |
| otelCollector.serviceAccounts[1] | string | `"langsmith-backend"` |  |
| otelCollector.serviceAccounts[2] | string | `"langsmith-clickhouse"` |  |
| otelCollector.serviceAccounts[3] | string | `"langsmith-frontend"` |  |
| otelCollector.serviceAccounts[4] | string | `"langsmith-platform-backend"` |  |
| otelCollector.serviceAccounts[5] | string | `"langsmith-playground"` |  |
| otelCollector.serviceAccounts[6] | string | `"langsmith-postgres"` |  |
| otelCollector.serviceAccounts[7] | string | `"langsmith-queue"` |  |
| otelCollector.serviceAccounts[8] | string | `"langsmith-redis"` |  |
| otelCollector.traces.enabled | bool | `false` |  |

## Postgres Exporter

Values for Postgres Exporter: `https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-postgres-exporter/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgresexporter.config.datasource.database | string | `"postgres"` |  |
| postgresexporter.config.datasource.host | string | `"langsmith-postgres.romain.svc.cluster.local"` |  |
| postgresexporter.config.datasource.password | string | `"postgres"` |  |
| postgresexporter.config.datasource.port | string | `"5432"` |  |
| postgresexporter.config.datasource.user | string | `"postgres"` |  |
| postgresexporter.enabled | bool | `false` |  |
| postgresexporter.service.port | int | `80` |  |
| postgresexporter.service.targetPort | int | `9187` |  |
| postgresexporter.service.type | string | `"ClusterIP"` |  |

## Redis Exporter

Values for Redis Exporter: `https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-redis-exporter/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redisexporter.enabled | bool | `false` |  |
| redisexporter.redisAddress | string | `"langsmith-redis.romain.svc.cluster.local:6379"` |  |
| redisexporter.service.port | int | `9121` |  |
| redisexporter.service.portName | string | `"http"` |  |
| redisexporter.service.type | string | `"ClusterIP"` |  |

## Tempo

Values for Tempo: `https://github.com/grafana/helm-charts/blob/main/charts/tempo-distributed/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| tempo.enabled | bool | `false` |  |
| tempo.storage.trace.backend | string | `"s3"` |  |
| tempo.storage.trace.s3.access_key | string | `"admin"` |  |
| tempo.storage.trace.s3.bucket | string | `"langsmith-lgtm-stack"` |  |
| tempo.storage.trace.s3.endpoint | string | `"{{ .Release.Name }}-minio.{{ .Release.Namespace }}.svc.cluster.local:9000"` |  |
| tempo.storage.trace.s3.insecure | bool | `true` |  |
| tempo.storage.trace.s3.prefix | string | `"tempo"` |  |
| tempo.storage.trace.s3.secret_key | string | `"admin_password"` |  |
| tempo.traces.otlp.grpc.enabled | bool | `true` |  |
| tempo.traces.otlp.http.enabled | bool | `true` |  |
