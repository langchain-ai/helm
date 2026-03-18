-- This query exports all usage snapshots (daily entity counts).

SELECT *
FROM usage_snapshots
ORDER BY received_at DESC;
