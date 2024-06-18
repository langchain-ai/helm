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
UPDATE public.tenants SET display_name = 'Default', config = config || '{"is_personal": false, "max_identities": 100}' where id='00000000-0000-0000-0000-000000000000';
UPDATE public.organizations SET display_name = 'Default', is_personal = false, config = config || '{"max_identities": 100, "max_workspaces": -1}' where id=(SELECT organization_id FROM tenants WHERE id = '00000000-0000-0000-0000-000000000000');
WITH admin_user_id AS (
    SELECT id FROM public.users WHERE email = '$admin_user_email'
),
org_admin_identity_id AS (
INSERT INTO public.identities (id, organization_id, user_id, created_at, read_only, role_id, access_scope)
		VALUES(
		 '00000000-0000-0000-0000-000000000001',
		 (SELECT organization_id FROM tenants WHERE id = '00000000-0000-0000-0000-000000000000'),
		 (SELECT id FROM admin_user_id), NOW(),
		 FALSE,
		 (SELECT id FROM roles WHERE name = 'ORGANIZATION_ADMIN'),
		 'organization')
	RETURNING id
)
INSERT INTO public.identities (id, tenant_id, organization_id, user_id, created_at, read_only, role_id, access_scope, parent_identity_id)
		VALUES(
		'00000000-0000-0000-0000-000000000000',
		'00000000-0000-0000-0000-000000000000',
		(SELECT organization_id FROM tenants WHERE id = '00000000-0000-0000-0000-000000000000'),
		(SELECT id FROM admin_user_id),
		NOW(),
		FALSE,
		(SELECT id FROM roles WHERE name = 'WORKSPACE_ADMIN'),
		'workspace',
		(SELECT id FROM org_admin_identity_id)
	 );
EOF
)

# Execute PostgreSQL query and save results to a file
psql "$postgres_url" -c "$update_query_string"
