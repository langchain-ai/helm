# Automatic approval criteria

Approve a pull request only when its entire diff consists of version bumps allowed below.
If any change falls outside this allowlist or its purpose is uncertain, require human review.
Do not approve only the version-bump portion of a mixed pull request.

## Allowed version bumps

- In `charts/*/Chart.yaml`, changes only to the chart's top-level `version` and `appVersion` values.
- In chart values YAML files under `charts/`, changes only to existing container image version tags or digests.
- For a full image reference in a values file, only its tag or digest may change; the registry and repository must stay identical.
- Preserve all existing YAML keys, structure, and non-version values.
- Chart and app versions must increase, not roll back; image changes must be identifiable release updates, not mutable tags such as `latest`.
- A chart version bump may accompany an app or image version bump, but does not make other changes eligible.

## Always require human review

- Any change to a chart's `templates/` directory, including helpers, manifests, `NOTES.txt`, comments, whitespace, or hardcoded image versions.
- Any templating change anywhere, including embedded templates or manifests in values files.
- Any change to image registries or repositories, pull policies, credentials, or image-related settings other than release tags or digests.
- Added or removed keys, files, images, or dependencies; dependency version changes or lockfile changes.
- Changes to configuration defaults, resources, security, networking, storage, hooks, or chart behavior beyond the allowed version updates.
- Changes to documentation, scripts, workflows, schemas, tests, or approval criteria, even when accompanying version bumps.

Check the complete diff, not just the pull request title, description, author, or labels.
