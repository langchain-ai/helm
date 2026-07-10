#!/usr/bin/env bash
# End-to-end test for langsmith-auth-proxy HTTP proxy support with remote JWKS.
# Spins up a kind cluster with tinyproxy (HTTP forward proxy), fake gateway
# (echo server), and a JWKS server, deploys the chart with httpProxy enabled
# and jwksUri pointing at the JWKS server, and verifies that upstream traffic
# is routed through the proxy with keys fetched remotely.
set -euo pipefail

CLUSTER_NAME="auth-proxy-proxy-e2e"
RELEASE_NAME="auth-proxy-proxy-e2e"
NAMESPACE="default"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_PORT=10000

PASS=0
FAIL=0

# ── Cleanup ──────────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "=== Cleanup ==="
  if [[ -n "${PF_PID:-}" ]] && kill -0 "$PF_PID" 2>/dev/null; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
  echo "Done."
}
trap cleanup EXIT

# ── Helpers ──────────────────────────────────────────────────────────
log()  { echo "--- $*"; }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$desc (HTTP $actual)"
  else
    fail "$desc — expected $expected, got $actual"
  fi
}

# ── 1. Prerequisites ────────────────────────────────────────────────
log "Checking prerequisites"
for cmd in kind helm kubectl step curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH" >&2
    exit 1
  fi
done
echo "All prerequisites found."

# ── 2. Kind cluster ─────────────────────────────────────────────────
log "Creating kind cluster '$CLUSTER_NAME'"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster already exists, reusing."
else
  kind create cluster --name "$CLUSTER_NAME" --wait 60s
fi
kubectl cluster-info --context "kind-$CLUSTER_NAME" >/dev/null

# ── 3. Generate RSA keys + JWT ──────────────────────────────────────
log "Generating RSA key pair and test JWT"
TMPDIR_KEYS="$(mktemp -d)"

step crypto keypair "$TMPDIR_KEYS/pub.pem" "$TMPDIR_KEYS/priv.pem" \
  --kty RSA --size 2048 --no-password --insecure

PUB_JWK=$(step crypto key format --jwk < "$TMPDIR_KEYS/pub.pem")
JWKS_JSON=$(echo "$PUB_JWK" | jq -c '{keys: [. + {use: "sig", alg: "RS256"}]}')
echo "JWKS: $JWKS_JSON"

NOW=$(date +%s)
EXP=$(( NOW + 3600 ))
JTI=$(uuidgen | tr '[:upper:]' '[:lower:]')

CUSTOM_CLAIMS=$(jq -nc \
  --arg jti "$JTI" \
  '{
    jti: $jti,
    ls_user_id: "e2e-ls-user-id",
    organization_id: "e2e-org-id",
    workspace_id: "e2e-workspace-id",
    request_id: $jti,
    actor_type: "user"
  }')

JWT=$(echo "$CUSTOM_CLAIMS" | step crypto jwt sign \
  --key "$TMPDIR_KEYS/priv.pem" \
  --iss "langsmith" \
  --aud "test-audience" \
  --sub "e2e-test-user-id" \
  --nbf "$NOW" \
  --exp "$EXP")
echo "JWT: ${JWT:0:40}..."

rm -rf "$TMPDIR_KEYS"

# ── 4. Deploy tinyproxy (HTTP forward proxy) ─────────────────────────
log "Deploying tinyproxy"
kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/tinyproxy.yaml"
kubectl rollout status deployment/tinyproxy --context "kind-$CLUSTER_NAME" --timeout=90s

# ── 5. Deploy fake gateway (echo upstream) ───────────────────────────
log "Deploying fake gateway"
kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/fake-gateway.yaml"
kubectl rollout status deployment/fake-gateway --context "kind-$CLUSTER_NAME" --timeout=90s

# ── 6. Deploy JWKS server ───────────────────────────────────────────
log "Deploying JWKS server"
kubectl create configmap jwks-server-script \
  --context "kind-$CLUSTER_NAME" \
  --from-file="jwks-server.py=$SCRIPT_DIR/jwks-server.py" \
  --dry-run=client -o yaml | kubectl apply --context "kind-$CLUSTER_NAME" -f -

# Inject the generated JWKS JSON into a ConfigMap mounted by the server
kubectl create configmap jwks-data \
  --context "kind-$CLUSTER_NAME" \
  --from-literal="jwks.json=$JWKS_JSON" \
  --dry-run=client -o yaml | kubectl apply --context "kind-$CLUSTER_NAME" -f -

kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/jwks-server.yaml"
kubectl rollout status deployment/jwks-server --context "kind-$CLUSTER_NAME" --timeout=90s

# ── 7. Deploy chart ──────────────────────────────────────────────────
log "Installing chart with helm"
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --kube-context "kind-$CLUSTER_NAME" \
  -f "$SCRIPT_DIR/e2e-values.yaml" \
  --set authProxy.httpProxy.host="tinyproxy" \
  --wait --timeout 120s

