-- Re-queues trace usage rows that were left in the terminal 'failed' state so the
-- usage reporter sends them again.
--
-- Run once against the deployment's Postgres. Safe to re-run: rows already
-- re-queued no longer match, so a second run reports 0.
--
-- The affected window defaults to the values below. Override either bound with
-- -v window_start=2026-07-20T00:00:00Z -v window_end=2026-08-19T00:00:00Z
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

-- 2. The re-queue itself. Reports how many rows it changed.
--
--    status = 'failed' is matched explicitly rather than excluding other states,
--    so rows that are already sent, already reconciled, or deliberately not
--    reported are never touched. Rows attached to a backfill_id are skipped
--    because they are already part of a manual reconciliation.
with requeued as (
update trace_count_transactions
set status = 'pending',
    num_failed_send_attempts = 0
where status = 'failed'
  and backfill_id is null
  and source = 'local'
  and num_failed_send_attempts > 0
  and interval_start >= :'window_start'
  and interval_start <  :'window_end'
  and extract(epoch from insertion_time_range_start)::bigint % 3600 = 0
  and insertion_time_range_end = insertion_time_range_start + interval '1 hour'
  returning 1
)
select count(*) as rows_requeued from requeued;
