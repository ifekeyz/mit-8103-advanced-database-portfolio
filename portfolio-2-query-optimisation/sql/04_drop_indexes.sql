DROP INDEX IF EXISTS idx_ledger_account_created;
DROP INDEX IF EXISTS idx_accounts_customer;
DROP INDEX IF EXISTS idx_txn_completed_transfers_time;
DROP INDEX IF EXISTS idx_ledger_large_debits;
DROP INDEX IF EXISTS idx_txn_type_time_cover;
ANALYZE;