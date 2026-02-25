#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image, retag it, and push to a destination registry.
#
# Ensure that you have logged into the destination registry if credentials are required.
#
# Default mode: retag as <REGISTRY>/<original-repo>:<tag>
# Marketplace mode (--dest-repo): retag as <REGISTRY>/<dest-repo>:<image-name>-<tag>
#                                  (all images in one repo, tag = image-name-version)
#
# Examples:
# ./mirror_langsmith_images.sh --registry myregistry --version 0.13.14 --platform linux/arm64
# ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#     --dest-repo langchain/langchain-repository --version 0.13.14 --platform linux/amd64 --dry-run

set -euo pipefail

# Ensure docker credential helpers are available (e.g. Docker Desktop on macOS)
DOCKER_BIN="/Applications/Docker.app/Contents/Resources/bin"
if [[ -d "$DOCKER_BIN" ]] && [[ ":$PATH:" != *":$DOCKER_BIN:"* ]]; then
    export PATH="$DOCKER_BIN:$PATH"
fi

# Default version
DEFAULT_VERSION="0.13.14"
DEFAULT_OPERATOR_VERSION="0.1.37"

###############################################################################
# CLI parsing
###############################################################################
REGISTRY=""
VERSION=""
OPERATOR_VERSION=""
PLATFORM="linux/amd64"
DRY_RUN=false
DEST_REPO=""
PUSH_CHART=false
CHART_ONLY=false
CHART_DIR=""
CHART_VERSION=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--dest-repo <repo>] [--version <version>] [--platform linux/arm64] [--push-chart] [--chart-dir <path>] [--chart-version <ver>] [--dry-run]

    --registry       Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --dest-repo      Single destination repo for marketplace mode (e.g. langchain/langchain-repository). Tags become <image-name>-<version>.
    --version        Version to use for LangSmith images (default: $DEFAULT_VERSION)
    --operator-version   Version for langgraph-operator (default: $DEFAULT_OPERATOR_VERSION)
    --platform       Architecture to pull (default: linux/amd64)
    --push-chart           Package and push the Helm chart as an OCI artifact to ECR (requires --dest-repo)
    --chart-only           Skip image mirroring, only package and push the Helm chart
    --chart-dir            Chart directory to package (default: <script-dir>/..)
    --chart-version        Chart version tag in ECR (default: same as --version)
    --dry-run              Only print the docker/helm commands
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --registry) REGISTRY="$2"; shift 2 ;;
        --dest-repo) DEST_REPO="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --operator-version) OPERATOR_VERSION="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --push-chart) PUSH_CHART=true; shift ;;
        --chart-only) PUSH_CHART=true; CHART_ONLY=true; shift ;;
        --chart-dir) CHART_DIR="$2"; shift 2 ;;
        --chart-version) CHART_VERSION="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }
if $PUSH_CHART && [[ -z $DEST_REPO ]]; then
    echo "ERROR: --push-chart requires --dest-repo"
    usage
fi

# Use provided version or default
VERSION="${VERSION:-$DEFAULT_VERSION}"
OPERATOR_VERSION="${OPERATOR_VERSION:-$DEFAULT_OPERATOR_VERSION}"
CHART_DIR="${CHART_DIR:-${SCRIPT_DIR}/..}"
CHART_VERSION="${CHART_VERSION:-${VERSION}}"

# Build images array with the specified version
IMAGES=(
    "docker.io/langchain/langsmith-ace-backend:${VERSION}"
    "docker.io/langchain/langsmith-backend:${VERSION}"
    "docker.io/langchain/langsmith-clio:${VERSION}"
    "docker.io/langchain/langsmith-frontend:${VERSION}"
    "docker.io/langchain/hosted-langserve-backend:${VERSION}"
    "docker.io/langchain/langgraph-operator:${OPERATOR_VERSION}"
    "docker.io/langchain/langsmith-go-backend:${VERSION}"
    "docker.io/langchain/langsmith-playground:${VERSION}"
    "docker.io/langchain/agent-builder-tool-server:${VERSION}"
    "docker.io/langchain/agent-builder-trigger-server:${VERSION}"
    "docker.io/langchain/agent-builder-deep-agent:${VERSION}"
    "docker.io/postgres:14.21"
    "docker.io/redis:7.4.8"
    "docker.io/clickhouse/clickhouse-server:25.12"
)

