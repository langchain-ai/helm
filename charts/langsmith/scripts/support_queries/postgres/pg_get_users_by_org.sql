-- This query retreives a list of users by organization.
-- There will be one row per unique user-organization combination

select distinct
  u.email as user_email,
  u.full_name as user_name,
  o.display_name as organization_name,
  o.id as organization_id
from users u 

join identities i
  on u.id = i.user_id 

join organizations o
  on i.organization_id = o.id 
  and not o.is_personal
  and i.tenant_id is null