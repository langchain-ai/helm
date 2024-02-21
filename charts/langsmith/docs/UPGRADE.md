# General Upgrade Instructions

If you don't have the repo added, run the following command to add it:
```bash
helm repo add langchain https://langchain-ai.github.io/helm/
```

Update your local helm repo
```bash
helm repo update
```

Run the following command to upgrade the chart(replace version with the version you want to upgrade to):
```bash
helm upgrade <release-name> langchain/langsmith --version <version> --values <path-to-values-file>
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
