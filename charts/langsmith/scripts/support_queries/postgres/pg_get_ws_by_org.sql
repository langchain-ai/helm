-- This query pulls a list of workspaces by organization
-- Personal orgs if they exist are excluded

select distinct
    ws.organization_id as organization_id,
    o.display_name as organization_name,
    ws.id as workspace_id,
    ws.display_name as workspace_name
from tenants ws

join organizations o 
  on ws.organization_id = o.id

where not o.is_personal
