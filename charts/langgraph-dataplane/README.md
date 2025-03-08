# langgraph-dataplane

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart to deploy a langgraph dataplane on kubernetes.

## Deploying a LangGraph Dataplane with Helm

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
| commonEnv | list | `[]` | Common environment variables that will be applied to all deployments/statefulsets except for the playground/aceBackend services (which are sandboxed). Be careful not to override values already specified by the chart. |
| commonLabels | object | `{}` | Labels that will be applied to all resources created by the chart |
| fullnameOverride | string | `""` | String to fully override `"langsmith.fullname"` |
| images.imagePullSecrets | list | `[]` | Secrets with credentials to pull images from a private registry. Specified as name: value. |
| images.listenerImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.listenerImage.repository | string | `"docker.io/langchain/hosted-langserve-backend"` |  |
| images.listenerImage.tag | string | `"0.9.57"` |  |
| images.redisImage.pullPolicy | string | `"IfNotPresent"` |  |
| images.redisImage.repository | string | `"docker.io/redis"` |  |
| images.redisImage.tag | string | `"7"` |  |
| nameOverride | string | `""` | Provide a name in place of `langsmith` |

## Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config.langgraphPlatformLicenseKey | string | `""` |  |
| config.langsmithApiKey | string | `""` |  |

## Listener

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| listener.autoscaling.createHpa | bool | `true` |  |
| listener.autoscaling.enabled | bool | `false` |  |
| listener.autoscaling.maxReplicas | int | `10` |  |
| listener.autoscaling.minReplicas | int | `3` |  |
| listener.autoscaling.targetCPUUtilizationPercentage | int | `50` |  |
| listener.autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| listener.deployment.affinity | object | `{}` |  |
| listener.deployment.annotations | object | `{}` |  |
| listener.deployment.autoRestart | bool | `true` |  |
| listener.deployment.command[0] | string | `"saq"` |  |
| listener.deployment.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.command[2] | string | `"--quiet"` |  |
| listener.deployment.extraContainerConfig | object | `{}` |  |
| listener.deployment.extraEnv | list | `[]` |  |
| listener.deployment.labels | object | `{}` |  |
| listener.deployment.livenessProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.livenessProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.livenessProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.livenessProbe.failureThreshold | int | `6` |  |
| listener.deployment.livenessProbe.periodSeconds | int | `60` |  |
| listener.deployment.livenessProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.nodeSelector | object | `{}` |  |
| listener.deployment.podSecurityContext | object | `{}` |  |
| listener.deployment.readinessProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.readinessProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.readinessProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.readinessProbe.failureThreshold | int | `6` |  |
| listener.deployment.readinessProbe.periodSeconds | int | `60` |  |
| listener.deployment.readinessProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.replicas | int | `3` |  |
| listener.deployment.resources.limits.cpu | string | `"2000m"` |  |
| listener.deployment.resources.limits.memory | string | `"4Gi"` |  |
| listener.deployment.resources.requests.cpu | string | `"1000m"` |  |
| listener.deployment.resources.requests.memory | string | `"2Gi"` |  |
| listener.deployment.securityContext | object | `{}` |  |
| listener.deployment.sidecars | list | `[]` |  |
| listener.deployment.startupProbe.exec.command[0] | string | `"saq"` |  |
| listener.deployment.startupProbe.exec.command[1] | string | `"app.workers.queues.host_worker.settings"` |  |
| listener.deployment.startupProbe.exec.command[2] | string | `"--check"` |  |
| listener.deployment.startupProbe.failureThreshold | int | `6` |  |
| listener.deployment.startupProbe.periodSeconds | int | `60` |  |
| listener.deployment.startupProbe.timeoutSeconds | int | `30` |  |
| listener.deployment.terminationGracePeriodSeconds | int | `30` |  |
| listener.deployment.tolerations | list | `[]` |  |
| listener.deployment.topologySpreadConstraints | list | `[]` |  |
| listener.deployment.volumeMounts | list | `[]` |  |
| listener.deployment.volumes | list | `[]` |  |
| listener.name | string | `"listener"` |  |
| listener.pdb.enabled | bool | `false` |  |
| listener.pdb.minAvailable | int | `1` |  |
| listener.serviceAccount.annotations | object | `{}` |  |
| listener.serviceAccount.create | bool | `true` |  |
| listener.serviceAccount.labels | object | `{}` |  |
| listener.serviceAccount.name | string | `""` |  |

## Redis

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.containerPort | int | `6379` |  |
| redis.external.connectionUrl | string | `""` |  |
| redis.external.connectionUrlSecretKey | string | `"connection_url"` |  |
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
| redis.statefulSet.topologySpreadConstraints | list | `[]` |  |
| redis.statefulSet.volumeMounts | list | `[]` |  |
| redis.statefulSet.volumes | list | `[]` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Ankush | <ankush@langchain.dev> |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
## Docs Generated by [helm-docs](https://github.com/norwoodj/helm-docs)
`helm-docs -t ./charts/langgraph-cloud/README.md.gotmpl`
