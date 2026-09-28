#!/bin/bash

# Diagnostic collection for self-hosted LangSmith/LangGraph clusters.
#
# Usage: $0 --namespace <namespace> [--redact] [--redact-strict] [--exclude-logs] [--exclude-describe] [--pod-selector <label-selector>]
#
# Default: collects everything — kubectl describe, events, resources, pod
# metrics, and pod logs (last 24h + previous on restart).
#
# --redact           : balanced best-effort redaction (secrets, credentials, auth
#                      material, emails/SSN/cards, LLM trace payloads). Timestamps,
#                      log messages, UUIDs, IPs and resource hashes are PRESERVED so
#                      the bundle stays diagnosable. REVIEW THE BUNDLE BEFORE SHARING —
#                      regex cannot catch unstructured PHI such as patient names or
#                      medical narratives inside log messages.
# --redact-strict    : implies --redact and adds the identifier sweep (UUIDs, IPv4/IPv6,
#                      MACs, ZIP codes, bare dates, bare 13-19 digit runs, 40-char
#                      hashes, ICD-10 codes). For PHI-sensitive environments. Expect a
#                      much harder-to-read bundle.
# --exclude-logs     : skip pod log collection.
# --exclude-describe : skip kubectl describe collection.
# --pod-selector     : restrict describe/log collection to pods matching this
#                      Kubernetes label selector (e.g. "app.kubernetes.io/component=fleet-queue").
#                      Namespace-wide resources (summary, events, top pods, helm values)
#                      are still collected in full. Omit for the default whole-namespace behavior.

REDACT=0
REDACT_STRICT=0
COLLECT_LOGS=1
COLLECT_DESCRIBE=1
POD_SELECTOR=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --namespace)       NS="$2"; shift ;;
    --redact)          REDACT=1 ;;
    --redact-strict)   REDACT=1; REDACT_STRICT=1 ;;
    --exclude-logs)    COLLECT_LOGS=0 ;;
    --exclude-describe) COLLECT_DESCRIBE=0 ;;
    --pod-selector)    POD_SELECTOR="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$NS" ]]; then
  echo "Usage: $0 --namespace <namespace> [--redact] [--redact-strict] [--exclude-logs] [--exclude-describe] [--pod-selector <label-selector>]"
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
#
# Two tiers:
#   --redact         Balanced (default). Secrets, credentials, auth material
#                    and LLM trace payloads are scrubbed. Timestamps, log
#                    messages, UUIDs, IPs and resource hashes are PRESERVED so
#                    the bundle is still diagnosable.
#   --redact-strict  Adds the identifier sweep: UUIDs, IPv4/IPv6, MACs, ZIP
#                    codes, bare dates, bare 13-19 digit runs, 40-char hashes
#                    and ICD-10 codes. Use for PHI-sensitive environments and
#                    expect the bundle to be much harder to read.
#
# Timestamps are protected in BOTH tiers: ISO-8601 and HH:MM:SS values are
# encoded to sentinel bytes before any rule runs and restored at the end, so
# the date / IPv6 / ZIP rules can no longer shred them.

TS_D=$'\001'   # stands in for "-" inside a protected timestamp
TS_C=$'\002'   # stands in for ":" inside a protected timestamp
MARK=$'\003'   # marks "this line is inside an LLM payload region" (mark_payload_lines)
KEEP=$'\004'   # shields a keep-list key from the payload value-blanking rule

# Benign envelope / telemetry / structural fields kept VISIBLE even inside a
# payload region (timestamps, log level, HTTP status, latency, model params,
# message role/type). Otherwise the generic value-blank below would erase a
# payload record's own timestamp and log metadata.
# "path" and "route" are deliberately NOT kept: inside a payload they can carry
# a filename or URL holding a name or record number.
KEEP_KEYS='ts|timestamp|time|level|severity|event|logger|caller|status|status_code|method|http_method|duration_ms|latency_ms|elapsed_ms|model|temperature|max_tokens|top_p|finish_reason|index|role|type'

# Keys whose presence means "this JSON record is an LLM payload". Used by the
# marking pre-pass, not by sed directly.
PAYLOAD_KEYS='messages|role|chat_history|generations|llm_output|tool_calls|function_call|kwargs'

