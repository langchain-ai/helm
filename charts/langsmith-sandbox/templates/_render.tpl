{{- /*
Object bodies for the sandbox runtime, shared by this chart and by the
langsmith chart's sameCluster mode (which depends on this chart only to call
these templates). Each caller computes names, labels, Secret references and
image from its own values and helpers and passes them in one dict, so neither
chart's object names or selectors depend on the other.

Common inputs:
  name, namespace        object name and namespace
  labels, annotations    metadata maps (already merged by the caller)
  sandboxHost            the sandboxHost values block
  juicefs                the juicefs values block
*/ -}}

{{- /*
langsmithSandbox.render.hostDeployment

  selectorLabels      map, Deployment selector and anti-affinity labels
  podLabelsOmit       label keys left off the pod template
  podAnnotations      map
  podSecurityContext  rendered YAML or ""
  dnsConfig           rendered dnsConfig block or ""
  serviceAccountName
  image, pullPolicy, pullSecrets
  initContainers      list (common, then the host's own)
  env                 dict:
    appVersion
    serviceAuth          {secretName, key, optional?}
    previousServiceAuth  {secretName, key, optional?} or empty
    sslCertFile          bool
    callbackJwk          {secretName, key, optional?}
    oauthIssuer          "" to omit
    egressProxy          {secretName, key, noProxy}
    internalEndpoint
    deploymentName
    extra                list (common env, then the host's extraEnv)
  extraVolumeMounts, extraVolumes   lists appended after the fixed ones
  juicefsConfigSecretName, proxyCaSecretName
*/ -}}
{{- define "langsmithSandbox.render.hostDeployment" -}}
{{- $in := . -}}
{{- $d := $in.sandboxHost.deployment -}}
{{- $autoscaling := $in.sandboxHost.autoscaling -}}
{{- $hostMount := $in.juicefs.hostMount -}}
{{- $env := $in.env -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $in.name }}
  namespace: {{ $in.namespace }}
  labels:
    {{- toYaml $in.labels | nindent 4 }}
  annotations:
    {{- with $in.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- toYaml $in.selectorLabels | nindent 6 }}
  {{- if not $autoscaling.enabled }}
  replicas: {{ $d.replicas }}
  {{- end }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
  template:
    metadata:
      {{- /* The caller drops labels that change on every chart or appVersion
      bump: a pod-template change rolls every host, suspending its VMs. */}}
      {{- $podLabels := deepCopy $in.labels }}
      {{- range $in.podLabelsOmit }}
      {{- $_ := unset $podLabels . }}
      {{- end }}
      labels:
        {{- toYaml $podLabels | nindent 8 }}
      annotations:
        {{- toYaml $in.podAnnotations | nindent 8 }}
    spec:
      {{- with $in.podSecurityContext }}
      securityContext:
        {{- . | nindent 8 }}
      {{- end }}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      {{- $in.dnsConfig | nindent 6 }}
      serviceAccountName: {{ $in.serviceAccountName }}
      automountServiceAccountToken: {{ $in.sandboxHost.serviceAccount.automountServiceAccountToken }}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            {{- /* One host per node; hostPort enforces it regardless. */}}
            - labelSelector:
                matchLabels:
                  {{- toYaml $in.selectorLabels | nindent 18 }}
              topologyKey: kubernetes.io/hostname
      {{- with $in.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $d.priorityClassName }}
      priorityClassName: {{ . }}
      {{- end }}
      {{- with $d.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $d.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $in.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: sandbox-host
          image: {{ $in.image | quote }}
          imagePullPolicy: {{ $in.pullPolicy }}
          env:
            - name: LANGCHAIN_ENV
              value: "local_kubernetes"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_UID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.uid
            - name: POD_HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            {{- /* The release this host runs (its image tag), reported for the
            control plane's version-skew warning. */}}
            - name: LANGSMITH_APP_VERSION
              value: {{ $env.appVersion | quote }}
            - name: SANDBOX_X_SERVICE_AUTH_JWT_SECRET
              {{- include "langsmithSandbox.render.secretKeyRef" $env.serviceAuth | nindent 14 }}
            {{- with $env.previousServiceAuth }}
            - name: SANDBOX_X_SERVICE_AUTH_JWT_SECRET_PREVIOUS
              {{- include "langsmithSandbox.render.secretKeyRef" . | nindent 14 }}
            {{- end }}
            - name: SANDBOX_HOST_PROXY_CA_DIR
              value: /certs
            {{- if $env.sslCertFile }}
            - name: SSL_CERT_FILE
              value: /etc/ssl/certs/custom-ca-certificates.crt
            {{- end }}
            - name: LANGSMITH_SANDBOX_CALLBACK_SIGNING_JWK
              {{- include "langsmithSandbox.render.secretKeyRef" $env.callbackJwk | nindent 14 }}
            {{- /* Receivers fetch the key from <issuer>/.well-known/jwks.json. */}}
            {{- with $env.oauthIssuer }}
            - name: OAUTH_AS_ISSUER
              value: {{ . | quote }}
            {{- end }}
            {{- /* Self-hosted reaches private addresses; SaaS is what blocks them. */}}
            - name: SSRF_ALLOW_PRIVATE_IPS_CALLBACKS
              value: "true"
            - name: SANDBOX_CALLBACK_LOOPBACK_REWRITE
              value: "false"
            {{- /* The URL may carry proxy credentials, so it always comes from the
            Secret; a missing key means direct egress. An https proxy is verified
            against SSL_CERT_FILE, the custom CA, when set. */}}
            - name: SANDBOX_EGRESS_UPSTREAM_PROXY_URL
              {{- include "langsmithSandbox.render.secretKeyRef" (dict "secretName" $env.egressProxy.secretName "key" $env.egressProxy.key "optional" true) | nindent 14 }}
            {{- with $env.egressProxy.noProxy }}
            - name: SANDBOX_EGRESS_UPSTREAM_PROXY_NO_PROXY
              value: {{ join "," . | quote }}
            {{- end }}
            - name: LANGSMITH_SANDBOX_INTERNAL_ENDPOINT
              value: {{ $env.internalEndpoint | quote }}
            - name: SANDBOX_HOST_DEPLOYMENT_NAME
              value: {{ $env.deploymentName | quote }}
            - name: SANDBOX_HOST_TERMINATION_GRACE_SECONDS
              value: {{ $d.terminationGracePeriodSeconds | quote }}
            - name: SANDBOX_HOST_JUICEFS_META_URL_FILE
              value: /run/secrets/juicefs/metaurl
            - name: SANDBOX_HOST_JUICEFS_MOUNT_OPTIONS
              value: {{ concat (list (printf "--cache-dir=%s" (join ":" $hostMount.cacheDirs))) $hostMount.mountOptions | toJson | quote }}
            {{- with ($in.juicefs.redis | default dict).iamAuthProvider }}
            - name: SANDBOX_HOST_JUICEFS_REDIS_IAM_AUTH_PROVIDER
              value: {{ . | quote }}
            {{- end }}
            {{- /* Baseline; autoscale-* annotations override it live. */}}
            - name: SANDBOX_HOST_AUTOSCALE_ENABLED
              value: {{ $autoscaling.enabled | quote }}
            {{- if $autoscaling.enabled }}
            - name: SANDBOX_HOST_AUTOSCALE_MIN_REPLICAS
              value: {{ $autoscaling.minReplicas | quote }}
            - name: SANDBOX_HOST_AUTOSCALE_MAX_REPLICAS
              value: {{ $autoscaling.maxReplicas | quote }}
            - name: SANDBOX_HOST_AUTOSCALE_TARGET_UTILIZATION_PERCENT
              value: {{ $autoscaling.targetUtilizationPercent | quote }}
            - name: SANDBOX_HOST_AUTOSCALE_HEADROOM_HOSTS
              value: {{ $autoscaling.headroomHosts | quote }}
            - name: SANDBOX_HOST_AUTOSCALE_SCALE_DOWN_STABILIZATION_SECONDS
              value: {{ $autoscaling.scaleDownStabilizationSeconds | quote }}
            {{- end }}
            {{- with $env.extra }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- /* Fixed: the host's own defaults. SANDBOX_HOST_LISTEN_ADDR is not set. */}}
          ports:
            - name: http
              containerPort: 19190
              hostPort: 19190
              protocol: TCP
          {{- with $d.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            {{- toYaml $d.securityContext | nindent 12 }}
          resources:
            {{- toYaml $d.resources | nindent 12 }}
          volumeMounts:
            - name: juicefs
              mountPath: /juicefs
            {{- range $index, $cacheDir := $hostMount.cacheDirs }}
            - name: juicefs-cache-{{ $index }}
              mountPath: {{ $cacheDir | quote }}
            {{- end }}
            - name: juicefs-meta
              mountPath: /run/secrets/juicefs
              readOnly: true
            - name: host-bin
              mountPath: /host-bin
            - name: proxy-ca
              mountPath: /certs
              readOnly: true
            {{- with $in.extraVolumeMounts }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
        {{- with $d.sidecars }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      volumes:
        - name: juicefs
          # Writable mount target. sandbox-host mounts JuiceFS over this directory.
          emptyDir: {}
        {{- range $index, $cacheDir := $hostMount.cacheDirs }}
        - name: juicefs-cache-{{ $index }}
          hostPath:
            path: {{ $cacheDir | quote }}
            type: DirectoryOrCreate
        {{- end }}
        - name: juicefs-meta
          secret:
            secretName: {{ $in.juicefsConfigSecretName }}
            defaultMode: 0400
            items:
              - key: metaurl
                path: metaurl
        - name: proxy-ca
          secret:
            secretName: {{ $in.proxyCaSecretName }}
        - name: host-bin
          hostPath:
            path: /var/lib/sandbox-host
            type: DirectoryOrCreate
        {{- with $in.extraVolumes }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      terminationGracePeriodSeconds: {{ $d.terminationGracePeriodSeconds }}
{{- end -}}

{{- /* A valueFrom.secretKeyRef; "optional" is written only when the caller sets it. */ -}}
{{- define "langsmithSandbox.render.secretKeyRef" -}}
valueFrom:
  secretKeyRef:
    name: {{ .secretName }}
    key: {{ .key }}
    {{- if hasKey . "optional" }}
    optional: {{ .optional }}
    {{- end }}
{{- end -}}

{{- /*
langsmithSandbox.render.formatJob

  job                 the juicefsFormatJob values block
  podLabels, podAnnotations   maps (podAnnotations may be empty)
  serviceAccountName
  hostNetwork         bool (GKE: join the host network for the node identity)
  dnsConfig           rendered dnsConfig block or ""
  podSecurityContext  rendered YAML
  image, pullPolicy, pullSecrets
  env                 rendered env list YAML
  extraVolumeMounts, extraVolumes   lists
  juicefsConfigSecretName
*/ -}}
{{- define "langsmithSandbox.render.formatJob" -}}
{{- $in := . -}}
{{- $job := $in.job -}}
{{- $d := $in.sandboxHost.deployment -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $in.name }}
  namespace: {{ $in.namespace }}
  labels:
    {{- toYaml $in.labels | nindent 4 }}
  annotations:
    {{- toYaml $in.annotations | nindent 4 }}
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  activeDeadlineSeconds: {{ $job.activeDeadlineSeconds }}
  template:
    metadata:
      {{- with $in.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- toYaml $in.podLabels | nindent 8 }}
    spec:
      serviceAccountName: {{ $in.serviceAccountName }}
      automountServiceAccountToken: {{ $in.sandboxHost.serviceAccount.automountServiceAccountToken }}
      {{- if $in.hostNetwork }}
      {{- /* GKE Workload Identity does not serve host-network pods and sandbox-host
      runs on the host network, so the formatter joins it there: both pods then
      authenticate as the node pool's service account. */}}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      {{- end }}
      {{- with $in.dnsConfig }}
      {{- . | nindent 6 }}
      {{- end }}
      restartPolicy: Never
      securityContext:
        {{- $in.podSecurityContext | nindent 8 }}
      {{- with $in.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (default $d.nodeSelector $job.nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $job.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (default $d.tolerations $job.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: juicefs-format
          image: {{ $in.image | quote }}
          imagePullPolicy: {{ $in.pullPolicy }}
          command:
            - /opt/sandbox-host/bin/sandbox-host
          args:
            - --internal-juicefs-format
          env:
            {{- $in.env | nindent 12 }}
          securityContext:
            {{- toYaml $job.securityContext | nindent 12 }}
          resources:
            {{- toYaml $job.resources | nindent 12 }}
          volumeMounts:
            - name: juicefs-config
              mountPath: /run/secrets/juicefs
              readOnly: true
            {{- with $in.extraVolumeMounts }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
      volumes:
        - name: juicefs-config
          secret:
            secretName: {{ $in.juicefsConfigSecretName }}
            defaultMode: 0400
        {{- with $in.extraVolumes }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
{{- end -}}

{{- /* langsmithSandbox.render.serviceAccount: name, namespace, labels, annotations, sandboxHost. */ -}}
{{- define "langsmithSandbox.render.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
automountServiceAccountToken: {{ .sandboxHost.serviceAccount.automountServiceAccountToken }}
{{- end -}}

{{- /* langsmithSandbox.render.pdb: name, namespace, labels, annotations, selectorLabels, sandboxHost. */ -}}
{{- define "langsmithSandbox.render.pdb" -}}
{{- $pdb := .sandboxHost.pdb -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- with .annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- toYaml .selectorLabels | nindent 6 }}
  {{- /* Only one may be set, so an explicit minAvailable wins over the default maxUnavailable. */}}
  {{- if hasKey $pdb "minAvailable" }}
  minAvailable: {{ $pdb.minAvailable }}
  {{- else if hasKey $pdb "maxUnavailable" }}
  maxUnavailable: {{ $pdb.maxUnavailable }}
  {{- end }}
{{- end -}}

{{- /* langsmithSandbox.render.rbac: name, namespace, labels, annotations, serviceAccountName. */ -}}
{{- define "langsmithSandbox.render.rbac" -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- with .annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
rules:
# Host liveness leases + leader election.
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - create
  - delete
  - get
  - list
  - update
  - watch
# The elected host reads and resizes its own Deployment.
- apiGroups:
  - apps
  resources:
  - deployments
  resourceNames:
  - {{ .name }}
  verbs:
  - get
  - patch
# Pod deletion cost, so the emptiest host is evicted first.
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- with .annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
subjects:
  - kind: ServiceAccount
    name: {{ .serviceAccountName }}
    namespace: {{ .namespace }}
roleRef:
  kind: Role
  name: {{ .name }}
  apiGroup: rbac.authorization.k8s.io
{{- end -}}

{{- /* langsmithSandbox.render.juicefsConfig: name, namespace, labels, annotations, data (rendered stringData). */ -}}
{{- define "langsmithSandbox.render.juicefsConfig" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
type: Opaque
stringData:
{{ .data | indent 2 }}
{{- end -}}

{{- /* langsmithSandbox.render.proxyCa: name, namespace, labels, annotations. Keeps the CA it finds, otherwise generates one. */ -}}
{{- define "langsmithSandbox.render.proxyCa" -}}
{{- $existing := lookup "v1" "Secret" .namespace .name -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  namespace: {{ .namespace }}
  labels:
    {{- toYaml .labels | nindent 4 }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
type: kubernetes.io/tls
data:
  {{- if $existing }}
  tls.crt: {{ index $existing.data "tls.crt" | quote }}
  tls.key: {{ index $existing.data "tls.key" | quote }}
  {{- else }}
  {{- $ca := genCA "smithbox-proxy-ca" 3650 }}
  tls.crt: {{ $ca.Cert | b64enc | quote }}
  tls.key: {{ $ca.Key | b64enc | quote }}
  {{- end }}
{{- end -}}
