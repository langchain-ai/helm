-- This query exports all remote metrics.

SELECT
    rm.id,
    rm.from_timestamp,
    rm.to_timestamp,
    rm.received_at,
    rm.measures,
    rm.tags,
    rm.logs,
    rm.reported_status,
    rm.num_failed_metronome_send_attempts,
    rm.tenant_id,
    rm.self_hosted_customer_id,
    rm.backfill_id,
    rm.backfilled_at,
    t.display_name AS workspace_name,
    o.display_name AS organization_name
FROM remote_metrics rm
JOIN tenants t ON rm.tenant_id = t.id
JOIN organizations o ON t.organization_id = o.id
ORDER BY rm.received_at DESC;
