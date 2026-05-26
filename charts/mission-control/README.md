# mission-control

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![AppVersion: 2.0.0](https://img.shields.io/badge/AppVersion-2.0.0-informational?style=flat-square)

Mission Control to deploy and manage Langsmith in EKS

A web console that runs **inside your Kubernetes cluster** to deploy and manage LangSmith (and peer LangChain Helm releases). Access is via `kubectl port-forward` — no ingress required.

## Quick start

```bash
helm repo add langchain https://langchain-ai.github.io/helm/
helm repo update

helm upgrade --install mission-control langchain/mission-control \
  --namespace langsmith \
  --create-namespace \
  --atomic

kubectl port-forward svc/mission-control-frontend 3000:3000 -n langsmith
# → http://localhost:3000
```

On first install (when `auth.enabled: true`, the default), `helm install` prints a one-time setup token. Paste it into the Mission Control setup form to create the auth secret. The token secret is deleted automatically once setup completes.

## Features

- **Configuration** — fetches the upstream chart's `values.yaml` from GitHub and renders every field as a typed form. Bidirectional YAML editor, draft auto-save, colour-coded diff before deploy.
- **Health Status** — node + pod metrics, networking topology, storage, events. Auto-refreshes.
- **Preflight Checks** — pre-deploy validation per product (LangSmith, LangGraph Cloud, LangGraph Dataplane, Auth Proxy, Observability, Hybrid).
- **Releases** — lists chart versions per product with GitHub release notes; highlights the deployed version.
- **Diagnostic Logs** — one-click bundle of pod logs + `kubectl describe` output as a zip.
- **Alerts** — configurable email + webhook notifications on cluster conditions.
- **Chat Assistant** — in-app LangChain docs agent.

## Enterprise / compliance

All write operations and external egress are gated behind Helm feature flags. With every flag off the ClusterRole is read-only.

| Flag | Default | Controls |
|---|---|---|
| `features.fixIssue` | `true` | Pod deletion (Fix Issue button) |
| `features.adopt` | `true` | Helm ownership patching (Adopt button) |
| `features.alerts` | `true` | SMTP / webhook alert notifications |
| `features.chat` | `true` | Chat assistant — outbound egress to LangChain/LangGraph |
| `features.diagnostics` | `true` | Diagnostic log bundle download |
| `features.configSave` | `true` | Draft config persistence to a K8s Secret |
| `features.discover` | `true` | Infra discovery scan (connection strings, license keys) |
| `features.deploy` | `true` | In-UI `helm upgrade --install` (LangSmith + sibling charts) |

Read-only console — zero write verbs, no external egress:

```bash
helm upgrade --install mission-control langchain/mission-control \
  --namespace langsmith \
  --set features.fixIssue=false \
  --set features.adopt=false \
  --set features.alerts=false \
  --set features.chat=false \
  --set features.diagnostics=false \
  --set features.configSave=false \
  --set features.discover=false
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.extraEnv | list | `[]` | Additional environment variables passed to the backend container. |
| backend.podSecurityContext | object | `{}` | Pod-level security context. |
| backend.replicas | int | `1` | Replica count. Set > 1 only when config.auth.jwtSecretKey is set so all pods validate each other's tokens. |
| backend.resources.limits.cpu | string | `"500m"` |  |
| backend.resources.limits.memory | string | `"512Mi"` |  |
| backend.resources.requests.cpu | string | `"250m"` |  |
| backend.resources.requests.memory | string | `"256Mi"` |  |
| backend.securityContext | object | `{}` | Container-level security context. |
| backend.service.port | int | `8000` |  |
| backend.service.type | string | `"ClusterIP"` | Internal Service type; port-forward is the default access path. |
| backend.serviceAccount.create | bool | `true` | When true (default) the chart creates a ServiceAccount, ClusterRole, and ClusterRoleBinding. Set to false to bring your own ServiceAccount; you must then grant it the same RBAC. |
| backend.serviceAccount.name | string | `""` | Override the generated ServiceAccount name. |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonPodAnnotations | object | `{}` | Annotations that will be applied to all pods created by the chart |
| config.auth.allowedOrigins | string | `""` | Optional: comma-separated list of origins allowed to make credentialed requests. Required only when the backend and frontend are served from different hostnames. |
| config.auth.enabled | bool | `true` |  |
| config.auth.existingSecret | string | `"mission-control-auth"` | Pre-created Secret with username/password (and optionally JWT signing) keys. Leave as-is to use the first-run setup flow described above. |
| config.auth.jwtSecretKey | string | `""` | Optional: key in `existingSecret` holding the JWT signing secret. Required when backend.replicas > 1 so all pods can validate each other's tokens. Generate with: openssl rand -base64 32 |
| config.auth.passwordKey | string | `"password"` | Key in `existingSecret` holding the basic-auth password. |
| config.auth.usernameKey | string | `"username"` | Key in `existingSecret` holding the basic-auth username. |
| config.discoverNamespaces | string | `""` | Extra namespaces (comma-separated) the discover feature is allowed to scan. Default scans only the chart's release namespace to prevent cross-namespace secret disclosure on shared clusters. Add namespaces only when you trust every listed namespace. Example: "langsmith,monitoring" |
| config.features.adopt | bool | `true` | Adopt button: patches Helm ownership metadata onto existing resources. Grants secrets/configmaps/serviceaccounts/deployments/statefulsets:patch. |
| config.features.alerts | bool | `true` | Alert notifications (SMTP + webhook). Grants write access to alert-config secrets. Egress: outbound SMTP and webhook to the configured endpoints. |
| config.features.chat | bool | `true` | Chat assistant: floating widget that proxies to chat.langchain.com. Egress: outbound HTTPS to chat.langchain.com and *.us.langgraph.app. |
| config.features.configSave | bool | `true` | Persists working configuration to the draft Kubernetes Secret. Grants write access to the mission-control-draft secret. |
| config.features.dbTools | bool | `true` | Database detection, preflight checks, and support query execution. Adds no extra RBAC verbs; gates the /db/* endpoints at the application layer. |
| config.features.deploy | bool | `true` | In-UI `helm upgrade --install` for LangSmith and sibling charts. Grants broad write RBAC on secrets/configmaps cluster-wide (required for Helm). Set to `false` in compliance-sensitive installs to revert to read-mostly mode. |
| config.features.valuesOverride | bool | `false` | Server-side values override layer applied on top of every deploy. When enabled, operators can lock specific Helm values that users cannot override from the UI. |
| config.features.diagnostics | bool | `true` | Diagnostic bundle download (pod logs + resource manifests packaged as a zip). |
| config.features.discover | bool | `true` | Namespace-scoped infrastructure discovery via the /api/discover endpoint. Adds no extra RBAC verbs; gates the endpoint at the application layer. |
| config.features.fixIssue | bool | `true` | Fix Issue button: deletes pods stuck in CreateContainerConfigError. Grants pods:delete. |
| diagnostics.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| diagnostics.persistence.enabled | bool | `false` |  |
| diagnostics.persistence.size | string | `"1Gi"` |  |
| diagnostics.persistence.storageClass | string | `""` | Leave empty to use the cluster default StorageClass. |
| frontend.extraEnv | list | `[]` | Additional environment variables passed to the frontend container. |
| frontend.podSecurityContext | object | `{}` | Pod-level security context. |
| frontend.replicas | int | `1` | Replica count. |
| frontend.resources.limits.cpu | string | `"200m"` |  |
| frontend.resources.limits.memory | string | `"256Mi"` |  |
| frontend.resources.requests.cpu | string | `"100m"` |  |
| frontend.resources.requests.memory | string | `"128Mi"` |  |
| frontend.securityContext | object | `{}` | Container-level security context. |
| frontend.service.port | int | `3000` |  |
| frontend.service.type | string | `"ClusterIP"` |  |
| fullnameOverride | string | `""` | String to fully override the chart's full name |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"langchain/mission-control-backend"` |  |
| images.backendImage.tag | string | `"latest"` | Backend image tag. Defaults to `latest`; pin to a specific release like `1.0.0` for reproducible deploys. Versioned tags are published alongside `latest` on every release. |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"langchain/mission-control-frontend"` |  |
| images.frontendImage.tag | string | `"latest"` | Frontend image tag. Defaults to `latest`; pin to a specific release like `1.0.0` for reproducible deploys. Versioned tags are published alongside `latest` on every release. |
| images.imagePullSecrets | list | `[{"name":"regcred"}]` | Image pull secrets used by all components. |
| images.registry | string | `""` | If supplied, all child <image>.repository values will be prepended with this registry name + `/` |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `""` |  |
| nameOverride | string | `""` | Provide a name in place of `mission-control` |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./README.md.gotmpl`
