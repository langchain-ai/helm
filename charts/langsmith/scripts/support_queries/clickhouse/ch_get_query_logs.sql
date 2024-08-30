-- This query returns all queries to Clickhouse 
-- from the last 1 hour

select * 
from clusterAllReplicas(default,system.query_log) 
where event_time >= now() - interval 1 hour
    and event_date >= toDate(now() - interval 1 hour)
    and query ilike '-- %' 
order by event_time desc 
