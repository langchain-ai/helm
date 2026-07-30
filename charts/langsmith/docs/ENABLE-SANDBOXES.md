# Enable LangSmith Sandboxes

Sandboxes run untrusted code in Firecracker microVMs on dedicated nodes in the same cluster as
LangSmith. They are disabled by default and turned on with `config.sandboxes.enabled=true`.

Currently supported on AWS/EKS and GCP/GKE. Azure/AKS is supported by the base LangSmith chart,
but not by sandboxes.

## Cluster prerequisites

These are cluster-side and are **not** created by the chart. Have them in place before enabling
sandboxes.

### 1. A node pool with `/dev/kvm`

Each sandbox is a Firecracker microVM, so the host nodes need KVM.

- **GKE**: any `n2-*` machine type with nested virtualization enabled. `e2-*` does not support it.
- **EKS**: EC2 does not offer nested virtualization on shared-tenancy instance types, so this
  requires **bare-metal** instances (for example `m5.metal`, `c5.metal`). Confirm your chosen
  instance type exposes `/dev/kvm` before sizing the pool.

Size the pool for whole sandboxes: `config.sandboxes.limits.maxCpuCores` and `maxMemoryGb` cap a
single sandbox, and one node hosts many.

### 2. Node labels and taints

`sandbox-host` runs one pod per node and expects the pool to be labelled and tainted:

```
label: sandbox.langsmith.com/host=true
taint: sandbox.langsmith.com/host=true:NoSchedule
```

Override with `config.sandboxes.sandboxHost.deployment.nodeSelector` and `.tolerations` if your
pool uses different keys.

### 3. Node port reachability

`sandbox-host` is `hostNetwork` and binds `hostPort` 19190. The LangSmith platform backend
connects to hosts on that port by node IP, so node-level firewalling or security groups must
allow it from the pods in the LangSmith namespace.

Only one host pod can occupy a node, which the chart enforces with required pod anti-affinity.

### 4. Privileged pods allowed in the namespace

`sandbox-host` runs privileged in order to manage microVMs. If you apply Pod Security Admission,
the LangSmith namespace must not be `restricted`.

### 5. Object storage for JuiceFS

Sandbox filesystems live in JuiceFS, backed by a bucket you provide as
`config.sandboxes.juicefs.bucket`.

- **S3** (`storage: s3`): use a region-explicit endpoint,
  `https://<bucket>.s3.<region>.amazonaws.com`. The `s3://<bucket>` shorthand is rejected,
  because JuiceFS would then resolve the region with `GetBucketLocation`.
- **GCS** (`storage: gs`): `gs://<bucket>`.

Grant the JuiceFS CSI node ServiceAccount access to the bucket with workload identity rather than
static keys, via `config.sandboxes.juicefs.csi.node.serviceAccount.annotations` (AWS IRSA or GCP
Workload Identity).

### 6. Redis for JuiceFS metadata

`config.sandboxes.juicefs.redis.metaURL` points at a Redis holding JuiceFS metadata. This is
separate from the Redis LangSmith itself uses.

**It must be configured with `maxmemory-policy noeviction`.** An evicting Redis silently discards
filesystem metadata. On Redis Cluster, the `/DB` path component is used by JuiceFS as a hash-tag
key prefix, not as a logical database index.

### 7. Wildcard DNS and TLS, if you expose sandbox services

Only needed when you set `config.sandboxes.serviceUrlBaseUrl` to reach HTTP services running
inside sandboxes. That host needs wildcard DNS and a wildcard certificate for `*.<host>`. With
`ingress.enabled=true` the chart adds the matching wildcard rule; add the host to `ingress.tls`
yourself.

### 8. A `sandbox-host` image your registry can pull

`images.sandboxHostImage.tag` has no default and is required when sandboxes are enabled. Sandbox
images are published for `linux/amd64` only. To mirror them into a private registry:

```bash
./scripts/mirror_langsmith_images.sh --registry <registry> --version <version> --include-sandboxes
```

The image must be recent enough to read `SANDBOX_HOST_DEPLOYMENT_NAME`, which the chart uses to
tell the host which Deployment to scale. An older image ignores it and pool autoscaling will not
work.

## Required values

```yaml
config:
  hostname: langsmith.example.com   # supplies the public issuer for signed sandbox callbacks
  sandboxes:
    enabled: true
    callbackSigningJwk: '{...}'     # private JWK; or key sandbox_callback_signing_jwk in your existing Secret
    juicefs:
      bucket: https://my-bucket.s3.us-west-2.amazonaws.com
      redis:
        metaURL: redis://my-redis:6379/1

images:
  sandboxHostImage:
    tag: "<version>"
```

`config.hostname` is not strictly required, but without it the chart cannot advertise a public
issuer and sandbox egress callbacks fail closed, since receivers fetch the verification key from
`<issuer>/.well-known/jwks.json`.

Service auth between LangSmith and the sandbox runtime reuses `config.apiKeySalt`, the same secret
the chart already uses for `X_SERVICE_AUTH_JWT_SECRET`. There is nothing extra to set.

## Reaching internal HTTPS services from sandboxes

Sandbox egress is intercepted by a MITM proxy on the host, so code inside a sandbox only ever
validates the proxy's own CA — nothing in the guest needs your CA. The proxy is what verifies the
real origin, and it does so against the system trust store.

If sandboxes need to reach an internal service signed by your own CA, set `config.customCa`
(`secretName` and `secretKey`). The chart mounts it for `sandbox-host` and points
`SANDBOX_HOST_EGRESS_ORIGIN_CA_FILE` at it, which **adds** your CA to the proxy's trust pool
rather than replacing it, so public HTTPS keeps working in the same sandbox. Requires a
`sandbox-host` image containing that variable; an older image ignores it.

A configured CA that cannot be read fails host startup, rather than starting with the CA silently
absent.

## The JuiceFS CSI driver

Enabling sandboxes also installs the JuiceFS CSI driver, which creates **cluster-scoped**
resources (a `CSIDriver` named `csi.juicefs.com`, plus ClusterRoles) under the upstream names.

- Only one sandbox-enabled LangSmith release per cluster may install it.
- If the cluster already runs the JuiceFS CSI driver, set
  `config.sandboxes.juicefs.csi.install=false`. The chart then renders only the sandbox
  PersistentVolumes, PersistentVolumeClaims and CSI config Secret, bound to the existing driver.
- Leaving it enabled alongside an independent installation fails the install on those shared
  names.

## Scaling the host pool

`config.sandboxes.sandboxHost.deployment.replicas` sets how many nodes back the pool. Because
hosts are one per node, it must not exceed the size of the sandbox node pool.

The pool can size itself instead: with `config.sandboxes.sandboxHost.autoscaling.enabled=true`,
the elected host resizes its own Deployment from observed load, and the chart stops managing
`replicas` so Helm does not fight it. For a live change that does not restart hosts — restarting a
host suspends every microVM on it — set `sandbox-host.smith.langchain.com/autoscale-*` annotations
on the Deployment; the chart does not manage those. `autoscale-override` freezes (`off`) or pins
the pool to an exact count.

Image updates roll one node at a time (`maxSurge: 0`), because a surge pod could never schedule
against the `hostPort`. Each host suspends its microVMs to JuiceFS within
`terminationGracePeriodSeconds` before exiting.
