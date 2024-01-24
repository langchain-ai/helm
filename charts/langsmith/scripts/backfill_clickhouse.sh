#!/bin/bash

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <postgres_url> <clickhouse_url>"
    exit 1
fi

# Assign command-line arguments to variables
postgres_url=$1
clickhouse_url=$2

#PostgreSQL query
runs_query_string=$(cat <<EOF
SELECT
    r.id,
    ts.tenant_id,
    r.name,
    r.start_time,
    r.end_time,
    r.extra,
    r.error,
    CASE
        WHEN r.parent_run_id IS NULL THEN True
        ELSE False
    END AS is_root,
    r.run_type,
    coalesce(input_blob.inline, r.inputs) as inputs,
    coalesce(output_blob.inline, r.outputs) as outputs,
    r.session_id,
    r.parent_run_id,
    r.reference_example_id,
    ts.reference_dataset_id,
    r.events,
    r.tags,
    r.manifest_id,
    r.status,
    r.trace_id,
    r.dotted_order,
    r.prompt_tokens,
    r.completion_tokens,
    r.total_tokens,
    r.first_token_time::timestamp,
    input_blob.s3_urls as inputs_s3_urls,
    output_blob.s3_urls as outputs_s3_urls
FROM
    runs r
JOIN
    tracer_session ts ON r.session_id = ts.id
LEFT JOIN run_blobs as input_blob ON r.id = input_blob.run_id and input_blob.key = 'inputs'
LEFT JOIN run_blobs as output_blob ON r.id = output_blob.run_id and output_blob.key = 'outputs'
EOF
)

runs_insert_query_string=$(cat <<EOF
INSERT INTO runs (
    id,
    tenant_id,
    name,
    start_time,
    end_time,
    extra,
    error,
    is_root,
    run_type,
    inputs,
    outputs,
    session_id,
    parent_run_id,
    reference_example_id,
    reference_dataset_id,
    events,
    tags,
    manifest_id,
    status,
    trace_id,
    dotted_order,
    prompt_tokens,
    completion_tokens,
    total_tokens,
    first_token_time,
    modified_at,
    is_deleted,
    inputs_s3_urls,
    outputs_s3_urls
)
SELECT
    toUUID(c1),  -- id
    toUUID(c2),  -- tenant_id
    c3, -- name
    c4, -- start_time
    c5, -- end_time
    toString(c6), -- extra
    c7, -- error
    c8, -- is_root
    c9, -- run_type
    toString(c10), -- inputs
    toString(c11), -- outpus
    toUUID(c12), -- session_id
    toUUIDOrNull(c13), -- parent_run_id
    toUUIDOrNull(c14), -- reference_example_id
    toUUIDOrNull(c15), -- reference_dataset_id
    toString(c16), -- events
    JSONExtract(assumeNotNull(c17), 'Array(String)') , -- tags
    toUUIDOrNull(c18), -- manifest_id
    c19, -- status
    toUUIDOrNull(c20), -- trace_id
    c21, -- dotted_order
    c22, -- prompt_tokens
    c23, -- completion_tokens
    c24, -- total_tokens
    c25, -- first_token_time,
    toDateTime64('2023-01-01 00:00:00', 6, 'UTC'), -- modified_at
    0, -- is_deleted
    toString(c26), -- inputs_s3_urls
    toString(c27) -- outputs_s3_urls
FROM input('c1 String, c2 String, c3 String, c4 DateTime64(6), c5 DateTime64(6), c6 String, c7 String, c8 bool, c9 String, c10 String, c11 String, c12 String, c13 String, c14 String, c15 String, c16 String, c17 String, c18 String, c19 String, c20 String, c21 String, c22 UInt64, c23 UInt64, c24 UInt64, c25 DateTime64(6), c26 String, c27 String')
FORMAT CSV
EOF
)

# Temporary file to store PostgreSQL query results
runs_file="runs.csv"

# Execute PostgreSQL query and save results to a file
psql "$postgres_url" -c "$runs_query_string" -o "$runs_file" --csv -t -P 'null=\N'

# Execute ClickHouse query to insert data
if [ -s "$runs_file" ]; then
# Execute ClickHouse query to insert data
cat 'runs.csv' | clickhouse-client "$clickhouse_url" --query "$runs_insert_query_string"
  echo "ClickHouse runs insertion completed."
else
    echo "No runs to migrate. No data inserted into ClickHouse."
fi


# Migrate Feedback
feedback_query_string=$(cat <<EOF
SELECT
    f.id,
    f.run_id,
    r.session_id,
    ts.tenant_id,
    CASE
        WHEN r.parent_run_id IS NULL THEN True
        ELSE False
    END AS is_root,
		r.start_time,
    f.created_at,
    f.modified_at,
    f.key,
    f.score,
    f.value,
    f.comment,
    f.correction,
	  r.trace_id,
    f.feedback_source
FROM
    feedback f
JOIN
    runs r ON f.run_id = r.id
JOIN
    tracer_session ts ON r.session_id = ts.id
EOF
)

feedback_insert_query_string=$(cat <<EOF
INSERT INTO feedbacks
SELECT
  toUUID(c1),
  toUUID(c2),
  toUUID(c3),
  toUUID(c4),
  c5,
  c6,
  c7,
  c8,
  c9,
  toDecimal32OrNull(c10, 4),
  toString(c11),
  c12,
  toString(c13),
  toUUID(c14),
  toString(c15),
  0
FROM input('c1 String, c2 String, c3 String, c4 String, c5 String, c6 DateTime64(6), c7 DateTime64(6), c8 DateTime64(6), c9 String, c10 String, c11 String, c12 String, c13 String, c14 String, c15 String')
FORMAT CSV
EOF
)

# Temporary file to store PostgreSQL query results
feedback_file="feedback.csv"

# Execute PostgreSQL query and save results to a file
psql $postgres_url -c "$feedback_query_string" -o "$feedback_file" --csv -t -P 'null=\N'
if [ -s "$feedback_file" ]; then
# Execute ClickHouse query to insert data
  cat "$feedback_file" | clickhouse-client "$clickhouse_url" --query "$feedback_insert_query_string"
  echo "ClickHouse feedback insertion completed."
else
    echo "No feedback to migrate. No data inserted into ClickHouse."
fi
