# Migrating from no-auth to OAuth

We have provided a migration script to migrate your no-auth tenant to an oauth tenant. The script is located in the `scripts` directory of this repository.

### Prerequisites

Ensure you have the following tools/items ready.

1. PostgreSQL client
    1. https://www.postgresql.org/download/
2. PostgreSQL database connection:
    1. Host
    2. Port
    3. Username
       1. If using the bundled version, this is `postgres`
    4. Password
       1. If using the bundled version, this is `postgres`
    5. Database name
       1. If using the bundled version, this is `postgres` 
3. Connectivity to the PostgreSQL database from the machine you will be running the migration script on.
   1. If you are using the bundled version, you may need to port forward the postgresql service to your local machine.
   2. Run `kubectl port-forward svc/langsmith-postgres 5432:5432` to port forward the postgresql service to your local machine.
4. The script can only be run after oauth is added and someone has logged in with the desired "admin user" at least once.

### Running the migration script

Run the following command to run the migration script:

```bash
sh migrate_no_auth.sh <postgres connection url> <admin user email>
```

For example, if you are using the bundled version with port-forwarding, the command would look like:

```bash
sh migrate_no_auth.sh "postgres://postgres:postgres@localhost:5432/postgres" "harrison@langchain.dev"
```

If you visit the Langsmith UI, you should now see a tenant called default that has your old runs.
