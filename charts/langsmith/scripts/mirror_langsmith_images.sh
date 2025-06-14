#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image, retag it with <REGISTRY>/<original-repo>:<tag>, push.
#
# Example:
#   ./mirror_langsmith_images.sh --registry myregistry --platform linux/arm64 --version 0.10.74
#   ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#                                --platform linux/amd64 --dry-run --version 0.10.74

set -euo pipefail

#########################################################################
# Image list (only langchain/* images use the “app version” tag)
#########################################################################
BASE_VERSION="0.10.74"
IMAGES=(
  "docker.io/langchain/langsmith-ace-backend:${BASE_VERSION}"
  "docker.io/langchain/langsmith-backend:${BASE_VERSION}"
  "docker.io/langchain/langsmith-frontend:${BASE_VERSION}"
  "docker.io/langchain/hosted-langserve-backend:${BASE_VERSION}"
  "docker.io/langchain/langgraph-operator:6cc83a8"
  "docker.io/langchain/langsmith-go-backend:${BASE_VERSION}"
  "docker.io/langchain/langsmith-playground:${BASE_VERSION}"
  "docker.io/postgres:14.7"
  "docker.io/redis:7"
  "docker.io/clickhouse/clickhouse-server:24.8"
)

#########################################################################
# CLI parsing
#########################################################################
REGISTRY=""
PLATFORM="linux/amd64"
DRY_RUN=false
NEW_VERSION=""

usage() {
cat <<EOF
Usage: $0 --registry <registry-prefix> [--platform linux/arm64] [--version x.y.z] [--dry-run]

  --registry   Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
  --platform   Architecture to pull (default: linux/amd64)
  --version    Replace all '0.10.66' langchain image tags with this version
  --dry-run    Only print the docker commands
EOF
exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --registry) REGISTRY="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --version)  NEW_VERSION="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    *) usage ;;
  esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

#########################################################################
# Substitute version in the IMAGES array if requested
#########################################################################
if [[ -n $NEW_VERSION ]]; then
  for i in "${!IMAGES[@]}"; do
    IMAGES[$i]="${IMAGES[$i]//:${BASE_VERSION}/:${NEW_VERSION}}"
  done
fi

#########################################################################
# Helper: echo or execute docker commands
#########################################################################
run_cmd() {
  if $DRY_RUN; then
    printf '[DRY-RUN] %q\n' "$@"
  else
    "$@"
  fi
}

#########################################################################
# Main loop
#########################################################################
for SRC in "${IMAGES[@]}"; do
  repo_tag=${SRC#*/}               # strip docker.io/
  repo=${repo_tag%%:*}             # langchain/langsmith-backend
  tag=${repo_tag##*:}              # e.g. 0.10.74

  DEST="${REGISTRY}/${repo}:${tag}"

  echo "--- Mirroring ${SRC} → ${DEST} (${PLATFORM}) ---"
  run_cmd docker pull --platform "$PLATFORM" "$SRC"
  run_cmd docker tag "$SRC" "$DEST"
  run_cmd docker push "$DEST"
  echo
done

echo "✓ All images processed."
