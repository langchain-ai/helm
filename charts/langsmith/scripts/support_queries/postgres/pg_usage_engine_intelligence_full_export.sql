-- This query exports all Smith Intelligence (self-hosted Engine) token usage. It
-- already carries customer_id, organization_id and tenant_id, so no join needed.

SELECT
    sit.*
FROM smith_intelligence_token_usage sit
ORDER BY sit.hour_start DESC;
