{{/*
Expand the name of the chart.
*/}}
{{- define "langgraphDataplane.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "langgraphDataplane.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "langgraphDataplane.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langgraphDataplane.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langgraphDataplane.chart" . }}
{{ include "langgraphDataplane.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "langgraphDataplane.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "langgraphDataplane.chart" . }}
{{ include "langgraphDataplane.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langgraphDataplane.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langgraphDataplane.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the secret containing the secrets for this chart. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langgraphDataplane.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "langgraphDataplane.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for redis. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langgraphDataplane.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "langgraphDataplane.fullname" . }}-redis
{{- end }}
{{- end }}


{{/*
Template containing common environment variables that are used by several services.
*/}}
{{- define "langgraphDataplane.commonEnv" -}}
- name: LANGCHAIN_ENV
  value: "local_kubernetes"
- name: REDIS_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langgraphDataplane.redisSecretsName" . }}
      key: {{ .Values.redis.external.connectionUrlSecretKey }}
- name: HOST_WORKER_LANGSMITH_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langgraphDataplane.secretsName" . }}
      key: langsmith_api_key
- name: HOST_QUEUE
  value: "host"
- name: HOST_WORKER_RECONCILIATION_CRON_ENABLED
  value: "true"
- name: HOST_WORKER_EXTERNAL_ENABLED
  value: "true"
- name: HOST_BACKEND_ENDPOINT
  value: {{ .Values.config.hostBackendUrl }}
- name: HOST_LANGCHAIN_API_ENDPOINT
  value: {{ .Values.config.smithBackendUrl }}
- name: HOST_WORKER_TENANT_ID
  value: {{ .Values.config.langsmithWorkspaceId }}
- name: HOST_WORKER_LISTENER_ID
  value: {{ .Values.config.langgraphListenerId }}
- name: HOSTED_K8S_ROOT_DOMAIN
  value: {{ .Values.config.rootDomain | quote }}
- name: HOSTED_K8S_SHARED_INGRESS
  value: "true"
- name: LOG_LEVEL
  value: "INFO"
- name: ENABLE_LGP_DEPLOYMENT_HEALTH_CHECK
  value: {{ .Values.listener.enableLGPDeploymentHealthCheck | quote }}
{{- end }}


{{- define "listener.serviceAccountName" -}}
{{- if .Values.listener.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langgraphDataplane.fullname" .) .Values.listener.name) .Values.listener.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.listener.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "operator.serviceAccountName" -}}
{{- if .Values.operator.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langgraphDataplane.fullname" .) .Values.operator.name) .Values.operator.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.operator.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langgraphDataplane.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* Fail on duplicate keys in the inputted list of environment variables */}}
{{- define "langgraphDataplane.detectDuplicates" -}}
{{- $inputList := . -}}
{{- $keyCounts := dict -}}
{{- $duplicates := list -}}

{{- range $i, $val := $inputList }}
  {{- $key := $val.name -}}
  {{- if hasKey $keyCounts $key }}
    {{- $_ := set $keyCounts $key (add (get $keyCounts $key) 1) -}}
  {{- else }}
    {{- $_ := set $keyCounts $key 1 -}}
  {{- end }}
  {{- if gt (get $keyCounts $key) 1 }}
    {{- $duplicates = append $duplicates $key -}}
  {{- end }}
{{- end }}

{{- if gt (len $duplicates) 0 }}
  {{ fail (printf "Duplicate keys detected: %v" $duplicates) }}
{{- end }}
{{- end -}}


{{/*
Creates the image reference used for LangGraph DataPlane deployments. If registry is specified, concatenate it, along with a '/'.
*/}}
{{- define "langgraphDataplane.image" -}}
{{- $imageConfig := index .Values.images .component -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}
