-- =====================================================================
-- Portfolio 3: demo wallets for the concurrency experiments
-- Run on nairapay_db. RE-RUN THIS FILE to reset both wallets to 500.00
-- before each experiment.
--
-- Demo Alice (9000000001) and Demo Bob (9000000002) get an opening balance
-- of 500.00 directly. They have NO ledger lines, because the lock
-- experiments touch only accounts.balance. They are kept separate from the
-- seeded accounts so the main ledger stays consistent.
-- =====================================================================

INSERT INTO customers (first_name, last_name, email, phone, customer_type)
VALUES ('Demo', 'Alice', 'demo.alice@nairapay.test', '08200000001', 'INDIVIDUAL'),
       ('Demo', 'Bob',   'demo.bob@nairapay.test',   '08200000002', 'INDIVIDUAL')
ON CONFLICT (email) DO NOTHING;

INSERT INTO accounts (customer_id, account_number, balance)
SELECT customer_id, '9000000001', 500 FROM customers WHERE email = 'demo.alice@nairapay.test'
ON CONFLICT (account_number) DO UPDATE SET balance = 500, status = 'ACTIVE';

INSERT INTO accounts (customer_id, account_number, balance)
SELECT customer_id, '9000000002', 500 FROM customers WHERE email = 'demo.bob@nairapay.test'
ON CONFLICT (account_number) DO UPDATE SET balance = 500, status = 'ACTIVE';

SELECT account_number, balance FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;