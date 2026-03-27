{{/*
Expand the name of the chart.
*/}}
{{- define "authProxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "authProxy.fullname" -}}
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
{{- define "authProxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "authProxy.labels" -}}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
helm.sh/chart: {{ include "authProxy.chart" . }}
{{ include "authProxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "authProxy.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
helm.sh/chart: {{ include "authProxy.chart" . }}
{{ include "authProxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common pod annotations
*/}}
{{- define "authProxy.commonPodAnnotations" -}}
{{- if .Values.commonPodAnnotations }}
{{ toYaml .Values.commonPodAnnotations }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "authProxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "authProxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Template for merging commonPodSecurityContext with component-specific podSecurityContext.
Component-specific values take precedence over common values.
*/}}
{{- define "authProxy.podSecurityContext" -}}
{{- $merged := merge .componentSecurityContext .Values.commonPodSecurityContext -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Creates the image reference used for deployments. If registry is specified, concatenate it, along with a '/'.
*/}}
{{- define "authProxy.image" -}}
{{- $imageConfig := index .Values.images .component -}}
{{- if .Values.images.registry -}}
{{ .Values.images.registry }}/{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- else -}}
{{ $imageConfig.repository }}:{{ $imageConfig.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end -}}

{{/*
Extract hostname from a URL string.
Usage: include "authProxy.urlHostname" "http://example.com:8080"
*/}}
{{- define "authProxy.urlHostname" -}}
{{- $url := urlParse . -}}
{{- $parts := splitList ":" $url.host -}}
{{- index $parts 0 -}}
{{- end -}}

{{/*
Extract port from a URL string. Defaults to 443 for https, 80 for http.
Usage: include "authProxy.urlPort" "http://example.com:8080"
*/}}
{{- define "authProxy.urlPort" -}}
{{- $url := urlParse . -}}
{{- $parts := splitList ":" $url.host -}}
{{- if gt (len $parts) 1 -}}
{{- index $parts 1 -}}
{{- else -}}
{{- if eq $url.scheme "https" -}}443{{- else -}}80{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common DNS configuration for all pods. When commonDnsConfig is set, it will be applied to all pods.
*/}}
{{- define "authProxy.dnsConfig" -}}
{{- if .Values.commonDnsConfig }}
dnsConfig:
  {{- toYaml .Values.commonDnsConfig | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Determine whether the upstream hostname should use the HTTP proxy.
Returns "true" if proxy should be used, "false" if the hostname matches a noProxy entry.
Usage: include "authProxy.shouldUseProxy" (dict "hostname" $hostname "noProxy" .Values.authProxy.httpProxy.noProxy)
*/}}
{{- define "authProxy.shouldUseProxy" -}}
{{- $hostname := .hostname -}}
{{- $noProxy := .noProxy -}}
{{- $result := dict "bypass" false -}}
{{- range $entry := $noProxy -}}
  {{- if eq $entry "*" -}}
    {{- $_ := set $result "bypass" true -}}
  {{- else if eq $entry $hostname -}}
    {{- $_ := set $result "bypass" true -}}
  {{- else if and (hasPrefix "." $entry) (hasSuffix $entry $hostname) -}}
    {{- $_ := set $result "bypass" true -}}
  {{- end -}}
{{- end -}}
{{- if $result.bypass -}}false{{- else -}}true{{- end -}}
{{- end -}}

{{/*
Normalized custom CA values and paths.
*/}}
{{- define "authProxy.customCaSecretName" -}}
{{- .Values.customCa.secretName | default "" | trim -}}
{{- end -}}

{{- define "authProxy.customCaSecretKey" -}}
{{- .Values.customCa.secretKey | default "" | trim -}}
{{- end -}}

{{- define "authProxy.customCaRolloutToken" -}}
{{- .Values.customCa.rolloutToken | default "" | trim -}}
{{- end -}}

{{- define "authProxy.customCaEnabled" -}}
{{- $secretName := include "authProxy.customCaSecretName" . -}}
{{- $secretKey := include "authProxy.customCaSecretKey" . -}}
{{- if and $secretName $secretKey -}}true{{- end -}}
{{- end -}}

{{- define "authProxy.customCaMountDir" -}}
/etc/langsmith/custom-ca
{{- end -}}

{{- define "authProxy.customCaFileName" -}}
ca.crt
{{- end -}}

{{- define "authProxy.customCaFilePath" -}}
{{- printf "%s/%s" (include "authProxy.customCaMountDir" .) (include "authProxy.customCaFileName" .) -}}
{{- end -}}

{{- define "authProxy.customCaRolloutHash" -}}
{{- $name := include "authProxy.customCaSecretName" . -}}
{{- $key := include "authProxy.customCaSecretKey" . -}}
{{- if and $name $key -}}
{{- dict "secretName" $name "secretKey" $key "rolloutToken" (include "authProxy.customCaRolloutToken" .) | toYaml | sha256sum -}}
{{- end -}}
{{- end -}}

{{/*
Client certificate helpers for mTLS with upstream services.
*/}}
{{- define "authProxy.mtlsSecretName" -}}
{{- .Values.mtls.secretName | default "" | trim -}}
{{- end -}}

{{- define "authProxy.mtlsCertKey" -}}
{{- .Values.mtls.certKey | default "" | trim -}}
{{- end -}}

{{- define "authProxy.mtlsKeyKey" -}}
{{- .Values.mtls.keyKey | default "" | trim -}}
{{- end -}}

{{- define "authProxy.mtlsRolloutToken" -}}
{{- .Values.mtls.rolloutToken | default "" | trim -}}
{{- end -}}

{{- define "authProxy.mtlsEnabled" -}}
{{- $secretName := include "authProxy.mtlsSecretName" . -}}
{{- $certKey := include "authProxy.mtlsCertKey" . -}}
{{- $keyKey := include "authProxy.mtlsKeyKey" . -}}
{{- if and $secretName $certKey $keyKey -}}true{{- end -}}
{{- end -}}

{{- define "authProxy.mtlsMountDir" -}}
/etc/langsmith/client-cert
{{- end -}}

{{- define "authProxy.mtlsCertFileName" -}}
tls.crt
{{- end -}}

{{- define "authProxy.mtlsKeyFileName" -}}
tls.key
{{- end -}}

{{- define "authProxy.mtlsFilePath" -}}
{{- printf "%s/%s" (include "authProxy.mtlsMountDir" .) (include "authProxy.mtlsCertFileName" .) -}}
{{- end -}}

{{- define "authProxy.mtlsKeyFilePath" -}}
{{- printf "%s/%s" (include "authProxy.mtlsMountDir" .) (include "authProxy.mtlsKeyFileName" .) -}}
{{- end -}}

{{- define "authProxy.mtlsRolloutHash" -}}
{{- $name := include "authProxy.mtlsSecretName" . -}}
{{- $certKey := include "authProxy.mtlsCertKey" . -}}
{{- $keyKey := include "authProxy.mtlsKeyKey" . -}}
{{- if and $name $certKey $keyKey -}}
{{- dict "secretName" $name "certKey" $certKey "keyKey" $keyKey "rolloutToken" (include "authProxy.mtlsRolloutToken" .) | toYaml | sha256sum -}}
{{- end -}}
{{- end -}}

{{/*
Renders the Envoy UpstreamTlsContext extras for custom CA and/or client certificate.
Combines validation_context and tls_certificates under a single common_tls_context
block to avoid duplicate YAML keys.
Usage: include "authProxy.envoyUpstreamTlsContextExtras" . | nindent N
*/}}
{{- define "authProxy.envoyUpstreamTlsContextExtras" -}}
{{- $customCa := include "authProxy.customCaEnabled" . -}}
{{- $mtls := include "authProxy.mtlsEnabled" . -}}
{{- if $customCa -}}
auto_sni_san_validation: true
{{- end -}}
{{- if or $customCa $mtls }}
common_tls_context:
  {{- if $customCa }}
  validation_context:
    trusted_ca:
      filename: {{ include "authProxy.customCaFilePath" . }}
  {{- end }}
  {{- if $mtls }}
  tls_certificates:
    - certificate_chain:
        filename: {{ include "authProxy.mtlsFilePath" . }}
      private_key:
        filename: {{ include "authProxy.mtlsKeyFilePath" . }}
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "authProxy.serviceAccountName" -}}
{{- if .Values.authProxy.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "authProxy.fullname" .) .Values.authProxy.name) .Values.authProxy.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.authProxy.serviceAccount.name }}
{{- end -}}
{{- end -}}
