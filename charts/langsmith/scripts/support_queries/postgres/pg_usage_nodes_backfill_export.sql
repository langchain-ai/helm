-- This query exports all pending remote metrics.
-- It also sets backfill_id to a common random UUID for tracking
-- and sets backfilled_at to the current timestamp.
-- Every pending row is stamped, so the update script closes them all out, but rows
-- with no nodes and no runs bill nothing and are left out of the export.
-- Non-numeric node or run values are kept rather than failing the query.

WITH backfill_info AS (
    SELECT
        gen_random_uuid() AS backfill_id,
        now() AS backfilled_at
),
backfill_txns AS (
  UPDATE remote_metrics rm
  SET backfill_id = backfill_info.backfill_id,
      backfilled_at = backfill_info.backfilled_at
  FROM backfill_info
  WHERE rm.reported_status = 'pending'
  RETURNING
      id,
      from_timestamp,
      to_timestamp,
      received_at,
      measures,
      tags,
      logs,
      reported_status,
      num_failed_metronome_send_attempts,
      tenant_id,
      self_hosted_customer_id,
      rm.backfill_id,
      rm.backfilled_at
)
SELECT
    bt.*,
    t.organization_id,
    :'customer_id' AS customer_id,
    :'customer_name' AS customer_name
FROM backfill_txns bt
LEFT JOIN tenants t ON bt.tenant_id = t.id
WHERE CASE jsonb_typeof(bt.measures->'langgraph.platform.nodes')
         WHEN 'number' THEN (bt.measures->>'langgraph.platform.nodes')::numeric > 0
         WHEN 'null' THEN false
         ELSE jsonb_typeof(bt.measures->'langgraph.platform.nodes') IS NOT NULL
       END
    OR CASE jsonb_typeof(bt.measures->'langgraph.platform.runs')
         WHEN 'number' THEN (bt.measures->>'langgraph.platform.runs')::numeric > 0
         WHEN 'null' THEN false
         ELSE jsonb_typeof(bt.measures->'langgraph.platform.runs') IS NOT NULL
       END
ORDER BY bt.received_at DESC;
