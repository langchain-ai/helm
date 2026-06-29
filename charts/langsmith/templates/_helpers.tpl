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
Common pod annotations
*/}}
{{- define "langsmith.commonPodAnnotations" -}}
{{- if .Values.commonPodAnnotations }}
{{ toYaml .Values.commonPodAnnotations }}
{{- end }}
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
      optional: {{ .Values.config.disableSecretCreation }}
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
Template for merging commonPodSecurityContext with component-specific podSecurityContext.
Component-specific values take precedence over common values.
Usage: {{ include "langsmith.podSecurityContext" (dict "Values" .Values "componentSecurityContext" .Values.backend.deployment.podSecurityContext) }}
*/}}
{{- define "langsmith.podSecurityContext" -}}
{{- $merged := merge .componentSecurityContext .Values.commonPodSecurityContext -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Common DNS configuration for all pods. When commonDnsConfig is set, it will be applied to all pods.
*/}}
{{- define "langsmith.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
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
      key: {{ .Values.postgres.external.connectionUrlSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
{{- if .Values.postgres.external.enabled }}
- name: POSTGRES_SCHEMA
  value: {{ .Values.postgres.external.schema | quote }}
- name: POSTGRES_TLS
  value: {{ .Values.postgres.external.customTls | quote }}
{{- if .Values.postgres.external.clientCert.secretName }}
- name: POSTGRES_TLS_CLIENT_CERT_PATH
  value: /etc/postgres/certs/client.crt
- name: POSTGRES_TLS_CLIENT_KEY_PATH
  value: /etc/postgres/certs/client.key
{{- end }}
{{- end }}
{{- if .Values.config.hostname }}
- name: LANGSMITH_URL
  value: {{ include "langsmith.hostnameWithoutProtocol" . }}{{- with .Values.config.basePath }}/{{ . }}{{- end }}
- name: HOST_BACKEND_ENDPOINT_PUBLIC
  value: {{ .Values.config.hostname }}/api-host
{{- end }}
{{- if .Values.fleet.enabled }}
{{- $ns := .Values.namespace | default .Release.Namespace -}}
{{- $cd := .Values.clusterDomain -}}
{{- $fleetApi := printf "http://%s.%s.svc.%s:%v" (include "langsmith.agentFeatures.apiServerK8sServiceName" (dict "root" . "product" "fleet")) $ns $cd .Values.fleet.apiServer.service.httpPort }}
- name: LANGGRAPH_DEPLOYMENT_URL
  value: {{ $fleetApi | quote }}
{{- end }}
- name: REDIS_CLUSTER_ENABLED
  value: {{ .Values.redis.external.cluster.enabled | quote }}
{{- if .Values.redis.external.cluster.enabled }}
- name: REDIS_CLUSTER_DATABASE_URIS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.redisSecretsName" . }}
      key: {{ .Values.redis.external.cluster.nodeUrisSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: REDIS_CLUSTER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.redisSecretsName" . }}
      key: {{ .Values.redis.external.cluster.passwordSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: REDIS_CLUSTER_USE_SSL_CONNECTION
  value: {{ .Values.redis.external.cluster.tlsEnabled | quote }}
{{- else }}
- name: REDIS_DATABASE_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.redisSecretsName" . }}
      key: {{ .Values.redis.external.connectionUrlSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: REDIS_CLUSTER_SAFE_MODE
  value: {{ .Values.redis.external.clusterSafeMode | quote }}
{{- end }}
{{- if .Values.redis.external.clientCert.secretName }}
- name: REDIS_TLS_CLIENT_CERT_PATH
  value: /etc/redis/certs/client.crt
- name: REDIS_TLS_CLIENT_KEY_PATH
  value: /etc/redis/certs/client.key
{{- end }}
{{- if .Values.postgres.external.iamAuthProvider }}
- name: POSTGRES_IAM_AUTH_PROVIDER
  value: {{ .Values.postgres.external.iamAuthProvider | quote }}
{{- end }}
{{- if .Values.redis.external.iamAuthProvider }}
- name: REDIS_IAM_AUTH_PROVIDER
  value: {{ .Values.redis.external.iamAuthProvider | quote }}
{{- end }}
- name: CLICKHOUSE_HYBRID
  value: {{ .Values.clickhouse.external.hybrid | quote }}
- name: CLICKHOUSE_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.databaseSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.hostSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.portSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_NATIVE_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.nativePortSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.userSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.passwordSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
- name: CLICKHOUSE_TLS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.clickhouseSecretsName" . }}
      key: {{ .Values.clickhouse.external.tlsSecretKey }}
      optional: {{ .Values.config.disableSecretCreation }}
{{- if .Values.clickhouse.external.clientCert.secretName }}
- name: CLICKHOUSE_TLS_CLIENT_CERT_PATH
  value: /etc/clickhouse/certs/client.crt
- name: CLICKHOUSE_TLS_CLIENT_KEY_PATH
  value: /etc/clickhouse/certs/client.key
{{- end }}
- name: CLICKHOUSE_CLUSTER
  value: {{ .Values.clickhouse.external.cluster | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
{{- if .Values.config.oauth.enabled }}
- name: OAUTH_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_client_id
      optional: {{ .Values.config.disableSecretCreation }}
- name: OAUTH_ISSUER_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_issuer_url
      optional: {{ .Values.config.disableSecretCreation }}
{{- if eq .Values.config.authType "mixed" }}
- name: OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: oauth_client_secret
      optional: {{ .Values.config.disableSecretCreation }}
{{- end }}
{{- end }}
- name: LANGSMITH_LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: langsmith_license_key
      optional: {{ .Values.config.disableSecretCreation }}
- name: API_KEY_SALT
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: api_key_salt
      optional: {{ .Values.config.disableSecretCreation }}
- name: BASIC_AUTH_ENABLED
  value: {{ .Values.config.basicAuth.enabled | quote }}
{{- if .Values.config.basicAuth.enabled }}
- name: BASIC_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: jwt_secret
      optional: {{ .Values.config.disableSecretCreation }}
{{- end }}
- name: FF_ORG_CREATION_DISABLED
  value: {{ .Values.config.userOrgCreationDisabled | quote }}
- name: FF_PERSONAL_ORGS_DISABLED
  value: {{ .Values.config.personalOrgsDisabled | quote }}
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
{{- if .Values.config.infoEndpointAuthRequired }}
- name: FF_INFO_ENDPOINT_AUTH_REQUIRED
  value: {{ .Values.config.infoEndpointAuthRequired | quote }}
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
{{- if (or (eq .Values.config.blobStorage.engine "S3") (eq .Values.config.blobStorage.engine "s3") (eq .Values.config.blobStorage.engine "GCS") (eq .Values.config.blobStorage.engine "gcs")) }}
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
- name: S3_USE_PATH_STYLE
  value: {{ .Values.config.blobStorage.s3UsePathStyle | quote }}
{{- if .Values.config.blobStorage.kmsEncryptionEnabled }}
- name: S3_KMS_ENCRYPTION_ENABLED
  value: {{ .Values.config.blobStorage.kmsEncryptionEnabled | quote }}
{{- if .Values.config.blobStorage.kmsKeyArn }}
- name: S3_KMS_KEY_ARN
  value: {{ .Values.config.blobStorage.kmsKeyArn | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- if (or (eq .Values.config.blobStorage.engine "Azure") (eq .Values.config.blobStorage.engine "azure")) }}
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
- name: LANGGRAPH_CLOUD_LICENSE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: langsmith_license_key
      optional: {{ .Values.config.disableSecretCreation }}
{{- if .Values.config.deployment.enabled }}
- name: HOST_QUEUE
  value: "host"
- name: HOST_WORKER_RECONCILIATION_CRON_ENABLED
  value: "true"
- name: HOSTED_K8S_ROOT_DOMAIN
  value: {{ include "langsmith.hostnameWithoutProtocol" . | quote }}
- name: HOSTED_K8S_SHARED_INGRESS
  value: "true"
{{- end }}
- name: ENABLE_LGP_DEPLOYMENT_HEALTH_CHECK
  value: {{ .Values.config.deployment.ingressHealthCheckEnabled | quote }}
{{- if and .Values.config.customCa.secretName .Values.config.customCa.secretKey }}
- name: SSL_CERT_FILE
  value: /etc/ssl/certs/custom-ca-certificates.crt
{{- end }}
{{- if .Values.ingestQueue.enabled }}
- name: GO_QUEUE_ENABLED_ALL
  value: "true"
- name: GO_FEEDBACK_QUEUE_ENABLED_ALL
  value: "true"
- name: FF_PERSIST_BATCHED_RUNS_SUCCESS_LOGGING
  value: "true"
{{- end }}
{{- if or .Values.config.agentBuilder.enabled .Values.fleet.enabled }}
- name: AGENT_BUILDER_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: agent_builder_encryption_key
{{- end }}
{{- if .Values.insights.enabled }}
- name: CLIO_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: insights_encryption_key
      optional: false
{{- end }}
{{- if .Values.polly.enabled }}
- name: POLLY_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: polly_encryption_key
      optional: false
{{- end }}
{{- end }}

{{/*
SmithDB resource name prefix.
*/}}
{{- define "langsmith.smithdb.fullname" -}}
{{- printf "%s-%s" (include "langsmith.fullname" .) .Values.smithdb.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of a SmithDB component Service or Deployment.
Args: root, component.
*/}}
{{- define "langsmith.smithdb.componentName" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $componentValues := index $root.Values.smithdb $component -}}
{{- printf "%s-%s" (include "langsmith.smithdb.fullname" $root) $componentValues.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the shared SmithDB service account.
Args: root.
*/}}
{{- define "langsmith.smithdb.serviceAccountName" -}}
{{- $root := .root -}}
{{- if $root.Values.smithdb.serviceAccount.create -}}
{{- default (include "langsmith.smithdb.fullname" $root) $root.Values.smithdb.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- default "default" $root.Values.smithdb.serviceAccount.name }}
{{- end -}}
{{- end }}

{{/*
SmithDB internal service URL used by LangSmith and SmithDB gRPC clients.
Args: root, component, port.
*/}}
{{- define "langsmith.smithdb.grpcServiceUrl" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $port := .port -}}
{{- printf "%s.%s.svc.%s:%v" (include "langsmith.smithdb.componentName" (dict "root" $root "component" $component)) ($root.Values.namespace | default $root.Release.Namespace) $root.Values.clusterDomain $port }}
{{- end }}

{{/*
SmithDB HTTP-style endpoint used by SmithDB workloads for internal component calls.
Args: root, component, port.
*/}}
{{- define "langsmith.smithdb.httpServiceUrl" -}}
{{- printf "http://%s" (include "langsmith.smithdb.grpcServiceUrl" .) }}
{{- end }}

{{/*
SmithDB cluster-manager HTTP endpoint used by SmithDB services.
*/}}
{{- define "langsmith.smithdb.clusterManagerHttpEndpoint" -}}
{{- include "langsmith.smithdb.httpServiceUrl" (dict "root" . "component" "clusterManager" "port" .Values.smithdb.clusterManager.service.port) }}
{{- end }}

{{/*
SmithDB cluster-manager client env vars. Args: root, service.
*/}}
{{- define "langsmith.smithdb.clusterManagerClientEnv" -}}
{{- $root := .root -}}
{{- $service := upper .service -}}
{{- $prefix := printf "SMITHDB_%s__CLUSTER_MANAGER" $service -}}
- name: {{ $prefix }}__ENABLED
  value: "true"
- name: {{ $prefix }}__ENDPOINT
  value: {{ include "langsmith.smithdb.clusterManagerHttpEndpoint" $root | quote }}
- name: {{ $prefix }}__STATUS_INTERVAL
  value: "1s"
- name: {{ $prefix }}__RETRY_DELAY
  value: "1s"
- name: {{ $prefix }}__STATUS_BUFFER_SIZE
  value: "32"
- name: {{ $prefix }}__CONNECT_TIMEOUT
  value: "1s"
{{- end }}

{{/*
SmithDB component env vars.
Args: root, service, displayName.
*/}}
{{- define "langsmith.smithdb.componentEnv" -}}
{{- $root := .root -}}
{{- $service := .service -}}
{{- $envVars := include "langsmith.smithdb.serviceEnv" (dict "root" $root "service" $service "displayName" .displayName) | fromYamlArray -}}
{{- if $root.Values.smithdb.enabled }}
{{- $envVars = concat $envVars (include "langsmith.smithdb.clusterManagerClientEnv" (dict "root" $root "service" $service) | fromYamlArray) -}}
{{- end }}
{{- $envVars = concat $envVars $root.Values.commonEnv $root.Values.smithdb.commonEnv -}}
{{- toYaml $envVars }}
{{- end }}

{{/*
SmithDB OTEL resource attributes.
*/}}
{{- define "langsmith.smithdb.otelResourceAttributes" -}}
{{- $resourceAttributes := list "pod_name=$(POD_NAME)" "k8s.pod.name=$(POD_NAME)" "container_name=$(CONTAINER_NAME)" "k8s.container.name=$(CONTAINER_NAME)" -}}
{{- range $key, $value := .Values.smithdb.config.observability.tracing.extraResourceAttributes }}
{{- $resourceAttributes = append $resourceAttributes (printf "%s=%s" $key (toString $value)) -}}
{{- end }}
{{- join "," $resourceAttributes -}}
{{- end }}

{{/*
Shared SmithDB service env vars. Args: root, service, displayName.
*/}}
{{- define "langsmith.smithdb.serviceEnv" -}}
{{- $root := .root -}}
{{- $service := .service -}}
{{- $displayName := .displayName -}}
{{- $prefix := printf "SMITHDB_%s" (upper $service) -}}
{{- $objectStoreType := lower (default "s3" $root.Values.smithdb.config.objectStore.type) -}}
{{- $objectStoreRootFolder := "smithdb" -}}
{{- $tracingEnabled := $root.Values.smithdb.config.observability.tracing.enabled -}}
{{- $logLevel := default "INFO,vortex=WARN" $root.Values.smithdb.config.observability.logging.level -}}
- name: {{ $prefix }}__LOGGING__FORMAT
  value: {{ ternary "opentelemetry" "console" $tracingEnabled | quote }}
- name: {{ $prefix }}__LOGGING__TRACING_ENABLED
  value: {{ $tracingEnabled | quote }}
- name: {{ $prefix }}__LOGGING__SERVICE_NAME
  value: {{ $displayName | quote }}
- name: {{ $prefix }}__OBJECT_STORE__TYPE
  value: {{ $objectStoreType | quote }}
{{- if eq $objectStoreType "s3" }}
- name: {{ $prefix }}__OBJECT_STORE__S3__BUCKET
  value: {{ $root.Values.smithdb.config.objectStore.bucket | quote }}
- name: {{ $prefix }}__OBJECT_STORE__S3__ROOT_FOLDER
  value: {{ $objectStoreRootFolder | quote }}
{{- with $root.Values.smithdb.config.objectStore.s3.region }}
- name: {{ $prefix }}__OBJECT_STORE__S3__REGION
  value: {{ . | quote }}
{{- end }}
{{- with $root.Values.smithdb.config.objectStore.s3.endpoint }}
- name: {{ $prefix }}__OBJECT_STORE__S3__ENDPOINT
  value: {{ . | quote }}
{{- end }}
{{- if hasKey $root.Values.smithdb.config.objectStore.s3 "allowHttp" }}
- name: {{ $prefix }}__OBJECT_STORE__S3__ALLOW_HTTP
  value: {{ $root.Values.smithdb.config.objectStore.s3.allowHttp | quote }}
{{- end }}
{{- if $root.Values.smithdb.config.objectStore.s3.accessKeyIdSecretKey }}
- name: {{ $prefix }}__OBJECT_STORE__S3__ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.objectStore.s3.accessKeyIdSecretKey }}
{{- end }}
{{- if $root.Values.smithdb.config.objectStore.s3.secretAccessKeySecretKey }}
- name: {{ $prefix }}__OBJECT_STORE__S3__SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.objectStore.s3.secretAccessKeySecretKey }}
{{- end }}
{{- else if eq $objectStoreType "gcs" }}
- name: {{ $prefix }}__OBJECT_STORE__GCS__BUCKET
  value: {{ $root.Values.smithdb.config.objectStore.bucket | quote }}
- name: {{ $prefix }}__OBJECT_STORE__GCS__ROOT_FOLDER
  value: {{ $objectStoreRootFolder | quote }}
{{- end }}
- name: {{ $prefix }}__METASTORE__TYPE
  value: "postgres"
- name: {{ $prefix }}__METASTORE__DEFAULT_URI
  value: {{ ternary "s3://" "gs://" (eq $objectStoreType "s3") | quote }}
- name: {{ $prefix }}__METASTORE__HOST
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.metastore.hostSecretKey }}
- name: {{ $prefix }}__METASTORE__PORT
  value: {{ $root.Values.smithdb.config.metastore.port | quote }}
- name: {{ $prefix }}__METASTORE__DATABASE
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.metastore.databaseSecretKey }}
- name: {{ $prefix }}__METASTORE__USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.metastore.usernameSecretKey }}
- name: {{ $prefix }}__METASTORE__PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $root.Values.smithdb.config.existingSecretName }}
      key: {{ $root.Values.smithdb.config.metastore.passwordSecretKey }}
