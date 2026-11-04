-- Q1: Account statement. The 50 most recent ledger lines for one wallet.
-- Business use: the customer opens "Transaction history" in the app.
SELECT l.created_at, l.direction, l.amount, l.balance_after,
       t.txn_type, t.reference
FROM ledger_entries l
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
ORDER BY l.created_at DESC
LIMIT 50;
