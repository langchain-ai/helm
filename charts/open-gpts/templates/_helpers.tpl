{{/*
Expand the name of the chart.
*/}}
{{- define "openGPTs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openGPTs.fullname" -}}
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
{{- define "openGPTs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openGPTs.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "openGPTs.chart" . }}
{{ include "openGPTs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "openGPTs.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "openGPTs.chart" . }}
{{ include "openGPTs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openGPTs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openGPTs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the secret containing the secrets for this chart. This can be overriden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "openGPTs.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "openGPTs.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for postgres. This can be overriden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "openGPTs.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "openGPTs.fullname" . }}-redis
{{- end }}
{{- end }}

{{- define "backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "openGPTs.fullname" .) .Values.backend.name) .Values.backend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.backend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "openGPTs.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}
