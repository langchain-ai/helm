-- Re-queues trace usage rows that were left in the terminal 'failed' state so the
-- usage reporter sends them again.
--
-- Run once against the deployment's Postgres. Safe to re-run: rows already
-- re-queued no longer match, so a second run reports 0.
--
-- Usage, from the scripts directory:
--   sh run_support_query_pg.sh "postgres://USER:PASS@HOST:PORT/DB" \
--     --input support_queries/postgres/pg_reset_failed_trace_transactions.sql
--
-- The affected window defaults to the values below. Override either bound by
-- appending -v window_start=2026-07-20T00:00:00Z
--
-- No restart needed. The reporter picks the rows up on its next scheduled run,
-- then moves them to 'sent'. Use query 1 afterwards to watch that happen.

\if :{?window_start}
\else
  \set window_start '2026-07-24T00:00:00Z'
\endif
\if :{?window_end}
\else
  \set window_end '2026-08-19T00:00:00Z'
\endif

-- 1. Before and after. Run on its own first to see what will change,
--    and again afterwards to confirm.
select
    status,
    count(*) as rows,
    sum(trace_count) as traces
from trace_count_transactions
where source = 'local'
  and interval_start >= :'window_start'
  and interval_start <  :'window_end'
  and extract(epoch from insertion_time_range_start)::bigint % 3600 = 0
  and insertion_time_range_end = insertion_time_range_start + interval '1 hour'
group by status
order by status;

-- 2. The re-queue itself, in chunks so it reports progress rather than looking
--    hung. psql prints each NOTICE as it arrives.
--
--    status = 'failed' is matched explicitly rather than excluding other states,
--    so rows that are already sent, already reconciled, or deliberately not
--    reported are never touched. Rows attached to a backfill_id are skipped
--    because they are already part of a manual reconciliation.
--
--    statement_timeout is cleared for this session only. A default of a minute or
--    two will otherwise kill the update part-way and roll all of it back.
set statement_timeout = 0;

-- psql does not substitute :'vars' inside a $$-quoted body, so pass them through
-- session settings instead.
select set_config('requeue.window_start', :'window_start', false),
       set_config('requeue.window_end',   :'window_end',   false);

do $$
declare
    window_start timestamptz := current_setting('requeue.window_start')::timestamptz;
    window_end   timestamptz := current_setting('requeue.window_end')::timestamptz;
    batch_size   int := 50000;
    in_batch     bigint;
    requeued     bigint := 0;
    expected     bigint;
begin
    select count(*) into expected
    from trace_count_transactions
    where status = 'failed'
      and backfill_id is null
      and source = 'local'
      and num_failed_send_attempts > 0
      and interval_start >= window_start
      and interval_start <  window_end
      and extract(epoch from insertion_time_range_start)::bigint % 3600 = 0
      and insertion_time_range_end = insertion_time_range_start + interval '1 hour';

    raise notice 'rows to re-queue: %', expected;

    loop
        update trace_count_transactions
        set status = 'pending',
            num_failed_send_attempts = 0
        where id in (
            select id
            from trace_count_transactions
            where status = 'failed'
              and backfill_id is null
              and source = 'local'
              and num_failed_send_attempts > 0
              and interval_start >= window_start
              and interval_start <  window_end
              and extract(epoch from insertion_time_range_start)::bigint % 3600 = 0
              and insertion_time_range_end = insertion_time_range_start + interval '1 hour'
            limit batch_size
        );

        get diagnostics in_batch = row_count;
        exit when in_batch = 0;

        requeued := requeued + in_batch;
        raise notice 're-queued % of %', requeued, expected;
    end loop;

    raise notice 'done. re-queued % rows', requeued;
end $$;
