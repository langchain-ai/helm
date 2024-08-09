-- This query retrieves the count of monthly traces by workspace ID
-- This count excludes deleted traces

select toStartOfInterval(inserted_at, interval 1 month) as ts, 
    tenant_id as workspace_id, 
    count(distinct id) as trace_count
from default.runs 
where is_root = 1
group by ts, tenant_id
order by ts, tenant_id