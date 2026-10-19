-- =====================================================================
-- Portfolio 2: seed data for NairaPay
-- Run on nairapay_db AFTER 02_create_tables.sql. Takes roughly a minute.
--
-- WARNING: this script first EMPTIES every NairaPay table, so it can be
-- re-run safely, but it will delete any data you added by hand.
--
-- Generates (approximately):
--   5,001 customers (incl. one internal settlement customer), 6,001 accounts
--   ~200,000 transfers, ~6,000 opening deposits, ~100 reversals
--   ~400,000 double-entry ledger lines
-- Everything is generated with SQL (generate_series, random, window
-- functions), so the data is reproducible by anyone with this file.
-- The whole script is a single transaction: it either completes or leaves
-- the tables untouched.
-- =====================================================================

BEGIN;

SELECT setseed(0.42);   -- makes random() repeatable between runs

TRUNCATE customers, transactions RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- 1. Customers. The first row is an internal settlement customer whose
--    account funds the opening deposits (the "other side" of each deposit).
-- ---------------------------------------------------------------------
INSERT INTO customers (first_name, last_name, email, phone, customer_type, created_at)
VALUES ('NairaPay', 'Settlement', 'settlement@nairapay.test', '08000000000',
        'MERCHANT', now() - interval '800 days');

INSERT INTO customers (first_name, last_name, email, phone, customer_type, status, created_at)
SELECT
    (ARRAY['Ada','Chidi','Emeka','Ngozi','Tunde','Funke','Ibrahim','Aisha','Bola','Yemi',
           'Kemi','Segun','Zainab','Obinna','Folake','Musa','Chiamaka','Femi','Halima','Ikenna'])
        [1 + (n * 7) % 20],
    (ARRAY['Okafor','Adeyemi','Bello','Eze','Okonkwo','Abubakar','Balogun','Nwosu',
           'Abiola','Danjuma','Ogunleye','Lawal','Umeh','Salami','Chukwu'])
        [1 + (n * 11) % 15],
    'user' || n || '@nairapay.test',
    '081' || lpad(n::text, 8, '0'),
    CASE WHEN n % 10 = 0 THEN 'MERCHANT' ELSE 'INDIVIDUAL' END,
    CASE WHEN n % 100 = 0 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
    -- joined 400 to 700 days ago, so every account exists before the transfer window
    now() - interval '400 days' - random() * interval '300 days'
FROM generate_series(1, 5000) AS n;

-- ---------------------------------------------------------------------
-- 2. KYC records: one per customer; rejected customers resubmit once.
-- ---------------------------------------------------------------------
INSERT INTO kyc_records (customer_id, id_type, id_number, verification_status,
                         submitted_at, verified_at)
SELECT c.customer_id,
       (ARRAY['NIN','BVN','PASSPORT','DRIVERS_LICENCE'])[1 + c.customer_id % 4],
       lpad((c.customer_id * 7919 % 100000000000)::text, 11, '0'),
       s.status,
       c.created_at + interval '1 hour',
       CASE WHEN s.status = 'PENDING' THEN NULL ELSE c.created_at + interval '1 day' END
FROM customers c
CROSS JOIN LATERAL (
    SELECT CASE WHEN c.customer_id % 25 = 0 THEN 'PENDING'
                WHEN c.customer_id % 40 = 0 THEN 'REJECTED'
                ELSE 'VERIFIED' END AS status
) s
WHERE c.email <> 'settlement@nairapay.test';

INSERT INTO kyc_records (customer_id, id_type, id_number, verification_status,
                         submitted_at, verified_at)
SELECT customer_id, 'NIN', id_number, 'VERIFIED',
       submitted_at + interval '3 days', submitted_at + interval '4 days'
FROM kyc_records
WHERE verification_status = 'REJECTED';

-- ---------------------------------------------------------------------
-- 3. Accounts: the settlement account (huge opening balance), one wallet
--    for every customer, and a second wallet for every fifth customer.
-- ---------------------------------------------------------------------
INSERT INTO accounts (customer_id, account_number, balance, opened_at)
SELECT customer_id, '1000000000', 1000000000000, created_at
FROM customers WHERE email = 'settlement@nairapay.test';

INSERT INTO accounts (customer_id, account_number, balance, status, opened_at)
SELECT customer_id, '22' || lpad(customer_id::text, 8, '0'), 0,
       CASE WHEN customer_id % 100 = 0 THEN 'FROZEN' ELSE 'ACTIVE' END,
       created_at + interval '2 days'
FROM customers WHERE email <> 'settlement@nairapay.test';

