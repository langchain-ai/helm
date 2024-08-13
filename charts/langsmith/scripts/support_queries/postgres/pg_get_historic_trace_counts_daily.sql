-- Gets a daily count of traces by workspace ID and organization ID
-- This is done in PG so that we can join to get org names and workspace names
-- This count includes since-deleted traces

with date_series as (
    select generate_series(
        (select date_trunc('day', min(upper(interval))) from trace_count_transactions),
        (select date_trunc('day', max(upper(interval))) from trace_count_transactions),
        interval '1 day'
    ) as ds
),
transaction_types as (
    select distinct transaction_type from trace_count_transactions
),
periodic_data as (
    select 
        date_series.ds as ds, 
        o.id as organization_id,
        o.display_name as organization_name,
        tenants.id as workspace_id,
        tenants.display_name as workspace_name,
        tt.transaction_type as transaction_type,
        coalesce(sum(trace_count), 0) as trace_count
    from date_series
    cross join tenants
    cross join transaction_types tt
    left join trace_count_transactions traces
        on traces.tenant_id = tenants.id 
        and date_trunc('day', upper(interval) - interval '1 millisecond') = date_series.ds
        and traces.transaction_type = tt.transaction_type
    join organizations o
        on o.id = tenants.organization_id 
    group by 1, 2, 3, 4, 5, 6
    order by 1, 2, 3, 4, 5, 6
)
select * from periodic_data
