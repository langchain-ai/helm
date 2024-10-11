-- Gets a count of experiments and count of traces in experiments
-- by workspace ID and name

select 
    p.tenant_id as workspace_id,
    t.display_name as workspace_name,
    count(case when reference_dataset_id is not null then 1 end) as num_experiments,
    sum(case when reference_dataset_id is not null then trace_count else 0 end) as num_traces
from tracer_session p

join tenants t
on p.tenant_id = t.id

join trace_count_transactions tr
on tr.tenant_id = t.id
and tr.session_id = p.id 

group by workspace_id, workspace_name
having number_experiments > 0