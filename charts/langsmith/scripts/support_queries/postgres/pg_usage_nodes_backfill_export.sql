-- This query exports all pending remote metrics.
-- It also sets backfill_id to a common random UUID for tracking
-- and sets backfilled_at to the current timestamp.

WITH backfill_info AS (
    SELECT
        gen_random_uuid() AS backfill_id,
        now() AS backfilled_at
),
backfill_txns AS (
  UPDATE remote_metrics rm
  SET backfill_id = backfill_info.backfill_id,
      backfilled_at = backfill_info.backfilled_at
  FROM backfill_info
  WHERE rm.reported_status = 'pending'
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
      rm.backfill_id,
      rm.backfilled_at
)
SELECT
    bt.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name,
    :'customer_id' AS customer_id,
    :'customer_name' AS customer_name
FROM backfill_txns bt
JOIN tenants t ON bt.tenant_id = t.id
JOIN organizations o ON o.id = t.organization_id
ORDER BY bt.received_at DESC;