- name: {{ $prefix }}__METASTORE__USE_SSL
  value: {{ $root.Values.smithdb.config.metastore.useSsl | quote }}
- name: NODE_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
{{- if $tracingEnabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $root.Values.smithdb.config.observability.tracing.endpoint | quote }}
{{- /* SmithDB exports OTLP over gRPC. */}}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "grpc"
{{- end }}
- name: OTEL_SERVICE_NAME
  value: {{ $displayName | quote }}
- name: RUST_LOG
  value: {{ $logLevel | quote }}
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_UID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: CONTAINER_NAME
  value: {{ $displayName | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ include "langsmith.smithdb.otelResourceAttributes" $root | quote }}
- name: _RJEM_MALLOC_CONF
  value: "prof:true,prof_active:false,lg_prof_sample:19"
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

{{- define "ingestQueue.serviceAccountName" -}}
{{- if .Values.ingestQueue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.ingestQueue.name) .Values.ingestQueue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.ingestQueue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "fleetToolServer.serviceAccountName" -}}
{{- if .Values.fleetToolServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.fleetToolServer.name) .Values.fleetToolServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.fleetToolServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "fleetTriggerServer.serviceAccountName" -}}
{{- if .Values.fleetTriggerServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.fleetTriggerServer.name) .Values.fleetTriggerServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.fleetTriggerServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "agentGateway.serviceAccountName" -}}
{{- if .Values.agentGateway.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.agentGateway.name) .Values.agentGateway.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.agentGateway.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "presidioAnalyzer.serviceAccountName" -}}
{{- if .Values.presidioAnalyzer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) .Values.presidioAnalyzer.name) .Values.presidioAnalyzer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.presidioAnalyzer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "agentBootstrap.serviceAccountName" -}}
{{- if .Values.backend.agentBootstrap.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.fullname" .) "agent-bootstrap") .Values.backend.agentBootstrap.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.backend.agentBootstrap.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "fleetApiServer.serviceAccountName" -}}
{{- if .Values.fleet.apiServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "fleet")) .Values.fleet.apiServer.name) .Values.fleet.apiServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.fleet.apiServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "fleetQueue.serviceAccountName" -}}
{{- if .Values.fleet.queue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "fleet")) .Values.fleet.queue.name) .Values.fleet.queue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.fleet.queue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "insightsApiServer.serviceAccountName" -}}
{{- if .Values.insights.apiServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "insights")) .Values.insights.apiServer.name) .Values.insights.apiServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.insights.apiServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "insightsQueue.serviceAccountName" -}}
{{- if .Values.insights.queue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "insights")) .Values.insights.queue.name) .Values.insights.queue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.insights.queue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "pollyApiServer.serviceAccountName" -}}
{{- if .Values.polly.apiServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "polly")) .Values.polly.apiServer.name) .Values.polly.apiServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.polly.apiServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "pollyQueue.serviceAccountName" -}}
{{- if .Values.polly.queue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langsmith.agentFeatures.fullname" (dict "root" . "product" "polly")) .Values.polly.queue.name) .Values.polly.queue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.polly.queue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Fullname prefix for a given agent feature product.
Usage: include "langsmith.agentFeatures.fullname" (dict "root" . "product" "fleet")
Produces: <release>-<namePrefix>  e.g. "langsmith-fleet"
*/}}
{{- define "langsmith.agentFeatures.fullname" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $prefix := (index $root.Values $product).namePrefix }}
{{- printf "%s-%s" (include "langsmith.fullname" $root) $prefix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Component name for StatefulSet-backed agent feature resources.
Kept to 52 chars so Kubernetes can append a 10-char controller revision hash
as a label value without exceeding the 63-char label limit.
Usage: include "langsmith.agentFeatures.componentName" (dict "root" . "product" "fleet" "component" "postgres")
*/}}
{{- define "langsmith.agentFeatures.componentName" -}}
{{- $root := index . "root" -}}
{{- $product := index . "product" -}}
{{- $componentName := index . "component" -}}
{{- $feature := index $root.Values $product -}}
{{- $component := index $feature $componentName -}}
{{- $suffix := printf "%s-%s" $feature.namePrefix $component.name -}}
{{- $prefixMaxLen := int (sub 51 (len $suffix)) -}}
{{- $prefix := include "langsmith.fullname" $root | trunc $prefixMaxLen | trimSuffix "-" -}}
{{- printf "%s-%s" $prefix $suffix -}}
{{- end -}}