# Key class for the generic value-blanking rules. Excludes only the double
# quote and the keep-list sentinel, so keys containing spaces or punctuation
# ("user name") are still covered, while a key already shielded by the
# keep-list rule (prefixed with KEEP) can no longer match. Do not widen this
# to include KEEP or the shield stops working.
KEY="[^\"${KEEP}]+"

# Applied FIRST: hide timestamps from every rule that follows.
SED_PROTECT=(
  # 2026-09-02T18:34:12 and 2026-09-02 18:34:12
  -e "s/([12][0-9]{3})-([0-1][0-9])-([0-3][0-9])([T ])([0-2][0-9]):([0-5][0-9]):([0-5][0-9])/\1${TS_D}\2${TS_D}\3\4\5${TS_C}\6${TS_C}\7/g"
  # bare HH:MM:SS (ClickHouse, kubectl, syslog-style prefixes)
  -e "s/(^|[^0-9:])([0-2][0-9]):([0-5][0-9]):([0-5][0-9])/\1\2${TS_C}\3${TS_C}\4/g"
)

# Applied LAST: put the timestamps back and drop the marker / keep-list bytes.
SED_RESTORE=(
  -e "s/${TS_D}/-/g"
  -e "s/${TS_C}/:/g"
  -e "s/${MARK}//g"
  -e "s/${KEEP}//g"
)

