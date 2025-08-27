# langgraph-cloud

![Version: 0.1.17](https://img.shields.io/badge/Version-0.1.17-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.2.0](https://img.shields.io/badge/AppVersion-0.2.0-informational?style=flat-square)

Helm chart to deploy the LangGraph Cloud application and all services it depends on.

## Documentation

For information on how to use this chart, up-to-date release notes, and other guides please check out the [documentation.](https://docs.smith.langchain.com/self_hosting)

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiServer.autoscaling.enabled | bool | `false` |  |
| apiServer.autoscaling.keda.cooldownPeriod | int | `300` |  |
| apiServer.autoscaling.keda.enabled | bool | `false` |  |
| apiServer.autoscaling.keda.pollingInterval | int | `30` |  |
| apiServer.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| apiServer.autoscaling.maxReplicas | int | `5` |  |
| apiServer.autoscaling.minReplicas | int | `1` |  |
| apiServer.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| apiServer.containerPort | int | `8000` |  |
| apiServer.deployment.affinity | object | `{}` |  |
| apiServer.deployment.annotations | object | `{}` |  |
| apiServer.deployment.envFrom | list | `[]` |  |
| apiServer.deployment.extraEnv | list | `[]` |  |
| apiServer.deployment.initContainers | list | `[]` |  |
| apiServer.deployment.labels | object | `{}` |  |
| apiServer.deployment.nodeSelector | object | `{}` |  |
| apiServer.deployment.podSecurityContext | object | `{}` |  |
| apiServer.deployment.priorityClassName | string | `""` |  |
| apiServer.deployment.replicaCount | int | `1` |  |
| apiServer.deployment.resources.limits.cpu | string | `"2000m"` |  |
| apiServer.deployment.resources.limits.memory | string | `"4Gi"` |  |
| apiServer.deployment.resources.requests.cpu | string | `"1000m"` |  |
| apiServer.deployment.resources.requests.memory | string | `"2Gi"` |  |
| apiServer.deployment.securityContext | object | `{}` |  |
| apiServer.deployment.sidecars | list | `[]` |  |
| apiServer.deployment.tolerations | list | `[]` |  |
| apiServer.deployment.volumeMounts | list | `[]` |  |
| apiServer.deployment.volumes | list | `[]` |  |
| apiServer.name | string | `"api-server"` |  |
| apiServer.pdb.enabled | bool | `false` |  |
| apiServer.pdb.minAvailable | int | `1` |  |
| apiServer.service.annotations | object | `{}` |  |
| apiServer.service.httpPort | int | `80` |  |
| apiServer.service.httpsPort | int | `443` |  |
| apiServer.service.labels | object | `{}` |  |
| apiServer.service.loadBalancerIP | string | `""` |  |
| apiServer.service.loadBalancerSourceRanges | list | `[]` |  |
| apiServer.service.type | string | `"LoadBalancer"` |  |
| apiServer.serviceAccount.annotations | object | `{}` |  |
| apiServer.serviceAccount.create | bool | `true` |  |
| apiServer.serviceAccount.labels | object | `{}` |  |
| apiServer.serviceAccount.name | string | `""` |  |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonVolumeMounts | list | `[]` | Common volume mounts added to all deployments/statefulsets. |
| commonVolumes | list | `[]` | Common volumes added to all deployments/statefulsets. |
| fullnameOverride | string | `""` | String to fully override `"langgraph-cloud.fullname"` |
| images.apiServerImage.pullPolicy | string | `"Always"` |  |
| images.apiServerImage.repository | string | `"docker.io/langchain/langgraph-api"` |  |
| images.apiServerImage.tag | string | `"3.11"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.postgresImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.postgresImage.repository | string | `"pgvector/pgvector"` |  |
| images.postgresImage.tag | string | `"pg16"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"6"` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| images.studioImage.pullPolicy | string | `"Always"` |  |
| images.studioImage.repository | string | `"docker.io/langchain/langgraph-debugger"` |  |
| images.studioImage.tag | string | `"latest"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.studioHostname | string | `""` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraph-cloud` for the chart |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |
| studio.autoscaling.enabled | bool | `false` |  |
| studio.autoscaling.keda.cooldownPeriod | int | `300` |  |
| studio.autoscaling.keda.enabled | bool | `false` |  |
| studio.autoscaling.keda.pollingInterval | int | `30` |  |
| studio.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| studio.autoscaling.maxReplicas | int | `5` |  |
| studio.autoscaling.minReplicas | int | `1` |  |
| studio.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| studio.containerPort | int | `3968` |  |
| studio.deployment.affinity | object | `{}` |  |
| studio.deployment.annotations | object | `{}` |  |
| studio.deployment.extraEnv | list | `[]` |  |
| studio.deployment.labels | object | `{}` |  |
| studio.deployment.nodeSelector | object | `{}` |  |
| studio.deployment.podSecurityContext | object | `{}` |  |
| studio.deployment.priorityClassName | string | `""` |  |
| studio.deployment.replicaCount | int | `1` |  |
| studio.deployment.resources.limits.cpu | string | `"1000m"` |  |
| studio.deployment.resources.limits.memory | string | `"2Gi"` |  |
| studio.deployment.resources.requests.cpu | string | `"500m"` |  |
| studio.deployment.resources.requests.memory | string | `"1Gi"` |  |
| studio.deployment.securityContext | object | `{}` |  |
| studio.deployment.sidecars | list | `[]` |  |
| studio.deployment.tolerations | list | `[]` |  |
| studio.deployment.volumeMounts | list | `[]` |  |
| studio.deployment.volumes | list | `[]` |  |
| studio.enabled | bool | `true` |  |
| studio.localGraphUrl | string | `""` |  |
| studio.name | string | `"studio"` |  |
| studio.pdb.enabled | bool | `false` |  |
| studio.pdb.minAvailable | int | `1` |  |
| studio.service.annotations | object | `{}` |  |
| studio.service.httpPort | int | `80` |  |
| studio.service.httpsPort | int | `443` |  |
| studio.service.labels | object | `{}` |  |
| studio.service.loadBalancerIP | string | `""` |  |
| studio.service.loadBalancerSourceRanges | list | `[]` |  |
| studio.service.type | string | `"LoadBalancer"` |  |
| studio.serviceAccount.annotations | object | `{}` |  |
| studio.serviceAccount.create | bool | `true` |  |
| studio.serviceAccount.labels | object | `{}` |  |
| studio.serviceAccount.name | string | `""` |  |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.auth.enabled | bool | `false` |  |
| config.auth.langSmithAuthEndpoint | string | `""` |  |
| config.auth.langSmithTenantId | string | `""` |  |
| config.existingSecretName | string | `""` |  |
| config.langGraphCloudLicenseKey | string | `""` |  |
| config.numberOfJobsPerWorker | int | `10` |  |

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
| postgres.containerPort | int | `5432` |  |
| postgres.external.connectionUrl | string | `""` |  |
| postgres.external.database | string | `"postgres"` |  |
| postgres.external.enabled | bool | `false` |  |
| postgres.external.existingSecretName | string | `""` |  |
| postgres.external.host | string | `""` |  |
| postgres.external.password | string | `"postgres"` |  |
| postgres.external.port | string | `"5432"` |  |
| postgres.external.schema | string | `"public"` |  |
| postgres.external.user | string | `"postgres"` |  |
| postgres.name | string | `"postgres"` |  |
| postgres.pdb.enabled | bool | `false` |  |
| postgres.pdb.minAvailable | int | `1` |  |
| postgres.service.annotations | object | `{}` |  |
| postgres.service.labels | object | `{}` |  |
| postgres.service.loadBalancerIP | string | `""` |  |
| postgres.service.loadBalancerSourceRanges | list | `[]` |  |
| postgres.service.port | int | `5432` |  |
| postgres.service.type | string | `"ClusterIP"` |  |
| postgres.serviceAccount.annotations | object | `{}` |  |
| postgres.serviceAccount.create | bool | `true` |  |
| postgres.serviceAccount.labels | object | `{}` |  |
| postgres.serviceAccount.name | string | `""` |  |
| postgres.statefulSet.affinity | object | `{}` |  |
| postgres.statefulSet.annotations | object | `{}` |  |
| postgres.statefulSet.command | list | `[]` |  |
| postgres.statefulSet.extraContainerConfig | object | `{}` |  |
| postgres.statefulSet.extraEnv | list | `[]` |  |
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.enabled | bool | `true` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
| postgres.statefulSet.podSecurityContext | object | `{}` |  |
| postgres.statefulSet.priorityClassName | string | `""` |  |
| postgres.statefulSet.resources.limits.cpu | string | `"4000m"` |  |
| postgres.statefulSet.resources.limits.memory | string | `"16Gi"` |  |
| postgres.statefulSet.resources.requests.cpu | string | `"2000m"` |  |
| postgres.statefulSet.resources.requests.memory | string | `"8Gi"` |  |
| postgres.statefulSet.securityContext | object | `{}` |  |
| postgres.statefulSet.sidecars | list | `[]` |  |
| postgres.statefulSet.tolerations | list | `[]` |  |
| postgres.statefulSet.volumeMounts | list | `[]` |  |
| postgres.statefulSet.volumes | list | `[]` |  |

## Queue

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.keda.cooldownPeriod | int | `300` |  |
| queue.autoscaling.keda.enabled | bool | `false` |  |
| queue.autoscaling.keda.pollingInterval | int | `30` |  |
| queue.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| queue.autoscaling.maxReplicas | int | `5` |  |
| queue.autoscaling.minReplicas | int | `1` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| queue.containerPort | int | `8000` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.envFrom | list | `[]` |  |
| queue.deployment.extraEnv | list | `[]` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.priorityClassName | string | `""` |  |
| queue.deployment.replicaCount | int | `1` |  |
| queue.deployment.resources.limits.cpu | string | `"2000m"` |  |
| queue.deployment.resources.limits.memory | string | `"4Gi"` |  |
| queue.deployment.resources.requests.cpu | string | `"1000m"` |  |
| queue.deployment.resources.requests.memory | string | `"2Gi"` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.sidecars | list | `[]` |  |
| queue.deployment.tolerations | list | `[]` |  |
| queue.deployment.volumeMounts | list | `[]` |  |
| queue.deployment.volumes | list | `[]` |  |
| queue.enabled | bool | `false` |  |
| queue.name | string | `"queue"` |  |
| queue.pdb.enabled | bool | `false` |  |
| queue.pdb.minAvailable | int | `1` |  |
| queue.serviceAccount.annotations | object | `{}` |  |
| queue.serviceAccount.create | bool | `true` |  |
| queue.serviceAccount.labels | object | `{}` |  |
| queue.serviceAccount.name | string | `""` |  |

## Redis

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.containerPort | int | `6379` |  |
| redis.deployment.affinity | object | `{}` |  |
| redis.deployment.annotations | object | `{}` |  |
| redis.deployment.command | list | `[]` |  |
| redis.deployment.extraContainerConfig | object | `{}` |  |
| redis.deployment.extraEnv | list | `[]` |  |
| redis.deployment.labels | object | `{}` |  |
| redis.deployment.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.livenessProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.livenessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.livenessProbe.failureThreshold | int | `6` |  |
| redis.deployment.livenessProbe.periodSeconds | int | `10` |  |
| redis.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.nodeSelector | object | `{}` |  |
| redis.deployment.podSecurityContext | object | `{}` |  |
| redis.deployment.priorityClassName | string | `""` |  |
| redis.deployment.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.readinessProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.readinessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.readinessProbe.failureThreshold | int | `6` |  |
| redis.deployment.readinessProbe.periodSeconds | int | `10` |  |
| redis.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.resources.limits.cpu | string | `"2000m"` |  |
| redis.deployment.resources.limits.memory | string | `"4Gi"` |  |
| redis.deployment.resources.requests.cpu | string | `"1000m"` |  |
| redis.deployment.resources.requests.memory | string | `"2Gi"` |  |
| redis.deployment.securityContext | object | `{}` |  |
| redis.deployment.sidecars | list | `[]` |  |
| redis.deployment.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.startupProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.startupProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.startupProbe.failureThreshold | int | `6` |  |
| redis.deployment.startupProbe.periodSeconds | int | `10` |  |
| redis.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.tolerations | list | `[]` |  |
| redis.deployment.volumeMounts | list | `[]` |  |
| redis.deployment.volumes | list | `[]` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.enabled | bool | `false` |  |
| redis.external.existingSecretName | string | `""` |  |
| redis.name | string | `"redis"` |  |
| redis.pdb.enabled | bool | `false` |  |
| redis.pdb.minAvailable | int | `1` |  |
| redis.service.annotations | object | `{}` |  |
| redis.service.labels | object | `{}` |  |
| redis.service.loadBalancerIP | string | `""` |  |
| redis.service.loadBalancerSourceRanges | list | `[]` |  |
| redis.service.port | int | `6379` |  |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.serviceAccount.annotations | object | `{}` |  |
| redis.serviceAccount.create | bool | `true` |  |
| redis.serviceAccount.labels | object | `{}` |  |
| redis.serviceAccount.name | string | `""` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith/README.md.gotmpl`
