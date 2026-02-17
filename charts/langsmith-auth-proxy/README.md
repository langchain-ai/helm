# langsmith-auth-proxy

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.37.0](https://img.shields.io/badge/AppVersion-1.37.0-informational?style=flat-square)

Helm chart to deploy the langsmith auth-proxy application.

## Request flow

```
Client -> Envoy(:10000)
  -> Health check filter (/healthz bypasses auth)
  -> JWT validation (RS256, configurable issuer + audiences)
  -> [optional] ext_authz HTTP filter (e.g. inject provider API key)
  -> Upstream LLM provider or gateway
```

## ext_authz integration

This integration uses Envoy's [HTTP ext_authz filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_authz_filter) (not gRPC).

When `extAuthz.enabled: true`, Envoy calls the configured service at `/check` before forwarding upstream. The ext_authz service receives the `x-langsmith-llm-auth` header (containing the validated JWT) and can inject/override headers like `Authorization` that get forwarded upstream.

### Interface

This chart uses the **HTTP** `ext_authz` mode — HTTP request in, HTTP response out. The gRPC proto messages (`CheckRequest`, `OkHttpResponse`, etc.) do not apply.

**Request** — Envoy sends an HTTP request to `{serviceUrl}/check{original_path}` with:
- Same HTTP method as the original request
- Headers matching `allowed_headers` patterns (`x-langsmith-llm-auth`, `x-*`)
- Request body only if `sendBody: true`

**Response** — The service returns a plain HTTP response:
- `2xx` → allow: headers matching `allowed_upstream_headers` (`authorization`, `x-langsmith-llm-auth`, `x-forwarded-*`) are forwarded upstream
- Non-`2xx` → deny: status code + headers matching `allowed_client_headers` (`www-authenticate`, `x-*`) are sent back to the client

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| authProxy.autoscaling.hpa.additionalMetrics | list | `[]` |  |
| authProxy.autoscaling.hpa.enabled | bool | `false` |  |
| authProxy.autoscaling.hpa.maxReplicas | int | `5` |  |
| authProxy.autoscaling.hpa.minReplicas | int | `1` |  |
| authProxy.autoscaling.hpa.targetCPUUtilizationPercentage | int | `50` |  |
| authProxy.autoscaling.hpa.targetMemoryUtilizationPercentage | int | `80` |  |
| authProxy.containerPort | int | `10000` |  |
| authProxy.deployment.affinity | object | `{}` |  |
| authProxy.deployment.annotations | object | `{}` |  |
| authProxy.deployment.command[0] | string | `"envoy"` |  |
| authProxy.deployment.command[1] | string | `"-c"` |  |
| authProxy.deployment.command[2] | string | `"/etc/envoy/envoy.yaml"` |  |
| authProxy.deployment.extraContainerConfig | object | `{}` |  |
| authProxy.deployment.extraEnv | list | `[]` |  |
| authProxy.deployment.initContainers | list | `[]` |  |
| authProxy.deployment.labels | object | `{}` |  |
| authProxy.deployment.livenessProbe.failureThreshold | int | `6` |  |
| authProxy.deployment.livenessProbe.httpGet.path | string | `"/healthz"` |  |
| authProxy.deployment.livenessProbe.httpGet.port | int | `10000` |  |
| authProxy.deployment.livenessProbe.periodSeconds | int | `10` |  |
| authProxy.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| authProxy.deployment.nodeSelector | object | `{}` |  |
| authProxy.deployment.podSecurityContext | object | `{}` |  |
| authProxy.deployment.readinessProbe.failureThreshold | int | `6` |  |
| authProxy.deployment.readinessProbe.httpGet.path | string | `"/healthz"` |  |
| authProxy.deployment.readinessProbe.httpGet.port | int | `10000` |  |
| authProxy.deployment.readinessProbe.periodSeconds | int | `10` |  |
| authProxy.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| authProxy.deployment.replicas | int | `1` |  |
| authProxy.deployment.resources.limits.cpu | string | `"500m"` |  |
| authProxy.deployment.resources.limits.memory | string | `"256Mi"` |  |
| authProxy.deployment.resources.requests.cpu | string | `"100m"` |  |
| authProxy.deployment.resources.requests.memory | string | `"128Mi"` |  |
| authProxy.deployment.securityContext | object | `{}` |  |
| authProxy.deployment.sidecars | list | `[]` |  |
| authProxy.deployment.startupProbe.failureThreshold | int | `6` |  |
| authProxy.deployment.startupProbe.httpGet.path | string | `"/healthz"` |  |
| authProxy.deployment.startupProbe.httpGet.port | int | `10000` |  |
| authProxy.deployment.startupProbe.periodSeconds | int | `10` |  |
| authProxy.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| authProxy.deployment.terminationGracePeriodSeconds | int | `30` |  |
| authProxy.deployment.tolerations | list | `[]` |  |
| authProxy.deployment.topologySpreadConstraints | list | `[]` |  |
| authProxy.deployment.volumeMounts | list | `[]` |  |
| authProxy.deployment.volumes | list | `[]` |  |
| authProxy.enabled | bool | `true` |  |
| authProxy.extAuthz.allowedHeadersRegex | string | `".*"` | Regex controlling which client request headers are forwarded to the ext_authz service. Defaults to all headers. Maps to http_service.allowed_headers. Uses Google RE2 syntax: https://github.com/google/re2/wiki/Syntax. |
| authProxy.extAuthz.allowedUpstreamHeaders | list | `[{exact: "authorization"}, {prefix: "x-"}]` | Patterns controlling which ext_authz response headers are forwarded upstream (authorization_response.allowed_upstream_headers). Each entry is an object with one of these keys: `exact`, `prefix`, or `safe_regex`. |
| authProxy.extAuthz.disallowedHeadersRegex | string | `""` | Regex controlling which client request headers are NOT forwarded to the ext_authz service (higher precedence than allowedHeadersRegex). Maps to http_service.disallowed_headers. Uses Google RE2 syntax: https://github.com/google/re2/wiki/Syntax. |
| authProxy.extAuthz.enabled | bool | `false` |  |
| authProxy.extAuthz.headersToAdd | list | `[]` | Static headers to add to every ext_authz check request (authorization_request.headers_to_add). Example: [{key: "x-auth-context", value: "langsmith"}] |
| authProxy.extAuthz.maxRequestBytes | int | `8192` | Maximum request body bytes to buffer for ext_authz |
| authProxy.extAuthz.sendBody | bool | `false` | Whether to send the request body to ext_authz |
| authProxy.extAuthz.serviceUrl | string | `""` | HTTP service URL for ext_authz (e.g. http://my-auth-service:8080) |
| authProxy.extAuthz.timeout | string | `"10s"` | Timeout for ext_authz requests |
| authProxy.jwksJson | string | `""` | JWKS JSON string containing the public keys for JWT validation. Generate with the LangSmith JWKS tooling and paste the full JSON here. |
| authProxy.jwtAudiences | list | `[]` | JWT audience claims to validate. Must match audiences in the signed JWT. |
| authProxy.jwtIssuer | string | `"langsmith"` | JWT issuer claim to validate |
| authProxy.name | string | `"auth-proxy"` |  |
| authProxy.pdb.annotations | object | `{}` |  |
| authProxy.pdb.enabled | bool | `false` |  |
| authProxy.pdb.labels | object | `{}` |  |
| authProxy.pdb.minAvailable | int | `1` |  |
| authProxy.rollout | object | `{"enabled":false,"strategy":{"canary":{"steps":[{"setWeight":100}]}}}` | ArgoCD Rollouts configuration. If enabled, will create a Rollout resource instead of a Deployment. See https://argo-rollouts.readthedocs.io/ |
| authProxy.rollout.strategy | object | `{"canary":{"steps":[{"setWeight":100}]}}` | Rollout strategy configuration. See https://argo-rollouts.readthedocs.io/en/stable/features/specification/ |
| authProxy.service.annotations | object | `{}` |  |
| authProxy.service.labels | object | `{}` |  |
| authProxy.service.loadBalancerIP | string | `""` |  |
| authProxy.service.loadBalancerSourceRanges | list | `[]` |  |
| authProxy.service.port | int | `10000` |  |
| authProxy.service.type | string | `"ClusterIP"` |  |
| authProxy.serviceAccount.annotations | object | `{}` |  |
| authProxy.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| authProxy.serviceAccount.create | bool | `true` |  |
| authProxy.serviceAccount.labels | object | `{}` |  |
| authProxy.serviceAccount.name | string | `""` |  |
| authProxy.streamIdleTimeout | string | `"300s"` | Idle timeout for streaming responses (e.g. SSE from LLM providers) |
| authProxy.upstream | string | `""` | Upstream LLM provider URL (e.g. https://api.openai.com) |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonPodAnnotations | object | `{}` | Annotations that will be applied to all pods created by the chart |
| commonPodSecurityContext | object | `{}` | Common pod security context applied to all pods. Component-specific podSecurityContext values will be merged on top of this (component values take precedence). |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| gateway | object | `{"annotations":{},"enabled":false,"hostnames":[],"labels":{},"name":"","namespace":"","sectionName":""}` | Gateway API HTTPRoute configuration |
| gateway.hostnames | list | `[]` | Hostnames to match on |
| gateway.name | string | `""` | Name of the Gateway resource to attach to |
| gateway.namespace | string | `""` | Namespace of the Gateway resource (if different from chart namespace) |
| gateway.sectionName | string | `""` | SectionName of the Gateway listener to attach to |
| images.authProxyImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.authProxyImage.repository | string | `"docker.io/envoyproxy/envoy"` |  |
| images.authProxyImage.tag | string | `"v1.37-latest"` |  |
| images.imagePullSecrets | list | `[]` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| ingress | object | `{"annotations":{},"enabled":false,"hosts":[],"ingressClassName":"","labels":{},"tls":[]}` | Ingress configuration |
| ingress.annotations | object | `{}` | Annotations for streaming support. Defaults shown are for nginx ingress controller. |
| nameOverride | string | `""` | Provide a name in place of `langsmith-auth-proxy` |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |

## E2E tests

See [e2e/README.md](e2e/README.md) for local end-to-end testing with kind.

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Brian | <brian@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith-auth-proxy/README.md.gotmpl`
