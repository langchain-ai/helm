# Security & CVE Transparency

<!-- BEGIN: current-chart -->
**Latest release covered:** chart `langsmith-0.15.0` / images tagged `0.15.8`
<!-- END: current-chart -->
<!-- BEGIN: last-updated -->
**Last updated:** 2026-05-28
<!-- END: last-updated -->
**Maintainer contact:** security@langchain.dev

> **Chart version vs. image tag.** The Helm chart and the container images use
> independent version schemes. The chart version (e.g., `langsmith-0.14.6`) is
> what you set in your Helm install; the chart's `appVersion` (e.g., `0.14.9`)
> is the tag your scanner will report against the running images
> (`docker.io/langchain/langsmith-backend:0.14.9`, etc.). Both are listed in
> the heading above so you can match either side to the CVE table below.
> (The current GA release follows the same pattern: chart `langsmith-0.15.0`
> ships images tagged `0.15.8`.)

## Covered images

This document covers the following container images published by LangChain and
deployed by the `langsmith` Helm chart in this repository:

- `docker.io/langchain/langsmith-backend`
- `docker.io/langchain/langsmith-go-backend`
- `docker.io/langchain/langsmith-ace-backend`
- `docker.io/langchain/langsmith-frontend`
- `docker.io/langchain/langsmith-playground`
- `docker.io/langchain/hosted-langserve-backend`
- `docker.io/langchain/langsmith-clio` (deployed by the `langsmith` chart as the insights/summarization agent)
- `docker.io/langchain/langsmith-polly` (deployed by the `langsmith` chart as the tracing agent)
- `docker.io/langchain/agent-builder-deep-agent` (deployed by the `langsmith` chart for agent-builder workloads)
- `docker.io/langchain/agent-builder-tool-server`
- `docker.io/langchain/agent-builder-trigger-server`
- `docker.io/langchain/langgraph-operator` (deployed by the `langsmith` chart and by `langgraph-dataplane`)

## Scope

This document covers images deployed by the `langsmith` Helm chart only. The
`langgraph-cloud`, `langgraph-dataplane`, and `mission-control` charts in this
repository (which deploy `langchain/langgraph-api`,
`langchain/mission-control-backend`, and `langchain/mission-control-frontend`,
among others) do not yet have a security transparency artifact. Contact
[security@langchain.dev](mailto:security@langchain.dev) for findings against
those images.

Within the `langsmith` chart, this document applies to both deployment models
that pull the images above:

- **Self-hosted** (Helm-based installs in customer-managed Kubernetes)
- **Bring Your Own Cloud (BYOC)** (LangChain-managed control plane, customer-managed data plane)

This document covers self-hosted and BYOC deployments of the langsmith Helm chart. LangChain operates its own internal scans for the hosted service at smith.langchain.com — customers using only the hosted service do not need to scan images directly.

If your security team is running an image scanner (Wiz, Trivy, JFrog Xray, Prisma
Cloud, Black Duck, Snyk, Anchore, or similar) against any of the images above,
**triage your findings against this document before opening a ticket.** Most
common findings are already addressed below — either as patched in the current
release, as a known false positive, or as an accepted risk with a published
remediation ETA.

## Remediation SLAs

LangChain commits to the following remediation timelines, measured from the
date of a confirmed finding (either via internal scan or third-party report):

| Severity | SLA |
|---|---|
| Critical (CVSS 9.0–10.0) | Patched image published within **2 weeks** |
| High (CVSS 7.0–8.9) | Patched image published within **30 days** |
| Medium (CVSS 4.0–6.9) | Addressed on the next regular patch cycle |
| Low (CVSS < 4.0) | Addressed on the next regular patch cycle |

**Deployment-model parity:** Patched images are published to the same registry
on the same SLA windows regardless of whether you are running hosted,
self-hosted, or BYOC. There is no separate "BYOC patch track" — when a fix
ships, it ships to one tag and all deployments pull from the same source.

To consume a patched image, bump the chart version when upgrading the langsmith Helm release. Image tags are hardcoded in values.yaml per chart version, so bumping the chart version is what pulls the patched image. The Chart.yaml appVersion field is metadata only and does not change which image gets pulled.

