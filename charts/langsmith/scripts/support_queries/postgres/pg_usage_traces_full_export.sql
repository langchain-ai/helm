-- This query exports all trace count transactions.

SELECT
    tc.*
FROM trace_count_transactions tc
ORDER BY tc.created_at DESC;
