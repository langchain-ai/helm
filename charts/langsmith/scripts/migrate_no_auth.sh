# You must pick a user to be the owner of the migrated tenant.

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <postgres_url> <admin_user_email>"
    exit 1
fi

# Assign command-line arguments to variables
postgres_url=$1
admin_user_email=$2

#PostgreSQL query
update_query_string=$(cat <<EOF
UPDATE public.tenants SET display_name = 'Default', config = config || '{"is_personal": false, "max_identities": 5}' where id='00000000-0000-0000-0000-000000000000';
WITH admin_user_id AS (
    SELECT id FROM public.users WHERE email = '$admin_user_email'
)
INSERT INTO public.identities(id, tenant_id, user_id, created_at, read_only)
VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', (SELECT id FROM admin_user_id), NOW(), false);
EOF
)

# Execute PostgreSQL query and save results to a file
psql "$postgres_url" -c "$update_query_string"