{{/*
Postgres secret name for a given product.
Usage: include "langsmith.agentFeatures.postgresSecretName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.postgresSecretName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $pg := (index $root.Values $product).postgres }}
{{- if $pg.external.existingSecretName }}
{{- $pg.external.existingSecretName }}
{{- else }}
{{- include "langsmith.agentFeatures.fullname" . }}-postgres
{{- end }}
{{- end -}}

{{/*
Redis secret name for a given product.
Usage: include "langsmith.agentFeatures.redisSecretName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.redisSecretName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $redis := (index $root.Values $product).redis }}
{{- if $redis.external.existingSecretName }}
{{- $redis.external.existingSecretName }}
{{- else }}
{{- include "langsmith.agentFeatures.fullname" . }}-redis
{{- end }}
{{- end -}}

{{/*
FQDN for an agent feature's api-server Service (used by frontend nginx proxy_pass).
Usage: include "langsmith.agentFeatures.apiServerK8sServiceName" (dict "root" . "product" "fleet")
*/}}
{{- define "langsmith.agentFeatures.apiServerK8sServiceName" -}}
{{- $root := index . "root" }}
{{- $product := index . "product" }}
{{- $feat := index $root.Values $product }}
{{- printf "%s-%s" (include "langsmith.agentFeatures.fullname" .) $feat.apiServer.name }}
{{- end -}}

