{{- define "langsmithSandbox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "langsmithSandbox.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "langsmithSandbox.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end -}}

{{- /* helm.sh/chart is a label value, so it is capped at 63 characters. A chart
version carrying SemVer build metadata can exceed that once "+" becomes "_",
which renders an invalid object the API server rejects. Truncate as the sibling
charts do rather than inlining the printf. */}}
{{- define "langsmithSandbox.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "langsmithSandbox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langsmithSandbox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "langsmithSandbox.labels" -}}
helm.sh/chart: {{ include "langsmithSandbox.chart" . }}
{{ include "langsmithSandbox.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "langsmithSandbox.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "langsmithSandbox.commonPodAnnotations" -}}
{{- with .Values.commonPodAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "langsmithSandbox.podSecurityContext" -}}
{{- $merged := merge .componentSecurityContext .Values.commonPodSecurityContext -}}
{{- toYaml $merged -}}
{{- end -}}

{{- define "langsmithSandbox.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "langsmithSandbox.image" -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ .Values.images.sandboxHost.repository }}:{{ .Values.images.sandboxHost.tag | default .Chart.AppVersion }}
{{- else -}}
{{ .Values.images.sandboxHost.repository }}:{{ .Values.images.sandboxHost.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}

{{- define "langsmithSandbox.sandboxHostFullname" -}}
{{- printf "%s-%s" (include "langsmithSandbox.fullname" .) .Values.sandboxHost.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "langsmithSandbox.serviceAccountName" -}}
{{- if .Values.sandboxHost.serviceAccount.create -}}
{{- default (include "langsmithSandbox.sandboxHostFullname" .) .Values.sandboxHost.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default "default" .Values.sandboxHost.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "langsmithSandbox.serviceAuthSecretName" -}}
{{- .Values.serviceAuth.existingSecretName -}}
{{- end -}}

{{- define "langsmithSandbox.proxyCaSecretName" -}}
{{- if eq .Values.proxyCa.mode "existingSecret" -}}
{{- .Values.proxyCa.existingSecretName -}}
{{- else -}}
{{- default "smithbox-proxy-ca" .Values.proxyCa.secretName -}}
{{- end -}}
{{- end -}}

{{- define "langsmithSandbox.juicefsConfigSecretName" -}}
{{- default (printf "%s-juicefs-config" (include "langsmithSandbox.fullname" .)) .Values.juicefs.existingSecretName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "langsmithSandbox.juicefsConfigSecretData" -}}
name: {{ .Values.juicefs.name | quote }}
metaurl: {{ .Values.juicefs.redis.metaURL | quote }}
storage: {{ .Values.juicefs.storage | quote }}
bucket: {{ .Values.juicefs.bucket | quote }}
{{- if eq .Values.juicefs.storage "wasb" }}
access-key: {{ .Values.juicefs.storageAccountName | quote }}
{{- end }}
{{- end -}}

{{- define "langsmithSandbox.juicefsConfigSecretChecksum" -}}
{{- if .Values.juicefs.existingSecretName -}}
{{- printf "existing:%s" (include "langsmithSandbox.juicefsConfigSecretName" .) | sha256sum -}}
{{- else -}}
{{- include "langsmithSandbox.juicefsConfigSecretData" . | sha256sum -}}
{{- end -}}
{{- end -}}

{{- /* A Job's spec.template is immutable, so every value that lands in the pod
spec has to be part of the name hash. Otherwise changing one leaves the name
fixed and the next helm upgrade fails on the immutable field instead of rolling
a fresh formatter. */}}
{{- define "langsmithSandbox.juicefsFormatJobName" -}}
{{- $job := .Values.juicefsFormatJob -}}
{{- $inputs := dict
  "chartVersion" .Chart.Version
  "config" (include "langsmithSandbox.juicefsConfigSecretChecksum" .)
  "image" (include "langsmithSandbox.image" .)
  "pullPolicy" .Values.images.sandboxHost.pullPolicy
  "pullSecrets" .Values.images.imagePullSecrets
  "labels" $job.labels
  "annotations" $job.annotations
  "podSecurityContext" (include "langsmithSandbox.podSecurityContext" (dict "Values" .Values "componentSecurityContext" $job.podSecurityContext))
  "securityContext" $job.securityContext
  "resources" $job.resources
  "serviceAccount" (include "langsmithSandbox.serviceAccountName" .)
  "nodeSelector" (default .Values.sandboxHost.deployment.nodeSelector $job.nodeSelector)
  "tolerations" (default .Values.sandboxHost.deployment.tolerations $job.tolerations)
  "affinity" $job.affinity
  "dnsConfig" (include "langsmithSandbox.dnsConfig" .)
-}}
{{- printf "%s-juicefs-format-%s" (include "langsmithSandbox.fullname" .) (toJson $inputs | sha256sum | trunc 8) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "langsmithSandbox.detectDuplicates" -}}
{{- $keyCounts := dict -}}
{{- $duplicates := list -}}
{{- range $val := . }}
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
