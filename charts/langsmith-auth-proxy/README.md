# langsmith-auth-proxy

Helm chart that deploys an Envoy-based proxy for validating LangSmith-signed JWTs and optionally calling an external authorization service before forwarding requests to an upstream LLM provider or gateway.

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

## E2E tests

See [e2e/README.md](e2e/README.md) for local end-to-end testing with kind.
