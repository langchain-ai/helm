#!/bin/bash

# Reports the reads LangSmith made on ClickHouse over the last days, from
# system.query_log, so you can tell when ClickHouse can be turned off.
#
# Only queries of the ClickHouse user LangSmith connects as count. Reads of
# system tables, schema checks, this script and the Instance health job are
# housekeeping and left out. Reads by the SmithDB migration are reported
# apart: they stop once the migration completes.
#
# Exit codes: 0 no reads, 1 usage or connection error, 2 query_log cannot be
# read, 3 reads found (LangSmith or the migration), 4 the result cannot be
# trusted.

print_usage_and_exit() {
    echo "Error: $1"
    echo "Usage: $0 <clickhouse_url> [--app-user <user>] [--days <days>] [--cluster <name>] [--ssl] [--output <path/to/file.csv>] [--debug]"
    echo "Example: $0 clickhouse://admin:password@host:8123/default --app-user langsmith --days 7"
    exit 1
}

clickhouse_url=""
app_user=""
days=7
cluster=""
ssl=""
output_file=""
debug=""

while [ $# -gt 0 ]; do
    case "$1" in
        --app-user)
            app_user="$2"
            shift 2
            ;;
        --days)
            days="$2"
            shift 2
            ;;
        --cluster)
            cluster="$2"
            shift 2
            ;;
        --ssl)
            ssl="true"
            shift
            ;;
        --output)
            output_file="$2"
            shift 2
            ;;
        --debug)
            debug="true"
            shift
            ;;
        *)
            if [ -z "$clickhouse_url" ]; then
                clickhouse_url="$1"
                shift
            else
                print_usage_and_exit "Unknown argument: $1"
            fi
            ;;
    esac
done

if [ -z "$clickhouse_url" ]; then
    print_usage_and_exit "ClickHouse URL is required."
fi

