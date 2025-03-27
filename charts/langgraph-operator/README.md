# langgraph-operator

![Version: 0.1.8](https://img.shields.io/badge/Version-0.1.8-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

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
| images.operatorImage.tag | string | `"aa9dff4"` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraphOperator` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.createCRDs | bool | `true` |  |
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
| manager.templates.deployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${name}\n  template:\n    metadata:\n      labels:\n        app: ${name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: api-server\n        image: ${image}\n        ports:\n        - name: api-server\n          containerPort: 8000\n          protocol: TCP\n        livenessProbe:\n          httpGet:\n            path: /ok?check_db=1\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n        readinessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          initialDelaySeconds: 90\n          periodSeconds: 5\n          timeoutSeconds: 5\n"` |  |
| manager.templates.ingress | string | `"apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  ingressClassName: ${ingress.ingressClassName}\n  rules:\n  - host: ${ingress.hostname}\n    http:\n      paths:\n      - path: /\n        pathType: Prefix\n        backend:\n          service:\n            name: ${name}\n            port:\n              number: 8000\n"` |  |
| manager.templates.service | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  type: ClusterIP\n  selector:\n    app: ${name}\n  ports:\n  - name: api-server\n    protocol: TCP\n    port: 8000\n    targetPort: 8000\n"` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
