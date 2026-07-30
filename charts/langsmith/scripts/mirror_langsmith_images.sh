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
# ./mirror_langsmith_images.sh --registry myregistry --version 0.15.18 --platform linux/amd64
# Target a release candidate instead of the GA default:
# ./mirror_langsmith_images.sh --registry myregistry --version 0.16.13rc1 --operator-version 0.1.47 --platform linux/amd64
# ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#     --dest-repo langchain/langchain-repository --version 0.15.18 --platform linux/amd64 --dry-run

set -euo pipefail

###############################################################################
# Versions
###############################################################################
# LangSmith application images + operator. Bump these when targeting a new release.
DEFAULT_VERSION="0.15.18"             # latest GA appVersion -> all langchain/* application images (override with --version, e.g. an RC)
DEFAULT_OPERATOR_VERSION="0.1.47"     # langgraph-operator image tag (same in current GA and RC)

# In-cluster dependency image tags. These are pinned by the chart (charts/langsmith/values.yaml)
# and are NOT tied to --version. Re-verify them against values.yaml whenever you bump the chart:
#   postgresImage.tag, redisImage.tag, clickhouseImage.tag, and the operator.templates pgvector tag.
PG_TAG="14.7"
REDIS_TAG="7"
CLICKHOUSE_TAG="25.12"
PGVECTOR_TAG="pg15"

# Optional components (off by default; enable with --with-presidio / --with-smithdb).
PRESIDIO_TAG="2.2.354"                # mcr.microsoft.com/presidio-analyzer (PII redaction)
SMITHDB_TAG="latest"                  # langchain/smithdb (0.16+ only, absent in GA; floating tag -> pin a digest for air-gap)

###############################################################################
# CLI parsing
###############################################################################
REGISTRY=""
VERSION=""
OPERATOR_VERSION=""
PLATFORM="linux/amd64"
DRY_RUN=false
DEST_REPO=""
WITH_PRESIDIO=false
WITH_SMITHDB=false

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--dest-repo <repo>] [--version <version>]
          [--operator-version <version>] [--platform linux/arm64]
          [--with-presidio] [--with-smithdb] [--dry-run]

    --registry           Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --dest-repo          Single destination repo (e.g. langchain/langchain_repository). Tags become <image-name>-<version>.
    --version            Version for LangSmith application images (default: $DEFAULT_VERSION)
    --operator-version   Version for langgraph-operator (default: $DEFAULT_OPERATOR_VERSION)
    --platform           Architecture to pull (default: linux/amd64)
    --with-presidio      Also mirror mcr.microsoft.com/presidio-analyzer:$PRESIDIO_TAG (PII redaction add-on)
    --with-smithdb       Also mirror docker.io/langchain/smithdb:$SMITHDB_TAG (0.16+ only)
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
        --with-presidio) WITH_PRESIDIO=true; shift ;;
        --with-smithdb) WITH_SMITHDB=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

# Warn if falling back to the built-in default versions instead of an explicit --version.
[[ -z $VERSION ]] && echo "WARNING: --version not provided; using default ${DEFAULT_VERSION}. Pass --version to target a specific release." >&2
[[ -z $OPERATOR_VERSION ]] && echo "WARNING: --operator-version not provided; using default ${DEFAULT_OPERATOR_VERSION}." >&2
VERSION="${VERSION:-$DEFAULT_VERSION}"
OPERATOR_VERSION="${OPERATOR_VERSION:-$DEFAULT_OPERATOR_VERSION}"

###############################################################################
# Image list
###############################################################################
# Application images are tagged with --version; the operator with --operator-version;
# in-cluster dependencies with the chart-pinned constants above. This is the complete
# set the chart deploys for core + Fleet + Insights + Polly with in-cluster databases.
IMAGES=(
    # Core LangSmith services
    "docker.io/langchain/langsmith-backend:${VERSION}"
    "docker.io/langchain/langsmith-frontend:${VERSION}"
    "docker.io/langchain/langsmith-go-backend:${VERSION}"
    "docker.io/langchain/langsmith-ace-backend:${VERSION}"
    "docker.io/langchain/langsmith-playground:${VERSION}"
    "docker.io/langchain/hosted-langserve-backend:${VERSION}"
    "docker.io/langchain/langgraph-operator:${OPERATOR_VERSION}"
    # Add-ons: Insights, Fleet, Polly/Chat
    "docker.io/langchain/langsmith-clio:${VERSION}"                # Insights
    "docker.io/langchain/agent-builder-deep-agent:${VERSION}"      # Fleet
    "docker.io/langchain/agent-builder-tool-server:${VERSION}"     # Fleet
    "docker.io/langchain/agent-builder-trigger-server:${VERSION}"  # Fleet
    "docker.io/langchain/langsmith-polly:${VERSION}"               # Polly / Chat
    # In-cluster dependencies (tags pinned by the chart, not by --version)
    "docker.io/postgres:${PG_TAG}"                                 # platform + feature-app Postgres
    "docker.io/redis:${REDIS_TAG}"                                 # platform + feature-app + operator Redis
    "docker.io/clickhouse/clickhouse-server:${CLICKHOUSE_TAG}"
    "docker.io/pgvector/pgvector:${PGVECTOR_TAG}"                  # operator-created per-deployment Postgres
)

# Optional components
if $WITH_PRESIDIO; then
    IMAGES+=( "mcr.microsoft.com/presidio-analyzer:${PRESIDIO_TAG}" )
fi
if $WITH_SMITHDB; then
    echo "WARNING: mirroring langchain/smithdb:${SMITHDB_TAG} (floating tag). Pin to a digest for reproducible/air-gapped installs." >&2
    IMAGES+=( "docker.io/langchain/smithdb:${SMITHDB_TAG}" )
fi

echo "Using version:      ${VERSION}"
echo "Operator version:   ${OPERATOR_VERSION}"
echo "Registry:           ${REGISTRY}"
[[ -n $DEST_REPO ]] && echo "Dest repo:          ${DEST_REPO}"
echo "Platform:           ${PLATFORM}"
echo "With presidio:      ${WITH_PRESIDIO}"
echo "With smithdb:       ${WITH_SMITHDB}"
echo "Dry-run:            ${DRY_RUN}"
echo "Images to mirror:   ${#IMAGES[@]}"
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
    repo_tag=${SRC#*/}        # strip registry host (docker.io/…, mcr.microsoft.com/…)
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

echo "✓ All ${#IMAGES[@]} images processed."
