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
    t.organization_id
FROM remote_metrics rm
LEFT JOIN tenants t ON rm.tenant_id = t.id
ORDER BY rm.received_at DESC;
