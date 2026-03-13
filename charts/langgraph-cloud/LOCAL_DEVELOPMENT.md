# LangGraph Cloud Local Development

This chart now has a safe local development workflow built around `kind`.

The goal is to make it easy to:

- render chart changes locally
- install the chart into an isolated disposable cluster
- run a basic smoke test against the API
- collect diagnostics when something fails

## Safety Model

The scripts are intentionally scoped to `kind` clusters only.

- They target `kind-${KIND_CLUSTER_NAME}` explicitly.
- They refuse to run against a non-`kind` kube context.
- They default to a dedicated namespace and release name.
- They use `ClusterIP` services and `kubectl port-forward` instead of exposing public load balancers.

The default local values live in [ci/dev-kind-values.yaml](./ci/dev-kind-values.yaml).

## Prerequisites

You need:

- `docker`
- `kind`
- `kubectl`
- `helm`

If you want to test your own app image, set `LANGGRAPH_CLOUD_API_IMAGE`. If you do not set one, the scripts use the chart's default API image.

## Quickstart

From the repo root:

```bash
make cloud-dev-up
make cloud-dev-smoke
make cloud-dev-connect
```

Then open:

```text
http://127.0.0.1:8000/docs
```

When you are done:

```bash
make cloud-dev-down
```

## Make Targets

Run `make help` to list everything. The main targets are:

- `make cloud-dev-template`
- `make cloud-dev-up`
- `make cloud-dev-smoke`
- `make cloud-dev-connect`
- `make cloud-dev-logs`
- `make cloud-dev-status`
- `make cloud-dev-down`

## Environment Variables

These are the main knobs:

- `LANGGRAPH_CLOUD_API_IMAGE`
  - Full image reference, for example `my-api:dev` or `localhost:5001/my-api:dev`
- `LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY`
- `LANGGRAPH_CLOUD_API_IMAGE_TAG`
  - Use these instead of `LANGGRAPH_CLOUD_API_IMAGE` if you prefer split values
- `KIND_CLUSTER_NAME`
  - Defaults to `langgraph-cloud-dev`
- `NAMESPACE`
  - Defaults to `langgraph-cloud-dev`
- `RELEASE_NAME`
  - Defaults to `langgraph-cloud-dev`
- `DEV_VALUES_FILE`
  - Defaults to `charts/langgraph-cloud/ci/dev-kind-values.yaml`
- `EXTRA_VALUES_FILE`
  - Optional extra values file layered on top of the dev defaults
- `KIND_LOAD_IMAGE`
  - `auto`, `always`, or `never`
- `INSTALL_MONGO_FIXTURE`
  - Defaults to `1`
- `PORT_FORWARD_PORT`
  - Defaults to `8000`
- `EXPECT_ENV_VARS`
  - Optional comma-separated list of env vars that must be present during `make cloud-dev-smoke`

## Typical Workflows

### Render the chart only

```bash
make cloud-dev-template
```

### Install the chart into kind

```bash
make cloud-dev-up
```

To test your own app image instead of the chart default:

```bash
export LANGGRAPH_CLOUD_API_IMAGE=your-image:dev
make cloud-dev-up
```

### Run a smoke test

```bash
make cloud-dev-smoke
```

This checks:

- the Helm release exists
- the API service can be port-forwarded
- `/ok` returns successfully
- `/docs` returns successfully
- the optional local Mongo fixture responds

### Manual testing

```bash
make cloud-dev-connect
```

That keeps a port-forward open so you can hit the API manually.

### Feature-branch overlays

If you are working on a chart feature and need extra values, layer them with `EXTRA_VALUES_FILE`.

Example:

```bash
export EXTRA_VALUES_FILE=charts/langgraph-cloud/ci/some-feature-values.yaml
make cloud-dev-up
make cloud-dev-smoke
```

If you also need to assert specific env vars from your chart change:

```bash
export EXPECT_ENV_VARS=LS_DEFAULT_CHECKPOINTER_BACKEND,LS_MONGODB_URI
make cloud-dev-smoke
```

## Diagnostics

If install fails, the install script automatically dumps Kubernetes diagnostics into:

```text
.tmp/langgraph-cloud-dev-debug/
```

You can also collect them manually:

```bash
make cloud-dev-logs
```

## Notes

- The default local values intentionally disable `studio` and `ingress` to keep the dev footprint small.
- `queue` is disabled by default in the local profile for a tighter feedback loop.
- The local Mongo fixture is there to support feature testing. The chart does not depend on it unless your overlay values do.
