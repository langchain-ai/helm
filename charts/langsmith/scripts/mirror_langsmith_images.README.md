# Mirroring LangSmith self-hosted images

`mirror_langsmith_images.sh` pulls every image the LangSmith self-hosted Helm chart deploys,
retags it, and pushes it to a private registry — for air-gapped clusters or environments that
must pull from an internal registry.

It mirrors the **complete** set for a deployment that includes the add-ons (Fleet, Insights,
Polly/Chat) with in-cluster databases.

## Quick start

Always dry-run first to see exactly what would be pushed:

```bash
./mirror_langsmith_images.sh --registry your-registry.example.com --dry-run
```

Then mirror for real (defaults to the latest GA app version):

```bash
./mirror_langsmith_images.sh --registry your-registry.example.com
```

## Flags

| Flag | Purpose |
|------|---------|
| `--registry` | **Required.** Destination registry prefix (e.g. `your-registry.example.com` or `123456789012.dkr.ecr.us-east-1.amazonaws.com`). |
| `--version` | App-image tag for all `langchain/*` LangSmith images. **This is the chart's `appVersion`, not the Helm chart version** (see below). Defaults to the latest GA app version. |
| `--operator-version` | Tag for `langgraph-operator`. Defaults to the value pinned by the current chart. |
| `--platform` | Architecture to pull (`linux/amd64` default, or `linux/arm64`). |
| `--dest-repo` | "Marketplace" mode: push every image into a single repo, tagged `<image-name>-<version>` (useful for registries like ECR that prefer one repo). |
| `--with-presidio` | Also mirror `mcr.microsoft.com/presidio-analyzer` (only needed if you enable PII redaction). |
| `--with-smithdb` | Also mirror `langchain/smithdb` (0.16+ only). |
| `--dry-run` | Print the `docker` commands without executing them. |

## Examples

```bash
# 1. Preview the GA image set without pushing
./mirror_langsmith_images.sh --registry your-registry.example.com --dry-run

# 2. Mirror the latest GA release (app version 0.15.18)
./mirror_langsmith_images.sh --registry your-registry.example.com --version 0.15.18

# 3. Mirror a release candidate instead of GA
./mirror_langsmith_images.sh --registry your-registry.example.com \
    --version 0.16.13rc1 --operator-version 0.1.47

# 4. arm64 nodes
./mirror_langsmith_images.sh --registry your-registry.example.com \
    --version 0.15.18 --platform linux/arm64

# 5. Single-repo ("marketplace") mode, e.g. AWS ECR
./mirror_langsmith_images.sh --registry 123456789012.dkr.ecr.us-east-1.amazonaws.com \
    --dest-repo langchain/langsmith --version 0.15.18

# 6. Include the optional components (PII redaction + smithdb)
./mirror_langsmith_images.sh --registry your-registry.example.com \
    --version 0.16.13rc1 --operator-version 0.1.47 --with-presidio --with-smithdb
```

## What gets mirrored

| Group | Images |
|-------|--------|
| Core | `langsmith-backend`, `langsmith-frontend`, `langsmith-go-backend`, `langsmith-ace-backend`, `langsmith-playground`, `hosted-langserve-backend`, `langgraph-operator` |
| Add-ons | `langsmith-clio` (Insights), `agent-builder-deep-agent` + `agent-builder-tool-server` + `agent-builder-trigger-server` (Fleet), `langsmith-polly` (Polly/Chat) |
| In-cluster dependencies | `postgres`, `redis`, `clickhouse-server`, `pgvector/pgvector` |
| Optional (flags) | `presidio-analyzer` (`--with-presidio`), `smithdb` (`--with-smithdb`) |

## IMPORTANT: chart version vs. image tag

There are **two different version numbers**, and mixing them up is the most common mistake:

- **Helm chart version** — what the self-hosted changelog and GitHub releases show (e.g. `0.15.13`),
  and what you pass to `helm upgrade --install … --version`.
- **App image tag (`appVersion`)** — the tag on the container images (e.g. `0.15.18`), and what this
  script's `--version` expects.

