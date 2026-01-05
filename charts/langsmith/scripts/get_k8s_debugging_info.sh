#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# LangSmith k8s debugging bundle
# Canonical script (merge of helm + reference)
# -----------------------------

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC} %s\n" "$*"; }

usage() {
  cat <<'EOF'
Usage:
  ./get_k8s_debugging_info.sh --namespace <namespace> [--since <duration>] [--aws-region <region>] [--include-aws]

Options:
  --namespace      Kubernetes namespace (required)
  --since          Log lookback window for current logs (default: 24h)
  --aws-region     AWS region for ELBv2 calls (default: $AWS_REGION or us-west-2)
  --include-aws    Attempt AWS ALB/target-group diagnostics (requires aws CLI configured)

Notes:
  - This script reads cluster state and collects logs; it does not mutate Kubernetes resources.
  - Bundles output to .zip when available, else .tar.gz.
EOF
}

NS=""
LOG_SINCE="24h"
AWS_REGION_DEFAULT="${AWS_REGION:-us-west-2}"
INCLUDE_AWS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NS="${2:-}"; shift 2 ;;
    --since) LOG_SINCE="${2:-}"; shift 2 ;;
    --aws-region) AWS_REGION_DEFAULT="${2:-}"; shift 2 ;;
    --include-aws) INCLUDE_AWS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown parameter: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${NS}" ]]; then
  error "Missing --namespace"
  usage
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  error "kubectl not found in PATH"
  exit 1
fi

if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
  error "Namespace '${NS}' does not exist or you do not have access."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found. Per-container restart counting will be degraded (previous logs may be incomplete)."
fi

DIR="/tmp/langchain-debugging-$(date +%Y%m%d%H%M%S)"
mkdir -p "${DIR}"
mkdir -p "${DIR}/logs"

info "Starting k8s debugging capture"
info "Namespace: ${NS}"
info "Output directory: ${DIR}"
info "Log window: --since=${LOG_SINCE}"

capture() {
  local desc="$1"
  local cmd="$2"
  local out="$3"

  info "Capturing: ${desc}"
  if bash -c "${cmd}" > "${DIR}/${out}" 2>&1; then
    ok "Saved: ${out}"
  else
    warn "Failed: ${desc} (see ${out})"
  fi
}

# --- Core (helm script behavior) ---
capture "Resources summary (get all -o wide)" \
  "kubectl get all -n \"${NS}\" -o wide" \
  "resources_summary.txt"

capture "Resources details (get all -o yaml)" \
  "kubectl get all -n \"${NS}\" -o yaml" \
  "resources_details.yaml"

capture "Kubernetes events" \
  "kubectl get events -n \"${NS}\" --sort-by=.lastTimestamp" \
  "events.txt"

# Pod metrics (containers)
if kubectl top pods -n "${NS}" --containers >/dev/null 2>&1; then
  capture "Pod resource usage (kubectl top pods --containers)" \
    "kubectl top pods -n \"${NS}\" --containers" \
    "pod-resource-usage.txt"
else
  warn "Metrics not available for pods (metrics-server likely missing). Skipping pod-resource-usage.txt"
fi

# --- Added: nodes + top nodes (from capture-diagnostics) ---
capture "Node list (wide)" \
  "kubectl get nodes -o wide" \
  "nodes-wide.txt"

if kubectl top nodes >/dev/null 2>&1; then
  capture "Node resource usage (kubectl top nodes)" \
    "kubectl top nodes" \
    "nodes-top.txt"
else
  warn "Metrics not available for nodes (metrics-server likely missing). Skipping nodes-top.txt"
fi

# --- Added: ingress/service/endpoints (from capture-diagnostics) ---
capture "Ingress resources (wide)" \
  "kubectl get ingress -n \"${NS}\" -o wide" \
  "ingress-list.txt"

