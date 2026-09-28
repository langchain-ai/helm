# Approval policy

Open SWE may approve a pull request when it fits one of these and has no unresolved findings:

1. **Release version bumps.** Changes only a chart's `Chart.yaml` `version` and `appVersion`,
   image `tag` values in its `values.yaml`, and the matching generated `README.md`. Every
   image tag moves to the same new release, the chart version increases, and no other
   values change.
2. **Small chart changes.** Roughly 50 changed lines or fewer in one chart, with its
   `Chart.yaml` version bumped and `README.md` regenerated to match. For example: adding an
   optional value that defaults to current behavior, or adjusting probe timings, resource
   requests and limits, labels, or annotations.
3. **Documentation.** Markdown only, such as `README.md` or a chart's `docs/`.

Always require human review when a pull request:

- removes or renames a value, or changes a default that existing installs rely on
  (other than probe timings and resource requests and limits);
- adds a chart, template file, or Kubernetes resource kind;
- touches RBAC, service accounts, token automount, security contexts, network policies,
  secrets, TLS, or authentication settings;
- touches persistent storage, databases, migrations, backup and restore, or data retention;
- changes CRDs, operator versions, or chart dependencies;
- changes CI, release automation, or scripts (`.github/`, `hack/`, `Makefile`), or Go
  dependencies;
- touches `.open-swe/`, including this file.
