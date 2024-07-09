#!/bin/sh

## Function Definitions

# Function to generate a fake UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        echo "uuidgen command not found. Exiting..."
        exit 1
    fi
}

# Function to execute a select statement against PostgreSQL
execute_pg_select(){
    local query_string="$1"
    local result=$(psql $postgres_url -t -c "$query_string" -A 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error executing select statement: $result"
        return 1
    fi
    echo "$result"
}

# Function for deleting from a ClickHouse table
delete_from_ch(){
    local table="$1"
    local run_column="$2"
    local row_count=""

    local select_command_template="curl \
        --fail \
        -sS \
        --user '$ch_user:$ch_passwd' \
        --data-binary \"select count(1) from $ch_database.$table where tenant_id = '$workspace_id' \" \
        $ch_protocol://$ch_host:$ch_port/?wait_end_of_query=1"

    local delete_command_template="curl \
        -vvv \
        --user '$ch_user:$ch_passwd' \
        --data-binary \"DELETE from $ch_database.$table where tenant_id = '$workspace_id' \" \
        $ch_protocol://$ch_host:$ch_port?wait_end_of_query=0"

    echo "Testing select of runs for Workspace ID $workspace_id from $table..."

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
        echo "Deleting $row_count rows from Workspace ID $workspace_id in $table..."
        SECONDS=0
        sh -c "$delete_command_template"
        echo "DELETE FROM query completed in $SECONDS seconds."

    ## Otherwise skip...
    else
        echo "No rows to delete in $table from Workspace ID $workspace_id!"
    fi
}

# Function for deleting from PostgreSQL
delete_from_pg(){
    local query_string="$1"
    psql $postgres_url -c "$query_string"
}

## Argument Parsing
clickhouse_url=""
postgres_url=""
workspace_id=""
force=""
ssl=""
debug=""
sync=""

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
        --workspace_id)
            if [ -n "$2" ]; then
                workspace_id="$2"
                shift 2
            else
                echo "Error: --workspace_id requires a non-empty argument."
                exit 1
            fi
            ;;
        *)
            if [ -z "$clickhouse_url" ]; then
                clickhouse_url="$1"
            elif [ -z "$postgres_url" ]; then
                postgres_url="$1"
            else
                echo "Unknown argument: $1"
                echo "Usage: $0 <clickhouse_url> <postgres_url> --workspace_id <workspace_id> [--force] [--ssl] [--debug] [--sync]"
                echo "Example: $0 clickhouse://username:password@host:port/database postgres://username:password@host:port/database --workspace_id $(generate_uuid) --force --ssl --debug --sync"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$clickhouse_url" ] || [ -z "$postgres_url" ] || [ -z "$workspace_id" ]; then
    fake_workspace_id=$(generate_uuid)
    echo "Incorrect command syntax."
    echo "Usage: $0 <clickhouse_url> <postgres_url> --workspace_id <workspace_id> [--force] [--ssl] [--debug] [--sync]"
    echo
    echo "Example: $0 clickhouse://username:password@host:port/database postgres://username:password@host:port/database --workspace_id $fake_workspace_id --force --ssl --debug --sync"
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

## Parse the PostgreSQL URL
pg_user=""
pg_passwd=""
pg_host=""
pg_port=""
pg_database=""