INGRESS_RESOURCES="$(kubectl get ingress -n "${NS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
if [[ -n "${INGRESS_RESOURCES}" ]]; then
  for INGRESS in ${INGRESS_RESOURCES}; do
    capture "Ingress describe: ${INGRESS}" \
      "kubectl describe ingress \"${INGRESS}\" -n \"${NS}\"" \
      "ingress-${INGRESS}-describe.txt"
    capture "Ingress YAML: ${INGRESS}" \
      "kubectl get ingress \"${INGRESS}\" -n \"${NS}\" -o yaml" \
      "ingress-${INGRESS}.yaml"
  done
else
  warn "No ingresses found in namespace ${NS}"
fi

capture "Service list (wide)" \
  "kubectl get svc -n \"${NS}\" -o wide" \
  "services-list.txt"

capture "Endpoints" \
  "kubectl get endpoints -n \"${NS}\"" \
  "endpoints.txt"

SERVICES="$(kubectl get svc -n "${NS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
if [[ -n "${SERVICES}" ]]; then
  for SVC in ${SERVICES}; do
    capture "Service describe: ${SVC}" \
      "kubectl describe svc \"${SVC}\" -n \"${NS}\"" \
      "svc-${SVC}-describe.txt"
  done
fi

# --- Added: PVC + controllers (from capture-diagnostics) ---
capture "PersistentVolumeClaims" \
  "kubectl get pvc -n \"${NS}\" -o wide" \
  "pvc-list.txt"

capture "StatefulSets (wide)" \
  "kubectl get statefulsets -n \"${NS}\" -o wide" \
  "statefulsets.txt"

capture "Deployments (wide)" \
  "kubectl get deployments -n \"${NS}\" -o wide" \
  "deployments.txt"

# --- Logs (helm script behavior: per pod/container, current + previous) ---
info "Capturing container logs for all pods/containers (current + previous where restarted)..."
PODS="$(kubectl get pods -n "${NS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"

if [[ -z "${PODS}" ]]; then
  warn "No pods found in namespace ${NS}; skipping logs."
else
  for POD in ${PODS}; do
    CONTAINERS="$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
    for CONTAINER in ${CONTAINERS}; do
      info "Logs (current, since ${LOG_SINCE}): ${POD}/${CONTAINER}"
      kubectl logs -n "${NS}" "${POD}" -c "${CONTAINER}" --since="${LOG_SINCE}" \
        > "${DIR}/logs/${POD}_${CONTAINER}_current.log" 2>/dev/null || true

      # Previous logs when restarted
      if command -v jq >/dev/null 2>&1; then
        RESTART_COUNT="$(kubectl get pod "${POD}" -n "${NS}" -o json \
          | jq -r ".status.containerStatuses[] | select(.name==\"${CONTAINER}\") | .restartCount // 0" 2>/dev/null || echo 0)"
        if [[ "${RESTART_COUNT}" -gt 0 ]]; then
          info "Logs (previous): ${POD}/${CONTAINER} restarted (${RESTART_COUNT})"
          kubectl logs -n "${NS}" "${POD}" -c "${CONTAINER}" --previous \
            > "${DIR}/logs/${POD}_${CONTAINER}_previous.log" 2>/dev/null || true
        fi
      else
        # Fallback: try previous logs anyway (may fail noisily; we ignore)
        kubectl logs -n "${NS}" "${POD}" -c "${CONTAINER}" --previous \
          > "${DIR}/logs/${POD}_${CONTAINER}_previous.log" 2>/dev/null || true
      fi
    done
  done
fi

# --- Added: AWS ALB target group health (from capture-diagnostics) ---
# Gated behind --include-aws to avoid surprising failures in restricted environments.
if [[ "${INCLUDE_AWS}" == "true" ]]; then
  if command -v aws >/dev/null 2>&1; then
    info "AWS diagnostics enabled. Attempting ALB target group + target health capture..."
    if [[ -n "${INGRESS_RESOURCES}" ]]; then
      for INGRESS in ${INGRESS_RESOURCES}; do
        # Best-effort ways to identify the ALB:
        # 1) alb.ingress.kubernetes.io/load-balancer-name
        # 2) alb.ingress.kubernetes.io/load-balancer-id (nonstandard; keep for backward compatibility)
        # 3) .status.loadBalancer.ingress[].hostname (resolve to ALB via AWS)
        LB_NAME="$(kubectl get ingress "${INGRESS}" -n "${NS}" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-name}' 2>/dev/null || true)"
        LB_ID_ANN="$(kubectl get ingress "${INGRESS}" -n "${NS}" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-id}' 2>/dev/null || true)"
        LB_HOST="$(kubectl get ingress "${INGRESS}" -n "${NS}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

        ALB_ARN=""

        if [[ -n "${LB_ID_ANN}" ]] && [[ "${LB_ID_ANN}" == arn:aws:elasticloadbalancing:* ]]; then
          ALB_ARN="${LB_ID_ANN}"
        elif [[ -n "${LB_NAME}" ]]; then
          ALB_ARN="$(aws elbv2 describe-load-balancers --names "${LB_NAME}" --region "${AWS_REGION_DEFAULT}" \
            --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
        elif [[ -n "${LB_HOST}" ]]; then
          # LB_HOST usually contains the ALB DNS name; find matching LB by DNSName.
          ALB_ARN="$(aws elbv2 describe-load-balancers --region "${AWS_REGION_DEFAULT}" \
            --query "LoadBalancers[?DNSName=='${LB_HOST}'].LoadBalancerArn | [0]" --output text 2>/dev/null || true)"
        fi

        if [[ -z "${ALB_ARN}" || "${ALB_ARN}" == "None" ]]; then
          warn "Could not resolve ALB ARN for ingress ${INGRESS} (name='${LB_NAME}', host='${LB_HOST}'). Skipping AWS checks."
          continue
        fi

        capture "ALB info (ARN) for ingress ${INGRESS}" \
          "printf '%s\n' '${ALB_ARN}'" \
          "alb-${INGRESS}-info.txt"

        # Target groups
        if aws elbv2 describe-target-groups --load-balancer-arn "${ALB_ARN}" --region "${AWS_REGION_DEFAULT}" >/dev/null 2>&1; then
          capture "ALB target groups for ${INGRESS}" \
            "aws elbv2 describe-target-groups --load-balancer-arn \"${ALB_ARN}\" --region \"${AWS_REGION_DEFAULT}\"" \
            "alb-${INGRESS}-target-groups.json"

          TARGET_GROUPS="$(aws elbv2 describe-target-groups --load-balancer-arn "${ALB_ARN}" --region "${AWS_REGION_DEFAULT}" \
            --query 'TargetGroups[*].TargetGroupArn' --output text 2>/dev/null || true)"

          if [[ -n "${TARGET_GROUPS}" ]]; then
            for TG_ARN in ${TARGET_GROUPS}; do
              TG_ID="${TG_ARN##*/}" # safer than basename for ARNs
              capture "Target health for ${INGRESS} TG=${TG_ARN}" \
                "aws elbv2 describe-target-health --target-group-arn \"${TG_ARN}\" --region \"${AWS_REGION_DEFAULT}\"" \
                "alb-${INGRESS}-target-health-${TG_ID}.json"
            done
          else
            warn "No target groups found for ALB ${ALB_ARN}"
          fi
        else
          warn "AWS call failed: describe-target-groups for ALB ${ALB_ARN} (region ${AWS_REGION_DEFAULT})"
        fi
      done
    else
      warn "No ingresses found; skipping AWS ALB diagnostics."
    fi
  else
    warn "aws CLI not found; skipping AWS diagnostics."
  fi
else
  info "AWS diagnostics disabled (pass --include-aws to enable)."
fi

# --- Added: summary.txt (from capture-diagnostics) ---
SUMMARY_FILE="${DIR}/summary.txt"
{
  echo "LangSmith Self-Hosted Diagnostics Summary"
  echo "========================================"
  echo "Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Namespace: ${NS}"
  echo "Output Directory: ${DIR}"
  echo ""
  echo "Configuration:"
  echo "  LOG_SINCE: ${LOG_SINCE}"
  echo "  AWS_REGION: ${AWS_REGION_DEFAULT}"
  echo "  INCLUDE_AWS: ${INCLUDE_AWS}"
  echo ""
  echo "Captured Information:"
  echo "  - kubectl get all (wide + yaml)"
  echo "  - events"
  echo "  - pod metrics (if available)"
  echo "  - per-container logs (current since window + previous on restart)"
  echo "  - ingress list + describe + yaml"
  echo "  - services list + describe"
  echo "  - endpoints"
  echo "  - nodes list + node metrics (if available)"
  echo "  - pvc list"
  echo "  - statefulsets + deployments"
  if [[ "${INCLUDE_AWS}" == "true" ]] && command -v aws >/dev/null 2>&1; then
    echo "  - ALB target groups + target health (best-effort)"
  fi
  echo ""
  echo "Files captured:"
  find "${DIR}" -type f | sort | sed 's|^|  |'
} > "${SUMMARY_FILE}"

ok "Diagnostics capture complete."
ok "Summary: ${SUMMARY_FILE}"

# --- Bundle (helm script behavior) ---
info "Compressing directory..."
if command -v zip >/dev/null 2>&1; then
  zip -r "${DIR}.zip" "${DIR}" >/dev/null && ok "Bundle written to ${DIR}.zip"
else
  warn "zip not available; falling back to tar.gz (zip is nicer for Slack uploads)."
  tar -czf "${DIR}.tar.gz" -C "$(dirname "${DIR}")" "$(basename "${DIR}")" && ok "Bundle written to ${DIR}.tar.gz"
fi
