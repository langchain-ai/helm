{{- define "agentFeatures.postgres.secrets" -}}
{{- if not .Values.postgres.external.existingSecretName }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "langGraphCloud.postgresSecretsName" .}}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
data:
  {{- if .Values.postgres.external.enabled }}
  {{- if .Values.postgres.external.connectionUrl }}
  postgres_connection_url: {{ .Values.postgres.external.connectionUrl | b64enc }}
  {{- else }}
  postgres_connection_url: {{ printf "postgres://%s:%s@%s:%s/%s?sslmode=disable" .Values.postgres.external.user .Values.postgres.external.password .Values.postgres.external.host (toString .Values.postgres.external.port) .Values.postgres.external.database | b64enc }}
  {{- end }}
  {{- else }}
  postgres_user: {{ .Values.postgres.external.user | b64enc }}
  postgres_password: {{ .Values.postgres.external.password | b64enc }}
  postgres_db: {{ .Values.postgres.external.database | b64enc }}
  postgres_connection_url: {{ printf "postgres://%s:%s@%s-%s.%s.svc.%s:%s/%s?sslmode=disable" .Values.postgres.external.user .Values.postgres.external.password (include "langGraphCloud.fullname" .) .Values.postgres.name (default .Release.Namespace .Values.namespace) .Values.clusterDomain (toString .Values.postgres.service.port) .Values.postgres.external.database | b64enc }}
  {{- end}}
{{- end }}
{{- end -}}

