-- This query exports all sandbox uptime usage — the raw sandbox outbox. It
-- already carries organization_id and the self-hosted attribution columns, so no
-- join is needed.

SELECT
    su.*
FROM sandbox_uptime_usage su
ORDER BY su.period_start DESC;
