-- Q5: CONTROL query. Look up a transaction by its idempotency key.
-- The UNIQUE constraint already created an index, so this should be fast
-- both before and after. It shows that constraints create indexes too.
SELECT *
FROM transactions
WHERE idempotency_key = 'seed-xfer-12345';
