#!/bin/bash

# Diagnostic collection for self-hosted LangSmith/LangGraph clusters.
#
# Default: collects everything — kubectl describe, events, resources, pod
# metrics, and pod logs (last 24h + previous on restart).
#
# --redact  : apply best-effort redaction to all collected files (secrets, PII,
#             ICD-10, trace payload fields). REVIEW THE BUNDLE BEFORE SHARING —
#             regex cannot catch unstructured PHI such as patient names or
#             medical narratives inside log messages.

REDACT=0
COLLECT_LOGS=1
COLLECT_DESCRIBE=1

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --namespace)       NS="$2"; shift ;;
    --redact)          REDACT=1 ;;
    --exclude-logs)    COLLECT_LOGS=0 ;;
    --exclude-describe) COLLECT_DESCRIBE=0 ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$NS" ]]; then
  echo "Usage: $0 --namespace <namespace> [--redact] [--exclude-logs] [--exclude-describe]"
  exit 1
fi

# Validate namespace to a safe subset of Kubernetes namespace naming rules and
# prevent shell metacharacter injection.
if [[ ! "$NS" =~ ^[a-z0-9]([-a-z0-9]{0,251}[a-z0-9])?$ ]]; then
  echo "Error: namespace must match [a-z0-9]([-a-z0-9]*[a-z0-9])? and be ≤ 253 characters."
  exit 1
fi

# ---------------------------------------------------------------------------
# Redaction helpers
# ---------------------------------------------------------------------------

