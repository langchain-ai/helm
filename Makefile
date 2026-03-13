SHELL := /usr/bin/env bash

KIND_CLUSTER_NAME ?= langgraph-cloud-dev
KUBE_CONTEXT ?= kind-$(KIND_CLUSTER_NAME)
NAMESPACE ?= langgraph-cloud-dev
RELEASE_NAME ?= langgraph-cloud-dev
CHART_DIR ?= charts/langgraph-cloud
DEV_VALUES_FILE ?= charts/langgraph-cloud/ci/dev-kind-values.yaml
MONGO_FIXTURE_FILE ?= hack/fixtures/mongo.yaml
PORT_FORWARD_PORT ?= 8000

export KIND_CLUSTER_NAME
export KUBE_CONTEXT
export NAMESPACE
export RELEASE_NAME
export CHART_DIR
export DEV_VALUES_FILE
export MONGO_FIXTURE_FILE
export PORT_FORWARD_PORT

.PHONY: help cloud-dev-check cloud-dev-template cloud-dev-up cloud-dev-smoke cloud-dev-connect cloud-dev-logs cloud-dev-status cloud-dev-down

help: ## Show available local development targets
	@awk 'BEGIN {FS = ": ## "}; /^[a-zA-Z0-9_.-]+: ## / {printf "%-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

cloud-dev-check: ## Validate local prerequisites and confirm the target context is a kind cluster
	@./hack/ensure-safe-kube-context.sh

cloud-dev-template: ## Render the langgraph-cloud chart with the checked-in local dev values
	@args=(-f "$(DEV_VALUES_FILE)"); \
	if [[ -n "$${EXTRA_VALUES_FILE:-}" ]]; then \
		args+=(-f "$${EXTRA_VALUES_FILE}"); \
	fi; \
	helm template "$(RELEASE_NAME)" "$(CHART_DIR)" --namespace "$(NAMESPACE)" "$${args[@]}"

cloud-dev-up: ## Create/reuse a kind cluster and install langgraph-cloud into a local namespace
	@./hack/kind-create.sh
	@./hack/install-langgraph-cloud.sh

cloud-dev-smoke: ## Port-forward the API service and run a basic local smoke test
	@./hack/smoke-langgraph-cloud.sh

cloud-dev-connect: ## Port-forward the API service for manual local testing
	@./hack/port-forward-langgraph-cloud.sh

cloud-dev-logs: ## Dump Kubernetes diagnostics for the local langgraph-cloud install
	@./hack/dump-k8s-debug.sh

cloud-dev-status: ## Show namespace resources in the local kind cluster
	@kubectl --context "$(KUBE_CONTEXT)" -n "$(NAMESPACE)" get pods,svc,deploy,statefulset,pvc

cloud-dev-down: ## Delete the local kind cluster
	@./hack/kind-delete.sh
