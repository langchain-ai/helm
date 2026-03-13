#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

repo_root() {
  git rev-parse --show-toplevel
}

absolute_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$(repo_root)" "$path"
  fi
}

setup_defaults() {
  : "${KIND_CLUSTER_NAME:=langgraph-cloud-dev}"
  : "${KUBE_CONTEXT:=kind-${KIND_CLUSTER_NAME}}"
  : "${NAMESPACE:=langgraph-cloud-dev}"
  : "${RELEASE_NAME:=langgraph-cloud-dev}"
  : "${CHART_DIR:=charts/langgraph-cloud}"
  : "${DEV_VALUES_FILE:=charts/langgraph-cloud/ci/dev-kind-values.yaml}"
  : "${MONGO_FIXTURE_FILE:=hack/fixtures/mongo.yaml}"
  : "${PORT_FORWARD_PORT:=8000}"
  : "${WAIT_TIMEOUT:=10m}"
  : "${INSTALL_MONGO_FIXTURE:=1}"
  : "${DEBUG_OUTPUT_DIR:=$(repo_root)/.tmp/langgraph-cloud-dev-debug}"
}

setup_defaults

kubectl_ctx() {
  kubectl --context "$KUBE_CONTEXT" "$@"
}

helm_ctx() {
  helm --kube-context "$KUBE_CONTEXT" "$@"
}

ensure_kind_cluster_exists() {
  kind get clusters | grep -qx "$KIND_CLUSTER_NAME" || die "kind cluster \"$KIND_CLUSTER_NAME\" does not exist"
}

ensure_kind_context() {
  [[ "$KUBE_CONTEXT" == kind-* ]] || die "refusing to run against non-kind context \"$KUBE_CONTEXT\""
  ensure_kind_cluster_exists
}

ensure_namespace() {
  if ! kubectl_ctx get namespace "$NAMESPACE" >/dev/null 2>&1; then
    log "Creating namespace $NAMESPACE"
    kubectl_ctx create namespace "$NAMESPACE" >/dev/null
  fi
}

parse_api_image() {
  local image_ref image_no_digest last_segment

  API_IMAGE_REPOSITORY=""
  API_IMAGE_TAG=""
  API_IMAGE_REF=""

  if [[ -n "${LANGGRAPH_CLOUD_API_IMAGE:-}" ]]; then
    image_ref="${LANGGRAPH_CLOUD_API_IMAGE}"
    image_no_digest="${image_ref%@*}"
    last_segment="${image_no_digest##*/}"

    [[ "$last_segment" == *:* ]] || die "LANGGRAPH_CLOUD_API_IMAGE must include a tag, got \"$image_ref\""

    API_IMAGE_REPOSITORY="${image_no_digest%:*}"
    API_IMAGE_TAG="${image_no_digest##*:}"
    API_IMAGE_REF="${image_no_digest}"
  elif [[ -n "${LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY:-}" || -n "${LANGGRAPH_CLOUD_API_IMAGE_TAG:-}" ]]; then
    API_IMAGE_REPOSITORY="${LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY:-}"
    API_IMAGE_TAG="${LANGGRAPH_CLOUD_API_IMAGE_TAG:-}"
    [[ -n "$API_IMAGE_REPOSITORY" && -n "$API_IMAGE_TAG" ]] || die "set LANGGRAPH_CLOUD_API_IMAGE or both LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY and LANGGRAPH_CLOUD_API_IMAGE_TAG"
    API_IMAGE_REF="${API_IMAGE_REPOSITORY}:${API_IMAGE_TAG}"
  else
    die "cloud-dev-up requires an explicit API image; set LANGGRAPH_CLOUD_API_IMAGE or both LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY and LANGGRAPH_CLOUD_API_IMAGE_TAG"
  fi

  export API_IMAGE_REPOSITORY API_IMAGE_TAG API_IMAGE_REF
}

maybe_load_api_image() {
  : "${KIND_LOAD_IMAGE:=auto}"

  if [[ -z "${API_IMAGE_REF:-}" ]]; then
    return 0
  fi

  case "$KIND_LOAD_IMAGE" in
    0|false|never)
      log "Skipping kind image load for $API_IMAGE_REF"
      return
      ;;
  esac

  if ! command -v docker >/dev/null 2>&1; then
    if [[ "$KIND_LOAD_IMAGE" == "always" ]]; then
      die "docker is required when KIND_LOAD_IMAGE=always"
    fi
    warn "docker not found; skipping kind image load and relying on remote image pulls"
    return
  fi

  if docker image inspect "$API_IMAGE_REF" >/dev/null 2>&1; then
    log "Loading $API_IMAGE_REF into kind cluster $KIND_CLUSTER_NAME"
    kind load docker-image "$API_IMAGE_REF" --name "$KIND_CLUSTER_NAME" >/dev/null
  elif [[ "$KIND_LOAD_IMAGE" == "always" ]]; then
    die "local Docker image $API_IMAGE_REF was not found"
  else
    warn "local Docker image $API_IMAGE_REF was not found; relying on remote image pulls"
  fi
}

find_release_resource_with_suffix() {
  local resource_kind="$1"
  local suffix="$2"
  local resource_name

  resource_name="$(
    kubectl_ctx -n "$NAMESPACE" get "$resource_kind" \
      -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' |
      grep -E -- "${suffix}\$" |
      head -n1 ||
      true
  )"

  [[ -n "$resource_name" ]] || die "could not find $resource_kind resource for release $RELEASE_NAME ending with \"$suffix\""
  printf '%s\n' "$resource_name"
}

wait_for_release_deployment_suffix() {
  local suffix="$1"
  local resource_name
  resource_name="$(find_release_resource_with_suffix deploy "$suffix")"
  log "Waiting for deployment/$resource_name"
  kubectl_ctx -n "$NAMESPACE" rollout status "deployment/$resource_name" --timeout "$WAIT_TIMEOUT"
}

wait_for_release_statefulset_suffix() {
  local suffix="$1"
  local resource_name
  resource_name="$(find_release_resource_with_suffix statefulset "$suffix")"
  log "Waiting for statefulset/$resource_name"
  kubectl_ctx -n "$NAMESPACE" rollout status "statefulset/$resource_name" --timeout "$WAIT_TIMEOUT"
}
