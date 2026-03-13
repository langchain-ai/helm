# LangSmith AWS Marketplace Release Guide

Releases a new version of the LangSmith container product to AWS Marketplace.

## Prerequisites

- Docker installed and running
- `helm` CLI installed
- `aws` CLI installed and configured with credentials that have:
  - ECR push access to `709825985650.dkr.ecr.us-east-1.amazonaws.com`
  - `aws-marketplace:StartChangeSet` permission

## Steps

### 1. Authenticate to ECR

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    709825985650.dkr.ecr.us-east-1.amazonaws.com
```

Also authenticate helm to push the OCI chart:

```bash
aws ecr get-login-password --region us-east-1 \
  | helm registry login --username AWS --password-stdin \
    709825985650.dkr.ecr.us-east-1.amazonaws.com
```

### 2. Mirror images and push the Helm chart

Pulls each image from Docker Hub, retags it into `langchain/langchain-repository`, and packages + pushes the patched Helm chart.

```bash
./scripts/mirror_langsmith_images.sh \
  --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
  --dest-repo langchain/langchain-repository \
  --version 0.13.14 \
  --platform linux/amd64 \
  --push-chart
```

> Use `--dry-run` to preview all docker/helm commands without executing them.

**What the script does to the chart before pushing:**
- Sets `images.registry` to the ECR registry
- Updates third-party image repositories to point at `langchain/langchain-repository`
- Disables bundled postgres and redis (`postgres.external.enabled: true`, `redis.external.enabled: true`)

### 3. Submit the new Marketplace version

```bash
./scripts/create_marketplace_version.sh --version 0.13.14
```

> Use `--dry-run` to print the changeset JSON without submitting.

This creates a new delivery option in the Marketplace product (`prod-6eamcxpv3kh6m`) pointing at the images and chart pushed in step 2.

## Overriding defaults

| Flag | Default | Description |
|------|---------|-------------|
| `--version` | `0.13.14` | LangSmith image version |
| `--operator-version` | `0.1.37` | langgraph-operator version |
| `--chart-version` | same as `--version` | Helm chart tag in ECR |
| `--platform` | `linux/amd64` | Image architecture to pull |

## Full example with overrides

```bash
VERSION=0.13.15
OPERATOR_VERSION=0.1.38

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    709825985650.dkr.ecr.us-east-1.amazonaws.com

aws ecr get-login-password --region us-east-1 \
  | helm registry login --username AWS --password-stdin \
    709825985650.dkr.ecr.us-east-1.amazonaws.com

./scripts/mirror_langsmith_images.sh \
  --registry 709825985650.dkr.ecr.us-east-1.amazonaws.com \
  --dest-repo langchain/langchain-repository \
  --version $VERSION \
  --operator-version $OPERATOR_VERSION \
  --platform linux/amd64 \
  --push-chart

./scripts/create_marketplace_version.sh \
  --version $VERSION \
  --operator-version $OPERATOR_VERSION
```

## Marketplace product details

| Field | Value |
|-------|-------|
| Product ID | `prod-6eamcxpv3kh6m` |
| Product code | `1mg5733eu3ph622ba3k5z8fhz` |
| ECR registry | `709825985650.dkr.ecr.us-east-1.amazonaws.com` |
| ECR repo | `langchain/langchain-repository` |
| Pricing model | ExternallyMetered (custom dimensions) |

### Pricing dimensions

| Key | Name | Description |
|-----|------|-------------|
| `traces` | Per Trace | Per-trace metered usage |
| `nodes_executed` | Per Agent Run | Per agent run metered usage |
| `usage_fee` | Metered Usage Amount | General metered usage |
| `annual_commit` | Minimum annual usage commitment | Billed in advance |

### MCO submission checklist

- [ ] **Usage instructions**: Step-by-step deployment guidance is embedded in `create_marketplace_version.sh` (max 4000 chars). Verify with `--dry-run`.
- [ ] **Demo video**: Record a walkthrough showing EKS deployment and product UI. Upload to the Marketplace listing.
- [ ] **Metering**: Application must call the AWS Marketplace `MeterUsage` API to report `traces` and `nodes_executed` dimensions. See "Metering integration" below.

### Metering integration (TODO)

The product uses `ExternallyMetered` pricing dimensions, which requires the LangSmith backend to call the [AWS Marketplace MeterUsage API](https://docs.aws.amazon.com/marketplace/latest/APIReference/API_marketplace-metering_MeterUsage.html) once per hour per pod to report usage for each dimension.

**What's needed in `langchainplus`:**
1. Add `github.com/aws/aws-sdk-go-v2/service/marketplacemetering` to `smith-go/go.mod`
2. Implement a `MeterUsage` reporter that sends hourly usage for `traces` and `nodes_executed`
3. Accept the product code (`1mg5733eu3ph622ba3k5z8fhz`) via env var (e.g., `AWS_MARKETPLACE_PRODUCT_CODE`)
4. Use IRSA credentials from the `AWSMP_SERVICE_ACCOUNT` service account (already wired via Helm override)

**What's already done in the Helm chart:**
- `backend.serviceAccount.name` is overridden to `${AWSMP_SERVICE_ACCOUNT}` by AWS Marketplace at deploy time
- The service account is mounted on backend pods automatically

## Inspecting the live product

```bash
./scripts/describe_marketplace_product.sh
```
