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

{{/* Include these env vars if they aren't defined in .Values.commonEnv */}}
{{- define "langsmith.conditionalEnvVars" -}}
- name: X_SERVICE_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: api_key_salt
{{- end }}
{{- define "langsmith.conditionalEnvVarsResolved" -}}
  {{- $commonEnvKeys := list -}}
  {{- range $i, $commonEnvVar := .Values.commonEnv -}}
    {{- $commonEnvKeys = append $commonEnvKeys $commonEnvVar.name -}}
  {{- end -}}

  {{- $resolvedEnvVars := list -}}
  {{- range $i, $envVar := include "langsmith.conditionalEnvVars" . | fromYamlArray }}
    {{- if not (has $envVar.name $commonEnvKeys) }}
      {{- $resolvedEnvVars = append $resolvedEnvVars $envVar -}}
    {{- end }}
  {{- end }}

  {{- if gt (len $resolvedEnvVars) 0 -}}
    {{ $resolvedEnvVars | toYaml }}
  {{- end -}}
{{- end }}


{{/*
Template containing common environment variables that are used by several services.
*/}}
{{- define "langsmith.commonEnv" -}}
- name: POSTGRES_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.postgresSecretsName" . }}
      key: {{ .Values.postgres.external.connectionUrlSecretKey }}
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
      key: {{ .Values.redis.external.connectionUrlSecretKey }}
- name: CLICKHOUSE_HYBRID
  value: {{ .Values.clickhouse.external.hybrid | quote }}
- name: CLICKHOUSE_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.databaseSecretKey }}
- name: CLICKHOUSE_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.hostSecretKey }}
- name: CLICKHOUSE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.portSecretKey }}
- name: CLICKHOUSE_NATIVE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.nativePortSecretKey }}
- name: CLICKHOUSE_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.userSecretKey }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.passwordSecretKey }}
- name: CLICKHOUSE_TLS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.tlsSecretKey }}
- name: CLICKHOUSE_CLUSTER
  value: {{ .Values.clickhouse.external.cluster }}
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
- name: FF_BLOB_STORAGE_ENABLED
  value: {{ .Values.config.blobStorage.enabled | quote }}
- name: BLOB_STORAGE_ENGINE
  value: {{ .Values.config.blobStorage.engine | quote }}
- name: MIN_BLOB_STORAGE_SIZE_KB
  value: {{ ternary 0 .Values.config.blobStorage.minBlobStorageSizeKb .Values.clickhouse.external.hybrid | quote }}
{{- if eq .Values.config.blobStorage.engine "S3" }}
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
{{- if eq .Values.config.blobStorage.engine "Azure" }}
- name: AZURE_STORAGE_ACCOUNT_NAME
  value: {{ .Values.config.blobStorage.azureStorageAccountName | quote }}
- name: AZURE_STORAGE_CONTAINER_NAME
  value: {{ .Values.config.blobStorage.azureStorageContainerName | quote }}
- name: AZURE_STORAGE_SERVICE_URL_OVERRIDE
  value: {{ .Values.config.blobStorage.azureStorageServiceUrlOverride | quote }}
- name: AZURE_STORAGE_ACCOUNT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: azure_storage_account_key
      optional: true
- name: AZURE_STORAGE_CONNECTION_STRING
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: azure_storage_connection_string
      optional: true
{{- end }}
{{- end }}
- name: FF_CH_SEARCH_ENABLED
  value: {{ ternary "false" .Values.config.blobStorage.chSearchEnabled .Values.clickhouse.external.hybrid | quote }}
{{ include "langsmith.conditionalEnvVarsResolved" . }}
- name: REDIS_RUNS_EXPIRY_SECONDS
  value: {{ .Values.config.settings.redisRunsExpirySeconds | quote }}
{{- if .Values.config.langgraphPlatform.enabled }}
- name: LANGGRAPH_CLOUD_LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: langgraph_cloud_license_key
- name: HOST_QUEUE
  value: "host"
- name: HOST_WORKER_RECONCILIATION_CRON_ENABLED
  value: "true"
- name: HOST_LANGCHAIN_API_ENDPOINT
  value: "http://{{ include "langsmith.fullname" . }}-{{ .Values.frontend.name }}.{{ .Release.Namespace }}:{{ .Values.frontend.service.httpPort }}/api/v1"
