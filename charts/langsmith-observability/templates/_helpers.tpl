{{/*
Expand the name of the chart.
*/}}
{{- define "langsmith-observability.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "langsmith-observability.lowercase_chartname" -}}
{{- default .Chart.Name | lower }}
{{- end }}