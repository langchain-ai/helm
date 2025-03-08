{{/*
Expand the name of the chart.
*/}}
{{- define "langgraph-dataplane.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "langgraph-dataplane.fullname" -}}
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
{{- define "langgraph-dataplane.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langgraph-dataplane.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langgraph-dataplane.chart" . }}
{{ include "langgraph-dataplane.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "langgraph-dataplane.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "langgraph-dataplane.chart" . }}
{{ include "langgraph-dataplane.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langgraph-dataplane.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langgraph-dataplane.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the secret containing the secrets for this chart. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langgraph-dataplane.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "langgraph-dataplane.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for redis. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langgraph-dataplane.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "langgraph-dataplane.fullname" . }}-redis
{{- end }}
{{- end }}


{{/*
Template containing common environment variables that are used by several services.
*/}}
{{- define "langgraph-dataplane.commonEnv" -}}
- name: LANGCHAIN_ENV
  value: "local_kubernetes"
- name: REDIS_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langgraph-dataplane.redisSecretsName" . }}
      key: {{ .Values.redis.external.connectionUrlSecretKey }}
- name: LANGGRAPH_CLOUD_LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langgraph-dataplane.secretsName" . }}
      key: langgraph_cloud_license_key
- name: HOST_WORKER_LANGSMITH_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langgraph-dataplane.secretsName" . }}
      key: langsmith_api_key
- name: HOST_QUEUE
  value: "host"
- name: HOST_WORKER_RECONCILIATION_CRON_ENABLED
  value: "true"
- name: HOST_WORKER_EXTERNAL_ENABLED
  value: "true"
- name: HOST_BACKEND_ENDPOINT
  value: {{ .Values.config.hostBackendUrl }}
- name: HOST_WORKER_TENANT_ID
  value: {{ .Values.config.langsmithWorkspaceId }}
{{- end }}


{{- define "listener.serviceAccountName" -}}
{{- if .Values.listener.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langgraph-dataplane.fullname" .) .Values.listener.name) .Values.listener.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.listener.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langgraph-dataplane.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* Fail on duplicate keys in the inputted list of environment variables */}}
{{- define "langgraph-dataplane.detectDuplicates" -}}
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
