# langgraph-operator

![Version: 0.1.10](https://img.shields.io/badge/Version-0.1.10-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the LangGraph Operator

## Deploying a LangGraph Operator with Helm

### TODO: Add instructions for deploying the chart

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonEnv | list | `[]` | Common environment variables that will be applied to all deployments |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langgraphOperator.fullname"` |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.operatorImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.operatorImage.repository | string | `"docker.io/langchain/langgraph-operator"` |  |
| images.operatorImage.tag | string | `"fb9e98d"` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraphOperator` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.createCRDs | bool | `true` |  |
| config.kedaEnabled | bool | `true` |  |
| config.watchNamespaces | string | `""` |  |

## Operator

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| manager.deployment.affinity | object | `{}` |  |
| manager.deployment.annotations | object | `{}` |  |
| manager.deployment.autoRestart | bool | `true` |  |
| manager.deployment.extraContainerConfig | object | `{}` |  |
| manager.deployment.extraEnv | list | `[]` |  |
| manager.deployment.labels | object | `{}` |  |
| manager.deployment.nodeSelector | object | `{}` |  |
| manager.deployment.podSecurityContext | object | `{}` |  |
| manager.deployment.replicas | int | `1` |  |
| manager.deployment.resources.limits.cpu | string | `"2000m"` |  |
| manager.deployment.resources.limits.memory | string | `"4Gi"` |  |
| manager.deployment.resources.requests.cpu | string | `"1000m"` |  |
| manager.deployment.resources.requests.memory | string | `"2Gi"` |  |
| manager.deployment.securityContext | object | `{}` |  |
| manager.deployment.sidecars | list | `[]` |  |
| manager.deployment.terminationGracePeriodSeconds | int | `30` |  |
| manager.deployment.tolerations | list | `[]` |  |
| manager.deployment.topologySpreadConstraints | list | `[]` |  |
| manager.deployment.volumeMounts | list | `[]` |  |
| manager.deployment.volumes | list | `[]` |  |
| manager.name | string | `"manager"` |  |
| manager.pdb.enabled | bool | `false` |  |
| manager.pdb.minAvailable | int | `1` |  |
| manager.rbac.annotations | object | `{}` |  |
| manager.rbac.create | bool | `true` |  |
| manager.rbac.labels | object | `{}` |  |
| manager.serviceAccount.annotations | object | `{}` |  |
| manager.serviceAccount.create | bool | `true` |  |
| manager.serviceAccount.labels | object | `{}` |  |
| manager.serviceAccount.name | string | `""` |  |
| manager.templates.databaseService | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${database.name}\n  namespace: ${namespace}\nspec:\n  selector:\n    app: ${database.name}\n  ports:\n    - port: 5432\n      targetPort: 5432\n  clusterIP: None\n"` |  |
| manager.templates.databaseStatefulSet | string | `"apiVersion: apps/v1\nkind: StatefulSet\nmetadata:\n  name: ${database.name}\n  namespace: ${namespace}\nspec:\n  serviceName: ${database.name}\n  selector:\n    matchLabels:\n      app: ${database.name}\n  template:\n    metadata:\n      labels:\n        app: ${database.name}\n    spec:\n      enableServiceLinks: false\n      containers:\n        - name: postgres\n          image: docker.io/pgvector/pgvector:pg15\n          ports:\n            - containerPort: 5432\n          command: [\"docker-entrypoint.sh\"]\n          args:\n            - postgres\n            - -c\n            - max_connections=${database.maxConnections}\n          env:\n            - name: POSTGRES_USER\n              value: postgres\n            - name: POSTGRES_DB\n              value: postgres\n            - name: POSTGRES_PASSWORD\n              valueFrom:\n                secretKeyRef:\n                  name: ${database.secretName}\n                  key: POSTGRES_PASSWORD\n          volumeMounts:\n            - name: postgres-data\n              mountPath: /var/lib/postgresql/data\n  volumeClaimTemplates:\n    - metadata:\n        name: postgres-data\n      spec:\n        accessModes: [\"ReadWriteOnce\"]\n        resources:\n          requests:\n            storage: \"${database.storageSizeGi}Gi\"\n"` |  |
| manager.templates.deployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${name}\n  template:\n    metadata:\n      labels:\n        app: ${name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: api-server\n        image: ${image}\n        ports:\n        - name: api-server\n          containerPort: 8000\n          protocol: TCP\n        livenessProbe:\n          httpGet:\n            path: /ok?check_db=1\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n        readinessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n"` |  |
| manager.templates.ingress | string | `"apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  ingressClassName: ${ingress.ingressClassName}\n  rules:\n  - host: ${ingress.hostname}\n    http:\n      paths:\n      - path: /\n        pathType: Prefix\n        backend:\n          service:\n            name: ${name}\n            port:\n              number: 8000\n"` |  |
| manager.templates.redisDeployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${redis.name}\n  namespace: ${namespace}\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      app: ${redis.name}\n  template:\n    metadata:\n      labels:\n        app: ${redis.name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: redis\n        image: docker.io/redis:7\n        ports:\n        - containerPort: 6379\n          name: redis\n        livenessProbe:\n          exec:\n            command:\n            - redis-cli\n            - ping\n          initialDelaySeconds: 30\n          periodSeconds: 10\n        readinessProbe:\n          tcpSocket:\n            port: 6379\n          initialDelaySeconds: 10\n          periodSeconds: 5\n"` |  |
| manager.templates.redisService | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${redis.name}\n  namespace: ${namespace}\n  labels:\n    app: ${redis.name}\nspec:\n  ports:\n  - port: 6379\n    targetPort: 6379\n    protocol: TCP\n    name: redis\n  selector:\n    app: ${redis.name}\n  type: ClusterIP\n"` |  |
| manager.templates.service | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  type: ClusterIP\n  selector:\n    app: ${name}\n  ports:\n  - name: api-server\n    protocol: TCP\n    port: 8000\n    targetPort: 8000\n"` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
