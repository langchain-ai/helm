#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

cleanup() {
  if [[ -n "${port_forward_pid:-}" ]]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

require_cmd kubectl
require_cmd helm
require_cmd curl
require_cmd kind

ensure_kind_context
mkdir -p "$DEBUG_OUTPUT_DIR"
helm_ctx -n "$NAMESPACE" status "$RELEASE_NAME" >/dev/null

api_service="$(find_release_resource_with_suffix svc "-api-server")"
api_deployment="$(find_release_resource_with_suffix deploy "-api-server")"

log "Starting port-forward for service/$api_service"
kubectl_ctx -n "$NAMESPACE" port-forward "service/${api_service}" "${PORT_FORWARD_PORT}:80" >"${DEBUG_OUTPUT_DIR}/port-forward.log" 2>&1 &
port_forward_pid="$!"

for _ in $(seq 1 30); do
  if curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/ok" >/dev/null; then
    break
  fi
  sleep 2
done

curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/ok" >/dev/null
curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/docs" >/dev/null

if [[ "$INSTALL_MONGO_FIXTURE" == "1" ]]; then
  log "Verifying the local Mongo fixture responds"
  kubectl_ctx -n "$NAMESPACE" exec deployment/mongo -- sh -lc 'mongosh --quiet "mongodb://mongo:27017/langgraph" --eval "db.adminCommand({ ping: 1 }).ok"' | grep -qx '1'
fi

if [[ -n "${EXPECT_ENV_VARS:-}" ]]; then
  log "Verifying expected API container env vars: $EXPECT_ENV_VARS"
  IFS=',' read -r -a env_names <<<"${EXPECT_ENV_VARS}"
  remote_check='set -eu;'
  for env_name in "${env_names[@]}"; do
    remote_check+=" value=\${${env_name}:-}; [ -n \"\$value\" ] || { echo \"${env_name} is not set\" >&2; exit 1; };"
  done
  kubectl_ctx -n "$NAMESPACE" exec "deployment/${api_deployment}" -- sh -lc "$remote_check"
fi

log "Smoke test passed"
log "API docs are available at http://127.0.0.1:${PORT_FORWARD_PORT}/docs"
