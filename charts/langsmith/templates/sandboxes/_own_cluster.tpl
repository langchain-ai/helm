{{/*
This install's own sandbox cluster, the one the in-cluster sandbox runtime serves.

Other sandbox clusters are not configured here. They are registered through the
instance admin API, each with its own service-auth secret.
*/}}

{{/*
"true" when this release runs the in-cluster sandbox runtime: sandboxes are on, no
external runtime is used, and sandboxes.ownCluster.enabled is not false.
*/}}
{{- define "langsmith.sandboxes.ownClusterEnabled" -}}
{{- $own := .Values.sandboxes.ownCluster | default dict -}}
{{- $on := true -}}
{{- if hasKey $own "enabled" -}}
{{- $on = $own.enabled -}}
{{- end -}}
{{- if and .Values.sandboxes.enabled (not .Values.sandboxes.external.enabled) $on -}}
true
{{- end -}}
{{- end -}}

{{/*
Env for the pods that sign or verify sandbox host calls (platform-backend and
ingest-queue): SANDBOX_OWN_CLUSTER_ENABLED=false when sandboxes.ownCluster.enabled
is false, so the control plane knows this install has no own-name cluster. Renders
nothing otherwise.
*/}}
{{- define "langsmith.sandboxes.ownClusterEnv" -}}
{{- $own := .Values.sandboxes.ownCluster | default dict -}}
{{- if and (hasKey $own "enabled") (not $own.enabled) }}
- name: SANDBOX_OWN_CLUSTER_ENABLED
  value: "false"
{{- end }}
{{- end -}}
