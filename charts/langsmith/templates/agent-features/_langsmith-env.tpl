{{- define "langsmith.agentFeatures.imagesPatch" -}}
{{- $root := index . "root" }}
{{- $apiComponent := index . "component" }}
{{- $api := index $root.Values.images $apiComponent }}
{{- $pg := $root.Values.images.postgresImage }}
{{- $rd := $root.Values.images.redisImage }}
{{- $inner := dict
  "apiServerImage" (dict "repository" $api.repository "tag" ($api.tag | toString) "pullPolicy" $api.pullPolicy)
  "postgresImage" (dict "repository" $pg.repository "tag" ($pg.tag | toString) "pullPolicy" $pg.pullPolicy)
  "redisImage" (dict "repository" $rd.repository "tag" ($rd.tag | toString) "pullPolicy" $rd.pullPolicy)
  "registry" ($root.Values.images.registry | default "")
  "imagePullSecrets" ($root.Values.images.imagePullSecrets | default list)
}}
{{- dict "images" $inner | toYaml }}
{{- end -}}

{{- define "langsmith.agentFeatures.apiServerExtraEnv" -}}
{{- $root := required "agent-features: synthetic context missing .Root" .Root }}
{{- $out := list -}}
{{- $raw := "" -}}
{{- if $root.Values.config.hostname -}}
{{- $raw = include "langsmith.hostnameWithProtocol" $root | trimSuffix "/" -}}
{{- end -}}
{{- if $raw }}
{{- $out = concat $out (list
  (dict "name" "GO_ENDPOINT" "value" (printf "%s/api/v1" $raw))
  (dict "name" "LANGSMITH_AUTH_ENDPOINT" "value" (printf "%s/api/v1" $raw))
  (dict "name" "LANGCHAIN_ENDPOINT" "value" (printf "%s/api/v1" $raw))
) }}
{{- if eq .Chart.Name "lgp-fleet" }}
{{- $out = concat $out (list
  (dict "name" "SMITH_BACKEND_ENDPOINT" "value" $raw)
  (dict "name" "HOST_BACKEND_ENDPOINT" "value" (printf "%s/api-host" $raw))
  (dict "name" "MCP_SERVER_URL" "value" (printf "%s/mcp" $raw))
) }}
{{- end }}
{{- end }}
{{- if eq .Chart.Name "lgp-fleet" }}
{{- $out = concat $out (list (dict "name" "LANGSMITH_LICENSE_REQUIRED_CLAIMS" "value" "agent_builder_enabled")) }}
{{- end }}
{{- if or (eq .Chart.Name "lgp-insights") (eq .Chart.Name "lgp-polly") }}
{{- $out = concat $out (list (dict "name" "LLM_AUTH_PROXY_ACCEPT_HTTP" "value" "true")) }}
{{- end }}
{{- $secretName := include "langsmith.secretsName" $root }}
{{- if eq .Chart.Name "lgp-fleet" }}
{{- $out = concat $out (list
  (dict "name" "AGENT_BUILDER_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "agent_builder_encryption_key")))
  (dict "name" "X_SERVICE_AUTH_JWT_SECRET" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "jwt_secret" "optional" true)))
) }}
{{- end }}
{{- if eq .Chart.Name "lgp-insights" }}
{{- $out = concat $out (list
  (dict "name" "CLIO_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "insights_encryption_key")))
  (dict "name" "X_SERVICE_AUTH_JWT_SECRET" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "jwt_secret" "optional" true)))
) }}
{{- end }}
{{- if eq .Chart.Name "lgp-polly" }}
{{- $out = concat $out (list
  (dict "name" "POLLY_ENCRYPTION_KEY" "valueFrom" (dict "secretKeyRef" (dict "name" $secretName "key" "polly_encryption_key")))
) }}
{{- end }}
{{- $user := .Values.apiServer.deployment.extraEnv | default list }}
{{- $out = concat $out $user }}
{{- if gt (len $out) 0 }}
{{- toYaml $out }}
{{- end }}
{{- end -}}

{{- define "langsmith.agentFeatures.apiServerK8sServiceName" -}}
{{- $root := index . "root" }}
{{- $feature := index . "feature" }}
{{- $chartName := index . "chartName" }}
{{- $m := omit (index $root.Values.agentFeatures $feature) "enabled" "encryptionKey" }}
{{- $m := mergeOverwrite $m (dict "clusterDomain" $root.Values.clusterDomain "namespace" ($root.Values.namespace | default "")) }}
{{- $miniChart := dict "Name" $chartName "Version" $root.Chart.Version "AppVersion" $root.Chart.AppVersion }}
{{- $ctx := dict "Values" $m "Release" $root.Release "Chart" $miniChart }}
{{- printf "%s-%s" (include "langGraphCloud.fullname" $ctx) $m.apiServer.name }}
{{- end -}}

{{- define "langsmith.agentFeatures.agentPathPrefix" -}}
{{- $root := index . "root" }}
{{- $segment := index . "segment" }}
{{- $bp := trimAll "/" (default "" $root.Values.config.basePath) -}}
{{- if $bp -}}/{{ $bp }}/agents/{{ $segment }}{{- else -}}/agents/{{ $segment }}{{- end -}}
{{- end -}}

{{- define "langsmith.agentFeatures.defaultApiServerHttpPort" -}}
{{- $feat := index .Values.agentFeatures "fleet" -}}
{{- $feat.apiServer.service.httpPort -}}
{{- end -}}
