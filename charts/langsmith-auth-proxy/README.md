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

This integration uses Envoy's [ext_authz filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_authz_filter).
Requ

When `extAuthz.enabled: true`, Envoy calls the configured service at `/check` before forwarding upstream. The ext_authz service receives the `x-langsmith-llm-auth` header (containing the validated JWT) and can inject/override headers like `Authorization` that get forwarded upstream.

### Interface

Input structure is defined [here](https://www.envoyproxy.io/docs/envoy/latest/api-v3/service/auth/v3/external_auth.proto#envoy-v3-api-msg-service-auth-v3-checkrequest).

```json
{
  "attributes": {
    "
  }
}
```

## E2E tests

See [e2e/README.md](e2e/README.md) for local end-to-end testing with kind.
