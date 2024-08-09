-- This query returns a count of datasets for each unique workspace

select 
    organizations.id as org_id,
    organizations.display_name as org_name,
    tenant_id as workspace_id,
    tenants.display_name as workspace_name,
    count(distinct dataset.id) as dataset_count
from dataset

join tenants 
    on dataset.tenant_id = tenants.id 

join organizations
    on tenants.organization_id = organizations.id 

group by
    org_id,
    org_name,
    workspace_id,
    workspace_name

order BY
    prompt_count desc 