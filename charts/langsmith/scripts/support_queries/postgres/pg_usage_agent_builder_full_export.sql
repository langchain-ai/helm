-- This query exports all agent builder usage.

SELECT
    abu.*,
    t.display_name AS workspace_name,
    o.display_name AS organization_name
FROM agent_builder_usage abu
JOIN tenants t ON abu.tenant_id = t.id
JOIN organizations o ON t.organization_id = o.id
ORDER BY abu.from_timestamp DESC;
