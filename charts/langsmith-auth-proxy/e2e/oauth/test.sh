#!/usr/bin/env bash
# Quick smoke-test for the oauth-token-exchange example.
#
# Deploys the auth-proxy chart with JWT validation disabled and httpbin.org
# as a safe upstream target, then verifies the Envoy healthz endpoint returns 200.
#
# Prerequisites:
#   1. Create a kind cluster (if you don't already have one):
#
#        kind create cluster --name auth-proxy-test
#
#   2. Set the kubectl context:
#
#        kubectl cluster-info --context kind-auth-proxy-test
#
# Usage:
#   ./test.sh            # deploy + test
#   ./test.sh cleanup    # tear down the test namespace
#   ./test.sh nuke       # cleanup + delete the kind cluster

set -euo pipefail

KIND_CLUSTER="auth-proxy-oauth-test"
NAMESPACE="auth-proxy-test"
RELEASE="auth-proxy-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_PORT=10100

cleanup() {
  echo "Cleaning up..."
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=false
  echo "Namespace $NAMESPACE scheduled for deletion."
}

if [[ "${1:-}" == "cleanup" ]]; then
  cleanup
  exit 0
fi

if [[ "${1:-}" == "nuke" ]]; then
  echo "Deleting kind cluster $KIND_CLUSTER..."
  kind delete cluster --name "$KIND_CLUSTER"
  exit 0
fi

# Ensure a kind cluster exists, creating one if needed.
if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER}$"; then
  echo "==> Creating kind cluster '$KIND_CLUSTER'"
  kind create cluster --name "$KIND_CLUSTER"
fi

echo "==> Setting kubectl context to kind-$KIND_CLUSTER"
kubectl cluster-info --context "kind-${KIND_CLUSTER}" >/dev/null 2>&1 \
  || { echo "ERROR: Cannot connect to kind cluster '$KIND_CLUSTER'."; exit 1; }
kubectl config use-context "kind-${KIND_CLUSTER}"

echo "==> Creating namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating oauth-credentials Secret (dummy values for testing)"
kubectl -n "$NAMESPACE" create secret generic oauth-credentials \
  --from-literal=OAUTH_TOKEN_URL=https://httpbin.org/post \
  --from-literal=OAUTH_CLIENT_ID=test-client-id \
  --from-literal=OAUTH_CLIENT_SECRET=test-client-secret \
  --from-literal=OAUTH_SCOPE="openid" \
  --dry-run=client -o yaml | kubectl -n "$NAMESPACE" apply -f -

echo "==> Creating ext-authz-oauth-script ConfigMap"
kubectl -n "$NAMESPACE" create configmap ext-authz-oauth-script \
  --from-file="$SCRIPT_DIR/ext-authz-oauth.py" \
  --dry-run=client -o yaml | kubectl -n "$NAMESPACE" apply -f -

echo "==> Installing Helm release $RELEASE"
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  -n "$NAMESPACE" \
  -f "$SCRIPT_DIR/values.yaml" \
  --set authProxy.upstream=https://httpbin.org \
  --set authProxy.jwtValidation.enabled=false \
  --wait --timeout 120s

echo "==> Waiting for deployment to be ready"
kubectl -n "$NAMESPACE" rollout status deployment -l app.kubernetes.io/instance="$RELEASE" --timeout=120s

SVC_NAME=$(kubectl -n "$NAMESPACE" get svc -l app.kubernetes.io/instance="$RELEASE" -o jsonpath='{.items[0].metadata.name}')
echo "==> Port-forwarding $SVC_NAME to localhost:$LOCAL_PORT"
kubectl -n "$NAMESPACE" port-forward svc/"$SVC_NAME" "$LOCAL_PORT":10000 &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 3

echo "==> Hitting /healthz endpoint"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LOCAL_PORT/healthz")

kill "$PF_PID" 2>/dev/null || true

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "SUCCESS: /healthz returned $HTTP_CODE"
else
  echo "FAIL: /healthz returned $HTTP_CODE (expected 200)"
  exit 1
fi

echo ""
echo "Test passed. To clean up run:"
echo "  $0 cleanup"
