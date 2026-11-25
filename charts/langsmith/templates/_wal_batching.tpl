{{/*
WAL batching (opt-in). The /runs* write path is served by platformBackend; the queue workers that persist the
uploaded batches are ingestQueue. Nothing here renders unless platformBackend.walBatching.enabled (or, for the
worker env only, ingestQueue.walWorker.enabled) is true.
*/}}

{{- define "langsmith.walBatching.enabled" -}}
{{- if .Values.platformBackend.walBatching.enabled -}}true{{- end -}}
{{- end -}}

{{/* Whether the WAL volume is the chart's default emptyDir (no override). */}}
{{- define "langsmith.walBatching.usesEmptyDir" -}}
{{- if and .Values.platformBackend.walBatching.enabled (empty .Values.platformBackend.walBatching.volume.override) -}}true{{- end -}}
{{- end -}}

{{/* emptyDir sizeLimit in Gi: WAL_MAX_DISK_GB plus a buffer, so the app backs off before the kubelet evicts. */}}
{{- define "langsmith.walBatching.sizeLimitGi" -}}
{{- add (int .Values.platformBackend.walBatching.maxDiskGB) (int .Values.platformBackend.walBatching.volume.sizeLimitBufferGB) -}}
{{- end -}}

{{/* Env vars for the platform backend (the WAL writer). */}}
{{- define "langsmith.walBatching.env" -}}
{{- $w := .Values.platformBackend.walBatching -}}
- name: FF_WAL_BATCHING_ENABLED
  value: "true"
- name: FF_WAL_BATCHING_ENABLED_TENANTS
  value: {{ toJson $w.enabledTenants | quote }}
- name: FF_WAL_BATCHING_DISABLED_TENANTS
  value: {{ toJson $w.disabledTenants | quote }}
- name: WAL_BACKEND
  value: {{ $w.backend | quote }}
- name: WAL_DIR
  value: {{ $w.dir | quote }}
- name: WAL_MAX_DISK_GB
  value: {{ $w.maxDiskGB | int | quote }}
- name: WAL_MAX_BATCH_MB
  value: {{ $w.maxBatchMB | int | quote }}
- name: WAL_MAX_BATCH_AGE_SEC
  value: {{ $w.maxBatchAgeSec | int | quote }}
{{- if not (kindIs "invalid" $w.fsyncIntervalMs) }}
- name: WAL_FSYNC_INTERVAL_MS
  value: {{ $w.fsyncIntervalMs | int | quote }}
{{- end }}
{{- if $w.multiTenant.enabled }}
- name: FF_WAL_MULTI_TENANT_ENABLED
  value: "true"
- name: WAL_TMP_BATCH_PREFIX
  value: {{ $w.multiTenant.tmpBatchPrefix | quote }}
{{- if not (kindIs "invalid" $w.multiTenant.groupMB) }}
- name: WAL_GROUP_MB
  value: {{ $w.multiTenant.groupMB | int | quote }}
{{- end }}
{{- with $w.zone }}
- name: WAL_ZONE
  value: {{ . | quote }}
{{- end }}
{{- with $w.zonalBucket }}
- name: WAL_ZONAL_BUCKET
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Env vars for the ingest queue workers (persist_s3_batch / plan_s3_batch). */}}
{{- define "langsmith.walBatching.workerEnv" -}}
{{- $w := .Values.ingestQueue.walWorker -}}
- name: WAL_WORKER_MEMORY_MB
  value: {{ $w.memoryMB | int | quote }}
- name: WAL_WORKER_DECODE_CONCURRENCY
  value: {{ $w.decodeConcurrency | int | quote }}
{{- if $w.multiTenantEnabled }}
- name: FF_WAL_MULTI_TENANT_ENABLED
  value: "true"
- name: WAL_TMP_BATCH_PREFIX
  value: {{ $w.tmpBatchPrefix | quote }}
{{- if not (kindIs "invalid" $w.groupMB) }}
- name: WAL_GROUP_MB
  value: {{ $w.groupMB | int | quote }}
{{- end }}
{{- with $w.zone }}
- name: WAL_ZONE
  value: {{ . | quote }}
{{- end }}
{{- if $w.zoneWorkerOnly }}
- name: WAL_ZONE_WORKER_ONLY
  value: "true"
{{- end }}
{{- with $w.zonalBucket }}
- name: WAL_ZONAL_BUCKET
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/* WAL volume for the platform backend pod. */}}
{{- define "langsmith.walBatching.volumes" -}}
- name: smith-wal
{{- if empty .Values.platformBackend.walBatching.volume.override }}
  emptyDir:
    sizeLimit: {{ include "langsmith.walBatching.sizeLimitGi" . }}Gi
{{- else }}
  {{- toYaml .Values.platformBackend.walBatching.volume.override | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "langsmith.walBatching.volumeMounts" -}}
- name: smith-wal
  mountPath: {{ .Values.platformBackend.walBatching.dir | quote }}
{{- end -}}

{{/*
Platform backend resources. With the default emptyDir WAL, merges an ephemeral-storage request (emptyDir limit plus
logs) into the configured resources unless the operator already set one.
*/}}
{{- define "langsmith.walBatching.resources" -}}
{{- $r := deepCopy (default (dict) .Values.platformBackend.deployment.resources) -}}
{{- if eq (include "langsmith.walBatching.usesEmptyDir" .) "true" -}}
{{- $requests := default (dict) $r.requests -}}
{{- if not (hasKey $requests "ephemeral-storage") -}}
{{- $_ := set $requests "ephemeral-storage" (printf "%dGi" (add (int (include "langsmith.walBatching.sizeLimitGi" . )) (int .Values.platformBackend.walBatching.volume.logsBufferGB))) -}}
{{- $_ := set $r "requests" $requests -}}
{{- end -}}
{{- end -}}
{{- toYaml $r -}}
{{- end -}}

{{/* Never lower the grace period when the WAL is on: it drains on SIGTERM. */}}
{{- define "langsmith.walBatching.terminationGracePeriodSeconds" -}}
{{- $base := int .Values.platformBackend.deployment.terminationGracePeriodSeconds -}}
{{- if .Values.platformBackend.walBatching.enabled -}}
{{- max $base (int .Values.platformBackend.walBatching.terminationGracePeriodSeconds) -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}
