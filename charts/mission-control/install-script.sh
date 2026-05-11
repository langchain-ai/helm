#!/usr/bin/env bash
# Mission Control installer.
#
# Usage:
#   ./install-script.sh [subcommand] [flags]
#   bash -c "$(curl -fsSL <raw-script-url>)" -- [subcommand] [flags]
#
# Subcommands (run individually or `all` for end-to-end):
#   prereqs    Verify kubectl/helm versions and required RBAC verbs
#   namespace  Create the langsmith namespace
#   secret     Create mission-control-auth Secret (interactive unless --username/--password-stdin)
#   values     Write a default values.yaml (skipped if file exists; use --force to overwrite)
#   install    helm upgrade --install from --chart-path, or from the public Helm repo
#   forward    kubectl port-forward the frontend on :3000
#   all        prereqs + namespace + secret + values + install (no forward)
#
# Flags:
#   -n, --namespace NAME       Kubernetes namespace (default: langsmith)
#   -r, --release NAME         Helm release name (default: mission-control)
#   -c, --chart-path PATH      Local Helm chart path (default: auto)
#       --chart-ref REF        Public Helm chart ref used when no local chart exists
#                              (default: langchain/mission-control)
#       --helm-repo-url URL    Public Helm repo URL
#                              (default: https://langchain-ai.github.io/helm)
#       --values-url URL       Public default values.yaml URL
#   -f, --values-file PATH     Values file path (default: values.yaml)
#   -u, --username NAME        Auth username (skips prompt)
#       --password-stdin       Read auth password from stdin (skips prompt)
#       --force                Overwrite existing values.yaml
#       --skip-rbac-check      Skip kubectl auth can-i checks in prereqs
#       --port LOCAL:REMOTE    Port mapping for forward (default: 3000:3000)
#       --frontend-service NAME
#                              Frontend Service name (default: mission-control-frontend)
#   -h, --help                 Show this help

set -euo pipefail

DEFAULT_CHART_REF="langchain/mission-control"
DEFAULT_HELM_REPO_NAME="langchain"
DEFAULT_HELM_REPO_URL="https://langchain-ai.github.io/helm"
DEFAULT_VALUES_URL="https://raw.githubusercontent.com/langchain-ai/helm/main/charts/mission-control/values.yaml"

NAMESPACE="langsmith"
RELEASE="mission-control"
CHART_PATH="auto"
CHART_REF="${MISSION_CONTROL_CHART_REF:-$DEFAULT_CHART_REF}"
HELM_REPO_NAME="${MISSION_CONTROL_HELM_REPO_NAME:-$DEFAULT_HELM_REPO_NAME}"
HELM_REPO_URL="${MISSION_CONTROL_HELM_REPO_URL:-$DEFAULT_HELM_REPO_URL}"
VALUES_URL="${MISSION_CONTROL_VALUES_URL:-$DEFAULT_VALUES_URL}"
VALUES_FILE="values.yaml"
USERNAME=""
PASSWORD_STDIN=0
FORCE=0
SKIP_RBAC_CHECK=0
PORT_MAP="3000:3000"
FRONTEND_SERVICE="mission-control-frontend"

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

sync_values_namespace() {
  if [[ "$NAMESPACE" == "langsmith" || ! -f "$VALUES_FILE" ]]; then
    return 0
  fi
  sed -i.bak "s/^namespace: .*/namespace: ${NAMESPACE}/" "$VALUES_FILE" && rm -f "${VALUES_FILE}.bak"
}

