-- This query exports all pending and pending-backfill trace count transactions
-- for local sources.

SELECT
    tc.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name
FROM trace_count_transactions tc
JOIN tenants t ON tc.tenant_id = t.id
JOIN organizations o ON tc.organization_id = o.id
WHERE (tc.status = 'pending' OR tc.status = 'pending-backfill')
  AND tc.source = 'local'
ORDER BY tc.created_at DESC;
