#!/bin/sh

# Function to print usage information and exit with a nonzero status
print_usage_and_exit() {
    echo "Error: $1"
    echo "Usage: $0 <clickhouse_url> [--debug] [--ssl] [--days <number_of_days>] [--interval <number_of_hours>] [--output <path/to/file.csv>] [--cluster]"
    echo "Example: $0 clickhouse://username:password@host:port/database [--debug] [--ssl] [--days 14] [--interval 1] [--output path/to/file.csv] [--cluster]"
    exit 1
}

# Argument Parsing
clickhouse_url=""
debug=""
ssl=""
days=14
interval=1
output_file=""
cluster=""
cluster_flag_passed=false

while [ $# -gt 0 ]; do
    case "$1" in
        --debug)
            debug="--debug"
            shift
            ;;
        --ssl)
            ssl="--ssl"
            shift
            ;;
        --days)
            days="$2"
            shift 2
            ;;
        --interval)
            interval="$2"
            shift 2
            ;;
        --output)
            output_file="$2"
            shift 2
            ;;
        --cluster)
            cluster="true"
            cluster_flag_passed=true
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

# Enable debugging if the --debug flag is set
if [ "$debug" = "--debug" ]; then
    set -x -e
fi

# Parse the ClickHouse URL
ch_user=""
ch_passwd=""
ch_host=""
ch_port=""
ch_database=""

if [[ $clickhouse_url =~ ^clickhouse://([^:]+):([^@]+)@([^:]+):([0-9]+)/([^/]+)$ ]]; then
    ch_user="${BASH_REMATCH[1]}"
    ch_passwd="${BASH_REMATCH[2]}"
    ch_host="${BASH_REMATCH[3]}"
    ch_port="${BASH_REMATCH[4]}"
    ch_database="${BASH_REMATCH[5]}"
else
    print_usage_and_exit "Invalid ClickHouse URL format. Expected format: clickhouse://username:password@host:port/database"
fi

# Set ClickHouse protocol based on --ssl flag
if [ "$ssl" = "--ssl" ]; then
    ch_protocol="https"
else
    ch_protocol="http"
fi

# Set default value for --cluster based on hostname if not explicitly passed
if [ "$cluster_flag_passed" = false ]; then
    if [ "$ch_host" = "127.0.0.1" ] || [ "$ch_host" = "localhost" ]; then
        cluster="false"
    elif [[ "$ch_host" == *"clickhouse.cloud"* ]]; then
        cluster="true"
    else
        cluster="false"
    fi
fi

# Create the metrics query string based on the --cluster flag and interval
if [ "$cluster" = "true" ]; then
    from_clause="from clusterAllReplicas(default, merge('system', '^query_log'))"
else
    from_clause="from merge('system', '^query_log')"
fi

metrics_query_string=$(cat <<EOF
select 
    toStartOfInterval(event_time, interval $interval hour) as ts,
    replaceOne(left(query,position(query,char(10))-1),'-- ','') as ch_query_type,
    sum(case when type = 'QueryFinish' then 1 else 0 end) as query_count_completed,
    sum(case when type = 'ExceptionBeforeStart' then 1 else 0 end) as query_count_exception_before_start,
    sum(case when type = 'ExceptionWhileProcessing' then 1 else 0 end) as query_count_exception_while_processing,
    avg(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_avg_seconds,
    sum(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_total_seconds,
    max(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_max_seconds,
    avg(ProfileEvents['SelectedBytes']::double) as query_avg_bytes_scanned,
    sum(ProfileEvents['SelectedBytes']::double) as query_total_bytes_scanned,
    max(ProfileEvents['SelectedBytes']::double) as query_max_bytes_scanned,
    avg(ProfileEvents['UserTimeMicroseconds']::double + ProfileEvents['SystemTimeMicroseconds']::double)/1000000.0 AS query_avgCPU,
    sum(ProfileEvents['UserTimeMicroseconds']::double + ProfileEvents['SystemTimeMicroseconds']::double)/1000000.0 AS query_totalCPU,
    max(ProfileEvents['UserTimeMicroseconds']::double + ProfileEvents['SystemTimeMicroseconds']::double)/1000000.0 AS query_maxCPU,
    avg(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_avg_memory_bytes,
    sum(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_total_memory_bytes,
    max(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_max_memory_bytes

$from_clause
where event_date >= now() - interval $days day 
    and left(query,2) = '--'
    and user = 'default'
    and type != 'QueryStart'

group by ts, ch_query_type
order by ts, ch_query_type

settings 
max_threads=5, 
enable_filesystem_cache=true, 
skip_unavailable_shards=true, 
read_from_filesystem_cache_if_exists_otherwise_bypass_cache=false
FORMAT CSV
EOF
)

# Determine curl options based on debug flag
if [ "$debug" = "--debug" ]; then
    curl_opts="-vvv"
else
    curl_opts="-s"
fi

# Execute the query and output to the specified CSV file or stdout
if [ -n "$output_file" ]; then
    curl $curl_opts --fail --user "$ch_user:$ch_passwd" --data-binary "$metrics_query_string" "$ch_protocol://$ch_host:$ch_port/?database=$ch_database" > "$output_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to ClickHouse."
        exit 1
    fi
    echo "Metrics have been successfully written to $output_file"
else
    curl $curl_opts --fail --user "$ch_user:$ch_passwd" --data-binary "$metrics_query_string" "$ch_protocol://$ch_host:$ch_port/?database=$ch_database"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to ClickHouse."
        exit 1
    fi
fi