INSERT INTO accounts (customer_id, account_number, balance, opened_at)
SELECT customer_id, '33' || lpad(customer_id::text, 8, '0'), 0,
       created_at + interval '10 days'
FROM customers
WHERE email <> 'settlement@nairapay.test' AND customer_id % 5 = 0;

-- ---------------------------------------------------------------------
-- 4. Cards (about half of the wallets) and saved beneficiaries (3 each).
-- ---------------------------------------------------------------------
INSERT INTO cards (account_id, last_four, card_type, expiry_date, status)
SELECT a.account_id,
       lpad(floor(random() * 10000)::int::text, 4, '0'),
       CASE WHEN random() < 0.7 THEN 'DEBIT' ELSE 'VIRTUAL' END,
       current_date + (30 + floor(random() * 1400))::int,
       CASE WHEN random() < 0.05 THEN 'BLOCKED' ELSE 'ACTIVE' END
FROM accounts a
WHERE a.account_number <> '1000000000' AND random() < 0.5;

INSERT INTO beneficiaries (customer_id, bank_name, account_number, account_name)
SELECT c.customer_id,
       (ARRAY['GTBank','Access Bank','Zenith Bank','First Bank','UBA','Kuda','Opay','Moniepoint'])
           [1 + (k + c.customer_id) % 8],
       lpad(((c.customer_id * 31 + k * 9973) % 10000000000)::text, 10, '0'),
       'Recipient ' || c.customer_id || '-' || k
FROM customers c
CROSS JOIN generate_series(1, 3) AS k
WHERE c.email <> 'settlement@nairapay.test';

-- ---------------------------------------------------------------------
-- 5. Transactions
-- ---------------------------------------------------------------------

-- 5a. Opening deposit of 1,000,000 NGN for every customer wallet.
INSERT INTO transactions (idempotency_key, txn_type, status, amount, reference,
                          initiated_at, completed_at)
SELECT 'seed-dep-' || a.account_id, 'DEPOSIT', 'COMPLETED', 1000000, 'Opening deposit',
       a.opened_at + interval '1 day', a.opened_at + interval '1 day'
FROM accounts a
WHERE a.account_number <> '1000000000'
ORDER BY a.account_id;

-- 5b. 200,000 wallet-to-wallet transfers between ACTIVE wallets, spread over
--     the last 360 days. About 2% fail. Amounts are 100 to 5,000 NGN, so no
--     wallet can run out of money.
CREATE TEMP TABLE seed_acc ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY account_id) AS idx, account_id
FROM accounts
WHERE account_number <> '1000000000' AND status = 'ACTIVE';

-- NOTE: the random sender is picked in the select list of a derived table.
-- (A LATERAL subquery that does not reference the outer row is evaluated
-- only once, which would give every transfer the same sender.)
CREATE TEMP TABLE seed_xfer ON COMMIT DROP AS
SELECT s.g AS n,
       s.idx AS sender_idx,
       -- offset 1..total-1 guarantees the receiver differs from the sender
       ((s.idx + floor(random() * (s.total - 1))::int) % s.total) + 1 AS receiver_idx,
       round((100 + random() * 4900)::numeric, 2) AS amount,
       now() - random() * interval '360 days' AS ts,
       random() AS r
FROM (
    SELECT g, c.total, 1 + floor(random() * c.total)::int AS idx
    FROM generate_series(1, 200000) AS g
    CROSS JOIN (SELECT count(*)::int AS total FROM seed_acc) c
) s;

INSERT INTO transactions (idempotency_key, txn_type, status, amount, reference,
                          initiated_at, completed_at)
SELECT 'seed-xfer-' || n, 'TRANSFER',
       CASE WHEN r < 0.02 THEN 'FAILED' ELSE 'COMPLETED' END,
       amount, 'P2P transfer ' || n, ts,
       CASE WHEN r < 0.02 THEN NULL ELSE ts + interval '2 seconds' END
FROM seed_xfer
ORDER BY n;

CREATE TEMP TABLE seed_map ON COMMIT DROP AS
SELECT x.n, x.sender_idx, x.receiver_idx, t.transaction_id, t.status, t.amount, t.initiated_at
FROM seed_xfer x
JOIN transactions t ON t.idempotency_key = 'seed-xfer-' || x.n;

-- 5c. About 100 completed transfers are reversed (a new REVERSAL transaction
--     points at the original; the original is marked REVERSED).
INSERT INTO transactions (idempotency_key, txn_type, status, amount, reference,
                          reversal_of, initiated_at, completed_at)
