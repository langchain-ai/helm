# Checking whether LangSmith still reads ClickHouse

Once LangSmith runs on SmithDB, ClickHouse can be turned off when LangSmith stops reading it. This script counts the reads LangSmith made on ClickHouse over the last days, from ClickHouse's own `system.query_log`.

On self-hosted, **Settings › Instance** tracks these reads every minute and tells you the next step. Use this script to cross-check it, or to see the queries behind a count.

On BYOC, ClickHouse queries stay on while ClickHouse runs, so the script always reports reads there. It still lists which callers read ClickHouse.

### Turning ClickHouse off, in order

1. Migrate every caller listed on **Deprecated API Usage**, in each workspace's settings, until it shows none.
2. Set `CLICKHOUSE_QUERY_ENABLED=false` in `commonEnv`. Before that, LangSmith's own jobs and UI read ClickHouse on purpose, so this script always reports reads.
3. Wait for 7 days with no reads, then set `clickhouse.enabled: false`.

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

4. ClickHouse must still hold the queries of the days you check. The in-cluster ClickHouse deletes each day's queries 3 days after that day starts, so it always holds the last 2 full days. One run there can't check a full week: run the script with `--days 2` every 2 days during the week, and once more on the 7th day.

### Running the script

```bash
bash get_clickhouse_reads.sh <clickhouse_url> [--app-user <user>] [--days 7] [--cluster <name>] [--ssl] [--output reads.csv]
```

For example, with the in-cluster ClickHouse and port forwarding (2 days, what it always holds):

```bash
bash get_clickhouse_reads.sh "clickhouse://default:<password>@localhost:8123/default" --days 2
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
| 1 | Bad arguments, or the script couldn't connect to ClickHouse. |
| 2 | `query_log` cannot be read: grant access or use an admin user. |
| 3 | LangSmith or the SmithDB migration still reads ClickHouse. Keep it on; the table shows which queries. This is expected until ClickHouse queries are off (step 2 above). |
| 4 | The result cannot be trusted: logging is off for the user, some replicas did not answer, or a replica's `query_log` does not go back the whole window. Keep ClickHouse on. |

Reads by the SmithDB migration show in the table under the source `job:smithdb-migration`, and their count has its own summary line. They are expected until the migration completes, and ClickHouse must stay on until then.
