-- =====================================================================
-- Portfolio 2: five NairaPay queries with execution plans
-- Run on nairapay_db after 01_seed_data.sql.
--
-- Each query is prefixed with EXPLAIN (ANALYZE, BUFFERS), which actually
-- runs the query and reports the plan, the real row counts, buffer usage
-- and the execution time.
--
-- Use this file twice:
--   1. BEFORE creating indexes (baseline)
--   2. AFTER running 04_create_indexes.sql
-- Run each query twice and record the second timing, so the first run does
-- not include cold-cache loading from disk.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1: Account statement. The 50 most recent ledger lines for one wallet.
-- Business use: the customer opens "Transaction history" in the app.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.created_at, l.direction, l.amount, l.balance_after,
       t.txn_type, t.reference
FROM ledger_entries l
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
ORDER BY l.created_at DESC
LIMIT 50;

-- ---------------------------------------------------------------------
-- Q2: Daily completed transfer totals for the last 30 days.
-- Business use: the finance dashboard.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('day', initiated_at) AS day,
       count(*)    AS transfers,
       sum(amount) AS total_amount
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND status = 'COMPLETED'
  AND initiated_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------
-- Q3: A customer's 10 largest outgoing transfers (joins three tables).
-- Business use: customer support investigating a dispute.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.transaction_id, t.amount, t.initiated_at, t.reference
FROM accounts a
JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
JOIN transactions t   ON t.transaction_id = l.transaction_id
WHERE a.customer_id = 1001
  AND t.txn_type = 'TRANSFER'
ORDER BY t.amount DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4: Fraud pattern. Customers with the most large outgoing transfers
-- (4,000 NGN or more) in the last 90 days.
-- Business use: the compliance team's daily review list.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.customer_id,
       count(*)    AS large_transfers,
       sum(l.amount) AS total_sent
FROM ledger_entries l
JOIN accounts a ON a.account_id = l.account_id
WHERE l.direction = 'DEBIT'
  AND l.amount >= 4000
  AND l.created_at >= now() - interval '90 days'
GROUP BY a.customer_id
ORDER BY large_transfers DESC, total_sent DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q5: CONTROL query. Look up a transaction by its idempotency key.
-- The UNIQUE constraint already created an index, so this should be fast
-- both before and after. It shows that constraints create indexes too.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM transactions
WHERE idempotency_key = 'seed-xfer-12345';