# langgraph-cloud

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy the LangGraph Cloud application and all services it depends on.

## Deploying LangGraph Cloud with Helm

### Prerequisites

Ensure you have the following tools/items ready.

1. A working Kubernetes cluster that you can access via `kubectl`
    1. Recommended: Atleast 1 vCPUs, 4GB Memory available
        1. You may need to tune resource requests/limits for all of our different services based off of organization size/usage
    1. Valid Dynamic PV provisioner or PVs available on your cluster. You can verify this by running:

        ```jsx
        kubectl get storageclass
        ```
1. `Helm`
    1. `brew install helm`
1. LangGraph Cloud License Key
    1. You can get this from your Langchain representative. Contact us at sales@langchain.dev for more information.
1. A LangGraph Cloud API image
    1. You can use the [langgraph-cli](https://langchain-ai.github.io/langgraph/cloud/reference/cli/) to build your own image.
1. SSL(optional)
    1. This should be attachable to a load balancer that the chart will provision
1. External Postgres(optional).
    1. You can configure external Postgres using the `values.yaml` file. You will need to provide a connection url for your postgres.
    2. We only official support Postgres versions >= 14.

### Configure your Helm Charts:

1. Create a new of `langgraph_cloud_config.yaml` file to contain your configuration.
1. Override any values in the file. Refer to the `values.yaml` documentation below to see all configurable values. Some values we recommend tuning:
    1. Resources
    1. SSL
        1. Add an annotation to the `apiServer.service` object to tell your cloud provider to provision a load balancer with said certificate attached.
        2. This will vary based on your cloud provider. Refer to their documentation for more information.
    1. License Key
    1. A LangGraph Cloud API image. You can use the [langgraph-cli](https://langchain-ai.github.io/langgraph/cloud/reference/cli/) to build your own image.

Bare minimum config file `langgraph_cloud_config.yaml`:

```yaml
images:
  # Make sure to replace this with your own LangGraph Cloud API image built with the cli.
  apiServerImage:
    pullPolicy: IfNotPresent
    repository: <your repository>
    tag: <image tag>

config:
  langGraphCloudLicenseKey: ""
```

Example `EKS` config file with certificates setup using ACM:

```jsx
images:
  # Make sure to replace this with your own LangGraph Cloud API image built with the cli.
  apiServerImage:
    pullPolicy: IfNotPresent
    repository: <your repository>
    tag: <image tag>

config:
  langGraphCloudLicenseKey: ""

apiServer:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "<certificate arn>"
```

Example config file with external postgres:

```jsx
images:
  # Make sure to replace this with your own LangGraph Cloud API image built with the cli.
  apiServerImage:
    pullPolicy: IfNotPresent
    repository: <your repository>
    tag: <image tag>

config:
  langGraphCloudLicenseKey: ""

postgres:
  external:
    enabled: true
    connectionUrl: "postgres://postgres:postgres@postgres-host.com:5432/postgres?sslmode=disable"
```

You can also use existingSecretName to avoid checking in secrets. This secret will need to follow
the same format as the secret in the corresponding `secrets.yaml` file.

### Deploying to Kubernetes:

1. Verify that you can connect to your Kubernetes cluster(note: We highly suggest installing into an empty namespace)
    1. Run `kubectl get pods`

        Output should look something like:

        ```bash
        kubectl get pods
        No resources found in default namespace.
        ```

2. Ensure you have the Langchain Helm repo added. (skip this step if you are using local charts)

        helm repo add langchain https://langchain-ai.github.io/helm/
        "langchain" has been added to your repositories

3. Run `helm install langgraph-cloud langchain/langgraph-cloud --values langgraph_cloud_config.yaml`
4. Run `kubectl get pods`
    1. Output should now look something like:

    ```bash
    NAME                                 READY   STATUS    RESTARTS      AGE
    langgraph-cloud-api-server-666d79569d-k4wgk   1/1     Running   2 (26s ago)   31s
    langgraph-cloud-postgres-0                    1/1     Running   0             31s
    ```

### Validate your deployment:

1. Run `kubectl get services`

    Output should look something like:

    ```bash
    NAME                         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                     AGE
    langgraph-cloud-api-server   LoadBalancer   172.20.59.8      <ip>         80:30176/TCP,443:31693/TCP   67s
    langgraph-cloud-postgres     ClusterIP      172.20.91.2      <none>       6379/TCP                     7m22s
    ```

3. Visit the `ip/docs` for the `langgraph-cloud-api-server` service on your browser

    The LangGraph Cloud docs UI should be visible/operational

    ![./langgraph_cloud_ui.png](langgraph_cloud_ui.png)

## FAQ:

1. How can we upgrade our application?
    - To upgrade, you will need to follow the upgrade instructions in the Helm README and run a `helm upgrade langgraph-cloud --values <values file>`
2. How can we backup our application?
    - Currently, we rely on PVCs/PV to power storage for our application. We strongly encourage setting up `Persistent Volume` backups or moving to a managed service for `Postgres` to support disaster recovery
3. How does load balancing work/ingress work?
    - Currently, our application spins up one load balancer using a k8s service of type `LoadBalancer` for our frontend. If you do not want to setup a load balancer you can simply port-forward the frontend and use that as your external ip for the application.
    - We also have an option for the chart to provision an ingress resource for the application.
4. How can we authenticate to the application?
    - You can use LangSmith authentication to authenticate to the application. You can find more information on how to setup LangSmith in the LangSmith documentation.
5. How can I use External `Postgres`?
    - You can configure external postgres using the external sections in the `values.yaml` file. You will need to provide the connection url/params for the postgres instance. Look at the configuration above example for more information.
6. What networking configuration is needed  for the application?
    - Our deployment only needs egress for a few things:
        - Fetching images (If mirroring your images, this may not be needed)
        - Talking to any LLMs
    - Your VPC can set up rules to limit any other access.
7. What resources should we allocate to the application?
    - We recommend at least 1 vCPUs and 4GB of memory for our application.
    - We have some default resources set in our `values.yaml` file. You can override these values to tune resource usage for your organization.
    - If the metrics server is enabled in your cluster, we also recommend enabling autoscaling on all deployments.

## General parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations that will be applied to all resources created by the chart |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langgraph-cloud.fullname"` |
| images.apiServerImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.apiServerImage.repository | string | `"docker.io/langchain/langgraph-api"` |  |
| images.apiServerImage.tag | string | `"3.11"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.postgresImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.postgresImage.repository | string | `"docker.io/postgres"` |  |
| images.postgresImage.tag | string | `"16"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraph-cloud` for the chart |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.auth.enabled | bool | `false` |  |
| config.auth.langSmithAuthEndpoint | string | `""` |  |
| config.auth.langSmithTenantId | string | `""` |  |
| config.existingSecretName | string | `""` |  |
| config.langGraphCloudLicenseKey | string | `""` |  |

## Api Server

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiServer.autoscaling.enabled | bool | `false` |  |
| apiServer.autoscaling.maxReplicas | int | `5` |  |
| apiServer.autoscaling.minReplicas | int | `1` |  |
| apiServer.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| apiServer.containerPort | int | `8000` |  |
| apiServer.deployment.affinity | object | `{}` |  |
| apiServer.deployment.annotations | object | `{}` |  |
| apiServer.deployment.extraEnv | list | `[]` |  |
| apiServer.deployment.labels | object | `{}` |  |
| apiServer.deployment.nodeSelector | object | `{}` |  |
| apiServer.deployment.podSecurityContext | object | `{}` |  |
| apiServer.deployment.replicaCount | int | `1` |  |
| apiServer.deployment.resources | object | `{}` |  |
| apiServer.deployment.securityContext | object | `{}` |  |
| apiServer.deployment.sidecars | list | `[]` |  |
| apiServer.deployment.tolerations | list | `[]` |  |
| apiServer.deployment.volumeMounts | list | `[]` |  |
| apiServer.deployment.volumes | list | `[]` |  |
| apiServer.migrations.affinity | object | `{}` |  |
| apiServer.migrations.annotations | object | `{}` |  |
| apiServer.migrations.enabled | bool | `true` |  |
| apiServer.migrations.extraEnv | list | `[]` |  |
| apiServer.migrations.labels | object | `{}` |  |
| apiServer.migrations.nodeSelector | object | `{}` |  |
| apiServer.migrations.podSecurityContext | object | `{}` |  |
| apiServer.migrations.replicaCount | int | `1` |  |
| apiServer.migrations.resources | object | `{}` |  |
| apiServer.migrations.securityContext | object | `{}` |  |
| apiServer.migrations.sidecars | list | `[]` |  |
| apiServer.migrations.tolerations | list | `[]` |  |
| apiServer.migrations.volumeMounts | list | `[]` |  |
| apiServer.migrations.volumes | list | `[]` |  |
| apiServer.name | string | `"api-server"` |  |
| apiServer.service.annotations | object | `{}` |  |
| apiServer.service.httpPort | int | `80` |  |
| apiServer.service.httpsPort | int | `443` |  |
| apiServer.service.labels | object | `{}` |  |
| apiServer.service.loadBalancerIP | string | `""` |  |
| apiServer.service.loadBalancerSourceRanges | list | `[]` |  |
| apiServer.service.type | string | `"LoadBalancer"` |  |
| apiServer.serviceAccount.annotations | object | `{}` |  |
| apiServer.serviceAccount.create | bool | `true` |  |
| apiServer.serviceAccount.labels | object | `{}` |  |
| apiServer.serviceAccount.name | string | `""` |  |

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

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
