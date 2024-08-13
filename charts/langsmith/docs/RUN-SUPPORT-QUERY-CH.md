# Generating Clickhouse Stats
This Helm repository contains queries to produce output that the LangSmith UI does not currently support directly (e.g. obtaining trace counts for multiple workspaces by date in a single query). 

This command takes a clickhouse connection string that contains an embedded name and password (which can be passed in from a call to a secrets manager) and executes a query from an input file.  In the example below, we are using the `ch_get_current_trace_counts_by_ws_daily` input file in the `support_queries` directory.

### Prerequisites

Ensure you have the following tools/items ready.

1. kubectl

   - https://kubernetes.io/docs/tasks/tools/

2. Clickhouse database credentials

   - Host
   - Port
   - Username
     - If using the bundled version, this is `default`
   - Password
     - If using the bundled version, this is `password`
   - Database name
     - If using the bundled version, this is `default`

3. Connectivity to the Clickhouse database from the machine you will be running the `get_clickhouse_stats` script on.

   - If you are using the bundled version, you may need to port forward the clickhouse service to your local machine.
   - Run `kubectl port-forward svc/langsmith-clickhouse 8123:8123` to port forward the clickhouse service to your local machine.

### Running the clickhouse stats generation script

## Running the query script

Run the following command to run the desired query:

```bash
sh run_support_query_ch.sh <clickhouse_url> --input path/to/query.sql
```

For example, if you are using the bundled version with port-forwarding, the command might look like:

```bash
sh run_support_query_ch.sh "clickhouse://default:password@localhost:8123/default" --input support_queries/clickhouse/ch_get_current_trace_counts_by_ws_daily
```

which will output the count of daily traces by workspace ID and organization ID.  To extract this to a file add the flag `--output path/to/file.csv`

