# You must enter the tenant id for the tenant you want to update.

# Check for required arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <postgres_url> <tenant_id> <feature_flag>"
    exit 1
fi

# Assign command-line arguments to variables
postgres_url=$1
tenant_id=$2
feature_flag=$3

#PostgreSQL query
update_query_string=$(cat <<EOF
UPDATE public.tenants SET config = jsonb_set(config, '{flags}', coalesce(config->'flags', '{}'::jsonb) || '{"$feature_flag":"true"}'::jsonb) where id='$tenant_id';
EOF
)

# Execute PostgreSQL query and save results to a file
psql "$postgres_url" -c "$update_query_string"
