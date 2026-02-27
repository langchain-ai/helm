#!/usr/bin/env bash
# describe_marketplace_product.sh
# Describe the LangSmith marketplace product to inspect current versions and delivery options.
#
# Usage: ./describe_marketplace_product.sh [--product-id <id>]

set -euo pipefail

DEFAULT_PRODUCT_ID="prod-6eamcxpv3kh6m"
PRODUCT_ID=""

usage() {
    cat <<EOF
Usage: $0 [--product-id <id>]

    --product-id    Marketplace product ID (default: $DEFAULT_PRODUCT_ID)
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --product-id) PRODUCT_ID="$2"; shift 2 ;;
        *) usage ;;
    esac
done

PRODUCT_ID="${PRODUCT_ID:-$DEFAULT_PRODUCT_ID}"

echo "Describing product: ${PRODUCT_ID}"
echo

aws marketplace-catalog describe-entity \
    --catalog AWSMarketplace \
    --entity-id "$PRODUCT_ID" \
    --region us-east-1 \
    --query '{EntityId: EntityIdentifier, Details: Details}' \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
details = json.loads(data.get('Details', '{}'))
print(json.dumps(details, indent=2))
"
