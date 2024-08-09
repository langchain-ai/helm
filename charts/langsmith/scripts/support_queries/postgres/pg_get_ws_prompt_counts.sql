-- This query returns a count of hub prompts for each unique workspace

select 
    organizations.id as org_id,
    organizations.display_name as org_name,
    tenant_id as workspace_id,
    tenants.display_name as workspace_name,
    count(distinct hub_repos.id) as prompt_count, 
    count(distinct hub_commits.id) as revision_count 
from hub_repos

join tenants 
    on hub_repos.tenant_id = tenants.id 

join organizations
    on tenants.organization_id = organizations.id 

join hub_commits 
    on hub_repos.id = hub_commits.repo_id 

group by
    org_id,
    org_name,
    workspace_id,
    workspace_name

order BY
    prompt_count desc 