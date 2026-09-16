{{/*
Expand the name of the chart.
*/}}
{{- define "connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name, truncated to 63 characters.
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
Chart name and version as used by the chart label.
*/}}
{{- define "connector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "connector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "connector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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
Merge commonPodSecurityContext with the connector podSecurityContext; connector values win.
*/}}
{{- define "connector.podSecurityContext" -}}
{{- $merged := merge (deepCopy (.Values.connector.podSecurityContext | default dict)) (.Values.commonPodSecurityContext | default dict) -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Image reference. If images.registry is set it is prepended with a '/'.
*/}}
{{- define "connector.image" -}}
{{- $imageConfig := .Values.images.connectorImage -}}
{{- $tag := $imageConfig.tag | default .Chart.AppVersion -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $tag }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $tag }}
{{- end -}}
{{- end -}}

{{/*
DNS configuration for all pods when commonDnsConfig is set.
*/}}
{{- define "connector.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
{{- end }}
{{- end }}

{{- define "connector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "connector.fullname" .) .Values.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Secret that holds the LangSmith API key: the operator's existing Secret, or the chart-managed one.
*/}}
{{- define "connector.secretName" -}}
{{- if .Values.connector.existingSecret -}}
{{ .Values.connector.existingSecret }}
{{- else -}}
{{ include "connector.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Key inside that Secret. The chart-managed Secret always uses "api-key".
*/}}
{{- define "connector.secretKey" -}}
{{- if .Values.connector.existingSecret -}}
{{ .Values.connector.existingSecretKey }}
{{- else -}}
api-key
{{- end -}}
{{- end -}}

{{/*
LANGSMITH_CONNECTOR_TARGETS: "name=address" pairs joined by commas, in sorted name order.
*/}}
{{- define "connector.targetsEnv" -}}
{{- $pairs := list -}}
{{- range $name, $address := .Values.connector.targets -}}
{{- $pairs = append $pairs (printf "%s=%s" $name $address) -}}
{{- end -}}
{{- join "," $pairs -}}
{{- end -}}
