{{/*
Expand the name of the chart.
*/}}
{{- define "opentelemetry-collector.name" -}}
{{ .Values.collector.name }}
{{- end }}

{{- define "opentelemetry-collector.lowercase_chartname" -}}
{{- default .Chart.Name | lower }}
{{- end }}

{{/*
Build a list of database DNS names for enabled metrics collectors
*/}}
{{- define "opentelemetry-collector.database-dns-names" -}}
{{- $dnsNames := list -}}
{{- $namespace := .Values.observability.langsmith_namespace -}}

{{- if and .Values.collector.metrics.postgres.enabled .Values.collector.metrics.postgres.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.postgres.service $namespace (.Values.collector.metrics.postgres.port | int) .Values.collector.metrics.postgres.path) -}}
{{- end -}}

{{- if and .Values.collector.metrics.redis.enabled .Values.collector.metrics.redis.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.redis.service $namespace (.Values.collector.metrics.redis.port | int) .Values.collector.metrics.redis.path) -}}
{{- end -}}

{{- if and .Values.collector.metrics.clickhouse.enabled .Values.collector.metrics.clickhouse.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.clickhouse.service $namespace (.Values.collector.metrics.clickhouse.port | int) .Values.collector.metrics.clickhouse.path) -}}
{{- end -}}

{{- $dnsNames | toJson -}}
{{- end -}}

{{/*
Build a list of service DNS names for enabled metrics collectors
*/}}
{{- define "opentelemetry-collector.service-dns-names" -}}
{{- $dnsNames := list -}}
{{- $namespace := .Values.observability.langsmith_namespace -}}

{{- if and .Values.collector.metrics.langsmith.backend.enabled .Values.collector.metrics.langsmith.backend.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.langsmith.backend.service $namespace (.Values.collector.metrics.langsmith.backend.port | int) .Values.collector.metrics.langsmith.backend.path) -}}
{{- end -}}

{{- if and .Values.collector.metrics.langsmith.hostBackend.enabled .Values.collector.metrics.langsmith.hostBackend.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.langsmith.hostBackend.service $namespace (.Values.collector.metrics.langsmith.hostBackend.port | int) .Values.collector.metrics.langsmith.hostBackend.path) -}}
{{- end -}}

{{- if and .Values.collector.metrics.langsmith.platformBackend.enabled .Values.collector.metrics.langsmith.platformBackend.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.langsmith.platformBackend.service $namespace (.Values.collector.metrics.langsmith.platformBackend.port | int) .Values.collector.metrics.langsmith.platformBackend.path) -}}
{{- end -}}

{{- if and .Values.collector.metrics.langsmith.playground.enabled .Values.collector.metrics.langsmith.playground.service -}}
{{- $dnsNames = append $dnsNames (printf "%s.%s.svc.cluster.local:%d%s" .Values.collector.metrics.langsmith.playground.service $namespace (.Values.collector.metrics.langsmith.playground.port | int) .Values.collector.metrics.langsmith.playground.path) -}}
{{- end -}}

{{- $dnsNames | toJson -}}
{{- end -}}


