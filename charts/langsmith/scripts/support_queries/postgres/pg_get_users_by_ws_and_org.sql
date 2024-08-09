-- This query retreives a list of users by workspace and organization.
-- There will be one row per unique user-workspace combination

select 
  u.email as user_email,
  u.full_name as user_name,
  o.display_name as organization_name,
  o.id as organization_id,
  t.display_name as workspace_name,
  t.id as workspace_id
from users u 

join identities i
  on u.id = i.user_id 

join tenants t
  on i.tenant_id = t.id 

join organizations o
  on t.organization_id = o.id 
  and NOT o.is_personal