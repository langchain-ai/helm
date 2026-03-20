#!/usr/bin/env bash
# End-to-end test for langsmith-auth-proxy transformer (ext_proc) support.
# Spins up a kind cluster, builds the Go ext_proc mock, deploys the chart
# with transformer enabled, and validates header injection + body rewriting.
set -euo pipefail

CLAIMS_FILE="${1:-}"

CLUSTER_NAME="auth-proxy-transformer-e2e"
RELEASE_NAME="auth-proxy-transformer-e2e"
NAMESPACE="default"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_PORT=10000  # local port-forward target

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
for cmd in kind helm kubectl step curl jq docker; do
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

# ── 3. Build + load transformer mock image ──────────────────────────
log "Building transformer-mock Docker image"
docker build -t transformer-mock:e2e "$SCRIPT_DIR"

log "Loading image into kind"
kind load docker-image transformer-mock:e2e --name "$CLUSTER_NAME"

# ── 4. Generate RSA keys + JWT ──────────────────────────────────────
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

if [[ -n "$CLAIMS_FILE" ]]; then
  echo "Using custom claims from: $CLAIMS_FILE"
  CUSTOM_CLAIMS=$(jq -c '.' "$CLAIMS_FILE")
else
  echo "Using default fake claims"
  CUSTOM_CLAIMS=$(jq -nc \
    --arg jti "$JTI" \
    --arg req "$JTI" \
    '{
      jti: $jti,
      ls_user_id: "e2e-ls-user-id",
      organization_id: "e2e-org-id",
      workspace_id: "e2e-workspace-id",
      model_provider: "fake-provider",
      model_name: "fake-model",
      streaming: false,
      request_id: $req,
      actor_type: "user"
    }')
fi
echo "Custom claims: $CUSTOM_CLAIMS"

JWT=$(echo "$CUSTOM_CLAIMS" | step crypto jwt sign \
  --key "$TMPDIR_KEYS/priv.pem" \
  --iss "langsmith" \
  --aud "test-audience" \
  --sub "e2e-test-user-id" \
  --nbf "$NOW" \
  --exp "$EXP")
echo "JWT: ${JWT:0:40}..."

rm -rf "$TMPDIR_KEYS"

# ── 5. Deploy fake gateway + transformer mock ────────────────────────
log "Deploying fake gateway"
kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/fake-gateway.yaml"
kubectl rollout status deployment/fake-gateway --context "kind-$CLUSTER_NAME" --timeout=90s

log "Deploying transformer mock"
kubectl apply --context "kind-$CLUSTER_NAME" -f "$SCRIPT_DIR/transformer-mock.yaml"
kubectl rollout status deployment/transformer-mock --context "kind-$CLUSTER_NAME" --timeout=90s

# ── 6. Deploy chart ─────────────────────────────────────────────────
log "Installing chart with helm"
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

# ── 7. Port-forward ─────────────────────────────────────────────────
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
  exit 1
fi

# ── 8. Tests ─────────────────────────────────────────────────────────
BASE="http://localhost:$LOCAL_PORT"

log "Test 1: GET /healthz → 200 (bypasses auth)"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/healthz")
assert_status "/healthz returns 200" "200" "$STATUS"

log "Test 2: POST /v1/chat/completions without JWT → 401"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions")
assert_status "No JWT returns 401" "401" "$STATUS"

log "Test 3: POST with valid JWT → 200 + transformer injects headers"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4","messages":[{"role":"user","content":"hello"}]}')
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
assert_status "Valid JWT returns 200" "200" "$STATUS"

# Verify ext_proc injected Authorization header
AUTH_HEADER=$(echo "$BODY" | jq -r '.headers.authorization // empty')
if [[ "$AUTH_HEADER" == "Bearer fake-upstream-key" ]]; then
  pass "ext_proc injected Authorization header"
else
  fail "Expected Authorization='Bearer fake-upstream-key', got '$AUTH_HEADER'"
fi

# Verify ext_proc added X-Ext-Proc-Applied header
EXT_PROC_HEADER=$(echo "$BODY" | jq -r '.headers["x-ext-proc-applied"] // empty')
if [[ "$EXT_PROC_HEADER" == "true" ]]; then
  pass "ext_proc added X-Ext-Proc-Applied header"
