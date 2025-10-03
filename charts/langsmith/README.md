# langsmith

![Version: 0.11.21](https://img.shields.io/badge/Version-0.11.21-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.11.64](https://img.shields.io/badge/AppVersion-0.11.64-informational?style=flat-square)

Helm chart to deploy the langsmith application and all services it depends on.

## Documentation

For information on how to use this chart, up-to-date release notes, and other guides please check out the [documentation.](https://docs.smith.langchain.com/self_hosting)

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonEnv | list | `[]` | Common environment variables that will be applied to all deployments/statefulsets except for the playground/aceBackend services (which are sandboxed). Be careful not to override values already specified by the chart. |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| commonPodAnnotations | object | `{}` | Annotations that will be applied to all pods created by the chart |
| commonVolumeMounts | list | `[]` | Common volume mounts added to all deployments/statefulsets except for the playground/aceBackend services (which are sandboxed). |
| commonVolumes | list | `[]` | Common volumes added to all deployments/statefulsets except for the playground/aceBackend services (which are sandboxed). |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| gateway.annotations | object | `{}` |  |
| gateway.enabled | bool | `false` |  |
| gateway.hostname | string | `""` |  |
| gateway.labels | object | `{}` |  |
| gateway.name | string | `""` |  |
| gateway.namespace | string | `""` |  |
| gateway.sectionName | string | `""` |  |
| gateway.subdomain | string | `""` |  |
| images.aceBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.aceBackendImage.repository | string | `"docker.io/langchain/langsmith-ace-backend"` |  |
| images.aceBackendImage.tag | string | `"0.11.64"` |  |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"docker.io/langchain/langsmith-backend"` |  |
| images.backendImage.tag | string | `"0.11.64"` |  |
| images.clickhouseImage.pullPolicy | string | `"Always"` |  |
| images.clickhouseImage.repository | string | `"docker.io/clickhouse/clickhouse-server"` |  |
| images.clickhouseImage.tag | string | `"25.4"` |  |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"docker.io/langchain/langsmith-frontend"` |  |
| images.frontendImage.tag | string | `"0.11.64"` |  |
| images.hostBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.hostBackendImage.repository | string | `"docker.io/langchain/hosted-langserve-backend"` |  |
| images.hostBackendImage.tag | string | `"0.11.64"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.operatorImage.pullPolicy | string | `"Always"` |  |
| images.operatorImage.repository | string | `"docker.io/langchain/langgraph-operator"` |  |
| images.operatorImage.tag | string | `"0.1.11"` |  |
| images.platformBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.platformBackendImage.repository | string | `"docker.io/langchain/langsmith-go-backend"` |  |
| images.platformBackendImage.tag | string | `"0.11.64"` |  |
| images.playgroundImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.playgroundImage.repository | string | `"docker.io/langchain/langsmith-playground"` |  |
| images.playgroundImage.tag | string | `"0.11.64"` |  |
| images.postgresImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.postgresImage.repository | string | `"docker.io/postgres"` |  |
| images.postgresImage.tag | string | `"14.7"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"7"` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.subdomain | string | `""` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langsmith` |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.apiKeySalt | string | `""` | Salt used to generate the API key. Should be a random string. |
| config.authType | string | `""` | Must be 'oauth' for OAuth with PKCE, 'mixed' for basic auth or OAuth without PKCE |
| config.basicAuth.enabled | bool | `false` |  |
| config.basicAuth.initialOrgAdminEmail | string | `""` | Kept for backwards compatibility. Will be removed in a future release. Please use values.config.initialOrgAdminEmail instead. |
| config.basicAuth.initialOrgAdminPassword | string | `""` |  |
| config.basicAuth.jwtSecret | string | `""` |  |
| config.blobStorage | object | `{"accessKey":"","accessKeySecret":"","apiURL":"https://s3.us-west-2.amazonaws.com","azureStorageAccountKey":"","azureStorageAccountName":"","azureStorageConnectionString":"","azureStorageContainerName":"","azureStorageServiceUrlOverride":"","bucketName":"","chSearchEnabled":true,"enabled":false,"engine":"S3","minBlobStorageSizeKb":"20"}` | Blob storage configuration Optional. Used to store inputs, outputs, and errors in Blob Storage. We currently support S3, GCS, Minio, and Azure as Blob Storage providers. |
| config.blobStorage.azureStorageAccountName | string | `""` | Optional. Set this along with azureStorageAccountKey to use a storage account and access key. Higher precedence than azureStorageConnectionString. |
| config.blobStorage.azureStorageConnectionString | string | `""` | Optional. Use this to specify the full connection string including any authentication params. |
| config.blobStorage.azureStorageContainerName | string | `""` | Required if using Azure blob storage |
| config.blobStorage.azureStorageServiceUrlOverride | string | `""` | Optional. Use this to customize the service URL, which by default is 'https://<storage_account_name>.blob.core.windows.net/' |
| config.customCa.secretKey | string | `""` |  |
| config.customCa.secretName | string | `""` | Optional. Used to set a file containing trusted CA certificates. Make sure to also include a public CA to access beacon and playground. |
| config.customLogo | object | `{"coBrandingEnabled":true,"enabled":false,"logoUrl":""}` | Custom logo configuration. If enabled, the logoUrl and coBrandingEnabled values must be provided. The logoUrl must be a valid URL to an image like png, jpg, or svg. Co-branding will show LangSmith and customer logos side by side. |
| config.defaultWorkspaceName | string | `"Workspace 1"` | Default workspace name to be provisioned when org is created. |
| config.existingSecretName | string | `""` |  |
| config.hostname | string | `""` | Base URL of the LangSmith installation. Used for redirects. |
| config.initialOrgAdminEmail | string | `""` |  |
| config.initialOrgName | string | `"Default"` | Initial org name to be provisioned. |
| config.langgraphPlatform.enabled | bool | `false` | Optional. Used to enable the Langgraph platform control plane. If enabled, the license key must be provided. |
| config.langgraphPlatform.ingressHealthCheckEnabled | bool | `true` |  |
| config.langgraphPlatform.langgraphPlatformLicenseKey | string | `""` |  |
| config.langgraphPlatform.rootDomain | string | `""` |  |
| config.langgraphPlatform.tlsEnabled | bool | `true` |  |
| config.langsmithLicenseKey | string | `""` |  |
| config.logLevel | string | `"info"` |  |
| config.oauth.enabled | bool | `false` |  |
| config.oauth.oauthClientId | string | `""` |  |
| config.oauth.oauthClientSecret | string | `""` | Client secret requires authType to be 'mixed' and hostname to be present |
| config.oauth.oauthIssuerUrl | string | `""` |  |
| config.oauth.oauthScopes | string | `"email,profile,openid"` |  |
| config.oauth.oauthSessionMaxSec | string | `"86400"` |  |
| config.observability.tracing.enabled | bool | `false` |  |
| config.observability.tracing.endpoint | string | `""` |  |
| config.observability.tracing.env | string | `"ls_self_hosted"` |  |
| config.observability.tracing.exporter | string | `"http"` |  |
| config.observability.tracing.useTls | bool | `true` |  |
| config.personalOrgsDisabled | bool | `true` | Disable personal orgs. |
| config.settings | object | `{"redisRunsExpirySeconds":"21600"}` | Application Settings. These are used to tune the application |
| config.settings.redisRunsExpirySeconds | string | `"21600"` | Optional. Be very careful when lowering this value as it can result in runs being lost if your queue is down/not processing items fast enough. |
| config.telemetry.metrics | bool | `true` | Optional. These values are used to send telemetry to the LangChain team to assist with troubleshooting. |
| config.telemetry.traces | bool | `true` |  |
| config.ttl | object | `{"enabled":true,"ttl_period_seconds":{"longlived":"34560000","shortlived":"1209600"}}` | TTL configuration Optional. Used to set TTLS for longlived and shortlived objects. |
| config.ttl.ttl_period_seconds.longlived | string | `"34560000"` | 400 day longlived and 14 day shortlived |
| config.userOrgCreationDisabled | bool | `true` | Prevent organization creation by users. This includes admins. |
| config.workspaceScopeOrgInvitesEnabled | bool | `false` | Enable Workspace Admins to invite users to the org and workspace. |

## Ace Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aceBackend.autoscaling.createHpa | bool | `true` |  |
| aceBackend.autoscaling.enabled | bool | `false` |  |
| aceBackend.autoscaling.maxReplicas | int | `5` |  |
| aceBackend.autoscaling.minReplicas | int | `1` |  |
| aceBackend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| aceBackend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| aceBackend.bindAddress | string | `"0.0.0.0"` |  |
| aceBackend.containerPort | int | `1987` |  |
| aceBackend.deployment.affinity | object | `{}` |  |
| aceBackend.deployment.annotations | object | `{}` |  |
| aceBackend.deployment.command[0] | string | `"./entrypoint.sh"` |  |
| aceBackend.deployment.extraContainerConfig | object | `{}` |  |
| aceBackend.deployment.extraEnv | list | `[]` |  |
| aceBackend.deployment.initContainers | list | `[]` |  |
| aceBackend.deployment.labels | object | `{}` |  |
| aceBackend.deployment.livenessProbe.failureThreshold | int | `6` |  |
| aceBackend.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| aceBackend.deployment.livenessProbe.httpGet.port | int | `1987` |  |
| aceBackend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| aceBackend.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| aceBackend.deployment.nodeSelector | object | `{}` |  |
| aceBackend.deployment.podSecurityContext | object | `{}` |  |
| aceBackend.deployment.readinessProbe.failureThreshold | int | `6` |  |
| aceBackend.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| aceBackend.deployment.readinessProbe.httpGet.port | int | `1987` |  |
| aceBackend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| aceBackend.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| aceBackend.deployment.replicas | int | `1` |  |
| aceBackend.deployment.resources.limits.cpu | string | `"1000m"` |  |
| aceBackend.deployment.resources.limits.memory | string | `"2Gi"` |  |
| aceBackend.deployment.resources.requests.cpu | string | `"200m"` |  |
| aceBackend.deployment.resources.requests.memory | string | `"1000Mi"` |  |
| aceBackend.deployment.securityContext | object | `{}` |  |
| aceBackend.deployment.sidecars | list | `[]` |  |
| aceBackend.deployment.startupProbe.failureThreshold | int | `6` |  |
| aceBackend.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| aceBackend.deployment.startupProbe.httpGet.port | int | `1987` |  |
| aceBackend.deployment.startupProbe.periodSeconds | int | `10` |  |
| aceBackend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| aceBackend.deployment.terminationGracePeriodSeconds | int | `30` |  |
| aceBackend.deployment.tolerations | list | `[]` |  |
| aceBackend.deployment.topologySpreadConstraints | list | `[]` |  |
| aceBackend.deployment.volumeMounts | list | `[]` |  |
| aceBackend.deployment.volumes | list | `[]` |  |
| aceBackend.name | string | `"ace-backend"` |  |
| aceBackend.pdb.annotations | object | `{}` |  |
| aceBackend.pdb.enabled | bool | `false` |  |
| aceBackend.pdb.labels | object | `{}` |  |
| aceBackend.pdb.minAvailable | int | `1` |  |
| aceBackend.service.annotations | object | `{}` |  |
| aceBackend.service.labels | object | `{}` |  |
| aceBackend.service.loadBalancerIP | string | `""` |  |
| aceBackend.service.loadBalancerSourceRanges | list | `[]` |  |
| aceBackend.service.port | int | `1987` |  |
| aceBackend.service.type | string | `"ClusterIP"` |  |
| aceBackend.serviceAccount.annotations | object | `{}` |  |
| aceBackend.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| aceBackend.serviceAccount.create | bool | `true` |  |
| aceBackend.serviceAccount.labels | object | `{}` |  |
| aceBackend.serviceAccount.name | string | `""` |  |

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.authBootstrap.affinity | object | `{}` |  |
| backend.authBootstrap.annotations | object | `{}` |  |
| backend.authBootstrap.command[0] | string | `"./auth_bootstrap_entrypoint.sh"` |  |
| backend.authBootstrap.extraContainerConfig | object | `{}` |  |
| backend.authBootstrap.extraEnv | list | `[]` |  |
| backend.authBootstrap.initContainers | list | `[]` |  |
| backend.authBootstrap.labels | object | `{}` |  |
| backend.authBootstrap.nodeSelector | object | `{}` |  |
| backend.authBootstrap.podSecurityContext | object | `{}` |  |
| backend.authBootstrap.randomizeName | bool | `false` |  |
| backend.authBootstrap.resources.limits.cpu | string | `"1000m"` |  |
| backend.authBootstrap.resources.limits.memory | string | `"1Gi"` |  |
| backend.authBootstrap.resources.requests.cpu | string | `"200m"` |  |
| backend.authBootstrap.resources.requests.memory | string | `"500Mi"` |  |
| backend.authBootstrap.securityContext | object | `{}` |  |
| backend.authBootstrap.sidecars | list | `[]` |  |
| backend.authBootstrap.tolerations | list | `[]` |  |
| backend.authBootstrap.topologySpreadConstraints | list | `[]` |  |
| backend.authBootstrap.ttlSecondsAfterFinished | int | `600` |  |
| backend.authBootstrap.volumeMounts | list | `[]` |  |
| backend.authBootstrap.volumes | list | `[]` |  |
| backend.autoscaling.createHpa | bool | `true` |  |
| backend.autoscaling.enabled | bool | `false` |  |
| backend.autoscaling.maxReplicas | int | `6` |  |
| backend.autoscaling.minReplicas | int | `2` |  |
| backend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| backend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| backend.clickhouseMigrations.affinity | object | `{}` |  |
| backend.clickhouseMigrations.annotations | object | `{}` |  |
| backend.clickhouseMigrations.command[0] | string | `"./ch_migration_entrypoint.sh"` |  |
| backend.clickhouseMigrations.enabled | bool | `true` |  |
| backend.clickhouseMigrations.extraContainerConfig | object | `{}` |  |
| backend.clickhouseMigrations.extraEnv | list | `[]` |  |
| backend.clickhouseMigrations.initContainers | list | `[]` |  |
| backend.clickhouseMigrations.labels | object | `{}` |  |
| backend.clickhouseMigrations.nodeSelector | object | `{}` |  |
| backend.clickhouseMigrations.podSecurityContext | object | `{}` |  |
| backend.clickhouseMigrations.randomizeName | bool | `false` |  |
| backend.clickhouseMigrations.resources.limits.cpu | string | `"1000m"` |  |
| backend.clickhouseMigrations.resources.limits.memory | string | `"1Gi"` |  |
| backend.clickhouseMigrations.resources.requests.cpu | string | `"200m"` |  |
| backend.clickhouseMigrations.resources.requests.memory | string | `"500Mi"` |  |
| backend.clickhouseMigrations.securityContext | object | `{}` |  |
| backend.clickhouseMigrations.sidecars | list | `[]` |  |
| backend.clickhouseMigrations.tolerations | list | `[]` |  |
| backend.clickhouseMigrations.topologySpreadConstraints | list | `[]` |  |
| backend.clickhouseMigrations.ttlSecondsAfterFinished | int | `600` |  |
| backend.clickhouseMigrations.volumeMounts | list | `[]` |  |
| backend.clickhouseMigrations.volumes | list | `[]` |  |
| backend.containerPort | int | `1984` |  |
| backend.deployment.affinity | object | `{}` |  |
| backend.deployment.annotations | object | `{}` |  |
| backend.deployment.command[0] | string | `"./entrypoint.sh"` |  |
| backend.deployment.extraContainerConfig | object | `{}` |  |
| backend.deployment.extraEnv | list | `[]` |  |
| backend.deployment.initContainers | list | `[]` |  |
| backend.deployment.labels | object | `{}` |  |
| backend.deployment.livenessProbe.failureThreshold | int | `6` |  |
| backend.deployment.livenessProbe.httpGet.path | string | `"/health"` |  |
| backend.deployment.livenessProbe.httpGet.port | int | `1984` |  |
| backend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| backend.deployment.livenessProbe.timeoutSeconds | int | `10` |  |
| backend.deployment.nodeSelector | object | `{}` |  |
| backend.deployment.podSecurityContext | object | `{}` |  |
| backend.deployment.readinessProbe.failureThreshold | int | `6` |  |
| backend.deployment.readinessProbe.httpGet.path | string | `"/health"` |  |
| backend.deployment.readinessProbe.httpGet.port | int | `1984` |  |
| backend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| backend.deployment.readinessProbe.timeoutSeconds | int | `10` |  |
| backend.deployment.replicas | int | `2` |  |
| backend.deployment.resources.limits.cpu | string | `"2000m"` |  |
| backend.deployment.resources.limits.memory | string | `"4Gi"` |  |
| backend.deployment.resources.requests.cpu | string | `"1000m"` |  |
| backend.deployment.resources.requests.memory | string | `"2Gi"` |  |
| backend.deployment.securityContext | object | `{}` |  |
| backend.deployment.sidecars | list | `[]` |  |
| backend.deployment.startupProbe.failureThreshold | int | `6` |  |
| backend.deployment.startupProbe.httpGet.path | string | `"/health"` |  |
| backend.deployment.startupProbe.httpGet.port | int | `1984` |  |
| backend.deployment.startupProbe.periodSeconds | int | `10` |  |
| backend.deployment.startupProbe.timeoutSeconds | int | `10` |  |
| backend.deployment.terminationGracePeriodSeconds | int | `30` |  |
| backend.deployment.tolerations | list | `[]` |  |
| backend.deployment.topologySpreadConstraints | list | `[]` |  |
| backend.deployment.volumeMounts | list | `[]` |  |
| backend.deployment.volumes | list | `[]` |  |
| backend.existingConfigMapName | string | `""` |  |
| backend.feedbackConfigMigration.affinity | object | `{}` |  |
| backend.feedbackConfigMigration.annotations | object | `{}` |  |
| backend.feedbackConfigMigration.command[0] | string | `"python"` |  |
| backend.feedbackConfigMigration.command[1] | string | `"scripts/jobs/migrate-feedback-config.pyc"` |  |
| backend.feedbackConfigMigration.enabled | bool | `true` |  |
| backend.feedbackConfigMigration.extraContainerConfig | object | `{}` |  |
| backend.feedbackConfigMigration.extraEnv | list | `[]` |  |
| backend.feedbackConfigMigration.initContainers | list | `[]` |  |
| backend.feedbackConfigMigration.labels | object | `{}` |  |
| backend.feedbackConfigMigration.nodeSelector | object | `{}` |  |
| backend.feedbackConfigMigration.podSecurityContext | object | `{}` |  |
| backend.feedbackConfigMigration.randomizeName | bool | `false` |  |
| backend.feedbackConfigMigration.resources.limits.cpu | string | `"2000m"` |  |
| backend.feedbackConfigMigration.resources.limits.memory | string | `"4Gi"` |  |
| backend.feedbackConfigMigration.resources.requests.cpu | string | `"1000m"` |  |
| backend.feedbackConfigMigration.resources.requests.memory | string | `"2Gi"` |  |
| backend.feedbackConfigMigration.securityContext | object | `{}` |  |
| backend.feedbackConfigMigration.sidecars | list | `[]` |  |
| backend.feedbackConfigMigration.tolerations | list | `[]` |  |
| backend.feedbackConfigMigration.topologySpreadConstraints | list | `[]` |  |
| backend.feedbackConfigMigration.ttlSecondsAfterFinished | int | `600` |  |
| backend.feedbackConfigMigration.volumeMounts | list | `[]` |  |
| backend.feedbackConfigMigration.volumes | list | `[]` |  |
| backend.feedbackDataMigration.affinity | object | `{}` |  |
| backend.feedbackDataMigration.annotations | object | `{}` |  |
| backend.feedbackDataMigration.command[0] | string | `"python"` |  |
| backend.feedbackDataMigration.command[1] | string | `"scripts/jobs/migrate-feedback-to-postgres.pyc"` |  |
| backend.feedbackDataMigration.enabled | bool | `true` |  |
| backend.feedbackDataMigration.extraContainerConfig | object | `{}` |  |
| backend.feedbackDataMigration.extraEnv | list | `[]` |  |
| backend.feedbackDataMigration.initContainers | list | `[]` |  |
| backend.feedbackDataMigration.labels | object | `{}` |  |
| backend.feedbackDataMigration.nodeSelector | object | `{}` |  |
| backend.feedbackDataMigration.podSecurityContext | object | `{}` |  |
| backend.feedbackDataMigration.randomizeName | bool | `false` |  |
| backend.feedbackDataMigration.resources.limits.cpu | string | `"2000m"` |  |
| backend.feedbackDataMigration.resources.limits.memory | string | `"4Gi"` |  |
| backend.feedbackDataMigration.resources.requests.cpu | string | `"1000m"` |  |
| backend.feedbackDataMigration.resources.requests.memory | string | `"2Gi"` |  |
| backend.feedbackDataMigration.securityContext | object | `{}` |  |
| backend.feedbackDataMigration.sidecars | list | `[]` |  |
| backend.feedbackDataMigration.tolerations | list | `[]` |  |
| backend.feedbackDataMigration.topologySpreadConstraints | list | `[]` |  |
| backend.feedbackDataMigration.ttlSecondsAfterFinished | int | `600` |  |
| backend.feedbackDataMigration.volumeMounts | list | `[]` |  |
| backend.feedbackDataMigration.volumes | list | `[]` |  |
| backend.migrations.affinity | object | `{}` |  |
| backend.migrations.annotations | object | `{}` |  |
| backend.migrations.command[0] | string | `"./pg_migration_entrypoint.sh"` |  |
| backend.migrations.enabled | bool | `true` |  |
| backend.migrations.extraContainerConfig | object | `{}` |  |
| backend.migrations.extraEnv | list | `[]` |  |
| backend.migrations.initContainers | list | `[]` |  |
| backend.migrations.labels | object | `{}` |  |
| backend.migrations.nodeSelector | object | `{}` |  |
| backend.migrations.podSecurityContext | object | `{}` |  |
| backend.migrations.randomizeName | bool | `false` |  |
| backend.migrations.resources.limits.cpu | string | `"1000m"` |  |
| backend.migrations.resources.limits.memory | string | `"1Gi"` |  |
| backend.migrations.resources.requests.cpu | string | `"200m"` |  |
| backend.migrations.resources.requests.memory | string | `"500Mi"` |  |
| backend.migrations.securityContext | object | `{}` |  |
| backend.migrations.sidecars | list | `[]` |  |
| backend.migrations.tolerations | list | `[]` |  |
| backend.migrations.topologySpreadConstraints | list | `[]` |  |
| backend.migrations.ttlSecondsAfterFinished | int | `600` |  |
| backend.migrations.volumeMounts | list | `[]` |  |
| backend.migrations.volumes | list | `[]` |  |
| backend.name | string | `"backend"` |  |
| backend.pdb.annotations | object | `{}` |  |
| backend.pdb.enabled | bool | `false` |  |
| backend.pdb.labels | object | `{}` |  |
| backend.pdb.minAvailable | int | `1` |  |
| backend.service.annotations | object | `{}` |  |
| backend.service.labels | object | `{}` |  |
| backend.service.loadBalancerIP | string | `""` |  |
| backend.service.loadBalancerSourceRanges | list | `[]` |  |
| backend.service.port | int | `1984` |  |
| backend.service.type | string | `"ClusterIP"` |  |
| backend.serviceAccount.annotations | object | `{}` |  |
| backend.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| backend.serviceAccount.create | bool | `true` |  |
| backend.serviceAccount.labels | object | `{}` |  |
| backend.serviceAccount.name | string | `""` |  |

## Clickhouse

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.config.allowSimdjson | bool | `true` |  |
| clickhouse.config.logLevel | string | `"warning"` |  |
| clickhouse.containerHttpPort | int | `8123` |  |
| clickhouse.containerNativePort | int | `9000` |  |
| clickhouse.external.cluster | string | `""` |  |
| clickhouse.external.database | string | `"default"` |  |
| clickhouse.external.databaseSecretKey | string | `"clickhouse_db"` |  |
| clickhouse.external.enabled | bool | `false` |  |
| clickhouse.external.existingSecretName | string | `""` |  |
| clickhouse.external.host | string | `""` |  |
| clickhouse.external.hostSecretKey | string | `"clickhouse_host"` |  |
| clickhouse.external.hybrid | bool | `false` | Must be set to true if using managed ClickHouse |
| clickhouse.external.nativePort | string | `"9000"` |  |
| clickhouse.external.nativePortSecretKey | string | `"clickhouse_native_port"` |  |
| clickhouse.external.password | string | `"password"` |  |
| clickhouse.external.passwordSecretKey | string | `"clickhouse_password"` |  |
| clickhouse.external.port | string | `"8123"` |  |
| clickhouse.external.portSecretKey | string | `"clickhouse_port"` |  |
| clickhouse.external.tls | bool | `false` |  |
| clickhouse.external.tlsSecretKey | string | `"clickhouse_tls"` |  |
| clickhouse.external.user | string | `"default"` |  |
| clickhouse.external.userSecretKey | string | `"clickhouse_user"` |  |
| clickhouse.metrics.port | int | `9363` |  |
| clickhouse.name | string | `"clickhouse"` |  |
| clickhouse.pdb.annotations | object | `{}` |  |
| clickhouse.pdb.enabled | bool | `false` |  |
| clickhouse.pdb.labels | object | `{}` |  |
| clickhouse.pdb.minAvailable | int | `1` |  |
| clickhouse.service.annotations | object | `{}` |  |
| clickhouse.service.httpPort | int | `8123` |  |
| clickhouse.service.labels | object | `{}` |  |
| clickhouse.service.loadBalancerIP | string | `""` |  |
| clickhouse.service.loadBalancerSourceRanges | list | `[]` |  |
| clickhouse.service.nativePort | int | `9000` |  |
| clickhouse.service.type | string | `"ClusterIP"` |  |
| clickhouse.serviceAccount.annotations | object | `{}` |  |
| clickhouse.serviceAccount.automountServiceAccountToken | bool | `true` |  |
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
| clickhouse.statefulSet.initContainers | list | `[]` |  |
| clickhouse.statefulSet.labels | object | `{}` |  |
| clickhouse.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.livenessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.enabled | bool | `true` |  |
| clickhouse.statefulSet.persistence.size | string | `"50Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.readinessProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.readinessProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.readinessProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.readinessProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.resources.limits.cpu | string | `"8000m"` |  |
| clickhouse.statefulSet.resources.limits.memory | string | `"32Gi"` |  |
| clickhouse.statefulSet.resources.requests.cpu | string | `"3500m"` |  |
| clickhouse.statefulSet.resources.requests.memory | string | `"12Gi"` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.sidecars | list | `[]` |  |
| clickhouse.statefulSet.startupProbe.failureThreshold | int | `6` |  |
| clickhouse.statefulSet.startupProbe.httpGet.path | string | `"/ping"` |  |
| clickhouse.statefulSet.startupProbe.httpGet.port | int | `8123` |  |
| clickhouse.statefulSet.startupProbe.periodSeconds | int | `10` |  |
| clickhouse.statefulSet.startupProbe.timeoutSeconds | int | `1` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.topologySpreadConstraints | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |

## E2E Test

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| e2eTest.affinity | object | `{}` |  |
| e2eTest.annotations | object | `{}` |  |
| e2eTest.command[0] | string | `"python"` |  |
| e2eTest.command[1] | string | `"scripts/test_e2e_trace.pyc"` |  |
| e2eTest.enabled | bool | `true` |  |
| e2eTest.extraContainerConfig | object | `{}` |  |
| e2eTest.extraEnv | list | `[]` |  |
| e2eTest.initContainers | list | `[]` |  |
| e2eTest.labels | object | `{}` |  |
| e2eTest.name | string | `"e2e-test"` |  |
| e2eTest.nodeSelector | object | `{}` |  |
| e2eTest.podSecurityContext | object | `{}` |  |
| e2eTest.resources.limits.cpu | string | `"500m"` |  |
| e2eTest.resources.limits.memory | string | `"1Gi"` |  |
| e2eTest.resources.requests.cpu | string | `"200m"` |  |
| e2eTest.resources.requests.memory | string | `"500Mi"` |  |
| e2eTest.securityContext | object | `{}` |  |
| e2eTest.serviceAccount.annotations | object | `{}` |  |
| e2eTest.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| e2eTest.serviceAccount.create | bool | `false` |  |
| e2eTest.serviceAccount.labels | object | `{}` |  |
| e2eTest.serviceAccount.name | string | `""` |  |
| e2eTest.sidecars | list | `[]` |  |
| e2eTest.tolerations | list | `[]` |  |
| e2eTest.topologySpreadConstraints | list | `[]` |  |
| e2eTest.ttlSecondsAfterFinished | int | `10` |  |
| e2eTest.volumeMounts | list | `[]` |  |
| e2eTest.volumes | list | `[]` |  |

## Host Backend (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hostBackend.autoscaling.createHpa | bool | `true` |  |
| hostBackend.autoscaling.enabled | bool | `false` |  |
| hostBackend.autoscaling.maxReplicas | int | `5` |  |
| hostBackend.autoscaling.minReplicas | int | `1` |  |
| hostBackend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| hostBackend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| hostBackend.containerPort | int | `1985` |  |
| hostBackend.deployment.affinity | object | `{}` |  |
| hostBackend.deployment.annotations | object | `{}` |  |
| hostBackend.deployment.command[0] | string | `"./entrypoint.sh"` |  |
| hostBackend.deployment.extraContainerConfig | object | `{}` |  |
| hostBackend.deployment.extraEnv | list | `[]` |  |
| hostBackend.deployment.initContainers | list | `[]` |  |
| hostBackend.deployment.labels | object | `{}` |  |
| hostBackend.deployment.livenessProbe.failureThreshold | int | `6` |  |
| hostBackend.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| hostBackend.deployment.livenessProbe.httpGet.port | int | `1985` |  |
| hostBackend.deployment.livenessProbe.periodSeconds | int | `10` |  |
| hostBackend.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| hostBackend.deployment.nodeSelector | object | `{}` |  |
| hostBackend.deployment.podSecurityContext | object | `{}` |  |
| hostBackend.deployment.readinessProbe.failureThreshold | int | `6` |  |
| hostBackend.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| hostBackend.deployment.readinessProbe.httpGet.port | int | `1985` |  |
| hostBackend.deployment.readinessProbe.periodSeconds | int | `10` |  |
| hostBackend.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| hostBackend.deployment.replicas | int | `1` |  |
| hostBackend.deployment.resources.limits.cpu | string | `"1000m"` |  |
| hostBackend.deployment.resources.limits.memory | string | `"2Gi"` |  |
| hostBackend.deployment.resources.requests.cpu | string | `"200m"` |  |
| hostBackend.deployment.resources.requests.memory | string | `"1000Mi"` |  |
| hostBackend.deployment.securityContext | object | `{}` |  |
| hostBackend.deployment.sidecars | list | `[]` |  |
| hostBackend.deployment.startupProbe.failureThreshold | int | `6` |  |
| hostBackend.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| hostBackend.deployment.startupProbe.httpGet.port | int | `1985` |  |
| hostBackend.deployment.startupProbe.periodSeconds | int | `10` |  |
| hostBackend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| hostBackend.deployment.terminationGracePeriodSeconds | int | `30` |  |
| hostBackend.deployment.tolerations | list | `[]` |  |
| hostBackend.deployment.topologySpreadConstraints | list | `[]` |  |
| hostBackend.deployment.volumeMounts | list | `[]` |  |
| hostBackend.deployment.volumes | list | `[]` |  |
| hostBackend.name | string | `"host-backend"` |  |
| hostBackend.pdb.annotations | object | `{}` |  |
| hostBackend.pdb.enabled | bool | `false` |  |
| hostBackend.pdb.labels | object | `{}` |  |
| hostBackend.pdb.minAvailable | int | `1` |  |
| hostBackend.rbac.annotations | object | `{}` |  |
| hostBackend.rbac.create | bool | `true` |  |
| hostBackend.rbac.labels | object | `{}` |  |
| hostBackend.service.annotations | object | `{}` |  |
| hostBackend.service.labels | object | `{}` |  |
| hostBackend.service.loadBalancerIP | string | `""` |  |
| hostBackend.service.loadBalancerSourceRanges | list | `[]` |  |
| hostBackend.service.port | int | `1985` |  |
| hostBackend.service.type | string | `"ClusterIP"` |  |
| hostBackend.serviceAccount.annotations | object | `{}` |  |
| hostBackend.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| hostBackend.serviceAccount.create | bool | `true` |  |
| hostBackend.serviceAccount.labels | object | `{}` |  |
| hostBackend.serviceAccount.name | string | `""` |  |

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
| frontend.deployment.command[0] | string | `"/entrypoint.sh"` |  |
| frontend.deployment.extraContainerConfig | object | `{}` |  |
| frontend.deployment.extraEnv | list | `[]` |  |
| frontend.deployment.initContainers | list | `[]` |  |
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
| frontend.deployment.terminationGracePeriodSeconds | int | `30` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.deployment.topologySpreadConstraints | list | `[]` |  |
| frontend.deployment.volumeMounts | list | `[]` |  |
| frontend.deployment.volumes | list | `[]` |  |
| frontend.existingConfigMapName | string | `""` |  |
| frontend.ipv6Enabled | bool | `true` |  |
| frontend.keepAliveTimeout | string | `"75"` |  |
| frontend.maxBodySize | string | `"25M"` |  |
| frontend.name | string | `"frontend"` |  |
| frontend.pdb.annotations | object | `{}` |  |
| frontend.pdb.enabled | bool | `false` |  |
| frontend.pdb.labels | object | `{}` |  |
| frontend.pdb.minAvailable | int | `1` |  |
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
| frontend.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| frontend.serviceAccount.create | bool | `true` |  |
| frontend.serviceAccount.labels | object | `{}` |  |
| frontend.serviceAccount.name | string | `""` |  |
| frontend.ssl.certificatePath | string | `""` |  |
| frontend.ssl.enabled | bool | `false` |  |
| frontend.ssl.keyPath | string | `""` |  |
| frontend.ssl.port | int | `8443` |  |

## Listener (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| listener.autoscaling.createHpa | bool | `true` |  |
| listener.autoscaling.enabled | bool | `false` |  |
| listener.autoscaling.maxReplicas | int | `10` |  |
| listener.autoscaling.minReplicas | int | `3` |  |
| listener.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| listener.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| listener.containerPort | int | `8080` |  |
| listener.deployment.affinity | object | `{}` |  |
| listener.deployment.annotations | object | `{}` |  |
| listener.deployment.command[0] | string | `"./listener_entrypoint.sh"` |  |
| listener.deployment.extraContainerConfig | object | `{}` |  |
| listener.deployment.extraEnv | list | `[]` |  |
| listener.deployment.initContainers | list | `[]` |  |
| listener.deployment.labels | object | `{}` |  |
| listener.deployment.livenessProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.livenessProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.livenessProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.livenessProbe.failureThreshold | int | `6` |  |
| listener.deployment.livenessProbe.periodSeconds | int | `60` |  |
| listener.deployment.livenessProbe.timeoutSeconds | int | `60` |  |
| listener.deployment.nodeSelector | object | `{}` |  |
| listener.deployment.podSecurityContext | object | `{}` |  |
| listener.deployment.readinessProbe.failureThreshold | int | `6` |  |
| listener.deployment.readinessProbe.httpGet.path | string | `"/health"` |  |
| listener.deployment.readinessProbe.httpGet.port | int | `8080` |  |
| listener.deployment.readinessProbe.periodSeconds | int | `10` |  |
| listener.deployment.readinessProbe.timeoutSeconds | int | `10` |  |
| listener.deployment.replicas | int | `1` |  |
| listener.deployment.resources.limits.cpu | string | `"2000m"` |  |
| listener.deployment.resources.limits.memory | string | `"4Gi"` |  |
| listener.deployment.resources.requests.cpu | string | `"1000m"` |  |
| listener.deployment.resources.requests.memory | string | `"2Gi"` |  |
| listener.deployment.securityContext | object | `{}` |  |
| listener.deployment.sidecars | list | `[]` |  |
| listener.deployment.startupProbe.failureThreshold | int | `6` |  |
| listener.deployment.startupProbe.httpGet.path | string | `"/health"` |  |
| listener.deployment.startupProbe.httpGet.port | int | `8080` |  |
| listener.deployment.startupProbe.periodSeconds | int | `10` |  |
| listener.deployment.startupProbe.timeoutSeconds | int | `10` |  |
| listener.deployment.terminationGracePeriodSeconds | int | `30` |  |
| listener.deployment.tolerations | list | `[]` |  |
| listener.deployment.topologySpreadConstraints | list | `[]` |  |
| listener.deployment.volumeMounts | list | `[]` |  |
| listener.deployment.volumes | list | `[]` |  |
| listener.name | string | `"listener"` |  |
| listener.pdb.annotations | object | `{}` |  |
| listener.pdb.enabled | bool | `false` |  |
| listener.pdb.labels | object | `{}` |  |
| listener.pdb.minAvailable | int | `1` |  |
| listener.rbac.annotations | object | `{}` |  |
| listener.rbac.create | bool | `true` |  |
| listener.rbac.labels | object | `{}` |  |
| listener.serviceAccount.annotations | object | `{}` |  |
| listener.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| listener.serviceAccount.create | bool | `true` |  |
| listener.serviceAccount.labels | object | `{}` |  |
| listener.serviceAccount.name | string | `""` |  |

## Operator (Optional)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| operator.createCRDs | bool | `true` |  |
| operator.deployment.affinity | object | `{}` |  |
| operator.deployment.annotations | object | `{}` |  |
| operator.deployment.extraContainerConfig | object | `{}` |  |
| operator.deployment.extraEnv | list | `[]` |  |
| operator.deployment.initContainers | list | `[]` |  |
| operator.deployment.labels | object | `{}` |  |
| operator.deployment.nodeSelector | object | `{}` |  |
| operator.deployment.podSecurityContext | object | `{}` |  |
| operator.deployment.replicas | int | `1` |  |
| operator.deployment.resources.limits.cpu | string | `"2000m"` |  |
| operator.deployment.resources.limits.memory | string | `"4Gi"` |  |
| operator.deployment.resources.requests.cpu | string | `"1000m"` |  |
| operator.deployment.resources.requests.memory | string | `"2Gi"` |  |
| operator.deployment.securityContext | object | `{}` |  |
| operator.deployment.sidecars | list | `[]` |  |
| operator.deployment.terminationGracePeriodSeconds | int | `30` |  |
| operator.deployment.tolerations | list | `[]` |  |
| operator.deployment.topologySpreadConstraints | list | `[]` |  |
| operator.deployment.volumeMounts | list | `[]` |  |
| operator.deployment.volumes | list | `[]` |  |
| operator.enabled | bool | `true` |  |
| operator.kedaEnabled | bool | `true` |  |
| operator.name | string | `"operator"` |  |
| operator.pdb.annotations | object | `{}` |  |
| operator.pdb.enabled | bool | `false` |  |
| operator.pdb.labels | object | `{}` |  |
| operator.pdb.minAvailable | int | `1` |  |
| operator.rbac.annotations | object | `{}` |  |
| operator.rbac.create | bool | `true` |  |
| operator.rbac.labels | object | `{}` |  |
| operator.serviceAccount.annotations | object | `{}` |  |
| operator.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| operator.serviceAccount.create | bool | `true` |  |
| operator.serviceAccount.labels | object | `{}` |  |
| operator.serviceAccount.name | string | `""` |  |
| operator.templates.db | string | `"apiVersion: apps/v1\nkind: StatefulSet\nmetadata:\n  name: ${service_name}\nspec:\n  serviceName: ${service_name}\n  selector:\n    matchLabels:\n      app: ${service_name}\n  persistentVolumeClaimRetentionPolicy:\n    whenDeleted: Delete\n    whenScaled: Retain\n  template:\n    metadata:\n      labels:\n        app: ${service_name}\n    spec:\n      containers:\n      - name: postgres\n        image: pgvector/pgvector:pg15\n        ports:\n        - containerPort: 5432\n        command: [\"docker-entrypoint.sh\"]\n        args:\n          - postgres\n          - -c\n          - max_connections=${max_connections}\n        env:\n        - name: PGDATA\n          value: /var/lib/postgresql/data/pgdata\n        volumeMounts:\n        - name: postgres-data\n          mountPath: /var/lib/postgresql/data\n      enableServiceLinks: false\n  volumeClaimTemplates:\n  - metadata:\n      name: postgres-data\n    spec:\n      accessModes: [\"ReadWriteOnce\"]\n      resources:\n        requests:\n          storage: \"${storage_gi}Gi\"\n"` |  |
| operator.templates.deployment | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  replicas: ${replicas}\n  selector:\n    matchLabels:\n      app: ${name}\n  template:\n    metadata:\n      labels:\n        app: ${name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: api-server\n        image: ${image}\n        ports:\n        - name: api-server\n          containerPort: 8000\n          protocol: TCP\n        livenessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          periodSeconds: 15\n          timeoutSeconds: 5\n          failureThreshold: 6\n        readinessProbe:\n          httpGet:\n            path: /ok\n            port: 8000\n          periodSeconds: 15\n          timeoutSeconds: 5\n          failureThreshold: 6\n"` |  |
| operator.templates.redis | string | `"apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: ${service_name}\n  namespace: ${namespace}\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      app: ${service_name}\n  template:\n    metadata:\n      labels:\n        app: ${service_name}\n    spec:\n      enableServiceLinks: false\n      containers:\n      - name: redis\n        image: docker.io/redis:7\n        ports:\n        - containerPort: 6379\n          name: redis\n        livenessProbe:\n          exec:\n            command:\n            - redis-cli\n            - ping\n          initialDelaySeconds: 30\n          periodSeconds: 10\n        readinessProbe:\n          tcpSocket:\n            port: 6379\n          initialDelaySeconds: 10\n          periodSeconds: 5\n"` |  |
| operator.templates.service | string | `"apiVersion: v1\nkind: Service\nmetadata:\n  name: ${name}\n  namespace: ${namespace}\nspec:\n  type: ClusterIP\n  selector:\n    app: ${name}\n  ports:\n  - name: api-server\n    protocol: TCP\n    port: 8000\n    targetPort: 8000\n"` |  |
| operator.watchNamespaces | string | `""` |  |

## Platform Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| platformBackend.autoscaling.createHpa | bool | `true` |  |
| platformBackend.autoscaling.enabled | bool | `false` |  |
| platformBackend.autoscaling.maxReplicas | int | `10` |  |
| platformBackend.autoscaling.minReplicas | int | `3` |  |
| platformBackend.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| platformBackend.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| platformBackend.containerPort | int | `1986` |  |
| platformBackend.deployment.affinity | object | `{}` |  |
| platformBackend.deployment.annotations | object | `{}` |  |
| platformBackend.deployment.command[0] | string | `"./entrypoint.sh"` |  |
| platformBackend.deployment.extraContainerConfig | object | `{}` |  |
| platformBackend.deployment.extraEnv | list | `[]` |  |
| platformBackend.deployment.initContainers | list | `[]` |  |
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
| platformBackend.deployment.replicas | int | `3` |  |
| platformBackend.deployment.resources.limits.cpu | string | `"2000m"` |  |
| platformBackend.deployment.resources.limits.memory | string | `"4Gi"` |  |
| platformBackend.deployment.resources.requests.cpu | string | `"1000m"` |  |
| platformBackend.deployment.resources.requests.memory | string | `"2Gi"` |  |
| platformBackend.deployment.securityContext | object | `{}` |  |
| platformBackend.deployment.sidecars | list | `[]` |  |
| platformBackend.deployment.startupProbe.failureThreshold | int | `6` |  |
| platformBackend.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| platformBackend.deployment.startupProbe.httpGet.port | int | `1986` |  |
| platformBackend.deployment.startupProbe.periodSeconds | int | `10` |  |
| platformBackend.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| platformBackend.deployment.terminationGracePeriodSeconds | int | `30` |  |
| platformBackend.deployment.tolerations | list | `[]` |  |
| platformBackend.deployment.topologySpreadConstraints | list | `[]` |  |
| platformBackend.deployment.volumeMounts | list | `[]` |  |
| platformBackend.deployment.volumes | list | `[]` |  |
| platformBackend.existingConfigMapName | string | `""` |  |
| platformBackend.name | string | `"platform-backend"` |  |
| platformBackend.pdb.annotations | object | `{}` |  |
| platformBackend.pdb.enabled | bool | `false` |  |
| platformBackend.pdb.labels | object | `{}` |  |
| platformBackend.pdb.minAvailable | int | `1` |  |
| platformBackend.service.annotations | object | `{}` |  |
| platformBackend.service.labels | object | `{}` |  |
| platformBackend.service.loadBalancerIP | string | `""` |  |
| platformBackend.service.loadBalancerSourceRanges | list | `[]` |  |
| platformBackend.service.port | int | `1986` |  |
| platformBackend.service.type | string | `"ClusterIP"` |  |
| platformBackend.serviceAccount.annotations | object | `{}` |  |
| platformBackend.serviceAccount.automountServiceAccountToken | bool | `true` |  |
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
| playground.containerPort | int | `1988` |  |
| playground.deployment.affinity | object | `{}` |  |
| playground.deployment.annotations | object | `{}` |  |
| playground.deployment.command[0] | string | `"./entrypoint.sh"` |  |
| playground.deployment.extraContainerConfig | object | `{}` |  |
| playground.deployment.extraEnv | list | `[]` |  |
| playground.deployment.initContainers | list | `[]` |  |
| playground.deployment.labels | object | `{}` |  |
| playground.deployment.livenessProbe.failureThreshold | int | `6` |  |
| playground.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.livenessProbe.httpGet.port | int | `1988` |  |
| playground.deployment.livenessProbe.periodSeconds | int | `10` |  |
| playground.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.nodeSelector | object | `{}` |  |
| playground.deployment.podSecurityContext | object | `{}` |  |
| playground.deployment.readinessProbe.failureThreshold | int | `6` |  |
| playground.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.readinessProbe.httpGet.port | int | `1988` |  |
| playground.deployment.readinessProbe.periodSeconds | int | `10` |  |
| playground.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.replicas | int | `1` |  |
| playground.deployment.resources.limits.cpu | string | `"1000m"` |  |
| playground.deployment.resources.limits.memory | string | `"8Gi"` |  |
| playground.deployment.resources.requests.cpu | string | `"500m"` |  |
| playground.deployment.resources.requests.memory | string | `"1Gi"` |  |
| playground.deployment.securityContext | object | `{}` |  |
| playground.deployment.sidecars | list | `[]` |  |
| playground.deployment.startupProbe.failureThreshold | int | `6` |  |
| playground.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| playground.deployment.startupProbe.httpGet.port | int | `1988` |  |
| playground.deployment.startupProbe.periodSeconds | int | `10` |  |
| playground.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| playground.deployment.terminationGracePeriodSeconds | int | `30` |  |
| playground.deployment.tolerations | list | `[]` |  |
| playground.deployment.topologySpreadConstraints | list | `[]` |  |
| playground.deployment.volumeMounts | list | `[]` |  |
| playground.deployment.volumes | list | `[]` |  |
| playground.name | string | `"playground"` |  |
| playground.pdb.annotations | object | `{}` |  |
| playground.pdb.enabled | bool | `false` |  |
| playground.pdb.labels | object | `{}` |  |
| playground.pdb.minAvailable | int | `1` |  |
| playground.service.annotations | object | `{}` |  |
| playground.service.labels | object | `{}` |  |
| playground.service.loadBalancerIP | string | `""` |  |
| playground.service.loadBalancerSourceRanges | list | `[]` |  |
| playground.service.port | int | `1988` |  |
| playground.service.type | string | `"ClusterIP"` |  |
| playground.serviceAccount.annotations | object | `{}` |  |
| playground.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| playground.serviceAccount.create | bool | `true` |  |
| playground.serviceAccount.labels | object | `{}` |  |
| playground.serviceAccount.name | string | `""` |  |

## Postgres

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgres.containerPort | int | `5432` |  |
| postgres.external.connectionUrl | string | `""` |  |
| postgres.external.connectionUrlSecretKey | string | `"connection_url"` |  |
| postgres.external.customTls | bool | `false` |  |
| postgres.external.database | string | `"postgres"` |  |
| postgres.external.enabled | bool | `false` |  |
| postgres.external.existingSecretName | string | `""` |  |
| postgres.external.host | string | `""` |  |
| postgres.external.password | string | `"postgres"` |  |
| postgres.external.port | string | `"5432"` |  |
| postgres.external.schema | string | `"public"` |  |
| postgres.external.user | string | `"postgres"` |  |
| postgres.name | string | `"postgres"` |  |
| postgres.pdb.annotations | object | `{}` |  |
| postgres.pdb.enabled | bool | `false` |  |
| postgres.pdb.labels | object | `{}` |  |
| postgres.pdb.minAvailable | int | `1` |  |
| postgres.service.annotations | object | `{}` |  |
| postgres.service.labels | object | `{}` |  |
| postgres.service.loadBalancerIP | string | `""` |  |
| postgres.service.loadBalancerSourceRanges | list | `[]` |  |
| postgres.service.port | int | `5432` |  |
| postgres.service.type | string | `"ClusterIP"` |  |
| postgres.serviceAccount.annotations | object | `{}` |  |
| postgres.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| postgres.serviceAccount.create | bool | `true` |  |
| postgres.serviceAccount.labels | object | `{}` |  |
| postgres.serviceAccount.name | string | `""` |  |
| postgres.statefulSet.affinity | object | `{}` |  |
| postgres.statefulSet.annotations | object | `{}` |  |
| postgres.statefulSet.command | list | `[]` |  |
| postgres.statefulSet.extraContainerConfig | object | `{}` |  |
| postgres.statefulSet.extraEnv | list | `[]` |  |
| postgres.statefulSet.initContainers | list | `[]` |  |
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| postgres.statefulSet.livenessProbe.exec.command[1] | string | `"-c"` |  |
| postgres.statefulSet.livenessProbe.exec.command[2] | string | `"exec pg_isready -d postgres -U postgres"` |  |
| postgres.statefulSet.livenessProbe.failureThreshold | int | `6` |  |
| postgres.statefulSet.livenessProbe.periodSeconds | int | `10` |  |
| postgres.statefulSet.livenessProbe.timeoutSeconds | int | `1` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.enabled | bool | `true` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
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
| postgres.statefulSet.topologySpreadConstraints | list | `[]` |  |
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
| queue.containerPort | int | `8080` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.command[0] | string | `"./queue_entrypoint.sh"` |  |
| queue.deployment.extraContainerConfig | object | `{}` |  |
| queue.deployment.extraEnv | list | `[]` |  |
| queue.deployment.initContainers | list | `[]` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.livenessProbe.exec.command[0] | string | `"saq"` |  |
| queue.deployment.livenessProbe.exec.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.livenessProbe.exec.command[2] | string | `"--check"` |  |
| queue.deployment.livenessProbe.failureThreshold | int | `6` |  |
| queue.deployment.livenessProbe.periodSeconds | int | `60` |  |
| queue.deployment.livenessProbe.timeoutSeconds | int | `60` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.readinessProbe.failureThreshold | int | `6` |  |
| queue.deployment.readinessProbe.httpGet.path | string | `"/health"` |  |
| queue.deployment.readinessProbe.httpGet.port | int | `8080` |  |
| queue.deployment.readinessProbe.periodSeconds | int | `10` |  |
| queue.deployment.readinessProbe.timeoutSeconds | int | `10` |  |
| queue.deployment.replicas | int | `3` |  |
| queue.deployment.resources.limits.cpu | string | `"2000m"` |  |
| queue.deployment.resources.limits.memory | string | `"4Gi"` |  |
| queue.deployment.resources.requests.cpu | string | `"1000m"` |  |
| queue.deployment.resources.requests.memory | string | `"2Gi"` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.sidecars | list | `[]` |  |
| queue.deployment.startupProbe.failureThreshold | int | `6` |  |
| queue.deployment.startupProbe.httpGet.path | string | `"/health"` |  |
| queue.deployment.startupProbe.httpGet.port | int | `8080` |  |
| queue.deployment.startupProbe.periodSeconds | int | `10` |  |
| queue.deployment.startupProbe.timeoutSeconds | int | `10` |  |
| queue.deployment.terminationGracePeriodSeconds | int | `30` |  |
| queue.deployment.tolerations | list | `[]` |  |
| queue.deployment.topologySpreadConstraints | list | `[]` |  |
| queue.deployment.volumeMounts | list | `[]` |  |
| queue.deployment.volumes | list | `[]` |  |
| queue.name | string | `"queue"` |  |
| queue.pdb.annotations | object | `{}` |  |
| queue.pdb.enabled | bool | `false` |  |
| queue.pdb.labels | object | `{}` |  |
| queue.pdb.minAvailable | int | `1` |  |
| queue.serviceAccount.annotations | object | `{}` |  |
| queue.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| queue.serviceAccount.create | bool | `true` |  |
| queue.serviceAccount.labels | object | `{}` |  |
| queue.serviceAccount.name | string | `""` |  |

## Redis

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.containerPort | int | `6379` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.connectionUrlSecretKey | string | `"connection_url"` |  |
| redis.external.enabled | bool | `false` |  |
| redis.external.existingSecretName | string | `""` |  |
| redis.name | string | `"redis"` |  |
| redis.pdb.annotations | object | `{}` |  |
| redis.pdb.enabled | bool | `false` |  |
| redis.pdb.labels | object | `{}` |  |
| redis.pdb.minAvailable | int | `1` |  |
| redis.service.annotations | object | `{}` |  |
| redis.service.labels | object | `{}` |  |
| redis.service.loadBalancerIP | string | `""` |  |
| redis.service.loadBalancerSourceRanges | list | `[]` |  |
| redis.service.port | int | `6379` |  |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.serviceAccount.annotations | object | `{}` |  |
| redis.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| redis.serviceAccount.create | bool | `true` |  |
| redis.serviceAccount.labels | object | `{}` |  |
| redis.serviceAccount.name | string | `""` |  |
| redis.statefulSet.affinity | object | `{}` |  |
| redis.statefulSet.annotations | object | `{}` |  |
| redis.statefulSet.command | list | `[]` |  |
| redis.statefulSet.extraContainerConfig | object | `{}` |  |
| redis.statefulSet.extraEnv | list | `[]` |  |
| redis.statefulSet.initContainers | list | `[]` |  |
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
| redis.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
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
| redis.statefulSet.topologySpreadConstraints | list | `[]` |  |
| redis.statefulSet.volumeMounts | list | `[]` |  |
| redis.statefulSet.volumes | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith/README.md.gotmpl`
