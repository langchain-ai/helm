-- This query exports all remote metrics with node or run usage.
-- Rows marked skipped and rows with no nodes and no runs bill nothing, so they are left out.
-- Numeric strings count; other non-numeric node or run values count as no usage.

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
WHERE rm.reported_status <> 'skipped'
  AND rm.measures @? '$ ? (@."langgraph.platform.nodes".double() > 0 || @."langgraph.platform.runs".double() > 0)'
ORDER BY rm.received_at DESC;
