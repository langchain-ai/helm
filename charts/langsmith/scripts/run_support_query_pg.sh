#!/bin/sh

# Function to print usage information and exit with a nonzero status
print_usage_and_exit() {
    echo "Error: $1"
    echo "Usage: $0 <postgres_url> [--debug] [--output <path/to/file.csv>] [--input <path/to/file.sql>] [-v var=value]..."
    echo "Example: $0 postgres://username:password@host:port/database [--debug] [--output path/to/file.csv] [--input path/to/file.sql] [-v backfill_id=\"id\" -v other_var=\"other-value\"]"
    echo "Note: The -v flag is used to pass variables to queries that support them.  String values should NOT be wrapped in single quotes, as the scripts will do that for you."
    exit 1
}

# Argument Parsing
postgres_url=""
debug=""
output_file=""
input_file=""
psql_vars=()

while [ $# -gt 0 ]; do
    case "$1" in
        --debug)
            debug="--debug"
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
        -v)
            if [ -z "$2" ]; then
                print_usage_and_exit "Missing value for -v flag"
            fi
            var_name="${2%%=*}"
            var_value="${2#*=}"
            psql_vars+=(-v "$var_name=$var_value")
            shift 2
            ;;
        *)
            if [ -z "$postgres_url" ]; then
                postgres_url="$1"
                shift
            else
                print_usage_and_exit "Unknown argument: $1"
            fi
            ;;
    esac
done

if [ -z "$postgres_url" ]; then
    print_usage_and_exit "PostgreSQL URL is required."
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

# Parse the PostgreSQL URL
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
    print_usage_and_exit "Invalid PostgreSQL URL format. Expected format: postgres://username:password@host:port/database"
fi

# Determine psql options based on debug flag
if [ "$debug" = "--debug" ]; then
    psql_opts="-h $pg_host -p $pg_port -U $pg_user -d $pg_database -A -F ',' --csv"
else
    psql_opts="-h $pg_host -p $pg_port -U $pg_user -d $pg_database -A -F ',' --csv -q"
fi

# Execute the query and output to the specified CSV file or stdout
export PGPASSWORD="$pg_passwd"
if [ -n "$output_file" ]; then
    psql $psql_opts "${psql_vars[@]}" -f "$input_file" > "$output_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to execute query on PostgreSQL."
        exit 1
    fi
    echo "Metrics have been successfully written to $output_file"
else
    psql $psql_opts "${psql_vars[@]}" -f "$input_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to execute query on PostgreSQL."
        exit 1
    fi
fi
