#!/usr/bin/env bash
# Fails when charts/langsmith and charts/langsmith-sandbox would ship different
# LangSmith releases: their appVersions differ, the runtime chart pins its image
# tag, or the langsmith chart's sandbox-host tag is not its appVersion.
# Usage: check-sandbox-chart-pairing.sh [repository root]
set -euo pipefail

root="${1:-.}"
main_chart="$root/charts/langsmith"
runtime_chart="$root/charts/langsmith-sandbox"

if [[ ! -f "$runtime_chart/Chart.yaml" ]]; then
  echo "No langsmith-sandbox chart; nothing to check."
  exit 0
fi

app_version() {
  sed -n -E 's/^appVersion:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/p' "$1/Chart.yaml"
}

# Prints the value of the first `tag:` inside the two-space-indented block `key:`
# of a chart's values.yaml (for example images.sandboxHost), without quotes.
image_tag() {
  awk -v key="  $2:" '
    $0 == key { found = 1; next }
    found && /^  [^ #]/ { exit }
    found && /^    tag:/ { sub(/^    tag:[[:space:]]*/, ""); gsub(/"/, ""); print; exit }
  ' "$1/values.yaml"
}

main_app="$(app_version "$main_chart")"
runtime_app="$(app_version "$runtime_chart")"
runtime_tag="$(image_tag "$runtime_chart" sandboxHost)"
main_tag="$(image_tag "$main_chart" sandboxHostImage)"
status=0

if [[ -z "$main_app" || "$main_app" != "$runtime_app" ]]; then
  echo "::error::appVersion mismatch: charts/langsmith has '$main_app', charts/langsmith-sandbox has '$runtime_app'. Both charts must ship the same LangSmith release."
  status=1
fi
if [[ -n "$runtime_tag" ]]; then
  echo "::error::charts/langsmith-sandbox images.sandboxHost.tag must be empty so the image follows the chart appVersion (found '$runtime_tag')."
  status=1
fi
if [[ "$main_tag" != "$main_app" ]]; then
  echo "::error::charts/langsmith images.sandboxHostImage.tag ('$main_tag') must equal the chart appVersion ('$main_app')."
  status=1
fi
if [[ "$status" -eq 0 ]]; then
  echo "langsmith and langsmith-sandbox both ship $main_app."
fi
exit "$status"
