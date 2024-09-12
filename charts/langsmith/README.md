# langsmith

![Version: 0.7.6](https://img.shields.io/badge/Version-0.7.6-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.7.20](https://img.shields.io/badge/AppVersion-0.7.20-informational?style=flat-square)

Helm chart to deploy the langsmith application and all services it depends on.

## Documentation

For information on how to use this chart, up-to-date release notes, and other guides please check out the [documentation.](https://docs.smith.langchain.com/self_hosting)

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiIngress.annotations | object | `{}` |  |
| apiIngress.enabled | bool | `false` |  |
| apiIngress.hostname | string | `""` |  |
| apiIngress.ingressClassName | string | `""` |  |
| apiIngress.labels | object | `{}` |  |
| apiIngress.subdomain | string | `""` |  |
| apiIngress.tls | list | `[]` |  |
| clickhouse.config.allowSimdjson | bool | `true` |  |
| clickhouse.containerHttpPort | int | `8123` |  |
| clickhouse.containerNativePort | int | `9000` |  |
| clickhouse.external.database | string | `"default"` |  |
| clickhouse.external.enabled | bool | `false` |  |
| clickhouse.external.existingSecretName | string | `""` |  |
| clickhouse.external.host | string | `""` |  |
| clickhouse.external.nativePort | string | `"9000"` |  |
| clickhouse.external.password | string | `"password"` |  |
| clickhouse.external.port | string | `"8123"` |  |
| clickhouse.external.tls | bool | `false` |  |
| clickhouse.external.user | string | `"default"` |  |
| clickhouse.name | string | `"clickhouse"` |  |
| clickhouse.service.annotations | object | `{}` |  |
| clickhouse.service.httpPort | int | `8123` |  |
| clickhouse.service.labels | object | `{}` |  |
| clickhouse.service.loadBalancerIP | string | `""` |  |
| clickhouse.service.loadBalancerSourceRanges | list | `[]` |  |
| clickhouse.service.nativePort | int | `9000` |  |
| clickhouse.service.type | string | `"ClusterIP"` |  |
| clickhouse.serviceAccount.annotations | object | `{}` |  |
| clickhouse.serviceAccount.create | bool | `true` |  |
| clickhouse.serviceAccount.labels | object | `{}` |  |
| clickhouse.serviceAccount.name | string | `""` |  |
| clickhouse.statefulSet.affinity | object | `{}` |  |
| clickhouse.statefulSet.annotations | object | `{}` |  |
| clickhouse.statefulSet.command[0] | string | `"/bin/bash"` |  |
| clickhouse.statefulSet.command[1] | string | `"-c"` |  |
| clickhouse.statefulSet.command[2] | string | `"sed 's/id -g/id -gn/' /entrypoint.sh > /tmp/entrypoint.sh; exec bash /tmp/entrypoint.sh"` |  |
| clickhouse.statefulSet.extraContainerConfig | object | `{}` |  |
| clickhouse.statefulSet.extraEnv | list | `[]` |  |
| clickhouse.statefulSet.labels | object | `{}` |  |
| clickhouse.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"50Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.resources.limits.cpu | string | `"8000m"` |  |
| clickhouse.statefulSet.resources.limits.memory | string | `"32Gi"` |  |
| clickhouse.statefulSet.resources.requests.cpu | string | `"3500m"` |  |
| clickhouse.statefulSet.resources.requests.memory | string | `"15Gi"` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.sidecars | list | `[]` |  |
| clickhouse.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.startupProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.startupProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonEnv | list | `[]` | Common environment variables that will be applied to all deployments/statefulsets created by the chart. Be careful not to override values already specified by the chart. |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"docker.io/langchain/langsmith-backend"` |  |
| images.backendImage.tag | string | `"0.7.20"` |  |
| images.clickhouseImage.pullPolicy | string | `"Always"` |  |
| images.clickhouseImage.repository | string | `"docker.io/clickhouse/clickhouse-server"` |  |
| images.clickhouseImage.tag | string | `"24.2"` |  |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"docker.io/langchain/langsmith-frontend"` |  |
| images.frontendImage.tag | string | `"0.7.20"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.platformBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.platformBackendImage.repository | string | `"docker.io/langchain/langsmith-go-backend"` |  |
| images.platformBackendImage.tag | string | `"0.7.20"` |  |
| images.playgroundImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.playgroundImage.repository | string | `"docker.io/langchain/langsmith-playground"` |  |
| images.playgroundImage.tag | string | `"0.7.20"` |  |
| images.postgresImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.postgresImage.repository | string | `"docker.io/postgres"` |  |
| images.postgresImage.tag | string | `"14.7"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"7"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.subdomain | string | `""` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langsmith` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.apiKeySalt | string | `""` | Salt used to generate the API key. Should be a random string. |
| config.authType | string | `""` |  |
| config.basicAuth.enabled | bool | `false` |  |
| config.basicAuth.initialOrgAdminEmail | string | `""` |  |
| config.basicAuth.initialOrgAdminPassword | string | `""` |  |
| config.basicAuth.jwtSecret | string | `""` |  |
| config.blobStorage | object | `{"accessKey":"","accessKeySecret":"","apiURL":"https://s3.us-west-2.amazonaws.com","bucketName":"","chSearchEnabled":true,"enabled":false}` | Blob storage configuration Optional. Used to store inputs, outputs, and errors in Blob Storage. We currently support S3, GCS, and Minio as Blob Storage providers. |
| config.existingSecretName | string | `""` |  |
| config.langsmithLicenseKey | string | `""` |  |
| config.logLevel | string | `"info"` |  |
| config.oauth.enabled | bool | `false` |  |
| config.oauth.oauthClientId | string | `""` |  |
| config.oauth.oauthIssuerUrl | string | `""` |  |
| config.orgCreationDisabled | bool | `false` | Prevent organization creation. If using basic auth, this is set to true by default. |
| config.personalOrgsDisabled | bool | `false` | Disable personal orgs. Users will need to be invited to an org manually. If using basic auth, this is set to true by default. |
| config.ttl | object | `{"enabled":true,"ttl_period_seconds":{"longlived":"34560000","shortlived":"1209600"}}` | TTL configuration Optional. Used to set TTLS for longlived and shortlived objects. |
| config.ttl.ttl_period_seconds.longlived | string | `"34560000"` | 400 day longlived and 14 day shortlived |
| config.workspaceScopeOrgInvitesEnabled | bool | `false` | Enable Workspace Admins to invite users to the org and workspace. |

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.authBootstrap.affinity | object | `{}` |  |
| backend.authBootstrap.annotations | object | `{}` |  |
| backend.authBootstrap.command[0] | string | `"python"` |  |
| backend.authBootstrap.command[1] | string | `"hooks/auth_bootstrap.pyc"` |  |
| backend.authBootstrap.extraContainerConfig | object | `{}` |  |
| backend.authBootstrap.extraEnv | list | `[]` |  |
| backend.authBootstrap.labels | object | `{}` |  |
| backend.authBootstrap.nodeSelector | object | `{}` |  |
| backend.authBootstrap.podSecurityContext | object | `{}` |  |
| backend.authBootstrap.resources | object | `{}` |  |
| backend.authBootstrap.securityContext | object | `{}` |  |
| backend.authBootstrap.sidecars | list | `[]` |  |
| backend.authBootstrap.tolerations | list | `[]` |  |
| backend.authBootstrap.volumeMounts | list | `[]` |  |
| backend.authBootstrap.volumes | list | `[]` |  |
| backend.autoscaling.createHpa | bool | `true` |  |
| backend.autoscaling.enabled | bool | `false` |  |
| backend.autoscaling.maxReplicas | int | `5` |  |
| backend.autoscaling.minReplicas | int | `1` |  |
| backend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| backend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| backend.clickhouseMigrations.affinity | object | `{}` |  |
| backend.clickhouseMigrations.annotations | object | `{}` |  |
| backend.clickhouseMigrations.command[0] | string | `"/bin/bash"` |  |
| backend.clickhouseMigrations.command[1] | string | `"scripts/wait_for_clickhouse_and_migrate.sh"` |  |
| backend.clickhouseMigrations.enabled | bool | `true` |  |
| backend.clickhouseMigrations.extraContainerConfig | object | `{}` |  |
| backend.clickhouseMigrations.extraEnv | list | `[]` |  |
| backend.clickhouseMigrations.labels | object | `{}` |  |
| backend.clickhouseMigrations.nodeSelector | object | `{}` |  |
| backend.clickhouseMigrations.podSecurityContext | object | `{}` |  |
| backend.clickhouseMigrations.resources | object | `{}` |  |
| backend.clickhouseMigrations.securityContext | object | `{}` |  |
| backend.clickhouseMigrations.sidecars | list | `[]` |  |
| backend.clickhouseMigrations.tolerations | list | `[]` |  |
| backend.clickhouseMigrations.volumeMounts | list | `[]` |  |
| backend.clickhouseMigrations.volumes | list | `[]` |  |
| backend.containerPort | int | `1984` |  |
| backend.deployment.affinity | object | `{}` |  |
| backend.deployment.annotations | object | `{}` |  |
| backend.deployment.autoRestart | bool | `true` |  |
| backend.deployment.command[0] | string | `"uvicorn"` |  |
| backend.deployment.command[10] | string | `"--http"` |  |
| backend.deployment.command[11] | string | `"httptools"` |  |
| backend.deployment.command[12] | string | `"--no-access-log"` |  |
| backend.deployment.command[1] | string | `"app.main:app"` |  |
| backend.deployment.command[2] | string | `"--host"` |  |
| backend.deployment.command[3] | string | `"0.0.0.0"` |  |
| backend.deployment.command[4] | string | `"--port"` |  |
| backend.deployment.command[5] | string | `"$(PORT)"` |  |
| backend.deployment.command[6] | string | `"--log-level"` |  |
| backend.deployment.command[7] | string | `"$(LOG_LEVEL)"` |  |
| backend.deployment.command[8] | string | `"--loop"` |  |
| backend.deployment.command[9] | string | `"uvloop"` |  |
| backend.deployment.extraContainerConfig | object | `{}` |  |
| backend.deployment.extraEnv | list | `[]` |  |
| backend.deployment.labels | object | `{}` |  |
| backend.deployment.livenessProbe.failureThreshold | int | `6` |  |
| backend.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| backend.deployment.livenessProbe.httpGet.port | int | `1984` |  |
| backend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| backend.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| backend.deployment.nodeSelector | object | `{}` |  |
| backend.deployment.podSecurityContext | object | `{}` |  |
| backend.deployment.readinessProbe.failureThreshold | int | `6` |  |
| backend.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| backend.deployment.readinessProbe.httpGet.port | int | `1984` |  |
| backend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| backend.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| backend.deployment.replicas | int | `1` |  |
| backend.deployment.resources.limits.cpu | string | `"2000m"` |  |
| backend.deployment.resources.limits.memory | string | `"4Gi"` |  |
| backend.deployment.resources.requests.cpu | string | `"1000m"` |  |
| backend.deployment.resources.requests.memory | string | `"2Gi"` |  |
| backend.deployment.securityContext | object | `{}` |  |
| backend.deployment.sidecars | list | `[]` |  |
| backend.deployment.startupProbe.failureThreshold | int | `6` |  |
| backend.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| backend.deployment.startupProbe.httpGet.port | int | `1984` |  |
| backend.deployment.startupProbe.periodSeconds | int | `10` |  |
| backend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| backend.deployment.tolerations | list | `[]` |  |
| backend.deployment.volumeMounts | list | `[]` |  |
| backend.deployment.volumes | list | `[]` |  |
| backend.existingConfigMapName | string | `""` |  |
| backend.migrations.affinity | object | `{}` |  |
| backend.migrations.annotations | object | `{}` |  |
| backend.migrations.command[0] | string | `"/bin/bash"` |  |
| backend.migrations.command[1] | string | `"-c"` |  |
| backend.migrations.command[2] | string | `"alembic upgrade head"` |  |
| backend.migrations.enabled | bool | `true` |  |
| backend.migrations.extraContainerConfig | object | `{}` |  |
| backend.migrations.extraEnv | list | `[]` |  |
| backend.migrations.labels | object | `{}` |  |
| backend.migrations.nodeSelector | object | `{}` |  |
| backend.migrations.podSecurityContext | object | `{}` |  |
| backend.migrations.resources | object | `{}` |  |
| backend.migrations.securityContext | object | `{}` |  |
| backend.migrations.sidecars | list | `[]` |  |
| backend.migrations.tolerations | list | `[]` |  |
| backend.migrations.volumeMounts | list | `[]` |  |
| backend.migrations.volumes | list | `[]` |  |
| backend.name | string | `"backend"` |  |
| backend.service.annotations | object | `{}` |  |
| backend.service.labels | object | `{}` |  |
| backend.service.loadBalancerIP | string | `""` |  |
| backend.service.loadBalancerSourceRanges | list | `[]` |  |
| backend.service.port | int | `1984` |  |
| backend.service.type | string | `"ClusterIP"` |  |
| backend.serviceAccount.annotations | object | `{}` |  |
| backend.serviceAccount.create | bool | `true` |  |
| backend.serviceAccount.labels | object | `{}` |  |
| backend.serviceAccount.name | string | `""` |  |

## Clickhouse

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.config.allowSimdjson | bool | `true` |  |
| clickhouse.containerHttpPort | int | `8123` |  |
| clickhouse.containerNativePort | int | `9000` |  |
| clickhouse.external.database | string | `"default"` |  |
| clickhouse.external.enabled | bool | `false` |  |
| clickhouse.external.existingSecretName | string | `""` |  |
| clickhouse.external.host | string | `""` |  |
| clickhouse.external.nativePort | string | `"9000"` |  |
| clickhouse.external.password | string | `"password"` |  |
| clickhouse.external.port | string | `"8123"` |  |
| clickhouse.external.tls | bool | `false` |  |
| clickhouse.external.user | string | `"default"` |  |
| clickhouse.name | string | `"clickhouse"` |  |
| clickhouse.service.annotations | object | `{}` |  |
| clickhouse.service.httpPort | int | `8123` |  |
| clickhouse.service.labels | object | `{}` |  |
| clickhouse.service.loadBalancerIP | string | `""` |  |
| clickhouse.service.loadBalancerSourceRanges | list | `[]` |  |
| clickhouse.service.nativePort | int | `9000` |  |
| clickhouse.service.type | string | `"ClusterIP"` |  |
| clickhouse.serviceAccount.annotations | object | `{}` |  |
| clickhouse.serviceAccount.create | bool | `true` |  |
| clickhouse.serviceAccount.labels | object | `{}` |  |
| clickhouse.serviceAccount.name | string | `""` |  |
| clickhouse.statefulSet.affinity | object | `{}` |  |
| clickhouse.statefulSet.annotations | object | `{}` |  |
| clickhouse.statefulSet.command[0] | string | `"/bin/bash"` |  |
| clickhouse.statefulSet.command[1] | string | `"-c"` |  |
| clickhouse.statefulSet.command[2] | string | `"sed 's/id -g/id -gn/' /entrypoint.sh > /tmp/entrypoint.sh; exec bash /tmp/entrypoint.sh"` |  |
| clickhouse.statefulSet.extraContainerConfig | object | `{}` |  |
| clickhouse.statefulSet.extraEnv | list | `[]` |  |
| clickhouse.statefulSet.labels | object | `{}` |  |
| clickhouse.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"50Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.resources.limits.cpu | string | `"8000m"` |  |
| clickhouse.statefulSet.resources.limits.memory | string | `"32Gi"` |  |
| clickhouse.statefulSet.resources.requests.cpu | string | `"3500m"` |  |
| clickhouse.statefulSet.resources.requests.memory | string | `"15Gi"` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.sidecars | list | `[]` |  |
| clickhouse.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.startupProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.startupProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.autoscaling.createHpa | bool | `true` |  |
| frontend.autoscaling.enabled | bool | `false` |  |
| frontend.autoscaling.maxReplicas | int | `5` |  |
| frontend.autoscaling.minReplicas | int | `1` |  |
| frontend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| frontend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| frontend.containerPort | int | `8080` |  |
| frontend.deployment.affinity | object | `{}` |  |
| frontend.deployment.annotations | object | `{}` |  |
| frontend.deployment.autoRestart | bool | `true` |  |
| frontend.deployment.command[0] | string | `"/entrypoint.sh"` |  |
| frontend.deployment.extraContainerConfig | object | `{}` |  |
| frontend.deployment.extraEnv | list | `[]` |  |
| frontend.deployment.labels | object | `{}` |  |
| frontend.deployment.livenessProbe.failureThreshold | int | `10` |  |
| frontend.deployment.livenessProbe.httpGet.path | string | `"/health"` |  |
| frontend.deployment.livenessProbe.httpGet.port | int | `8080` |  |
| frontend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| frontend.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| frontend.deployment.nodeSelector | object | `{}` |  |
| frontend.deployment.podSecurityContext | object | `{}` |  |
| frontend.deployment.readinessProbe.failureThreshold | int | `10` |  |
| frontend.deployment.readinessProbe.httpGet.path | string | `"/health"` |  |
| frontend.deployment.readinessProbe.httpGet.port | int | `8080` |  |
| frontend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| frontend.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| frontend.deployment.replicas | int | `1` |  |
| frontend.deployment.resources.limits.cpu | string | `"1000m"` |  |
| frontend.deployment.resources.limits.memory | string | `"2Gi"` |  |
| frontend.deployment.resources.requests.cpu | string | `"500m"` |  |
| frontend.deployment.resources.requests.memory | string | `"1Gi"` |  |
| frontend.deployment.securityContext | object | `{}` |  |
| frontend.deployment.sidecars | list | `[]` |  |
| frontend.deployment.startupProbe.failureThreshold | int | `10` |  |
| frontend.deployment.startupProbe.httpGet.path | string | `"/health"` |  |
| frontend.deployment.startupProbe.httpGet.port | int | `8080` |  |
| frontend.deployment.startupProbe.periodSeconds | int | `10` |  |
| frontend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.deployment.volumeMounts | list | `[]` |  |
| frontend.deployment.volumes | list | `[]` |  |
| frontend.existingConfigMapName | string | `""` |  |
| frontend.maxBodySize | string | `"25M"` |  |
| frontend.name | string | `"frontend"` |  |
| frontend.proxyConnectTimeout | string | `"60"` |  |
| frontend.proxyReadTimeout | string | `"300"` |  |
| frontend.proxyWriteTimeout | string | `"300"` |  |
| frontend.service.annotations | object | `{}` |  |
| frontend.service.httpPort | int | `80` |  |
| frontend.service.httpsPort | int | `443` |  |
| frontend.service.labels | object | `{}` |  |
| frontend.service.loadBalancerIP | string | `""` |  |
| frontend.service.loadBalancerSourceRanges | list | `[]` |  |
| frontend.service.type | string | `"LoadBalancer"` |  |
| frontend.serviceAccount.annotations | object | `{}` |  |
| frontend.serviceAccount.create | bool | `true` |  |
| frontend.serviceAccount.labels | object | `{}` |  |
| frontend.serviceAccount.name | string | `""` |  |

## Platform Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| platformBackend.autoscaling.createHpa | bool | `true` |  |
| platformBackend.autoscaling.enabled | bool | `false` |  |
| platformBackend.autoscaling.maxReplicas | int | `5` |  |
| platformBackend.autoscaling.minReplicas | int | `1` |  |
| platformBackend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| platformBackend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| platformBackend.containerPort | int | `1986` |  |
| platformBackend.deployment.affinity | object | `{}` |  |
| platformBackend.deployment.annotations | object | `{}` |  |
| platformBackend.deployment.autoRestart | bool | `true` |  |
| platformBackend.deployment.command[0] | string | `"./smith-go"` |  |
| platformBackend.deployment.extraContainerConfig | object | `{}` |  |
| platformBackend.deployment.extraEnv | list | `[]` |  |
| platformBackend.deployment.labels | object | `{}` |  |
| platformBackend.deployment.livenessProbe.failureThreshold | int | `6` |  |
| platformBackend.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| platformBackend.deployment.livenessProbe.httpGet.port | int | `1986` |  |
| platformBackend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| platformBackend.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| platformBackend.deployment.nodeSelector | object | `{}` |  |
| platformBackend.deployment.podSecurityContext | object | `{}` |  |
| platformBackend.deployment.readinessProbe.failureThreshold | int | `6` |  |
| platformBackend.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| platformBackend.deployment.readinessProbe.httpGet.port | int | `1986` |  |
| platformBackend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| platformBackend.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| platformBackend.deployment.replicas | int | `1` |  |
| platformBackend.deployment.resources.limits.cpu | string | `"1000m"` |  |
| platformBackend.deployment.resources.limits.memory | string | `"2Gi"` |  |
| platformBackend.deployment.resources.requests.cpu | string | `"500m"` |  |
| platformBackend.deployment.resources.requests.memory | string | `"1Gi"` |  |
| platformBackend.deployment.securityContext | object | `{}` |  |
| platformBackend.deployment.sidecars | list | `[]` |  |
| platformBackend.deployment.startupProbe.failureThreshold | int | `6` |  |
| platformBackend.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| platformBackend.deployment.startupProbe.httpGet.port | int | `1986` |  |
| platformBackend.deployment.startupProbe.periodSeconds | int | `10` |  |
| platformBackend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| platformBackend.deployment.tolerations | list | `[]` |  |
| platformBackend.deployment.volumeMounts | list | `[]` |  |
| platformBackend.deployment.volumes | list | `[]` |  |
| platformBackend.existingConfigMapName | string | `""` |  |
| platformBackend.name | string | `"platform-backend"` |  |
| platformBackend.service.annotations | object | `{}` |  |
| platformBackend.service.labels | object | `{}` |  |
| platformBackend.service.loadBalancerIP | string | `""` |  |
| platformBackend.service.loadBalancerSourceRanges | list | `[]` |  |
| platformBackend.service.port | int | `1986` |  |
| platformBackend.service.type | string | `"ClusterIP"` |  |
| platformBackend.serviceAccount.annotations | object | `{}` |  |
| platformBackend.serviceAccount.create | bool | `true` |  |
| platformBackend.serviceAccount.labels | object | `{}` |  |
| platformBackend.serviceAccount.name | string | `""` |  |

## Playground

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| playground.autoscaling.createHpa | bool | `true` |  |
| playground.autoscaling.enabled | bool | `false` |  |
| playground.autoscaling.maxReplicas | int | `5` |  |
| playground.autoscaling.minReplicas | int | `1` |  |
| playground.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| playground.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| playground.containerPort | int | `3001` |  |
| playground.deployment.affinity | object | `{}` |  |
| playground.deployment.annotations | object | `{}` |  |
| playground.deployment.autoRestart | bool | `true` |  |
| playground.deployment.command[0] | string | `"yarn"` |  |
| playground.deployment.command[1] | string | `"start"` |  |
| playground.deployment.extraContainerConfig | object | `{}` |  |
| playground.deployment.extraEnv | list | `[]` |  |
| playground.deployment.labels | object | `{}` |  |
| playground.deployment.livenessProbe.failureThreshold | int | `6` |  |
| playground.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.livenessProbe.httpGet.port | int | `3001` |  |
| playground.deployment.livenessProbe.periodSeconds | int | `10` |  |
| playground.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.nodeSelector | object | `{}` |  |
| playground.deployment.podSecurityContext | object | `{}` |  |
| playground.deployment.readinessProbe.failureThreshold | int | `6` |  |
| playground.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.readinessProbe.httpGet.port | int | `3001` |  |
| playground.deployment.readinessProbe.periodSeconds | int | `10` |  |
| playground.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.replicas | int | `1` |  |
| playground.deployment.resources.limits.cpu | string | `"1000m"` |  |
| playground.deployment.resources.limits.memory | string | `"2Gi"` |  |
| playground.deployment.resources.requests.cpu | string | `"500m"` |  |
| playground.deployment.resources.requests.memory | string | `"1Gi"` |  |
| playground.deployment.securityContext | object | `{}` |  |
| playground.deployment.sidecars | list | `[]` |  |
| playground.deployment.startupProbe.failureThreshold | int | `6` |  |
| playground.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.startupProbe.httpGet.port | int | `3001` |  |
| playground.deployment.startupProbe.periodSeconds | int | `10` |  |
| playground.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.tolerations | list | `[]` |  |
| playground.deployment.volumeMounts | list | `[]` |  |
| playground.deployment.volumes | list | `[]` |  |
| playground.name | string | `"playground"` |  |
| playground.service.annotations | object | `{}` |  |
| playground.service.labels | object | `{}` |  |
| playground.service.loadBalancerIP | string | `""` |  |
| playground.service.loadBalancerSourceRanges | list | `[]` |  |
| playground.service.port | int | `3001` |  |
| playground.service.type | string | `"ClusterIP"` |  |
| playground.serviceAccount.annotations | object | `{}` |  |
| playground.serviceAccount.create | bool | `true` |  |
| playground.serviceAccount.labels | object | `{}` |  |
| playground.serviceAccount.name | string | `""` |  |

## Postgres

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgres.containerPort | int | `5432` |  |
| postgres.external.connectionUrl | string | `""` |  |
| postgres.external.database | string | `"postgres"` |  |
| postgres.external.enabled | bool | `false` |  |
| postgres.external.existingSecretName | string | `""` |  |
| postgres.external.host | string | `""` |  |
| postgres.external.password | string | `"postgres"` |  |
| postgres.external.port | string | `"5432"` |  |
| postgres.external.schema | string | `"public"` |  |
| postgres.external.user | string | `"postgres"` |  |
| postgres.name | string | `"postgres"` |  |
| postgres.service.annotations | object | `{}` |  |
| postgres.service.labels | object | `{}` |  |
| postgres.service.loadBalancerIP | string | `""` |  |
| postgres.service.loadBalancerSourceRanges | list | `[]` |  |
| postgres.service.port | int | `5432` |  |
| postgres.service.type | string | `"ClusterIP"` |  |
| postgres.serviceAccount.annotations | object | `{}` |  |
| postgres.serviceAccount.create | bool | `true` |  |
| postgres.serviceAccount.labels | object | `{}` |  |
| postgres.serviceAccount.name | string | `""` |  |
| postgres.statefulSet.affinity | object | `{}` |  |
| postgres.statefulSet.annotations | object | `{}` |  |
| postgres.statefulSet.command | list | `[]` |  |
| postgres.statefulSet.extraContainerConfig | object | `{}` |  |
| postgres.statefulSet.extraEnv | list | `[]` |  |
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| postgres.statefulSet.livenessProbe.exec.command[1] | string | `"-c"` |  |
| postgres.statefulSet.livenessProbe.exec.command[2] | string | `"exec pg_isready -d postgres -U postgres"` |  |
| postgres.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| postgres.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| postgres.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.podSecurityContext | object | `{}` |  |
| postgres.statefulSet.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| postgres.statefulSet.readinessProbe.exec.command[1] | string | `"-c"` |  |
| postgres.statefulSet.readinessProbe.exec.command[2] | string | `"exec pg_isready -d postgres -U postgres"` |  |
| postgres.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| postgres.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| postgres.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| postgres.statefulSet.resources.limits.cpu | string | `"4000m"` |  |
| postgres.statefulSet.resources.limits.memory | string | `"16Gi"` |  |
| postgres.statefulSet.resources.requests.cpu | string | `"2000m"` |  |
| postgres.statefulSet.resources.requests.memory | string | `"8Gi"` |  |
| postgres.statefulSet.securityContext | object | `{}` |  |
| postgres.statefulSet.sidecars | list | `[]` |  |
| postgres.statefulSet.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| postgres.statefulSet.startupProbe.exec.command[1] | string | `"-c"` |  |
| postgres.statefulSet.startupProbe.exec.command[2] | string | `"exec pg_isready -d postgres -U postgres"` |  |
| postgres.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| postgres.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| postgres.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| postgres.statefulSet.tolerations | list | `[]` |  |
| postgres.statefulSet.volumeMounts | list | `[]` |  |
| postgres.statefulSet.volumes | list | `[]` |  |

## Queue

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| queue.autoscaling.createHpa | bool | `true` |  |
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.maxReplicas | int | `10` |  |
| queue.autoscaling.minReplicas | int | `3` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| queue.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.autoRestart | bool | `true` |  |
| queue.deployment.command[0] | string | `"saq"` |  |
| queue.deployment.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.command[2] | string | `"--quiet"` |  |
| queue.deployment.extraContainerConfig | object | `{}` |  |
| queue.deployment.extraEnv | list | `[]` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.livenessProbe.exec.command[0] | string | `"saq"` |  |
| queue.deployment.livenessProbe.exec.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.livenessProbe.exec.command[2] | string | `"--check"` |  |
| queue.deployment.livenessProbe.failureThreshold | int | `6` |  |
| queue.deployment.livenessProbe.periodSeconds | int | `60` |  |
| queue.deployment.livenessProbe.timeoutSeconds | int | `30` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.readinessProbe.exec.command[0] | string | `"saq"` |  |
| queue.deployment.readinessProbe.exec.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.readinessProbe.exec.command[2] | string | `"--check"` |  |
| queue.deployment.readinessProbe.failureThreshold | int | `6` |  |
| queue.deployment.readinessProbe.periodSeconds | int | `60` |  |
| queue.deployment.readinessProbe.timeoutSeconds | int | `30` |  |
| queue.deployment.replicas | int | `3` |  |
| queue.deployment.resources.limits.cpu | string | `"2000m"` |  |
| queue.deployment.resources.limits.memory | string | `"4Gi"` |  |
| queue.deployment.resources.requests.cpu | string | `"1000m"` |  |
| queue.deployment.resources.requests.memory | string | `"2Gi"` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.sidecars | list | `[]` |  |
| queue.deployment.startupProbe.exec.command[0] | string | `"saq"` |  |
| queue.deployment.startupProbe.exec.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.startupProbe.exec.command[2] | string | `"--check"` |  |
| queue.deployment.startupProbe.failureThreshold | int | `6` |  |
| queue.deployment.startupProbe.periodSeconds | int | `60` |  |
| queue.deployment.startupProbe.timeoutSeconds | int | `30` |  |
| queue.deployment.tolerations | list | `[]` |  |
| queue.deployment.volumeMounts | list | `[]` |  |
| queue.deployment.volumes | list | `[]` |  |
| queue.name | string | `"queue"` |  |
| queue.serviceAccount.annotations | object | `{}` |  |
| queue.serviceAccount.create | bool | `true` |  |
| queue.serviceAccount.labels | object | `{}` |  |
| queue.serviceAccount.name | string | `""` |  |

## Redis

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.containerPort | int | `6379` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.enabled | bool | `false` |  |
| redis.external.existingSecretName | string | `""` |  |
| redis.name | string | `"redis"` |  |
| redis.service.annotations | object | `{}` |  |
| redis.service.labels | object | `{}` |  |
| redis.service.loadBalancerIP | string | `""` |  |
| redis.service.loadBalancerSourceRanges | list | `[]` |  |
| redis.service.port | int | `6379` |  |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.serviceAccount.annotations | object | `{}` |  |
| redis.serviceAccount.create | bool | `true` |  |
| redis.serviceAccount.labels | object | `{}` |  |
| redis.serviceAccount.name | string | `""` |  |
| redis.statefulSet.affinity | object | `{}` |  |
| redis.statefulSet.annotations | object | `{}` |  |
| redis.statefulSet.command | list | `[]` |  |
| redis.statefulSet.extraContainerConfig | object | `{}` |  |
| redis.statefulSet.extraEnv | list | `[]` |  |
| redis.statefulSet.labels | object | `{}` |  |
| redis.statefulSet.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.livenessProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.livenessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.nodeSelector | object | `{}` |  |
| redis.statefulSet.persistence.enabled | bool | `true` |  |
| redis.statefulSet.persistence.size | string | `"8Gi"` |  |
| redis.statefulSet.persistence.storageClassName | string | `""` |  |
| redis.statefulSet.podSecurityContext | object | `{}` |  |
| redis.statefulSet.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.readinessProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.readinessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.resources.limits.cpu | string | `"4000m"` |  |
| redis.statefulSet.resources.limits.memory | string | `"8Gi"` |  |
| redis.statefulSet.resources.requests.cpu | string | `"2000m"` |  |
| redis.statefulSet.resources.requests.memory | string | `"4Gi"` |  |
| redis.statefulSet.securityContext | object | `{}` |  |
| redis.statefulSet.sidecars | list | `[]` |  |
| redis.statefulSet.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.statefulSet.startupProbe.exec.command[1] | string | `"-c"` |  |
| redis.statefulSet.startupProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| redis.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| redis.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| redis.statefulSet.tolerations | list | `[]` |  |
| redis.statefulSet.volumeMounts | list | `[]` |  |
| redis.statefulSet.volumes | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith/README.md.gotmpl`
