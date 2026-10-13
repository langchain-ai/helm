#!/usr/bin/env bash
# create_marketplace_version.sh
# Create a new version of the LangSmith marketplace container product.
#
# Prerequisites:
#   - All container images and Helm chart must already be pushed to the marketplace ECR.
#   - AWS credentials must be valid with marketplace-catalog permissions.
#
# The image list and default versions come from the chart this script ships in, and match what
# mirror_langsmith_images.sh --dest-repo pushes from the same chart.
#
# Usage:
#   ./create_marketplace_version.sh
#   ./create_marketplace_version.sh --version 0.13.9 --dry-run

set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=chart_images.sh
source "$CHART_DIR/scripts/chart_images.sh"

# Defaults
PRODUCT_ID="prod-6eamcxpv3kh6m"
REGISTRY="709825985650.dkr.ecr.us-east-1.amazonaws.com"
REPO="langchain/langchain-repository"

###############################################################################
# CLI parsing
###############################################################################
VERSION=""
CHART_VERSION=""
OPERATOR_VERSION=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 [--version <version>] [--chart-version <chart-version>] [--operator-version <version>] [--product-id <id>] [--dry-run]

    --version           LangSmith version (default: appVersion of this chart)
    --chart-version     Helm chart version/tag in ECR (default: version of this chart)
    --operator-version  LangGraph operator version (default: images.operatorImage.tag of this chart)
    --product-id        Marketplace product ID (default: $PRODUCT_ID)
    --dry-run           Only print the changeset JSON, don't submit
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --chart-version) CHART_VERSION="$2"; shift 2 ;;
        --operator-version) OPERATOR_VERSION="$2"; shift 2 ;;
        --product-id) PRODUCT_ID="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) usage ;;
    esac
done

APP_VERSION=$(chart_field appVersion)
VERSION="${VERSION:-$APP_VERSION}"
CHART_VERSION="${CHART_VERSION:-$(chart_field version)}"
INCLUDE_SANDBOXES=false
INCLUDE_PRESIDIO=false

###############################################################################
# Build container image list, named the way mirror_langsmith_images.sh --dest-repo pushes them
###############################################################################
CHART_IMAGES=$(chart_images)
CONTAINER_IMAGES=""
SEEN=" "
while read -r key repo tag; do
    [[ $key == operatorImage ]] && OPERATOR_VERSION="$tag"
    image="${REGISTRY}/${REPO}:${repo##*/}-${tag}"
    [[ $SEEN == *" ${image} "* ]] && continue
    SEEN+="${image} "
    CONTAINER_IMAGES+="${CONTAINER_IMAGES:+,}"$'\n'"    \"${image}\""
done <<<"$CHART_IMAGES"
CONTAINER_IMAGES="[${CONTAINER_IMAGES}"$'\n'"]"

###############################################################################
# Build changeset
###############################################################################
CHANGESET=$(cat <<EOF
[
    {
        "ChangeType": "AddDeliveryOptions",
        "Entity": {
            "Type": "ContainerProduct@1.0",
            "Identifier": "${PRODUCT_ID}"
        },
        "DetailsDocument": {
            "Version": {
                "VersionTitle": "${VERSION}",
                "ReleaseNotes": "LangSmith ${VERSION} release"
            },
            "DeliveryOptions": [
                {
                    "DeliveryOptionTitle": "LangSmith Helm Chart",
                    "Details": {
                        "HelmDeliveryOptionDetails": {
                            "CompatibleServices": ["EKS"],
                            "ContainerImages": ${CONTAINER_IMAGES},
                            "HelmChartUri": "${REGISTRY}/${REPO}:${CHART_VERSION}",
                            "Namespace": "langsmith",
                            "Description": "Deploy LangSmith Agent Engineering Platform on Amazon EKS using Helm.",
                            "UsageInstructions": "See https://docs.smith.langchain.com/self_hosting for full installation and configuration instructions.",
                            "OverrideParameters": [
                                {
                                    "Key": "backend.serviceAccount.name",
                                    "DefaultValue": "\${AWSMP_SERVICE_ACCOUNT}",
                                    "Metadata": {
                                        "Label": "Service Account",
                                        "Description": "Kubernetes service account for AWS Marketplace license verification",
                                        "Obfuscate": false
                                    }
                                }
                            ]
                        }
                    }
                }
            ]
        }
    }
]
EOF
)

echo "Product ID:       ${PRODUCT_ID}"
echo "Version:          ${VERSION}"
echo "Chart version:    ${CHART_VERSION}"
echo "Operator version: ${OPERATOR_VERSION}"
echo

if $DRY_RUN; then
    echo "--- Changeset JSON ---"
    echo "$CHANGESET" | python3 -m json.tool
    echo
    echo "[DRY-RUN] Would submit the above changeset."
else
    echo "--- Submitting changeset ---"
    aws marketplace-catalog start-change-set \
        --catalog AWSMarketplace \
        --change-set "$CHANGESET" \
        --region us-east-1
fi
