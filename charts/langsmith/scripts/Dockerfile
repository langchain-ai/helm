# Use Clickhouse as the base image for access to Clickhouse client
FROM docker.io/clickhouse/clickhouse-server:23.9

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install utilities
RUN apt-get update && apt-get install -y wget gnupg2 software-properties-common

# Install PostgreSQL
RUN apt-get install -y postgresql postgresql-contrib

# Install ClickHouse
RUN apt-get update && apt-get install -y clickhouse-server clickhouse-client

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --chmod=0755 ./backfill_clickhouse.sh ./backfill_clickhouse.sh
COPY --chmod=0755 ./migrate_no_auth.sh ./migrate_no_auth.sh

# Set the default command for the container. This is optional and can be customized as needed.
CMD ["bash"]
