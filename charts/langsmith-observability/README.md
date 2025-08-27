# langsmith-observability

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the observability stack for LangSmith.

## Documentation

For information on how to use this chart, up-to-date release notes, and other guides please check out the [documentation.](https://docs.smith.langchain.com/self_hosting)

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

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
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
| kube-state-metrics.enabled | bool | `false` |  |
| kube-state-metrics.namespaces | string | `"romain"` |  |
| kube-state-metrics.resources.limits.cpu | string | `"250m"` |  |
| kube-state-metrics.resources.limits.memory | string | `"500Mi"` |  |
| kube-state-metrics.resources.requests.cpu | string | `"100m"` |  |
| kube-state-metrics.resources.requests.memory | string | `"250Mi"` |  |
| kube-state-metrics.service.port | int | `8080` |  |
| kube-state-metrics.service.type | string | `"ClusterIP"` |  |
| langSmithReleaseName | string | `"langsmith"` |  |
| langsmithNamespace | string | `"langsmith"` |  |
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
| loki.singleBinary.resources.limits.cpu | string | `"3000m"` |  |
| loki.singleBinary.resources.limits.memory | string | `"4Gi"` |  |
| loki.singleBinary.resources.requests.cpu | string | `"2000m"` |  |
| loki.singleBinary.resources.requests.memory | string | `"2Gi"` |  |
| loki.test.enabled | bool | `false` |  |
| loki.write.replicas | int | `0` |  |
| mimir.affinity | object | `{}` |  |
| mimir.annotations | object | `{}` |  |
| mimir.enabled | bool | `false` |  |
| mimir.envFrom | list | `[]` |  |
| mimir.extraEnv | list | `[]` |  |
| mimir.extraVolumeMounts | list | `[]` |  |
| mimir.extraVolumes | list | `[]` |  |
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
| mimir.nodeSelector | object | `{}` |  |
| mimir.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| mimir.persistence.annotations | object | `{}` |  |
| mimir.persistence.enabled | bool | `true` |  |
| mimir.persistence.selector | object | `{}` |  |
| mimir.persistence.size | string | `"10Gi"` |  |
| mimir.persistence.storageClass | string | `""` |  |
| mimir.podAnnotations | object | `{}` |  |
| mimir.podSecurityContext | object | `{}` |  |
| mimir.readinessProbe.failureThreshold | int | `3` |  |
| mimir.readinessProbe.httpGet.path | string | `"/ready"` |  |
| mimir.readinessProbe.httpGet.port | string | `"http"` |  |
| mimir.readinessProbe.initialDelaySeconds | int | `20` |  |
| mimir.readinessProbe.periodSeconds | int | `10` |  |
| mimir.readinessProbe.timeoutSeconds | int | `5` |  |
| mimir.resources.limits.cpu | string | `"2000m"` |  |
| mimir.resources.limits.memory | string | `"4Gi"` |  |
| mimir.resources.requests.cpu | string | `"1000m"` |  |
| mimir.resources.requests.memory | string | `"2Gi"` |  |
| mimir.securityContext | object | `{}` |  |
| mimir.service.port | int | `9009` |  |
| mimir.service.targetPort | string | `"http"` |  |
| mimir.service.type | string | `"ClusterIP"` |  |
| mimir.tolerations | list | `[]` |  |
| mimir.updateStrategy.type | string | `"RollingUpdate"` |  |
| nameOverride | string | `""` |  |
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
| otelCollector.gatewayNameOverride | string | `""` |  |
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
| otelCollector.sidecarNameOverride | string | `""` |  |
| otelCollector.traces.enabled | bool | `false` |  |
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
| tempo.tempo.resources.limits.cpu | string | `"2000m"` |  |
| tempo.tempo.resources.limits.memory | string | `"6Gi"` |  |
| tempo.tempo.resources.requests.cpu | string | `"1000m"` |  |
| tempo.tempo.resources.requests.memory | string | `"4Gi"` |  |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Ace Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Clickhouse

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## E2E Test

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Host Backend (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Listener (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Operator (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Platform Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Playground

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Postgres

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

## Queue

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Redis

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

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Romain | <romain@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith/README.md.gotmpl`
