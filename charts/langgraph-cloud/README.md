# langgraph-cloud

![Version: 0.1.19](https://img.shields.io/badge/Version-0.1.19-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.2.0](https://img.shields.io/badge/AppVersion-0.2.0-informational?style=flat-square)

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
    1. You can get this from your LangChain representative. Contact us at sales@langchain.dev for more information.
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

If your application reads from environment variables, specify `apiServer.deployment.extraEnv`:

```yaml
images:
  # Make sure to replace this with your own LangGraph Cloud API image built with the cli.
  apiServerImage:
    pullPolicy: IfNotPresent
    repository: <your repository>
    tag: <image tag>

config:
  langGraphCloudLicenseKey: ""

apiServer:
  deployment:
    extraEnv:
      - name: ENV_VAR_1
        value: "foo"
      - name: ENV_VAR_2
        value: "bar"
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
the same format as the secret in the corresponding `secrets.yaml` file. Note: API keys such as `OPENAI_API_KEY` should not be specified as environment variables. These values should be stored as secrets (e.g. Kubernetes secrets).

### Deploying to Kubernetes:

1. Verify that you can connect to your Kubernetes cluster(note: We highly suggest installing into an empty namespace)
    1. Run `kubectl get pods`

        Output should look something like:

        ```bash
        kubectl get pods
        No resources found in default namespace.
        ```

2. Ensure you have the LangChain Helm repo added. (skip this step if you are using local charts)

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
| commonVolumeMounts | list | `[]` | Common volume mounts added to all deployments/statefulsets. |
| commonVolumes | list | `[]` | Common volumes added to all deployments/statefulsets. |
| fullnameOverride | string | `""` | String to fully override `"langgraph-cloud.fullname"` |
| images.apiServerImage.pullPolicy | string | `"Always"` |  |
| images.apiServerImage.repository | string | `"docker.io/langchain/langgraph-api"` |  |
| images.apiServerImage.tag | string | `"3.11"` |  |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.postgresImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.postgresImage.repository | string | `"pgvector/pgvector"` |  |
| images.postgresImage.tag | string | `"pg16"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"6"` |  |
| images.registry | string | `""` | If supplied, all children <image_name>.repository values will be prepended with this registry name + `/` |
| images.studioImage.pullPolicy | string | `"Always"` |  |
| images.studioImage.repository | string | `"docker.io/langchain/langgraph-debugger"` |  |
| images.studioImage.tag | string | `"0.12.40"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hostname | string | `""` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.labels | object | `{}` |  |
| ingress.studioHostname | string | `""` |  |
| ingress.tls | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langgraph-cloud` for the chart |
| namespace | string | `""` | Namespace to install the chart into. If not set, will use the namespace of the current context. |
| queue.autoscaling.enabled | bool | `false` |  |
| queue.autoscaling.keda.cooldownPeriod | int | `300` |  |
| queue.autoscaling.keda.enabled | bool | `false` |  |
| queue.autoscaling.keda.pollingInterval | int | `30` |  |
| queue.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| queue.autoscaling.maxReplicas | int | `5` |  |
| queue.autoscaling.minReplicas | int | `1` |  |
| queue.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| queue.containerPort | int | `8000` |  |
| queue.deployment.affinity | object | `{}` |  |
| queue.deployment.annotations | object | `{}` |  |
| queue.deployment.envFrom | list | `[]` |  |
| queue.deployment.extraEnv | list | `[]` |  |
| queue.deployment.labels | object | `{}` |  |
| queue.deployment.livenessProbe.failureThreshold | int | `6` |  |
| queue.deployment.livenessProbe.httpGet.path | string | `"/ok"` |  |
| queue.deployment.livenessProbe.httpGet.port | int | `8000` |  |
| queue.deployment.livenessProbe.periodSeconds | int | `10` |  |
| queue.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| queue.deployment.nodeSelector | object | `{}` |  |
| queue.deployment.podSecurityContext | object | `{}` |  |
| queue.deployment.priorityClassName | string | `""` |  |
| queue.deployment.readinessProbe.failureThreshold | int | `6` |  |
| queue.deployment.readinessProbe.httpGet.path | string | `"/ok"` |  |
| queue.deployment.readinessProbe.httpGet.port | int | `8000` |  |
| queue.deployment.readinessProbe.periodSeconds | int | `10` |  |
| queue.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| queue.deployment.replicaCount | int | `1` |  |
| queue.deployment.resources.limits.cpu | string | `"2000m"` |  |
| queue.deployment.resources.limits.memory | string | `"4Gi"` |  |
| queue.deployment.resources.requests.cpu | string | `"1000m"` |  |
| queue.deployment.resources.requests.memory | string | `"2Gi"` |  |
| queue.deployment.securityContext | object | `{}` |  |
| queue.deployment.sidecars | list | `[]` |  |
| queue.deployment.startupProbe.failureThreshold | int | `6` |  |
| queue.deployment.startupProbe.httpGet.path | string | `"/ok"` |  |
| queue.deployment.startupProbe.httpGet.port | int | `8000` |  |
| queue.deployment.startupProbe.periodSeconds | int | `10` |  |
| queue.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| queue.deployment.tolerations | list | `[]` |  |
| queue.deployment.volumeMounts | list | `[]` |  |
| queue.deployment.volumes | list | `[]` |  |
| queue.enabled | bool | `false` |  |
| queue.name | string | `"queue"` |  |
| queue.pdb.enabled | bool | `false` |  |
| queue.pdb.minAvailable | int | `1` |  |
| queue.serviceAccount.annotations | object | `{}` |  |
| queue.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| queue.serviceAccount.create | bool | `true` |  |
| queue.serviceAccount.labels | object | `{}` |  |
| queue.serviceAccount.name | string | `""` |  |
| redis.containerPort | int | `6379` |  |
| redis.deployment.affinity | object | `{}` |  |
| redis.deployment.annotations | object | `{}` |  |
| redis.deployment.command | list | `[]` |  |
| redis.deployment.extraContainerConfig | object | `{}` |  |
| redis.deployment.extraEnv | list | `[]` |  |
| redis.deployment.labels | object | `{}` |  |
| redis.deployment.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.livenessProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.livenessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.livenessProbe.failureThreshold | int | `6` |  |
| redis.deployment.livenessProbe.periodSeconds | int | `10` |  |
| redis.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.nodeSelector | object | `{}` |  |
| redis.deployment.podSecurityContext | object | `{}` |  |
| redis.deployment.priorityClassName | string | `""` |  |
| redis.deployment.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.readinessProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.readinessProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.readinessProbe.failureThreshold | int | `6` |  |
| redis.deployment.readinessProbe.periodSeconds | int | `10` |  |
| redis.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.resources.limits.cpu | string | `"2000m"` |  |
| redis.deployment.resources.limits.memory | string | `"4Gi"` |  |
| redis.deployment.resources.requests.cpu | string | `"1000m"` |  |
| redis.deployment.resources.requests.memory | string | `"2Gi"` |  |
| redis.deployment.securityContext | object | `{}` |  |
| redis.deployment.sidecars | list | `[]` |  |
| redis.deployment.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| redis.deployment.startupProbe.exec.command[1] | string | `"-c"` |  |
| redis.deployment.startupProbe.exec.command[2] | string | `"exec redis-cli ping"` |  |
| redis.deployment.startupProbe.failureThreshold | int | `6` |  |
| redis.deployment.startupProbe.periodSeconds | int | `10` |  |
| redis.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| redis.deployment.tolerations | list | `[]` |  |
| redis.deployment.volumeMounts | list | `[]` |  |
| redis.deployment.volumes | list | `[]` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.enabled | bool | `false` |  |
| redis.external.existingSecretName | string | `""` |  |
| redis.name | string | `"redis"` |  |
| redis.pdb.enabled | bool | `false` |  |
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
| studio.autoscaling.enabled | bool | `false` |  |
| studio.autoscaling.keda.cooldownPeriod | int | `300` |  |
| studio.autoscaling.keda.enabled | bool | `false` |  |
| studio.autoscaling.keda.pollingInterval | int | `30` |  |
| studio.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| studio.autoscaling.maxReplicas | int | `5` |  |
| studio.autoscaling.minReplicas | int | `1` |  |
| studio.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| studio.containerPort | int | `3968` |  |
| studio.deployment.affinity | object | `{}` |  |
| studio.deployment.annotations | object | `{}` |  |
| studio.deployment.extraEnv | list | `[]` |  |
| studio.deployment.labels | object | `{}` |  |
| studio.deployment.livenessProbe.failureThreshold | int | `6` |  |
| studio.deployment.livenessProbe.httpGet.path | string | `"/health"` |  |
| studio.deployment.livenessProbe.httpGet.port | int | `3968` |  |
| studio.deployment.livenessProbe.periodSeconds | int | `10` |  |
| studio.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| studio.deployment.nodeSelector | object | `{}` |  |
| studio.deployment.podSecurityContext | object | `{}` |  |
| studio.deployment.priorityClassName | string | `""` |  |
| studio.deployment.readinessProbe.failureThreshold | int | `3` |  |
| studio.deployment.readinessProbe.httpGet.path | string | `"/health"` |  |
| studio.deployment.readinessProbe.httpGet.port | int | `3968` |  |
| studio.deployment.readinessProbe.periodSeconds | int | `10` |  |
| studio.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| studio.deployment.replicaCount | int | `1` |  |
| studio.deployment.resources.limits.cpu | string | `"1000m"` |  |
| studio.deployment.resources.limits.memory | string | `"2Gi"` |  |
| studio.deployment.resources.requests.cpu | string | `"500m"` |  |
| studio.deployment.resources.requests.memory | string | `"1Gi"` |  |
| studio.deployment.securityContext | object | `{}` |  |
| studio.deployment.sidecars | list | `[]` |  |
| studio.deployment.startupProbe.failureThreshold | int | `6` |  |
| studio.deployment.startupProbe.httpGet.path | string | `"/health"` |  |
| studio.deployment.startupProbe.httpGet.port | int | `3968` |  |
| studio.deployment.startupProbe.periodSeconds | int | `10` |  |
| studio.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| studio.deployment.tolerations | list | `[]` |  |
| studio.deployment.volumeMounts | list | `[]` |  |
| studio.deployment.volumes | list | `[]` |  |
| studio.enabled | bool | `true` |  |
| studio.localGraphUrl | string | `""` |  |
| studio.name | string | `"studio"` |  |
| studio.pdb.enabled | bool | `false` |  |
| studio.pdb.minAvailable | int | `1` |  |
| studio.service.annotations | object | `{}` |  |
| studio.service.httpPort | int | `80` |  |
| studio.service.httpsPort | int | `443` |  |
| studio.service.labels | object | `{}` |  |
| studio.service.loadBalancerIP | string | `""` |  |
| studio.service.loadBalancerSourceRanges | list | `[]` |  |
| studio.service.type | string | `"LoadBalancer"` |  |
| studio.serviceAccount.annotations | object | `{}` |  |
| studio.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| studio.serviceAccount.create | bool | `true` |  |
| studio.serviceAccount.labels | object | `{}` |  |
| studio.serviceAccount.name | string | `""` |  |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.auth.enabled | bool | `false` |  |
| config.auth.langSmithAuthEndpoint | string | `""` |  |
| config.auth.langSmithTenantId | string | `""` |  |
| config.existingSecretName | string | `""` |  |
| config.langGraphCloudLicenseKey | string | `""` |  |
| config.numberOfJobsPerWorker | int | `10` |  |

## Api Server

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiServer.autoscaling.enabled | bool | `false` |  |
| apiServer.autoscaling.keda.cooldownPeriod | int | `300` |  |
| apiServer.autoscaling.keda.enabled | bool | `false` |  |
| apiServer.autoscaling.keda.pollingInterval | int | `30` |  |
| apiServer.autoscaling.keda.scaleDownStabilizationWindowSeconds | int | `300` |  |
| apiServer.autoscaling.maxReplicas | int | `5` |  |
| apiServer.autoscaling.minReplicas | int | `1` |  |
| apiServer.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| apiServer.containerPort | int | `8000` |  |
| apiServer.deployment.affinity | object | `{}` |  |
| apiServer.deployment.annotations | object | `{}` |  |
| apiServer.deployment.envFrom | list | `[]` |  |
| apiServer.deployment.extraEnv | list | `[]` |  |
| apiServer.deployment.initContainers | list | `[]` |  |
| apiServer.deployment.labels | object | `{}` |  |
| apiServer.deployment.livenessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| apiServer.deployment.livenessProbe.exec.command[1] | string | `"-c"` |  |
| apiServer.deployment.livenessProbe.exec.command[2] | string | `"exec python /api/healthcheck.py"` |  |
| apiServer.deployment.livenessProbe.failureThreshold | int | `6` |  |
| apiServer.deployment.livenessProbe.periodSeconds | int | `10` |  |
| apiServer.deployment.livenessProbe.timeoutSeconds | int | `1` |  |
| apiServer.deployment.nodeSelector | object | `{}` |  |
| apiServer.deployment.podSecurityContext | object | `{}` |  |
| apiServer.deployment.priorityClassName | string | `""` |  |
| apiServer.deployment.readinessProbe.exec.command[0] | string | `"/bin/sh"` |  |
| apiServer.deployment.readinessProbe.exec.command[1] | string | `"-c"` |  |
| apiServer.deployment.readinessProbe.exec.command[2] | string | `"exec python /api/healthcheck.py"` |  |
| apiServer.deployment.readinessProbe.failureThreshold | int | `6` |  |
| apiServer.deployment.readinessProbe.periodSeconds | int | `10` |  |
| apiServer.deployment.readinessProbe.timeoutSeconds | int | `1` |  |
| apiServer.deployment.replicaCount | int | `1` |  |
| apiServer.deployment.resources.limits.cpu | string | `"2000m"` |  |
| apiServer.deployment.resources.limits.memory | string | `"4Gi"` |  |
| apiServer.deployment.resources.requests.cpu | string | `"1000m"` |  |
| apiServer.deployment.resources.requests.memory | string | `"2Gi"` |  |
| apiServer.deployment.securityContext | object | `{}` |  |
| apiServer.deployment.sidecars | list | `[]` |  |
| apiServer.deployment.startupProbe.exec.command[0] | string | `"/bin/sh"` |  |
| apiServer.deployment.startupProbe.exec.command[1] | string | `"-c"` |  |
| apiServer.deployment.startupProbe.exec.command[2] | string | `"exec python /api/healthcheck.py"` |  |
| apiServer.deployment.startupProbe.failureThreshold | int | `6` |  |
| apiServer.deployment.startupProbe.periodSeconds | int | `10` |  |
| apiServer.deployment.startupProbe.timeoutSeconds | int | `1` |  |
| apiServer.deployment.tolerations | list | `[]` |  |
| apiServer.deployment.volumeMounts | list | `[]` |  |
| apiServer.deployment.volumes | list | `[]` |  |
| apiServer.name | string | `"api-server"` |  |
| apiServer.pdb.enabled | bool | `false` |  |
| apiServer.pdb.minAvailable | int | `1` |  |
| apiServer.service.annotations | object | `{}` |  |
| apiServer.service.httpPort | int | `80` |  |
| apiServer.service.httpsPort | int | `443` |  |
| apiServer.service.labels | object | `{}` |  |
| apiServer.service.loadBalancerIP | string | `""` |  |
| apiServer.service.loadBalancerSourceRanges | list | `[]` |  |
| apiServer.service.type | string | `"LoadBalancer"` |  |
| apiServer.serviceAccount.annotations | object | `{}` |  |
| apiServer.serviceAccount.automountServiceAccountToken | bool | `true` |  |
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
| postgres.pdb.enabled | bool | `false` |  |
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
| postgres.statefulSet.labels | object | `{}` |  |
| postgres.statefulSet.nodeSelector | object | `{}` |  |
| postgres.statefulSet.persistence.enabled | bool | `true` |  |
| postgres.statefulSet.persistence.size | string | `"8Gi"` |  |
| postgres.statefulSet.persistence.storageClassName | string | `""` |  |
| postgres.statefulSet.persistentVolumeClaimRetentionPolicy | object | `{}` |  |
| postgres.statefulSet.podSecurityContext | object | `{}` |  |
| postgres.statefulSet.priorityClassName | string | `""` |  |
| postgres.statefulSet.resources.limits.cpu | string | `"4000m"` |  |
| postgres.statefulSet.resources.limits.memory | string | `"16Gi"` |  |
| postgres.statefulSet.resources.requests.cpu | string | `"2000m"` |  |
| postgres.statefulSet.resources.requests.memory | string | `"8Gi"` |  |
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
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