SELECT 'seed-rev-' || m.transaction_id, 'REVERSAL', 'COMPLETED', m.amount,
       'Reversal of transaction ' || m.transaction_id, m.transaction_id,
       m.initiated_at + interval '1 hour', m.initiated_at + interval '1 hour 2 seconds'
FROM seed_map m
JOIN seed_xfer x ON x.n = m.n
WHERE m.status = 'COMPLETED' AND x.r >= 0.5 AND x.r < 0.5005
ORDER BY m.transaction_id;

UPDATE transactions o
SET status = 'REVERSED'
FROM transactions rv
WHERE rv.reversal_of = o.transaction_id;

-- ---------------------------------------------------------------------
-- 6. Ledger: every completed transaction gets one DEBIT and one CREDIT.
--    balance_after is a running total per account, computed with a window
--    function in time order.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE seed_moves ON COMMIT DROP AS
-- deposits: settlement account is debited
SELECT t.transaction_id,
       (SELECT account_id FROM accounts WHERE account_number = '1000000000') AS account_id,
       'DEBIT'::varchar AS direction, t.amount, t.initiated_at AS ts
FROM transactions t WHERE t.txn_type = 'DEPOSIT'
UNION ALL
-- deposits: the customer wallet is credited
SELECT t.transaction_id, substring(t.idempotency_key from 10)::bigint,
       'CREDIT', t.amount, t.initiated_at
FROM transactions t WHERE t.txn_type = 'DEPOSIT'
UNION ALL
-- transfers: sender debited
SELECT m.transaction_id, sa.account_id, 'DEBIT', m.amount, m.initiated_at
FROM seed_map m JOIN seed_acc sa ON sa.idx = m.sender_idx
WHERE m.status IN ('COMPLETED', 'REVERSED')
UNION ALL
-- transfers: receiver credited
SELECT m.transaction_id, ra.account_id, 'CREDIT', m.amount, m.initiated_at
FROM seed_map m JOIN seed_acc ra ON ra.idx = m.receiver_idx
WHERE m.status IN ('COMPLETED', 'REVERSED')
UNION ALL
-- reversals: the original receiver is debited
SELECT rv.transaction_id, ra.account_id, 'DEBIT', rv.amount, rv.initiated_at
FROM transactions rv
JOIN seed_map m ON m.transaction_id = rv.reversal_of
JOIN seed_acc ra ON ra.idx = m.receiver_idx
WHERE rv.txn_type = 'REVERSAL'
UNION ALL
-- reversals: the original sender is credited back
SELECT rv.transaction_id, sa.account_id, 'CREDIT', rv.amount, rv.initiated_at
FROM transactions rv
JOIN seed_map m ON m.transaction_id = rv.reversal_of
JOIN seed_acc sa ON sa.idx = m.sender_idx
WHERE rv.txn_type = 'REVERSAL';

INSERT INTO ledger_entries (transaction_id, account_id, direction, amount, balance_after, created_at)
SELECT m.transaction_id, m.account_id, m.direction, m.amount,
       CASE WHEN m.account_id = (SELECT account_id FROM accounts
                                 WHERE account_number = '1000000000')
            THEN 1000000000000 ELSE 0 END
       + SUM(CASE WHEN m.direction = 'CREDIT' THEN m.amount ELSE -m.amount END)
         OVER (PARTITION BY m.account_id ORDER BY m.ts, m.transaction_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
       m.ts
FROM seed_moves m
ORDER BY m.transaction_id, m.direction;

-- accounts.balance is the cached total: copy each account's latest balance_after
UPDATE accounts a
SET balance = l.balance_after
FROM (SELECT DISTINCT ON (account_id) account_id, balance_after
      FROM ledger_entries
      ORDER BY account_id, created_at DESC, transaction_id DESC) l
WHERE a.account_id = l.account_id;

-- ---------------------------------------------------------------------
-- 7. Fraud flags: a quarter of the very large transfers get flagged.
-- ---------------------------------------------------------------------
INSERT INTO fraud_flags (transaction_id, reason, risk_score, status, flagged_at)
SELECT t.transaction_id,
       CASE WHEN random() < 0.5 THEN 'Unusually large transfer'
            ELSE 'Rapid repeated transfers' END,
       50 + floor(random() * 50)::int,
       (ARRAY['OPEN','UNDER_REVIEW','CLEARED','CONFIRMED'])[1 + floor(random() * 4)::int],
       t.initiated_at + interval '5 minutes'
FROM transactions t
WHERE t.txn_type = 'TRANSFER' AND t.amount >= 4950 AND random() < 0.25;

COMMIT;

-- Refresh planner statistics so execution plans are realistic.
ANALYZE;