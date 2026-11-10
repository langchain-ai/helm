{{/*
Sandbox clusters added to this install with sandboxes.clusters.

sandboxes.clusters is a map keyed by cluster name, so values files merge by key.
The reserved key `incluster` is this install's in-cluster sandbox runtime and takes
only `enabled` and `default`. Every other key is an added cluster, reached through
its own host ingress with its own service-auth key in config.existingSecretName.
*/}}

{{/*
"true" when this release runs the in-cluster sandbox runtime: sandboxes are on, no
external runtime is used, and sandboxes.clusters.incluster.enabled is not false.
*/}}
{{- define "langsmith.sandboxes.inclusterEnabled" -}}
{{- $incluster := (.Values.sandboxes.clusters | default dict).incluster | default dict -}}
{{- $on := true -}}
{{- if hasKey $incluster "enabled" -}}
{{- $on = $incluster.enabled -}}
{{- end -}}
{{- if and .Values.sandboxes.enabled (not .Values.sandboxes.external.enabled) $on -}}
true
{{- end -}}
{{- end -}}

{{/*
The added cluster names (every key except incluster), sorted, as a JSON array.
*/}}
{{- define "langsmith.sandboxes.addedClusterNames" -}}
{{- $names := list -}}
{{- range $name, $_ := (.Values.sandboxes.clusters | default dict) -}}
{{- if ne $name "incluster" -}}
{{- $names = append $names $name -}}
{{- end -}}
{{- end -}}
{{- sortAlpha $names | toJson -}}
{{- end -}}

{{/*
The env var holding an added cluster's service-auth secret: the name upper-cased,
with - turned into _. Cluster names are DNS labels, so the mapping is one-to-one.
*/}}
{{- define "langsmith.sandboxes.clusterSecretEnv" -}}
{{- printf "SANDBOX_CLUSTER_%s_SERVICE_AUTH_SECRET" (. | replace "-" "_" | upper) -}}
{{- end -}}

{{/*
Env for the pods that sign or verify sandbox host calls (platform-backend and
ingest-queue): SANDBOX_CLUSTERS, each added cluster's service-auth secret, and
SANDBOX_OWN_CLUSTER_ENABLED=false when incluster is disabled. Renders nothing
without sandboxes.clusters.
Args: root, previous (render the previous secrets, for the verifying pod).
*/}}
{{- define "langsmith.sandboxes.clustersEnv" -}}
{{- $root := .root -}}
{{- $clusters := $root.Values.sandboxes.clusters | default dict -}}
{{- $names := include "langsmith.sandboxes.addedClusterNames" $root | fromJsonArray -}}
{{- if $names }}
{{- $entries := list -}}
{{- range $name := $names -}}
{{- $cluster := index $clusters $name | default dict -}}
{{- $auth := $cluster.serviceAuth | default dict -}}
{{- $secretEnv := include "langsmith.sandboxes.clusterSecretEnv" $name -}}
{{- $previousEnv := "" -}}
{{- if $auth.previousSecretKey -}}
{{- $previousEnv = printf "%s_PREVIOUS" $secretEnv -}}
{{- end -}}
{{- /* Built by hand to keep the documented field order; toJson sorts keys. */ -}}
{{- $entries = append $entries (printf "{\"name\":%s,\"ingress\":{\"url\":%s},\"auth\":{\"secret_env\":%s,\"previous_env\":%s}%s}" ($name | toJson) ($cluster.hostIngressEndpoint | toJson) ($secretEnv | toJson) ($previousEnv | toJson) (ternary ",\"default\":true" "" (eq (toString $cluster.default) "true"))) -}}
{{- end }}
- name: SANDBOX_CLUSTERS
  value: {{ printf "[%s]" (join "," $entries) | quote }}
{{- range $name := $names }}
{{- $auth := (index $clusters $name | default dict).serviceAuth | default dict }}
{{- $secretEnv := include "langsmith.sandboxes.clusterSecretEnv" $name }}
- name: {{ $secretEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" $root }}
      key: {{ $auth.secretKey }}
      optional: false
{{- if and $.previous $auth.previousSecretKey }}
- name: {{ $secretEnv }}_PREVIOUS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" $root }}
      key: {{ $auth.previousSecretKey }}
      optional: false
{{- end }}
{{- end }}
{{- end }}
{{- $incluster := $clusters.incluster | default dict }}
{{- if and (hasKey $incluster "enabled") (not $incluster.enabled) }}
- name: SANDBOX_OWN_CLUSTER_ENABLED
  value: "false"
{{- end }}
{{- end -}}
