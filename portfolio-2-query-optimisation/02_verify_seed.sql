-- =====================================================================
-- Portfolio 2: verify the seed data
-- Run on nairapay_db after 01_seed_data.sql. Screenshot the results.
-- =====================================================================

-- 1. Row counts per table
SELECT 'customers' AS table_name, count(*) AS row_count FROM customers
UNION ALL SELECT 'kyc_records',    count(*) FROM kyc_records
UNION ALL SELECT 'accounts',       count(*) FROM accounts
UNION ALL SELECT 'beneficiaries',  count(*) FROM beneficiaries
UNION ALL SELECT 'cards',          count(*) FROM cards
UNION ALL SELECT 'transactions',   count(*) FROM transactions
UNION ALL SELECT 'ledger_entries', count(*) FROM ledger_entries
UNION ALL SELECT 'fraud_flags',    count(*) FROM fraud_flags
ORDER BY table_name;

-- 2. Transactions by type and status
SELECT txn_type, status, count(*) AS txn_count
FROM transactions
GROUP BY txn_type, status
ORDER BY txn_type, status;

-- 3. Double-entry check: every transaction with ledger lines must balance.
--    Expected: 0
SELECT count(*) AS unbalanced_transactions
FROM (
    SELECT transaction_id
    FROM ledger_entries
    GROUP BY transaction_id
    HAVING SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END) <> 0
) x;

-- 4. Cached balance check: accounts.balance must equal the ledger total
--    (the settlement account also has its 1,000,000,000,000 opening balance).
--    Expected: 0
SELECT count(*) AS mismatched_accounts
FROM accounts a
JOIN (
    SELECT account_id,
           SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE -amount END) AS net
    FROM ledger_entries
    GROUP BY account_id
) l ON l.account_id = a.account_id
WHERE a.balance <> l.net + CASE WHEN a.account_number = '1000000000'
                                THEN 1000000000000 ELSE 0 END;

-- 5. Completed or reversed transactions with no ledger lines. Expected: 0
SELECT count(*) AS completed_without_ledger
FROM transactions t
WHERE t.status IN ('COMPLETED', 'REVERSED')
  AND NOT EXISTS (SELECT 1 FROM ledger_entries l WHERE l.transaction_id = t.transaction_id);

-- 6. Failed transactions must have no ledger lines. Expected: 0
SELECT count(*) AS failed_with_ledger
FROM transactions t
WHERE t.status = 'FAILED'
  AND EXISTS (SELECT 1 FROM ledger_entries l WHERE l.transaction_id = t.transaction_id);

-- 7. The busiest accounts (a preview of the data Portfolio 2 will query)
SELECT a.account_number, a.balance, count(*) AS ledger_lines
FROM accounts a
JOIN ledger_entries l ON l.account_id = a.account_id
GROUP BY a.account_id, a.account_number, a.balance
ORDER BY ledger_lines DESC
LIMIT 5;