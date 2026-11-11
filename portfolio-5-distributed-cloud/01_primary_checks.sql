-- Portfolio 5: replication health, run on the PRIMARY (port 5433)
\echo '=== Is this server a replica? (expected: f = primary)'
SELECT pg_is_in_recovery() AS is_replica;

\echo
\echo '=== Connected replicas (one row per streaming standby)'
SELECT application_name, client_addr, state, sync_state,
       sent_lsn, replay_lsn,
       replay_lag
FROM pg_stat_replication;

\echo
\echo '=== Replication slots (the primary keeps WAL until the replica has it)'
SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots;

\echo
\echo '=== Current WAL position on the primary'
SELECT pg_current_wal_lsn() AS primary_wal_position;