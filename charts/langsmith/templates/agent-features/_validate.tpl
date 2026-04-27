{{- define "langsmith.agentFeatures.validate" -}}
{{- $root := . }}
{{- $urls := list }}
{{- $pairs := list (dict "n" "fleet" "c" "lgp-fleet") (dict "n" "insights" "c" "lgp-insights") (dict "n" "polly" "c" "lgp-polly") }}
{{- range $pair := $pairs }}
{{- $fn := index $pair "n" }}
{{- $feat := index $root.Values.agentFeatures $fn }}
{{- if $feat.enabled }}
{{- if not $feat.encryptionKey }}
{{- fail (printf "agentFeatures.%s.encryptionKey is required when agentFeatures.%s.enabled is true" $fn $fn) }}
{{- end }}
{{- if $feat.postgres.external.enabled }}
{{- $pg := "" }}
{{- if $feat.postgres.external.connectionUrl }}
{{- $pg = trimAll " " $feat.postgres.external.connectionUrl }}
{{- else }}
{{- $pg = printf "postgres://%s:%s@%s:%s/%s?sslmode=disable" $feat.postgres.external.user $feat.postgres.external.password $feat.postgres.external.host (toString $feat.postgres.external.port) $feat.postgres.external.database }}
{{- end }}
{{- if $pg }}
{{- $urls = append $urls $pg }}
{{- end }}
{{- end }}
{{- if $feat.redis.external.enabled }}
{{- if not $feat.redis.external.connectionUrl }}
{{- fail (printf "agentFeatures.%s: redis.external.connectionUrl is required when redis.external.enabled is true" $fn) }}
{{- end }}
{{- $rurl := trimAll " " $feat.redis.external.connectionUrl }}
{{- if $rurl }}
{{- $urls = append $urls $rurl }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if and (gt (len $urls) 0) (ne (len $urls) (len (uniq $urls))) }}
{{- fail "agentFeatures: each enabled stack must use distinct external postgres/redis connection URLs; duplicate URLs were detected across fleet/insights/polly." }}
{{- end }}
{{- end -}}
