{{/*
Expand the name of the chart.
*/}}
{{- define "langGraphCloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "langGraphCloud.fullname" -}}
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
{{- define "langGraphCloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langGraphCloud.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "langGraphCloud.chart" . }}
{{ include "langGraphCloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "langGraphCloud.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "langGraphCloud.chart" . }}
{{ include "langGraphCloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langGraphCloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langGraphCloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the secret containing the secrets for this chart. This can be overriden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langGraphCloud.secretsName" -}}
{{- if .Values.config.existingSecretName }}
{{- .Values.config.existingSecretName }}
{{- else }}
{{- include "langGraphCloud.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for postgres. This can be overriden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langGraphCloud.postgresSecretsName" -}}
{{- if .Values.postgres.external.existingSecretName }}
{{- .Values.postgres.external.existingSecretName }}
{{- else }}
{{- include "langGraphCloud.fullname" . }}-postgres
{{- end }}
{{- end }}

{{/*
Name of the secret containing the secrets for redis. This can be overriden by a secrets file created by
the user or some other secret provisioning mechanism
*/}}
{{- define "langGraphCloud.redisSecretsName" -}}
{{- if .Values.redis.external.existingSecretName }}
{{- .Values.redis.external.existingSecretName }}
{{- else }}
{{- include "langGraphCloud.fullname" . }}-redis
{{- end }}
{{- end }}

{{/*
Common DNS configuration for all pods. When commonDnsConfig is set, it will be applied to all pods.
*/}}
{{- define "langGraphCloud.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Name of the secret containing the MongoDB URI for the optional Mongo checkpointer default.
*/}}
{{- define "langGraphCloud.mongoSecretsName" -}}
{{- if and .Values.mongo.external.enabled .Values.mongo.external.existingSecretName }}
{{- .Values.mongo.external.existingSecretName }}
{{- else }}
{{- include "langGraphCloud.fullname" . }}-mongo
{{- end }}
{{- end }}

{{/*
Name of the Service backing the chart-managed MongoDB instance.
*/}}
{{- define "langGraphCloud.mongoServiceName" -}}
{{- include "langGraphCloud.fullname" . }}-mongo
{{- end }}

{{/*
Stable DNS name for the primary member of the chart-managed single-node MongoDB replica set.
*/}}
{{- define "langGraphCloud.mongoPrimaryHost" -}}
{{- printf "%s.%s.svc.%s:%v" (include "langGraphCloud.mongoServiceName" .) (default .Release.Namespace .Values.namespace) .Values.clusterDomain 27017 -}}
{{- end }}

{{/*
MongoDB connection URL used by the chart-managed checkpointer default.
*/}}
{{- define "langGraphCloud.mongoConnectionUrl" -}}
{{- if and .Values.mongo.enabled (not .Values.mongo.external.enabled) -}}
{{- printf "mongodb://%s/langgraph?replicaSet=rs0" (include "langGraphCloud.mongoPrimaryHost" .) -}}
{{- else -}}
{{- .Values.mongo.external.connectionUrl -}}
{{- end -}}
{{- end }}

{{/*
Validates MongoDB provisioning and default-checkpointer settings.
*/}}
{{- define "langGraphCloud.validateMongoConfiguration" -}}
{{- if and (hasKey .Values.mongo "resources") (not (empty .Values.mongo.resources)) -}}
{{- fail "mongo.resources has moved to mongo.statefulSet.resources; update your values file to use the new path" -}}
{{- end -}}
{{- if and (hasKey .Values.mongo "persistence") (not (empty .Values.mongo.persistence)) -}}
{{- fail "mongo.persistence has moved to mongo.statefulSet.persistence; update your values file to use the new path" -}}
{{- end -}}
{{- if and (not .Values.mongo.enabled) .Values.mongo.external.enabled -}}
{{- fail "mongo.external.enabled requires mongo.enabled=true" -}}
{{- end -}}
{{- if and .Values.mongo.external.enabled (not .Values.mongo.external.existingSecretName) (empty .Values.mongo.external.connectionUrl) -}}
{{- fail "mongo.external.connectionUrl must be set or mongo.external.existingSecretName must be provided when mongo.external.enabled=true" -}}
{{- end -}}
{{- if and .Values.mongo.enabled (not .Values.mongo.external.enabled) (empty .Values.mongo.statefulSet.persistence.size) -}}
{{- fail "mongo.statefulSet.persistence.size must be set when mongo.enabled=true and using the bundled MongoDB instance" -}}
{{- end -}}
{{- end }}

{{/*
Environment variables used to default agent server checkpointers without overriding app-level LANGGRAPH_CHECKPOINTER.
*/}}
{{- define "langGraphCloud.checkpointerEnv" -}}
{{- $root := .root | default . -}}
{{- include "langGraphCloud.validateMongoConfiguration" $root -}}
{{- if $root.Values.mongo.enabled }}
- name: LS_DEFAULT_CHECKPOINTER_BACKEND
  value: "mongo"
- name: LS_MONGODB_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "langGraphCloud.mongoSecretsName" $root }}
      key: mongodb_connection_url
{{- end }}
{{- end }}
{{- define "apiServer.serviceAccountName" -}}
{{- if .Values.apiServer.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langGraphCloud.fullname" .) .Values.apiServer.name) .Values.apiServer.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.apiServer.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "queue.serviceAccountName" -}}
{{- if .Values.queue.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langGraphCloud.fullname" .) .Values.queue.name) .Values.queue.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.queue.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "postgres.serviceAccountName" -}}
{{- if .Values.postgres.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langGraphCloud.fullname" .) .Values.postgres.name) .Values.postgres.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.postgres.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis.serviceAccountName" -}}
{{- if .Values.redis.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "langGraphCloud.fullname" .) .Values.redis.name) .Values.redis.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.redis.serviceAccount.name }}
{{- end -}}
{{- end -}}


{{/*
Creates the image reference used for LangGraph Cloud deployments. If registry is specified, concatenate it, along with a '/'.
*/}}
{{- define "langGraphCloud.image" -}}
{{- $imageConfig := index .Values.images .component -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}
