# langsmith-auth-proxy

![Version: 0.0.10](https://img.shields.io/badge/Version-0.0.10-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.37.0](https://img.shields.io/badge/AppVersion-1.37.0-informational?style=flat-square)

Helm chart to deploy the langsmith auth-proxy application.

## Request flow

```
Client -> Envoy(:10000)
  -> Health check filter (/healthz bypasses auth)
  -> JWT validation (RS256, configurable issuer + audiences)
  -> [optional] ext_authz HTTP filter (e.g. inject provider API key)
  -> [optional] ext_proc gRPC filter (e.g. transform request/response bodies)
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

## ext_proc transformer integration

For use cases that require **request/response body transformation** (not just header injection), this chart supports Envoy's [ext_proc filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_proc_filter).

### When to use ext_proc vs ext_authz

| Capability | ext_authz | ext_proc (transformer) |
|-----------|-----------|------------------------|
| Modify request headers | Yes | Yes |
| Modify response headers | No | Yes |
| Modify request body | No | Yes |
| Modify response body | No | Yes |
| Protocol | HTTP | gRPC |

Use **ext_authz** if you only need to inject auth headers (e.g. API keys). Use **transformer** (ext_proc) if you need to rewrite request or response bodies — for example, converting between OpenAI format and a custom gateway format.

Both can be enabled simultaneously: ext_authz for auth header injection, transformer for body rewriting.

### gRPC interface

The transformer service must implement the `envoy.service.ext_proc.v3.ExternalProcessor` gRPC service. See [e2e/transformer/](e2e/transformer/) for a sample Go implementation.

### Processing modes

Control which phases are sent to the transformer via `processingMode`:
- **Header modes** (`SEND`, `SKIP`, `DEFAULT`): whether request/response headers are forwarded
- **Body modes** (`NONE`, `STREAMED`, `BUFFERED`, `BUFFERED_PARTIAL`): whether and how bodies are forwarded
- **Trailer modes** (`SEND`, `SKIP`): whether trailers are forwarded

`BUFFERED` mode buffers the entire body before sending — simplest for transformations but uses more memory for large payloads. `STREAMED` sends chunks incrementally (complex to implement). Use `NONE` to skip body processing entirely.

## Custom CA support

Use `customCa.secretName` and `customCa.secretKey` to mount a CA bundle that Envoy should trust for outbound HTTPS connections.

This bundle is applied to every HTTPS peer Envoy validates in this chart:
- The main upstream cluster defined by `authProxy.upstream`
- The remote JWKS cluster when `authProxy.jwksUri` uses `https://`

### Secret example

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: corporate-ca-bundle
type: Opaque
stringData:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

```yaml
customCa:
  secretName: corporate-ca-bundle
  secretKey: ca.crt
```

### Important notes

- Provide the full CA bundle Envoy should trust, not just a single private root. If your upstream or JWKS endpoint chains to public roots as well, include those certificates in the bundle.
- `customCa.secretName` and `customCa.secretKey` must either both be set or both be left empty.
- Envoy reads the CA bundle from a mounted Secret volume. To make trust changes deterministic, roll the pod when the bundle changes.
- Required when using `mtls` — see [mTLS support](#mtls-support) below.

### Rotation workflow

- Preferred: publish a new Secret name such as `corporate-ca-bundle-v2` and update `customCa.secretName`.
- Alternate: keep the same Secret name and bump `customCa.rolloutToken` to force Helm to update the pod template and restart Envoy.

## mTLS support

Use `mtls.secretName`, `mtls.certKey`, and `mtls.keyKey` to present a client certificate when connecting to the upstream. This is required when the upstream enforces mutual TLS.

`customCa` **must** also be configured — without a trusted CA bundle Envoy sends client certificates but does not verify the upstream server's identity, which is not mutual authentication. The chart will fail validation if `mtls` is set without `customCa`.

### Secret example

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: upstream-client-cert
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-client-certificate>
  tls.key: <base64-encoded-client-private-key>
```

```yaml
customCa:
  secretName: corporate-ca-bundle
  secretKey: ca.crt
mtls:
  secretName: upstream-client-cert
  certKey: tls.crt
  keyKey: tls.key
```

### Rotation workflow

- Preferred: publish a new Secret name such as `upstream-client-cert-v2` and update `mtls.secretName`.
- Alternate: keep the same Secret name and bump `mtls.rolloutToken` to force a pod restart.

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
| authProxy.deployment.lifecycle | object | `{}` |  |
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
| authProxy.httpProxy | object | `{"enabled":false,"host":"","noProxy":[],"port":3128}` | HTTP proxy configuration for the upstream cluster. Envoy does not respect HTTP_PROXY/HTTPS_PROXY/NO_PROXY env vars; configure proxy here instead. See https://github.com/envoyproxy/envoy/issues/21175. Uses the two-listener loopback pattern (tcp_proxy + tunneling_config) to route through an HTTP CONNECT proxy. Supports both IP addresses and hostnames for the proxy host. |
| authProxy.httpProxy.enabled | bool | `false` | Enable routing upstream traffic through an HTTP proxy |
| authProxy.httpProxy.host | string | `""` | Proxy hostname or IP address |
| authProxy.httpProxy.noProxy | list | `[]` | List of hostnames/domains to bypass the proxy for (NO_PROXY equivalent). Supports exact match ("internal.corp") and domain suffix (".internal.corp"). If the upstream hostname matches any entry, proxy is not used. |
| authProxy.httpProxy.port | int | `3128` | Proxy port |
| authProxy.jwksCacheDurationSeconds | int | `300` | Cache duration in seconds for remote JWKS keys. Only used when jwksUri is set. |
| authProxy.jwksJson | string | `""` | JWKS JSON string containing the public keys for JWT validation. Generate with the LangSmith JWKS tooling and paste the full JSON here. Mutually exclusive with jwksUri — if both are set, jwksUri takes precedence. |
| authProxy.jwksUri | string | `""` | Remote JWKS endpoint URL for fetching public keys (e.g. https://langsmith.example.com/.well-known/jwks.json for self-hosted LangSmith or https://api.smith.langchain.com/.well-known/jwks.json in SaaS). When set, Envoy fetches and caches keys from this URL instead of using inline jwksJson. Mutually exclusive with jwksJson — if both are set, jwksUri takes precedence. |
| authProxy.jwtAudiences | list | `[]` | JWT audience claims to validate. Must match audiences in the signed JWT. |
| authProxy.jwtIssuer | string | `"langsmith"` | JWT issuer claim to validate |
| authProxy.jwtValidation | object | `{"enabled":true}` | JWT validation configuration |
| authProxy.jwtValidation.enabled | bool | `true` | Set to false to disable the envoy.filters.http.jwt_authn filter entirely. Useful for testing or when JWT validation is handled elsewhere. |
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
| authProxy.transformer.enabled | bool | `false` | Enable the request/response transformer (ext_proc filter). |
| authProxy.transformer.failureModeAllow | bool | `false` | Whether to fail open (allow request) or closed (reject) on transformer errors |
| authProxy.transformer.processingMode | object | `{"requestBodyMode":"NONE","requestHeaderMode":"SEND","requestTrailerMode":"SKIP","responseBodyMode":"NONE","responseHeaderMode":"SKIP","responseTrailerMode":"SKIP"}` | Processing phases to enable. Only enabled phases are sent to the transformer service. Disabling unused phases avoids unnecessary gRPC round-trips and reduces latency. |
| authProxy.transformer.processingMode.requestBodyMode | string | `"NONE"` | Whether and how to send the request body to the transformer. NONE: do not send. BUFFERED: buffer the full body before sending (simplest — good for JSON rewriting). STREAMED: send body chunks as they arrive (lower latency, harder to implement). BUFFERED_PARTIAL: buffer up to the route-level per_route buffer limit, then send what was collected. IMPORTANT: when mutating the body, your ext_proc service MUST also set the content-length header to match the new body size via HeaderMutation in the body response. Envoy rejects responses where content-length doesn't match the mutated body. See e2e/transformer/sample-ext-proc.go for an example. |
| authProxy.transformer.processingMode.requestHeaderMode | string | `"SEND"` | Whether to send request headers to the transformer. SEND: forward headers (use this to read JWTs, inject auth headers, add routing metadata). SKIP: do not forward. DEFAULT: use the server-side default. |
| authProxy.transformer.processingMode.requestTrailerMode | string | `"SKIP"` | Whether to send request trailers to the transformer. SEND or SKIP. Trailers are rarely used in LLM APIs; leave as SKIP unless your upstream requires them. |
| authProxy.transformer.processingMode.responseBodyMode | string | `"NONE"` | Whether and how to send the response body to the transformer. NONE: do not send. BUFFERED: buffer the full body before sending. STREAMED: send body chunks as they arrive (use for SSE/streaming LLM responses — each chunk is forwarded individually). BUFFERED_PARTIAL: buffer up to the route-level per_route buffer limit, then send what was collected. |
| authProxy.transformer.processingMode.responseHeaderMode | string | `"SKIP"` | Whether to send response headers to the transformer. SEND: forward headers (use this to strip, rewrite, or add response headers). SKIP: do not forward. DEFAULT: use the server-side default. |
| authProxy.transformer.processingMode.responseTrailerMode | string | `"SKIP"` | Whether to send response trailers to the transformer. SEND or SKIP. Trailers are rarely used in LLM APIs; leave as SKIP unless your upstream requires them. |
| authProxy.transformer.serviceUrl | string | `""` | gRPC service URL for the transformer (e.g. grpc://my-transformer:50051) |
| authProxy.transformer.timeout | string | `"10s"` | Timeout for transformer calls |
| authProxy.upstream | string | `""` | Upstream LLM provider or gateway URL (e.g. https://gateway.example.com or https://gateway.example.com/api/v1). If a path is included, all requests will be prefixed with it (e.g. /chat/completions becomes /api/v1/chat/completions). |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonDnsConfig | object | `{"options":[{"name":"ndots","value":"4"}]}` | Set to null to disable and use Kubernetes defaults (ndots: 5). |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonPodAnnotations | object | `{}` | Annotations that will be applied to all pods created by the chart |
| commonPodSecurityContext | object | `{}` | Common pod security context applied to all pods. Component-specific podSecurityContext values will be merged on top of this (component values take precedence). |
| customCa | object | `{"rolloutToken":"","secretKey":"","secretName":""}` | Custom CA certificate for upstream TLS verification. Envoy uses BoringSSL and does NOT trust the system CA store. Provide a Kubernetes Secret with your CA bundle to verify upstream HTTPS connections signed by private/internal CAs. |
| customCa.rolloutToken | string | `""` | Optional manual rollout trigger. Bump this when the Secret contents change without changing secretName, so Helm updates the pod template and restarts Envoy. |
| customCa.secretKey | string | `""` | Key within the Secret that holds the CA certificate PEM data |
| customCa.secretName | string | `""` | Name of the Kubernetes Secret containing the CA certificate |
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
