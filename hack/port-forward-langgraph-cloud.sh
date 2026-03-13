#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

require_cmd kubectl
require_cmd kind
ensure_kind_context

api_service="$(find_api_service)"
api_service_port="$(get_service_port_by_name "$api_service" "http")"

log "Port-forwarding service/$api_service on service port $api_service_port to http://127.0.0.1:${PORT_FORWARD_PORT}"
exec kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" port-forward "service/${api_service}" "${PORT_FORWARD_PORT}:${api_service_port}"
