# langgraph-dataplane

![Version: 0.1.17](https://img.shields.io/badge/Version-0.1.17-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

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
| images.listenerImage.tag | string | `"0.10.83"` |  |
| images.operatorImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.operatorImage.repository | string | `"docker.io/langchain/langgraph-operator"` |  |
| images.operatorImage.tag | string | `"f8f6901"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"7"` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| ingress.additionalPaths | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `true` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.tls | list | `[]` |  |
| ingress.tlsEnabled | bool | `true` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraphDataplane` |
| operator.createCRDs | bool | `true` |  |
| operator.deployment.affinity | object | `{}` |  |
| operator.deployment.annotations | object | `{}` |  |
| operator.deployment.autoRestart | bool | `true` |  |
| operator.deployment.extraContainerConfig | object | `{}` |  |
| operator.deployment.extraEnv | list | `[]` |  |
| operator.deployment.labels | object | `{}` |  |
| operator.deployment.nodeSelector | object | `{}` |  |
| operator.deployment.podSecurityContext | object | `{}` |  |
| operator.deployment.replicas | int | `1` |  |
| operator.deployment.resources.limits.cpu | string | `"2000m"` |  |
| operator.deployment.resources.limits.memory | string | `"4Gi"` |  |
| operator.deployment.resources.requests.cpu | string | `"1000m"` |  |
| operator.deployment.resources.requests.memory | string | `"2Gi"` |  |
| operator.deployment.securityContext | object | `{}` |  |
| operator.deployment.sidecars | list | `[]` |  |
| operator.deployment.terminationGracePeriodSeconds | int | `30` |  |
| operator.deployment.tolerations | list | `[]` |  |
| operator.deployment.topologySpreadConstraints | list | `[]` |  |
| operator.deployment.volumeMounts | list | `[]` |  |
| operator.deployment.volumes | list | `[]` |  |
| operator.enabled | bool | `true` |  |
| operator.kedaEnabled | bool | `true` |  |
| operator.name | string | `"operator"` |  |
| operator.pdb.enabled | bool | `false` |  |
| operator.pdb.minAvailable | int | `1` |  |
| operator.rbac.annotations | object | `{}` |  |
| operator.rbac.create | bool | `true` |  |
| operator.rbac.labels | object | `{}` |  |
| operator.service.annotations | object | `{}` |  |
| operator.service.labels | object | `{}` |  |
| operator.service.loadBalancerIP | string | `""` |  |
| operator.service.loadBalancerSourceRanges | list | `[]` |  |
| operator.service.type | string | `"ClusterIP"` |  |
| operator.serviceAccount.annotations | object | `{}` |  |
| operator.serviceAccount.create | bool | `true` |  |
| operator.serviceAccount.labels | object | `{}` |  |
| operator.serviceAccount.name | string | `""` |  |
| operator.templates.deployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${name}\n  template:\n    metadata:\n      labels:\n        app: ${name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: api-server\n        image: ${image}\n        ports:\n        - name: api-server\n          containerPort: 8000\n          protocol: TCP\n        livenessProbe:\n          httpGet:\n            path: /ok?check_db=1\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n        readinessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n"` |  |
| operator.templates.ingress | string | `"apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  rules:\n  - host: ${ingress.hostname}\n    http:\n      paths:\n      - path: /\n        pathType: Prefix\n        backend:\n          service:\n            name: ${name}\n            port:\n              number: 8000\n"` |  |
| operator.templates.service | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  type: ClusterIP\n  selector:\n    app: ${name}\n  ports:\n  - name: api-server\n    protocol: TCP\n    port: 8000\n    targetPort: 8000\n"` |  |
| operator.watchNamespaces | string | `""` |  |

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
| listener.rbac.annotations | object | `{}` |  |
| listener.rbac.create | bool | `true` |  |
| listener.rbac.labels | object | `{}` |  |
| listener.serviceAccount.annotations | object | `{}` |  |
| listener.serviceAccount.create | bool | `true` |  |
| listener.serviceAccount.labels | object | `{}` |  |
| listener.serviceAccount.name | string | `""` |  |
| listener.templates.db | string | `"apiVersion: apps/v1\nkind: StatefulSet\nmetadata:\n  name: ${service_name}\nspec:\n  serviceName: ${service_name}\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${service_name}\n  persistentVolumeClaimRetentionPolicy:\n    whenDeleted: Delete\n    whenScaled: Retain\n  template:\n    metadata:\n      labels:\n        app: ${service_name}\n    spec:\n      containers:\n      - name: postgres\n        image: pgvector/pgvector:pg15\n        ports:\n        - containerPort: 5432\n        command: [\"docker-entrypoint.sh\"]\n        args:\n          - postgres\n          - -c\n          - max_connections=${max_connections}\n        env:\n        - name: POSTGRES_PASSWORD\n          valueFrom:\n            secretKeyRef:\n              name: ${secret_name}\n              key: POSTGRES_PASSWORD\n        - name: POSTGRES_USER\n          value: ${postgres_user}\n        - name: POSTGRES_DB\n          value: ${postgres_db}\n        - name: PGDATA\n          value: /var/lib/postgresql/data/pgdata\n        volumeMounts:\n        - name: postgres-data\n          mountPath: /var/lib/postgresql/data\n        resources:\n          requests:\n            cpu: \"${cpu}\"\n            memory: \"${memory_mb}Mi\"\n          limits:\n            cpu: \"${cpu_limit}\"\n            memory: \"${memory_limit}Mi\"\n      enableServiceLinks: false\n  volumeClaimTemplates:\n  - metadata:\n      name: postgres-data\n    spec:\n      accessModes: [\"ReadWriteOnce\"]\n      resources:\n        requests:\n          storage: \"${storage_gi}Gi\"\n"` |  |
| listener.templates.redis | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${service_name}\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      app: ${service_name}\n  template:\n    metadata:\n      labels:\n        app: ${service_name}\n    spec:\n      containers:\n      - name: redis\n        image: redis:6\n        ports:\n        - containerPort: 6379\n        livenessProbe:\n          exec:\n            command:\n            - redis-cli\n            - ping\n          initialDelaySeconds: 30\n          periodSeconds: 10\n        readinessProbe:\n          tcpSocket:\n            port: 6379\n          initialDelaySeconds: 10\n          periodSeconds: 5\n        resources:\n          requests:\n            cpu: \"1\"\n            memory: \"2048Mi\"\n          limits:\n            cpu: \"1\"\n            memory: \"2048Mi\"\n      enableServiceLinks: false\n"` |  |

## Operator (Optional, deployed as sub-chart)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| operator.createCRDs | bool | `true` |  |
| operator.deployment.affinity | object | `{}` |  |
| operator.deployment.annotations | object | `{}` |  |
| operator.deployment.autoRestart | bool | `true` |  |
| operator.deployment.extraContainerConfig | object | `{}` |  |
| operator.deployment.extraEnv | list | `[]` |  |
| operator.deployment.labels | object | `{}` |  |
| operator.deployment.nodeSelector | object | `{}` |  |
| operator.deployment.podSecurityContext | object | `{}` |  |
| operator.deployment.replicas | int | `1` |  |
| operator.deployment.resources.limits.cpu | string | `"2000m"` |  |
| operator.deployment.resources.limits.memory | string | `"4Gi"` |  |
| operator.deployment.resources.requests.cpu | string | `"1000m"` |  |
| operator.deployment.resources.requests.memory | string | `"2Gi"` |  |
| operator.deployment.securityContext | object | `{}` |  |
| operator.deployment.sidecars | list | `[]` |  |
| operator.deployment.terminationGracePeriodSeconds | int | `30` |  |
| operator.deployment.tolerations | list | `[]` |  |
| operator.deployment.topologySpreadConstraints | list | `[]` |  |
| operator.deployment.volumeMounts | list | `[]` |  |
| operator.deployment.volumes | list | `[]` |  |
| operator.enabled | bool | `true` |  |
| operator.kedaEnabled | bool | `true` |  |
| operator.name | string | `"operator"` |  |
| operator.pdb.enabled | bool | `false` |  |
| operator.pdb.minAvailable | int | `1` |  |
| operator.rbac.annotations | object | `{}` |  |
| operator.rbac.create | bool | `true` |  |
| operator.rbac.labels | object | `{}` |  |
| operator.service.annotations | object | `{}` |  |
| operator.service.labels | object | `{}` |  |
| operator.service.loadBalancerIP | string | `""` |  |
| operator.service.loadBalancerSourceRanges | list | `[]` |  |
| operator.service.type | string | `"ClusterIP"` |  |
| operator.serviceAccount.annotations | object | `{}` |  |
| operator.serviceAccount.create | bool | `true` |  |
| operator.serviceAccount.labels | object | `{}` |  |
| operator.serviceAccount.name | string | `""` |  |
| operator.templates.deployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${name}\n  template:\n    metadata:\n      labels:\n        app: ${name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: api-server\n        image: ${image}\n        ports:\n        - name: api-server\n          containerPort: 8000\n          protocol: TCP\n        livenessProbe:\n          httpGet:\n            path: /ok?check_db=1\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n        readinessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n"` |  |
| operator.templates.ingress | string | `"apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  rules:\n  - host: ${ingress.hostname}\n    http:\n      paths:\n      - path: /\n        pathType: Prefix\n        backend:\n          service:\n            name: ${name}\n            port:\n              number: 8000\n"` |  |
| operator.templates.service | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  type: ClusterIP\n  selector:\n    app: ${name}\n  ports:\n  - name: api-server\n    protocol: TCP\n    port: 8000\n    targetPort: 8000\n"` |  |
| operator.watchNamespaces | string | `""` |  |

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
| redis.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
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
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
