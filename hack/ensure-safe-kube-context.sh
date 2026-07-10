#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kind
require_cmd kubectl
require_cmd helm
ensure_kind_context

log "Using local-safe kind context: $KUBE_CONTEXT"
