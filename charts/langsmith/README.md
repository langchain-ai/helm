# langsmith

![Version: 0.2.9](https://img.shields.io/badge/Version-0.2.9-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the langsmith application and all services it depends on.

## Migrating from LangSmith 0.1.0 to 0.2.0

LangSmith 0.2.0 introduces a new dependency on Clickhouse for run storage. If you wish to retain runs in LangSmith from versions of LangSmith prior to 0.2.0, you will need to complete a migration process.
You can view the upgrade guide [here](https://github.com/langchain-ai/helm/blob/main/charts/langsmith/docs/UPGRADE-0.2.x.md).
If you need assistance, please reach out to support@langchain.dev.

## Deploying LangSmith with Helm

### Prerequisites

Ensure you have the following tools/items ready.

1. A working Kubernetes cluster that you can access via `kubectl`
    1. Recommended: Atleast 4 vCPUs, 16GB Memory available
        1. You may need to tune resource requests/limits for all of our different services based off of organization size/usage
    2. Valid Dynamic PV provisioner or PVs available on your cluster. You can verify this by running:

        ```jsx
        kubectl get storageclass
        ```
2. `Helm`
    1. `brew install helm`
3. LangSmith License Key
    1. You can get this from your Langchain representative. Contact us at support@langchain.dev for more information.
3. SSL(optional)
    1. This should be attachable to a load balancer that
4. OpenAI API Key(optional).
    1. Used for natural language search feature. Can specify OpenAI key in browser as well for the playground feature.
5. Oauth Configuration(optional).
    1. You can configure oauth using the `values.yaml` file. You will need to provide a `client_id` and `client_issuer_url` for your oauth provider.
    2. Note, we do rely on the OIDC Authorization Code with PKCE flow. We currently support almost anything that is OIDC compliant however Google does not support this flow.
6. External Postgres(optional).
    1. You can configure external postgres using the `values.yaml` file. You will need to provide connection parameters for your postgres instance.
    2. If using a schema other than public, ensure that you do not have any other schemas with the pgcrypto extension enabled or you must include that in your search path.
    3. Note: We do only officially support Postgres versions >= 14.
7. External Redis(optional).
    1. You can configure external redis using the `values.yaml` file. You will need to provide a connection url for your redis instance.
    2. Currently, we do not support using Redis with TLS. We will be supporting this shortly.
    3. We only official support Redis versions >= 6.

### Configure your Helm Charts:

1. Create a copy of `values.yaml`
2. Override any values in the file. Refer to the `values.yaml` documentation below to see all configurable values. Some values we recommend tuning:
    1. Resources
    2. SSL(If on EKS or some other cloud provider)
        1. Add an annotation to the `frontend.service` object to tell your cloud provider to provision a load balancer with said certificate attached
    3. OpenAI Api Key
    4. Images
    5. Oauth

Bare minimum config file `langsmith_config.yaml`:

```yaml
config:
  langsmithLicenseKey: ""

```

Example `EKS` config file with certificates setup using ACM:

```jsx
config:
  langsmithLicenseKey: ""

frontend:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "<certificate arn>"
```

Example config file with oauth setup:

```jsx
config:
  langsmithLicenseKey: ""
  oauth:
    enabled: true
    oauthClientId: "0oa805851lEvitA1i697"
    oauthIssuerUrl: "https://trial-5711606.okta.com/oauth2/default"
```
This should be configured as a Single Page Application in your OIDC provider. You will also need to add
<external ip>/oauth-callback as a redirect uri for your application.

Example config file with external postgres and redis:

```jsx
config:
  langsmithLicenseKey: ""
postgres:
  external:
    enabled: true
    host: <host>
    port: 5432
    user: <user>
    password: <password>
    database: <database>
redis:
  external:
    enabled: true
    connectionUrl: "redis://<url>:6379"
```

You can also use existingSecretName to avoid checking in secrets. This secret will need to follow
the same format as the secret in the corresponding `secrets.yaml` file.

### Deploying to Kubernetes:

1. Verify that you can connect to your Kubernetes cluster(note: We highly suggest installing into an empty namespace)
    1. Run `kubectl get pods`

        Output should look something like:

        ```bash
        kubectl get pods                                                                                                                                                                     ⎈ langsmith-eks-2vauP7wf 21:07:46
        No resources found in default namespace.
        ```

2. Ensure you have the Langchain Helm repo added. (skip this step if you are using local charts)

        helm repo add langchain https://langchain-ai.github.io/helm/
        "langchain" has been added to your repositories

3. Run `helm install langsmith langchain/langsmith --values langsmith_config.yaml`
4. Run `kubectl get pods`
    1. Output should now look something like:

    ```bash
    langsmith-backend-6ff46c99c4-wz22d       1/1     Running   0          3h2m
    langsmith-frontend-6bbb94c5df-8xrlr      1/1     Running   0          3h2m
    langsmith-hub-backend-5cc68c888c-vppjj   1/1     Running   0          3h2m
    langsmith-playground-6d95fd8dc6-x2d9b    1/1     Running   0          3h2m
    langsmith-postgres-0                     1/1     Running   0          9h
    langsmith-queue-5898b9d566-tv6q8         1/1     Running   0          3h2m
    langsmith-redis-0                        1/1     Running   0          9h
    ```

### Validate your deployment:

1. Run `kubectl get services`

    Output should look something like:

    ```bash
    NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
    langsmith-backend       ClusterIP      172.20.140.77    <none>                                                                    1984/TCP       35h
    langsmith-frontend      LoadBalancer   172.20.253.251   <external ip>   80:31591/TCP   35h
    langsmith-hub-backend   ClusterIP      172.20.112.234   <none>                                                                    1985/TCP       35h
    langsmith-playground    ClusterIP      172.20.153.194   <none>                                                                    3001/TCP       9h
    langsmith-postgres      ClusterIP      172.20.244.82    <none>                                                                    5432/TCP       35h
    langsmith-redis         ClusterIP      172.20.81.217    <none>                                                                    6379/TCP       35h
    ```

2. Curl the external ip of the `langsmith-frontend` service:

    ```bash
    curl <external ip>/api/tenants
    [{"id":"00000000-0000-0000-0000-000000000000","has_waitlist_access":true,"created_at":"2023-09-13T18:25:10.488407","display_name":"Personal","config":{"is_personal":true,"max_identities":1},"tenant_handle":"default"}]%
    ```

3. Visit the external ip for the `langsmith-frontend` service on your browser

    The LangSmith UI should be visible/operational

    ![./langsmith_ui.png](langsmith_ui.png)

### Using your deployment:

We typically validate deployment using the following quickstart guide:

1. [https://docs.smith.langchain.com/#quick-start](https://docs.smith.langchain.com/#quick-start)
2. For `"LANGCHAIN_ENDPOINT"` you will want to use `<external ip>/api`
3. For `LANGCHAIN_HUB_API_URL` you will want to use `<external ip>/api-hub`
4. For `"LANGCHAIN_API_KEY"` you will want to set an API key you generate. If not using oauth, you can set this to some random value `"foo"`
5. Run through the notebook and validate that all cells complete successfully.

## FAQ:

1. How can we upgrade our application?
    - We plan to release new minor versions of the LangSmith application every 6 weeks. This will include release notes and all changes should be backwards compatible. To upgrade, you will need to follow the upgrade instructions in the Helm README and run a `helm upgrade langsmith --values <values file>`
2. How can we backup our application?
    - Currently, we rely on PVCs/PV to power storage for our application. We strongly encourage setting up `Persistent Volume` backups or moving to a managed service for `Postgres` to support disaster recovery
3. How does load balancing work/ingress work?
    - Currently, our application spins up one load balancer using a k8s service of type `LoadBalancer` for our frontend. If you do not want to setup a load balancer you can simply port-forward the frontend and use that as your external ip for the application.
    - We also have an option for the chart to provision an ingress resource for the application.
4. How can we authenticate to the application?
    - Currently, our self-hosted solution supports oauth as an authn solution.
    - Note, we do offer a no-auth solution but highly recommend setting up oauth before moving into production.
5. How can I use External `Postgres` or `Redis`?
    - You can configure external postgres or redis using the external sections in the `values.yaml` file. You will need to provide the connection url/params for the database/redis instance. Look at the configuration above example for more information.
6. What networking configuration is needed  for the application?
    - Our deployment only needs egress for a few things:
        - Fetching images (If mirroring your images, this may not be needed)
        - Talking to any LLMs
    - Your VPC can set up rules to limit any other access.
7. What resources should we allocate to the application?
    - We recommend at least 4 vCPUs and 16GB of memory for our application.
    - We have some default resources set in our `values.yaml` file. You can override these values to tune resource usage for your organization.
    - If the metrics server is enabled in your cluster, we also recommend enabling autoscaling on all deployments.

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.containerHttpPort | int | `8123` |  |
| clickhouse.containerNativePort | int | `9000` |  |
| clickhouse.external.database | string | `"default"` |  |
| clickhouse.external.enabled | bool | `false` |  |
| clickhouse.external.existingSecretName | string | `""` |  |
| clickhouse.external.host | string | `""` |  |
| clickhouse.external.nativePort | string | `"9000"` |  |
| clickhouse.external.password | string | `"password"` |  |
| clickhouse.external.port | string | `"8123"` |  |
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
| clickhouse.statefulSet.labels | object | `{}` |  |
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"8Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.resources | object | `{}` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"docker.io/langchain/langchainplus-backend"` |  |
| images.backendImage.tag | string | `"c9cf130"` |  |
| images.clickhouseImage.pullPolicy | string | `"Always"` |  |
| images.clickhouseImage.repository | string | `"docker.io/clickhouse/clickhouse-server"` |  |
| images.clickhouseImage.tag | string | `"23.9"` |  |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"docker.io/langchain/langchainplus-frontend-dynamic"` |  |
| images.frontendImage.tag | string | `"c9cf130"` |  |
| images.hubBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.hubBackendImage.repository | string | `"docker.io/langchain/langchainhub-backend"` |  |
| images.hubBackendImage.tag | string | `"c9cf130"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.playgroundImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.playgroundImage.repository | string | `"docker.io/langchain/langchainplus-playground"` |  |
| images.playgroundImage.tag | string | `"c9cf130"` |  |
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
| config.existingSecretName | string | `""` |  |
| config.langsmithLicenseKey | string | `""` |  |
| config.logLevel | string | `"info"` |  |
| config.oauth.enabled | bool | `false` |  |
| config.oauth.oauthClientId | string | `""` |  |
| config.oauth.oauthIssuerUrl | string | `""` |  |
| config.openaiApiKey | string | `""` |  |

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.autoscaling.enabled | bool | `false` |  |
| backend.autoscaling.maxReplicas | int | `5` |  |
| backend.autoscaling.minReplicas | int | `1` |  |
| backend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| backend.containerPort | int | `1984` |  |
| backend.deployment.affinity | object | `{}` |  |
| backend.deployment.annotations | object | `{}` |  |
| backend.deployment.extraEnv | list | `[]` |  |
| backend.deployment.labels | object | `{}` |  |
| backend.deployment.nodeSelector | object | `{}` |  |
| backend.deployment.podSecurityContext | object | `{}` |  |
| backend.deployment.replicas | int | `1` |  |
| backend.deployment.resources | object | `{}` |  |
| backend.deployment.securityContext | object | `{}` |  |
| backend.deployment.sidecars | list | `[]` |  |
| backend.deployment.tolerations | list | `[]` |  |
| backend.deployment.volumeMounts | list | `[]` |  |
| backend.deployment.volumes | list | `[]` |  |
| backend.migrations.affinity | object | `{}` |  |
| backend.migrations.annotations | object | `{}` |  |
| backend.migrations.enabled | bool | `true` |  |
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
| clickhouse.containerHttpPort | int | `8123` |  |
| clickhouse.containerNativePort | int | `9000` |  |
| clickhouse.external.database | string | `"default"` |  |
| clickhouse.external.enabled | bool | `false` |  |
| clickhouse.external.existingSecretName | string | `""` |  |
| clickhouse.external.host | string | `""` |  |
| clickhouse.external.nativePort | string | `"9000"` |  |
| clickhouse.external.password | string | `"password"` |  |
| clickhouse.external.port | string | `"8123"` |  |
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
| clickhouse.statefulSet.labels | object | `{}` |  |
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"8Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.resources | object | `{}` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.autoscaling.enabled | bool | `false` |  |
| frontend.autoscaling.maxReplicas | int | `5` |  |
| frontend.autoscaling.minReplicas | int | `1` |  |
| frontend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| frontend.containerPort | int | `8080` |  |
| frontend.deployment.affinity | object | `{}` |  |
| frontend.deployment.annotations | object | `{}` |  |
| frontend.deployment.extraEnv | list | `[]` |  |
| frontend.deployment.labels | object | `{}` |  |
| frontend.deployment.nodeSelector | object | `{}` |  |
| frontend.deployment.podSecurityContext | object | `{}` |  |
| frontend.deployment.replicas | int | `1` |  |
| frontend.deployment.resources | object | `{}` |  |
| frontend.deployment.securityContext | object | `{}` |  |
| frontend.deployment.sidecars | list | `[]` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.deployment.volumeMounts | list | `[]` |  |
| frontend.deployment.volumes | list | `[]` |  |
| frontend.existingConfigMapName | string | `""` |  |
| frontend.name | string | `"frontend"` |  |
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

## Hub Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hubBackend.autoscaling.enabled | bool | `false` |  |
| hubBackend.autoscaling.maxReplicas | int | `5` |  |
| hubBackend.autoscaling.minReplicas | int | `1` |  |
| hubBackend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| hubBackend.containerPort | int | `1985` |  |
| hubBackend.deployment.affinity | object | `{}` |  |
| hubBackend.deployment.annotations | object | `{}` |  |
| hubBackend.deployment.extraEnv | list | `[]` |  |
| hubBackend.deployment.labels | object | `{}` |  |
| hubBackend.deployment.nodeSelector | object | `{}` |  |
| hubBackend.deployment.podSecurityContext | object | `{}` |  |
| hubBackend.deployment.replicas | int | `1` |  |
| hubBackend.deployment.resources | object | `{}` |  |
| hubBackend.deployment.securityContext | object | `{}` |  |
| hubBackend.deployment.sidecars | list | `[]` |  |
| hubBackend.deployment.tolerations | list | `[]` |  |
| hubBackend.deployment.volumeMounts | list | `[]` |  |
| hubBackend.deployment.volumes | list | `[]` |  |
| hubBackend.name | string | `"hub-backend"` |  |
| hubBackend.service.annotations | object | `{}` |  |
| hubBackend.service.labels | object | `{}` |  |
| hubBackend.service.loadBalancerIP | string | `""` |  |
| hubBackend.service.loadBalancerSourceRanges | list | `[]` |  |
| hubBackend.service.port | int | `1985` |  |
| hubBackend.service.type | string | `"ClusterIP"` |  |
| hubBackend.serviceAccount.annotations | object | `{}` |  |
| hubBackend.serviceAccount.create | bool | `true` |  |
| hubBackend.serviceAccount.labels | object | `{}` |  |
| hubBackend.serviceAccount.name | string | `""` |  |

## Playground

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.autoscaling.enabled | bool | `false` |  |
| frontend.autoscaling.maxReplicas | int | `5` |  |
| frontend.autoscaling.minReplicas | int | `1` |  |
| frontend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| frontend.containerPort | int | `8080` |  |
| frontend.deployment.affinity | object | `{}` |  |
| frontend.deployment.annotations | object | `{}` |  |
| frontend.deployment.extraEnv | list | `[]` |  |
| frontend.deployment.labels | object | `{}` |  |
| frontend.deployment.nodeSelector | object | `{}` |  |
| frontend.deployment.podSecurityContext | object | `{}` |  |
| frontend.deployment.replicas | int | `1` |  |
| frontend.deployment.resources | object | `{}` |  |
| frontend.deployment.securityContext | object | `{}` |  |
| frontend.deployment.sidecars | list | `[]` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.deployment.volumeMounts | list | `[]` |  |
| frontend.deployment.volumes | list | `[]` |  |
| frontend.existingConfigMapName | string | `""` |  |
| frontend.name | string | `"frontend"` |  |
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
| postgres.statefulSet.extraEnv | list | `[]` |  |
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.enabled | bool | `false` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.podSecurityContext | object | `{}` |  |
| postgres.statefulSet.resources | object | `{}` |  |
| postgres.statefulSet.securityContext | object | `{}` |  |
| postgres.statefulSet.sidecars | list | `[]` |  |
| postgres.statefulSet.tolerations | list | `[]` |  |
| postgres.statefulSet.volumeMounts | list | `[]` |  |
| postgres.statefulSet.volumes | list | `[]` |  |

## Queue

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.maxReplicas | int | `10` |  |
| queue.autoscaling.minReplicas | int | `3` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.extraEnv | list | `[]` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.replicas | int | `3` |  |
| queue.deployment.resources | object | `{}` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.sidecars | list | `[]` |  |
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
| redis.statefulSet.extraEnv | list | `[]` |  |
| redis.statefulSet.labels | object | `{}` |  |
| redis.statefulSet.nodeSelector | object | `{}` |  |
| redis.statefulSet.persistence.enabled | bool | `false` |  |
| redis.statefulSet.persistence.size | string | `"8Gi"` |  |
| redis.statefulSet.persistence.storageClassName | string | `""` |  |
| redis.statefulSet.podSecurityContext | object | `{}` |  |
| redis.statefulSet.resources | object | `{}` |  |
| redis.statefulSet.securityContext | object | `{}` |  |
| redis.statefulSet.sidecars | list | `[]` |  |
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
