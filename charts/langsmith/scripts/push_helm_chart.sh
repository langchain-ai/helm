#!/usr/bin/env bash
# push_helm_chart.sh
# Repackage the LangSmith Helm chart with a marketplace-compatible name and push to ECR.
#
# Ensure that you have logged into the destination registry if credentials are required.
# For marketplace ECR:
#   aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin <registry>
#
# Examples:
# ./push_helm_chart.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com
# ./push_helm_chart.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com --version 0.3.10 --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/.."

# Defaults
DEFAULT_VERSION="0.3.10"
DEFAULT_CHART_NAME="langchain-repository"
DEFAULT_NAMESPACE="langchain"

###############################################################################
# CLI parsing
###############################################################################
REGISTRY=""
VERSION=""
CHART_NAME=""
NAMESPACE=""
CHART_PATH=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 --registry <registry> [--version <version>] [--chart-name <name>] [--namespace <ns>] [--chart <path>] [--dry-run]

    --registry    Mandatory. Destination registry (e.g. 709825985650.dkr.ecr.us-east-1.amazonaws.com)
    --version     Chart version (default: $DEFAULT_VERSION)
    --chart-name  Name to use in Chart.yaml for the marketplace repo (default: $DEFAULT_CHART_NAME)
    --namespace   OCI namespace to push under (default: $DEFAULT_NAMESPACE)
    --chart       Path to chart directory or .tgz (default: $CHART_DIR)
    --dry-run     Only print the commands
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --registry) REGISTRY="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --chart-name) CHART_NAME="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --chart) CHART_PATH="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

VERSION="${VERSION:-$DEFAULT_VERSION}"
CHART_NAME="${CHART_NAME:-$DEFAULT_CHART_NAME}"
NAMESPACE="${NAMESPACE:-$DEFAULT_NAMESPACE}"
CHART_PATH="${CHART_PATH:-$CHART_DIR}"

echo "Registry:   ${REGISTRY}"
echo "Version:    ${VERSION}"
echo "Chart name: ${CHART_NAME}"
echo "Namespace:  ${NAMESPACE}"
echo "Chart path: ${CHART_PATH}"
echo "Dry-run:    ${DRY_RUN}"
echo

###############################################################################
# Create temp workspace
###############################################################################
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

###############################################################################
# Extract or copy chart
###############################################################################
if [[ "$CHART_PATH" == *.tgz ]]; then
    echo "--- Extracting chart from ${CHART_PATH} ---"
    tar -xzf "$CHART_PATH" -C "$TMPDIR"
else
    echo "--- Packaging chart from ${CHART_PATH} ---"
    helm package "$CHART_PATH" --version "$VERSION" -d "$TMPDIR" > /dev/null
    TGZ=$(ls "$TMPDIR"/*.tgz)
    tar -xzf "$TGZ" -C "$TMPDIR"
    rm "$TGZ"
fi

# Find the extracted chart directory
EXTRACTED_DIR=$(find "$TMPDIR" -maxdepth 1 -mindepth 1 -type d | head -1)
ORIGINAL_NAME=$(basename "$EXTRACTED_DIR")

###############################################################################
# Rename chart if needed
###############################################################################
if [[ "$ORIGINAL_NAME" != "$CHART_NAME" ]]; then
    echo "--- Renaming chart: ${ORIGINAL_NAME} → ${CHART_NAME} ---"
    sed -i.bak "s/^name: .*/name: ${CHART_NAME}/" "$EXTRACTED_DIR/Chart.yaml"
    rm -f "$EXTRACTED_DIR/Chart.yaml.bak"
    mv "$EXTRACTED_DIR" "$TMPDIR/$CHART_NAME"
    EXTRACTED_DIR="$TMPDIR/$CHART_NAME"
fi

###############################################################################
# Apply marketplace overrides
###############################################################################
echo "--- Setting marketplace overrides in values.yaml ---"
sed -i.bak \
    -e 's/^  skipValidation: false/  skipValidation: true/' \
    -e 's/^nameOverride: ""/nameOverride: "langsmith"/' \
    "$EXTRACTED_DIR/values.yaml"
rm -f "$EXTRACTED_DIR/values.yaml.bak"

echo "--- Rewriting image references to marketplace ECR ---"
MARKETPLACE_REPO="${REGISTRY}/${NAMESPACE}/${CHART_NAME}"
python3 - "$EXTRACTED_DIR/values.yaml" "$MARKETPLACE_REPO" <<'PYEOF'
import sys, re

values_path = sys.argv[1]
marketplace_repo = sys.argv[2]

with open(values_path, 'r') as f:
    content = f.read()

# Map docker.io image paths to marketplace tag prefixes
# e.g. "docker.io/langchain/langsmith-backend" -> repository becomes marketplace_repo,
#      tag becomes "langsmith-backend-<version>"
image_map = {
    'docker.io/langchain/langsmith-ace-backend': 'langsmith-ace-backend',
    'docker.io/langchain/langsmith-backend': 'langsmith-backend',
    'docker.io/langchain/langsmith-clio': 'langsmith-clio',
    'docker.io/langchain/langsmith-frontend': 'langsmith-frontend',
    'docker.io/langchain/hosted-langserve-backend': 'hosted-langserve-backend',
    'docker.io/langchain/langgraph-operator': 'langgraph-operator',
    'docker.io/langchain/langsmith-go-backend': 'langsmith-go-backend',
    'docker.io/langchain/langsmith-playground': 'langsmith-playground',
    'docker.io/postgres': 'postgres',
    'docker.io/redis': 'redis',
    'docker.io/clickhouse/clickhouse-server': 'clickhouse-server',
    'docker.io/langchain/agent-builder-tool-server': 'agent-builder-tool-server',
    'docker.io/langchain/agent-builder-trigger-server': 'agent-builder-trigger-server',
    'docker.io/langchain/agent-builder-deep-agent': 'agent-builder-deep-agent',
}

lines = content.split('\n')
result = []
i = 0
while i < len(lines):
    line = lines[i]
    matched = False
    for docker_ref, tag_prefix in image_map.items():
        if f'repository: "{docker_ref}"' in line:
            # Replace repository
            result.append(line.replace(f'"{docker_ref}"', f'"{marketplace_repo}"'))
            # Find the tag line (within next few lines)
            i += 1
            while i < len(lines):
                tag_line = lines[i]
                tag_match = re.match(r'^(\s+tag:\s*)"(.+)"', tag_line)
                if tag_match:
                    indent = tag_match.group(1)
                    old_tag = tag_match.group(2)
                    new_tag = f'{tag_prefix}-{old_tag}'
                    result.append(f'{indent}"{new_tag}"')
                    matched = True
                    break
                else:
                    result.append(tag_line)
                i += 1
            break
    if not matched:
        result.append(line)
    i += 1

with open(values_path, 'w') as f:
    f.write('\n'.join(result))

print(f"  Rewrote image references to {marketplace_repo}")
PYEOF

###############################################################################
# Package and push
###############################################################################
echo "--- Packaging ${CHART_NAME} ---"
helm package "$EXTRACTED_DIR" -d "$TMPDIR" > /dev/null
CHART_TGZ="$TMPDIR/${CHART_NAME}-${VERSION}.tgz"

OCI_URL="oci://${REGISTRY}/${NAMESPACE}"

if $DRY_RUN; then
    echo "[DRY-RUN] helm push ${CHART_TGZ} ${OCI_URL}"
else
    echo "--- Pushing ${CHART_NAME}:${VERSION} → ${OCI_URL} ---"
    helm push "$CHART_TGZ" "$OCI_URL"
fi

echo
echo "✓ Helm chart pushed."
