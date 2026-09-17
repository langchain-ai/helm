{{/*
Expand the name of the chart.
*/}}
{{- define "connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "connector.fullname" -}}
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
{{- define "connector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "connector.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "connector.chart" . }}
{{ include "connector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "connector.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "connector.chart" . }}
{{ include "connector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common pod annotations
*/}}
{{- define "connector.commonPodAnnotations" -}}
{{- if .Values.commonPodAnnotations }}
{{ toYaml .Values.commonPodAnnotations }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "connector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "connector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Template for merging commonPodSecurityContext with component-specific podSecurityContext.
Component-specific values take precedence over common values.
*/}}
{{- define "connector.podSecurityContext" -}}
{{- $merged := merge (deepCopy (.componentSecurityContext | default dict)) (.Values.commonPodSecurityContext | default dict) -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Creates the image reference used for deployments. If registry is specified, concatenate it, along with a '/'.
*/}}
{{- define "connector.image" -}}
{{- $imageConfig := index .Values.images .component -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}

{{/*
Common DNS configuration for all pods. When commonDnsConfig is set, it will be applied to all pods.
*/}}
{{- define "connector.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
{{- end }}
{{- end }}

{{- define "connector.serviceAccountName" -}}
{{- if .Values.connector.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "connector.fullname" .) .Values.connector.name) .Values.connector.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.connector.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Name of the secret containing the LangSmith API key. This can be overridden by a secret created by
the user or some other secret provisioning mechanism.
*/}}
{{- define "connector.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "connector.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
LANGSMITH_CONNECTOR_TARGETS: "name=address" pairs joined by commas, in sorted name order.
*/}}
{{- define "connector.targetsEnv" -}}
{{- $pairs := list -}}
{{- range $name, $address := .Values.config.targets -}}
{{- $pairs = append $pairs (printf "%s=%s" $name $address) -}}
{{- end -}}
{{- join "," $pairs -}}
{{- end -}}
