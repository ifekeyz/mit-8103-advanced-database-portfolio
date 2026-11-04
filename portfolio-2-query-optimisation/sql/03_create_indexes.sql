-- Q1 and Q3: one account's ledger lines in time order.
-- Equality column first (account_id), then the sort column.
DROP INDEX IF EXISTS idx_ledger_account_created;
CREATE INDEX idx_ledger_account_created
    ON ledger_entries (account_id, created_at DESC);

-- Q3: accounts of one customer. PostgreSQL does NOT auto-index foreign keys.
DROP INDEX IF EXISTS idx_accounts_customer;
CREATE INDEX idx_accounts_customer
    ON accounts (customer_id);

-- Q2: partial + covering index. Only completed transfers are indexed;
-- INCLUDE (amount) lets the sum be read from the index alone.
DROP INDEX IF EXISTS idx_txn_completed_transfers_time;
CREATE INDEX idx_txn_completed_transfers_time
    ON transactions (initiated_at) INCLUDE (amount)
    WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED';

-- Q4: partial index of only large DEBIT lines.
DROP INDEX IF EXISTS idx_ledger_large_debits;
CREATE INDEX idx_ledger_large_debits
    ON ledger_entries (created_at) INCLUDE (account_id, amount)
    WHERE direction = 'DEBIT' AND amount >= 4000;

-- Q8: needs ALL statuses, so the partial index above cannot serve it
-- (a query's WHERE must imply the index's WHERE). Covering index instead.
DROP INDEX IF EXISTS idx_txn_type_time_cover;
CREATE INDEX idx_txn_type_time_cover
    ON transactions (txn_type, initiated_at) INCLUDE (status, amount);

ANALYZE;

-- Index sizes, for the write-up.
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname IN ('idx_ledger_account_created', 'idx_accounts_customer',
                       'idx_txn_completed_transfers_time', 'idx_ledger_large_debits',
                       'idx_txn_type_time_cover')
ORDER BY indexrelname;