-- This query exports all legacy issues-agent (Engine) token usage. It is
-- tenant-scoped only, so LEFT JOIN tenants to recover organization_id (LEFT so a
-- row with no matching tenant still exports).

SELECT
    iat.*,
    t.organization_id
FROM issues_agent_token_usage iat
LEFT JOIN tenants t ON iat.tenant_id = t.id
ORDER BY iat.hour_start DESC;
