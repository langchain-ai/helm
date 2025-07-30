# Replicated Clickhouse Cluster
This folder can be used to setup a replicated clickhouse setup on a kubernetes cluster. You can then connect your LangSmith instance to this replicated ClickHouse setup. There are two manifest files in this folder that are used in the installation instructions below:
- `zookeeper-3-node-config.yaml`
- `replicated-clickhouse-3-node-config.yaml`

Note: This is intended for LangSmith instances that are expected to receive high load for both trace ingestion (write path) as well as high load for trace querying (read path). The default single instance ClickHouse deployment that comes with LangSmith should be able to handle other scenarios.

## Deployment Steps
1. Install the clickhouse operator on the kubernetes cluster. Run the command below after replacing `<langsmith-namespace>` with the namespace you will be deploying the replicated clickhouse cluster into.
```
$ curl -s https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator-web-installer/clickhouse-operator-install.sh | OPERATOR_NAMESPACE=<langsmith-namespace> bash
```
You should see a clickhouse operator pod created.
```
$ kubectl get pods
clickhouse-operator-67db695d69-9pvtz   2/2     Running   0          17m
```

2. Apply the zookeeper configuration file found in this repo. The resource configuration currently set should be able to handle a wide range of load patterns, but feel free to update that if needed.

**Important: There must be a default storage class on the cluster, or you will need to specify how you would like to provision volumes in the manifest itself.**
```
$ kubectl -n <langsmith-namespace> apply -f zookeeper-3-node-config.yaml
```
You should see zookeeper pods created.
```
$ kubectl get pods
langsmith-zookeeper-0                            1/1     Running   0          9m16s
langsmith-zookeeper-1                            1/1     Running   0          8m25s
langsmith-zookeeper-2                            1/1     Running   0          7m36s

$ kubectl get pvc
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
datadir-volume-langsmith-zookeeper-0   Bound    pvc-bd8844ea-fab1-408b-8daf-2c4387028946   25Gi       RWO            gp3            <unset>                 9m24s
datadir-volume-langsmith-zookeeper-1   Bound    pvc-7d7905e8-09d8-4ac5-93f2-474e222b7591   25Gi       RWO            gp3            <unset>                 8m40s
datadir-volume-langsmith-zookeeper-2   Bound    pvc-8a41cb6f-e7db-48fa-af2f-489e882b5ee2   25Gi       RWO            gp3            <unset>                 7m59s
```

3. Apply the clickhouse installation manifest which will instruct the clickhouse operator how to setup the replicated clickhouse cluster. You can update fields there as needed as well, but the default values should be a great starting point.

**Warning: If your pod IP space is not 10.0.0.0/16, please update this section to use your pod's CIDR block:**
```yaml
      default/networks/ip:
        - "10.0.0.0/16"
```

Run a command like this:
```
$ kubectl -n <langsmith-namespace> apply -f replicated-clickhouse-3-node-config.yaml
```
You should see a 3 node replicated ClickHouse cluster provisioned.
```
$ kubectl get pods
chi-ch-repl-replicated-0-0-0                    1/1     Running   0             3m8s
chi-ch-repl-replicated-0-1-0                    1/1     Running   0             2m3s
chi-ch-repl-replicated-0-2-0                    1/1     Running   0             72s

$ kubectl get pvc
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
default-chi-ch-repl-replicated-0-0-0   Bound    pvc-2dccb1b8-cf96-4ef1-af17-a85276277d9b   200Gi      RWO            gp3            <unset>                 4m3s
default-chi-ch-repl-replicated-0-1-0   Bound    pvc-c9e231c8-fa63-4849-9157-e236ca595842   200Gi      RWO            gp3            <unset>                 2m56s
default-chi-ch-repl-replicated-0-2-0   Bound    pvc-8c94e554-eb86-42c6-b20b-c9a1bad7f1df   200Gi      RWO            gp3            <unset>                 2m5s
```

4. After the replicated ClickHouse cluster is setup, you can then configure the appropriate LangSmith values. Here is an example if you do not change any of the fields in replicated-clickhouse-3-node-config.yaml (please fill in `<langsmith-namespace>`):
```yaml
clickhouse:
  external:
    enabled: true
    host: langsmith-ch-clickhouse-replicated.<langsmith-namespace>.svc.cluster.local
    port: "8123"
    nativePort: "9000"
    user: "default"
    password: "password"
    database: "default"
    cluster: "replicated"
```
Running a helm install/upgrade with the above snippet included should allow the LangSmith application to connect to your replicated clickhouse setup.

**Important: If you notice that your ClickHouse setup is reaching resource limits, try increasing those and applying your updated clickhouse installtion manifest.**
