-- This query exports all langchain_usage rows — the shared LCU/LSU store for the
-- newer products (sandbox-priced, LSD/engine, gateway_hosted_models, fleet),
-- distinguished by the product / usage_type / metric_type columns.
-- langchain_usage carries only tenant_id, so LEFT JOIN tenants to recover
-- organization_id (LEFT so a row with no matching tenant still exports).

SELECT
    lu.*,
    t.organization_id
FROM langchain_usage lu
LEFT JOIN tenants t ON lu.tenant_id = t.id
ORDER BY lu.bucket_start DESC;
