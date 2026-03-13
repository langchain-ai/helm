#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

should_dump_diagnostics=0

cleanup_on_error() {
  local exit_code="$1"
  if [[ "$exit_code" -ne 0 && "$should_dump_diagnostics" == "1" ]]; then
    warn "Installation failed, collecting Kubernetes diagnostics"
    "$(absolute_path hack/dump-k8s-debug.sh)" || true
  fi
}

trap 'cleanup_on_error $?' EXIT

require_cmd kind
require_cmd kubectl
require_cmd helm

ensure_kind_context
ensure_namespace
parse_api_image
maybe_load_api_image
should_dump_diagnostics=1

if [[ "$INSTALL_MONGO_FIXTURE" == "1" ]]; then
  log "Installing local Mongo fixture"
  kubectl_ctx -n "$NAMESPACE" apply -f "$(absolute_path "$MONGO_FIXTURE_FILE")" >/dev/null
  kubectl_ctx -n "$NAMESPACE" rollout status deployment/mongo --timeout "$WAIT_TIMEOUT"
fi

helm_args=(
  upgrade
  --install
  "$RELEASE_NAME"
  "$(absolute_path "$CHART_DIR")"
  --namespace
  "$NAMESPACE"
  --create-namespace
  -f
  "$(absolute_path "$DEV_VALUES_FILE")"
)

if [[ -n "${API_IMAGE_REPOSITORY:-}" ]]; then
  helm_args+=(
    --set-string
    "images.apiServerImage.repository=${API_IMAGE_REPOSITORY}"
    --set-string
    "images.apiServerImage.tag=${API_IMAGE_TAG}"
  )
fi

if [[ -n "${EXTRA_VALUES_FILE:-}" ]]; then
  helm_args+=(-f "$(absolute_path "$EXTRA_VALUES_FILE")")
fi

if [[ -n "${LANGGRAPH_CLOUD_LICENSE_KEY:-}" ]]; then
  helm_args+=(--set-string "config.langGraphCloudLicenseKey=${LANGGRAPH_CLOUD_LICENSE_KEY}")
fi

if [[ -n "${LANGSMITH_API_KEY:-}" ]]; then
  helm_args+=(--set-string "config.apiKey=${LANGSMITH_API_KEY}")
fi

log "Installing $RELEASE_NAME into namespace $NAMESPACE"
helm_ctx "${helm_args[@]}"

wait_for_release_statefulset_suffix "-postgres"
wait_for_release_deployment_suffix "-redis"
wait_for_release_deployment_suffix "-api-server"

log "LangGraph Cloud is installed"
log "Run 'make cloud-dev-smoke' to verify the API is reachable"
log "Run 'make cloud-dev-connect' to port-forward the API service for manual testing"