usage() {
  cat <<'USAGE'
Mission Control installer.

Usage:
  ./install-script.sh [subcommand] [flags]
  bash -c "$(curl -fsSL <raw-script-url>)" -- [subcommand] [flags]

Subcommands:
  prereqs    Verify kubectl/helm versions and required RBAC verbs
  namespace  Create the langsmith namespace
  secret     Create mission-control-auth Secret
  values     Write a default values.yaml
  install    helm upgrade --install from --chart-path, or from the public Helm repo
  forward    kubectl port-forward the frontend on :3000
  all        prereqs + namespace + secret + values + install

Flags:
  -n, --namespace NAME       Kubernetes namespace (default: langsmith)
  -r, --release NAME         Helm release name (default: mission-control)
  -c, --chart-path PATH      Local Helm chart path (default: auto)
      --chart-ref REF        Public Helm chart ref used when no local chart exists
                             (default: langchain/mission-control)
      --helm-repo-url URL    Public Helm repo URL
                             (default: https://langchain-ai.github.io/helm)
      --values-url URL       Public default values.yaml URL
  -f, --values-file PATH     Values file path (default: values.yaml)
  -u, --username NAME        Auth username (skips prompt)
      --password-stdin       Read auth password from stdin (skips prompt)
      --force                Overwrite existing values.yaml
      --skip-rbac-check      Skip kubectl auth can-i checks in prereqs
      --port LOCAL:REMOTE    Port mapping for forward (default: 3000:3000)
      --frontend-service NAME
                             Frontend Service name (default: mission-control-frontend)
  -h, --help                 Show this help
USAGE
}

require_arg() {
  [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
}

parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--namespace)        require_arg "$1" "${2:-}"; NAMESPACE="$2"; shift 2 ;;
      -r|--release)          require_arg "$1" "${2:-}"; RELEASE="$2"; shift 2 ;;
      -c|--chart-path)       require_arg "$1" "${2:-}"; CHART_PATH="$2"; shift 2 ;;
      --chart-ref)           require_arg "$1" "${2:-}"; CHART_REF="$2"; shift 2 ;;
      --helm-repo-url)       require_arg "$1" "${2:-}"; HELM_REPO_URL="$2"; shift 2 ;;
      --values-url)          require_arg "$1" "${2:-}"; VALUES_URL="$2"; shift 2 ;;
      -f|--values-file)      require_arg "$1" "${2:-}"; VALUES_FILE="$2"; shift 2 ;;
      -u|--username)         require_arg "$1" "${2:-}"; USERNAME="$2"; shift 2 ;;
      --password-stdin)      PASSWORD_STDIN=1; shift ;;
      --force)               FORCE=1; shift ;;
      --skip-rbac-check)     SKIP_RBAC_CHECK=1; shift ;;
      --port)                require_arg "$1" "${2:-}"; PORT_MAP="$2"; shift 2 ;;
      --frontend-service)    require_arg "$1" "${2:-}"; FRONTEND_SERVICE="$2"; shift 2 ;;
      -h|--help)             usage; exit 0 ;;
      *)                     die "unknown flag: $1" ;;
    esac
  done
}

needs_public_chart() {
  [[ "$CHART_PATH" == "auto" && ! -f "./Chart.yaml" ]]
}

step_prereqs() {
  need kubectl
  need helm
  if needs_public_chart; then
    need curl
  fi
  if [[ $SKIP_RBAC_CHECK -eq 1 ]]; then
    echo "  [skip] kubectl auth can-i RBAC checks"
    return 0
  fi
  local checks=(
    "create clusterrole"
    "create clusterrolebinding"
    "create serviceaccount -n $NAMESPACE"
    "create deployment -n $NAMESPACE"
    "create secret -n $NAMESPACE"
  )
  local fail=0
  for c in "${checks[@]}"; do
    # shellcheck disable=SC2086
    if [[ "$(kubectl auth can-i $c 2>/dev/null)" != "yes" ]]; then
      echo "  [!] kubectl auth can-i $c -> no"
      fail=1
    else
      echo "  [ok] kubectl auth can-i $c"
    fi
  done
  if [[ $fail -ne 0 ]]; then
    cat >&2 <<EOF

Missing Kubernetes permissions for install.

Mission Control installs a ServiceAccount, ClusterRole, and ClusterRoleBinding.
Ask a cluster admin to run this installer, or grant an installer role that can create:
- clusterroles
- clusterrolebindings
- serviceaccounts in ${NAMESPACE}
- deployments in ${NAMESPACE}
- secrets in ${NAMESPACE}

If your organization intentionally blocks kubectl auth can-i but Helm is approved
through another control path, rerun with --skip-rbac-check.
EOF
    exit 1
  fi
}

resolve_chart_path() {
  if [[ "$CHART_PATH" != "auto" ]]; then
    [[ -f "$CHART_PATH/Chart.yaml" ]] || die "Chart.yaml not found in --chart-path $CHART_PATH"
    return 0
  fi

  if [[ -f "./Chart.yaml" && -d "./templates" ]]; then
    CHART_PATH="."
    return 0
  fi

  echo "Using public Helm chart ${CHART_REF}"
  helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" --force-update >/dev/null
  helm repo update >/dev/null
  CHART_PATH="$CHART_REF"
}

