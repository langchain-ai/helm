-- This query retreives a list of users and the count of 
-- organizations and workspaces they are a member of
-- There will be one row per unique user

select 
  u.email as user_email,
  u.full_name as user_name,
  count(distinct o.id) as org_count,
  count(distinct t.id) as workspace_count
from users u 

join identities i
  on u.id = i.user_id 

join tenants t
  on i.tenant_id = t.id 

join organizations o
  on t.organization_id = o.id 
  and NOT o.is_personal

group by
  user_email,
  user_name