- name: HOSTED_K8S_ROOT_DOMAIN
  value: {{ .Values.config.langgraphPlatform.rootDomain | quote }}
- name: HOSTED_K8S_SHARED_INGRESS
  value: "true"
{{- end }}
{{- if .Values.config.fullTextSearch.indexing.enabled }}
- name: QUICKWIT_INDEXING_ENABLED_ALL
  value: "true"
- name: QUICKWIT_INDEXING_URL
  value: {{ include "langsmith.quickwit-indexing-endpoint" . }}
- name: QUICKWIT_SEARCH_URL
  value: {{ include "langsmith.quickwit-search-endpoint" . }}
- name: QUICKWIT_SEARCH_ENABLED
  value: "true"
{{- end }}
{{- end }}


{{- define "aceBackend.serviceAccountName" -}}
{{- if .Values.aceBackend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.aceBackend.name) .Values.aceBackend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.aceBackend.serviceAccount.name }}
{{- end -}}
{{- end -}}


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

{{- define "hostBackend.serviceAccountName" -}}
{{- if .Values.hostBackend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.hostBackend.name) .Values.hostBackend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.hostBackend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "listener.serviceAccountName" -}}
{{- if .Values.listener.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.listener.name) .Values.listener.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.listener.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "operator.serviceAccountName" -}}
{{- if .Values.operator.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.operator.name) .Values.operator.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.operator.serviceAccount.name }}
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

{{/* Fail on duplicate keys in the inputted list of environment variables */}}
{{- define "langsmith.detectDuplicates" -}}
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

{{/*
Quickwit selector labels, different from langsmith.selectorLabels, needed for headless service
*/}}
{{- define "quickwit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langsmith.name" . }}-{{ .Values.quickwit.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "langsmith.name" . }}
{{- end }}

{{/*
Quickwit common labels
*/}}
{{- define "quickwit.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langsmith.chart" . }}
{{ include "quickwit.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Quickwit cluster name
*/}}
{{- define "quickwit.clusterName" -}}
{{ include "langsmith.fullname" . }}-{{ .Values.quickwit.name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "quickwit.serviceAccountName" -}}
{{- if .Values.quickwit.serviceAccount.create }}
{{- default (include "quickwit.clusterName" . ) .Values.quickwit.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.quickwit.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Quickwit ConfigMap name
*/}}
{{- define "quickwit.configMapName" -}}
{{ include "quickwit.clusterName" . }}
{{- end }}


{{/*
Quickwit environment
*/}}
{{- define "quickwit.environment" -}}
- name: NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: QW_CONFIG
  value: {{ .Values.quickwit.configLocation }}
- name: QW_CLUSTER_ID
  value: {{ include "quickwit.clusterName" . }}
- name: QW_NODE_ID
  value: "$(POD_NAME)"
- name: QW_PEER_SEEDS
  value: {{ include "quickwit.clusterName" . }}-headless
- name: QW_ADVERTISE_ADDRESS
  value: "$(POD_IP)"
- name: QW_CLUSTER_ENDPOINT
  value: {{ include "langsmith.quickwit-cluster-endpoint" . }}
{{- range $key, $value := .Values.quickwit.environment }}
- name: "{{ $key }}"
  value: "{{ $value }}"
{{- end }}
{{- end }}

{{- define "langsmith.quickwit-runs-index" -}}
{{- $.Files.Get "resources/quickwit-index-runs.yaml" -}}
{{- end -}}

{{- define "langsmith.quickwit-cluster-endpoint" -}}
{{- printf "http://%s-%s:7280" (include "langsmith.fullname" .) (.Values.quickwit.metastore.name) -}}
{{- end }}

{{- define "langsmith.quickwit-indexing-endpoint" -}}
{{- printf "http://%s-%s:7280" (include "langsmith.fullname" .) (.Values.quickwit.indexer.name) -}}
{{- end }}

{{- define "langsmith.quickwit-search-endpoint" -}}
{{- printf "http://%s-%s:7280" (include "langsmith.fullname" .) (.Values.quickwit.searcher.name) -}}
{{- end }}

