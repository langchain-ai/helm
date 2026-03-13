#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kubectl
require_cmd kind
ensure_kind_context

api_service="$(find_release_resource_with_suffix svc "-api-server")"

log "Port-forwarding service/$api_service to http://127.0.0.1:${PORT_FORWARD_PORT}"
exec kubectl_ctx -n "$NAMESPACE" port-forward "service/${api_service}" "${PORT_FORWARD_PORT}:80"
