# langsmith

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.3.4](https://img.shields.io/badge/AppVersion-0.3.4-informational?style=flat-square)

Helm chart to deploy the langsmith application and all services it depends on.

## Migrating from LangSmith 0.4.x to 0.5.0

LangSmith 0.5.0 should be a drop-in replacement for LangSmith 0.4.x You can follow the generic upgrade instructions [here](docs/UPGRADE.md).

There are a few important changes when migrating from 0.4.x to 0.5.0 The majority of these will require no action on your part. However, there are a few things to note:

- Small changes to the commands used to run the queue/clickhouseMigrations. If you were overriding this command you may have to update the override.
- We have now added a new `platform-backend` service that is used internally.
  - This service uses a new `images.platformBackendImage`.
  - You can configure this service under the `platformBackend` section of your `values.yaml` file
- Several feature improvements and bug fixes have been made to the application.

You can view more release notes [here](https://docs.smith.langchain.com/self_hosting/release_notes)

** Note: Using a new api key salt will invalidate all old api keys. **

## Migrating from LangSmith 0.3.0 to 0.4.0

LangSmith 0.4.0 should be a drop-in replacement for LangSmith 0.3.0. You can follow the generic upgrade instructions [here](docs/UPGRADE.md).

There are a few important changes when migrating from 0.3.0 to 0.4.0. The majority of these will require no action on your part. However, there are a few things to note:

- OAuth Flow now relies on using Access Tokens instead of OIDC ID tokens. This shouldn't impact any of your application functionality.
- Queue implementation is now asynchronous. This should improve the performance of the application trace ingestion.
- Clickhouse persistence now uses 50Gi of storage by default. You can adjust this by changing the `clickhouse.statefulSet.persistence.size` value in your `values.yaml` file.
  - You may need to resize your existing storage class or set `clickhouse.statefulSet.persistence.size` to the old default value of `8Gi`.
- Some of our image repositories have been updated. You can see the root repositories in our `values.yaml` file. You may need to update mirrors.
- We now expose an api key salt parameter. This previously defaulted to your LangSmith License Key. To ensure backwards compatibility, you should set this param to your license key to avoid invalidating old api keys.
- Consolidation of hubBackend and backend services. We now use one service to serve both of these endpoints. This should not impact your application.

** Note: Using a new api key salt will invalidate all old api keys. **

## Migrating from LangSmith 0.2.0 to 0.3.0

LangSmith 0.3.0 should be a drop-in replacement for LangSmith 0.2.0. You can follow the generic upgrade instructions [here](docs/UPGRADE.md).

**Note: If you want to preserve old runs from 0.1.x, you will need to first upgrade to 0.2.0, migrate your runs, and then upgrade to 0.3.0.**

## Migrating from LangSmith 0.1.0 to 0.2.0

LangSmith 0.2.0 introduces a new dependency on Clickhouse for run storage. If you wish to retain runs in LangSmith from versions of LangSmith prior to 0.2.0, you will need to complete a migration process.
You can view the upgrade guide [here](docs/UPGRADE-0.2.x.md).
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
4. Api Key Salt
    1. This is a secret key that you can generate. It should be a random string of characters.
    2. You can generate this using the following command:
        ```bash
        openssl rand -base64 32
        ```
5. SSL(optional)
    1. This should be attachable to the load balancer that you will be provisioning.
6. OpenAI API Key(optional).
    1. Used for natural language search feature/evaluators. Can specify OpenAI key in the application as well.
7. Oauth Configuration(optional).
    1. You can configure oauth using the `values.yaml` file. You will need to provide a `client_id` and `client_issuer_url` for your oauth provider.
    2. Note, we do rely on the OIDC Authorization Code with PKCE flow. We currently support almost anything that is OIDC compliant however Google does not support this flow.
8. External Postgres(optional).
    1. You can configure external postgres using the `values.yaml` file. You will need to provide connection parameters for your postgres instance.
    2. If using a schema other than public, ensure that you do not have any other schemas with the pgcrypto extension enabled or you must include that in your search path.
    3. We use the following extensions: `pg_trgm`, `btree_gin`, `btree_gist`, `pgcrypto`, `citext`. You may need to whitelist these extensions in your database.
    4. Note: We do only officially support Postgres versions >= 14.
9. External Redis(optional).
    1. You can configure external redis using the `values.yaml` file. You will need to provide a connection url for your redis instance.
    2. If using TLS, ensure that you use `rediss://` instead of `redis://. E.g "rediss://langsmith-redis:6380/0?password=foo"
    3. We only official support Redis versions >= 6.
10. External ClickHouse(optional).
    1. You can configure external clickhouse using the `values.yaml` file. You will need to provide several connection parameters for your ClickHouse instance.
    2, If using TLS, make sure to set `clickhouse.external.tls` to `true`.
    3. We only officially support ClickHouse versions >= 23. We also only support standalone ClickHouse or ClickHouse Cloud(not clustered or replicated).

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
  apiKeySalt: "foo"
```

Example `EKS` config file with certificates setup using ACM:

```jsx
config:
  langsmithLicenseKey: ""
  apiKeySalt: "foo"

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
  apiKeySalt: "foo"

  oauth:
    enabled: true
    oauthClientId: "0oa805851lEvitA1i697"
    oauthIssuerUrl: "https://trial-5711606.okta.com/oauth2/default"
```
This should be configured as a Single Page Application in your OIDC provider. You will also need to add
<external ip>/oauth-callback as a redirect uri for your application.

More examples can be found in the `examples` directory.

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
    langsmith-backend-7bbc58d7-792nb              1/1     Running     0          40m
    langsmith-backend-ch-migrations-x92wh         0/1     Completed   0          40m
    langsmith-backend-migrations-5ttkp            0/1     Completed   0          95d
    langsmith-backend-pg-migrations-6r8gp         0/1     Completed   0          40m
    langsmith-clickhouse-0                        1/1     Running     0          76m
    langsmith-frontend-b8ff79c4f-5qgn6            1/1     Running     0          40m
    langsmith-platform-backend-549d9d9f68-4cn2v   1/1     Running     0          40m
    langsmith-playground-58cb7ff9c8-64r9t         1/1     Running     0          40m
    langsmith-postgres-0                          1/1     Running     0          68m
    langsmith-queue-6bcd7499-42jzh                1/1     Running     0          40m
    langsmith-queue-6bcd7499-c8zp4                1/1     Running     0          40m
    langsmith-queue-6bcd7499-nsrqw                1/1     Running     0          40m
    langsmith-redis-0                             1/1     Running     0          76m
    ```

### Validate your deployment:

1. Run `kubectl get services`

    Output should look something like:

    ```bash
    NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
    langsmith-backend            ClusterIP      172.20.66.115    <none>          1984/TCP                     46d
    langsmith-clickhouse         ClusterIP      172.20.134.49    <none>          8123/TCP,9000/TCP            46d
    langsmith-frontend           LoadBalancer   172.20.130.135   <external ip>   80:30872/TCP,443:30929/TCP   46d
    langsmith-platform-backend   ClusterIP      172.20.44.253    <none>          1986/TCP                     17d
    langsmith-playground         ClusterIP      172.20.77.65     <none>          3001/TCP                     46d
    langsmith-postgres           ClusterIP      172.20.76.70     <none>          5432/TCP                     75m
    langsmith-redis              ClusterIP      172.20.113.4     <none>          6379/TCP                     39d                                                                  6379/TCP       35h
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
5. How can I use External `Postgres`, `Redis`, or `ClickHouse`?
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
| apiIngress.annotations | object | `{}` |  |
| apiIngress.enabled | bool | `false` |  |
| apiIngress.hostname | string | `""` |  |
| apiIngress.ingressClassName | string | `""` |  |
| apiIngress.labels | object | `{}` |  |
| apiIngress.subdomain | string | `""` |  |
| apiIngress.tls | list | `[]` |  |
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
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"50Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.resources | object | `{}` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.sidecars | list | `[]` |  |
| clickhouse.statefulSet.tolerations | list | `[]` |  |
| clickhouse.statefulSet.volumeMounts | list | `[]` |  |
| clickhouse.statefulSet.volumes | list | `[]` |  |
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"docker.io/langchain/langsmith-backend"` |  |
| images.backendImage.tag | string | `"0.3.4"` |  |
| images.clickhouseImage.pullPolicy | string | `"Always"` |  |
| images.clickhouseImage.repository | string | `"docker.io/clickhouse/clickhouse-server"` |  |
| images.clickhouseImage.tag | string | `"23.9"` |  |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"docker.io/langchain/langsmith-frontend"` |  |
| images.frontendImage.tag | string | `"0.3.4"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.platformBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.platformBackendImage.repository | string | `"docker.io/langchain/langsmith-go-backend"` |  |
| images.platformBackendImage.tag | string | `"0.3.4"` |  |
| images.playgroundImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.playgroundImage.repository | string | `"docker.io/langchain/langsmith-playground"` |  |
| images.playgroundImage.tag | string | `"0.3.4"` |  |
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
| backend.autoscaling.createHpa | bool | `true` |  |
| backend.autoscaling.enabled | bool | `false` |  |
| backend.autoscaling.maxReplicas | int | `5` |  |
| backend.autoscaling.minReplicas | int | `1` |  |
| backend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| backend.clickhouseMigrations.affinity | object | `{}` |  |
| backend.clickhouseMigrations.annotations | object | `{}` |  |
| backend.clickhouseMigrations.command[0] | string | `"/bin/bash"` |  |
| backend.clickhouseMigrations.command[1] | string | `"-c"` |  |
| backend.clickhouseMigrations.command[2] | string | `"sleep 20s; migrate -source file://clickhouse/migrations -database 'clickhouse://$(CLICKHOUSE_HOST):$(CLICKHOUSE_NATIVE_PORT)?username=$(CLICKHOUSE_USER)&password=$(CLICKHOUSE_PASSWORD)&database=$(CLICKHOUSE_DB)&x-multi-statement=true&x-migrations-table-engine=MergeTree' up"` |  |
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
| backend.deployment.nodeSelector | object | `{}` |  |
| backend.deployment.podSecurityContext | object | `{}` |  |
| backend.deployment.replicas | int | `1` |  |
| backend.deployment.resources | object | `{}` |  |
| backend.deployment.securityContext | object | `{}` |  |
| backend.deployment.sidecars | list | `[]` |  |
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
| clickhouse.statefulSet.nodeSelector | object | `{}` |  |
| clickhouse.statefulSet.persistence.size | string | `"50Gi"` |  |
| clickhouse.statefulSet.persistence.storageClassName | string | `""` |  |
| clickhouse.statefulSet.podSecurityContext | object | `{}` |  |
| clickhouse.statefulSet.resources | object | `{}` |  |
| clickhouse.statefulSet.securityContext | object | `{}` |  |
| clickhouse.statefulSet.sidecars | list | `[]` |  |
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
| frontend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| frontend.containerPort | int | `8080` |  |
| frontend.deployment.affinity | object | `{}` |  |
| frontend.deployment.annotations | object | `{}` |  |
| frontend.deployment.command[0] | string | `"/entrypoint.sh"` |  |
| frontend.deployment.extraContainerConfig | object | `{}` |  |
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

## Platform Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| platformBackend.autoscaling.createHpa | bool | `true` |  |
| platformBackend.autoscaling.enabled | bool | `false` |  |
| platformBackend.autoscaling.maxReplicas | int | `5` |  |
| platformBackend.autoscaling.minReplicas | int | `1` |  |
| platformBackend.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| platformBackend.containerPort | int | `1986` |  |
| platformBackend.deployment.affinity | object | `{}` |  |
| platformBackend.deployment.annotations | object | `{}` |  |
| platformBackend.deployment.command[0] | string | `"./smith-go"` |  |
| platformBackend.deployment.extraContainerConfig | object | `{}` |  |
| platformBackend.deployment.extraEnv | list | `[]` |  |
| platformBackend.deployment.labels | object | `{}` |  |
| platformBackend.deployment.nodeSelector | object | `{}` |  |
| platformBackend.deployment.podSecurityContext | object | `{}` |  |
| platformBackend.deployment.replicas | int | `1` |  |
| platformBackend.deployment.resources | object | `{}` |  |
| platformBackend.deployment.securityContext | object | `{}` |  |
| platformBackend.deployment.sidecars | list | `[]` |  |
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
| playground.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| playground.containerPort | int | `3001` |  |
| playground.deployment.affinity | object | `{}` |  |
| playground.deployment.annotations | object | `{}` |  |
| playground.deployment.command[0] | string | `"node"` |  |
| playground.deployment.command[1] | string | `"./scripts/run-playground-docker.mjs"` |  |
| playground.deployment.extraContainerConfig | object | `{}` |  |
| playground.deployment.extraEnv | list | `[]` |  |
| playground.deployment.labels | object | `{}` |  |
| playground.deployment.nodeSelector | object | `{}` |  |
| playground.deployment.podSecurityContext | object | `{}` |  |
| playground.deployment.replicas | int | `1` |  |
| playground.deployment.resources | object | `{}` |  |
| playground.deployment.securityContext | object | `{}` |  |
| playground.deployment.sidecars | list | `[]` |  |
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
| postgres.statefulSet.nodeSelector | object | `{}` |  |
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
| queue.autoscaling.createHpa | bool | `true` |  |
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.maxReplicas | int | `10` |  |
| queue.autoscaling.minReplicas | int | `3` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.command[0] | string | `"saq"` |  |
| queue.deployment.command[1] | string | `"app.workers.queues.single_queue_worker.settings"` |  |
| queue.deployment.command[2] | string | `"--quiet"` |  |
| queue.deployment.extraContainerConfig | object | `{}` |  |
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
| redis.statefulSet.command | list | `[]` |  |
| redis.statefulSet.extraContainerConfig | object | `{}` |  |
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
