#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image from the chart's values.yaml, retag it, and push to a
# destination registry.
#
# By default the image list and tags are read from ../values.yaml (relative to
# this script).  Pass --version to override the tag for all LangChain images
# while keeping infrastructure image tags (postgres, redis, clickhouse) as-is.
#
# Ensure that you have logged into the destination registry if credentials are
# required.
#
# Examples:
#   ./mirror_langsmith_images.sh --registry myregistry --platform linux/arm64
#   ./mirror_langsmith_images.sh --registry myregistry --version 0.13.14 --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/../values.yaml"

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
    --version   Override tag for LangChain images (infra images keep their values.yaml tags)
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

###############################################################################
# Read images from values.yaml
###############################################################################
if [[ ! -f "$VALUES_FILE" ]]; then
    echo "ERROR: values.yaml not found at ${VALUES_FILE}"
    exit 1
fi

IMAGES=()
current_repo=""
while IFS= read -r line; do
    # Match repository lines like:  repository: "docker.io/langchain/langsmith-backend"
    if [[ $line =~ repository:[[:space:]]*\"([^\"]+)\" ]]; then
        current_repo="${BASH_REMATCH[1]}"
    # Match tag lines like:  tag: "0.13.23"
    elif [[ $line =~ tag:[[:space:]]*\"([^\"]+)\" && -n $current_repo ]]; then
        tag="${BASH_REMATCH[1]}"
        # If --version was given, override tags for langchain images only
        if [[ -n $VERSION && $current_repo == *langchain/* ]]; then
            tag="$VERSION"
        fi
        IMAGES+=("${current_repo}:${tag}")
        current_repo=""
    fi
done < "$VALUES_FILE"

if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "ERROR: no images found in ${VALUES_FILE}"
    exit 1
fi

echo "Registry:    ${REGISTRY}"
echo "Platform:    ${PLATFORM}"
[[ -n $VERSION ]] && echo "Version override: ${VERSION} (LangChain images only)"
echo "Dry-run:     ${DRY_RUN}"
echo "Images (${#IMAGES[@]}):"
printf '  %s\n' "${IMAGES[@]}"
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
    repo=${repo_tag%%:*}
    tag=${repo_tag##*:}
    DEST="${REGISTRY}/${repo}:${tag}"

    echo "--- Mirroring ${SRC} -> ${DEST} (${PLATFORM}) ---"
    run_cmd docker pull --platform "$PLATFORM" "$SRC"
    run_cmd docker tag "$SRC" "$DEST"
    run_cmd docker push "$DEST"
    echo
done

echo "All images processed."
