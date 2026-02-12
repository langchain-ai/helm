#!/usr/bin/env bash
# create_marketplace_version.sh
# Create a new version of the LangSmith marketplace container product.
#
# Prerequisites:
#   - All container images and Helm chart must already be pushed to the marketplace ECR.
#   - AWS credentials must be valid with marketplace-catalog permissions.
#
# Usage:
#   ./create_marketplace_version.sh --version 0.3.10
#   ./create_marketplace_version.sh --version 0.3.10 --dry-run

set -euo pipefail

# Defaults
DEFAULT_VERSION="0.3.10"
DEFAULT_CHART_VERSION="0.3.10"
DEFAULT_OPERATOR_VERSION="0.1.37"
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
Usage: $0 --version <version> [--chart-version <chart-version>] [--operator-version <version>] [--product-id <id>] [--dry-run]

    --version           LangSmith version (default: $DEFAULT_VERSION)
    --chart-version     Helm chart version/tag in ECR (default: $DEFAULT_CHART_VERSION)
    --operator-version  LangGraph operator version (default: $DEFAULT_OPERATOR_VERSION)
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

VERSION="${VERSION:-$DEFAULT_VERSION}"
CHART_VERSION="${CHART_VERSION:-$DEFAULT_CHART_VERSION}"
OPERATOR_VERSION="${OPERATOR_VERSION:-$DEFAULT_OPERATOR_VERSION}"

###############################################################################
# Build container image list
###############################################################################
CONTAINER_IMAGES=$(cat <<EOF
[
    "${REGISTRY}/${REPO}:langsmith-ace-backend-${VERSION}",
    "${REGISTRY}/${REPO}:langsmith-backend-${VERSION}",
    "${REGISTRY}/${REPO}:langsmith-clio-${VERSION}",
    "${REGISTRY}/${REPO}:langsmith-frontend-${VERSION}",
    "${REGISTRY}/${REPO}:hosted-langserve-backend-${VERSION}",
    "${REGISTRY}/${REPO}:langgraph-operator-${OPERATOR_VERSION}",
    "${REGISTRY}/${REPO}:langsmith-go-backend-${VERSION}",
    "${REGISTRY}/${REPO}:langsmith-playground-${VERSION}",
    "${REGISTRY}/${REPO}:agent-builder-tool-server-${VERSION}",
    "${REGISTRY}/${REPO}:agent-builder-trigger-server-${VERSION}",
    "${REGISTRY}/${REPO}:agent-builder-deep-agent-${VERSION}",
    "${REGISTRY}/${REPO}:postgres-15.15",
    "${REGISTRY}/${REPO}:redis-8",
    "${REGISTRY}/${REPO}:clickhouse-server-25.12"
]
EOF
)

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
