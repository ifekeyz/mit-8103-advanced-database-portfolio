-- Q6: Balance reconciliation. The cached accounts.balance must equal the
-- balance_after of the account's most recent ledger line.
-- Business use: end-of-day check that the cache and the ledger agree.
-- Expected result: 0 rows.
SELECT a.account_number,
       a.balance        AS cached_balance,
       l.balance_after  AS ledger_balance,
       a.balance - l.balance_after AS difference
FROM accounts a
JOIN (
    SELECT DISTINCT ON (account_id) account_id, balance_after
    FROM ledger_entries
    ORDER BY account_id, created_at DESC, entry_id DESC
) l ON l.account_id = a.account_id
WHERE a.balance <> l.balance_after;
