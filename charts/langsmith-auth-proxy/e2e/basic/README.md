# E2E Tests

Self-contained end-to-end tests for the `langsmith-auth-proxy` chart. Spins up a kind cluster, generates fresh RSA keys + JWT, deploys a fake gateway (echo server) as upstream, runs a Python ext_authz sidecar, and validates the full request flow through Envoy.

## Prerequisites

`kind`, `helm`, `kubectl`, `step`, `curl`, `jq`

## Usage

```bash
# Run with default fake claims
./test.sh

# Run with custom JWT claims
./test.sh path/to/claims.json
```

## What it tests

1. `GET /healthz` returns 200 (health check bypasses auth)
2. Request without JWT returns 401
3. Request with valid JWT returns 200, ext_authz injects `Authorization: Bearer fake-upstream-key`
4. Request with garbage JWT returns 401

## Request flow

```
curl -H "X-LangSmith-LLM-Auth: <JWT>" -> Envoy(:10000)
  -> JWT filter (validate sig, iss, aud)
  -> ext_authz filter -> localhost:10002 (sidecar)
    <- 200 + Authorization: Bearer fake-upstream-key
  -> fake-gateway:10001
    <- 200 + JSON with all received headers
```

## Files

| File | Purpose |
|------|---------|
| `test.sh` | Orchestration script |
| `e2e-values.yaml` | Helm values override |
| `fake-gateway.yaml` | Echo server Deployment+Service (upstream) |
| `ext-authz-mock.py` | Python ext_authz sidecar mock |

## Cleanup

The script deletes the kind cluster on exit via `trap`. To keep it for debugging, comment out the `trap cleanup EXIT` line.
