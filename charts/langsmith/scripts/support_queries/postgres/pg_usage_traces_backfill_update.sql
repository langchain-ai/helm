-- This query updates the status of trace count transactions that were pending to sent-backfilled
-- for a specific backfill_id. It also returns the updated transactions for reference.
-- This query requires the backfill_id to be passed in as a variable with -v backfill_id="'<backfill_id>'"

WITH backfilled_txns AS (
    UPDATE trace_count_transactions
    SET status = 'sent-backfilled'
    WHERE backfill_id = :'backfill_id'
    RETURNING *
)
SELECT
    bt.*
FROM backfilled_txns bt
ORDER BY bt.created_at DESC;
