-- Q3: A customer's 10 largest outgoing transfers (joins three tables).
-- Business use: customer support investigating a dispute.
SELECT t.transaction_id, t.amount, t.initiated_at, t.reference
FROM accounts a
JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
JOIN transactions t   ON t.transaction_id = l.transaction_id
WHERE a.customer_id = 1001
  AND t.txn_type = 'TRANSFER'
ORDER BY t.amount DESC
LIMIT 10;
