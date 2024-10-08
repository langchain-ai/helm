-- This query retrieves the count of daily traces by workspace ID
-- This count includes since-deleted traces

select toStartOfInterval(inserted_at, interval 1 day) as ts, 
    tenant_id as workspace_id, 
    count(distinct id) as trace_count
from default.runs_history 
where is_root = 1
group by ts, tenant_id
order by ts, tenant_id