if [[ $clickhouse_url =~ ^clickhouse://([^:]+):([^@]+)@([^:]+):([0-9]+)/([^/]+)$ ]]; then
    ch_user="${BASH_REMATCH[1]}"
    ch_passwd="${BASH_REMATCH[2]}"
    ch_host="${BASH_REMATCH[3]}"
    ch_port="${BASH_REMATCH[4]}"
    ch_database="${BASH_REMATCH[5]}"
else
    print_usage_and_exit "Invalid ClickHouse URL format. Expected format: clickhouse://username:password@host:port/database"
fi

# Run as the LangSmith user by default; an admin passes --app-user.
app_user="${app_user:-$ch_user}"

# Values go into the URL as query parameters, so keep them URL-safe.
for value in "$app_user" "$cluster"; do
    if [[ -n "$value" && ! $value =~ ^[A-Za-z0-9_.-]+$ ]]; then
        print_usage_and_exit "Unsupported characters in '$value'."
    fi
done
if [[ ! $days =~ ^[1-9][0-9]*$ ]]; then
    print_usage_and_exit "--days must be a positive number."
fi

if [ "$debug" = "true" ]; then
    set -x
fi

if [ "$ssl" = "true" ]; then
    ch_protocol="https"
else
    ch_protocol="http"
fi
base_url="$ch_protocol://$ch_host:$ch_port/?database=$ch_database&param_app_user=$app_user&param_days=$days"

# run_query <sql> [format]: prints the result, or prints the ClickHouse error
# on stderr and returns nonzero. The leading comment lets later runs skip
# these queries.
run_query() {
    local out
    if ! out=$(curl -s --show-error --fail-with-body --user "$ch_user:$ch_passwd" \
        -H "X-ClickHouse-Format: ${2:-TSV}" \
        --data-binary "-- get_clickhouse_reads
$1" "$base_url&param_cluster=$cluster" 2>&1); then
        echo "ClickHouse query failed: $out" >&2
        return 1
    fi
    printf '%s\n' "$out"
}

# 1. query_log must be readable.
if ! run_query "SELECT count() FROM merge('system', '^query_log') WHERE event_date >= today()" > /dev/null; then
    echo "Cannot read system.query_log."
    echo "Grant SELECT ON system.query_log, SELECT ON system.clusters and REMOTE ON *.* to the user in the URL, or run this script with an admin user and --app-user."
    exit 2
fi

# 2. query_log is per replica: read every replica of the cluster. On
# ClickHouse Cloud, all_groups.<cluster> holds the replicas of every compute
# group. Without a cluster, read the server connected to.
if [ -z "$cluster" ]; then
    cluster=$(run_query "SELECT cluster FROM system.clusters WHERE cluster IN ('all_groups.default', 'default') GROUP BY cluster ORDER BY cluster = 'all_groups.default' DESC LIMIT 1") || exit 1
fi
if [ -n "$cluster" ]; then
    replicas_expected=$(run_query "SELECT count() FROM system.clusters WHERE cluster = {cluster:String}") || exit 1
    source="clusterAllReplicas({cluster:String}, merge('system', '^query_log'))"
    reachable_query="SELECT uniqExact(hostName()) FROM clusterAllReplicas({cluster:String}, system.one)"
else
    replicas_expected=1
    source="merge('system', '^query_log')"
    reachable_query="SELECT 1"
fi
settings="SETTINGS skip_unavailable_shards = 1, max_threads = 5"
replicas_reachable=$(run_query "$reachable_query $settings") || exit 1

# The oldest entry of each replica's query_log, which its retention sets.
coverage=$(run_query "
SELECT
    countIf(oldest <= now() - INTERVAL {days:UInt32} DAY),
    toString(max(oldest))
FROM (SELECT hostName() AS replica, min(event_time) AS oldest FROM $source GROUP BY replica)
$settings") || exit 1
IFS=$'\t' read -r replicas_covered newest_start <<< "$coverage"

# One row per query of the window, marked as a LangSmith read or not.
read_rows="
SELECT
    hostName() AS replica,
    event_time,
    user,
    type != 'QueryStart' AND query_kind = 'Select'
        AND user = {app_user:String}
        AND NOT (notEmpty(tables) AND arrayAll(
            t -> startsWith(t, 'system.') OR startsWith(t, '_table_function.'),
            tables))
        AND query NOT LIKE '%schema_migrations%'
        AND NOT startsWith(query, '-- get_clickhouse_reads')
        AND NOT startsWith(query, '-- instance_health_clickhouse') AS is_read,
    http_user_agent LIKE 'clickhouse-rs/%' AS is_migration,
    type != 'QueryFinish' AS failed,
    extract(query, '\n-- job_func_name:([^\n]+)') AS job_name,
    concat(client_name, ' ', http_user_agent) AS client,
    multiIf(
        is_migration, 'job:smithdb-migration',
        job_name != '', concat('job:smith-backend:', job_name),
        position(client, 'asynq') > 0, 'job:smith-go',
        position(client, 'platform-backend/') > 0, 'api:smith-go',
        position(client, 'python-httpx/') > 0, 'api:smith-backend',
        concat('other:', trimBoth(client))) AS caller_source,
    replaceRegexpAll(replaceRegexpOne(
        splitByChar('\n', replaceRegexpOne(query, '^\\\\s+', ''))[1], '^--', ''),
        '^\\\\s+|\\\\s+$', '') AS caller_query
FROM $source
WHERE event_date >= today() - {days:UInt32}
    AND event_time >= now() - INTERVAL {days:UInt32} DAY
"
# 3. Summary.
summary=$(run_query "
SELECT
    countIf(user = {app_user:String}),
    countIf(is_read AND NOT is_migration),
    toString(maxIf(event_time, is_read AND NOT is_migration)),
    countIf(is_read AND is_migration)
FROM ($read_rows)
$settings") || exit 1
IFS=$'\t' read -r app_user_queries reads last_read migration_reads <<< "$summary"

# 4. Reads by caller, for whoever still uses ClickHouse. Source and query
# match the labels on LangSmith's Instance health page.
callers_query="
SELECT
    caller_source AS source,
    if(caller_query = '', 'unlabeled', caller_query) AS query,
    countIf(NOT failed) AS reads,
    countIf(failed) AS failed_reads,
    min(event_time) AS first_read,
    max(event_time) AS last_read
FROM ($read_rows)
WHERE is_read
GROUP BY source, query
ORDER BY reads + failed_reads DESC
$settings"

echo "ClickHouse reads by LangSmith user '$app_user' over the last $days days"
echo "  Replicas read:   $replicas_reachable of $replicas_expected${cluster:+ (cluster $cluster)}"
echo "  Full window in:  $replicas_covered of $replicas_reachable replicas' query_log"
if [ "$reads" != "0" ]; then
    echo "  Reads:           $reads (last: $last_read)"
else
    echo "  Reads:           0"
fi
echo "  Migration reads: $migration_reads"
echo

if [ "$reads" != "0" ] || [ "$migration_reads" != "0" ]; then
    if [ -n "$output_file" ]; then
        run_query "$callers_query" CSVWithNames > "$output_file" || exit 1
        echo "Reads by caller written to $output_file"
    else
        run_query "$callers_query" PrettyCompactMonoBlock || exit 1
    fi
    echo
fi

# 5. Verdict. Never report "no reads" when part of the data is missing.
untrusted=""
if [ "$app_user_queries" = "0" ]; then
    echo "No queries at all from '$app_user' in query_log: query logging is off for this user, or it is not the user LangSmith connects as."
    echo "Turn logging on with: ALTER USER $app_user SETTINGS log_queries = 1 (or <log_queries>1</log_queries> in its users.xml profile), then rerun after $days days."
    untrusted="true"
fi
if [ "$replicas_reachable" -lt "$replicas_expected" ]; then
    echo "Only $replicas_reachable of $replicas_expected replicas answered; reads on the others are not counted. Rerun against the missing ones."
    untrusted="true"
fi
if [ "$replicas_covered" -lt "$replicas_reachable" ]; then
    echo "query_log on some replicas only goes back to $newest_start, so this covers less than $days days. Check the query_log TTL."
    untrusted="true"
fi
if [ "$reads" != "0" ]; then
    echo "LangSmith still reads ClickHouse. Keep ClickHouse on."
    echo "Expected while ClickHouse queries are on: once Deprecated API Usage shows none, set CLICKHOUSE_QUERY_ENABLED=false in commonEnv, then rerun after $days day$([ "$days" = 1 ] || echo s)."
    exit 3
fi
if [ "$migration_reads" != "0" ]; then
    echo "The SmithDB migration still reads ClickHouse. Keep ClickHouse on until it completes."
    exit 3
fi
if [ -n "$untrusted" ]; then
    echo "Cannot confirm that LangSmith stopped reading ClickHouse. Keep ClickHouse on."
    exit 4
fi
echo "No LangSmith reads in the last $days days on every replica."
exit 0
