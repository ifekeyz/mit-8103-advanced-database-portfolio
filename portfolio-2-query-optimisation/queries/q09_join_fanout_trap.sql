-- Q9: The join fan-out trap (a correctness query, not an index query).
-- Every transfer has TWO ledger lines. Joining transactions to ledger lines
-- and then summing transactions.amount counts each transfer twice.
-- Expected result: fan_out_total is exactly 2 times correct_total.
SELECT
    (SELECT sum(t.amount)
       FROM transactions t
       JOIN ledger_entries l ON l.transaction_id = t.transaction_id
      WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
        AND t.initiated_at >= now() - interval '30 days') AS fan_out_total,
    (SELECT sum(t.amount)
       FROM transactions t
      WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
        AND t.initiated_at >= now() - interval '30 days') AS correct_total;
