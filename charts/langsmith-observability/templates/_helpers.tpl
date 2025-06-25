
{{/*
Expand the name of the chart.
*/}}
{{- define "langsmith-observability.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "langsmith-observability.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langsmith-observability.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langsmith-observability.chart" . }}
{{ include "langsmith-observability.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langsmith-observability.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langsmith-observability.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* 
Mimir Resource Name
*/}}
{{ define "langsmith-mimir.name" -}}
{{- printf "%s-%s" .Release.Name "mimir" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
OTEL Gatway Collector Resource Name
*/}}
{{ define "langsmith-gateway-collector.name" -}}
{{- if .Values.otelCollector.gatewayNameOverride -}}
{{- .Values.otelCollector.gatewayNameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "langsmith-observability.name" .) "collector-gateway" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
OTEL Sidecar Collector Resource Name
*/}}
{{ define "langsmith-sidecar-collector.name" -}}
{{- if .Values.otelCollector.sidecarNameOverride -}}
{{- .Values.otelCollector.sidecarNameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "langsmith-observability.name" .) "collector-sidecar" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}