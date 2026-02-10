#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image, retag it, and push to a destination registry.
#
# Ensure that you have logged into the destination registry if credentials are required.
#
# Default mode: retag as <REGISTRY>/<original-repo>:<tag>
# Marketplace mode (--dest-repo): retag as <REGISTRY>/<dest-repo>:<image-name>-<tag>
#
# Examples:
# ./mirror_langsmith_images.sh --registry myregistry --version 0.10.66 --platform linux/arm64
# ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#     --dest-repo langchain/langchain-repository --version 0.10.67 --platform linux/amd64 --dry-run

set -euo pipefail

# Default version
DEFAULT_VERSION="0.13.9"
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

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--dest-repo <repo>] [--version <version>] [--platform linux/arm64] [--dry-run]

    --registry  Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --dest-repo Single destination repo (e.g. langchain/langchain_repository). Tags become <image-name>-<version>.
    --version            Version to use for LangSmith images (default: $DEFAULT_VERSION)
    --operator-version   Version for langgraph-operator (default: $DEFAULT_OPERATOR_VERSION)
    --platform           Architecture to pull (default: linux/amd64)
    --dry-run            Only print the docker commands
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
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

# Use provided version or default
VERSION="${VERSION:-$DEFAULT_VERSION}"
OPERATOR_VERSION="${OPERATOR_VERSION:-$DEFAULT_OPERATOR_VERSION}"

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
    "docker.io/postgres:15.15"
    "docker.io/redis:8"
    "docker.io/clickhouse/clickhouse-server:25.12"
)

echo "Using version: ${VERSION}"
echo "Registry: ${REGISTRY}"
[[ -n $DEST_REPO ]] && echo "Dest repo: ${DEST_REPO}"
echo "Platform: ${PLATFORM}"
echo "Dry-run: ${DRY_RUN}"
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
for SRC in "${IMAGES[@]}"; do
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
    run_cmd docker pull --platform "$PLATFORM" "$SRC"
    run_cmd docker tag "$SRC" "$DEST"
    run_cmd docker push "$DEST"
    echo
done

echo "✓ All images processed."
