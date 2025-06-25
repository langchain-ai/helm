# langsmith-observability

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the observability stack for LangSmith.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | grafana | 9.2.6 |
| https://grafana.github.io/helm-charts | loki | 6.30.1 |
| https://grafana.github.io/helm-charts | tempo(tempo) | 1.23.1 |
| https://prometheus-community.github.io/helm-charts | kube-state-metrics(kube-state-metrics) | 5.37.0 |
| https://prometheus-community.github.io/helm-charts | nginx-exporter(prometheus-nginx-exporter) | 1.6.0 |
| https://prometheus-community.github.io/helm-charts | postgres-exporter(prometheus-postgres-exporter) | 6.10.2 |
| https://prometheus-community.github.io/helm-charts | redis-exporter(prometheus-redis-exporter) | 6.11.0 |

## Documentation
For information on how to use this chart and how to deploy the full LangSmith Observability stack, please refer to the [documentation](https://docs.smith.langchain.com/self_hosting/observability).

NOTE: For any values in dependencies (Loki, Mimir, Tempo, etc.), you can update the values as you see fit. Only a small set of
values are listed in the `values.yaml` and this `README`. Refer to the `values.yaml` files listed next to each dependency header for additional values.

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| langSmithReleaseName | string | `"langsmith"` |  |
| langsmithNamespace | string | `"langsmith"` |  |
| nameOverride | string | `""` |  |

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
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://{{ .Release.Name }}-loki-gateway:80"` |  |
| grafana.datasources."datasources.yaml".datasources[1].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[1].name | string | `"Mimir"` |  |
| grafana.datasources."datasources.yaml".datasources[1].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[1].uid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[1].url | string | `"http://{{ .Release.Name }}-mimir:9009/prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[2].isDefault | bool | `false` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.lokiSearch.datasourceUid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.serviceMap.datasourceUid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.tracesToLogsV2.datasourceUid | string | `"loki"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.tracesToMetrics.datasourceUid | string | `"prom"` |  |
| grafana.datasources."datasources.yaml".datasources[2].name | string | `"Tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].type | string | `"tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].uid | string | `"tempo"` |  |
| grafana.datasources."datasources.yaml".datasources[2].url | string | `"http://{{ .Release.Name }}-tempo:3200"` |  |
| grafana.enabled | bool | `false` |  |

## Kube State Metrics

Values for Kube State Metrics: `https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| kube-state-metrics.enabled | bool | `false` |  |
| kube-state-metrics.namespaces | string | `"romain"` |  |
| kube-state-metrics.resources.limits.cpu | string | `"250m"` |  |
| kube-state-metrics.resources.limits.memory | string | `"500Mi"` |  |
| kube-state-metrics.resources.requests.cpu | string | `"100m"` |  |
| kube-state-metrics.resources.requests.memory | string | `"250Mi"` |  |
| kube-state-metrics.service.port | int | `8080` |  |
| kube-state-metrics.service.type | string | `"ClusterIP"` |  |

## Loki

Values for Loki Single Binary: `https://github.com/grafana/loki/blob/main/production/helm/loki/values.yaml#L1364`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| loki.backend.replicas | int | `0` |  |
| loki.bloomCompactor.replicas | int | `0` |  |
| loki.bloomGateway.replicas | int | `0` |  |
| loki.compactor.replicas | int | `0` |  |
| loki.deploymentMode | string | `"SingleBinary"` |  |
| loki.distributor.replicas | int | `0` |  |
| loki.enabled | bool | `false` |  |
| loki.indexGateway.replicas | int | `0` |  |
| loki.ingester.replicas | int | `0` |  |
| loki.loki.auth_enabled | bool | `false` |  |
| loki.loki.commonConfig.replication_factor | int | `1` |  |
| loki.loki.limits_config.allow_structured_metadata | bool | `true` |  |
| loki.loki.limits_config.volume_enabled | bool | `true` |  |
| loki.loki.pattern_ingester.enabled | bool | `true` |  |
| loki.loki.ruler.enable_api | bool | `true` |  |
| loki.loki.schemaConfig.configs[0].from | string | `"2024-04-01"` |  |
| loki.loki.schemaConfig.configs[0].index.period | string | `"24h"` |  |
| loki.loki.schemaConfig.configs[0].index.prefix | string | `"loki_index_"` |  |
| loki.loki.schemaConfig.configs[0].object_store | string | `"filesystem"` |  |
| loki.loki.schemaConfig.configs[0].schema | string | `"v13"` |  |
| loki.loki.schemaConfig.configs[0].store | string | `"tsdb"` |  |
| loki.loki.storage.filesystem.admin_api_directory | string | `"/var/loki/admin"` |  |
| loki.loki.storage.filesystem.chunks_directory | string | `"/var/loki/chunks"` |  |
| loki.loki.storage.filesystem.rules_directory | string | `"/var/loki/rules"` |  |
| loki.loki.storage.type | string | `"filesystem"` |  |
| loki.lokiCanary.enabled | bool | `false` |  |
| loki.minio.enabled | bool | `false` |  |
| loki.querier.replicas | int | `0` |  |
| loki.queryFrontend.replicas | int | `0` |  |
| loki.queryScheduler.replicas | int | `0` |  |
| loki.read.replicas | int | `0` |  |
| loki.singleBinary.persistence.enabled | bool | `true` |  |
| loki.singleBinary.persistence.size | string | `"10Gi"` |  |
| loki.singleBinary.persistence.storageClass | string | `nil` |  |
| loki.singleBinary.replicas | int | `1` |  |
| loki.test.enabled | bool | `false` |  |
| loki.write.replicas | int | `0` |  |

## Mimir

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| mimir.enabled | bool | `false` |  |
| mimir.extraEnv | list | `[]` |  |
| mimir.image.pullPolicy | string | `"IfNotPresent"` |  |
| mimir.image.registry | string | `"docker.io"` |  |
| mimir.image.repository | string | `"grafana/mimir"` |  |
| mimir.image.tag | string | `nil` |  |
| mimir.livenessProbe.failureThreshold | int | `3` |  |
| mimir.livenessProbe.httpGet.path | string | `"/ready"` |  |
| mimir.livenessProbe.httpGet.port | string | `"http"` |  |
| mimir.livenessProbe.initialDelaySeconds | int | `20` |  |
| mimir.livenessProbe.periodSeconds | int | `10` |  |
| mimir.livenessProbe.timeoutSeconds | int | `5` |  |
| mimir.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| mimir.persistence.annotations | object | `{}` |  |
| mimir.persistence.enabled | bool | `true` |  |
| mimir.persistence.selector | object | `{}` |  |
| mimir.persistence.size | string | `"10Gi"` |  |
| mimir.persistence.storageClass | string | `nil` |  |
| mimir.readinessProbe.failureThreshold | int | `3` |  |
| mimir.readinessProbe.httpGet.path | string | `"/ready"` |  |
| mimir.readinessProbe.httpGet.port | string | `"http"` |  |
| mimir.readinessProbe.initialDelaySeconds | int | `20` |  |
| mimir.readinessProbe.periodSeconds | int | `10` |  |
| mimir.readinessProbe.timeoutSeconds | int | `5` |  |
| mimir.replicas | int | `1` |  |
| mimir.service.port | int | `9009` |  |
| mimir.service.targetPort | string | `"http"` |  |
| mimir.service.type | string | `"ClusterIP"` |  |
| mimir.updateStrategy.type | string | `"RollingUpdate"` |  |

## Nginx Exporter

Values for Nginx Exporter: `https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-nginx-exporter/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| nginx-exporter.additionalAnnotations | object | `{}` |  |
| nginx-exporter.additionalLabels | object | `{}` |  |
| nginx-exporter.affinity | object | `{}` |  |
| nginx-exporter.enabled | bool | `false` |  |
| nginx-exporter.extraContainers | list | `[]` |  |
| nginx-exporter.extraEnv | list | `[]` |  |
| nginx-exporter.extraVolumeMounts | list | `[]` |  |
| nginx-exporter.extraVolumes | list | `[]` |  |
| nginx-exporter.initContainers | list | `[]` |  |
| nginx-exporter.nginxServer | string | `"http://langsmith-frontend.romain.svc.cluster.local:80/nginx_status"` |  |
| nginx-exporter.nodeSelector | object | `{}` |  |
| nginx-exporter.podAnnotations | object | `{}` |  |
| nginx-exporter.service.port | int | `9113` |  |
| nginx-exporter.service.type | string | `"ClusterIP"` |  |
| nginx-exporter.tolerations | list | `[]` |  |

## OTEL Collector

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
| postgres-exporter.affinity | object | `{}` |  |
| postgres-exporter.annotations | object | `{}` |  |
| postgres-exporter.config.datasource.database | string | `"postgres"` |  |
| postgres-exporter.config.datasource.host | string | `"langsmith-postgres.romain.svc.cluster.local"` |  |
| postgres-exporter.config.datasource.password | string | `"postgres"` |  |
| postgres-exporter.config.datasource.port | string | `"5432"` |  |
| postgres-exporter.config.datasource.user | string | `"postgres"` |  |
| postgres-exporter.enabled | bool | `false` |  |
| postgres-exporter.extraContainers | list | `[]` |  |
| postgres-exporter.extraEnv | list | `[]` |  |
| postgres-exporter.extraVolumeMounts | list | `[]` |  |
| postgres-exporter.extraVolumes | list | `[]` |  |
| postgres-exporter.initContainers | list | `[]` |  |
| postgres-exporter.nodeSelector | object | `{}` |  |
| postgres-exporter.podLabels | object | `{}` |  |
| postgres-exporter.service.port | int | `80` |  |
| postgres-exporter.service.targetPort | int | `9187` |  |
| postgres-exporter.service.type | string | `"ClusterIP"` |  |
| postgres-exporter.tolerations | list | `[]` |  |

## Redis Exporter

Values for Redis Exporter: `https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-redis-exporter/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis-exporter.affinity | object | `{}` |  |
| redis-exporter.annotations | object | `{}` |  |
| redis-exporter.enabled | bool | `false` |  |
| redis-exporter.extraArgs | object | `{}` |  |
| redis-exporter.labels | object | `{}` |  |
| redis-exporter.nodeSelector | object | `{}` |  |
| redis-exporter.redisAddress | string | `"langsmith-redis.romain.svc.cluster.local:6379"` |  |
| redis-exporter.service.port | int | `9121` |  |
| redis-exporter.service.portName | string | `"http"` |  |
| redis-exporter.service.type | string | `"ClusterIP"` |  |
| redis-exporter.tolerations | list | `[]` |  |

## Tempo

Values for Tempo: `https://github.com/grafana/helm-charts/blob/main/charts/tempo/values.yaml`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| tempo.enabled | bool | `false` |  |
| tempo.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| tempo.persistence.enabled | bool | `true` |  |
| tempo.persistence.size | string | `"10Gi"` |  |
| tempo.persistence.storageClassName | string | `""` |  |
| tempo.tempo.metricsGenerator.enabled | bool | `true` |  |
| tempo.tempo.overrides.defaults.metrics_generator.processors[0] | string | `"service-graphs"` |  |
| tempo.tempo.overrides.defaults.metrics_generator.processors[1] | string | `"span-metrics"` |  |
| tempo.tempo.overrides.defaults.metrics_generator.processors[2] | string | `"local-blocks"` |  |
| tempo.tempo.reportingEnabled | bool | `false` |  |
