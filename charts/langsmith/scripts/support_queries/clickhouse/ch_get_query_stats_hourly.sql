-- This query will return hourly statistics for all LangSmith-driven queries
-- in the last 7 days, cut by query type
-- 
-- Each row includes the unique exceptions for that hour (if any) and the full
-- query text of the longest running query

select
    toStartOfInterval(query_start_time, interval 1 hour) as ts,
    replaceOne(left(query,position(query,char(10))-1),'-- ','') as ch_query_type,

    sum(case when type = 'QueryFinish' then 1 else 0 end) as query_count_completed,
    sum(case when type = 'ExceptionBeforeStart' then 1 else 0 end) as query_count_exception_before_start,
    sum(case when type = 'ExceptionWhileProcessing' then 1 else 0 end) as query_count_exception_while_processing,

    avg(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_avg_seconds,
    sum(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_total_seconds,
    max(case when type != 'ExceptionBeforeStart' then query_duration_ms end)/1000.0 as query_max_seconds,

    avg(read_bytes) as query_avg_bytes_scanned,
    sum(read_bytes) as query_total_bytes_scanned,
    max(read_bytes) as query_max_bytes_scanned,

    avg(read_rows) as query_avg_rows_scanned,
    sum(read_rows) as query_total_rows_scanned,
    max(read_rows) as query_max_rows_scanned,

    avg(ProfileEvents['ProfileEvent_OSCPUVirtualTimeMicroseconds']::double)/1000000.0 AS query_avgCPU,
    sum(ProfileEvents['ProfileEvent_OSCPUVirtualTimeMicroseconds']::double)/1000000.0 AS query_totalCPU,
    max(ProfileEvents['ProfileEvent_OSCPUVirtualTimeMicroseconds']::double)/1000000.0 AS query_maxCPU,

    avg(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_avg_memory_bytes,
    sum(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_total_memory_bytes,
    max(case when type != 'ExceptionBeforeStart' then memory_usage end) as query_max_memory_bytes,

    argMax(query,query_duration_ms) as longest_running_query,
    array_agg(distinct case when type::String ilike '%Exception%' then exception end) as unique_exceptions

from clusterAllReplicas(default, merge('system', '^query_log'))

where 
    left(query,2) = '--'
    and user IN ('default','langsmith')
    and event_date >= toDate(now() - interval 7 day)
    and event_time >= toDate(now() - interval 7 day)
    and type != 'QueryStart'
    and databases[1] = 'default'
    and length(databases) = 1

group by ts, ch_query_type
order by ts desc, query_avg_seconds desc 

settings 
    max_threads=5, 
    enable_filesystem_cache=true, 
    skip_unavailable_shards=true, 
    read_from_filesystem_cache_if_exists_otherwise_bypass_cache=false
