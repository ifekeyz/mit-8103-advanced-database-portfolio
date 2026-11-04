-- Q4: Fraud pattern. Customers with the most large outgoing transfers
-- (4,000 NGN or more) in the last 90 days.
-- Business use: the compliance team's daily review list.
SELECT a.customer_id,
       count(*)      AS large_transfers,
       sum(l.amount) AS total_sent
FROM ledger_entries l
JOIN accounts a ON a.account_id = l.account_id
WHERE l.direction = 'DEBIT'
  AND l.amount >= 4000
  AND l.created_at >= now() - interval '90 days'
GROUP BY a.customer_id
ORDER BY large_transfers DESC, total_sent DESC
LIMIT 10;
