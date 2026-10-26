# langsmith-sandbox

![Version: 0.18.0-rc.1](https://img.shields.io/badge/Version-0.18.0--rc.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.18.17rc1](https://img.shields.io/badge/AppVersion-0.18.17rc1-informational?style=flat-square)

Helm chart to deploy the LangSmith sandbox runtime in a dedicated Kubernetes cluster.

## Usage

Install this chart in a dedicated sandbox cluster with `sandboxHost.enabled=true` while the main `langsmith` chart uses `sandboxes.enabled=true` and `sandboxes.deploymentMode=separateCluster`.

The sandbox cluster must have KVM-capable `linux/amd64` nodes, network access to the LangSmith API, a JuiceFS metadata Redis using `noeviction`, and object-storage access. Set `platform.endpoint` to the externally reachable LangSmith API base including `/api`.

Create the Secret described under [Requirements](#requirements), then set `serviceAuth.existingSecretName`.

For GitOps workflows that render without live cluster access, set `proxyCa.mode=existingSecret`. The default `generatedSecret` mode uses Helm `lookup` to preserve the CA, which pure render workflows cannot do.

By default, the LangSmith control plane connects directly to the node IPs advertised by sandbox-host on TCP port 19190. That traffic is plain HTTP and carries sandbox commands, files and credentials, so keep it on a private network you trust. If the clusters have no routed private network, or the traffic would leave one you trust, enable `sandboxHost.ingress` with TLS and set its `https://` origin as `sandboxes.hostIngressEndpoint` in the main `langsmith` chart. TLS ends at the ingress: inside the sandbox cluster, traffic from the ingress to the sandbox hosts and between sandbox hosts stays plain HTTP on port 19190, so allow it between sandbox nodes and keep that network private.

### Host ingress

The Ingress routes only `/internal/SandboxHost/` (host RPCs) and `/guest-operation/` (exec, files, tunnels, sandbox links, browser and service URLs). It does not route `/metrics` or `/readyz`; scrape and probe those on each sandbox-host pod at port 19190. Before you rely on the ingress, check:

- **Who connects:** the LangSmith `platform-backend` and `ingest-queue` pods, and the sandbox hosts themselves, which dial the ingress for sandbox links. If the ingress restricts source addresses, allow both. The sandbox hosts must also resolve the ingress hostname and trust its certificate; if a private CA signs it, add that CA to `customCa`. The LangSmith pods trust a private CA through the `langsmith` chart's `config.customCa`.
- **Health checks:** load balancers check the sandbox-host pods directly, not through these paths, and many check `/` (or the Ingress path) by default, which returns 404. Set the health-check path to `/readyz`. With the AWS Load Balancer Controller, add `alb.ingress.kubernetes.io/healthcheck-path: /readyz` and `alb.ingress.kubernetes.io/target-type: ip` (the Service is ClusterIP) to `sandboxHost.ingress.annotations`. On GKE, leave `ingressClassName` empty, set the `kubernetes.io/ingress.class: gce` annotation, and attach a `BackendConfig` with `healthCheck.requestPath: /readyz` and `healthCheck.port: 19190` through `sandboxHost.ingress.service.annotations` (`cloud.google.com/backend-config`).
- **Timeouts:** LangSmith waits up to 310 seconds for an exec request, and exec streams, tunnels, sandbox links and browser sessions are long-lived WebSockets or server-sent events. Set the controller's read, idle and backend timeouts above 310 seconds, and higher if long sessions must stay open; defaults of 30 to 60 seconds cut them off. On GKE, set `timeoutSec` in the same `BackendConfig`.
- **Request size:** file uploads go through the ingress. Raise the controller's body-size limit to at least your largest upload; on ingress-nginx set `nginx.ingress.kubernetes.io/proxy-body-size` (default `1m`).
- **WebSockets:** the controller must allow WebSocket upgrades on Ingress routes. Azure Application Gateway for Containers supports WebSockets only through the Gateway API, so it cannot serve this Ingress. Use another controller, or leave `sandboxHost.ingress` disabled and route the two paths above to port 19190 of the sandbox-host pods with your own Service and Gateway API `HTTPRoute`.

## Requirements

### Every cloud

- **Nodes:** KVM-capable `linux/amd64` nodes, tainted `sandbox.langsmith.com/host=true:NoSchedule` (the chart's default toleration) and labeled to match `sandboxHost.deployment.nodeSelector`. The selector has no default and must be set. With other taints, override `sandboxHost.deployment.tolerations` too.
- **JuiceFS metadata Redis:** `maxmemory-policy noeviction`. Require AUTH, TLS or IAM authentication whenever another cluster can reach it.
- **Network:**
  - TCP 19190 inbound to sandbox nodes from wherever the LangSmith `platform-backend` and `ingest-queue` pods appear on the network (node security group, pod CIDR or SNAT address, depending on the CNI).
  - TCP 19190 from the other sandbox nodes, which forward ingress requests, dial sandbox links and send live-migration streams to each other on that port.
  - With the host ingress, TCP 19190 from its controller or load balancer.
  - This hop is plain HTTP and carries sandbox secrets, commands and files. Keep it on a private network you trust, or use the host ingress with TLS (see Host ingress above).
  - Sandbox nodes must reach `platform.endpoint` on its port through every load balancer allowlist and egress firewall, and reach the JuiceFS Redis and object storage.
- **`platform.endpoint`:** `https://<LangSmith hostname>[/<base path>]/api`.
- **Secrets:** create a minimal Secret in the sandbox namespace and set `serviceAuth.existingSecretName`. Never copy the whole LangSmith application Secret. It holds:
  - the sandbox service-auth secret under `serviceAuth.secretKey` (default `sandbox_service_auth_secret`). Use a dedicated random value, never the LangSmith `api_key_salt`, which signs LangSmith's other service calls; the `langsmith` chart refuses `separateCluster` without one. Its value must equal the control plane's: `sandbox_service_auth_secret` in the `langsmith` chart's managed Secret, or the key `sandboxes.serviceAuth.secretKey` names in your `config.existingSecretName`. During a rotation, also set `serviceAuth.previousSecretKey`.
  - the callback signing JWK under `serviceAuth.callbackSigningJwkSecretKey`, identical to the control plane's. It is an Ed25519 private JWK; one way to generate it with OpenSSL:

    ```bash
    openssl genpkey -algorithm ED25519 -out callback-signing.pem
    d=$(openssl pkey -in callback-signing.pem -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=\n')
    x=$(openssl pkey -in callback-signing.pem -pubout -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=\n')
    printf '{"kty":"OKP","crv":"Ed25519","alg":"EdDSA","use":"sig","kid":"sandbox-callback-%s","x":"%s","d":"%s"}\n' "$(openssl rand -hex 8)" "$x" "$d"
    rm callback-signing.pem
    ```

  - optionally, the egress proxy URL under `authProxy.httpProxy.urlSecretKey`.
- **Version pairing and one runtime:**
  - Run the newest `langsmith-sandbox` chart whose appVersion equals the `langsmith` chart's (`helm search repo langchain/langsmith-sandbox --versions --devel`), and leave `images.sandboxHost.tag` empty so the image follows it.
  - Upgrade `langsmith` first and this chart within days. Pin exact chart versions, never ranges.
  - Run exactly one release of this chart per LangSmith install, and only while the `langsmith` release uses `sandboxes.deploymentMode: separateCluster`. Two runtimes reporting to one install merge into one host pool and stop each other's sandboxes.
  - To move from `sameCluster`, switch the `langsmith` release to `separateCluster` first, then install this chart against the same JuiceFS metadata and bucket.

### EKS

- An IAM OIDC provider for the sandbox cluster, and an IAM role that trusts `system:serviceaccount:<namespace>:<ServiceAccount name>`. Set `sandboxHost.serviceAccount.name` so the subject is stable.
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` and `s3:AbortMultipartUpload` on `arn:aws:s3:::<bucket>/<juicefs.name>/*`, and `s3:ListBucket` on `arn:aws:s3:::<bucket>` with the condition `s3:prefix` like `<juicefs.name>/*`. A bucket used only by JuiceFS needs no condition.
- `workloadIdentity.provider: aws` with `workloadIdentity.aws.roleArn`.
- Instance types that expose KVM, such as bare-metal instances.

### GKE

- A Standard cluster, not Autopilot, with a node pool on `UBUNTU_CONTAINERD` and nested virtualization (N2, N1, C3 or C4). Set the node pool's OAuth scope to `cloud-platform`, so IAM grants decide access.
- Recommended: a bucket used only by JuiceFS, with uniform bucket-level access, and `roles/storage.objectAdmin` on it for the node pool's service account. If JuiceFS must share a bucket, turn on uniform bucket-level access and use the condition `resource.name.startsWith("projects/_/buckets/<bucket>/objects/<juicefs.name>/") || resource.type == "storage.googleapis.com/Bucket"`. A prefix-only condition blocks the lists JuiceFS makes; the second clause lets sandbox nodes list every object's name and metadata in the bucket.
- With `juicefs.redis.iamAuthProvider: gcp`, use Memorystore for Redis Cluster and grant the node service account `roles/redis.dbConnectionUser`.
- Point `juicefs.hostMount.cacheDirs` at node-local SSD.
- `workloadIdentity.provider: gcp`. sandbox-host already uses the host network, and the chart runs the JuiceFS formatter there too, so both authenticate as the node pool's service account and need no Workload Identity binding. Leave `juicefsFormatJob.nodeSelector` empty, so the formatter runs on the sandbox node pool and uses that pool's service account.
- If the sandbox cluster shares a Google Cloud project with the main LangSmith cluster and has Workload Identity enabled, install this chart in a namespace other than the main install's. Workload Identity trusts a namespace and ServiceAccount name across every cluster in a project.

### AKS

- A VM size that supports nested virtualization.
- OIDC issuer and Workload Identity enabled, and a federated credential with subject `system:serviceaccount:<namespace>:<ServiceAccount name>`. Set `sandboxHost.serviceAccount.name` so it is stable.
- `Storage Blob Data Contributor` on the container; `juicefs.storage: wasb` with `juicefs.storageAccountName`.
- Azure Managed Redis on database 0 over `rediss://`, with the `NoEviction` eviction policy set on the database. JuiceFS cannot change it.
- Point `juicefs.hostMount.cacheDirs` at the temporary disk under `/mnt`.
- `workloadIdentity.provider: azure` with `workloadIdentity.azure.clientId` (and `tenantId` if it differs from the cluster's). The chart labels sandbox-host and the formatter with `azure.workload.identity/use`.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| authProxy.httpProxy | object | `{"noProxy":[],"urlSecretKey":"sandbox_egress_proxy_url"}` | Route sandbox egress (the sandbox auth proxy's upstream connections) through a corporate HTTP forward proxy, as an HTTP_PROXY/HTTPS_PROXY client would: plain HTTP as standard proxy requests, HTTPS and other TCP through CONNECT. The proxy must allow CONNECT to 443 and any other TCP ports sandboxes use; nothing falls back to direct access. |
| authProxy.httpProxy.noProxy | list | `[]` | Destinations dialed directly instead of through the proxy, with standard NO_PROXY matching: "internal.corp" matches the host and its subdomains, ".internal.corp" only subdomains, plus IP addresses, CIDR ranges such as "10.0.0.0/8", "host:port" entries, and "*". |
| authProxy.httpProxy.urlSecretKey | string | `"sandbox_egress_proxy_url"` | Key in serviceAuth.existingSecretName holding the proxy URL, `http://host:port` or `https://host:port` (TLS to the proxy itself, verified against customCa when set, otherwise the system roots). A missing key sends egress directly. For Basic proxy authentication use `http://user:password@host:port`, percent-encoding reserved characters; sandboxes never see the credentials. Read only from the Secret because the URL may carry credentials. |
| commonAnnotations | object | `{}` | Annotations applied to all resources. |
| commonDnsConfig | object | `{"options":[{"name":"ndots","value":"4"}]}` | DNS configuration applied to every sandbox runtime pod, including the JuiceFS formatter. sandbox-host resolves the external LangSmith API on each callback, so this is the hook for pointing at a specific resolver or trimming search-domain expansion. Set to null to inherit the Kubernetes defaults. |
| commonEnv | list | `[]` | Environment variables added to sandbox-host. Applied before sandboxHost.deployment.extraEnv, and rejected at render time if a name collides with one the chart manages. |
| commonInitContainers | list | `[]` | Init containers added to sandbox-host. Not applied to the JuiceFS formatter. |
| commonLabels | object | `{}` | Labels applied to all resources. |
| commonPodAnnotations | object | `{}` | Annotations applied to all pods. |
| commonPodSecurityContext | object | `{}` | Pod security context merged into component-specific pod security contexts. |
| commonVolumeMounts | list | `[]` | Volume mounts added to sandbox-host. Not applied to the JuiceFS formatter. |
| commonVolumes | list | `[]` | Volumes added to sandbox-host. Not applied to the JuiceFS formatter, which is a one-shot Job with a fixed spec. |
| customCa.existingSecretName | string | `""` | Existing Secret containing CA certificates (PEM; one key may hold several) that sandbox-host trusts when it calls the LangSmith API, the host ingress and an https egress proxy. |
| customCa.secretKey | string | `""` | Key within customCa.existingSecretName containing the CA certificate. |
| fullnameOverride | string | `""` | String to fully override the chart's generated name. |
| images.imagePullSecrets | list | `[]` | Image pull secrets for sandbox-host and the JuiceFS formatter. |
| images.registry | string | `""` | Optional registry prepended to the sandbox-host repository. |
| images.sandboxHost.pullPolicy | string | `"IfNotPresent"` |  |
| images.sandboxHost.repository | string | `"docker.io/langchain/sandbox-host"` |  |
| images.sandboxHost.tag | string | `""` | Leave empty to run the image matching this chart's appVersion, which is the LangSmith release it pairs with. Set it only to point at a mirror that carries the same tag; a pinned tag does not move when the chart is upgraded. |
| juicefs.bucket | string | `""` | Object storage bucket URL. S3: a region-explicit endpoint such as `https://bucket-name.s3.us-west-2.amazonaws.com`, not `s3://bucket-name`. GCS: `gs://bucket-name`. Azure: `https://<container>.blob.core.windows.net`. JuiceFS stores objects under `<juicefs.name>/`; use juicefs.name, not a bucket path, to separate volumes. |
| juicefs.existingSecretName | string | `""` | Existing Secret with JuiceFS config keys `name`, `metaurl`, `storage` and `bucket`. For Azure, `access-key` holds the storage account name; set `secret-key` only for account-key authentication. When set, the values above are ignored. |
| juicefs.hostMount.cacheDirs | list | `["/var/cache/juicefs"]` | Node-local paths for the JuiceFS cache, mounted from the host. Back them with local SSD or the node's temporary disk; the cache survives pod restarts on the same node, not node replacement. |
| juicefs.hostMount.mountOptions | list | `["--cache-size=51200","--cache-large-write"]` | Additional JuiceFS mount options. Configure cacheDirs instead of passing a cache-dir option here. |
| juicefs.name | string | `"sandbox-juicefs"` | JuiceFS volume name used for sandbox snapshots and filesystem state. |
| juicefs.redis.iamAuthProvider | string | `""` | IAM authentication provider for the JuiceFS Redis: "", `azure` or `gcp`. Needs workloadIdentity.provider set to the same value. On GKE, sandbox-host and the formatter both run on the host network and authenticate as the node pool's service account. |
| juicefs.redis.metaURL | string | `""` | JuiceFS Redis metadata URL. The Redis maxmemory policy must be noeviction. |
| juicefs.storage | string | `"s3"` | Object storage backend: `s3` (AWS), `gs` (GCP) or `wasb` (Azure Blob Storage). |
| juicefs.storageAccountName | string | `""` | Azure storage account name, passed to JuiceFS as its access key. Required when storage is wasb. |
| juicefsFormatJob.affinity | object | `{}` |  |
| juicefsFormatJob.annotations | object | `{}` |  |
| juicefsFormatJob.labels | object | `{}` | Extra labels on the JuiceFS formatter pod. A value here wins over the workload-identity label the chart adds. |
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
| sandboxHost.deployment.labels | object | `{}` | Extra labels on the sandbox-host Deployment and pods. With workloadIdentity.provider azure the chart adds `azure.workload.identity/use`; a value here wins. |
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
| sandboxHost.ingress.enabled | bool | `false` | Create an Ingress for sandbox-host port 19190. Enable it when the LangSmith control plane cannot reach sandbox node IPs, or when that plain-HTTP traffic would leave a trusted private network. Configure `tls` and set `sandboxes.hostIngressEndpoint` in the langsmith chart to its `https://` origin. Routes only `/internal/SandboxHost/` and `/guest-operation/`; see Host ingress in the chart README. |
| sandboxHost.ingress.host | string | `""` |  |
| sandboxHost.ingress.ingressClassName | string | `""` |  |
| sandboxHost.ingress.service.annotations | object | `{}` | Annotations on the sandbox-host Service the Ingress points at, for example `cloud.google.com/backend-config` on GKE. They win over `commonAnnotations` on a key clash. |
| sandboxHost.ingress.tls | list | `[]` |  |
| sandboxHost.name | string | `"sandbox-host"` |  |
| sandboxHost.pdb.annotations | object | `{}` |  |
| sandboxHost.pdb.enabled | bool | `false` |  |
| sandboxHost.pdb.labels | object | `{}` |  |
| sandboxHost.pdb.maxUnavailable | int | `1` |  |
| sandboxHost.rbac.annotations | object | `{}` |  |
| sandboxHost.rbac.create | bool | `true` |  |
| sandboxHost.rbac.labels | object | `{}` |  |
| sandboxHost.serviceAccount.annotations | object | `{}` | Extra ServiceAccount annotations. They win over commonAnnotations and over the workload-identity annotations the chart adds. |
| sandboxHost.serviceAccount.automountServiceAccountToken | bool | `true` |  |
| sandboxHost.serviceAccount.create | bool | `true` | Create the ServiceAccount sandbox-host and the formatter run as. |
| sandboxHost.serviceAccount.labels | object | `{}` | Extra ServiceAccount labels. |
| sandboxHost.serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the sandbox-host fullname. Set it explicitly when an IAM role trust policy or a federated credential names it. |
| serviceAuth.callbackSigningJwkSecretKey | string | `"sandbox_callback_signing_jwk"` | Secret key containing the Ed25519 private JWK used to sign sandbox callbacks. |
| serviceAuth.existingSecretName | string | `""` | Existing Secret containing only the shared sandbox service-auth key and callback-signing JWK. The values must match the LangSmith control-plane Secret. |
| serviceAuth.previousSecretKey | string | `""` | Optional Secret key containing the previous service-auth key during rotation. |
| serviceAuth.secretKey | string | `"sandbox_service_auth_secret"` | Secret key holding the sandbox service-auth secret (SANDBOX_X_SERVICE_AUTH_JWT_SECRET): a dedicated random value, never the LangSmith api_key_salt. Its value must equal the control plane's: `sandbox_service_auth_secret` in the langsmith chart's managed Secret, or the key `sandboxes.serviceAuth.secretKey` names in its config.existingSecretName. |
| workloadIdentity.aws.roleArn | string | `""` | IAM role assumed through IRSA. Required when provider is aws. |
| workloadIdentity.azure.clientId | string | `""` | Client ID of the user-assigned managed identity. Required when provider is azure. |
| workloadIdentity.azure.tenantId | string | `""` | Optional Entra tenant ID; defaults to the cluster's tenant. |
| workloadIdentity.provider | string | `""` | Cloud workload identity for sandbox-host and the JuiceFS formatter: "", `aws`, `gcp` or `azure`. With `gcp` the formatter runs on the host network, so both pods use the node pool's service account. |
