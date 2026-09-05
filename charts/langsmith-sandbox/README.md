# langsmith-sandbox

![Version: 0.1.0-rc.1](https://img.shields.io/badge/Version-0.1.0--rc.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.17.18rc1](https://img.shields.io/badge/AppVersion-0.17.18rc1-informational?style=flat-square)

Helm chart to deploy the LangSmith sandbox runtime in a dedicated Kubernetes cluster.

## Usage

Install this chart in a dedicated sandbox cluster with `sandboxHost.enabled=true` while the main `langsmith` chart uses `sandboxes.enabled=true` and `sandboxes.deploymentMode=separateCluster`.

The sandbox cluster must have KVM-capable `linux/amd64` nodes, network access to the LangSmith API, a JuiceFS metadata Redis using `noeviction`, and object-storage access. Set `platform.endpoint` to the externally reachable LangSmith API base including `/api`.

Create a minimal Secret in the sandbox namespace containing the same sandbox service-auth value and callback-signing JWK used by the LangSmith control plane, then set `serviceAuth.existingSecretName`. Do not copy the entire LangSmith application Secret into the sandbox cluster.

For GitOps workflows that render without live cluster access, set `proxyCa.mode=existingSecret`. The default `generatedSecret` mode uses Helm `lookup` to preserve the CA, which pure render workflows cannot do.

By default, the LangSmith control plane connects directly to the node IPs advertised by sandbox-host on TCP port 19190. If the cluster networks are not routed, enable `sandboxHost.ingress` and configure the resulting HTTP(S) origin as `sandboxes.hostIngressEndpoint` in the main `langsmith` chart.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` | Annotations applied to all resources. |
| commonLabels | object | `{}` | Labels applied to all resources. |
| commonPodAnnotations | object | `{}` | Annotations applied to all pods. |
| commonPodSecurityContext | object | `{}` | Pod security context merged into component-specific pod security contexts. |
| customCa.existingSecretName | string | `""` | Existing Secret containing a CA certificate trusted when sandbox-host calls the LangSmith API. |
| customCa.secretKey | string | `""` | Key within customCa.existingSecretName containing the CA certificate. |
| fullnameOverride | string | `""` | String to fully override the chart's generated name. |
| images.imagePullSecrets | list | `[]` | Image pull secrets for sandbox-host and the JuiceFS formatter. |
| images.registry | string | `""` | Optional registry prepended to the sandbox-host repository. |
| images.sandboxHost.pullPolicy | string | `"IfNotPresent"` |  |
| images.sandboxHost.repository | string | `"docker.io/langchain/sandbox-host"` |  |
| images.sandboxHost.tag | string | `""` |  |
| juicefs.bucket | string | `""` | Object storage bucket or root URL. |
| juicefs.existingSecretName | string | `""` | Existing Secret containing name, metaurl, storage, bucket, and optional access-key/secret-key entries. |
| juicefs.hostMount.cacheDirs | list | `["/var/cache/juicefs"]` | Node-local paths used for the JuiceFS cache. |
| juicefs.hostMount.mountOptions[0] | string | `"--cache-size=51200"` |  |
| juicefs.hostMount.mountOptions[1] | string | `"--cache-large-write"` |  |
| juicefs.name | string | `"sandbox-juicefs"` | JuiceFS volume name used for sandbox snapshots and filesystem state. |
| juicefs.redis.metaURL | string | `""` | JuiceFS Redis metadata URL. The Redis maxmemory policy must be noeviction. |
| juicefs.storage | string | `"s3"` | Object storage backend: s3, gs, or wasb. |
| juicefs.storageAccountName | string | `""` | Azure storage account name. Required when storage is wasb. |
| juicefsFormatJob.affinity | object | `{}` |  |
| juicefsFormatJob.annotations | object | `{}` |  |
| juicefsFormatJob.labels | object | `{}` |  |
| juicefsFormatJob.nodeSelector | object | `{}` |  |
| juicefsFormatJob.podSecurityContext | object | `{}` |  |
| juicefsFormatJob.resources.requests.cpu | string | `"100m"` |  |
| juicefsFormatJob.resources.requests.memory | string | `"128Mi"` |  |
| juicefsFormatJob.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| juicefsFormatJob.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| juicefsFormatJob.tolerations | list | `[]` |  |
| nameOverride | string | `""` | Provide a name in place of `langsmith-sandbox`. |
| namespace | string | `""` | Namespace to install into. Defaults to the Helm release namespace. |
| platform.callbackIssuer | string | `""` | Issuer placed in sandbox callback JWTs. Defaults to platform.endpoint. |
| platform.endpoint | string | `""` | Externally reachable LangSmith API base used for host observations and lifecycle callbacks, including the `/api` prefix. |
| proxyCa.existingSecretName | string | `""` | Existing TLS Secret containing tls.crt and tls.key. |
| proxyCa.mode | string | `"generatedSecret"` | generatedSecret creates and reuses a self-signed sandbox proxy CA; existingSecret uses a Secret managed outside this chart. |
| proxyCa.secretName | string | `"smithbox-proxy-ca"` |  |
| sandboxHost.autoscaling.enabled | bool | `false` |  |
| sandboxHost.autoscaling.headroomHosts | int | `1` |  |
| sandboxHost.autoscaling.maxReplicas | int | `10` |  |
| sandboxHost.autoscaling.minReplicas | int | `1` |  |
| sandboxHost.autoscaling.scaleDownStabilizationSeconds | int | `300` |  |
| sandboxHost.autoscaling.targetUtilizationPercent | int | `70` |  |
| sandboxHost.deployment.annotations | object | `{}` |  |
| sandboxHost.deployment.extraEnv | list | `[]` |  |
| sandboxHost.deployment.initContainers | list | `[]` |  |
| sandboxHost.deployment.labels | object | `{}` |  |
| sandboxHost.deployment.nodeSelector | object | `{}` | Node selector for KVM-capable linux/amd64 nodes. |
| sandboxHost.deployment.podAnnotations | object | `{}` |  |
| sandboxHost.deployment.podSecurityContext | object | `{}` |  |
| sandboxHost.deployment.priorityClassName | string | `""` |  |
| sandboxHost.deployment.readinessProbe.failureThreshold | int | `3` |  |
| sandboxHost.deployment.readinessProbe.initialDelaySeconds | int | `5` |  |
| sandboxHost.deployment.readinessProbe.periodSeconds | int | `10` |  |
| sandboxHost.deployment.readinessProbe.tcpSocket.port | string | `"http"` |  |
| sandboxHost.deployment.readinessProbe.timeoutSeconds | int | `3` |  |
| sandboxHost.deployment.replicas | int | `1` |  |
| sandboxHost.deployment.resources.requests.cpu | string | `"2"` |  |
| sandboxHost.deployment.resources.requests.memory | string | `"2Gi"` |  |
| sandboxHost.deployment.securityContext.privileged | bool | `true` |  |
| sandboxHost.deployment.sidecars | list | `[]` |  |
| sandboxHost.deployment.terminationGracePeriodSeconds | int | `300` |  |
| sandboxHost.deployment.tolerations[0].effect | string | `"NoSchedule"` |  |
| sandboxHost.deployment.tolerations[0].key | string | `"sandbox.langsmith.com/host"` |  |
| sandboxHost.deployment.tolerations[0].operator | string | `"Equal"` |  |
| sandboxHost.deployment.tolerations[0].value | string | `"true"` |  |
| sandboxHost.deployment.volumeMounts | list | `[]` |  |
| sandboxHost.deployment.volumes | list | `[]` |  |
| sandboxHost.enabled | bool | `false` | Deploy the sandbox-host runtime and supporting resources. |
| sandboxHost.ingress.annotations | object | `{}` |  |
| sandboxHost.ingress.enabled | bool | `false` | Expose one authenticated entry point for control planes that cannot route directly to sandbox node IPs on port 19190. |
| sandboxHost.ingress.host | string | `""` |  |
| sandboxHost.ingress.ingressClassName | string | `""` |  |
| sandboxHost.ingress.tls | list | `[]` |  |
| sandboxHost.name | string | `"sandbox-host"` |  |
| sandboxHost.pdb.annotations | object | `{}` |  |
| sandboxHost.pdb.enabled | bool | `false` |  |
| sandboxHost.pdb.labels | object | `{}` |  |
| sandboxHost.pdb.maxUnavailable | int | `1` |  |
| sandboxHost.rbac.annotations | object | `{}` |  |
| sandboxHost.rbac.create | bool | `true` |  |
| sandboxHost.rbac.labels | object | `{}` |  |
| sandboxHost.serviceAccount.annotations | object | `{}` |  |
| sandboxHost.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| sandboxHost.serviceAccount.create | bool | `true` |  |
| sandboxHost.serviceAccount.labels | object | `{}` |  |
| sandboxHost.serviceAccount.name | string | `""` |  |
| serviceAuth.callbackSigningJwkSecretKey | string | `"sandbox_callback_signing_jwk"` | Secret key containing the Ed25519 private JWK used to sign sandbox callbacks. |
| serviceAuth.existingSecretName | string | `""` | Existing Secret containing only the shared sandbox service-auth key and callback-signing JWK. The values must match the LangSmith control-plane Secret. |
| serviceAuth.previousSecretKey | string | `""` | Optional Secret key containing the previous service-auth key during rotation. |
| serviceAuth.secretKey | string | `"api_key_salt"` | Secret key containing the value used as SANDBOX_X_SERVICE_AUTH_JWT_SECRET. |
