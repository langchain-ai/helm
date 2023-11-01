# langsmith

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the langsmith application and all services it depends on.

## Deploying Langsmith with Helm

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
3. Langsmith License Key
    1. You can get this from your Langchain representative. Contact us at support@langchain.dev for more information.
3. SSL(optional)
    1. This should be attachable to a load balancer that
4. OpenAI API Key(optional).
    1. Used for natural language search feature. Can specify OpenAI key in browser as well for the playground feature.
5. Oauth Configuration(optional).
    1. You can configure oauth using the `values.yaml` file. You will need to provide a `client_id` and `client_issuer_url` for your oauth provider. We currently support anything that is OIDC compliant.
6. External Postgres(optional).
    1. You can configure external postgres using the `values.yaml` file. You will need to provide connection parameters for your postgres instance.
    2. Note: We do not support a schema other than public at this time.
7. External Redis(optional).
    1. You can configure external redis using the `values.yaml` file. You will need to provide a connection url for your redis instance.

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

3. Run `helm install langchain/langsmith . --values langsmith_config.yaml`
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

    The Langsmith UI should be visible/operational

    ![./langsmith_ui.png](langsmith_ui.png)

### Using your deployment:

We typically validate deployment using the following Jupyter notebook:

1. [https://github.com/langchain-ai/langchain/blob/master/docs/docs/guides/langsmith/walkthrough.ipynb](https://github.com/langchain-ai/langchain/blob/master/docs/docs/guides/langsmith/walkthrough.ipynb)
2. For `"LANGCHAIN_ENDPOINT"` you will want to use `<external ip>/api`
3. For `LANGCHAIN_HUB_API_URL` you will want to use `<external ip>/api-hub`
4. For `"LANGCHAIN_API_KEY"` you will want to set an API key you generate. If not using oauth, you can set this to some random value `"foo"`
5. Run through the notebook and validate that all cells complete successfully.

## FAQ:

1. How can we upgrade our application.
    - We plan to release new minor versions of the Langsmith application every 6 weeks. This will include release notes and all changes should be backwards compatible. To upgrade, you will need to follow the upgrade instructions in the Helm README and run a `helm upgrade langsmith --values <values file>`
2. Backups
    - Currently, we rely on PVCs/PV to power storage for our application. We strongly encourage setting up `Persistent Volume` backups or moving to a managed service for `Postgres` to support disaster recovery
3. Load Balancers
    - Currently, our application spins up one load balancer using a k8s service of type `LoadBalancer` for our frontend. If you do not want to setup a load balancer you can simply port-forward the frontend and use that as your external ip for the application.
4. Authentication
    - Currently, our self-hosted solution supports oauth as an authn solution.
    - Note, we do offer a no-auth solution but highly recommend setting up oauth before moving into production.
5. Using External `Postgres` or `Redis`
    - You can configure external postgres or redis using the external sections in the `values.yaml` file. You will need to provide the connection url/params for the database/redis instance. Look at the configuration above example for more information.
6. Networking
    - Our deployment only needs egress for a few things:
        - Fetching images (If mirroring your images, this may not be needed)
        - Talking to any LLMs
    - Your VPC can set up rules to limit any other access.
7. Resource Usage
    - We recommend at least 4 vCPUs and 16GB of memory for our application.
    - We have some default resources set in our `values.yaml` file. You can override these values to tune resource usage for your organization.
    - If the metrics server is enabled in your cluster, we also recommend enabling autoscaling on all deployments.

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| images.backendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.backendImage.repository | string | `"docker.io/langchain/langchainplus-backend"` |  |
| images.backendImage.tag | string | `"99d8f59"` |  |
| images.frontendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.frontendImage.repository | string | `"docker.io/langchain/langchainplus-frontend-dynamic"` |  |
| images.frontendImage.tag | string | `"99d8f59"` |  |
| images.hubBackendImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.hubBackendImage.repository | string | `"docker.io/langchain/langchainhub-backend"` |  |
| images.hubBackendImage.tag | string | `"99d8f59"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.playgroundImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.playgroundImage.repository | string | `"docker.io/langchain/langchainplus-playground"` |  |
| images.playgroundImage.tag | string | `"99d8f59"` |  |
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
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langsmith` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.existingSecretName | string | `""` |  |
| config.langsmithLicenseKey | string | `""` |  |
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
| backend.deployment.labels | object | `{}` |  |
| backend.deployment.nodeSelector | object | `{}` |  |
| backend.deployment.podSecurityContext | object | `{}` |  |
| backend.deployment.replicaCount | int | `1` |  |
| backend.deployment.resources | object | `{}` |  |
| backend.deployment.securityContext | object | `{}` |  |
| backend.deployment.tolerations | list | `[]` |  |
| backend.migrations.affinity | object | `{}` |  |
| backend.migrations.annotations | object | `{}` |  |
| backend.migrations.labels | object | `{}` |  |
| backend.migrations.nodeSelector | object | `{}` |  |
| backend.migrations.podSecurityContext | object | `{}` |  |
| backend.migrations.replicaCount | int | `1` |  |
| backend.migrations.resources | object | `{}` |  |
| backend.migrations.securityContext | object | `{}` |  |
| backend.migrations.tolerations | list | `[]` |  |
| backend.name | string | `"backend"` |  |
| backend.service.annotations | object | `{}` |  |
| backend.service.labels | object | `{}` |  |
| backend.service.port | int | `1984` |  |
| backend.service.type | string | `"ClusterIP"` |  |

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
| frontend.deployment.labels | object | `{}` |  |
| frontend.deployment.nodeSelector | object | `{}` |  |
| frontend.deployment.podSecurityContext | object | `{}` |  |
| frontend.deployment.replicaCount | int | `1` |  |
| frontend.deployment.resources | object | `{}` |  |
| frontend.deployment.securityContext | object | `{}` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.name | string | `"frontend"` |  |
| frontend.service.annotations | object | `{}` |  |
| frontend.service.httpPort | int | `80` |  |
| frontend.service.httpsPort | int | `443` |  |
| frontend.service.labels | object | `{}` |  |
| frontend.service.type | string | `"LoadBalancer"` |  |

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
| hubBackend.deployment.labels | object | `{}` |  |
| hubBackend.deployment.nodeSelector | object | `{}` |  |
| hubBackend.deployment.podSecurityContext | object | `{}` |  |
| hubBackend.deployment.replicaCount | int | `1` |  |
| hubBackend.deployment.resources | object | `{}` |  |
| hubBackend.deployment.securityContext | object | `{}` |  |
| hubBackend.deployment.tolerations | list | `[]` |  |
| hubBackend.name | string | `"hub-backend"` |  |
| hubBackend.service.annotations | object | `{}` |  |
| hubBackend.service.labels | object | `{}` |  |
| hubBackend.service.port | int | `1985` |  |
| hubBackend.service.type | string | `"ClusterIP"` |  |

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
| frontend.deployment.labels | object | `{}` |  |
| frontend.deployment.nodeSelector | object | `{}` |  |
| frontend.deployment.podSecurityContext | object | `{}` |  |
| frontend.deployment.replicaCount | int | `1` |  |
| frontend.deployment.resources | object | `{}` |  |
| frontend.deployment.securityContext | object | `{}` |  |
| frontend.deployment.tolerations | list | `[]` |  |
| frontend.name | string | `"frontend"` |  |
| frontend.service.annotations | object | `{}` |  |
| frontend.service.httpPort | int | `80` |  |
| frontend.service.httpsPort | int | `443` |  |
| frontend.service.labels | object | `{}` |  |
| frontend.service.type | string | `"LoadBalancer"` |  |

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
| postgres.external.user | string | `"postgres"` |  |
| postgres.name | string | `"postgres"` |  |
| postgres.service.annotations | object | `{}` |  |
| postgres.service.labels | object | `{}` |  |
| postgres.service.port | int | `5432` |  |
| postgres.service.type | string | `"ClusterIP"` |  |
| postgres.statefulSet.affinity | object | `{}` |  |
| postgres.statefulSet.annotations | object | `{}` |  |
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.enabled | bool | `false` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.podSecurityContext | object | `{}` |  |
| postgres.statefulSet.resources | object | `{}` |  |
| postgres.statefulSet.securityContext | object | `{}` |  |
| postgres.statefulSet.tolerations | list | `[]` |  |

## Queue

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.maxReplicas | int | `5` |  |
| queue.autoscaling.minReplicas | int | `1` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.replicaCount | int | `1` |  |
| queue.deployment.resources | object | `{}` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.tolerations | list | `[]` |  |
| queue.name | string | `"queue"` |  |

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
| redis.service.port | int | `6379` |  |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.statefulSet.affinity | object | `{}` |  |
| redis.statefulSet.annotations | object | `{}` |  |
| redis.statefulSet.labels | object | `{}` |  |
| redis.statefulSet.nodeSelector | object | `{}` |  |
| redis.statefulSet.persistence.enabled | bool | `false` |  |
| redis.statefulSet.persistence.size | string | `"8Gi"` |  |
| redis.statefulSet.persistence.storageClassName | string | `""` |  |
| redis.statefulSet.podSecurityContext | object | `{}` |  |
| redis.statefulSet.resources | object | `{}` |  |
| redis.statefulSet.securityContext | object | `{}` |  |
| redis.statefulSet.tolerations | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langsmith/README.md.gotmpl`
