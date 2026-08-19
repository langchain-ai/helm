-- This query exports all agent builder usage.

SELECT
    abu.*
FROM agent_builder_usage abu
ORDER BY abu.from_timestamp DESC;
