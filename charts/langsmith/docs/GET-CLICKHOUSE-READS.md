# Checking whether LangSmith still reads ClickHouse

Once LangSmith runs on SmithDB, ClickHouse can be turned off when LangSmith stops reading it. This script counts the reads LangSmith made on ClickHouse over the last days, from ClickHouse's own `system.query_log`.

It's safe to turn ClickHouse off once the script reports no reads for 7 days in a row.

### Prerequisites

1. Connectivity to ClickHouse from the machine you run the script on.

   - With the bundled ClickHouse, port forward it: `kubectl port-forward svc/langsmith-clickhouse 8123:8123`

2. ClickHouse credentials, either:

   - the user LangSmith connects as (with the bundled ClickHouse: `default` / `password`), or
   - an admin user, plus the LangSmith user's name passed with `--app-user`.

   The user in the URL needs `SELECT` on `system.query_log` and `system.clusters`, and `REMOTE` to read every replica:

   ```sql
   GRANT SELECT ON system.query_log, SELECT ON system.clusters, REMOTE ON *.* TO <user>
   ```

3. Query logging on for the LangSmith user (`log_queries = 1`, the ClickHouse default). The bundled ClickHouse keeps `query_log` for 3 days; with a shorter retention than `--days`, the script says so.

### Running the script

```bash
bash get_clickhouse_reads.sh <clickhouse_url> [--app-user <user>] [--days 7] [--cluster <name>] [--ssl] [--output reads.csv]
```

For example, with the bundled ClickHouse and port forwarding:

```bash
bash get_clickhouse_reads.sh "clickhouse://default:password@localhost:8123/default" --days 3
```

With an external ClickHouse, as an admin:

```bash
bash get_clickhouse_reads.sh "clickhouse://admin:<password>@<host>:8443/default" --ssl --app-user langsmith --days 7
```

The script reads `query_log` on every replica of the cluster. It picks `all_groups.default` (ClickHouse Cloud) or `default` when they exist; pass `--cluster` for another cluster name.

### Reading the result

The script prints a summary, the reads by query (to `--output` as CSV if set), and a verdict:

| Exit code | Meaning |
|---|---|
| 0 | No LangSmith reads over the window, on every replica. |
| 2 | `query_log` cannot be read: grant access or use an admin user. |
| 3 | LangSmith or the SmithDB migration still reads ClickHouse. Keep it on; the table shows which queries. |
| 4 | The result cannot be trusted: logging is off for the user, some replicas did not answer, or a replica's `query_log` does not go back the whole window. Keep ClickHouse on. |

Reads by the SmithDB migration are listed apart. They are expected until the migration completes, and ClickHouse must stay on until then.
