# Checking whether LangSmith still reads ClickHouse

Once LangSmith runs on SmithDB, ClickHouse can be turned off when LangSmith stops reading it. This script counts the reads LangSmith made on ClickHouse over the last days, from ClickHouse's own `system.query_log`.

This script is for BYOC data planes. On self-hosted, use **Settings › Instance** instead: its ClickHouse section tracks the reads every minute and tells you the next step.

### Turning ClickHouse off, in order

1. Migrate every caller listed on **Deprecated API Usage**, in each workspace's settings, until it shows none.
2. Once it shows none, contact LangChain support to turn ClickHouse queries off: LangChain manages this setting on BYOC data planes. Before that, LangSmith's own jobs and UI read ClickHouse on purpose, so this script always reports reads.

3. Wait for 7 days with no reads, then contact LangChain support to turn ClickHouse off.

### Prerequisites

1. Connectivity to ClickHouse from the machine you run the script on.

   - With the in-cluster ClickHouse, port forward it: `kubectl port-forward svc/langsmith-clickhouse 8123:8123`

2. ClickHouse credentials, either:

   - the user LangSmith connects as (in-cluster ClickHouse: `default`, with the password from the LangSmith secret), or
   - an admin user, plus the LangSmith user's name passed with `--app-user`.

   The user in the URL needs `SELECT` on `system.query_log` and `system.clusters`, and `REMOTE` to read every replica:

   ```sql
   GRANT SELECT ON system.query_log, SELECT ON system.clusters, REMOTE ON *.* TO <user>
   ```

3. Query logging on for the LangSmith user (`log_queries = 1`, the ClickHouse default).

4. ClickHouse must still hold the queries of the days you check. The in-cluster ClickHouse deletes them after 3 days, so one run there can't check a full week. Run the script with `--days 3` every 3 days during the week.

### Running the script

```bash
bash get_clickhouse_reads.sh <clickhouse_url> [--app-user <user>] [--days 7] [--cluster <name>] [--ssl] [--output reads.csv]
```

For example, with the in-cluster ClickHouse and port forwarding (3 days, all it keeps):

```bash
bash get_clickhouse_reads.sh "clickhouse://default:password@localhost:8123/default" --days 3
```

With an external ClickHouse, as an admin:

```bash
bash get_clickhouse_reads.sh "clickhouse://admin:<password>@<host>:8443/default" --ssl --app-user langsmith --days 7
```

The script reads `query_log` on every replica of the cluster. It picks `all_groups.default` (ClickHouse Cloud) or `default` when they exist. Pass `--cluster` only if LangSmith's `CLICKHOUSE_CLUSTER` setting names another cluster.

### Reading the result

The script prints a summary, the reads by source and query (to `--output` as CSV if set), and a verdict. The source says what ran the read: `api:smith-backend`, `api:smith-go`, `job:smith-backend:<job>`, `job:smith-go`, `job:smithdb-migration`, or `other:<client>` for any other tool.

| Exit code | Meaning |
|---|---|
| 0 | No LangSmith reads over the window, on every replica. |
| 2 | `query_log` cannot be read: grant access or use an admin user. |
| 3 | LangSmith or the SmithDB migration still reads ClickHouse. Keep it on; the table shows which queries. This is expected until ClickHouse queries are off (step 2 above). |
| 4 | The result cannot be trusted: logging is off for the user, some replicas did not answer, or a replica's `query_log` does not go back the whole window. Keep ClickHouse on. |

Reads by the SmithDB migration are listed apart. They are expected until the migration completes, and ClickHouse must stay on until then.
