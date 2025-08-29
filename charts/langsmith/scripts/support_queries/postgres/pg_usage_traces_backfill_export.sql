-- This query exports all pending trace count transactions
-- for local sources. It also sets backfill_id to a common random UUID for tracking
-- and sets backfilled_at to the current timestamp.

WITH backfill_info AS (
    SELECT
        gen_random_uuid() AS backfill_id,
        now() AS backfilled_at
),
backfill_txns AS (
  UPDATE trace_count_transactions tc
  SET backfill_id = backfill_info.backfill_id,
      backfilled_at = backfill_info.backfilled_at
  FROM backfill_info
  WHERE tc.status = 'pending'
    AND tc.source = 'local'
  RETURNING *
)
SELECT
    bt.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name,
    :'customer_id' AS customer_id,
    :'customer_name' AS customer_name
FROM backfill_txns bt
JOIN tenants t ON bt.tenant_id = t.id
JOIN organizations o ON bt.organization_id = o.id
ORDER BY bt.created_at DESC;
