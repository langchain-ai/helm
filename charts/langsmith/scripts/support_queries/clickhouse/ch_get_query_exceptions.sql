-- This query returns all queries to Clickhouse with exceptions
-- from the last 7 days

select * 
from clusterAllReplicas(default,system.query_log) 
where exception != '' 
    and event_time >= now() - interval 7 day
    and event_date >= toDate(now() - interval 7 day)
    and query ilike '-- %' 
order by event_time desc 