{{/*
URL path prefix for agent feature routes (handles basePath).
*/}}
{{- define "langsmith.agentFeatures.agentPathPrefix" -}}
{{- $root := index . "root" }}
{{- $segment := index . "segment" }}
{{- $bp := trimAll "/" (default "" $root.Values.config.basePath) -}}
{{- if $bp -}}/{{ $bp }}/agents/{{ $segment }}{{- else -}}/agents/{{ $segment }}{{- end -}}
{{- end -}}

{{/*
Extra env vars for fleet api-server and queue pods.
*/}}
{{- define "langsmith.fleet.extraEnv" -}}
{{- $root := index . "root" -}}
{{- $componentName := index . "component" -}}
{{- $feature := $root.Values.fleet -}}
{{- $component := index $feature $componentName -}}
{{- $out := list
  (dict "name" "PORT" "value" (toString $component.containerPort))
  (dict "name" "POSTGRES_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.postgresSecretName" (dict "root" $root "product" "fleet")) "key" "postgres_connection_url")))
  (dict "name" "REDIS_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.redisSecretName" (dict "root" $root "product" "fleet")) "key" "redis_connection_url")))
  (dict "name" "LANGSMITH_LICENSE_REQUIRED_CLAIMS" "value" "agent_builder_enabled")
  (dict "name" "SSRF_ALLOW_PRIVATE_IPS_MCP_SERVERS" "value" "true")
  (dict "name" "SSRF_ALLOW_PRIVATE_IPS_TOOLS" "value" "true")
  (dict "name" "SSRF_ALLOW_K8S_INTERNAL" "value" "true")
