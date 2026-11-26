# Running Support Queries against Postgres

This Helm repository contains queries to produce output that the LangSmith UI does not currently support directly (e.g. obtaining trace counts for multiple organizations in a single query). 

This command takes a postgres connection string that contains an embedded name and password (which can be passed in from a call to a secrets manager) and executes a query from an input file.  In the example below, we are using the `pg_get_users_by_org.sql` input file in the `support_queries/postgres` directory.

### Prerequisites

Ensure you have the following tools/items ready.

1. kubectl

   - https://kubernetes.io/docs/tasks/tools/

2. PostgreSQL client

   - https://www.postgresql.org/download/

3. PostgreSQL database connection:

   - Host
   - Port
   - Username
     - If using the bundled version, this is `postgres`
   - Password
     - If using the bundled version, this is `postgres`
   - Database name
     - If using the bundled version, this is `postgres`

4. Connectivity to the PostgreSQL database from the machine you will be running the migration script on.

   - If you are using the bundled version, you may need to port forward the postgresql service to your local machine.
   - Run `kubectl port-forward svc/langsmith-postgres 5432:5432` to port forward the postgresql service to your local machine.


### Running the query script

Run the following command to run the desired query:

```bash
sh run_support_query_pg.sh <postgres_url> --input path/to/query.sql
```

For example, if you are using the bundled version with port-forwarding, the command might look like:

```bash
sh run_support_query_pg.sh "postgres://postgres:postgres@localhost:5432/postgres" --input support_queries/postgres/pg_get_users_by_org.sql 
```

which will output the count of daily traces by workspace ID and organization ID.  To extract this to a file add the flag `--output path/to/file.csv`

### Exporting all usage data at once

To export every usage dataset in one command — instead of running each
`pg_usage_*_full_export.sql` individually — use `run_all_full_exports_pg.sh`. It
runs all read-only full-export queries, writes one CSV per dataset, and (if
`tar` is available) bundles them into a single `.tar.gz` for transfer. It only
runs the read-only `*_full_export.sql` scripts, never the `*_backfill_*` ones.

```bash
sh run_all_full_exports_pg.sh <postgres_url>
```

For example, if you are using the bundled version with port-forwarding:

```bash
sh run_all_full_exports_pg.sh "postgres://postgres:postgres@localhost:5432/postgres"
```

This writes one CSV per dataset into `./langsmith-usage-export/` (`traces`,
`nodes`, `agent_builder`, `snapshots`, `langchain_usage`, `sandbox`,
`engine_intelligence`, `engine_issues_agent`) and bundles
`./langsmith-usage-export.tar.gz`. Pass `--output-dir <dir>` to change the
location, `--debug` for verbose psql output, or `--help` for full usage.
