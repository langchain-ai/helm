# Transformer (ext_proc) E2E Tests

End-to-end tests for the `langsmith-auth-proxy` chart's transformer support. Spins up a kind cluster, builds a Go ext_proc gRPC mock, deploys it alongside a fake gateway (echo server), installs the chart with `transformer.enabled: true`, and validates that:

- Headers are injected by the ext_proc service
- Request bodies are rewritten before reaching upstream

## Prerequisites

`kind`, `helm`, `kubectl`, `step`, `curl`, `jq`, `docker`

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
3. Request with valid JWT returns 200, ext_proc injects `Authorization: Bearer fake-upstream-key` and `X-Ext-Proc-Applied: true`
4. Request body is transformed from `{"model":"X","messages":[...]}` to `{"custom_model":"X","custom_messages":[...],"metadata":{"source":"langsmith-ext-proc"}}`
5. Request with garbage JWT returns 401
6. Large multi-message body is transformed correctly

## Request flow

```
curl -H "X-LangSmith-LLM-Auth: <JWT>" -d '{"model":"gpt-4",...}' -> Envoy(:10000)
  -> JWT filter (validate sig, iss, aud)
  -> ext_proc filter -> transformer-mock:50051 (gRPC)
    <- mutate headers: add Authorization, X-Ext-Proc-Applied
    <- mutate body: rewrite to {custom_model, custom_messages, metadata}
  -> fake-gateway:10001
    <- 200 + JSON with all received headers + body
```

## Files

| File | Purpose |
|------|---------|
| `test.sh` | Orchestration script |
| `e2e-values.yaml` | Helm values override (transformer enabled, BUFFERED body mode) |
| `fake-gateway.yaml` | Echo server Deployment+Service (upstream) |
| `transformer-mock.yaml` | ext_proc gRPC mock Deployment+Service |
| `sample-ext-proc.go` | Go source for the ext_proc mock |
| `Dockerfile` | Multi-stage build for the mock |
| `go.mod` / `go.sum` | Go module dependencies |

## Cleanup

The script deletes the kind cluster on exit via `trap`. To keep it for debugging, comment out the `trap cleanup EXIT` line.