step_namespace() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

step_secret() {
  local user pass
  if [[ -n "$USERNAME" ]]; then
    user="$USERNAME"
  else
    read -r -p "Username: " user
  fi
  if [[ $PASSWORD_STDIN -eq 1 ]]; then
    IFS= read -r pass
  else
    read -r -s -p "Password: " pass; echo
  fi
  [[ -n "$user" && -n "$pass" ]] || die "username and password required"

  kubectl create secret generic mission-control-auth \
    --namespace="$NAMESPACE" \
    --from-literal=username="$user" \
    --from-literal=password="$pass" \
    --dry-run=client -o yaml | kubectl apply -f -
}

step_values() {
  if [[ -e "$VALUES_FILE" && $FORCE -ne 1 ]]; then
    echo "  $VALUES_FILE exists; skipping (use --force to overwrite)"
    return 0
  fi
  if command -v curl >/dev/null 2>&1 && curl -fsSL "$VALUES_URL" -o "$VALUES_FILE"; then
    sync_values_namespace
    echo "  wrote $VALUES_FILE from $VALUES_URL"
    return 0
  fi

  echo "  unable to download $VALUES_URL; writing embedded defaults"
  cat > "$VALUES_FILE" <<YAML
namespace: $NAMESPACE

images:
  registry: ""
  imagePullSecrets:
    - name: regcred
  backendImage:
    repository: langchain/mission-control
    pullPolicy: IfNotPresent
    tag: backend-latest
  frontendImage:
    repository: langchain/mission-control
    pullPolicy: IfNotPresent
    tag: frontend-latest

backend:
  replicas: 1
  podSecurityContext: {}
  securityContext: {}
  extraEnv: []
  resources:
    requests: { cpu: 250m, memory: 256Mi }
    limits:   { cpu: 500m, memory: 512Mi }
  service: { type: ClusterIP, port: 8000 }
  serviceAccount:
    create: true
    name: ""

frontend:
  replicas: 1
  podSecurityContext: {}
  securityContext: {}
  extraEnv: []
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits:   { cpu: 200m, memory: 256Mi }
  service: { type: ClusterIP, port: 3000 }

ingress:
  enabled: false
  host: ""

config:
  auth:
    enabled: true
    existingSecret: mission-control-auth
    usernameKey: username
    passwordKey: password
    jwtSecretKey: ""
    allowedOrigins: ""
  features:
    fixIssue: true
    adopt: true
    alerts: true
    chat: true
    diagnostics: true
    configSave: true
    discover: true
    dbTools: true
    deploy: false
  discoverNamespaces: ""

diagnostics:
  persistence:
    enabled: false
    storageClass: ""
    size: 1Gi
    accessMode: ReadWriteOnce
YAML
  echo "  wrote $VALUES_FILE"
}

step_install() {
  [[ -e "$VALUES_FILE" ]] || die "$VALUES_FILE not found; run 'values' step first"
  resolve_chart_path
  helm upgrade --install "$RELEASE" "$CHART_PATH" \
    -n "$NAMESPACE" \
    --create-namespace \
    -f "$VALUES_FILE" \
    --rollback-on-failure
  kubectl get pods -n "$NAMESPACE"
}

step_forward() {
  echo "Opening http://localhost:${PORT_MAP%%:*} once the forward is up..."
  exec kubectl port-forward "svc/${FRONTEND_SERVICE}" "$PORT_MAP" -n "$NAMESPACE"
}

main() {
  local cmd="${1:-all}"
  [[ $# -gt 0 ]] && shift || true
  parse_flags "$@"

  case "$cmd" in
    prereqs)   step_prereqs ;;
    namespace) step_namespace ;;
    secret)    step_secret ;;
    values)    step_values ;;
    install)   step_install ;;
    forward)   step_forward ;;
    all)
      step_prereqs
      step_namespace
      step_secret
      step_values
      step_install
      echo
      echo "Done. To access the UI:"
      echo "  kubectl port-forward svc/${FRONTEND_SERVICE} ${PORT_MAP} -n ${NAMESPACE}"
      ;;
    -h|--help) usage ;;
    *)         die "unknown subcommand: $cmd (try --help)" ;;
  esac
}

main "$@"