{{- define "agentFeatures.postgres.stateful-set" -}}
{{- if not .Values.postgres.external.enabled }}
{{- $volumes := concat .Values.commonVolumes .Values.postgres.statefulSet.volumes -}}
{{- $volumeMounts := concat .Values.commonVolumeMounts .Values.postgres.statefulSet.volumeMounts -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.postgres.statefulSet.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.postgres.statefulSet.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  serviceName: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  replicas: 1
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  template:
    metadata:
      {{- with .Values.postgres.statefulSet.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- with.Values.postgres.statefulSet.labels }}
            {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- include "langGraphCloud.labels" . | nindent 8 }}
        app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
    spec:
      {{- with .Values.images.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.postgres.statefulSet.priorityClassName }}
      priorityClassName: {{ .Values.postgres.statefulSet.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.postgres.statefulSet.terminationGracePeriodSeconds }}
      securityContext:
        {{- toYaml .Values.postgres.statefulSet.podSecurityContext | nindent 8 }}
      serviceAccountName: {{ include "postgres.serviceAccountName" . }}
      {{- include "langGraphCloud.dnsConfig" . | nindent 6 }}
      containers:
        - name: {{ .Values.postgres.name }}
          {{- with.Values.postgres.statefulSet.command }}
          command:
             {{ . }}
          {{- end }}
          env:
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.postgresSecretsName" .}}
                  key: postgres_db
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.postgresSecretsName" .}}
                  key: postgres_password
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.postgresSecretsName" .}}
                  key: postgres_user
            - name: PGDATA
              value: /var/lib/postgresql/data/postgres
            {{- with .Values.postgres.statefulSet.extraEnv }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          image: {{ include "langGraphCloud.image" (dict "Values" .Values "Chart" .Chart "component" "postgresImage") | quote }}
          imagePullPolicy: {{ .Values.images.postgresImage.pullPolicy }}
          ports:
            - name: postgres
              containerPort: {{ .Values.postgres.containerPort }}
              protocol: TCP
          startupProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -d postgres -U postgres
            failureThreshold: 6
            periodSeconds: 10
            timeoutSeconds: 1
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -d postgres -U postgres
            failureThreshold: 6
            periodSeconds: 10
            timeoutSeconds: 1
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -d postgres -U postgres
            failureThreshold: 6
            periodSeconds: 10
            timeoutSeconds: 1
          resources:
            {{- toYaml .Values.postgres.statefulSet.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.postgres.statefulSet.securityContext | nindent 12 }}
          {{- with .Values.postgres.statefulSet.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          volumeMounts:
            {{- with $volumeMounts }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- if .Values.postgres.statefulSet.persistence.enabled }}
            - mountPath: /var/lib/postgresql/data
              name: data
              subPath: postgres
            {{- end }}
          {{- with .Values.postgres.statefulSet.extraContainerConfig }}
            {{- toYaml . | nindent 10 }}
          {{- end }}
        {{- with .Values.postgres.statefulSet.sidecars }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.postgres.statefulSet.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.postgres.statefulSet.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.postgres.statefulSet.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $volumes }}
      volumes:
          {{- toYaml . | nindent 8 }}
      {{- end }}
 {{- if .Values.postgres.statefulSet.persistence.enabled }}
  {{- with .Values.postgres.statefulSet.persistentVolumeClaimRetentionPolicy }}
  persistentVolumeClaimRetentionPolicy:
        {{- toYaml . | nindent 4 }}
  {{- end }}
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
        labels:
          {{- include "langGraphCloud.selectorLabels" . | nindent 10 }}
          app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
      spec:

        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: {{ .Values.postgres.statefulSet.persistence.size }}
        {{- if .Values.postgres.statefulSet.persistence.storageClassName }}
        storageClassName: {{ .Values.postgres.statefulSet.persistence.storageClassName }}
        {{- end }}
  {{- end }}
{{- end}}
{{- end -}}

{{- define "agentFeatures.postgres.service" -}}
{{- if not .Values.postgres.external.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.postgres.service.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.postgres.service.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  type: {{ .Values.postgres.service.type }}
  ports:
    - name: postgres
      port: {{ .Values.postgres.service.port }}
      targetPort: postgres
      protocol: TCP
  selector:
    {{- include "langGraphCloud.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  {{- end }}
{{- end -}}

{{- define "agentFeatures.postgres.service-account" -}}
{{- if and (not .Values.postgres.external.enabled) .Values.postgres.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "postgres.serviceAccountName" . }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.postgres.serviceAccount.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.postgres.serviceAccount.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
automountServiceAccountToken: true
{{- end }}
{{- end -}}

{{- define "agentFeatures.postgres.pdb" -}}
{{- if .Values.postgres.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.postgres.name }}
  {{- if .Values.postgres.pdb.minAvailable }}
  minAvailable: {{ .Values.postgres.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.postgres.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.postgres.pdb.maxUnavailable }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.redis.secrets" -}}
{{- if not .Values.redis.external.existingSecretName }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "langGraphCloud.redisSecretsName" .}}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
data:
  {{- if .Values.redis.external.enabled }}
    redis_connection_url: {{ .Values.redis.external.connectionUrl | b64enc }}
  {{- else }}
    redis_connection_url: {{ printf "redis://%s-%s.%s.svc.%s:%v" (include "langGraphCloud.fullname" .) .Values.redis.name (default .Release.Namespace .Values.namespace) .Values.clusterDomain .Values.redis.containerPort | b64enc }}
  {{- end}}
{{- end }}
{{- end -}}

{{- define "agentFeatures.redis.deployment" -}}
{{- if not .Values.redis.external.enabled }}
{{- $volumes := concat .Values.commonVolumes .Values.redis.deployment.volumes -}}
{{- $volumeMounts := concat .Values.commonVolumeMounts .Values.redis.deployment.volumeMounts -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.redis.deployment.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.redis.deployment.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
  template:
    metadata:
      {{- with .Values.redis.deployment.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- with.Values.redis.deployment.labels }}
            {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- include "langGraphCloud.labels" . | nindent 8 }}
        app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
    spec:
      {{- with .Values.images.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.redis.deployment.priorityClassName }}
      priorityClassName: {{ .Values.redis.deployment.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.redis.deployment.terminationGracePeriodSeconds }}
      securityContext:
        {{- toYaml .Values.redis.deployment.podSecurityContext | nindent 8 }}
      serviceAccountName: {{ include "redis.serviceAccountName" . }}
      {{- include "langGraphCloud.dnsConfig" . | nindent 6 }}
      containers:
        - name: {{ .Values.redis.name }}
          {{- with.Values.redis.deployment.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.redis.deployment.extraEnv }}
          env:
            {{- with .Values.redis.deployment.extraEnv}}
             {{- toYaml . | nindent 12 }}
            {{- end }}
           {{- end }}
          image: {{ include "langGraphCloud.image" (dict "Values" .Values "Chart" .Chart "component" "redisImage") | quote }}
          imagePullPolicy: {{ .Values.images.redisImage.pullPolicy }}
          ports:
            - name: redis
              containerPort: {{ .Values.redis.containerPort }}
              protocol: TCP
          {{- with .Values.redis.deployment.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.redis.deployment.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.redis.deployment.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.redis.deployment.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.redis.deployment.securityContext | nindent 12 }}
          {{- with .Values.redis.deployment.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- with .Values.redis.deployment.extraContainerConfig }}
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.redis.deployment.sidecars }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.redis.deployment.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.redis.deployment.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.redis.deployment.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $volumes }}
      volumes:
          {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.redis.service" -}}
{{- if not .Values.redis.external.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.redis.service.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.redis.service.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  type: {{ .Values.redis.service.type }}
  ports:
    - name: redis
      port: {{ .Values.redis.service.port }}
      targetPort: redis
      protocol: TCP
  selector:
    {{- include "langGraphCloud.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.redis.service-account" -}}
{{- if and (not .Values.redis.external.enabled) .Values.redis.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "redis.serviceAccountName" . }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.redis.serviceAccount.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.redis.serviceAccount.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
automountServiceAccountToken: true
{{- end }}
{{- end -}}

{{- define "agentFeatures.redis.pdb" -}}
{{- if .Values.redis.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.redis.name }}
  {{- if .Values.redis.pdb.minAvailable }}
  minAvailable: {{ .Values.redis.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.redis.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.redis.pdb.maxUnavailable }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.queue.deployment" -}}
{{- if .Values.queue.enabled -}}
{{- $root := .Root }}
{{- $volumes := concat .Values.commonVolumes .Values.queue.deployment.volumes -}}
{{- $volumeMounts := concat .Values.commonVolumeMounts .Values.queue.deployment.volumeMounts -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.queue.deployment.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.queue.deployment.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if not .Values.queue.autoscaling.enabled }}
  replicas: {{ .Values.queue.deployment.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  template:
    metadata:
      {{- with .Values.queue.deployment.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- with.Values.queue.deployment.labels }}
            {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- include "langGraphCloud.labels" . | nindent 8 }}
        app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
    spec:
      serviceAccountName: {{ include "queue.serviceAccountName" . }}
      {{- include "langGraphCloud.dnsConfig" . | nindent 6 }}
      {{- with .Values.images.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.queue.deployment.priorityClassName }}
      priorityClassName: {{ .Values.queue.deployment.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.queue.deployment.terminationGracePeriodSeconds }}
      securityContext:
        {{- merge .Values.queue.deployment.podSecurityContext (.Values.commonPodSecurityContext | default dict) | toYaml | nindent 8 }}
      {{- with .Values.commonInitContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Values.queue.name }}
          command:
            - "/storage/queue_entrypoint.sh"
          env:
            {{- with .Values.commonEnv }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
            - name: PORT
              value: {{ .Values.queue.containerPort | quote }}
            - name: POSTGRES_URI
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.postgresSecretsName" . }}
                  key: postgres_connection_url
            - name: REDIS_URI
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.redisSecretsName" . }}
                  key: redis_connection_url
            - name: LANGGRAPH_CLOUD_LICENSE_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "langsmith.secretsName" $root }}
                  key: langsmith_license_key
                  optional: true
            - name: N_JOBS_PER_WORKER
              value: {{ .Values.queue.numberOfJobsPerWorker | quote }}
            {{- with .Values.queue.deployment.extraEnv }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- with .Values.queue.deployment.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: {{ include "langGraphCloud.image" (dict "Values" .Values "Chart" .Chart "component" "apiServerImage") | quote }}
          imagePullPolicy: {{ .Values.images.apiServerImage.pullPolicy }}
          ports:
            - name: queue
              containerPort: {{ .Values.queue.containerPort }}
              protocol: TCP
          startupProbe:
            {{- toYaml .Values.queue.deployment.startupProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.queue.deployment.readinessProbe | nindent 12 }}
          livenessProbe:
            {{- toYaml .Values.queue.deployment.livenessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.queue.deployment.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.queue.deployment.securityContext | nindent 12 }}
          {{- with .Values.queue.deployment.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $volumeMounts }}
          volumeMounts:
              {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- with .Values.queue.deployment.sidecars }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.queue.deployment.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.queue.deployment.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.queue.deployment.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $volumes }}
      volumes:
          {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end}}
{{- end -}}

{{- define "agentFeatures.queue.hpa" -}}
{{- if and .Values.queue.enabled .Values.queue.autoscaling.enabled (not .Values.queue.autoscaling.keda.enabled) }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  minReplicas: {{ .Values.queue.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.queue.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.queue.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.queue.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.queue.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.queue.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.queue.pdb" -}}
{{- if .Values.queue.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  {{- if .Values.queue.pdb.minAvailable }}
  minAvailable: {{ .Values.queue.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.queue.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.queue.pdb.maxUnavailable }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.queue.scaled-object" -}}
{{- if and .Values.queue.enabled .Values.queue.autoscaling.enabled .Values.queue.autoscaling.keda.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.queue.name }}
  minReplicaCount: {{ .Values.queue.autoscaling.minReplicas | default 1 }}
  maxReplicaCount: {{ .Values.queue.autoscaling.maxReplicas | default 10 }}
  pollingInterval: {{ .Values.queue.autoscaling.keda.pollingInterval | default 30 }}
  cooldownPeriod: {{ .Values.queue.autoscaling.keda.cooldownPeriod | default 300 }}
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: {{ .Values.queue.autoscaling.keda.scaleDownStabilizationWindowSeconds | default 300 }}
  triggers:
    {{- if .Values.queue.autoscaling.targetCPUUtilizationPercentage }}
    - type: cpu
      metricType: Utilization
      metadata:
        value: "{{ .Values.queue.autoscaling.targetCPUUtilizationPercentage }}"
    {{- end }}
    {{- if .Values.queue.autoscaling.targetMemoryUtilizationPercentage }}
    - type: memory
      metricType: Utilization
      metadata:
        value: "{{ .Values.queue.autoscaling.targetMemoryUtilizationPercentage }}"
    {{- end }}
    - type: postgresql
      metadata:
        connectionFromEnv: "POSTGRES_URI"
        query: "SELECT COUNT(*) FROM run WHERE status = 'pending'"
        targetQueryValue: {{ .Values.queue.numberOfJobsPerWorker | quote }}
        activationTargetQueryValue: {{ .Values.queue.numberOfJobsPerWorker | quote }}
    {{- with .Values.queue.autoscaling.keda.additionalTriggers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.queue.service-account" -}}
{{- if .Values.queue.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "queue.serviceAccountName" . }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.queue.deployment.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.queue.serviceAccount.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
automountServiceAccountToken: true
{{- end }}
{{- end -}}

{{- define "agentFeatures.api-server.deployment" -}}
{{- $root := .Root }}
{{- $volumes := concat .Values.commonVolumes .Values.apiServer.deployment.volumes -}}
{{- $volumeMounts := concat .Values.commonVolumeMounts .Values.apiServer.deployment.volumeMounts -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.apiServer.deployment.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.apiServer.deployment.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if not .Values.apiServer.autoscaling.enabled }}
  replicas: {{ .Values.apiServer.deployment.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  template:
    metadata:
      {{- with .Values.apiServer.deployment.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- with.Values.apiServer.deployment.labels }}
            {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- include "langGraphCloud.labels" . | nindent 8 }}
        app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
    spec:
      serviceAccountName: {{ include "apiServer.serviceAccountName" . }}
      {{- include "langGraphCloud.dnsConfig" . | nindent 6 }}
      {{- with .Values.images.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.apiServer.deployment.priorityClassName }}
      priorityClassName: {{ .Values.apiServer.deployment.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.apiServer.deployment.terminationGracePeriodSeconds }}
      securityContext:
        {{- merge .Values.apiServer.deployment.podSecurityContext (.Values.commonPodSecurityContext | default dict) | toYaml | nindent 8 }}
      {{- $initContainers := concat (.Values.commonInitContainers | default list) (.Values.apiServer.deployment.initContainers | default list) }}
      {{- with $initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Values.apiServer.name }}
          env:
            {{- with .Values.commonEnv }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
            - name: PORT
              value: {{ .Values.apiServer.containerPort | quote }}
            - name: POSTGRES_URI
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.postgresSecretsName" . }}
                  key: postgres_connection_url
            - name: REDIS_URI
              valueFrom:
                secretKeyRef:
                  name: {{ include "langGraphCloud.redisSecretsName" . }}
                  key: redis_connection_url
            - name: LANGGRAPH_CLOUD_LICENSE_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "langsmith.secretsName" $root }}
                  key: langsmith_license_key
                  optional: true
            {{- if .Values.queue.enabled }}
            - name: N_JOBS_PER_WORKER
              value: "0"
            {{- else }}
            - name: N_JOBS_PER_WORKER
              value: {{ .Values.queue.numberOfJobsPerWorker | quote }}
            {{- end }}
            {{- with include "langsmith.agentFeatures.apiServerExtraEnv" . | trim }}
              {{- . | nindent 12 }}
            {{- end }}
          {{- with .Values.apiServer.deployment.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: {{ include "langGraphCloud.image" (dict "Values" .Values "Chart" .Chart "component" "apiServerImage") | quote }}
          imagePullPolicy: {{ .Values.images.apiServerImage.pullPolicy }}
          ports:
            - name: api-server
              containerPort: {{ .Values.apiServer.containerPort }}
              protocol: TCP
          startupProbe:
            {{- toYaml .Values.apiServer.deployment.startupProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.apiServer.deployment.readinessProbe | nindent 12 }}
          livenessProbe:
            {{- toYaml .Values.apiServer.deployment.livenessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.apiServer.deployment.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.apiServer.deployment.securityContext | nindent 12 }}
          {{- with .Values.apiServer.deployment.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $volumeMounts }}
          volumeMounts:
              {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- with .Values.apiServer.deployment.sidecars }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.apiServer.deployment.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.apiServer.deployment.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.apiServer.deployment.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $volumes }}
      volumes:
          {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}

{{- define "agentFeatures.api-server.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.apiServer.service.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.apiServer.service.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  type: {{ .Values.apiServer.service.type }}
  ports:
    - name: http
      port: {{ .Values.apiServer.service.httpPort }}
      targetPort: api-server
      protocol: TCP
  selector:
    {{- include "langGraphCloud.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
{{- end -}}

{{- define "agentFeatures.api-server.service-account" -}}
{{- if .Values.apiServer.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "apiServer.serviceAccountName" . }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
    {{- with.Values.apiServer.deployment.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "langGraphCloud.annotations" . | nindent 4 }}
    {{- with.Values.apiServer.serviceAccount.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
automountServiceAccountToken: true
{{- end }}
{{- end -}}

{{- define "agentFeatures.api-server.hpa" -}}
{{- if and .Values.apiServer.autoscaling.enabled (not .Values.apiServer.autoscaling.keda.enabled) }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  minReplicas: {{ .Values.apiServer.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.apiServer.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.apiServer.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.apiServer.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.apiServer.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.apiServer.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.api-server.pdb" -}}
{{- if .Values.apiServer.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "langGraphCloud.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  {{- if .Values.apiServer.pdb.minAvailable }}
  minAvailable: {{ .Values.apiServer.pdb.minAvailable }}
  {{- end }}
  {{- if .Values.apiServer.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.apiServer.pdb.maxUnavailable }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agentFeatures.api-server.scaled-object" -}}
{{- if and .Values.apiServer.autoscaling.enabled .Values.apiServer.autoscaling.keda.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace | quote }}
  labels:
    {{- include "langGraphCloud.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    name: {{ include "langGraphCloud.fullname" . }}-{{ .Values.apiServer.name }}
  minReplicaCount: {{ .Values.apiServer.autoscaling.minReplicas | default 1 }}
  maxReplicaCount: {{ .Values.apiServer.autoscaling.maxReplicas | default 10 }}
  pollingInterval: {{ .Values.apiServer.autoscaling.keda.pollingInterval | default 30 }}
  cooldownPeriod: {{ .Values.apiServer.autoscaling.keda.cooldownPeriod | default 300 }}
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: {{ .Values.apiServer.autoscaling.keda.scaleDownStabilizationWindowSeconds | default 300 }}
  triggers:
    {{- if .Values.apiServer.autoscaling.targetCPUUtilizationPercentage }}
    - type: cpu
      metricType: Utilization
      metadata:
        value: "{{ .Values.apiServer.autoscaling.targetCPUUtilizationPercentage }}"
    {{- end }}
    {{- if .Values.apiServer.autoscaling.targetMemoryUtilizationPercentage }}
    - type: memory
      metricType: Utilization
      metadata:
        value: "{{ .Values.apiServer.autoscaling.targetMemoryUtilizationPercentage }}"
    {{- end }}
    {{- if not .Values.queue.enabled }}
    - type: postgresql
      metadata:
        connectionFromEnv: "POSTGRES_URI"
        query: "SELECT COUNT(*) FROM run WHERE status = 'pending'"
        targetQueryValue: {{ .Values.queue.numberOfJobsPerWorker | quote }}
        activationTargetQueryValue: {{ .Values.queue.numberOfJobsPerWorker | quote }}
    {{- end }}
    {{- with .Values.apiServer.autoscaling.keda.additionalTriggers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end -}}

