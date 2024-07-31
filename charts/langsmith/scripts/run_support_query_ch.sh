#!/bin/sh

# Function to print usage information and exit with a nonzero status
print_usage_and_exit() {
    echo "Error: $1"
    echo "Usage: $0 <clickhouse_url> [--debug] [--ssl] [--output <path/to/file.csv>] [--input <path/to/file.sql>]"
    echo "Example: $0 clickhouse://username:password@host:port/database [--debug] [--ssl] [--output path/to/file.csv] [--input path/to/file.sql]"
    exit 1
}

# Argument Parsing
clickhouse_url=""
debug=""
ssl=""
output_file=""
input_file=""

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
        --output)
            output_file="$2"
            shift 2
            ;;
        --input)
            input_file="$2"
            shift 2
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

if [ -z "$input_file" ]; then
    print_usage_and_exit "Input SQL file is required."
fi

if [ ! -f "$input_file" ]; then
    print_usage_and_exit "Input file not found: $input_file"
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

# Read the query from the input file
metrics_query_string=$(cat "$input_file")

# Determine curl options based on debug flag
if [ "$debug" = "--debug" ]; then
    curl_opts="-vvv"
else
    curl_opts="-s --fail"
fi

# Execute the query and output to the specified CSV file or stdout
if [ -n "$output_file" ]; then
    curl $curl_opts --user "$ch_user:$ch_passwd" --data-binary "$metrics_query_string" "$ch_protocol://$ch_host:$ch_port/?database=$ch_database" > "$output_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to ClickHouse."
        exit 1
    fi
    echo "Query results have been successfully written to $output_file"
else
    curl $curl_opts --user "$ch_user:$ch_passwd" --data-binary "$metrics_query_string" "$ch_protocol://$ch_host:$ch_port/?database=$ch_database"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to ClickHouse."
        exit 1
    fi
fi
