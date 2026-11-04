-- Q2: Daily completed transfer totals for the last 30 days.
-- Business use: the finance dashboard.
SELECT date_trunc('day', initiated_at) AS day,
       count(*)    AS transfers,
       sum(amount) AS total_amount
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND status = 'COMPLETED'
  AND initiated_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1;
