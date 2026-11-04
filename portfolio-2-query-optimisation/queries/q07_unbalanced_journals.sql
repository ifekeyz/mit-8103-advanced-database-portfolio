-- Q7: Unbalanced journals. Every completed (or later reversed) transaction
-- must have total debits equal to total credits, and at least one line.
-- Business use: the core accounting invariant audit.
-- Expected result: 0 rows.
SELECT t.transaction_id,
       t.txn_type,
       t.amount,
       count(l.entry_id) AS entry_count,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)  AS total_debits,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0) AS total_credits
FROM transactions t
LEFT JOIN ledger_entries l ON l.transaction_id = t.transaction_id
WHERE t.status IN ('COMPLETED', 'REVERSED')
GROUP BY t.transaction_id, t.txn_type, t.amount
HAVING count(l.entry_id) = 0
    OR coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)
    <> coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0);
