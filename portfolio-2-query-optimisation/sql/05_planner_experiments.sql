-- Part A: environment and the planner's cost settings.
SELECT version();
SHOW block_size;
SHOW shared_buffers;
SHOW work_mem;
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;

SELECT c.relname, c.relkind,
       c.relpages AS pages_8kb,
       c.reltuples::bigint AS estimated_rows,
       pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'i')
ORDER BY pg_relation_size(c.oid) DESC
LIMIT 15;

SELECT attname, n_distinct, most_common_vals, correlation
FROM pg_stats
WHERE tablename = 'ledger_entries' AND attname IN ('account_id', 'direction');

-- Part B: Q1 as the planner chooses, then with index scans switched off.
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.created_at, l.direction, l.amount, l.balance_after, t.txn_type
FROM ledger_entries l
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
ORDER BY l.created_at DESC
LIMIT 50;

SET enable_indexscan = off;
SET enable_bitmapscan = off;
SET enable_indexonlyscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.created_at, l.direction, l.amount, l.balance_after, t.txn_type
FROM ledger_entries l
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
ORDER BY l.created_at DESC
LIMIT 50;
RESET enable_indexscan;
RESET enable_bitmapscan;
RESET enable_indexonlyscan;

-- Part C: Q2 chosen plan vs forced sequential scan.
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('day', initiated_at) AS day, count(*), sum(amount)
FROM transactions
WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED'
  AND initiated_at >= now() - interval '30 days'
GROUP BY 1;

SET enable_indexscan = off;
SET enable_bitmapscan = off;
SET enable_indexonlyscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('day', initiated_at) AS day, count(*), sum(amount)
FROM transactions
WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED'
  AND initiated_at >= now() - interval '30 days'
GROUP BY 1;
RESET enable_indexscan;
RESET enable_bitmapscan;
RESET enable_indexonlyscan;

-- Part D: selectivity. Temporary index, then ROLLBACK (nothing is kept).
BEGIN;
CREATE INDEX tmp_customers_status ON customers (status);
ANALYZE customers;
EXPLAIN (ANALYZE) SELECT * FROM customers WHERE status = 'SUSPENDED';  -- rare
EXPLAIN (ANALYZE) SELECT * FROM customers WHERE status = 'ACTIVE';     -- common
ROLLBACK;
ANALYZE customers;