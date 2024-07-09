#!/bin/sh

## Function Definitions

# Function to generate a fake UUID in lowercase
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        echo "uuidgen command not found. Exiting..."
        exit 1
    fi
}

# Function for deleting from a ClickHouse table
delete_from_ch() {
    local table="$1"
    local run_column="$2"
    local trace_ids="$3"
    local row_count=""
    local curl_flags="-sS --fail"

    [ "$debug" = "--debug" ] && curl_flags="$curl_flags -vvv"

    # Modify the trace_ids to properly quote each ID
    local quoted_trace_ids=$(echo "$trace_ids" | awk '{ for (i=1; i<=NF; i++) printf "'\''%s'\''%s", $i, (i==NF ? "\n" : ",") }')

    local select_command_template="curl \
        $curl_flags \
        --user '$ch_user:$ch_passwd' \
        --data-binary \"select count(1) from $ch_database.$table where (tenant_id, $run_column) IN (select tenant_id, id from $ch_database.runs where trace_id IN ($quoted_trace_ids)) \" \
        $ch_protocol://$ch_host:$ch_port/?wait_end_of_query=1"

    local delete_command_template="curl \
        $curl_flags \
        --user '$ch_user:$ch_passwd' \
        --data-binary \"DELETE from $ch_database.$table where (tenant_id, $run_column) IN (select tenant_id, id from $ch_database.runs where trace_id IN ($quoted_trace_ids)) \" \
        $ch_protocol://$ch_host:$ch_port?wait_end_of_query=0"

    echo "Testing select of runs for trace IDs $trace_ids from $table..."

    ## Get the count of rows to delete
    ## This both tests the select statement AND tells us whether we need to execute the DELETE FROM command
    local row_count=$(sh -c "$select_command_template")

    ## If Row Count is empty that means Clickhouse errored out
    if [ -z "$row_count" ]; then
        echo "Error returned from ClickHouse on select statement. Exiting..." >&2
        exit 1
    ## If Row Count is not 0 then we should be good to issue the delete
    elif [ "$row_count" -gt 0 ]; then
        echo "Success! Found $row_count rows in $table..."
        echo "Deleting $row_count rows from trace IDs $trace_ids in $table..."
        SECONDS=0
        sh -c "$delete_command_template"
        echo "DELETE FROM query completed in $SECONDS seconds."
    ## Otherwise, if row_count is 0 and --force flag is set, issue the delete
    elif [ "$row_count" -eq 0 ] && [ "$force" = "--force" ]; then
        echo "No rows found in $table, but --force flag is set. Deleting anyway..."
        SECONDS=0
        sh -c "$delete_command_template"
        echo "DELETE FROM query completed in $SECONDS seconds."
    ## Otherwise skip...
    else
        echo "No rows to delete in $table for trace IDs $trace_ids!"
    fi
}

## Function to read trace IDs from a file
read_trace_ids_from_file() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        cat "$file_path" | tr '[:upper:]' '[:lower:]'
    else
        echo "File not found: $file_path"
        exit 1
    fi
}

## Argument Parsing
clickhouse_url=""
trace_id=""
force=""
ssl=""
debug=""
sync=""
file=""

while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            force="--force"
            shift
            ;;
        --ssl)
            ssl="--ssl"
            shift
            ;;
        --debug)
            debug="--debug"
            shift
            ;;
        --sync)
            sync="--sync"
            shift
            ;;
        --file)
            file="$2"
            shift 2
            ;;
        --trace_id)
            trace_id="$2"
            shift 2
            ;;
        *)
            if [ -z "$clickhouse_url" ]; then
                clickhouse_url="$1"
                shift
            else
                echo "Unknown argument: $1"
                echo "Usage: $0 <clickhouse_url> --trace_id <trace_id> [--force] [--ssl] [--debug] [--sync] | --file path/to/file.txt [--force] [--ssl] [--debug] [--sync]"
                echo "Example 1: $0 clickhouse://username:password@host:port/database --trace_id $(generate_uuid) [--force] [--ssl] [--debug] [--sync]"
                echo "Example 2: $0 clickhouse://username:password@host:port/database --file path/to/file.txt [--force] [--ssl] [--debug] [--sync]"
                exit 1
            fi
            ;;
    esac
done

if [ -z "$clickhouse_url" ] || ([ -z "$trace_id" ] && [ -z "$file" ]) || ([ -n "$trace_id" ] && [ -n "$file" ]); then
    fake_trace_id=$(generate_uuid)
    echo "Incorrect command syntax."
    echo "Usage: $0 <clickhouse_url> --trace_id <trace_id> [--force] [--ssl] [--debug] [--sync] | --file path/to/file.txt [--force] [--ssl] [--debug] [--sync]"
    echo
    echo "Example 1: $0 clickhouse://username:password@host:port/database --trace_id $fake_trace_id [--force] [--ssl] [--debug] [--sync]"
    echo "Example 2: $0 clickhouse://username:password@host:port/database --file path/to/file.txt [--force] [--ssl] [--debug] [--sync]"
    exit 1
