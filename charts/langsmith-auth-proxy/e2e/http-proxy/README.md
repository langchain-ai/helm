# HTTP Proxy E2E Test

End-to-end test for the `httpProxy` feature of the `langsmith-auth-proxy` chart. Verifies that upstream traffic is routed through an HTTP forward proxy using the two-listener loopback pattern (`tcp_proxy` + `tunneling_config`).

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
4. Tinyproxy logs confirm it proxied the CONNECT request to the upstream

## Architecture

```
curl -H "X-LangSmith-LLM-Auth: <JWT>" -> listener_0 (:10000, HCM)
  -> JWT filter (validate sig, iss, aud)
  -> loopback_cluster (STATIC, 127.0.0.1:10001)
    -> listener_1 (:10001, tcp_proxy + tunneling_config CONNECT)
      -> proxy_cluster (STRICT_DNS, tinyproxy:8888)
        -> tinyproxy (CONNECT tunnel)
          -> fake-gateway(:10001)
            <- 200 + JSON with all received headers
```

For HTTPS upstreams, TLS with SNI is applied on `loopback_cluster` so the encrypted payload flows through the CONNECT tunnel. `proxy_cluster` is always plaintext HTTP/1.1.

This pattern supports both IP addresses and hostnames for the proxy host.

## Files

| File | Purpose |
|------|---------|
| `test.sh` | Orchestration script |
| `e2e-values.yaml` | Helm values override (proxy enabled) |
| `fake-gateway.yaml` | Echo server Deployment+Service (upstream) |
| `tinyproxy.yaml` | Tinyproxy Deployment+Service+ConfigMap (HTTP proxy) |

## Cleanup

The script deletes the kind cluster on exit via `trap`. To keep it for debugging, comment out the `trap cleanup EXIT` line.