# ── 8. Port-forward ─────────────────────────────────────────────────
log "Setting up port-forward"
AUTH_POD=$(kubectl get pods --context "kind-$CLUSTER_NAME" \
  -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=langsmith-auth-proxy" \
  -o jsonpath='{.items[0].metadata.name}')
echo "Auth proxy pod: $AUTH_POD"

kubectl port-forward --context "kind-$CLUSTER_NAME" "pod/$AUTH_POD" "$LOCAL_PORT:10000" &
PF_PID=$!
sleep 3

if ! kill -0 "$PF_PID" 2>/dev/null; then
  echo "ERROR: port-forward died" >&2
  kubectl logs --context "kind-$CLUSTER_NAME" "$AUTH_POD" --tail=50
  exit 1
fi

# ── 9. Tests ─────────────────────────────────────────────────────────
BASE="http://localhost:$LOCAL_PORT"

log "Test 1: GET /healthz → 200 (bypasses auth)"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/healthz")
assert_status "/healthz returns 200" "200" "$STATUS"

log "Test 2: POST /v1/chat/completions without JWT → 401"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions")
assert_status "No JWT returns 401" "401" "$STATUS"

log "Test 3: POST /v1/chat/completions with valid JWT → 200 (routed through proxy, JWKS fetched remotely)"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d '{"model":"test"}')
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
assert_status "Valid JWT returns 200 through proxy" "200" "$STATUS"

# Verify the request body was forwarded to upstream through the proxy
UPSTREAM_BODY=$(echo "$BODY" | jq -r '.body // empty')
if echo "$UPSTREAM_BODY" | jq -e '.model == "test"' &>/dev/null; then
  pass "Request body forwarded to upstream through proxy"
else
  fail "Request body NOT forwarded to upstream through proxy — got: '$UPSTREAM_BODY'"
fi

# Verify content-length wasn't corrupted by the proxy chain
UPSTREAM_CL=$(echo "$BODY" | jq -r '.headers["content-length"] // empty')
if [[ "$UPSTREAM_CL" == "16" ]]; then
  pass "Content-Length preserved through proxy (${UPSTREAM_CL})"
else
  fail "Content-Length mismatch through proxy — expected 16, got '$UPSTREAM_CL'"
fi

log "Test 4: POST with large body through proxy — verify full body forwarded"
LARGE_BODY=$(jq -nc '{
  model: "gpt-4",
  messages: [
    {role: "system", content: "You are a helpful assistant."},
    {role: "user", content: "Tell me a story about a brave knight who fought dragons."}
  ],
  temperature: 0.7,
  max_tokens: 1024,
  stream: false
}')
RESP4=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d "$LARGE_BODY")
BODY4=$(echo "$RESP4" | sed '$d')
STATUS4=$(echo "$RESP4" | tail -1)
assert_status "Large body POST through proxy returns 200" "200" "$STATUS4"

UPSTREAM_BODY4=$(echo "$BODY4" | jq -r '.body // empty')
UPSTREAM_MODEL=$(echo "$UPSTREAM_BODY4" | jq -r '.model // empty')
UPSTREAM_MSG_COUNT=$(echo "$UPSTREAM_BODY4" | jq -r '.messages | length // 0')
if [[ "$UPSTREAM_MODEL" == "gpt-4" ]] && [[ "$UPSTREAM_MSG_COUNT" == "2" ]]; then
  pass "Large request body forwarded intact through proxy (model=$UPSTREAM_MODEL, messages=$UPSTREAM_MSG_COUNT)"
else
  fail "Large body corrupted or missing through proxy — model='$UPSTREAM_MODEL', messages='$UPSTREAM_MSG_COUNT'"
fi

EXPECTED_CL4=${#LARGE_BODY}
ACTUAL_CL4=$(echo "$BODY4" | jq -r '.headers["content-length"] // empty')
if [[ "$ACTUAL_CL4" == "$EXPECTED_CL4" ]]; then
  pass "Large body Content-Length correct through proxy ($ACTUAL_CL4)"
else
  fail "Large body Content-Length mismatch through proxy — expected $EXPECTED_CL4, got '$ACTUAL_CL4'"
fi

log "Test 5: Verify tinyproxy logged the proxied requests"
PROXY_POD=$(kubectl get pods --context "kind-$CLUSTER_NAME" \
  -l app=tinyproxy -o jsonpath='{.items[0].metadata.name}')
PROXY_LOGS=$(kubectl logs --context "kind-$CLUSTER_NAME" "$PROXY_POD" --tail=50 2>&1)
if echo "$PROXY_LOGS" | grep -qi "fake-gateway\|CONNECT\|10001"; then
  pass "tinyproxy logs show proxied request to fake-gateway"
else
  fail "tinyproxy logs do not show proxied request"
  echo "Proxy logs:"
  echo "$PROXY_LOGS"
fi

log "Test 6: Verify JWKS server received fetch requests from Envoy"
JWKS_POD=$(kubectl get pods --context "kind-$CLUSTER_NAME" \
  -l app=jwks-server -o jsonpath='{.items[0].metadata.name}')
JWKS_LOGS=$(kubectl logs --context "kind-$CLUSTER_NAME" "$JWKS_POD" --tail=50 2>&1)
if echo "$JWKS_LOGS" | grep -q "/well-known/jwks.json"; then
  pass "JWKS server received key fetch request from Envoy"
else
  fail "JWKS server did not receive any key fetch requests"
  echo "JWKS server logs:"
  echo "$JWKS_LOGS"
fi

# ── 10. Logs ─────────────────────────────────────────────────────────
log "Tinyproxy logs"
kubectl logs --context "kind-$CLUSTER_NAME" "$PROXY_POD" --tail=20

log "JWKS server logs"
kubectl logs --context "kind-$CLUSTER_NAME" "$JWKS_POD" --tail=20

log "Envoy logs (last 20 lines)"
kubectl logs --context "kind-$CLUSTER_NAME" "$AUTH_POD" --tail=20

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
