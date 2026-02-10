#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image, retag it with <REGISTRY>/<original-repo>:<tag>, push.
#
# Ensure that you have logged into the source destination registry if credentials are required.
# Example:
# ./mirror_langsmith_images.sh --registry myregistry --version 0.10.66 --platform linux/arm64
# ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#     --version 0.10.67 --platform linux/amd64 --dry-run

set -euo pipefail

# Default version
DEFAULT_VERSION="0.13.3"

###############################################################################
# CLI parsing
###############################################################################
REGISTRY=""
VERSION=""
PLATFORM="linux/amd64"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--version <version>] [--platform linux/arm64] [--dry-run]

    --registry  Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --version   Version to use for LangSmith images (default: $DEFAULT_VERSION)
    --platform  Architecture to pull (default: linux/amd64)
    --dry-run   Only print the docker commands
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --registry) REGISTRY="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

# Use provided version or default
VERSION="${VERSION:-$DEFAULT_VERSION}"

# Build images array with the specified version
IMAGES=(
    "docker.io/langchain/langsmith-ace-backend:${VERSION}"
    "docker.io/langchain/langsmith-backend:${VERSION}"
    "docker.io/langchain/langsmith-frontend:${VERSION}"
    "docker.io/langchain/hosted-langserve-backend:${VERSION}"
    "docker.io/langchain/langgraph-operator:6cc83a8"
    "docker.io/langchain/langsmith-go-backend:${VERSION}"
    "docker.io/langchain/langsmith-playground:${VERSION}"
    "docker.io/postgres:14.7"
    "docker.io/redis:7"
    "docker.io/clickhouse/clickhouse-server:25.12"
)

echo "Using version: ${VERSION}"
echo "Registry: ${REGISTRY}"
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
    repo=${repo_tag%%:*}      # langchain/langsmith-backend
    tag=${repo_tag##*:}       # version tag

    DEST="${REGISTRY}/${repo}:${tag}"  # final ref

    echo "--- Mirroring ${SRC} → ${DEST} (${PLATFORM}) ---"
    run_cmd docker pull --platform "$PLATFORM" "$SRC"
    run_cmd docker tag "$SRC" "$DEST"
    run_cmd docker push "$DEST"
    echo
done

echo "✓ All images processed."
