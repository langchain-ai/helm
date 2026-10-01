# You must enter the org id for the org you want to update

# Check for required arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <postgres_url> <organization_id> <feature_flag>"
    exit 1
fi

# Assign command-line arguments to variables
postgres_url=$1
organization_id=$2
feature_flag=$3

#PostgreSQL query
update_query_string=$(cat <<'EOF'
UPDATE organizations SET config = jsonb_set(config, '{flags}', coalesce(config->'flags', '{}'::jsonb) || jsonb_build_object(:'feature_flag', true)) where id = :'organization_id';
EOF
)

# Execute PostgreSQL query and save results to a file
psql "$postgres_url" -v feature_flag="$feature_flag" -v organization_id="$organization_id" -c "$update_query_string"
