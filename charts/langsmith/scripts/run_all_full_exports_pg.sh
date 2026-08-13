#!/bin/sh

# Runs every pg_usage_*_full_export.sql support query against a self-hosted
# LangSmith Postgres in one shot and writes one CSV per dataset into an output
# directory, then (if tar is available) bundles them into a single .tar.gz for
# easy transfer. This wraps run_support_query_pg.sh so DB URL parsing, psql
# flags, and PGPASSWORD handling stay in one place.
#
# Only the read-only *_full_export.sql scripts are run — never the
# *_backfill_export.sql / *_backfill_update.sql scripts (those mutate rows) nor
# the non-usage pg_get_* support queries.

print_usage_and_exit() {
    echo "Error: $1"
    echo "Usage: $0 <postgres_url> [--output-dir <dir>] [--debug]"
    echo "Example: $0 postgres://username:password@host:port/database --output-dir ./langsmith-usage-export"
    echo "Note: <postgres_url> must be postgres://user:password@host:port/database (explicit port, no query string), same as run_support_query_pg.sh."
    exit 1
}

postgres_url=""
output_dir="langsmith-usage-export"
debug=""

while [ $# -gt 0 ]; do
    case "$1" in
        --output-dir)
            [ -n "$2" ] || print_usage_and_exit "Missing value for --output-dir"
            output_dir="$2"
            shift 2
            ;;
        --debug)
            debug="--debug"
            shift
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

script_dir=$(dirname -- "$0")
script_dir=$(cd -- "$script_dir" && pwd)
runner="$script_dir/run_support_query_pg.sh"
query_dir="$script_dir/support_queries/postgres"

[ -f "$runner" ] || print_usage_and_exit "runner not found: $runner"
[ -d "$query_dir" ] || print_usage_and_exit "query dir not found: $query_dir"

mkdir -p "$output_dir" || print_usage_and_exit "could not create output dir: $output_dir"

# run_support_query_pg.sh uses bash arrays / [[ =~ ]], so invoke it with bash
# explicitly rather than relying on its shebang.
runner_shell="sh"
if command -v bash >/dev/null 2>&1; then
    runner_shell="bash"
fi

count=0
failed=0
for sql in "$query_dir"/pg_usage_*_full_export.sql; do
    [ -e "$sql" ] || continue # no-match guard when the glob matches nothing
    name=$(basename "$sql" .sql)
    label=${name#pg_usage_}
    label=${label%_full_export}
    out="$output_dir/${label}.csv"
    echo "==> exporting ${label} -> ${out}"
    if "$runner_shell" "$runner" "$postgres_url" $debug --input "$sql" --output "$out"; then
        count=$((count + 1))
    else
        echo "!! export failed for ${label} (continuing)"
        failed=$((failed + 1))
    fi
done

if [ "$count" -eq 0 ] && [ "$failed" -eq 0 ]; then
    print_usage_and_exit "no pg_usage_*_full_export.sql scripts found in $query_dir"
fi

# Bundle the CSVs into one archive for easy transfer, when tar is available.
if command -v tar >/dev/null 2>&1; then
    archive="${output_dir%/}.tar.gz"
    parent=$(dirname -- "$output_dir")
    base=$(basename -- "$output_dir")
    if tar -czf "$archive" -C "$parent" "$base"; then
        echo "Bundled ${count} CSV(s) into ${archive}"
    fi
fi

echo "Done. ${count} export(s) written to ${output_dir}/ (${failed} failed)."
[ "$failed" -eq 0 ] || exit 1
