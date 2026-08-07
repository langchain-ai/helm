-- This query updates the status of remote metrics that were pending to sent-backfilled
-- for a specific backfill_id. It also returns the updated transactions for reference.
-- This query requires the backfill_id to be passed in as a variable with -v backfill_id="'<backfill_id>'"

WITH backfilled_txns AS (
    UPDATE remote_metrics
    SET reported_status = 'sent-backfilled'
    WHERE backfill_id = :'backfill_id'
    RETURNING
      id,
      from_timestamp,
      to_timestamp,
      received_at,
      measures,
      tags,
      logs,
      reported_status,
      num_failed_metronome_send_attempts,
      tenant_id,
      self_hosted_customer_id,
      backfill_id,
      backfilled_at
)
SELECT
    bt.*
FROM backfilled_txns bt
ORDER BY bt.received_at DESC;