# Balanced tier. Order matters: auth headers / URIs first so URI-embedded
# Bearer tokens don't slip through later rules.
SED_BASE=(
  # Auth headers / URIs
  -e 's/([Bb]earer )[A-Za-z0-9._~+/=-]+/\1***REDACTED***/g'
  -e 's/([Aa]uthorization: *)[^[:space:]"'"'"']+/\1***REDACTED***/g'
  -e 's#([A-Za-z][A-Za-z0-9+.-]*://[^:/?#[:space:]]+):[^@[:space:]]+@#\1:***REDACTED***@#g'
  # Env-var / kv / JSON sensitive assignments
  -e 's/((PASSWORD|PASSWD|TOKEN|SECRET|API[_-]?KEY|APIKEY|ACCESS[_-]?KEY|PRIVATE[_-]?KEY|CREDENTIAL|AUTH)[A-Z0-9_-]*[[:space:]]*=[[:space:]]*)[^[:space:]"'"'"']+/\1***REDACTED***/gi'
  -e 's/("(password|passwd|token|secret|api[_-]?key|apikey|access[_-]?key|private[_-]?key|credential|auth)[A-Za-z0-9_-]*"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # JWK/JOSE private key material (RFC 7518 short field names — "d", and the
  # RSA CRT components — don't match the key-name patterns above). Scoped to
  # lines that also contain "kty" so a JWK's own key set isn't confused with
  # unrelated short field names elsewhere in the bundle.
  -e '/"kty"/ s/("(d|p|q|dp|dq|qi)"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Sensitive HTTP headers
  -e 's/("(x-service-key|x-api-key|x-auth-token|x-access-token|x-authorization|x-csrf-token|cookie|set-cookie)"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Tenant / user / customer / patient identifiers in headers
  -e 's/("(x-(tenant|user|organization|org|account|customer|patient|member|agent|thread|session|ls-user)[-_]id)"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # Envoy peer metadata blobs
  -e 's/("x-envoy-peer-metadata(-id)?"[[:space:]]*:[[:space:]]*")[^"]+/\1***REDACTED***/gi'
  # AWS account IDs inside ARNs
  -e 's/(arn:aws[A-Za-z0-9-]*:[a-z0-9-]*:[a-z0-9-]*:)[0-9]{12}:/\1***REDACTED-AWS-ACCT***:/g'

  # --- LLM trace payloads -------------------------------------------------
  # Unambiguous payload fields: always scrubbed, even without surrounding
  # context. The key is preserved and the value becomes ***REDACTED-<field>***
  # (\2 is the captured field name) so the payload shape stays visible.
  -e 's/("(inputs|outputs|input|output|prompt|completion|messages|run_inputs|run_outputs|trace_input|trace_output|input_text|output_text|tool_input|tool_output|tool_calls|function_call|chat_history|generations|llm_output|action_input|final_answer|observation)"[[:space:]]*:[[:space:]]*")(\\.|[^"\\])*"/\1***REDACTED-\2***"/g'
  # Keep-list: on payload lines, break the key match for benign envelope /
  # telemetry / structural fields with a sentinel byte so the value-blank below
  # skips them (their timestamps, log level, status, latency, model params and
  # role stay visible). SED_RESTORE strips the sentinel at the end.
  -e "/^${MARK}/ s/\"(${KEEP_KEYS})\"([[:space:]]*:)/\"${KEEP}\1\"\2/g"
  # Inside a payload region (flagged by mark_payload_lines with a leading
  # sentinel byte), keep every key but blank every string value. This preserves
  # the full nested skeleton — you can see the shape of the payload without any
  # values — and cannot leak unlisted inner fields. Scoped to marked lines so
  # ordinary log messages are untouched. This is the rule that used to blank
  # whole log lines. Add fields to KEEP_KEYS above to keep them visible.
  -e "/^${MARK}/ s/(\"(${KEY})\"[[:space:]]*:[[:space:]]*\")(\\\\.|[^\"\\\\])*\"/\1***REDACTED-\2***\"/g"
  # Same, for non-string values. Numeric PHI ("patient_mrn":99887766) and
  # booleans/nulls would otherwise survive inside a payload. Anchored on the
  # trailing delimiter so it cannot match a prefix of a longer token.
  -e "/^${MARK}/ s/(\"(${KEY})\"[[:space:]]*:[[:space:]]*)(-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?|true|false|null)([[:space:]]*[]},]|[[:space:]]*\$)/\1\"***REDACTED-\2***\"\6/g"
  # Object / array fallback for compact single-line dumps whose inner elements
  # aren't key:value pairs (the generic rule above can't reach bare array items).
  -e 's/("(inputs|outputs|input|output|messages|metadata|extra|tags|args|arguments|tool_calls|function_call|chat_history|generations|llm_output)"[[:space:]]*:[[:space:]]*)\{[^{}]*\}/\1{"r":"***REDACTED-\2***"}/g'
  -e 's/("(inputs|outputs|messages|tags|tool_calls|chat_history|args|generations)"[[:space:]]*:[[:space:]]*)\[[^][]*\]/\1["***REDACTED-\2***"]/g'

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
  # Very long hex blobs (SHA-256/512, generic tokens). The 40-char threshold
  # lives in the strict tier so 40-char git SHAs stay readable here.
  -e 's/[a-fA-F0-9]{64,}/***REDACTED-HEX***/g'
  # Personal identifiers
  -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/***REDACTED-EMAIL***/g'
  -e 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/***REDACTED-SSN***/g'
  # Anchored on non-alnum/non-hyphen so it can't chew the middle of a UUID.
  -e 's/(^|[^0-9A-Za-z-])[0-9]{4}[ -][0-9]{4}[ -][0-9]{4}[ -][0-9]{4}([^0-9A-Za-z-]|$)/\1***REDACTED-CC***\2/g'
  -e 's/\+[1-9][0-9]{7,14}/***REDACTED-PHONE***/g'
  -e 's/\(?[0-9]{3}\)?[ .-][0-9]{3}[ .-][0-9]{4}/***REDACTED-PHONE***/g'
)

# Strict tier. Broad identifier sweep — high false-positive rate by design.
SED_STRICT=(
  # 40-char hashes (git SHAs, generic tokens)
  -e 's/[a-fA-F0-9]{40,}/***REDACTED-HEX***/g'
  # Bare long digit runs (unformatted card / account numbers)
  -e 's/[0-9]{13,19}/***REDACTED-DIGITS***/g'
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
  # Bare dates (DOB candidates). Dates that are part of a timestamp are
  # protected above and survive.
  -e 's/[12][0-9]{3}-[0-1][0-9]-[0-3][0-9]/***REDACTED-DATE***/g'
  -e 's/[0-1]?[0-9][/-][0-3]?[0-9][/-][12][0-9]{3}/***REDACTED-DATE***/g'
  # ICD-10 diagnosis codes
  -e 's/(^|[^A-Z0-9])[A-TV-Z][0-9]{2}(\.[A-Z0-9]{1,4})?([^A-Z0-9]|$)/\1***REDACTED-ICD10***\3/g'
)

