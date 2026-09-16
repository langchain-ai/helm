# langsmith-connector

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart for the LangSmith tunnel connector. It runs inside your network and connects outbound to LangSmith so LangSmith products can reach your private services.

## What it does

The connector runs inside your network. It opens an outbound WebSocket to LangSmith and keeps two redundant sessions alive. When a LangSmith product needs to reach one of your private services, LangSmith sends the request over that tunnel and the connector forwards it to the target you named. Nothing needs to reach the connector pod: it exposes no ports.

## Prerequisites

1. In LangSmith, open Settings -> Tunnels and create a tunnel. Copy its connection ID.
2. Create an organization API key that can connect tunnels (the `connections:connect` permission).

## Installation

```bash
helm repo add langchain https://langchain-ai.github.io/helm/
helm repo update

helm install langsmith-connector langchain/langsmith-connector \
  --namespace langsmith-connector --create-namespace \
  --set connector.connectionId=<connection id> \
  --set connector.apiKey=<api key> \
  --set connector.targets.api=https://api.internal.example:8443 \
  --set connector.targets.database=db.internal.example:5432
```

To keep the API key out of Helm values, create a Secret and reference it:

```bash
kubectl -n langsmith-connector create secret generic langsmith-connector-key --from-literal=api-key=<api key>
helm install langsmith-connector langchain/langsmith-connector \
  --namespace langsmith-connector \
  --set connector.connectionId=<connection id> \
  --set connector.existingSecret=langsmith-connector-key \
  --set connector.targets.api=https://api.internal.example:8443
```

The key is mounted as a file and re-read on every reconnect, so rotating the Secret needs no restart.

Self-hosted LangSmith: set `connector.endpoint` to your API origin, including any `/api` prefix.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonDnsConfig | object | `{"options":[{"name":"ndots","value":"4"}]}` | Common DNS configuration applied to all pods. Reduces DNS query amplification in Kubernetes by ensuring service FQDNs (which have 4 dots) are resolved directly without search domain expansion. Set to null to disable and use Kubernetes defaults (ndots: 5). |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonPodAnnotations | object | `{}` | Annotations that will be applied to all pods created by the chart |
| commonPodSecurityContext | object | `{}` | Common pod security context applied to all pods. `connector.podSecurityContext` is merged on top of this (connector values take precedence). |
| connector.affinity | object | `{}` |  |
| connector.annotations | object | `{}` | Annotations added to the Deployment and its pods. |
| connector.apiKey | string | `""` | LangSmith API key with the `connections:connect` permission. Creates a chart-managed Secret. Mutually exclusive with `existingSecret`. |
| connector.connectionId | required | `""` | The tunnel's connection ID, copied from Settings -> Tunnels in LangSmith. |
| connector.endpoint | string | `"https://api.smith.langchain.com"` | LangSmith API URL. Self-hosted installs use their own API origin, including any `/api` prefix. |
| connector.existingSecret | string | `""` | Name of an existing Secret holding the API key. Mutually exclusive with `apiKey`. |
| connector.existingSecretKey | string | `"api-key"` | Key inside `existingSecret` that holds the API key. |
| connector.extraEnv | list | `[]` | Additional environment variables for the connector container. |
| connector.labels | object | `{}` | Labels added to the Deployment and its pods. |
| connector.nodeSelector | object | `{}` |  |
| connector.podSecurityContext | object | `{"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context, merged over commonPodSecurityContext. The image runs as UID 1000. |
| connector.replicas | int | `1` | Number of connector pods. One pod already holds two redundant sessions to LangSmith. |
| connector.resources.limits.cpu | string | `"500m"` |  |
| connector.resources.limits.memory | string | `"256Mi"` |  |
| connector.resources.requests.cpu | string | `"50m"` |  |
| connector.resources.requests.memory | string | `"64Mi"` |  |
| connector.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container-level security context. |
| connector.targets | required | `{}` | Target name to address. HTTP targets carry a scheme (`https://svc.internal:8443`); TCP targets are `host:port`. At least one target is required; the connector exits when the map is empty. Each entry becomes part of LANGSMITH_CONNECTOR_TARGETS. |
| connector.terminationGracePeriodSeconds | int | `45` | Covers the connector's 30 second drain grace on SIGTERM. |
| connector.tolerations | list | `[]` |  |
| fullnameOverride | string | `""` | String to fully override `"connector.fullname"` |
| images.connectorImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.connectorImage.repository | string | `"docker.io/langchain/langsmith-connector"` |  |
| images.connectorImage.tag | string | `"0.1.0"` |  |
| images.imagePullSecrets | list | `[]` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| nameOverride | string | `""` | Provide a name in place of `langsmith-connector` |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Mukil | <mukil@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith-connector/README.md.gotmpl`