They increment independently. For example, chart **`0.15.13`** ships app images tagged **`0.15.18`**.
Passing the chart version (`0.15.13`) to `--version` would try to pull image tags that don't exist.

| | Helm chart `--version` (helm) | App images (`--version` here) | Operator (`--operator-version`) | postgres | redis | clickhouse | pgvector |
|---|---|---|---|---|---|---|---|
| Latest GA | `0.15.13` | `0.15.18` | `0.1.47` | `14.7` | `7` | `25.12` | `pg15` |
| Latest RC | `0.16.0-rc.12` | `0.16.13rc1` | `0.1.47` | `14.7` | `7` | `25.12` | `pg15` |

_(As of 2026-07-14. Always re-verify against the chart you install — see next section.)_

## Picking the right versions for a release (do this on every upgrade)

The app-image tag follows `--version`, but the **dependency tags** (`postgres`, `redis`, `clickhouse`,
`pgvector`) are pinned by the chart release and are **independent of `--version`**. They're set as
constants at the top of the script. On the current GA and RC they're identical (`14.7` / `7` / `25.12` /
`pg15`), so moving between those only changes `--version`. A future release could bump one of them — so
when you adopt a new chart version, verify the tags against that chart and update the constants if needed.

Read the exact tags a given chart version deploys straight from the chart source (replace `CHART_VER`
with the Helm chart version you're installing):

```bash
CHART_VER=0.15.13
BASE="https://raw.githubusercontent.com/langchain-ai/helm/langsmith-${CHART_VER}/charts/langsmith"

# App-image tag to pass as --version (this is the chart's appVersion):
curl -s "$BASE/Chart.yaml" | grep '^appVersion:'

# Operator + dependency tags (compare against the script's constants):
curl -s "$BASE/values.yaml" | grep -E '^  (operatorImage|postgresImage|redisImage|clickhouseImage):' -A3 \
  | grep -E 'Image:|tag:'

# Operator-created database images (pgvector + inline redis):
curl -s "$BASE/values.yaml" | grep -E 'pgvector/pgvector:pg|image: docker.io/redis:'
```

(If you've added the LangSmith Helm repo, `helm show values <chart> --version <CHART_VER>` gives the
same information.)

Then set:
- `--version` = the `appVersion` value
- `--operator-version` = `operatorImage.tag`
- the script's `PG_TAG` / `REDIS_TAG` / `CLICKHOUSE_TAG` / `PGVECTOR_TAG` constants = the dependency tags,
  **only if they changed** from what the script already has.

## After mirroring: point the chart at your registry

In your `values.yaml`:

```yaml
images:
  registry: "your-registry.example.com"
  imagePullSecrets:
    - name: langsmith-pull-secret          # a docker-registry Secret in the install namespace
  # For each image, strip the leading "docker.io/" from the repository so it isn't doubled, and pin the tag.
  backendImage: { repository: "langchain/langsmith-backend", tag: "0.15.18" }
  # …one entry per image…
```

**One thing `images.registry` does NOT cover:** the langgraph-operator creates a Redis and a Postgres
(`pgvector`) for each agent deployment from raw image strings in `operator.templates.redis` and
`operator.templates.db`. Those are not rewritten by `images.registry`, so override the image line in each:

```yaml
operator:
  templates:
    redis: |   # …change the image line to  your-registry.example.com/redis:7
    db: |      # …change the image line to  your-registry.example.com/pgvector/pgvector:pg15
```

The full template blocks (with a placeholder registry) are in the docs — see the reference below.

## Optional: verify image signatures

v15+ `docker.io/langchain/*` images are keyless Cosign-signed. You can verify before and after mirroring:

```bash
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp 'https://github\.com/langchain-ai/langchainplus/\.github/workflows/release_self_hosted_on_version_bump\.yaml@refs/heads/v[0-9]+-stable' \
  docker.io/langchain/langsmith-backend:<tag>
```

## References

- Mirror images guide (incl. the full operator-template overrides and signature verification):
  https://docs.langchain.com/langsmith/self-host-mirroring-images
- Self-hosted changelog (chart versions): https://docs.langchain.com/langsmith/self-hosted-changelog
- Kubernetes install guide: https://docs.langchain.com/langsmith/kubernetes
