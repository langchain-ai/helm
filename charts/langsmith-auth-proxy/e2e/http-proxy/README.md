# HTTP Proxy E2E Test

End-to-end test for the `httpProxy` feature of the `langsmith-auth-proxy` chart. Verifies that upstream traffic is routed through an HTTP forward proxy using Envoy's `Http11ProxyUpstreamTransport`.

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
curl -H "X-LangSmith-LLM-Auth: <JWT>" -> Envoy(:10000)
  -> JWT filter (validate sig, iss, aud)
  -> Http11ProxyUpstreamTransport
    -> CONNECT tinyproxy(:8888)
      -> fake-gateway(:10001)
        <- 200 + JSON with all received headers
```

## Files

| File | Purpose |
|------|---------|
| `test.sh` | Orchestration script |
| `e2e-values.yaml` | Helm values override (proxy enabled) |
| `fake-gateway.yaml` | Echo server Deployment+Service (upstream) |
| `tinyproxy.yaml` | Tinyproxy Deployment+Service+ConfigMap (HTTP proxy) |

## Key detail: proxy address must be an IP

Envoy's `Http11ProxyUpstreamTransport` reads the proxy address from endpoint `typed_filter_metadata`. Envoy's `resolveProtoAddress()` only parses IP addresses — it does not perform DNS resolution. The test script handles this by resolving the tinyproxy Service ClusterIP before installing the chart:

```bash
PROXY_IP=$(kubectl get svc tinyproxy -o jsonpath='{.spec.clusterIP}')
helm upgrade --install ... --set authProxy.httpProxy.host="$PROXY_IP"
```

In production, users should provide the proxy's IP address (or a stable ClusterIP) rather than a hostname.

## Cleanup

The script deletes the kind cluster on exit via `trap`. To keep it for debugging, comment out the `trap cleanup EXIT` line.
