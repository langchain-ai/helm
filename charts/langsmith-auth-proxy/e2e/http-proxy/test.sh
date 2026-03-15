#!/usr/bin/env bash
# End-to-end test for langsmith-auth-proxy HTTP proxy support.
# Spins up a kind cluster with tinyproxy (HTTP forward proxy) + fake gateway
# (echo server), deploys the chart with httpProxy enabled, and verifies that
# upstream traffic is routed through the proxy.
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

# ── 6. Get tinyproxy ClusterIP ───────────────────────────────────────
# Http11ProxyUpstreamTransport requires an IP address in the proxy metadata
# (Envoy's resolveProtoAddress does not perform DNS resolution).
log "Resolving tinyproxy ClusterIP"
PROXY_IP=$(kubectl get svc tinyproxy --context "kind-$CLUSTER_NAME" \
  -o jsonpath='{.spec.clusterIP}')
echo "Tinyproxy ClusterIP: $PROXY_IP"

# ── 7. Deploy chart ─────────────────────────────────────────────────
log "Installing chart with helm"
TMPDIR_VALS="$(mktemp -d)"
cat > "$TMPDIR_VALS/runtime-values.yaml" <<EOYAML
authProxy:
  jwksJson: '$JWKS_JSON'
  httpProxy:
    host: "$PROXY_IP"
EOYAML

helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --kube-context "kind-$CLUSTER_NAME" \
  -f "$SCRIPT_DIR/e2e-values.yaml" \
  -f "$TMPDIR_VALS/runtime-values.yaml" \
  --wait --timeout 120s

rm -rf "$TMPDIR_VALS"

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

log "Test 3: POST /v1/chat/completions with valid JWT → 200 (routed through proxy)"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d '{"model":"test"}')
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
assert_status "Valid JWT returns 200 through proxy" "200" "$STATUS"

log "Test 4: Verify tinyproxy logged the proxied request"
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

# ── 10. Logs ─────────────────────────────────────────────────────────
log "Tinyproxy logs"
kubectl logs --context "kind-$CLUSTER_NAME" "$PROXY_POD" --tail=20

log "Envoy logs (last 20 lines)"
kubectl logs --context "kind-$CLUSTER_NAME" "$AUTH_POD" --tail=20

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