echo "Using version: ${VERSION}"
echo "Registry: ${REGISTRY}"
[[ -n $DEST_REPO ]] && echo "Dest repo: ${DEST_REPO}"
echo "Platform: ${PLATFORM}"
echo "Dry-run: ${DRY_RUN}"
$PUSH_CHART && echo "Push chart: true (chart-dir=${CHART_DIR}, chart-version=${CHART_VERSION})"
echo

###############################################################################
# Helper to echo or execute a docker command
###############################################################################
run_cmd() {
    if $DRY_RUN; then
        printf '[DRY-RUN] %q' "$1"
        shift
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

###############################################################################
# Main loop
###############################################################################
if $CHART_ONLY; then
    echo "Skipping image mirroring (--chart-only)"
    echo
fi

for SRC in "${IMAGES[@]}"; do
$CHART_ONLY && continue
    repo_tag=${SRC#*/}        # strip first path element (docker.io/…)
    tag=${repo_tag##*:}       # version tag

    if [[ -n $DEST_REPO ]]; then
        # Marketplace mode: all images → single repo, tag = <image-name>-<version>
        image_name=${repo_tag%%:*}    # e.g. langchain/langsmith-backend
        image_name=${image_name##*/}  # e.g. langsmith-backend
        DEST="${REGISTRY}/${DEST_REPO}:${image_name}-${tag}"
    else
        # Default mode: preserve original repo structure
        repo=${repo_tag%%:*}
        DEST="${REGISTRY}/${repo}:${tag}"
    fi

    echo "--- Mirroring ${SRC} → ${DEST} (${PLATFORM}) ---"
    if ! run_cmd docker pull --platform "$PLATFORM" "$SRC"; then
        echo "WARN: skipping ${SRC} (pull failed)"
        echo
        continue
    fi

    run_cmd docker tag "$SRC" "$DEST"
    if ! run_cmd docker push "$DEST"; then
        echo "WARN: skipping ${SRC} → ${DEST} (push failed, image may already exist)"
        echo
        continue
    fi
    echo
done

echo "✓ All images processed."

###############################################################################
# Helm chart packaging and push (marketplace mode only)
###############################################################################
if $PUSH_CHART; then
    echo "--- Packaging and pushing Helm chart ---"

    CHART_DIR_ABS="$(cd "${CHART_DIR}" && pwd)"
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "${TMPDIR}"' EXIT

    echo "Copying chart to temp dir: ${TMPDIR}"
    cp -r "${CHART_DIR_ABS}/." "${TMPDIR}/chart"

    echo "Patching values.yaml for marketplace registry overrides"
    python3 - <<PYEOF
import re, yaml

values_path = "${TMPDIR}/chart/values.yaml"
with open(values_path, "r") as f:
    content = f.read()

registry = "${REGISTRY}"
dest_repo = "${DEST_REPO}"

# Full ECR path: registry/dest_repo
# AWS Marketplace's scanner requires the registry domain to appear directly in the
# repository: field (not as a separate parent registry: key) so it can trace each
# rendered image back to values.yaml. We leave images.registry as "" so the chart's
# image helper uses the repository value directly: <full_repo>:<composite-tag>.
full_repo = registry + "/" + dest_repo

# 1. Patch ALL image sections: repository -> full_repo, tag -> composite <image-name>-<tag>
#    Every image rendered by the chart resolves to:
#      <full_repo>:<image-name>-<version>
#    which matches what was mirrored into the single-repo marketplace ECR.

# Parse current tag values before modifying content (yaml.safe_load ignores Helm expressions)
parsed = yaml.safe_load(content)
imgs = parsed.get("images", {})

# Map: values.yaml image key -> ECR image-name prefix used in composite tags
IMAGE_MAP = [
    ("aceBackendImage",                "langsmith-ace-backend"),
    ("backendImage",                   "langsmith-backend"),
    ("insightsAgentImage",             "langsmith-clio"),
    ("frontendImage",                  "langsmith-frontend"),
    ("hostBackendImage",               "hosted-langserve-backend"),
    ("operatorImage",                  "langgraph-operator"),
    ("platformBackendImage",           "langsmith-go-backend"),
    ("playgroundImage",                "langsmith-playground"),
    ("agentBuilderToolServerImage",    "agent-builder-tool-server"),
    ("agentBuilderTriggerServerImage", "agent-builder-trigger-server"),
    ("agentBuilderImage",              "agent-builder-deep-agent"),
    ("postgresImage",                  "postgres"),
    ("redisImage",                     "redis"),
    ("clickhouseImage",                "clickhouse-server"),
]

for img_key, img_name in IMAGE_MAP:
    if img_key not in imgs:
        print(f"WARNING: {img_key} not found in values.yaml images section, skipping")
        continue
    current_tag = str(imgs[img_key].get("tag", ""))
    composite_tag = img_name + "-" + current_tag

    # Patch repository with full ECR path (appears within 4 lines of the image key)
    repo_pat = "(" + re.escape(img_key) + r":\n(?:.*\n){0,4}?\s*repository:\s*)\"[^\"]*\""
    content = re.sub(repo_pat, r'\g<1>"' + full_repo + '"', content, count=1)

    # Patch tag (appears within 4 lines of the image key in values.yaml)
    tag_pat = "(" + re.escape(img_key) + r":\n(?:.*\n){0,4}?\s*tag:\s*)\"[^\"]*\""
    content = re.sub(tag_pat, r'\g<1>"' + composite_tag + '"', content, count=1)

    print(f"  {img_key}: {full_repo}:{composite_tag}")

# 2. Disable bundled postgres and redis so Marketplace does not scan their image references.
#    Customers connect to managed instances via override values at deploy time.
content = re.sub(
    r'(postgres:\n(?:.*\n)*?\s*external:\n(?:.*\n)*?\s*enabled:\s*)false',
    r'\g<1>true',
    content,
    count=1,
)
content = re.sub(
    r'(redis:\n(?:.*\n)*?\s*external:\n(?:.*\n)*?\s*enabled:\s*)false',
    r'\g<1>true',
    content,
    count=1,
)

# 3. Set skipValidation: true so AWS Marketplace helm template verification passes.
#    The chart's validate.yaml requires runtime values (apiKeySalt, licenseKey, etc.)
#    that aren't provided during Marketplace's helm template check.
content = re.sub(
    r'(skipValidation:\s*)false',
    r'\g<1>true',
    content,
    count=1,
)

with open(values_path, "w") as f:
    f.write(content)

print("values.yaml patched successfully")

# Rename chart to match destination repo name so helm pushes to the right ECR repo
chart_yaml_path = "${TMPDIR}/chart/Chart.yaml"
dest_repo = "${DEST_REPO}"
chart_name = dest_repo.split("/")[-1]  # e.g. langchain-repository
with open(chart_yaml_path, "r") as f:
    chart_content = f.read()
chart_content = re.sub(r'^name:.*$', 'name: ' + chart_name, chart_content, count=1, flags=re.MULTILINE)
with open(chart_yaml_path, "w") as f:
    f.write(chart_content)

print(f"Chart.yaml name set to: {chart_name}")
PYEOF

    CHART_NAME="$(basename "${DEST_REPO}")"
    CHART_PKG="${CHART_NAME}-${CHART_VERSION}.tgz"
    OCI_TARGET="oci://${REGISTRY}/$(dirname "${DEST_REPO}")"

    if $DRY_RUN; then
        echo "[DRY-RUN] helm package ${TMPDIR}/chart --version ${CHART_VERSION} --destination /tmp/"
        echo "[DRY-RUN] helm push /tmp/${CHART_PKG} ${OCI_TARGET}"
    else
        helm package "${TMPDIR}/chart" --version "${CHART_VERSION}" --destination /tmp/
        helm push "/tmp/${CHART_PKG}" "${OCI_TARGET}"
        rm -f "/tmp/${CHART_PKG}"
    fi

    echo "✓ Helm chart processed."
fi
