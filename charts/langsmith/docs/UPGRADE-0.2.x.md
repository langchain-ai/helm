# Upgrade from v0.1.x to v0.2.x

Langsmith now uses Clickhouse to power analytics/handle runs. This means that you will need to migrate your old runs to the new database. See the Clickhouse section in values.yaml for more information.

If you don't have the repo added, run the following command to add it:
```bash
helm repo add langchain https://langchain-ai.github.io/helm/
```

Update your local helm repo
```bash
helm repo update
```

Certain versions of 0.1.x may require you to delete old deployments and statefulsets due to label changes. This will not delete any of your data
```bash
kubectl delete deployment langsmith-backend langsmith-frontend langsmith-hub-backend langsmith-playground langsmith-queue
kubectl delete statefulset langsmith-postgres langsmith-redis
```

Run the following command to upgrade the chart(replace x with latest patch version):
```bash
helm upgrade <release-name> langchain/langsmith --version 0.2.x --values <path-to-values-file>
```

Verify that the upgrade was successful:
```bash
helm status <release-name>
```
All pods should be in the `Running` state. Verify that clickhouse is running and that both backend-migrations containers have completed.

```bash
kubectl get pods 

NAME                                     READY   STATUS      RESTARTS   AGE
langsmith-backend-95b6d54f5-gz48b        1/1     Running     0          15h
langsmith-backend-migrations-d2z6k       0/2     Completed   0          5h48m
langsmith-clickhouse-0                   1/1     Running     0          26h
langsmith-frontend-84687d9d45-6cg4r      1/1     Running     0          15h
langsmith-hub-backend-66ffb75fb4-qg6kl   1/1     Running     0          15h
langsmith-playground-85b444d8f7-pl589    1/1     Running     0          15h
langsmith-queue-d58cb64f7-87d68          1/1     Running     0          15h
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

    ![.langsmith_ui.png](../langsmith_ui.png)

Note that old runs will not be visibile in the UI unless you migrate them. See [Migrating old runs](#migrating-old-runs) for more information.
This step is only required if you need access to run data from before the upgrade to Langsmith 0.2.x. If you are unsure or need assistance, please reach out to support@langchain.dev and we'd be happy to help.

# Migrating old runs

We have provided a migration script to migrate old runs from the old database to the new database. The script is located in the `scripts` directory of this repository.

### Prerequisites

Ensure you have the following tools/items ready.

1. PostgreSQL client
    1. https://www.postgresql.org/download/
2. Clickhouse client
    1. https://clickhouse.com/docs/en/integrations/sql-clients/clickhouse-client-local
3. PostgreSQL database connection:
    1. Host
    2. Port
    3. Username
       1. If using the bundled version, this is `postgres`
    4. Password
       1. If using the bundled version, this is `postgres`
    5. Database name
       1. If using the bundled version, this is `postgres`

4. Clickhouse database credentials
    1. Host
    2. Port
    3. Username
       1. If using the bundled version, this is `default`
    4. Password
       1. If using the bundled version, this is `password`
    5. Database name
       1. If using the bundled version, this is `default`
    
5. Connectivity to the PostgreSQL database from the machine you will be running the migration script on.
   1. If you are using the bundled version, you may need to port forward the postgresql service to your local machine.
   2. Run `kubectl port-forward svc/langsmith-postgres 5432:5432` to port forward the postgresql service to your local machine.
6. Connectivity to the Clickhouse database from the machine you will be running the migration script on.
   1. If you are using the bundled version, you may need to port forward the clickhouse service to your local machine.
   2. Run `kubectl port-forward svc/langsmith-clickhouse 9000:9000` to port forward the clickhouse service to your local machine.

### Running the migration script

Run the following command to run the migration script:

```bash
sh backfill_clickhouse.sh <postgres connection url> <clickhouse connection url>
```

For example, if you are using the bundled version with port-forwarding, the command would look like:

```bash
sh backfill_clickhouse.sh "postgres://postgres:postgres@localhost:5432/postgres" "clickhouse://default:password@localhost:9000/default"
```

If you visit the Langsmith UI, you should now see your old runs.
