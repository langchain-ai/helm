#!/usr/bin/env bash
# create_marketplace_version.sh
# Create a new version of the LangSmith marketplace container product.
#
# Prerequisites:
#   - All container images and Helm chart must already be pushed to the marketplace ECR.
#   - AWS credentials must be valid with marketplace-catalog permissions.
#
# Usage:
#   ./create_marketplace_version.sh --version 0.13.14
#   ./create_marketplace_version.sh --version 0.13.14 --dry-run

set -euo pipefail

# Defaults
DEFAULT_VERSION="0.13.14"
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
    --chart-version     Helm chart version/tag in ECR (default: same as --version)
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
CHART_VERSION="${CHART_VERSION:-$VERSION}"
OPERATOR_VERSION="${OPERATOR_VERSION:-$DEFAULT_OPERATOR_VERSION}"

###############################################################################
# Build the changeset JSON via Python to safely handle multi-line strings
###############################################################################
export REGISTRY VERSION CHART_VERSION OPERATOR_VERSION PRODUCT_ID REPO
CHANGESET=$(python3 <<'PYEOF'
import json, os

registry = os.environ["REGISTRY"]
repo = os.environ["REPO"]
version = os.environ["VERSION"]
chart_version = os.environ["CHART_VERSION"]
operator_version = os.environ["OPERATOR_VERSION"]
product_id = os.environ["PRODUCT_ID"]

container_images = [
    f"{registry}/{repo}:langsmith-ace-backend-{version}",
    f"{registry}/{repo}:langsmith-backend-{version}",
    f"{registry}/{repo}:langsmith-clio-{version}",
    f"{registry}/{repo}:langsmith-frontend-{version}",
    f"{registry}/{repo}:hosted-langserve-backend-{version}",
    f"{registry}/{repo}:langgraph-operator-{operator_version}",
    f"{registry}/{repo}:langsmith-go-backend-{version}",
    f"{registry}/{repo}:langsmith-playground-{version}",
    f"{registry}/{repo}:agent-builder-tool-server-{version}",
    f"{registry}/{repo}:agent-builder-trigger-server-{version}",
    f"{registry}/{repo}:agent-builder-deep-agent-{version}",
    f"{registry}/{repo}:postgres-15.15",
    f"{registry}/{repo}:redis-8",
    f"{registry}/{repo}:clickhouse-server-25.12",
]

usage_instructions = f"""Prerequisites:
- An Amazon EKS cluster (v1.24+) with at least 16 vCPU and 64 GB RAM available.
- kubectl and Helm v3.8+ configured to access the cluster.
- An external PostgreSQL 15+ instance (Amazon RDS recommended).
- An external Redis 7+ instance (Amazon ElastiCache recommended).
- An external ClickHouse 24+ instance (ClickHouse Cloud or self-managed).
- A LangSmith license key (obtain from https://smith.langchain.com).

Step 1 - Create a values file (langsmith-values.yaml):

config:
  langsmithLicenseKey: "<your-license-key>"
  apiKeySalt: "<random-32-byte-base64-string>"
  authType: "mixed"
  basicAuth:
    enabled: true
    initialOrgAdminEmail: "admin@example.com"
    initialOrgAdminPassword: "<secure-password>"
    jwtSecret: "<random-32-byte-base64-string>"
postgres:
  external:
    enabled: true
    host: "<rds-endpoint>"
    port: 5432
    user: "langsmith"
    password: "<db-password>"
    database: "langsmith"
redis:
  external:
    enabled: true
    connectionUrl: "redis://<elasticache-endpoint>:6379"
clickhouse:
  external:
    enabled: true
    host: "<clickhouse-endpoint>"
    port: 8123
    user: "default"
    password: "<clickhouse-password>"
    database: "default"

Step 2 - Install with Helm:

helm install langsmith oci://{registry}/{repo} \\
  --version {chart_version} \\
  --namespace langsmith --create-namespace \\
  -f langsmith-values.yaml

Step 3 - Verify the deployment:

kubectl -n langsmith get pods
All pods should reach Running status within 5 minutes.

Step 4 - Access LangSmith:

kubectl -n langsmith port-forward svc/langsmith-frontend 8080:80
Open http://localhost:8080 and log in with the admin credentials from Step 1.

For production, configure an Ingress or LoadBalancer.
Full documentation: https://docs.langchain.com/langsmith/architectural-overview
Demo video: https://drive.google.com/file/d/1j918iJz4JsBmu3qwEhFxmzbl2hqoZvof/view"""

assert len(usage_instructions) <= 4000, f"UsageInstructions too long: {len(usage_instructions)} chars"

changeset = [
    {
        "ChangeType": "AddDeliveryOptions",
        "Entity": {
            "Type": "ContainerProduct@1.0",
            "Identifier": product_id,
        },
        "DetailsDocument": {
            "Version": {
                "VersionTitle": version,
                "ReleaseNotes": f"LangSmith {version} release",
            },
            "DeliveryOptions": [
                {
                    "DeliveryOptionTitle": f"LangSmith {version} Helm Chart",
                    "Details": {
                        "HelmDeliveryOptionDetails": {
                            "CompatibleServices": ["EKS"],
                            "ContainerImages": container_images,
                            "HelmChartUri": f"{registry}/{repo}:{chart_version}",
                            "Namespace": "langsmith",
                            "ReleaseName": "langsmith",
                            "Description": "Deploy LangSmith Agent Engineering Platform on Amazon EKS using Helm.",
                            "UsageInstructions": usage_instructions,
                            "QuickLaunchEnabled": False,
                            "OverrideParameters": [
                                {
                                    "Key": "backend.serviceAccount.name",
                                    "DefaultValue": "${AWSMP_SERVICE_ACCOUNT}",
                                    "Metadata": {
                                        "Label": "Service Account",
                                        "Description": "Kubernetes service account for AWS Marketplace license verification",
                                        "Obfuscate": False,
                                    },
                                }
                            ],
                        }
                    },
                }
            ],
        },
    }
]

print(json.dumps(changeset))
PYEOF
)

# Verify JSON was generated
if [ -z "$CHANGESET" ]; then
    echo "ERROR: Failed to generate changeset JSON" >&2
    exit 1
fi

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