fi

## Debugging flags
## Enable only if needed to debug this script
if [ "$debug" = "--debug" ]; then
    set -x -e
fi

## Parse the ClickHouse URL
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
    echo "Invalid ClickHouse URL format. Exiting."
    echo "Expected format: clickhouse://username:password@host:port/database"
    exit 1
fi

# Set ClickHouse protocol based on --ssl flag
if [ "$ssl" = "--ssl" ]; then
    ch_protocol="https"
else
    ch_protocol="http"
fi

trace_ids=""
if [ -n "$file" ]; then
    trace_ids=$(read_trace_ids_from_file "$file" | tr '\n' ',' | sed 's/,$//')
else
    trace_ids="$trace_id"
fi

## Check the trace IDs to make sure they are real UUIDs. Exit if not.
for id in $(echo "$trace_ids" | tr ',' ' '); do
    if ! [[ $id =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
        echo "Trace ID $id is not a valid UUID. Exiting"
        exit 1
    fi
done

## Find runs with these trace IDs in the main runs table.
## If query returns no results, exit unless the `--force` parameter is passed in
table="runs"
run_column="id"

# Modify trace_ids to properly quote each ID for the IN clause
quoted_trace_ids=$(echo "$trace_ids" | awk -F, '{ for (i=1; i<=NF; i++) printf "'\''%s'\''%s", $i, (i==NF ? "\n" : ",") }')

command_template="curl \
    -s \
    --fail \
    --user '$ch_user:$ch_passwd' \
    --data-binary \"SELECT distinct id from $ch_database.$table where (is_root, trace_id, session_id, $run_column) IN (select is_root, trace_id, session_id, id as $run_column from $ch_database.runs where trace_id IN ($quoted_trace_ids) and is_root)\" \
    $ch_protocol://$ch_host:$ch_port"

check_traces=$(sh -c "$command_template")

if [ -n "$check_traces" ]; then
    echo "Found trace IDs $trace_ids, continuing..."
else
    echo "Could not find trace IDs $trace_ids."
    if [ "$force" != "--force" ]; then 
        echo "Use --force if you still want to attempt to delete anyway. Exiting..."
        exit 1
    else
        echo "Respecting the --force flag and continuing..."

        echo "Issuing SQL commands even though trace IDs were not found in current runs table..."

    fi 
fi

## Split the trace IDs into batches of up to 100 IDs
batch_size=100
trace_id_array=($(echo "$trace_ids" | tr ',' ' '))

## Delete from ClickHouse tables in batches
## Delete from ClickHouse tables in batches
for ((i=0; i<${#trace_id_array[@]}; i+=batch_size)); do
    trace_id_batch="${trace_id_array[@]:i:batch_size}"
    trace_id_batch=$(echo "$trace_id_batch" | awk -F, '{ for (i=1; i<=NF; i++) printf "%s%s", $i, (i==NF ? "\n" : ",") }')

    if [ "$sync" = "--sync" ]; then
        delete_from_ch runs_token_counts id "$trace_id_batch"
        delete_from_ch runs_tags run_id "$trace_id_batch"
        delete_from_ch runs_run_type id "$trace_id_batch"
        delete_from_ch runs_run_id_v2 id "$trace_id_batch"
        delete_from_ch runs_reference_example_id id "$trace_id_batch"
        delete_from_ch runs_trace_id id "$trace_id_batch"
        delete_from_ch runs_metadata_kv run_id "$trace_id_batch"
        delete_from_ch feedbacks_rmt_id run_id "$trace_id_batch"
        delete_from_ch feedbacks_rmt run_id "$trace_id_batch"
        delete_from_ch feedbacks run_id "$trace_id_batch"
        delete_from_ch runs id "$trace_id_batch"
    else
        delete_from_ch runs_token_counts id "$trace_id_batch" &
        delete_from_ch runs_tags run_id "$trace_id_batch" &
        delete_from_ch runs_run_type id "$trace_id_batch" &
        delete_from_ch runs_run_id_v2 id "$trace_id_batch" &
        delete_from_ch runs_reference_example_id id "$trace_id_batch" &
        delete_from_ch runs_trace_id id "$trace_id_batch" &
        delete_from_ch runs_metadata_kv run_id "$trace_id_batch" &
        delete_from_ch feedbacks_rmt_id run_id "$trace_id_batch" &
        delete_from_ch feedbacks_rmt run_id "$trace_id_batch" &
        delete_from_ch feedbacks run_id "$trace_id_batch" &
        delete_from_ch runs id "$trace_id_batch" &
    fi
done

## Wait for all background processes to complete unless --sync flag is present
if [ "$sync" != "--sync" ]; then
    wait
fi

echo "Done!"
