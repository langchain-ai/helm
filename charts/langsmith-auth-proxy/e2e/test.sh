#!/usr/bin/env bash
# End-to-end test for langsmith-auth-proxy chart.
# Spins up a kind cluster, deploys an echo upstream + the chart with a
# Python ext_authz sidecar, and runs curl-based tests through the proxy.
set -euo pipefail

CLUSTER_NAME="auth-proxy-e2e"
RELEASE_NAME="auth-proxy-e2e"
NAMESPACE="default"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_PORT=10000  # local port-forward target

PASS=0
FAIL=0

# ── Cleanup ──────────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "=== Cleanup ==="
  # Kill any background port-forward
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

# Generate RSA key pair
step crypto keypair "$TMPDIR_KEYS/pub.pem" "$TMPDIR_KEYS/priv.pem" \
  --kty RSA --size 2048 --no-password --insecure

# Convert public key to JWK and build JWKS
PUB_JWK=$(step crypto key format --jwk < "$TMPDIR_KEYS/pub.pem")
JWKS_JSON=$(echo "$PUB_JWK" | jq -c '{keys: [. + {use: "sig", alg: "RS256"}]}')
echo "JWKS: $JWKS_JSON"

# Mint a valid JWT
NOW=$(date +%s)
EXP=$(( NOW + 3600 ))
JWT=$(step crypto jwt sign \
  --key "$TMPDIR_KEYS/priv.pem" \
  --iss "langsmith" \
  --aud "test-audience" \
  --sub "e2e-test" \
  --nbf "$NOW" \
  --exp "$EXP")
echo "JWT: ${JWT:0:40}..."

rm -rf "$TMPDIR_KEYS"

# ── 4. Deploy echo upstream ─────────────────────────────────────────
log "Deploying echo upstream"
kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/echo-upstream.yaml"
kubectl rollout status deployment/echo-upstream --context "kind-$CLUSTER_NAME" --timeout=90s

# ── 5. Deploy chart ─────────────────────────────────────────────────
log "Creating ext-authz-script ConfigMap"
kubectl create configmap ext-authz-script \
  --context "kind-$CLUSTER_NAME" \
  --from-file="ext-authz-mock.py=$SCRIPT_DIR/ext-authz-mock.py" \
  --dry-run=client -o yaml | kubectl apply --context "kind-$CLUSTER_NAME" -f -

log "Installing chart with helm"
# Write JWKS to a temp values file — --set cannot handle nested JSON braces
TMPDIR_VALS="$(mktemp -d)"
cat > "$TMPDIR_VALS/jwks-values.yaml" <<EOYAML
authProxy:
  jwksJson: '$JWKS_JSON'
EOYAML

helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --kube-context "kind-$CLUSTER_NAME" \
  -f "$SCRIPT_DIR/e2e-values.yaml" \
  -f "$TMPDIR_VALS/jwks-values.yaml" \
  --wait --timeout 120s

rm -rf "$TMPDIR_VALS"

# ── 6. Port-forward ─────────────────────────────────────────────────
log "Setting up port-forward"
# Find the auth-proxy pod
AUTH_POD=$(kubectl get pods --context "kind-$CLUSTER_NAME" \
  -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=langsmith-auth-proxy" \
  -o jsonpath='{.items[0].metadata.name}')
echo "Auth proxy pod: $AUTH_POD"

kubectl port-forward --context "kind-$CLUSTER_NAME" "pod/$AUTH_POD" "$LOCAL_PORT:10000" &
PF_PID=$!
sleep 3

# Quick sanity: make sure port-forward is alive
if ! kill -0 "$PF_PID" 2>/dev/null; then
  echo "ERROR: port-forward died" >&2
  exit 1
fi

# ── 7. Tests ─────────────────────────────────────────────────────────
BASE="http://localhost:$LOCAL_PORT"

log "Test 1: GET /healthz → 200 (bypasses auth)"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/healthz")
assert_status "/healthz returns 200" "200" "$STATUS"

log "Test 2: POST /v1/chat/completions without JWT → 401"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions")
assert_status "No JWT returns 401" "401" "$STATUS"

log "Test 3: POST /v1/chat/completions with valid JWT → 200 + injected header"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d '{"model":"test"}')
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
assert_status "Valid JWT returns 200" "200" "$STATUS"

# The echo server returns JSON with all received headers — verify ext_authz injected the Authorization header
AUTH_HEADER=$(echo "$BODY" | jq -r '.headers.authorization // empty')
if [[ "$AUTH_HEADER" == "Bearer fake-upstream-key" ]]; then
  pass "ext_authz injected Authorization header"
else
  fail "Expected Authorization='Bearer fake-upstream-key', got '$AUTH_HEADER'"
fi

log "Test 4: POST /v1/chat/completions with garbage JWT → 401"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: garbage.jwt.token")
assert_status "Garbage JWT returns 401" "401" "$STATUS"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