if [[ $postgres_url =~ ^postgres://([^:]+):([^@]+)@([^:]+):([0-9]+)/([^/]+)$ ]]; then
    pg_user="${BASH_REMATCH[1]}"
    pg_passwd="${BASH_REMATCH[2]}"
    pg_host="${BASH_REMATCH[3]}"
    pg_port="${BASH_REMATCH[4]}"
    pg_database="${BASH_REMATCH[5]}"
else
    echo "Invalid PostgreSQL URL format. Exiting."
    echo "Expected format: postgres://username:password@host:port/database"
    exit 1
fi

# Set ClickHouse protocol based on --ssl flag
if [ "$ssl" = "--ssl" ]; then
    ch_protocol="https"
else
    ch_protocol="http"
fi

## Check the Workspace ID to make sure it's a real UUID. Exit if not.
if [[ $workspace_id =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
    echo "Workspace ID $workspace_id is valid. Continuing..."
else
    echo "Workspace ID $workspace_id is not a valid UUID. Exiting"
    exit 1
fi

## Check if the workspace ID exists in PostgreSQL
workspace_check_query="select id from tenants where id IN ('$workspace_id')"
workspace_id_in_pg=$(execute_pg_select "$workspace_check_query")

if [ $? -ne 0 ]; then
    echo "Error executing PostgreSQL query. Exiting..."
    exit 1
elif [ -z "$workspace_id_in_pg" ]; then
    echo "Workspace ID $workspace_id not found in tenants table."
    if [ "$force" != "--force" ]; then
        echo "Use --force if you still want to attempt to delete anyway. Exiting..."
        exit 1
    else
        echo "Respecting the --force flag and continuing..."

        echo "Issuing SQL commands even though Workspace ID was not found in tenants table..."

    fi
else
    echo "Found workspace_id $workspace_id in PostgreSQL with id $workspace_id_in_pg. Continuing..."
fi

## Templates

# Query template for PostgreSQL deletion
pg_delete_tenant=$(cat <<EOF
DELETE FROM tenants
WHERE id = '$workspace_id'
EOF
)

## Find runs with this trace ID in the main runs table.
## If query returns no results, exit unless the `--force` parameter is passed in
table="runs"
run_column="id"

command_template="curl \
    -s \
    --fail \
    --user '$ch_user:$ch_passwd' \
    --data-binary \"SELECT distinct id from $ch_database.$table where (is_root, tenant_id, session_id, $run_column) IN (select is_root, tenant_id, session_id, id as $run_column from $ch_database.runs where tenant_id = '$workspace_id' and is_root)\" \
    $ch_protocol://$ch_host:$ch_port"

check_traces=$(sh -c "$command_template")

if [ -n "$check_traces" ]; then
    echo "Found Workspace ID $workspace_id, continuing..."
else
    echo "Could not find any traces for Workspace ID $workspace_id."
    if [ "$force" != "--force" ]; then 
        echo "Use --force if you still want to attempt to delete anyway. Exiting..."
        exit 1
    else
        echo "Respecting the --force flag and continuing..."

        echo "Issuing SQL commands even though the Workspace ID was not found in current runs table..."

    fi 
fi

## Delete from ClickHouse tables
if [ "$sync" = "--sync" ]; then
    delete_from_ch runs_token_counts id
    delete_from_ch runs_tags run_id
    delete_from_ch runs_run_type id
    delete_from_ch runs_run_id_v2 id
    delete_from_ch runs_reference_example_id id
    delete_from_ch runs_trace_id id
    delete_from_ch runs_metadata_kv run_id
    delete_from_ch feedbacks_rmt_id run_id
    delete_from_ch feedbacks_rmt run_id
    delete_from_ch feedbacks run_id
    delete_from_ch runs id
else
    delete_from_ch runs_token_counts id &
    delete_from_ch runs_tags run_id &
    delete_from_ch runs_run_type id &
    delete_from_ch runs_run_id_v2 id &
    delete_from_ch runs_reference_example_id id &
    delete_from_ch runs_trace_id id &
    delete_from_ch runs_metadata_kv run_id &
    delete_from_ch feedbacks_rmt_id run_id &
    delete_from_ch feedbacks_rmt run_id &
    delete_from_ch feedbacks run_id &
    delete_from_ch runs id &
fi

## Delete from PostgreSQL tables
if [ "$sync" = "--sync" ]; then
    delete_from_pg "$pg_delete_tenant" "$workspace_id"
else
    delete_from_pg "$pg_delete_tenant" "$workspace_id" &
fi

## Wait for all background processes to complete unless --sync flag is present
if [ "$sync" != "--sync" ]; then
    wait
fi

echo "Done!"
