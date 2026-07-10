#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kind

if kind get clusters | grep -qx "$KIND_CLUSTER_NAME"; then
  log "Deleting kind cluster $KIND_CLUSTER_NAME"
  kind delete cluster --name "$KIND_CLUSTER_NAME"
else
  log "kind cluster $KIND_CLUSTER_NAME does not exist"
fi
