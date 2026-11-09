-- This query exports all remote metrics with node or run usage.
-- Rows marked skipped and rows with no nodes and no runs bill nothing, so they are left out.
-- Non-numeric node or run values are kept rather than failing the query.

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
  AND (CASE jsonb_typeof(rm.measures->'langgraph.platform.nodes')
         WHEN 'number' THEN (rm.measures->>'langgraph.platform.nodes')::numeric > 0
         WHEN 'null' THEN false
         ELSE jsonb_typeof(rm.measures->'langgraph.platform.nodes') IS NOT NULL
       END
    OR CASE jsonb_typeof(rm.measures->'langgraph.platform.runs')
         WHEN 'number' THEN (rm.measures->>'langgraph.platform.runs')::numeric > 0
         WHEN 'null' THEN false
         ELSE jsonb_typeof(rm.measures->'langgraph.platform.runs') IS NOT NULL
       END)
ORDER BY rm.received_at DESC;
