{{/*
Expand the name of the chart.
*/}}
{{- define "langsmith.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "langsmith.fullname" -}}
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
{{- define "langsmith.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langsmith.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langsmith.chart" . }}
{{ include "langsmith.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "langsmith.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "langsmith.chart" . }}
{{ include "langsmith.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langsmith.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langsmith.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the secret containing the secrets for this chart. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langsmith.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "langsmith.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for postgres. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langsmith.postgresSecretsName" -}}
{{- if .Values.postgres.external.existingSecretName }}
{{- .Values.postgres.external.existingSecretName }}
{{- else }}
{{- include "langsmith.fullname" . }}-postgres
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for redis. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langsmith.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "langsmith.fullname" . }}-redis
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for clickhouse. This can be overridden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langsmith.clickhouseSecretsName" -}}
{{- if .Values.clickhouse.external.existingSecretName }}
{{- .Values.clickhouse.external.existingSecretName }}
{{- else }}
{{- include "langsmith.fullname" . }}-clickhouse
{{- end }}
{{- end }}


{{/*
Template containing common environment variables that are used by several services.
*/}}
{{- define "langsmith.commonEnv" -}}
- name: POSTGRES_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.postgresSecretsName" . }}
      key: connection_url
{{- if .Values.postgres.external.enabled }}
- name: POSTGRES_SCHEMA
  value: {{ .Values.postgres.external.schema }}
{{- end }}
{{- if .Values.config.hostname }}
- name: LANGSMITH_URL
  value: {{ .Values.config.hostname }}
{{- end }}
- name: REDIS_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.redisSecretsName" . }}
      key: connection_url
- name: CLICKHOUSE_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_db
- name: CLICKHOUSE_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_host
- name: CLICKHOUSE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_port
- name: CLICKHOUSE_NATIVE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_native_port
- name: CLICKHOUSE_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_user
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_password
- name: CLICKHOUSE_TLS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: clickhouse_tls
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel }}
{{- if .Values.config.oauth.enabled }}
- name: OAUTH_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_client_id
- name: OAUTH_ISSUER_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_issuer_url
{{- if eq .Values.config.authType "mixed" }}
- name: OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_client_secret
{{- end }}
{{- end }}
- name: LANGSMITH_LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: langsmith_license_key
- name: API_KEY_SALT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: api_key_salt
- name: BASIC_AUTH_ENABLED
  value: {{ .Values.config.basicAuth.enabled | quote }}
{{- if .Values.config.basicAuth.enabled }}
- name: BASIC_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: jwt_secret
- name: FF_ORG_CREATION_DISABLED
  value: "true"
- name: FF_PERSONAL_ORGS_DISABLED
  value: "true"
{{- else }}
- name: FF_ORG_CREATION_DISABLED
  value: {{ .Values.config.orgCreationDisabled | quote }}
- name: FF_PERSONAL_ORGS_DISABLED
  value: {{ .Values.config.personalOrgsDisabled | quote }}
{{- end }}
- name: GO_ENDPOINT
  value: http://{{- include "langsmith.fullname" . }}-{{.Values.platformBackend.name}}:{{ .Values.platformBackend.service.port }}
- name: SMITH_BACKEND_ENDPOINT
  value: http://{{- include "langsmith.fullname" . }}-{{.Values.backend.name}}:{{ .Values.backend.service.port }}
- name: X_SERVICE_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: api_key_salt
{{- if .Values.config.ttl.enabled }}
- name: FF_TRACE_TIERS_ENABLED
  value: {{ .Values.config.ttl.enabled | quote }}
- name: FF_UPGRADE_TRACE_TIER_ENABLED
  value: "true"
- name: TRACE_TIER_TTL_DURATION_SEC_MAP
  value: "{ \"longlived\": {{ .Values.config.ttl.ttl_period_seconds.longlived }}, \"shortlived\": {{ .Values.config.ttl.ttl_period_seconds.shortlived }} }"
{{- end }}
{{- if .Values.config.workspaceScopeOrgInvitesEnabled }}
- name: FF_WORKSPACE_SCOPE_ORG_INVITES_ENABLED
  value: {{ .Values.config.workspaceScopeOrgInvitesEnabled | quote }}
{{- end }}
{{- if .Values.config.blobStorage.enabled }}
- name: FF_S3_STORAGE_ENABLED
  value: {{ .Values.config.blobStorage.enabled | quote }}
- name: S3_BUCKET_NAME
  value: {{ .Values.config.blobStorage.bucketName | quote }}
- name: S3_RUN_MANIFEST_BUCKET_NAME
  value: {{ .Values.config.blobStorage.bucketName | quote }}
- name: S3_API_URL
  value: {{ .Values.config.blobStorage.apiURL | quote }}
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: blob_storage_access_key
      optional: true
- name: S3_ACCESS_KEY_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: blob_storage_access_key_secret
      optional: true
{{- end }}
- name: FF_CH_SEARCH_ENABLED
  value: {{ .Values.config.blobStorage.chSearchEnabled | quote }}
{{- end }}

{{- define "backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.backend.name) .Values.backend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.backend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "clickhouse.serviceAccountName" -}}
{{- if .Values.clickhouse.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.clickhouse.name) .Values.clickhouse.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.clickhouse.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "frontend.serviceAccountName" -}}
{{- if .Values.frontend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.frontend.name) .Values.frontend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.frontend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "platformBackend.serviceAccountName" -}}
{{- if .Values.platformBackend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.platformBackend.name) .Values.platformBackend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.platformBackend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "playground.serviceAccountName" -}}
{{- if .Values.playground.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.playground.name) .Values.playground.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.playground.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "postgres.serviceAccountName" -}}
{{- if .Values.postgres.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.postgres.name) .Values.postgres.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.postgres.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "queue.serviceAccountName" -}}
{{- if .Values.queue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.queue.name) .Values.queue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.queue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* Fail on duplicate keys in the inputted list on environment variables */}}
{{- define "langsmith-multitenant.detectDuplicates" -}}
{{- $inputList := . -}}
{{- $keyCounts := dict -}}
{{- $duplicates := list -}}

{{- range $i, $val := $inputList }}
  {{- $key := $val.name -}}
  {{- if hasKey $keyCounts $key }}
    {{- $_ := set $keyCounts $key (add (get $keyCounts $key) 1) -}}
  {{- else }}
    {{- $_ := set $keyCounts $key 1 -}}
  {{- end }}
  {{- if gt (get $keyCounts $key) 1 }}
    {{- $duplicates = append $duplicates $key -}}
  {{- end }}
{{- end }}

{{- if gt (len $duplicates) 0 }}
  {{ fail (printf "Duplicate keys detected: %v" $duplicates) }}
{{- end }}
{{- end -}}
