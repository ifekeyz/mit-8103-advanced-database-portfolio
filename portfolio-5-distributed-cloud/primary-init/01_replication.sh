#!/bin/bash
# Runs once, the first time the primary's data directory is created.
# 1) a dedicated login role that is allowed to stream WAL, 2) permission for it in pg_hba.conf.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPLICATION_PASSWORD}';
EOSQL
# "all" in pg_hba.conf does NOT cover replication connections, so it needs its own line.
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"