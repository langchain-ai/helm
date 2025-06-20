{{/* 
Check if any of the three services (redis, postgres, clickhouse) metrics are enabled
Usage: include "langsmith-observability.anyMetricsEnabled" .
*/}}
{{- define "langsmith-observability.databaseMetricsEnabled" -}}
{{- or .Values.otelCollector.metrics.redis.enabled .Values.otelCollector.metrics.postgres.enabled (default false .Values.otelCollector.metrics.clickhouse.enabled) -}}
{{- end -}}

{{/* 
Build a regex pattern for enabled services (redis, postgres, clickhouse)
Usage: include "langsmith-observability.enabledServicesRegex" .
*/}}
{{- define "langsmith-observability.enabledServicesRegex" -}}
{{- $services := list -}}
{{- if .Values.otelCollector.metrics.redis.enabled -}}
  {{- $serviceName := default (printf "%s-redis" .Values.langSmithReleaseName) .Values.otelCollector.metrics.redis.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if .Values.otelCollector.metrics.postgres.enabled -}}
  {{- $serviceName := default (printf "%s-postgres" .Values.langSmithReleaseName) .Values.otelCollector.metrics.postgres.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if .Values.otelCollector.metrics.clickhouse.enabled -}}
  {{- $serviceName := default (printf "%s-clickhouse" .Values.langSmithReleaseName) .Values.otelCollector.metrics.clickhouse.serviceName -}}
  {{- $services = append $services $serviceName -}}
{{- end -}}
{{- if $services -}}
({{ join "|" $services }})
{{- end -}}
{{- end -}}


