-- =====================================================================
-- Portfolio 2: remove the Portfolio 2 indexes to return to the baseline.
-- Use this if you need to re-capture the "before" plans.
-- (Indexes created by PRIMARY KEY and UNIQUE constraints are not touched.)
-- =====================================================================
DROP INDEX IF EXISTS idx_ledger_account_created;
DROP INDEX IF EXISTS idx_accounts_customer;
DROP INDEX IF EXISTS idx_txn_completed_transfers_time;
DROP INDEX IF EXISTS idx_ledger_large_debits;
ANALYZE;