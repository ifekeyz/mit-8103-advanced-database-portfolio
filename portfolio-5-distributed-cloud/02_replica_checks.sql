-- Portfolio 5: replication health, run on the REPLICA (port 5434)
\echo '=== Is this server a replica? (expected: t)'
SELECT pg_is_in_recovery() AS is_replica;

\echo
\echo '=== WAL receiver: the live connection to the primary'
SELECT status, sender_host, sender_port, slot_name FROM pg_stat_wal_receiver;

\echo
\echo '=== How far behind is this replica?'
SELECT pg_last_wal_receive_lsn() AS received_up_to,
       pg_last_wal_replay_lsn()  AS replayed_up_to,
       pg_last_xact_replay_timestamp() AS last_replayed_commit_time,
       now() - pg_last_xact_replay_timestamp() AS time_since_last_replayed_commit;

\echo
\echo '=== A read works on the replica'
SELECT count(*) AS accounts FROM accounts;

\echo
\echo '=== A write is refused on the replica (expected: ERROR)'
\set ON_ERROR_STOP off
UPDATE accounts SET balance = balance WHERE account_id = 1;