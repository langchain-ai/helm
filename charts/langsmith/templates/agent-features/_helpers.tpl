{{/*
Fullname prefix for a given agent feature product.
Usage: include "langsmith.agentFeatures.fullname" (dict "root" . "product" "fleet")
Produces: <release>-<namePrefix>  e.g. "langsmith-standalone-fleet"
*/}}
{{- define "langsmith.agentFeatures.fullname" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $prefix := (index $root.Values $product).namePrefix }}
{{- printf "%s-%s" (include "langsmith.fullname" $root) $prefix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Postgres secret name for a given product.
Usage: include "langsmith.agentFeatures.postgresSecretName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.postgresSecretName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $pg := (index $root.Values $product).postgres }}
{{- if $pg.external.existingSecretName }}
{{- $pg.external.existingSecretName }}
{{- else }}
{{- include "langsmith.agentFeatures.fullname" . }}-postgres
{{- end }}
{{- end -}}

{{/*
Redis secret name for a given product.
Usage: include "langsmith.agentFeatures.redisSecretName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.redisSecretName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $redis := (index $root.Values $product).redis }}
{{- if $redis.external.existingSecretName }}
{{- $redis.external.existingSecretName }}
{{- else }}
{{- include "langsmith.agentFeatures.fullname" . }}-redis
{{- end }}
{{- end -}}

{{/*
FQDN for an agent feature's api-server Service (used by frontend nginx proxy_pass).
Usage: include "langsmith.agentFeatures.apiServerK8sServiceName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.apiServerK8sServiceName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $feat := index $root.Values $product }}
{{- printf "%s-%s" (include "langsmith.agentFeatures.fullname" .) $feat.apiServer.name }}
{{- end -}}

{{/*
URL path prefix for agent feature routes (handles basePath).
*/}}
{{- define "langsmith.agentFeatures.agentPathPrefix" -}}
{{- $root := index . "root" }}
{{- $segment := index . "segment" }}
{{- $bp := trimAll "/" (default "" $root.Values.config.basePath) -}}
{{- if $bp -}}/{{ $bp }}/agents/{{ $segment }}{{- else -}}/agents/{{ $segment }}{{- end -}}
{{- end -}}

{{/*
Extra env vars for fleet api-server and queue pods.
*/}}
{{- define "langsmith.fleet.extraEnv" -}}
{{- $ns := .Values.namespace | default .Release.Namespace -}}
{{- $cd := .Values.clusterDomain -}}
{{- $frontend := printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" .) .Values.frontend.name $ns $cd .Values.frontend.service.httpPort -}}
{{- $toolServer := printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" .) .Values.agentBuilderToolServer.name $ns $cd .Values.agentBuilderToolServer.service.port -}}
{{- $out := list
  (dict "name" "GO_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGSMITH_AUTH_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGCHAIN_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "SMITH_BACKEND_ENDPOINT" "value" $frontend)
  (dict "name" "HOST_BACKEND_ENDPOINT" "value" (printf "%s/api-host" $frontend))
  (dict "name" "MCP_SERVER_URL" "value" $toolServer)
  (dict "name" "LANGSMITH_LICENSE_REQUIRED_CLAIMS" "value" "agent_builder_enabled")
-}}
{{- if .Values.fleet.enableTracing }}
{{- $out = append $out (dict "name" "TENANT_AWARE_TRACING_ENABLED" "value" "true") }}
{{- end }}
{{- $secretName := include "langsmith.secretsName" . }}
{{- $out = concat $out (list
  (dict "name" "AGENT_BUILDER_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "agent_builder_encryption_key")))
  (dict "name" "X_SERVICE_AUTH_JWT_SECRET" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "jwt_secret" "optional" true)))
) }}
{{- toYaml $out }}
{{- end -}}

{{/*
Extra env vars for insights api-server and queue pods.
*/}}
{{- define "langsmith.insights.extraEnv" -}}
{{- $ns := .Values.namespace | default .Release.Namespace -}}
{{- $cd := .Values.clusterDomain -}}
{{- $frontend := printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" .) .Values.frontend.name $ns $cd .Values.frontend.service.httpPort -}}
{{- $out := list
  (dict "name" "GO_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGSMITH_AUTH_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGCHAIN_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LLM_AUTH_PROXY_ACCEPT_HTTP" "value" "true")
  (dict "name" "LANGSMITH_TRACING" "value" "false")
-}}
{{- $secretName := include "langsmith.secretsName" . }}
{{- $out = concat $out (list
  (dict "name" "CLIO_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "insights_encryption_key")))
  (dict "name" "X_SERVICE_AUTH_JWT_SECRET" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "jwt_secret" "optional" true)))
) }}
{{- toYaml $out }}
{{- end -}}

{{/*
Extra env vars for polly api-server and queue pods.
*/}}
{{- define "langsmith.polly.extraEnv" -}}
{{- $ns := .Values.namespace | default .Release.Namespace -}}
{{- $cd := .Values.clusterDomain -}}
{{- $frontend := printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" .) .Values.frontend.name $ns $cd .Values.frontend.service.httpPort -}}
{{- $out := list
  (dict "name" "GO_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGSMITH_AUTH_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LANGCHAIN_ENDPOINT" "value" (printf "%s/api/v1" $frontend))
  (dict "name" "LLM_AUTH_PROXY_ACCEPT_HTTP" "value" "true")
  (dict "name" "LANGSMITH_TRACING" "value" (ternary "false" "true" .Values.polly.enableTracing))
-}}
{{- $secretName := include "langsmith.secretsName" . }}
{{- $out = concat $out (list
  (dict "name" "POLLY_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "polly_encryption_key")))
) }}
{{- toYaml $out }}
{{- end -}}
