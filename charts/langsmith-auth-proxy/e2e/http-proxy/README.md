# HTTP Proxy E2E Test

End-to-end test for the `httpProxy` feature of the `langsmith-auth-proxy` chart. Verifies that both upstream traffic and JWKS key fetches are routed through an HTTP forward proxy using the two-listener loopback pattern (`tcp_proxy` + `tunneling_config`).

## Prerequisites

`kind`, `helm`, `kubectl`, `step`, `curl`, `jq`

## Usage

```bash
./test.sh
```

## What it tests

1. `GET /healthz` returns 200 (health check bypasses auth)
2. Request without JWT returns 401
3. Request with valid JWT returns 200, traffic routed through tinyproxy to fake-gateway
4. Large request body forwarded intact through the proxy chain
5. Tinyproxy logs confirm it proxied the CONNECT request to the upstream
6. JWKS server logs confirm Envoy fetched keys remotely (via proxy)

## Architecture

```
curl -H "X-LangSmith-LLM-Auth: <JWT>" -> listener_0 (:10000, HCM)
  -> JWT filter (validate sig, iss, aud)
       keys fetched via:
         jwks_loopback_cluster (STATIC, 127.0.0.1:10002)
           -> listener_2 (:10002, tcp_proxy + tunneling_config CONNECT)
             -> proxy_cluster (tinyproxy:8888)
               -> jwks-server(:8080) /well-known/jwks.json
  -> loopback_cluster (STATIC, 127.0.0.1:10001)
    -> listener_1 (:10001, tcp_proxy + tunneling_config CONNECT)
      -> proxy_cluster (tinyproxy:8888)
        -> fake-gateway(:10001)
          <- 200 + JSON with all received headers
```

Both upstream LLM traffic and JWKS key fetches are routed through tinyproxy. This simulates the **cloud LangSmith** scenario where the auth-proxy pod has no direct internet access and must use a corporate HTTP proxy for all external traffic.

For **self-hosted LangSmith**, the JWKS host would be added to `httpProxy.noProxy`, causing Envoy to connect directly to the in-cluster JWKS endpoint via the `jwks_service` cluster (no proxy).

This pattern supports both IP addresses and hostnames for the proxy host.

## Files

| File | Purpose |
|------|---------|
| `test.sh` | Orchestration script |
| `e2e-values.yaml` | Helm values override (proxy enabled, jwksUri) |
| `fake-gateway.yaml` | Echo server Deployment+Service (upstream) |
| `tinyproxy.yaml` | Tinyproxy Deployment+Service+ConfigMap (HTTP proxy) |
| `jwks-server.py` | Minimal Python JWKS server script |
| `jwks-server.yaml` | JWKS server Deployment+Service |

## Cleanup

The script deletes the kind cluster on exit via `trap`. To keep it for debugging, comment out the `trap cleanup EXIT` line.