# sed patterns applied file-by-file. Order matters: auth headers / URIs first
# so URI-embedded Bearer tokens don't slip through later rules.
SED_ARGS=(
  # Auth headers / URIs
  -e 's/([Bb]earer )[A-Za-z0-9._~+/=-]+/\1***REDACTED***/g'
  -e 's/([Aa]uthorization: *)[^[:space:]"'"'"']+/\1***REDACTED***/g'
  -e 's#([A-Za-z][A-Za-z0-9+.-]*://[^:/?#[:space:]]+):[^@[:space:]]+@#\1:***REDACTED***@#g'
  # Env-var / kv / JSON sensitive assignments
  -e 's/((PASSWORD|PASSWD|TOKEN|SECRET|API[_-]?KEY|APIKEY|ACCESS[_-]?KEY|PRIVATE[_-]?KEY|CREDENTIAL|AUTH)[A-Z0-9_-]*[[:space:]]*=[[:space:]]*)[^[:space:]"'"'"']+/\1***REDACTED***/gi'
  -e 's/("(password|passwd|token|secret|api[_-]?key|apikey|access[_-]?key|private[_-]?key|credential|auth)[A-Za-z0-9_-]*"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Sensitive HTTP headers
  -e 's/("(x-service-key|x-api-key|x-auth-token|x-access-token|x-authorization|x-csrf-token|cookie|set-cookie)"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Tenant / user / customer / patient identifiers in headers
  -e 's/("(x-(tenant|user|organization|org|account|customer|patient|member|agent|thread|session|ls-user)[-_]id)"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Envoy peer metadata blobs
  -e 's/("x-envoy-peer-metadata(-id)?"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # AWS account IDs inside ARNs
  -e 's/(arn:aws[A-Za-z0-9-]*:[a-z0-9-]*:[a-z0-9-]*:)[0-9]{12}:/\1***REDACTED-AWS-ACCT***:/g'
  # LangSmith trace payload fields (inputs, outputs, messages, content, etc.)
  # These are not needed for infrastructure diagnostics and may carry PHI.
  -e 's/("(inputs|outputs|input|output|prompt|completion|messages|message|content|text|query|response|body|payload|extra|metadata|tags|run_inputs|run_outputs|trace_input|trace_output|input_text|output_text|tool_input|tool_output|args|arguments|function_call|tool_calls|chat_history|human|ai|system|user|assistant|generations|llm_output|observation|action_input|final_answer)"[[:space:]]*:[[:space:]]*")(\\.|[^"\\])*"/\1***REDACTED-TRACE***"/g'
  -e 's/("(inputs|outputs|input|output|messages|metadata|extra|tags|args|arguments|tool_calls|function_call|chat_history|generations|llm_output)"[[:space:]]*:[[:space:]]*)\{[^{}]*\}/\1{"r":"***REDACTED-TRACE***"}/g'
  -e 's/("(inputs|outputs|messages|tags|tool_calls|chat_history|args|generations)"[[:space:]]*:[[:space:]]*)\[[^][]*\]/\1["***REDACTED-TRACE***"]/g'
  # Known secret formats
  -e 's/sk-ant-[A-Za-z0-9_-]{20,}/***REDACTED-ANTHROPIC***/g'
  -e 's/sk-[A-Za-z0-9_-]{20,}/***REDACTED-OPENAI***/g'
  -e 's/(sk|pk|rk)_(live|test)_[A-Za-z0-9]{20,}/***REDACTED-STRIPE***/g'
  -e 's/xox[abprs]-[A-Za-z0-9-]{10,}/***REDACTED-SLACK***/g'
  -e 's#https://hooks\.slack\.com/services/[A-Za-z0-9/_-]+#***REDACTED-SLACK-WEBHOOK***#g'
  -e 's/AKIA[0-9A-Z]{16}/***REDACTED-AWS-KEY***/g'
  -e 's/ASIA[0-9A-Z]{16}/***REDACTED-AWS-STS***/g'
  -e 's/(ghp_|gho_|ghs_|ghu_|ghr_)[A-Za-z0-9]{30,}/***REDACTED-GITHUB***/g'
  -e 's/glpat-[A-Za-z0-9_-]{20,}/***REDACTED-GITLAB***/g'
  -e 's/AIza[0-9A-Za-z_-]{35}/***REDACTED-GOOGLE-API***/g'
  -e 's/(AC|SK)[0-9a-fA-F]{32}/***REDACTED-TWILIO***/g'
  -e 's/eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+\.[A-Za-z0-9_.+/=-]*/***REDACTED-JWT***/g'
  -e 's/lsv2_[A-Za-z0-9_]{20,}/***REDACTED-LANGSMITH***/g'
  # Long hex blobs (SHA hashes, generic tokens ≥ 40 chars)
  -e 's/[a-fA-F0-9]{40,}/***REDACTED-HEX***/g'
  # Personal identifiers
  -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/***REDACTED-EMAIL***/g'
  -e 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/***REDACTED-SSN***/g'
  -e 's/[0-9]{4}[ -][0-9]{4}[ -][0-9]{4}[ -][0-9]{4}/***REDACTED-CC***/g'
  -e 's/[0-9]{13,19}/***REDACTED-DIGITS***/g'
  -e 's/\+[1-9][0-9]{7,14}/***REDACTED-PHONE***/g'
  -e 's/\(?[0-9]{3}\)?[ .-][0-9]{3}[ .-][0-9]{4}/***REDACTED-PHONE***/g'
  # UUIDs (potential patient/record IDs)
  -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/***REDACTED-UUID***/g'
  # MAC addresses (before IPv6 to avoid overlap)
  -e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/***REDACTED-MAC***/g'
  # IPv4
  -e 's/(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)/\1***REDACTED-IP***\3/g'
  # IPv6 (loose)
  -e 's/([0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}/***REDACTED-IPV6***/g'
  # US ZIP codes
  -e 's/(^|[^0-9])[0-9]{5}(-[0-9]{4})?([^0-9]|$)/\1***REDACTED-ZIP***\3/g'
  # Dates (DOB candidates) — also affects k8s timestamps; accepted trade-off under --redact
  -e 's/[12][0-9]{3}-[0-1][0-9]-[0-3][0-9]/***REDACTED-DATE***/g'
  -e 's/[0-1]?[0-9][/-][0-3]?[0-9][/-][12][0-9]{3}/***REDACTED-DATE***/g'
  # ICD-10 diagnosis codes
  -e 's/(^|[^A-Z0-9])[A-TV-Z][0-9]{2}(\.[A-Z0-9]{1,4})?([^A-Z0-9]|$)/\1***REDACTED-ICD10***\3/g'
)

