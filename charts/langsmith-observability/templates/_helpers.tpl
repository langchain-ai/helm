{{/* 
Check if any of the three services (redis, postgres, clickhouse) metrics are enabled
Usage: include "langsmith-observability.anyMetricsEnabled" .
*/}}
{{- define "langsmith-observability.databaseMetricsEnabled" -}}
{{- or .Values.opentelemetryCollector.metrics.redis.enabled .Values.opentelemetryCollector.metrics.postgres.enabled (default false .Values.opentelemetryCollector.metrics.clickhouse.enabled) -}}
{{- end -}}

{{/* 
Build a regex pattern for enabled services (redis, postgres, clickhouse)
Usage: include "langsmith-observability.enabledServicesRegex" .
*/}}
{{- define "langsmith-observability.enabledServicesRegex" -}}
{{- $services := list -}}
{{- if .Values.opentelemetryCollector.metrics.redis.enabled -}}
  {{- $serviceName := default (printf "%s-redis" .Values.langSmithReleaseName) .Values.opentelemetryCollector.metrics.redis.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if .Values.opentelemetryCollector.metrics.postgres.enabled -}}
  {{- $serviceName := default (printf "%s-postgres" .Values.langSmithReleaseName) .Values.opentelemetryCollector.metrics.postgres.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if .Values.opentelemetryCollector.metrics.clickhouse.enabled -}}
  {{- $serviceName := default (printf "%s-clickhouse" .Values.langSmithReleaseName) .Values.opentelemetryCollector.metrics.clickhouse.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if $services -}}
({{ join "|" $services }})
{{- end -}}
{{- end -}}


