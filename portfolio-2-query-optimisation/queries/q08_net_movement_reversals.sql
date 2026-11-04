-- Q8: Net transfer movement for the last 90 days, reversal-aware.
-- Reversed originals must not be counted as money that really moved.
-- Business use: the treasury report.
SELECT count(*) FILTER (WHERE status = 'COMPLETED')    AS net_transfers,
       sum(amount) FILTER (WHERE status = 'COMPLETED') AS net_amount,
       count(*) FILTER (WHERE status = 'REVERSED')     AS reversed_transfers,
       sum(amount) FILTER (WHERE status = 'REVERSED')  AS reversed_amount,
       count(*) FILTER (WHERE status = 'FAILED')       AS failed_transfers
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND initiated_at >= now() - interval '90 days';
