{{/* Define the chart name */}}
{{- define "langsmith-mission-control.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{/* Define the full name (used in Deployments, Services, etc.) */}}
{{- define "langsmith-mission-control.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" (include "langsmith-mission-control.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}
