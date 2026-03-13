#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

json_escape() {
  local value="$1"
  local LC_ALL=C
  local escaped=""
  local char=""
  local char_ord=0
  local i=0

  for ((i = 0; i < ${#value}; i++)); do
    char="${value:i:1}"
    printf -v char_ord '%d' "'$char"
    case "$char" in
      '"')
        escaped+='\"'
        ;;
      \\)
        escaped+='\\'
        ;;
      $'\b')
        escaped+='\b'
        ;;
      $'\f')
        escaped+='\f'
        ;;
      $'\n')
        escaped+='\n'
        ;;
      $'\r')
        escaped+='\r'
        ;;
      $'\t')
        escaped+='\t'
        ;;
      *)
        if ((char_ord < 32)); then
          printf -v char '\\u%04x' "$char_ord"
          escaped+="$char"
        else
          escaped+="$char"
        fi
        ;;
    esac
  done

  printf '%s' "$escaped"
}

sh_single_quote() {
  local value="$1"
  value="${value//\'/\'\"\'\"\'}"
  printf "'%s'" "$value"
}

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

SMOKE_THREAD_ID="${SMOKE_THREAD_ID:-2cfc6f4f-c711-4a71-b193-5d89a681a813}"
SMOKE_ASSISTANT_ID="${SMOKE_ASSISTANT_ID:-agent}"
SMOKE_MESSAGE="${SMOKE_MESSAGE:-Hi there}"
SMOKE_STREAM_TIMEOUT_SECONDS="${SMOKE_STREAM_TIMEOUT_SECONDS:-30}"
SMOKE_SKIP_APP_RUN="${SMOKE_SKIP_APP_RUN:-0}"
SMOKE_API_KEY="${SMOKE_API_KEY:-}"
SMOKE_AUTH_TOKEN="${SMOKE_AUTH_TOKEN:-}"

api_service="$(find_api_service)"
api_service_port="$(get_service_port_by_name "$api_service" "http")"
api_deployment="$(find_api_deployment)"

log "Starting port-forward for service/$api_service on service port $api_service_port"
kubectl_ctx -n "$NAMESPACE" port-forward "service/${api_service}" "${PORT_FORWARD_PORT}:${api_service_port}" >"${DEBUG_OUTPUT_DIR}/port-forward.log" 2>&1 &
port_forward_pid="$!"

port_forward_ready=0
for _ in $(seq 1 30); do
  if ! kill -0 "$port_forward_pid" >/dev/null 2>&1; then
    sed -n '1,120p' "${DEBUG_OUTPUT_DIR}/port-forward.log" >&2 || true
    die "port-forward process exited unexpectedly"
  fi

  if curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/ok" >/dev/null; then
    port_forward_ready=1
    break
  fi
  sleep 2
done

if [[ "$port_forward_ready" != "1" ]]; then
  sed -n '1,120p' "${DEBUG_OUTPUT_DIR}/port-forward.log" >&2 || true
  die "timed out waiting for the API port-forward to become ready"
fi

curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/ok" >/dev/null
curl --fail --silent "http://127.0.0.1:${PORT_FORWARD_PORT}/docs" >/dev/null

if [[ "$SMOKE_SKIP_APP_RUN" != "1" ]]; then
  run_payload_file="${DEBUG_OUTPUT_DIR}/run-stream-payload.json"
  run_response_file="${DEBUG_OUTPUT_DIR}/run-stream-response.txt"
  escaped_assistant_id="$(json_escape "$SMOKE_ASSISTANT_ID")"
  escaped_message="$(json_escape "$SMOKE_MESSAGE")"

  cat >"$run_payload_file" <<EOF
{"input":{"messages":[{"role":"user","content":"${escaped_message}"}]},"assistant_id":"${escaped_assistant_id}","if_not_exists":"create"}
EOF

  log "Running application smoke request against /threads/${SMOKE_THREAD_ID}/runs/stream"
  curl_args=(
    --fail
    --silent
    --show-error
    --max-time "$SMOKE_STREAM_TIMEOUT_SECONDS"
    --header 'Accept: text/event-stream'
    --header 'Content-Type: application/json'
  )

  if [[ -n "$SMOKE_API_KEY" ]]; then
    curl_args+=(--header "X-Api-Key: ${SMOKE_API_KEY}")
  fi

  if [[ -n "$SMOKE_AUTH_TOKEN" ]]; then
    curl_args+=(--header "Authorization: Bearer ${SMOKE_AUTH_TOKEN}")
  fi

  curl \
    "${curl_args[@]}" \
    --data @"$run_payload_file" \
    "http://127.0.0.1:${PORT_FORWARD_PORT}/threads/${SMOKE_THREAD_ID}/runs/stream" \
    >"$run_response_file"

  [[ -s "$run_response_file" ]] || die "application smoke request returned an empty response body"
  if grep -q '^event: error' "$run_response_file"; then
    sed -n '1,120p' "$run_response_file" >&2
    die "application smoke request returned an error event"
  fi
fi

if [[ "$INSTALL_MONGO_FIXTURE" == "1" ]]; then
  log "Verifying the local Mongo fixture is a writable replica set primary"
  kubectl_ctx -n "$NAMESPACE" exec deployment/mongo -- sh -lc "mongosh --quiet \"mongodb://mongo:27017/langgraph?replicaSet=rs0\" --eval 'const hello = db.adminCommand({ hello: 1 }); quit(hello.setName === \"rs0\" && hello.isWritablePrimary ? 0 : 1)'"
fi

if [[ -n "${EXPECT_ENV_VARS:-}" ]]; then
  log "Verifying expected API container env vars: $EXPECT_ENV_VARS"
  IFS=',' read -r -a env_specs <<<"${EXPECT_ENV_VARS}"
  remote_check='set -eu;'
  for env_spec in "${env_specs[@]}"; do
    env_spec="${env_spec#"${env_spec%%[![:space:]]*}"}"
    env_spec="${env_spec%"${env_spec##*[![:space:]]}"}"
    [[ -n "$env_spec" ]] || die "EXPECT_ENV_VARS must not contain empty entries"

    env_name="$env_spec"
    expected_value=""
    has_expected_value=0
    if [[ "$env_spec" == *"="* ]]; then
      env_name="${env_spec%%=*}"
      expected_value="${env_spec#*=}"
      has_expected_value=1
    fi

    env_name="${env_name#"${env_name%%[![:space:]]*}"}"
    env_name="${env_name%"${env_name##*[![:space:]]}"}"
    [[ -n "$env_name" ]] || die "EXPECT_ENV_VARS must not contain empty names"
    [[ "$env_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "EXPECT_ENV_VARS entries must be valid shell variable names, got \"$env_name\""

    remote_check+=" value=\${${env_name}:-};"
    if [[ "$has_expected_value" == "1" ]]; then
      expected_value_quoted="$(sh_single_quote "$expected_value")"
      remote_check+=" [ \"\$value\" = ${expected_value_quoted} ] || { echo \"${env_name} does not match expected value\" >&2; exit 1; };"
    else
      remote_check+=" [ -n \"\$value\" ] || { echo \"${env_name} is not set\" >&2; exit 1; };"
    fi
  done
  kubectl_ctx -n "$NAMESPACE" exec "deployment/${api_deployment}" -- sh -lc "$remote_check"
fi

log "Smoke test passed"
log "API docs are available at http://127.0.0.1:${PORT_FORWARD_PORT}/docs"