else
  fail "Expected X-Ext-Proc-Applied='true', got '$EXT_PROC_HEADER'"
fi

log "Test 4: POST with valid JWT → body was transformed by ext_proc"
# The transformer mock rewrites {"model":"X","messages":[...]} into
# {"custom_model":"X","custom_messages":[...],"metadata":{"source":"langsmith-ext-proc"}}
UPSTREAM_BODY=$(echo "$BODY" | jq -r '.body // empty')
CUSTOM_MODEL=$(echo "$UPSTREAM_BODY" | jq -r '.custom_model // empty')
CUSTOM_MSGS=$(echo "$UPSTREAM_BODY" | jq -r '.custom_messages | length // 0')
METADATA_SRC=$(echo "$UPSTREAM_BODY" | jq -r '.metadata.source // empty')

if [[ "$CUSTOM_MODEL" == "gpt-4" ]]; then
  pass "Body transformed: custom_model=$CUSTOM_MODEL"
else
  fail "Expected custom_model='gpt-4', got '$CUSTOM_MODEL'"
fi

if [[ "$CUSTOM_MSGS" == "1" ]]; then
  pass "Body transformed: custom_messages has 1 entry"
else
  fail "Expected custom_messages length=1, got '$CUSTOM_MSGS'"
fi

if [[ "$METADATA_SRC" == "langsmith-ext-proc" ]]; then
  pass "Body transformed: metadata.source=langsmith-ext-proc"
else
  fail "Expected metadata.source='langsmith-ext-proc', got '$METADATA_SRC'"
fi

# Verify original fields are NOT present (body was rewritten, not passed through)
ORIGINAL_MODEL=$(echo "$UPSTREAM_BODY" | jq -r '.model // empty')
if [[ -z "$ORIGINAL_MODEL" ]]; then
  pass "Original 'model' field absent (body fully rewritten)"
else
  fail "Original 'model' field still present — transformer may not be working"
fi

log "Test 5: POST with garbage JWT → 401"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: garbage.jwt.token")
assert_status "Garbage JWT returns 401" "401" "$STATUS"

log "Test 6: POST with large body — verify transformer handles it"
LARGE_BODY=$(jq -nc '{
  model: "gpt-4",
  messages: [
    {role: "system", content: "You are a helpful assistant."},
    {role: "user", content: "Tell me a story about a brave knight who fought dragons and saved kingdoms across the land."}
  ],
  temperature: 0.7,
  max_tokens: 1024,
  stream: false
}')
RESP6=$(curl -s -w '\n%{http_code}' -X POST "$BASE/v1/chat/completions" \
  -H "X-LangSmith-LLM-Auth: $JWT" \
  -H "Content-Type: application/json" \
  -d "$LARGE_BODY")
BODY6=$(echo "$RESP6" | sed '$d')
STATUS6=$(echo "$RESP6" | tail -1)
assert_status "Large body POST returns 200" "200" "$STATUS6"

UPSTREAM_BODY6=$(echo "$BODY6" | jq -r '.body // empty')
LARGE_CUSTOM_MODEL=$(echo "$UPSTREAM_BODY6" | jq -r '.custom_model // empty')
LARGE_CUSTOM_MSGS=$(echo "$UPSTREAM_BODY6" | jq -r '.custom_messages | length // 0')
if [[ "$LARGE_CUSTOM_MODEL" == "gpt-4" ]] && [[ "$LARGE_CUSTOM_MSGS" == "2" ]]; then
  pass "Large body transformed correctly (custom_model=$LARGE_CUSTOM_MODEL, custom_messages=$LARGE_CUSTOM_MSGS)"
else
  fail "Large body transform failed — custom_model='$LARGE_CUSTOM_MODEL', custom_messages='$LARGE_CUSTOM_MSGS'"
fi

# ── 9. Logs ──────────────────────────────────────────────────────────
log "Echo upstream logs"
kubectl logs --context "kind-$CLUSTER_NAME" -l app=fake-gateway --tail=100

log "Transformer mock logs"
kubectl logs --context "kind-$CLUSTER_NAME" -l app=transformer-mock --tail=100

log "Envoy proxy logs"
kubectl logs --context "kind-$CLUSTER_NAME" "$AUTH_POD" --tail=100

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
