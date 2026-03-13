#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kubectl
require_cmd kind
ensure_kind_context

mkdir -p "$DEBUG_OUTPUT_DIR"

log "Writing Kubernetes diagnostics to $DEBUG_OUTPUT_DIR"

kubectl_ctx -n "$NAMESPACE" get pods,svc,deploy,statefulset,pvc -o wide >"${DEBUG_OUTPUT_DIR}/resources.txt" || true
kubectl_ctx -n "$NAMESPACE" get events --sort-by=.metadata.creationTimestamp >"${DEBUG_OUTPUT_DIR}/events.txt" || true

pods="$(
  kubectl_ctx -n "$NAMESPACE" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' ||
    true
)"

for pod in $pods; do
  kubectl_ctx -n "$NAMESPACE" describe "pod/${pod}" >"${DEBUG_OUTPUT_DIR}/${pod}-describe.txt" || true
  kubectl_ctx -n "$NAMESPACE" logs "pod/${pod}" --all-containers=true >"${DEBUG_OUTPUT_DIR}/${pod}-logs.txt" || true
done

log "Diagnostics captured"
