# langgraph-dataplane

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy a langgraph dataplane on kubernetes.

## Deploying a LangGraph Dataplane

### TODO: ADD README for LangGraph Dataplane Chart

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonEnv | list | `[]` | Common environment variables that will be applied to all deployments. |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langgraphDataplane.fullname"` |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.listenerImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.listenerImage.repository | string | `"docker.io/langchain/hosted-langserve-backend"` |  |
| images.listenerImage.tag | string | `"0.9.68"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"7"` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraphDataplane` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.existingSecretName | string | `""` |  |
| config.hostBackendUrl | string | `"https://api.host.langchain.com"` |  |
| config.langsmithApiKey | string | `""` |  |
| config.langsmithWorkspaceId | string | `""` |  |
| config.smithBackendUrl | string | `"https://api.smith.langchain.com"` |  |

## Listener

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| listener.autoscaling.createHpa | bool | `true` |  |
| listener.autoscaling.enabled | bool | `false` |  |
| listener.autoscaling.maxReplicas | int | `10` |  |
| listener.autoscaling.minReplicas | int | `3` |  |
| listener.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| listener.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| listener.deployment.affinity | object | `{}` |  |
| listener.deployment.annotations | object | `{}` |  |
| listener.deployment.autoRestart | bool | `true` |  |
| listener.deployment.command[0] | string | `"saq"` |  |
| listener.deployment.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.command[2] | string | `"--quiet"` |  |
| listener.deployment.extraContainerConfig | object | `{}` |  |
| listener.deployment.extraEnv | list | `[]` |  |
| listener.deployment.labels | object | `{}` |  |
| listener.deployment.livenessProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.livenessProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.livenessProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.livenessProbe.failureThreshold | int | `6` |  |
| listener.deployment.livenessProbe.periodSeconds | int | `60` |  |
| listener.deployment.livenessProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.nodeSelector | object | `{}` |  |
| listener.deployment.podSecurityContext | object | `{}` |  |
| listener.deployment.readinessProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.readinessProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.readinessProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.readinessProbe.failureThreshold | int | `6` |  |
| listener.deployment.readinessProbe.periodSeconds | int | `60` |  |
| listener.deployment.readinessProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.replicas | int | `1` |  |
| listener.deployment.resources.limits.cpu | string | `"2000m"` |  |
| listener.deployment.resources.limits.memory | string | `"4Gi"` |  |
| listener.deployment.resources.requests.cpu | string | `"1000m"` |  |
| listener.deployment.resources.requests.memory | string | `"2Gi"` |  |
| listener.deployment.securityContext | object | `{}` |  |
| listener.deployment.sidecars | list | `[]` |  |
| listener.deployment.startupProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.startupProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.startupProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.startupProbe.failureThreshold | int | `6` |  |
| listener.deployment.startupProbe.periodSeconds | int | `60` |  |
| listener.deployment.startupProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.terminationGracePeriodSeconds | int | `30` |  |
| listener.deployment.tolerations | list | `[]` |  |
| listener.deployment.topologySpreadConstraints | list | `[]` |  |
| listener.deployment.volumeMounts | list | `[]` |  |
| listener.deployment.volumes | list | `[]` |  |
| listener.name | string | `"listener"` |  |
| listener.pdb.enabled | bool | `false` |  |
| listener.pdb.minAvailable | int | `1` |  |
| listener.serviceAccount.annotations | object | `{}` |  |
| listener.serviceAccount.create | bool | `true` |  |
| listener.serviceAccount.labels | object | `{}` |  |
| listener.serviceAccount.name | string | `""` |  |

## Redis

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.containerPort | int | `6379` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.connectionUrlSecretKey | string | `"connection_url"` |  |
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
| redis.statefulSet.affinity | object | `{}` |  |
| redis.statefulSet.annotations | object | `{}` |  |
| redis.statefulSet.command | list | `[]` |  |
| redis.statefulSet.extraContainerConfig | object | `{}` |  |
| redis.statefulSet.extraEnv | list | `[]` |  |
| redis.statefulSet.labels | object | `{}` |  |
| redis.statefulSet.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.livenessProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.livenessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.nodeSelector | object | `{}` |  |
| redis.statefulSet.persistence.enabled | bool | `true` |  |
| redis.statefulSet.persistence.size | string | `"8Gi"` |  |
| redis.statefulSet.persistence.storageClassName | string | `""` |  |
| redis.statefulSet.podSecurityContext | object | `{}` |  |
| redis.statefulSet.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.readinessProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.readinessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.resources.limits.cpu | string | `"4000m"` |  |
| redis.statefulSet.resources.limits.memory | string | `"8Gi"` |  |
| redis.statefulSet.resources.requests.cpu | string | `"2000m"` |  |
| redis.statefulSet.resources.requests.memory | string | `"4Gi"` |  |
| redis.statefulSet.securityContext | object | `{}` |  |
| redis.statefulSet.sidecars | list | `[]` |  |
| redis.statefulSet.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.startupProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.startupProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.tolerations | list | `[]` |  |
| redis.statefulSet.topologySpreadConstraints | list | `[]` |  |
| redis.statefulSet.volumeMounts | list | `[]` |  |
| redis.statefulSet.volumes | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
