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

{{- define "authProxy.serviceAccountName" -}}
{{- if .Values.authProxy.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "authProxy.fullname" .) .Values.authProxy.name) .Values.authProxy.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.authProxy.serviceAccount.name }}
{{- end -}}
{{- end -}}
