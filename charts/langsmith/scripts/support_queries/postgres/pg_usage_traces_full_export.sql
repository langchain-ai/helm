-- This query exports all trace count transactions.

SELECT
    tc.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name
FROM trace_count_transactions tc
JOIN tenants t ON tc.tenant_id = t.id
JOIN organizations o ON t.organization_id = o.id
ORDER BY tc.created_at DESC;
