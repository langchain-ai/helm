# LangGraph Cloud Local Development

We've set up local testing with `kind`.

The goal is to make it easy to:

- render chart changes locally
- install the chart into an isolated disposable cluster
- run a basic smoke test against the API
- collect diagnostics when something fails

## Safety Model

The scripts are intentionally scoped to `kind` clusters only and refuse to run against other kube contexts.

## Prerequisites

You need:

- `docker`
- `kind`
- `kubectl`
- `helm`

You must provide an API image for `make cloud-dev-up`.

Set either:

- `LANGGRAPH_CLOUD_API_IMAGE`
- `LANGGRAPH_CLOUD_API_IMAGE_REPOSITORY` and `LANGGRAPH_CLOUD_API_IMAGE_TAG`

This is intentional. The local install flow should never silently fall back to the chart's default API image, because that makes it unclear what app you are actually testing.

## Build an Agent Server Image First

The normal local workflow is:

1. Create a small LangGraph app
2. Build an agent server image for it
3. Point `make cloud-dev-up` at that image

Example:

```bash
uv run langgraph new my_template
cd my_template
uv run langgraph build -t foo
cd ..
LANGGRAPH_CLOUD_API_IMAGE=docker.io/library/foo:latest make cloud-dev-up
```

If you already have an app and just need to rebuild the image:

```bash
cd path/to/your/app
uv run langgraph build -t foo
cd -
LANGGRAPH_CLOUD_API_IMAGE=docker.io/library/foo:latest make cloud-dev-up
```

Use the exact image reference you expect Docker and `kind` to see. If in doubt, check `docker image ls` or `docker image inspect`.

## Quickstart

From the repo root:

```bash
uv run langgraph new my_template
cd my_template
uv run langgraph build -t foo
cd ..
export LANGGRAPH_CLOUD_API_IMAGE=docker.io/library/foo:latest
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
  - Use `NAME=value` to assert an exact value, for example `LS_DEFAULT_CHECKPOINTER_BACKEND=mongo`
  - Entries must be valid shell variable names, for example `FOO` or `MY_APP_TOKEN`
- `SMOKE_THREAD_ID`
  - Defaults to `2cfc6f4f-c711-4a71-b193-5d89a681a813`
- `SMOKE_ASSISTANT_ID`
  - Defaults to `agent`
- `SMOKE_MESSAGE`
  - Defaults to `Hi there`
- `SMOKE_STREAM_TIMEOUT_SECONDS`
  - Defaults to `30`
- `SMOKE_SKIP_APP_RUN`
  - Set to `1` to skip the app-level run request during `make cloud-dev-smoke`
- `SMOKE_API_KEY`
  - Optional `X-Api-Key` header for apps that require API-key auth during the app-level smoke request
- `SMOKE_AUTH_TOKEN`
  - Optional bearer token for apps that require `Authorization: Bearer ...` during the app-level smoke request

## Typical Workflows

### Render the chart only

```bash
make cloud-dev-template
```

### Install the chart into kind

```bash
export LANGGRAPH_CLOUD_API_IMAGE=docker.io/library/foo:latest
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
- `POST /threads/<thread_id>/runs/stream` succeeds against the deployed app
- the optional local Mongo fixture becomes a writable single-node replica set

By default, the app-level smoke request assumes the starter app created by `uv run langgraph new ...` and sends:

```json
{"input":{"messages":[{"role":"user","content":"Hi there"}]},"assistant_id":"agent","if_not_exists":"create"}
```

to:

```text
/threads/2cfc6f4f-c711-4a71-b193-5d89a681a813/runs/stream
```

If your app uses a different assistant ID or you want a different prompt, override the defaults:

```bash
export SMOKE_ASSISTANT_ID=my-assistant
export SMOKE_MESSAGE="Hello from kind"
make cloud-dev-smoke
```

If your app requires auth, pass the needed header values into the smoke request:

```bash
export SMOKE_API_KEY=local-dev-key
make cloud-dev-smoke
```

or:

```bash
export SMOKE_AUTH_TOKEN=your-token
make cloud-dev-smoke
```

If you only want the infrastructure checks and need to skip the app-level run:

```bash
export SMOKE_SKIP_APP_RUN=1
make cloud-dev-smoke
```

### Manual testing

```bash
make cloud-dev-connect
```

That keeps a port-forward open so you can hit the API manually.

### Feature-branch overlays

If you are working on a chart feature and need extra values, layer them with `EXTRA_VALUES_FILE`.

Example:

```bash
cd path/to/your/app
uv run langgraph build -t foo
cd -
export LANGGRAPH_CLOUD_API_IMAGE=docker.io/library/foo:latest
export EXTRA_VALUES_FILE=charts/langgraph-cloud/ci/some-feature-values.yaml
make cloud-dev-up
make cloud-dev-smoke
```

If you also need to assert specific env vars from your chart change:

```bash
export EXPECT_ENV_VARS=LS_DEFAULT_CHECKPOINTER_BACKEND,LS_MONGODB_URI
make cloud-dev-smoke
```

If your app does not expose an assistant named `agent`, override the default app-level smoke request:

```bash
export SMOKE_ASSISTANT_ID=my-assistant
make cloud-dev-smoke
```

### Local Mongo checkpointer

The Mongo checkpointer expects a Mongo replica set member or `mongos`. A standalone `mongod` is not enough for transactional checkpoint writes.

To exercise the Mongo default checkpointer against the local fixture installed by `make cloud-dev-up`:

```bash
export EXTRA_VALUES_FILE=charts/langgraph-cloud/ci/dev-kind-mongo-checkpointer-values.yaml
export EXPECT_ENV_VARS=LS_DEFAULT_CHECKPOINTER_BACKEND=mongo,LS_MONGODB_URI
make cloud-dev-up
make cloud-dev-smoke
```

The checked-in `charts/langgraph-cloud/ci/mongo-checkpointer-values.yaml` file is still useful as a generic non-local example, but it points at `mongo.example.net` and is not intended for the disposable kind workflow.

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
- The local Mongo fixture is there to support feature testing. It runs as a single-node replica set because the Mongo checkpointer requires replica set semantics. The chart does not depend on it unless your overlay values do.