-}}
{{- if and (eq $componentName "apiServer") $feature.queue.enabled -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" "0") -}}
{{- else -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" (toString $feature.queue.numberOfJobsPerWorker)) -}}
{{- end -}}
{{- if $feature.enableTracing }}
{{- $out = append $out (dict "name" "TENANT_AWARE_TRACING_ENABLED" "value" "true") }}
{{- end }}
{{- toYaml $out }}
{{- end -}}

{{/*
Extra env vars for insights api-server and queue pods.
*/}}
{{- define "langsmith.insights.extraEnv" -}}
{{- $root := index . "root" -}}
{{- $componentName := index . "component" -}}
{{- $feature := $root.Values.insights -}}
{{- $component := index $feature $componentName -}}
{{- $out := list
  (dict "name" "PORT" "value" (toString $component.containerPort))
  (dict "name" "POSTGRES_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.postgresSecretName" (dict "root" $root "product" "insights")) "key" "postgres_connection_url")))
  (dict "name" "REDIS_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.redisSecretName" (dict "root" $root "product" "insights")) "key" "redis_connection_url")))
  (dict "name" "LANGSMITH_TRACING" "value" "false")
-}}
{{- if and (eq $componentName "apiServer") $feature.queue.enabled -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" "0") -}}
{{- else -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" (toString $feature.queue.numberOfJobsPerWorker)) -}}
{{- end -}}
{{- toYaml $out }}
{{- end -}}

{{/*
Extra env vars for polly api-server and queue pods.
*/}}
{{- define "langsmith.polly.extraEnv" -}}
{{- $root := index . "root" -}}
{{- $componentName := index . "component" -}}
{{- $feature := $root.Values.polly -}}
{{- $component := index $feature $componentName -}}
{{- $ns := $root.Values.namespace | default $root.Release.Namespace -}}
{{- $cd := $root.Values.clusterDomain -}}
{{- $backend := printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" $root) $root.Values.backend.name $ns $cd $root.Values.backend.service.port -}}
{{- $out := list
  (dict "name" "PORT" "value" (toString $component.containerPort))
  (dict "name" "POSTGRES_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.postgresSecretName" (dict "root" $root "product" "polly")) "key" "postgres_connection_url")))
  (dict "name" "REDIS_URI" "valueFrom" (dict "secretKeyRef" (dict "name" (include "langsmith.agentFeatures.redisSecretName" (dict "root" $root "product" "polly")) "key" "redis_connection_url")))
  (dict "name" "LANGSMITH_ENDPOINT" "value" $backend)
  (dict "name" "LANGSMITH_DISABLE_RUN_COMPRESSION" "value" "true")
  (dict "name" "LANGSMITH_TRACING" "value" (ternary "false" "true" $feature.enableTracing))
-}}
{{- if and (eq $componentName "apiServer") $feature.queue.enabled -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" "0") -}}
{{- else -}}
{{- $out = append $out (dict "name" "N_JOBS_PER_WORKER" "value" (toString $feature.queue.numberOfJobsPerWorker)) -}}
{{- end -}}
{{- toYaml $out }}
{{- end -}}

{{- define "agentBootstrap.createAgentProducts" -}}
{{- $createProducts := list }}
{{- if .Values.config.agentBuilder.enabled }}
{{- $createProducts = append $createProducts "agent_builder" }}
{{- end }}
{{ toYaml $createProducts }}
{{- end -}}

{{- define "agentBootstrap.destroyAgentProducts" -}}
{{- $destroyProducts := list }}
{{- if not .Values.config.agentBuilder.enabled }}
{{- $destroyProducts = append $destroyProducts "agent_builder" }}
{{- end }}
{{- $destroyProducts = append $destroyProducts "insights" }}
{{- $destroyProducts = append $destroyProducts "smith_polly" }}
{{ toYaml $destroyProducts }}
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

{{- define "langsmith.checksumAnnotations"}}
checksum/config: {{ include (print $.Template.BasePath "/config-map.yaml") . | sha256sum }}
{{- if .Values.frontend.enabled }}
checksum/frontend-config: {{ include (print $.Template.BasePath "/frontend/config-map.yaml") . | sha256sum }}
{{- end }}
{{- if not .Values.config.existingSecretName }}
checksum/secrets: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
{{- end }}
{{- if not .Values.redis.external.existingSecretName }}
checksum/redis: {{ include (print $.Template.BasePath "/redis/secrets.yaml") . | sha256sum }}
{{- end }}
{{- if not .Values.postgres.external.existingSecretName }}
checksum/postgres: {{ include (print $.Template.BasePath "/postgres/secrets.yaml") . | sha256sum }}
{{- end }}
{{- if not .Values.clickhouse.external.existingSecretName }}
checksum/clickhouse: {{ include (print $.Template.BasePath "/clickhouse/secrets.yaml") . | sha256sum }}
{{- end }}
{{- end }}

{{/*
Creates the image reference used for Langsmith deployments. If registry is specified, concatenate it, along with a '/'.
*/}}
{{- define "langsmith.image" -}}
{{- $imageConfig := index .Values.images .component -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- end -}}

{{- end -}}

{{- define "langsmith.tlsVolumeMounts" -}}
{{- $mounts := list -}}
{{- if and .Values.config.customCa.secretName .Values.config.customCa.secretKey -}}
{{- $mounts = append $mounts (dict "name" "langsmith-custom-ca" "mountPath" "/etc/ssl/certs/custom-ca-certificates.crt" "subPath" "ca-certificates.crt" "readOnly" true) -}}
{{- end -}}
{{- if .Values.redis.external.clientCert.secretName -}}
{{- $mounts = append $mounts (dict "name" "redis-client-cert" "mountPath" "/etc/redis/certs" "readOnly" true) -}}
{{- end -}}
{{- if .Values.postgres.external.clientCert.secretName -}}
{{- $mounts = append $mounts (dict "name" "postgres-client-cert" "mountPath" "/etc/postgres/certs" "readOnly" true) -}}
{{- end -}}
{{- if .Values.clickhouse.external.clientCert.secretName -}}
{{- $mounts = append $mounts (dict "name" "clickhouse-client-cert" "mountPath" "/etc/clickhouse/certs" "readOnly" true) -}}
{{- end -}}
{{ $mounts | toYaml }}
{{- end -}}

{{- define "langsmith.tlsVolumes" -}}
{{- $volumes := list -}}
{{- if and .Values.config.customCa.secretName .Values.config.customCa.secretKey -}}
{{- $volumes = append $volumes (dict "name" "langsmith-custom-ca" "secret" (dict "secretName" .Values.config.customCa.secretName "items" (list (dict "key" .Values.config.customCa.secretKey "path" "ca-certificates.crt")))) -}}
{{- end -}}
{{- if .Values.redis.external.clientCert.secretName -}}
{{- $volumes = append $volumes (dict "name" "redis-client-cert" "secret" (dict "secretName" .Values.redis.external.clientCert.secretName "items" (list (dict "key" .Values.redis.external.clientCert.certSecretKey "path" "client.crt" "mode" 0644) (dict "key" .Values.redis.external.clientCert.keySecretKey "path" "client.key" "mode" 0640)))) -}}
{{- end -}}
{{- if .Values.postgres.external.clientCert.secretName -}}
{{- $volumes = append $volumes (dict "name" "postgres-client-cert" "secret" (dict "secretName" .Values.postgres.external.clientCert.secretName "items" (list (dict "key" .Values.postgres.external.clientCert.certSecretKey "path" "client.crt" "mode" 0644) (dict "key" .Values.postgres.external.clientCert.keySecretKey "path" "client.key" "mode" 0640)))) -}}
{{- end -}}
{{- if .Values.clickhouse.external.clientCert.secretName -}}
{{- $volumes = append $volumes (dict "name" "clickhouse-client-cert" "secret" (dict "secretName" .Values.clickhouse.external.clientCert.secretName "items" (list (dict "key" .Values.clickhouse.external.clientCert.certSecretKey "path" "client.crt" "mode" 0644) (dict "key" .Values.clickhouse.external.clientCert.keySecretKey "path" "client.key" "mode" 0640)))) -}}
{{- end -}}
{{ $volumes | toYaml }}
{{- end -}}

{{/*
Strip protocol (http://, https://, etc.) from hostname
*/}}
{{- define "langsmith.hostnameWithoutProtocol" -}}
{{- if .Values.config.hostname -}}
{{- regexReplaceAll "^[a-zA-Z][a-zA-Z0-9+.-]*://" .Values.config.hostname "" -}}
{{- end -}}
{{- end -}}

{{/*
Sandbox runtime namespace.
*/}}
{{- define "langsmith.sandboxes.namespace" -}}
{{- default "langsmith-sandboxes" .Values.config.sandboxes.namespace -}}
{{- end -}}

{{/*
Sandbox runtime secret name in config.sandboxes.namespace.
*/}}
{{- define "langsmith.sandboxes.runtimeSecretName" -}}
{{- if .Values.config.sandboxes.runtimeSecret.existingSecretName -}}
{{- .Values.config.sandboxes.runtimeSecret.existingSecretName -}}
{{- else -}}
{{- default "sandbox-external" .Values.config.sandboxes.runtimeSecret.name -}}
{{- end -}}
{{- end -}}

{{/*
Sandbox proxy CA secret name in config.sandboxes.namespace.
*/}}
{{- define "langsmith.sandboxes.proxyCASecretName" -}}
{{- if eq .Values.config.sandboxes.proxyCA.mode "existingSecret" -}}
{{- .Values.config.sandboxes.proxyCA.existingSecretName -}}
{{- else -}}
{{- default "smithbox-proxy-ca" .Values.config.sandboxes.proxyCA.secretName -}}
{{- end -}}
{{- end -}}

{{/*
Sandbox service auth secret material for chart-created app/runtime Secrets.
*/}}
{{- define "langsmith.sandboxes.xServiceAuthJwtSecretValue" -}}
{{- default (default .Values.config.langsmithLicenseKey .Values.config.apiKeySalt) .Values.config.sandboxes.xServiceAuthJwtSecret -}}
{{- end -}}

{{/*
smithbox-control in-cluster URL.
*/}}
{{- define "langsmith.sandboxes.smithboxControlUrl" -}}
{{- printf "http://%s.%s.svc.%s:%v" .Values.config.sandboxes.smithboxControl.name (include "langsmith.sandboxes.namespace" .) .Values.clusterDomain .Values.config.sandboxes.smithboxControl.containerPort -}}
{{- end -}}

{{/*
Internal LangSmith platform endpoint used by sandbox runtime callbacks.
*/}}
{{- define "langsmith.sandboxes.langsmithInternalEndpoint" -}}
{{- printf "http://%s-%s.%s.svc.%s:%v" (include "langsmith.fullname" .) .Values.platformBackend.name (.Values.namespace | default .Release.Namespace) .Values.clusterDomain .Values.platformBackend.service.port -}}
{{- end -}}

{{/*
Namespace for the JuiceFS CSI config Secret.
*/}}
{{- define "langsmith.sandboxes.juicefsCSIConfigSecretNamespace" -}}
{{- default (.Values.namespace | default .Release.Namespace) .Values.config.sandboxes.juicefs.csi.configSecretNamespace -}}
{{- end -}}

{{/*
Sandbox service account names.
*/}}
{{- define "langsmith.sandboxes.smithboxControlServiceAccountName" -}}
{{- if .Values.config.sandboxes.smithboxControl.serviceAccount.create -}}
{{- default .Values.config.sandboxes.smithboxControl.name .Values.config.sandboxes.smithboxControl.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default "default" .Values.config.sandboxes.smithboxControl.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "langsmith.sandboxes.sandboxHostServiceAccountName" -}}
{{- if .Values.config.sandboxes.sandboxHost.serviceAccount.create -}}
{{- default .Values.config.sandboxes.sandboxHost.name .Values.config.sandboxes.sandboxHost.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default "default" .Values.config.sandboxes.sandboxHost.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Node selector for sandbox-host and sandbox-host-installer pods.
*/}}
{{- define "langsmith.sandboxes.sandboxHostNodeSelector" -}}
{{- if .Values.config.sandboxes.sandboxHost.nodeSelector -}}
{{- toYaml .Values.config.sandboxes.sandboxHost.nodeSelector -}}
{{- else -}}
sandbox.langsmith.com/host: "true"
{{- end -}}
{{- end -}}

{{/*
LangSmith app env vars for sandbox support.
*/}}
{{- define "langsmith.sandboxes.platformBackendEnv" -}}
{{- if .Values.config.sandboxes.enabled }}
- name: SANDBOX_FEATURE_ENABLED
  value: "true"
- name: SANDBOX_FRONTEND_ENABLED
  value: "true"
- name: SANDBOX_RUNTIME_V2
  value: "always"
- name: SMITHBOX_CONTROL_URL
  value: {{ include "langsmith.sandboxes.smithboxControlUrl" . | quote }}
- name: SANDBOX_SNAPSHOT_SERVICE_URL
  value: {{ include "langsmith.sandboxes.smithboxControlUrl" . | quote }}
- name: SANDBOX_K8S_CLUSTER_NAME
  value: {{ .Values.config.sandboxes.clusterName | quote }}
- name: SANDBOX_MAX_CPU_CORES
  value: {{ .Values.config.sandboxes.limits.maxCpuCores | quote }}
- name: SANDBOX_MAX_MEMORY_GB
  value: {{ .Values.config.sandboxes.limits.maxMemoryGb | quote }}
- name: SANDBOX_MIN_EPHEMERAL_STORAGE_GB
  value: {{ .Values.config.sandboxes.limits.minEphemeralStorageGb | quote }}
- name: SANDBOX_MAX_EPHEMERAL_STORAGE_GIB
  value: {{ .Values.config.sandboxes.limits.maxEphemeralStorageGib | quote }}
- name: SANDBOX_MAX_SANDBOXES
  value: {{ .Values.config.sandboxes.limits.maxSandboxes | quote }}
{{- if .Values.config.sandboxes.defaultBlueprintImage }}
- name: SANDBOX_DEFAULT_BLUEPRINT_IMAGE
  value: {{ .Values.config.sandboxes.defaultBlueprintImage | quote }}
{{- end }}
- name: SANDBOX_X_SERVICE_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: sandbox_x_service_auth_jwt_secret
      optional: {{ .Values.config.disableSecretCreation }}
{{- if .Values.config.sandboxes.xServiceAuthJwtSecretPrevious }}
- name: SANDBOX_X_SERVICE_AUTH_JWT_SECRET_PREVIOUS
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: sandbox_x_service_auth_jwt_secret_previous
      optional: {{ .Values.config.disableSecretCreation }}
{{- end }}
{{- if .Values.config.sandboxes.callbackSigningJwk }}
- name: LANGSMITH_SANDBOX_CALLBACK_SIGNING_JWK
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: sandbox_callback_signing_jwk
      optional: true
{{- end }}
{{- end }}
{{- end -}}

{{- define "langsmith.sandboxes.ingestQueueEnv" -}}
{{- if .Values.config.sandboxes.enabled }}
- name: SANDBOX_FEATURE_ENABLED
  value: "true"
- name: SMITHBOX_CONTROL_URL
  value: {{ include "langsmith.sandboxes.smithboxControlUrl" . | quote }}
- name: SANDBOX_SNAPSHOT_SERVICE_URL
  value: {{ include "langsmith.sandboxes.smithboxControlUrl" . | quote }}
- name: SANDBOX_K8S_CLUSTER_NAME
  value: {{ .Values.config.sandboxes.clusterName | quote }}
{{- if .Values.config.sandboxes.defaultBlueprintImage }}
- name: SANDBOX_DEFAULT_BLUEPRINT_IMAGE
  value: {{ .Values.config.sandboxes.defaultBlueprintImage | quote }}
{{- end }}
- name: SANDBOX_QUEUE_PRIORITY
  value: "1"
- name: SANDBOX_X_SERVICE_AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "langsmith.secretsName" . }}
      key: sandbox_x_service_auth_jwt_secret
      optional: {{ .Values.config.disableSecretCreation }}
{{- end }}
{{- end -}}

{{/*
Return config.hostname as an absolute URL.
If no scheme is provided, default to https://, except localhost-style hosts
which default to http:// for local development.
*/}}
{{- define "langsmith.hostnameWithProtocol" -}}
{{- if .Values.config.hostname -}}
  {{- $hostname := .Values.config.hostname -}}
  {{- if regexMatch "^[a-zA-Z][a-zA-Z0-9+.-]*://" $hostname -}}
    {{- $hostname -}}
  {{- else if regexMatch "^(localhost|127\\.0\\.0\\.1|\\[::1\\])(?::[0-9]+)?(?:/.*)?$" $hostname -}}
    {{- printf "http://%s" $hostname -}}
  {{- else -}}
    {{- printf "https://%s" $hostname -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
OAuth Authorization Server issuer URL advertised to remote MCP clients.
Derived from <hostnameWithProtocol>[/basePath]/api. The /api path is fixed because the
frontend nginx routes are hardcoded to it; host and scheme come from config.hostname.
*/}}
{{- define "langsmith.oauthAsIssuer" -}}
{{- include "langsmith.hostnameWithProtocol" . }}{{- with .Values.config.basePath }}/{{ . }}{{- end }}/api
{{- end -}}

{{/*
Public URL for the default Agent Builder MCP server.
Served through the frontend at /mcp (or /<basePath>/mcp).
*/}}
{{- define "langsmith.defaultMcpServerUrl" -}}
{{- if and (or .Values.config.agentBuilder.enabled .Values.fleet.enabled) .Values.config.hostname -}}
  {{- $baseURL := include "langsmith.hostnameWithProtocol" . | trimSuffix "/" -}}
  {{- $basePath := trimAll "/" (default "" .Values.config.basePath) -}}
  {{- if $basePath -}}
    {{- printf "%s/%s/mcp" $baseURL $basePath -}}
  {{- else -}}
    {{- printf "%s/mcp" $baseURL -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "agentBuilderOAuthEnvVars" -}}
{{- $googleOAuth := .Values.config.agentBuilder.oauth.googleOAuthProvider | default .Values.fleet.oauth.googleOAuthProvider }}
{{- $slackOAuth := .Values.config.agentBuilder.oauth.slackOAuthProvider | default .Values.fleet.oauth.slackOAuthProvider }}
{{- $linkedinOAuth := .Values.config.agentBuilder.oauth.linkedinOAuthProvider | default .Values.fleet.oauth.linkedinOAuthProvider }}
{{- $linearOAuth := .Values.config.agentBuilder.oauth.linearOAuthProvider | default .Values.fleet.oauth.linearOAuthProvider }}
{{- $githubOAuth := .Values.config.agentBuilder.oauth.githubOAuthProvider | default .Values.fleet.oauth.githubOAuthProvider }}
{{- $microsoftOAuth := .Values.config.agentBuilder.oauth.microsoftOAuthProvider | default .Values.fleet.oauth.microsoftOAuthProvider }}
{{- $salesforceOAuth := .Values.config.agentBuilder.oauth.salesforceOAuthProvider | default .Values.fleet.oauth.salesforceOAuthProvider }}
{{- if $googleOAuth }}
- name: "GOOGLE_OAUTH_PROVIDER"
  value: {{ $googleOAuth | quote }}
{{- end }}
{{- if $slackOAuth }}
- name: "SLACK_OAUTH_PROVIDER"
  value: {{ $slackOAuth | quote }}
{{- end }}
{{- if $linkedinOAuth }}
- name: "LINKEDIN_OAUTH_PROVIDER"
  value: {{ $linkedinOAuth | quote }}
{{- end }}
{{- if $linearOAuth }}
- name: "LINEAR_OAUTH_PROVIDER"
  value: {{ $linearOAuth | quote }}
{{- end }}
{{- if $githubOAuth }}
- name: "GITHUB_OAUTH_PROVIDER"
  value: {{ $githubOAuth | quote }}
{{- end }}
{{- if $microsoftOAuth }}
- name: "MICROSOFT_OAUTH_PROVIDER"
  value: {{ $microsoftOAuth | quote }}
{{- end }}
{{- if $salesforceOAuth }}
- name: "SALESFORCE_OAUTH_PROVIDER"
  value: {{ $salesforceOAuth | quote }}
{{- end }}
{{- end -}}

{{- define "fleetToolServerEnvVars" -}}
- name: "PORT"
  value: "{{ .Values.fleetToolServer.containerPort }}"
{{- include "agentBuilderOAuthEnvVars" . }}
{{- end -}}

{{- define "fleetTriggerServerEnvVars" -}}
{{- $ns := .Values.namespace | default .Release.Namespace -}}
{{- $cd := .Values.clusterDomain -}}
- name: "PORT"
  value: "{{ .Values.fleetTriggerServer.containerPort }}"
- name: "TRIGGER_SERVER_HOST_API_URL"
  value: "http://{{ include "langsmith.fullname" . }}-{{ .Values.hostBackend.name }}.{{ $ns }}.svc.{{ $cd }}:{{ .Values.hostBackend.service.port }}"
{{- if .Values.fleet.enabled }}
{{- $fleetApi := printf "http://%s.%s.svc.%s:%v" (include "langsmith.agentFeatures.apiServerK8sServiceName" (dict "root" . "product" "fleet")) $ns $cd .Values.fleet.apiServer.service.httpPort }}
- name: "LANGGRAPH_API_URL"
  value: {{ $fleetApi | quote }}
- name: "LANGGRAPH_API_URL_PUBLIC"
  value: {{ $fleetApi | quote }}
{{- end }}
{{- include "agentBuilderOAuthEnvVars" . }}
{{- $slackSigningSecret := .Values.config.agentBuilder.oauth.slackSigningSecret | default .Values.fleet.oauth.slackSigningSecret }}
{{- $slackBotId := .Values.config.agentBuilder.oauth.slackBotId | default .Values.fleet.oauth.slackBotId }}
{{- if $slackSigningSecret }}
- name: "SLACK_SIGNING_SECRET"
  value: {{ $slackSigningSecret | quote }}
{{- end }}
{{- if $slackBotId }}
- name: "AGENT_BUILDER_SLACK_BOT_ID"
  value: {{ $slackBotId | quote }}
{{- end }}
{{- end -}}