SED_ARGS=("${SED_PROTECT[@]}" "${SED_BASE[@]}")
if [[ "$REDACT_STRICT" -eq 1 ]]; then
  SED_ARGS+=("${SED_STRICT[@]}")
fi
SED_ARGS+=("${SED_RESTORE[@]}")

# Payload marking (awk program, run inside the redact_file pipeline).
#
# Line-oriented sed cannot see cross-line context, so pretty-printed JSON puts
# "role" and "content" on separate lines. This pass prefixes MARK onto every
# line that belongs to an LLM payload, and the generic value-blanking rules key
# off that prefix.
#
# Two regimes, which is what keeps it both complete and quiet:
#   * Pretty-printed record (opened by a lone brace/bracket at column 0): the
#     whole record is buffered, and if a payload key appears ANYWHERE in it,
#     every line of the record is marked. No length cap, and sibling fields are
#     covered even when they precede the payload key.
#   * Anything else (compact one-line JSON, or plain-text log lines): only the
#     individual line containing a payload key is marked. A payload key
#     mentioned in a plain-text log line therefore cannot bleed into the lines
#     that follow it.
# Fails closed: an unterminated record at EOF, or one past CAP lines, is
# treated as a payload.
AWK_MARK=$(cat <<'AWKEOF'
BEGIN { n = 0; hit = 0; inrec = 0; forced = 0; CAP = 50000 }
function flush() {
  for (i = 1; i <= n; i++) print (hit ? M buf[i] : buf[i])
  n = 0; hit = 0
}
{
  if (forced) {
    print M $0
    if ($0 ~ /^[}\]][ \t]*,?[ \t]*$/) { forced = 0; inrec = 0 }
    next
  }
  if (!inrec && $0 ~ /^[{[][ \t]*$/) { inrec = 1; n = 1; buf[1] = $0; next }
  if (inrec) {
    buf[++n] = $0
    if ($0 ~ PAYLOAD) hit = 1
    if ($0 ~ /^[}\]][ \t]*,?[ \t]*$/) { inrec = 0; flush(); next }
    if (n >= CAP) { hit = 1; flush(); forced = 1 }
    next
  }
  print ($0 ~ PAYLOAD) ? M $0 : $0
}
END { if (n > 0) { hit = 1; flush() } }
AWKEOF
)

# PEM private-key stripping (awk program, same pipeline).
AWK_PEM=$(cat <<'AWKEOF'
{
  if ($0 ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) { in_key=1; print "***REDACTED-PRIVATE-KEY***"; next }
  if (in_key) {
    if ($0 ~ /-----END [A-Z ]*PRIVATE KEY-----/) in_key=0
    next
  }
  print
}
AWKEOF
)

