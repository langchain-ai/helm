# OAuth Token Exchange Example

Deploys the auth-proxy with a Python sidecar that performs the [OAuth2 client credentials grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4) on every request. The sidecar acts as the Envoy ext_authz service — it fetches (and caches) an access token from your identity provider, then injects it as the `Authorization: Bearer <token>` header on the request forwarded to the upstream LLM provider.

## Prerequisites

`kind`, `helm`, `kubectl`

## Request flow

```
Client -H "X-LangSmith-LLM-Auth: <JWT>"
  -> Envoy (:10000)
    -> JWT validation if enabled (RS256, validates signature + issuer + audience)
    -> ext_authz -> localhost:10002 (sidecar)
         -> POST https://login.example.com/oauth/token
            grant_type=client_credentials&client_id=...&client_secret=...
         <- { "access_token": "...", "expires_in": 3600 }
       <- 200 + Authorization: Bearer <oauth-token>
    -> upstream LLM provider (with injected Authorization header)
```

Tokens are cached in-memory and refreshed 30 seconds before expiry.

## Setup

### 1. Create the OAuth credentials Secret

```bash
kubectl create secret generic oauth-credentials \
  --from-literal=OAUTH_TOKEN_URL=https://login.example.com/oauth/token \
  --from-literal=OAUTH_CLIENT_ID=my-client-id \
  --from-literal=OAUTH_CLIENT_SECRET=my-client-secret \
  --from-literal=OAUTH_SCOPE="api.read api.write"
```

### 2. Create the script ConfigMap

```bash
kubectl create configmap ext-authz-oauth-script \
  --from-file=ext-authz-oauth.py
```

### 3. Install the chart

```bash
helm install auth-proxy charts/langsmith-auth-proxy/ \
  -f charts/langsmith-auth-proxy/examples/oauth-token-exchange/values.yaml
```

## Configuration

All OAuth settings are passed via the `oauth-credentials` Secret:

| Environment Variable | Required | Description |
|---|---|---|
| `OAUTH_TOKEN_URL` | Yes | Token endpoint URL |
| `OAUTH_CLIENT_ID` | Yes | Client ID |
| `OAUTH_CLIENT_SECRET` | Yes | Client secret |
| `OAUTH_SCOPE` | No | Space-separated scopes |

## How it works

The sidecar (`ext-authz-oauth.py`) is a ~100-line Python HTTP server with no external dependencies. On each ext_authz check from Envoy:

1. If a valid cached token exists, return it immediately.
2. Otherwise, POST to the token endpoint with the client credentials grant.
3. Cache the token in memory, refreshing 30s before the `expires_in` window.
4. Return `Authorization: Bearer <token>` to Envoy, which injects it into the upstream request.

If the token fetch fails, the sidecar returns HTTP 503, and Envoy denies the request (ext_authz `failure_mode_allow: false`).
