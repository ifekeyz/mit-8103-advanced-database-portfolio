-- Portfolio 5: hash partitioning of the ledger (a single-node model of sharding)
-- Run on the PRIMARY after the NairaPay data has been loaded. Safe to re-run.
\echo '=== Rebuilding the partitioned copy of ledger_entries'
DROP TABLE IF EXISTS ledger_entries_sharded;

-- Partition key = account_id. All ledger lines of one wallet land in the SAME partition,
-- so an account statement touches exactly one partition.
-- (A primary key on a partitioned table must include the partition key.)
CREATE TABLE ledger_entries_sharded (
    entry_id       BIGINT        NOT NULL,
    transaction_id BIGINT        NOT NULL,
    account_id     BIGINT        NOT NULL,
    direction      VARCHAR(6)    NOT NULL,
    amount         NUMERIC(19,4) NOT NULL,
    balance_after  NUMERIC(19,4) NOT NULL,
    created_at     TIMESTAMPTZ   NOT NULL,
    PRIMARY KEY (account_id, entry_id)
) PARTITION BY HASH (account_id);

CREATE TABLE ledger_shard_0 PARTITION OF ledger_entries_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE ledger_shard_1 PARTITION OF ledger_entries_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE ledger_shard_2 PARTITION OF ledger_entries_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE ledger_shard_3 PARTITION OF ledger_entries_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO ledger_entries_sharded
SELECT entry_id, transaction_id, account_id, direction, amount, balance_after, created_at
FROM ledger_entries;

ANALYZE ledger_entries_sharded;

\echo
\echo '=== Rows per partition (hash spreads accounts roughly evenly)'
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM ledger_entries_sharded
GROUP BY 1 ORDER BY 1;

\echo
\echo '=== Same total as the original table? (expected: both numbers equal)'
SELECT (SELECT count(*) FROM ledger_entries)         AS original_rows,
       (SELECT count(*) FROM ledger_entries_sharded) AS partitioned_rows;

\echo
\echo '=== Query WITH the partition key: only ONE partition is scanned (partition pruning)'
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded WHERE account_id = 1001 ORDER BY created_at DESC LIMIT 10;

\echo
\echo '=== Query WITHOUT the partition key: ALL four partitions are scanned'
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded WHERE transaction_id = 12345;