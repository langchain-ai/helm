-- This query exports all pending and pending-backfill trace count transactions
-- and updates the status to sent-backfilled for those that were pending-backfill.

WITH backfilled_txns AS (
    UPDATE trace_count_transactions
    SET status = 'sent-backfilled'
    WHERE source = 'local'
      AND status = 'pending-backfill'
    RETURNING *
),
backfillable_txns AS (
    UPDATE trace_count_transactions
    SET status = 'pending-backfill'
    WHERE source = 'local'
      AND status = 'pending'
    RETURNING *
),
combined_txns AS (
    SELECT * FROM backfillable_txns
    UNION ALL
    SELECT * FROM backfilled_txns
)
SELECT
    ct.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name
FROM combined_txns ct
JOIN tenants t ON ct.tenant_id = t.id
JOIN organizations o ON t.organization_id = o.id
ORDER BY ct.created_at DESC;