redact_file() {
  local f="$1"
  [[ ! -f "$f" ]] && return
  local tmp
  tmp="$(mktemp)" || return
  if sed -E "${SED_ARGS[@]}" "$f" > "$tmp"; then
    mv "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
}

# Strip PEM private-key blocks (multi-line).
redact_pem() {
  local f="$1"
  [[ ! -f "$f" ]] && return
  local tmp
  tmp="$(mktemp)" || return
  awk '
    {
      if ($0 ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) { in_key=1; print "***REDACTED-PRIVATE-KEY***"; next }
      if (in_key) {
        if ($0 ~ /-----END [A-Z ]*PRIVATE KEY-----/) in_key=0
        next
      }
      print
    }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# Redact value: lines in YAML whose preceding name: looks sensitive.
redact_env_yaml() {
  local f="$1"
  [[ ! -f "$f" ]] && return
  local tmp
  tmp="$(mktemp)" || return
  awk '
    {
      if ($0 ~ /^[[:space:]]*-?[[:space:]]*name:[[:space:]]*/) last_name = $0
      if ($0 ~ /^[[:space:]]*value:[[:space:]]*/ &&
          last_name ~ /(KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|APIKEY|API_KEY)/) {
        sub(/value:.*/, "value: \"***REDACTED***\"")
        last_name = ""
      }
      print
    }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# ---------------------------------------------------------------------------
# Warnings
# ---------------------------------------------------------------------------

if [[ "$REDACT" -eq 0 ]]; then
  cat >&2 <<'EOF'
==============================================================================
WARNING: bundle is collected RAW (no --redact).
  Pod logs may contain customer inputs, outputs, or other sensitive data
  including PII or PHI. REVIEW THE BUNDLE BEFORE SHARING with LangChain
  Support. Use --redact for best-effort scrubbing (still not a guarantee).
==============================================================================
EOF
fi

if [[ "$REDACT" -eq 1 ]]; then
  cat >&2 <<'EOF'
==============================================================================
--redact is ENABLED. Best-effort scrub across the entire bundle for:
  secrets   : API keys (OpenAI, Anthropic, Stripe, Slack, AWS, GCP, GitHub,
              GitLab, Twilio, LangSmith), JWTs, Bearer/Authorization headers,
              passwords in URIs, env/JSON values for *KEY|SECRET|TOKEN|
              PASSWORD|CREDENTIAL, PEM private-key blocks, long hex blobs.
  identifiers: emails, phones, SSNs, card numbers, ZIP codes, UUIDs,
              IPv4/IPv6, MAC addresses, dates (DOB-shaped), ICD-10 codes,
              tenant/user/org/customer/patient/agent/thread IDs in headers,
              AWS account IDs in ARNs.
  trace data: inputs, outputs, messages, prompts, completions, content, text,
              tool calls, chat history, metadata, tags, extra — i.e. anything
              that could carry a user payload.

  --redact will mangle k8s timestamps, cluster IPs, and resource hashes.
  It WILL NOT catch unstructured PHI such as patient names, street addresses,
  or medical narratives inside log messages. REVIEW THE BUNDLE BEFORE SHARING.
==============================================================================
EOF
fi

# ---------------------------------------------------------------------------
# Collection
# ---------------------------------------------------------------------------

DIR=/tmp/langchain-debugging-$(date +%Y%m%d%H%M%S)

echo "Starting to pull debugging info. Creating directory $DIR..."
mkdir -p "$DIR"

echo "Pulling summary of resources..."
kubectl get all -n "$NS" -o wide > "$DIR/resources_summary.txt"

echo "Pulling details of all resources..."
kubectl get all -n "$NS" -o yaml > "$DIR/resources_details.yaml"

echo "Pulling kubernetes events..."
kubectl get events -n "$NS" --sort-by=.lastTimestamp > "$DIR/events.txt"

echo "Pulling resource usage for all pods..."
kubectl top pods -n "$NS" --containers > "$DIR/pod-resource-usage.txt"

PODS=$(kubectl get pods -n "$NS" -o jsonpath='{.items[*].metadata.name}')

if [[ "$COLLECT_DESCRIBE" -eq 1 ]]; then
  echo "Pulling describe output for all pods..."
  mkdir -p "$DIR/describe"
  for POD in $PODS; do
    echo "  Describing pod $POD..."
    kubectl describe pod "$POD" -n "$NS" > "$DIR/describe/${POD}_describe.txt" 2>/dev/null
  done
else
  echo "Skipping describe (--exclude-describe set)."
fi

if [[ "$COLLECT_LOGS" -eq 1 ]]; then
  echo "Pulling container logs for all pods (last 24h + previous on restart)..."
  mkdir -p "$DIR/logs"
  for POD in $PODS; do
    CONTAINERS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.containers[*].name}')
    for CONTAINER in $CONTAINERS; do
      echo "  Pulling logs for $POD/$CONTAINER..."
      kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --since=24h \
        > "$DIR/logs/${POD}_${CONTAINER}_current.log" 2>/dev/null

      RESTART_COUNT=$(kubectl get pod "$POD" -n "$NS" -o json \
        | jq ".status.containerStatuses[] | select(.name==\"$CONTAINER\") | .restartCount // 0")
      if [[ "$RESTART_COUNT" -gt 0 ]]; then
        echo "  $POD/$CONTAINER restarted ($RESTART_COUNT times) — grabbing previous logs..."
        kubectl logs -n "$NS" "$POD" -c "$CONTAINER" --previous \
          > "$DIR/logs/${POD}_${CONTAINER}_previous.log" 2>/dev/null
      fi
    done
  done
else
  echo "Skipping pod logs (--exclude-logs set)."
fi

# ---------------------------------------------------------------------------
# Helm values
# ---------------------------------------------------------------------------

if command -v helm >/dev/null 2>&1; then
  echo "Pulling Helm release values for namespace $NS..."
  mkdir -p "$DIR/helm-values"
  while IFS= read -r RELEASE; do
    # Validate release name — same safe character set as k8s names.
    if [[ ! "$RELEASE" =~ ^[a-z0-9]([-a-z0-9]{0,51}[a-z0-9])?$ ]]; then
      echo "  Skipping release with unexpected name: $RELEASE"
      continue
    fi
    echo "  Getting values for release: $RELEASE..."
    helm get values "$RELEASE" -n "$NS" > "$DIR/helm-values/${RELEASE}_values.yaml" 2>/dev/null
  done < <(helm list -n "$NS" -q)
else
  echo "helm not found — skipping Helm values collection."
fi

# ---------------------------------------------------------------------------
# Redaction pass
# ---------------------------------------------------------------------------

if [[ "$REDACT" -eq 1 ]]; then
  echo "Applying redaction pass over collected files..."
  redact_env_yaml "$DIR/resources_details.yaml"
  while IFS= read -r -d '' file; do
    redact_pem "$file"
    redact_file "$file"
  done < <(find "$DIR" -type f -print0)
fi

# ---------------------------------------------------------------------------
# Bundle
# ---------------------------------------------------------------------------

echo "Compressing directory..."
if command -v zip >/dev/null 2>&1; then
  zip -r "${DIR}.zip" "$DIR" >/dev/null && echo "Bundle written to ${DIR}.zip"
else
  echo "Unable to use zip, falling back to tar.gz. We encourage installing zip if possible to allow uploading via Slack."
  tar -czf "${DIR}.tar.gz" -C "$(dirname "$DIR")" "$(basename "$DIR")" \
    && echo "Bundle written to ${DIR}.tar.gz"
fi