# Single pass per file: strip PEM blocks, mark payload regions, then redact.
# All three run concurrently in one pipeline into one temp file, and the
# original is replaced only if every stage succeeds -- so a failure can never
# leave a file half-processed or carrying raw sentinel bytes.
redact_file() {
  local f="$1"
  [[ ! -f "$f" ]] && return
  local tmp
  local -a st
  tmp="$(mktemp)" || return
  awk "$AWK_PEM" "$f" \
    | awk -v M="$MARK" -v PAYLOAD="\"($PAYLOAD_KEYS)\"[[:space:]]*:" "$AWK_MARK" \
    | sed -E "${SED_ARGS[@]}" > "$tmp"
  st=("${PIPESTATUS[@]}")
  if [[ "${st[0]}" -eq 0 && "${st[1]}" -eq 0 && "${st[2]}" -eq 0 ]]; then
    mv "$tmp" "$f"
  else
    echo "  WARNING: redaction failed for $f (left unmodified, exit ${st[*]})" >&2
    rm -f "$tmp"
  fi
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
  if [[ -t 0 ]]; then
    read -r -p "Continue without redaction? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "Aborted. Re-run with --redact to enable best-effort scrubbing."
      exit 1
    fi
  fi
fi

if [[ "$REDACT" -eq 1 ]]; then
  cat >&2 <<'EOF'
==============================================================================
--redact is ENABLED (balanced). Best-effort scrub across the entire bundle for:
  secrets   : API keys (OpenAI, Anthropic, Stripe, Slack, AWS, GCP, GitHub,
              GitLab, Twilio, LangSmith), JWTs, Bearer/Authorization headers,
              passwords in URIs, env/JSON values for *KEY|SECRET|TOKEN|
              PASSWORD|CREDENTIAL, PEM private-key blocks, 64+ char hex blobs.
  identifiers: emails, phones, SSNs, formatted card numbers,
              tenant/user/org/customer/patient/agent/thread IDs in headers,
              AWS account IDs in ARNs.
  trace data: inputs, outputs, prompts, completions, tool calls, chat history,
              generations. Inside a detected LLM payload (incl. pretty-printed
              multi-line JSON, any length) every value is blanked -- strings,
              numbers, booleans -- while the keys are preserved, so the payload
              shape stays visible for diagnosis. Envelope fields (timestamp,
              level, status, latency, model params, role) stay readable.

  PRESERVED so the bundle stays diagnosable: timestamps, log messages, UUIDs
  (run/tenant/deployment IDs), cluster IPs, ports, k8s resource hashes, SQL,
  git SHAs. If your environment is PHI-sensitive, use --redact-strict instead.
  Neither tier catches unstructured PHI such as patient names, street
  addresses, or medical narratives inside log messages.
  REVIEW THE BUNDLE BEFORE SHARING.
==============================================================================
EOF
fi

if [[ "$REDACT_STRICT" -eq 1 ]]; then
  cat >&2 <<'EOF'
==============================================================================
--redact-strict is ENABLED. In addition to the balanced tier, this sweeps:
  UUIDs, IPv4/IPv6, MAC addresses, ZIP codes, bare dates (DOB-shaped),
  bare 13-19 digit runs, 40+ char hex hashes, ICD-10 codes.

  Timestamps are still preserved, but expect cluster IPs, run IDs, ports and
  k8s resource hashes to be mangled — the bundle will be much harder to read.
==============================================================================
EOF
fi

# ---------------------------------------------------------------------------
# Collection
# ---------------------------------------------------------------------------

DIR="$(mktemp -d -t langsmith-debugging.XXXXXX)"

echo "Starting to pull debugging info. Creating directory $DIR..."

echo "Pulling summary of resources..."
kubectl get all -n "$NS" -o wide > "$DIR/resources_summary.txt"

echo "Pulling details of all resources..."
kubectl get all -n "$NS" -o yaml > "$DIR/resources_details.yaml"

echo "Pulling kubernetes events..."
kubectl get events -n "$NS" --sort-by=.lastTimestamp > "$DIR/events.txt"

echo "Pulling resource usage for all pods..."
kubectl top pods -n "$NS" --containers > "$DIR/pod-resource-usage.txt"

if [[ -n "$POD_SELECTOR" ]]; then
  echo "Restricting describe/log collection to pods matching selector: $POD_SELECTOR"
  PODS=$(kubectl get pods -n "$NS" -l "$POD_SELECTOR" -o jsonpath='{.items[*].metadata.name}')
  if [[ -z "$PODS" ]]; then
    echo "Warning: no pods matched --pod-selector '$POD_SELECTOR' in namespace $NS." >&2
  fi
else
  PODS=$(kubectl get pods -n "$NS" -o jsonpath='{.items[*].metadata.name}')
fi

if [[ "$COLLECT_DESCRIBE" -eq 1 ]]; then
  echo "Pulling describe output for matching pods..."
  mkdir -p "$DIR/describe"
  for POD in $PODS; do
    echo "  Describing pod $POD..."
    kubectl describe pod "$POD" -n "$NS" > "$DIR/describe/${POD}_describe.txt" 2>/dev/null
  done
else
  echo "Skipping describe (--exclude-describe set)."
fi

if [[ "$COLLECT_LOGS" -eq 1 ]]; then
  echo "Pulling container logs for matching pods (last 24h + previous on restart)..."
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
