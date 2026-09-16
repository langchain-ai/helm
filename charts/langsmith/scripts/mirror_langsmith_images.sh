#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Mirror the images configured by the LangSmith chart to a destination registry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/../values.yaml"
CHART_FILE="${SCRIPT_DIR}/../Chart.yaml"
CONSOLIDATED_VERSION="0.16.21"

REGISTRY=""
VERSION=""
OPERATOR_VERSION=""
PLATFORM="linux/amd64"
DRY_RUN=false
DEST_REPO=""
INCLUDE_SANDBOXES=false

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--dest-repo <repo>] [--version <version>] [--operator-version <version>] [--platform linux/arm64] [--include-sandboxes] [--dry-run]

    --registry            Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --dest-repo           Single destination repo (e.g. langchain/langchain_repository). Tags become <image-name>-<version>.
    --version             Override the tag for LangSmith application images
    --operator-version    Override the tag for langgraph-operator
    --platform            Architecture to pull (default: linux/amd64)
    --include-sandboxes   Also mirror sandbox runtime images. Requires --platform linux/amd64.
    --dry-run             Only print the docker commands
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
        --include-sandboxes) INCLUDE_SANDBOXES=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }
[[ -f $VALUES_FILE ]] || { echo "ERROR: values.yaml not found at ${VALUES_FILE}" >&2; exit 1; }
[[ -f $CHART_FILE ]] || { echo "ERROR: Chart.yaml not found at ${CHART_FILE}" >&2; exit 1; }

if $INCLUDE_SANDBOXES && [[ $PLATFORM != "linux/amd64" ]]; then
    echo "ERROR: --include-sandboxes requires --platform linux/amd64 because sandbox runtime images are only published for amd64." >&2
    exit 1
fi

CHART_APP_VERSION=""
while IFS= read -r line; do
    if [[ $line =~ ^appVersion:[[:space:]]*\"?([^\"[:space:]#]+) ]]; then
        CHART_APP_VERSION="${BASH_REMATCH[1]}"
        break
    fi
done < "$CHART_FILE"

[[ -n $CHART_APP_VERSION ]] || { echo "ERROR: appVersion not found in ${CHART_FILE}" >&2; exit 1; }

version_before() {
    local version=$1
    local minimum=$2
    local version_major version_minor version_patch
    local minimum_major minimum_minor minimum_patch

    [[ $version =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+) ]] || return 1
    version_major=${BASH_REMATCH[1]}
    version_minor=${BASH_REMATCH[2]}
    version_patch=${BASH_REMATCH[3]}
    [[ $minimum =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+) ]]
    minimum_major=${BASH_REMATCH[1]}
    minimum_minor=${BASH_REMATCH[2]}
    minimum_patch=${BASH_REMATCH[3]}

    (( 10#$version_major < 10#$minimum_major )) && return 0
    (( 10#$version_major > 10#$minimum_major )) && return 1
    (( 10#$version_minor < 10#$minimum_minor )) && return 0
    (( 10#$version_minor > 10#$minimum_minor )) && return 1
    (( 10#$version_patch < 10#$minimum_patch ))
}

IMAGES=()

add_image() {
    IMAGES+=("${1}:${2}")
}

in_images=false
image_key=""
current_repo=""
while IFS= read -r line; do
    if [[ $line == "images:" ]]; then
        in_images=true
        continue
    fi
    $in_images || continue
    [[ $line =~ ^[^[:space:]#] ]] && break

    if [[ $line =~ ^[[:space:]]{2}([[:alnum:]_]+Image):[[:space:]]*$ ]]; then
        image_key="${BASH_REMATCH[1]}"
        current_repo=""
    elif [[ -n $image_key && $line =~ ^[[:space:]]{4}repository:[[:space:]]*\"([^\"]+)\" ]]; then
        current_repo="${BASH_REMATCH[1]}"
    elif [[ -n $current_repo && $line =~ ^[[:space:]]{4}tag:[[:space:]]*\"([^\"]*)\" ]]; then
        tag="${BASH_REMATCH[1]}"
        if [[ $current_repo == "docker.io/langchain/langgraph-operator" ]]; then
            tag="${OPERATOR_VERSION:-$tag}"
        elif [[ $current_repo == docker.io/langchain/* ]]; then
            tag="${VERSION:-${tag:-$CHART_APP_VERSION}}"
        fi

        if [[ $image_key != "sandboxHostImage" ]] || $INCLUDE_SANDBOXES; then
            [[ -n $tag ]] || { echo "ERROR: no tag configured for ${image_key}" >&2; exit 1; }
            add_image "$current_repo" "$tag"
        fi
        image_key=""
        current_repo=""
    fi
done < "$VALUES_FILE"

APP_VERSION="${VERSION:-$CHART_APP_VERSION}"
if version_before "$APP_VERSION" "$CONSOLIDATED_VERSION"; then
    for legacy_repository in \
        docker.io/langchain/langsmith-go-backend \
        docker.io/langchain/langsmith-playground \
        docker.io/langchain/hosted-langserve-backend \
        docker.io/langchain/agent-builder-tool-server \
        docker.io/langchain/agent-builder-trigger-server; do
        add_image "$legacy_repository" "$APP_VERSION"
    done
fi

[[ ${#IMAGES[@]} -gt 0 ]] || { echo "ERROR: no images found in ${VALUES_FILE}" >&2; exit 1; }

echo "App version: ${APP_VERSION}"
echo "Registry: ${REGISTRY}"
[[ -n $DEST_REPO ]] && echo "Dest repo: ${DEST_REPO}"
echo "Platform: ${PLATFORM}"
echo "Include sandboxes: ${INCLUDE_SANDBOXES}"
echo "Dry-run: ${DRY_RUN}"
echo "Images (${#IMAGES[@]}):"
printf '  %s\n' "${IMAGES[@]}"
echo

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

for SRC in "${IMAGES[@]}"; do
    repo_tag=${SRC#*/}
    tag=${repo_tag##*:}

    if [[ -n $DEST_REPO ]]; then
        image_name=${repo_tag%%:*}
        image_name=${image_name##*/}
        DEST="${REGISTRY}/${DEST_REPO}:${image_name}-${tag}"
    else
        repo=${repo_tag%%:*}
        DEST="${REGISTRY}/${repo}:${tag}"
    fi

    echo "--- Mirroring ${SRC} → ${DEST} (${PLATFORM}) ---"
    run_cmd docker pull --platform "$PLATFORM" "$SRC"
    run_cmd docker tag "$SRC" "$DEST"
    run_cmd docker push "$DEST"
    echo
done

echo "All images processed."
