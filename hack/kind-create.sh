#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kind
require_cmd kubectl
require_cmd helm

if kind get clusters | grep -qx "$KIND_CLUSTER_NAME"; then
  log "kind cluster $KIND_CLUSTER_NAME already exists"
else
  log "Creating kind cluster $KIND_CLUSTER_NAME"
  kind create cluster --name "$KIND_CLUSTER_NAME"
fi

ensure_kind_context
kubectl_ctx cluster-info >/dev/null

log "kind cluster is ready at context $KUBE_CONTEXT"
