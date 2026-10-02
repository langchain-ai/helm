#!/usr/bin/env bash
# mirror_langsmith_images.sh
# Pull each image, retag it, and push to a destination registry.
#
# The image list and tags come from the values.yaml of the chart this script ships in, so run the
# copy from the chart release you are installing:
#
#   helm pull langsmith --repo https://langchain-ai.github.io/helm/ --version <chart-version> --untar
#   bash langsmith/scripts/mirror_langsmith_images.sh --registry myregistry
#
# Ensure that you have logged into the destination registry if credentials are required.
#
# Default mode: retag as <REGISTRY>/<original-repo>:<tag>
# Marketplace mode (--dest-repo): retag as <REGISTRY>/<dest-repo>:<image-name>-<tag>
#
# Examples:
# ./mirror_langsmith_images.sh --registry myregistry --platform linux/arm64
# ./mirror_langsmith_images.sh --registry myregistry --include-sandboxes --platform linux/amd64
# ./mirror_langsmith_images.sh --registry myregistry --fips
# ./mirror_langsmith_images.sh --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
#     --dest-repo langchain/langchain-repository --platform linux/amd64 --dry-run

set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# LangSmith images published with a -fips variant.
FIPS_VARIANTS=" langsmith-backend langsmith-frontend langsmith-ace-backend langgraph-operator "

###############################################################################
# CLI parsing
###############################################################################
REGISTRY=""
VERSION=""
OPERATOR_VERSION=""
PLATFORM="linux/amd64"
DRY_RUN=false
DEST_REPO=""
INCLUDE_SANDBOXES=false
INCLUDE_PRESIDIO=false
FIPS=false

usage() {
    cat <<EOF
Usage: $0 --registry <registry-prefix> [--dest-repo <repo>] [--version <version>] [--platform linux/arm64] [--fips] [--include-sandboxes] [--include-presidio] [--dry-run]

    --registry  Mandatory. Destination registry (e.g. myregistry or 12345678.dkr.ecr.us-east-1.amazonaws.com)
    --dest-repo Single destination repo (e.g. langchain/langchain_repository). Tags become <image-name>-<version>.
    --version            Override the LangSmith version (default: appVersion of this chart)
    --operator-version   Override the langgraph-operator version (default: images.operatorImage.tag of this chart)
    --platform           Architecture to pull (default: linux/amd64)
    --fips               Mirror the -fips variant of each LangSmith image that has one. Images without one, and
                         third-party images, are mirrored as-is.
    --include-sandboxes  Also mirror sandbox runtime images. Requires --platform linux/amd64.
    --include-presidio   Also mirror the Presidio analyzer used by the Agent Gateway. Requires --platform linux/amd64.
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
        --fips) FIPS=true; shift ;;
        --include-sandboxes) INCLUDE_SANDBOXES=true; shift ;;
        --include-presidio) INCLUDE_PRESIDIO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

[[ -z $REGISTRY ]] && { echo "ERROR: --registry is required"; usage; }

if [[ ! -f $CHART_DIR/Chart.yaml || ! -f $CHART_DIR/values.yaml ]]; then
    echo "ERROR: no Chart.yaml and values.yaml in ${CHART_DIR}. Run the copy of this script inside the chart:" >&2
    echo "  helm pull langsmith --repo https://langchain-ai.github.io/helm/ --version <chart-version> --untar" >&2
    exit 1
fi

if $INCLUDE_SANDBOXES && [[ "$PLATFORM" != "linux/amd64" ]]; then
    echo "ERROR: --include-sandboxes requires --platform linux/amd64 because sandbox runtime images are only published for amd64." >&2
    exit 1
fi

if $INCLUDE_PRESIDIO && [[ "$PLATFORM" != "linux/amd64" ]]; then
    echo "ERROR: --include-presidio requires --platform linux/amd64 because the Presidio analyzer image is only published for amd64." >&2
    exit 1
fi

APP_VERSION=$(sed -n 's/^appVersion: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$CHART_DIR/Chart.yaml")
VERSION="${VERSION:-$APP_VERSION}"

###############################################################################
# Image list, read from the images: block of values.yaml
###############################################################################
# Print "<key> <repository> <tag>" for each entry under images: that has a repository.
# An empty tag prints as "-".
list_chart_images() {
    awk '
        function flush() { if (key != "" && repo != "") print key, repo, (tag == "" ? "-" : tag); key = "" }
        /^images:/ { in_images = 1; next }
        in_images && /^[^ #]/ { flush(); exit }
        !in_images || /^ *#/ { next }
        /^  [A-Za-z0-9]+: *$/ { flush(); key = $1; sub(/:$/, "", key); repo = ""; tag = ""; next }
        /^    repository:/ { repo = $2; gsub(/"/, "", repo) }
        /^    tag:/ { tag = $2; gsub(/"/, "", tag) }
        END { if (in_images) flush() }
    ' "$CHART_DIR/values.yaml"
}

IMAGES=()
NO_FIPS_VARIANT=()

while read -r key repo tag; do
    case $key in
        sandboxHostImage|juicefs*) $INCLUDE_SANDBOXES || continue ;;
        presidioAnalyzerImage) $INCLUDE_PRESIDIO || continue ;;
    esac

    # LangSmith images track appVersion; an empty tag means the chart defaults it to appVersion.
    if [[ $key == operatorImage ]]; then
        tag="${OPERATOR_VERSION:-$tag}"
    elif [[ $tag == "-" || $tag == "$APP_VERSION" ]]; then
        tag="$VERSION"
    fi

    if $FIPS && [[ $repo == docker.io/langchain/* ]]; then
        if [[ $FIPS_VARIANTS == *" ${repo##*/} "* ]]; then
            repo="${repo}-fips"
        else
            NO_FIPS_VARIANT+=("${repo##*/}")
        fi
    fi

    IMAGES+=("${repo}:${tag}")
done < <(list_chart_images)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "ERROR: found no images under images: in ${CHART_DIR}/values.yaml" >&2
    exit 1
fi

echo "Using version: ${VERSION}"
echo "Registry: ${REGISTRY}"
[[ -n $DEST_REPO ]] && echo "Dest repo: ${DEST_REPO}"
echo "Platform: ${PLATFORM}"
echo "FIPS: ${FIPS}"
echo "Include sandboxes: ${INCLUDE_SANDBOXES}"
echo "Include presidio: ${INCLUDE_PRESIDIO}"
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

if [[ ${#NO_FIPS_VARIANT[@]} -gt 0 ]]; then
    echo
    echo "WARNING: no -fips variant is published for ${NO_FIPS_VARIANT[*]}; mirrored the standard image." >&2
fi
