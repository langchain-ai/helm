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
{{- /* With localStorage the host plans its local disks itself: the JuiceFS
cache dirs and size, ephemeral sandbox disks, and room for received live
migrations. It refuses operator cache options, so cacheDirs and the cache
mount options are dropped. Without paths, the pod's own scratch storage backs
it and the budget becomes the pod's ephemeral-storage request. */ -}}
{{- $localStorage := $in.sandboxHost.localStorage | default dict -}}
{{- $localStorageEnabled := $localStorage.enabled | default false -}}
{{- $localStorageBudgetGiB := int64 ($localStorage.budgetGiB | default 0) -}}
{{- $localStorageEphemeralReserveGiB := int64 ($localStorage.ephemeralReserveGiB | default 0) -}}
{{- $localStoragePaths := $localStorage.paths | default list -}}
{{- $localStorageMountPaths := list -}}
{{- $mountOptions := list -}}
{{- if $localStorageEnabled -}}
{{- range $index, $path := ($localStoragePaths | default (list "")) -}}
{{- $localStorageMountPaths = append $localStorageMountPaths (printf "/var/lib/sandbox-host-local/%d" $index) -}}
{{- end -}}
{{- range $option := $hostMount.mountOptions -}}
{{- if not (has (trimPrefix "-" (trimPrefix "-" (first (splitList "=" $option)))) (list "cache-dir" "cache-size" "free-space-ratio")) -}}
{{- $mountOptions = append $mountOptions $option -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{- $mountOptions = concat (list (printf "--cache-dir=%s" (join ":" $hostMount.cacheDirs))) $hostMount.mountOptions -}}
{{- end -}}
{{- $resources := deepCopy ($d.resources | default dict) -}}
{{- if and $localStorageEnabled (empty $localStoragePaths) -}}
{{- /* A request, not a limit: exceeding a limit evicts the pod and every VM on it. */ -}}
{{- $requests := $resources.requests | default dict -}}
{{- $_ := set $requests "ephemeral-storage" (printf "%dGi" $localStorageBudgetGiB) -}}
{{- $_ := set $resources "requests" $requests -}}
{{- end -}}
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
              value: {{ $mountOptions | toJson | quote }}
            {{- if $localStorageEnabled }}
            - name: SANDBOX_HOST_LOCAL_STORAGE_DIRS
              value: {{ join ":" $localStorageMountPaths | quote }}
            {{- if gt $localStorageBudgetGiB 0 }}
            - name: SANDBOX_HOST_LOCAL_STORAGE_BUDGET_BYTES
              value: {{ mul $localStorageBudgetGiB 1073741824 | toString | quote }}
            {{- end }}
            {{- if gt $localStorageEphemeralReserveGiB 0 }}
            - name: SANDBOX_HOST_LOCAL_STORAGE_EPHEMERAL_RESERVE_BYTES
              value: {{ mul $localStorageEphemeralReserveGiB 1073741824 | toString | quote }}
            {{- end }}
            {{- end }}
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
            {{- toYaml $resources | nindent 12 }}
          volumeMounts:
            - name: juicefs
              mountPath: /juicefs
            {{- if $localStorageEnabled }}
            {{- range $index, $mountPath := $localStorageMountPaths }}
            - name: local-storage-{{ $index }}
              mountPath: {{ $mountPath | quote }}
            {{- end }}
            {{- else }}
            {{- range $index, $cacheDir := $hostMount.cacheDirs }}
            - name: juicefs-cache-{{ $index }}
              mountPath: {{ $cacheDir | quote }}
            {{- end }}
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
        {{- if and $localStorageEnabled $localStoragePaths }}
        {{- range $index, $path := $localStoragePaths }}
        - name: local-storage-{{ $index }}
          hostPath:
            path: {{ $path | quote }}
            type: DirectoryOrCreate
        {{- end }}
        {{- else if $localStorageEnabled }}
        # The pod's scratch storage, with no sizeLimit: exceeding one evicts the
        # pod and every VM on it. The host keeps itself under budgetGiB instead.
        - name: local-storage-0
          emptyDir: {}
        {{- else }}
        {{- range $index, $cacheDir := $hostMount.cacheDirs }}
        - name: juicefs-cache-{{ $index }}
          hostPath:
            path: {{ $cacheDir | quote }}
            type: DirectoryOrCreate
        {{- end }}
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

{{- /*
langsmithSandbox.validate.localStorage fails on an invalid localStorage block.

  localStorage   the sandboxHost.localStorage values block
  prefix         its values path, for messages
*/ -}}
{{- define "langsmithSandbox.validate.localStorage" -}}
{{- $ls := .localStorage | default dict -}}
{{- $p := .prefix -}}
{{- if $ls.enabled -}}
{{- range $key := list "budgetGiB" "ephemeralReserveGiB" -}}
{{- $v := index $ls $key | default 0 -}}
{{- if not (or (kindIs "int" $v) (kindIs "int64" $v) (and (kindIs "float64" $v) (eq (float64 $v) (floor (float64 $v))))) -}}
{{- fail (printf "%s.%s must be a whole number of GiB." $p $key) -}}
{{- end -}}
{{- if lt (int64 $v) 0 -}}
{{- fail (printf "%s.%s must not be negative." $p $key) -}}
{{- end -}}
{{- end -}}
{{- $budget := int64 ($ls.budgetGiB | default 0) -}}
{{- /* sandbox-host refuses to start with less: margin, jailer, scratch and a minimal cache. */ -}}
{{- if and (gt $budget 0) (lt $budget 24) -}}
{{- fail (printf "%s.budgetGiB must be at least 24 when set." $p) -}}
{{- end -}}
{{- if not (kindIs "slice" ($ls.paths | default list)) -}}
{{- fail (printf "%s.paths must be a list." $p) -}}
{{- end -}}
{{- if and (empty $ls.paths) (eq $budget 0) -}}
{{- fail (printf "%s.budgetGiB is required when paths is empty: the pod's scratch storage backs local storage, and the budget is its ephemeral-storage request." $p) -}}
{{- end -}}
{{- $seen := dict -}}
{{- range $path := $ls.paths -}}
{{- if not (kindIs "string" $path) -}}
{{- fail (printf "%s.paths entries must be strings." $p) -}}
{{- end -}}
{{- if or (eq $path "/") (not (hasPrefix "/" $path)) (ne (clean $path) $path) (contains ":" $path) -}}
{{- fail (printf "%s.paths entry %q must be a normalized absolute path other than / and must not contain ':'." $p $path) -}}
{{- end -}}
{{- if hasKey $seen $path -}}
{{- fail (printf "%s.paths contains duplicate path %q." $p $path) -}}
{{- end -}}
{{- $_ := set $seen $path true -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* Env the chart owns with localStorage enabled, for the callers' duplicate
check. SANDBOX_HOST_EPHEMERAL_ROOT is listed because the host refuses to start
with it beside SANDBOX_HOST_LOCAL_STORAGE_DIRS. */ -}}
{{- define "langsmithSandbox.localStorageManagedEnv" -}}
- name: SANDBOX_HOST_LOCAL_STORAGE_DIRS
- name: SANDBOX_HOST_LOCAL_STORAGE_BUDGET_BYTES
- name: SANDBOX_HOST_LOCAL_STORAGE_EPHEMERAL_RESERVE_BYTES
- name: SANDBOX_HOST_EPHEMERAL_ROOT
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