---

## Per-release CVE history

Patched CVEs for each release are tracked as auto-generated security fix bullets in the corresponding release entry of the [self-hosted changelog](https://docs.langchain.com/langsmith/self-hosted-changelog). The changelog is the single source of truth for "what CVEs were fixed in version X." This document covers the standing security posture (image inventory, false-positive registry, SLAs, reporting flow) that is not version-specific.

> **Chart version is not the image tag.** The changelog lists fixes by Helm chart version (e.g., `langsmith-0.14.6`). The image tag containing the fix is the chart's `appVersion`, which is different (e.g., `0.14.9`). To pull a patched image: find the chart version in the changelog, look up that chart's `appVersion` in [`charts/langsmith/Chart.yaml`](https://github.com/langchain-ai/helm/blob/main/charts/langsmith/Chart.yaml) at the matching release tag, then pull `docker.io/langchain/<image>:<appVersion>` — not the chart number.
>
> **Verified example:** chart `langsmith-0.14.6` shipped images tagged `0.14.9`. Pulling `langsmith-backend:0.14.6` does not clear these CVEs (Mako and python-multipart still vulnerable in this tag); pulling `langsmith-backend:0.14.9` does.

---

## Scanner noise — Chainguard base images

> **Before closing any finding here, check your scanner's `Status` field.**
>
> - **`Status: fixed`** with an upgrade version available → NOT a false positive. The patch exists in a newer image; rebuild/pull the patched tag, do not close.
> - **`Status: will_not_fix`** → eligible for close-with-confidence if a pattern below matches, verified against the [Chainguard advisory feed](https://images.chainguard.dev/security).
> - **`Status: affected`** (no fix listed) → eligible only if a pattern below cites a specific advisory marking the CVE as not exploitable in the running image.
> - **Any other status, or no pattern match below** → report to security@langchain.dev.

Several of the images above are built on [Chainguard](https://www.chainguard.dev/)
Wolfi-based minimal base images. Chainguard maintains its own security advisory
database, and **the way Chainguard tracks fixes does not always match upstream
NVD/OSV records**. As a result, third-party scanners that consult only upstream
vulnerability databases routinely flag CVEs against Chainguard images even when
the affected code is not present, the package is rebuilt with the fix
backported, or the vulnerable interface is not exposed.

**Reference:** Chainguard image security feed — [https://images.chainguard.dev/directory](https://images.chainguard.dev/directory)

**Rebuild-hygiene caveat:** These rationales assume the image was built within
the last 30 days against a current Chainguard base. If you are running a pinned
older image, the package-is-patched claim may not hold — contact
[security@langchain.dev](mailto:security@langchain.dev) to request a rebuild
confirmation for the specific image+tag you are running.

The table below documents the most common false-positive patterns we see in
customer scan reports. If a finding from your scanner matches a row here, you
can close it with confidence and reference this document.

| CVE | Package | Affected images | Rationale |
|---|---|---|---|
| `CVE-YYYY-NNNNN` (any unfixed `glibc` CVE flagged against a Chainguard/Wolfi image) | `glibc` | All images built on Chainguard bases | Chainguard/Wolfi images use the same upstream glibc but track fixes through Chainguard's own advisory feed. Scanners that read only NVD may report a glibc CVE as "unfixed" because they don't see a matching Chainguard advisory entry. The package is patched; the scanner record is stale. Verify by comparing the installed glibc version in the image against the Chainguard advisory for that CVE. |
| `CVE-YYYY-NNNNN` (any OpenSSL CVE flagged against `langsmith-go-backend`) | `openssl` | `langsmith-go-backend` | The `langsmith-go-backend` binary uses Go's `crypto/tls` (pure-Go implementation, no OpenSSL linkage). The runtime image does not install the `openssl` package. If your scanner reports an OpenSSL CVE against this image, it is matching package metadata from the Chainguard base layer; the vulnerable code is not loaded into the running container. |
| `CVE-YYYY-NNNNN` (any CVE marked "will not fix" in Chainguard's advisory feed) | Various | All images built on Chainguard bases | Chainguard sometimes marks individual CVEs as "will not fix" when the upstream vulnerability does not affect their build (e.g., the vulnerable feature is compiled out, the code path is unreachable in a Wolfi-based minimal context, or the CVE applies to a Debian-specific patch not present in Wolfi). Cross-reference with `https://images.chainguard.dev/security` for the specific image and tag. |
| `CVE-YYYY-NNNNN` (any CVE in a build-time-only package like `apk-tools`, `ca-certificates-bundle`, `wolfi-baselayout`) | Various build-only packages | All images built on Chainguard bases | These packages exist in the image manifest but are not loaded at runtime in a Wolfi-based minimal image. Scanners that match by package name alone surface these as findings; in practice they are not on the running attack surface. |

**How to confirm a finding is the same class as one of these rows:** check the
package name and version reported by your scanner, then look up the same
package + version in the Chainguard image security feed for that specific
image and tag. If Chainguard's record shows the package as patched or
"will not fix" with a documented rationale, your scanner is reading from a
stale or upstream-only database and the finding can be closed.

**This section is updated as confirmed false-positive patterns accumulate from
customer scan reports.** If you see a recurring finding not listed here that you
believe is a false positive, please report it (see below) so we can either add
it to this registry or treat it as a real finding under SLA.

---

## Accepted risk

The following findings have been triaged as real but with mitigated exposure.
Each has a published remediation ETA.

| CVE | Affected image(s) | Severity | Rationale | Fix ETA |
|---|---|---|---|---|
| `clickhouse-connect` dependency CVEs (no public CVE assigned at time of writing; this row is preemptive scope-marking for the package pending the SmithDB migration) | `langsmith-backend` | Varies (typically Medium–High) | ClickHouse client library dependency (`clickhouse-connect`). The vulnerable code paths handle ClickHouse wire-protocol input, which in LangSmith is sourced exclusively from our managed ClickHouse cluster (or, in self-hosted/BYOC, the customer's own ClickHouse deployment) — not from untrusted user input. Exposure is gated by trust in the ClickHouse instance, not the network. A migration off this client is in progress as part of the broader SmithDB data-tier work. | Tracked under the SmithDB migration; ETA updated quarterly. Contact [security@langchain.dev](mailto:security@langchain.dev) for current status. |

When the migration completes, this row will be removed and any remaining
ClickHouse-attributed findings will be re-triaged under standard SLA.

---

## Verifying image authenticity

LangChain does not currently publish cosign signatures or SLSA provenance
attestations for self-hosted images. Customers requiring cryptographic image
verification should use digest-pinned references (available in each Helm
chart's `values.yaml`) and verify the source registry
(`docker.io/langchain/*`). Image signing is planned; contact
[security@langchain.dev](mailto:security@langchain.dev) for current status or
to register interest.

---

## Reporting a finding

If you have a finding that is not addressed above, please report it to:

- **Email:** security@langchain.dev
- **Trust center:** [trust.langchain.com](https://trust.langchain.com)

**For self-hosted and BYOC deployments**, please include the following when
filing a report — this lets us reproduce your scanner output against the exact
image you are running:

<!-- BEGIN: reporting-example -->
1. The chart and `appVersion` you are deployed on (e.g., chart `langsmith-0.15.0` / `appVersion 0.15.8`)
<!-- END: reporting-example -->
2. The full image reference including digest **if available**, or tag and pull timestamp. Example to retrieve the digest:
   `docker inspect <image> --format '{{.RepoDigests}}'` →
   `langchain/langsmith-backend@sha256:...`
3. The raw scanner output (SARIF, JSON, or CSV) — not a summary
4. The scanner name and version (e.g., `Trivy 0.52.0`, `Wiz`, `JFrog Xray`)

We typically acknowledge reports within one business day and provide a
triage decision (Patched / False Positive / Accepted Risk / Under
Investigation) within five business days. Critical findings are
acknowledged on the same business day.

**Disclosure timeline.** Confirmed critical and high findings receive a
**7-day customer-notification window** before any public disclosure (Trust
Center update, GitHub Security Advisory). Medium and low findings are
disclosed alongside the patched release.

---

*This document is updated with each self-hosted release. For BYOC deployments,
patched images are published on the same cadence.*
