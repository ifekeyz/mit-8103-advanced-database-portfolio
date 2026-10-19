-- =====================================================================
-- Portfolio 1: constraint tests for NairaPay
-- Run on nairapay_db AFTER 02_create_tables.sql, in ONE go (F5).
-- Each negative test is wrapped in a DO block that expects the database
-- to reject the bad row, then prints PASS. If the bad row is accepted,
-- the block raises an error instead. Read the output in the Messages tab.
-- =====================================================================

-- ---------- Setup: valid rows that should be accepted ----------
INSERT INTO customers (first_name, last_name, email, phone, customer_type)
VALUES ('Feranmi', 'Micheal', 'feranmi@yopmail.com', '08012345678', 'INDIVIDUAL');

INSERT INTO accounts (customer_id, account_number, balance)
SELECT customer_id, '0123456789', 500
FROM customers WHERE email = 'feranmi@yopmail.com';

INSERT INTO transactions (idempotency_key, txn_type, amount)
VALUES ('txn-key-001', 'DEPOSIT', 500);

INSERT INTO ledger_entries (transaction_id, account_id, direction, amount, balance_after)
SELECT t.transaction_id, a.account_id, 'CREDIT', 500, 500
FROM transactions t, accounts a
WHERE t.idempotency_key = 'txn-key-001' AND a.account_number = '0123456789';

-- ---------- Test 1: balance can never go negative (CHECK) ----------
DO $$
BEGIN
    INSERT INTO accounts (customer_id, account_number, balance)
    SELECT customer_id, '0123456780', -1 FROM customers WHERE email = 'feranmi@yopmail.com';
    RAISE EXCEPTION 'TEST FAILED: negative balance was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS 1: negative balance rejected';
END $$;

-- ---------- Test 2: account number must be exactly 10 digits (CHECK) ----------
DO $$
BEGIN
    INSERT INTO accounts (customer_id, account_number)
    SELECT customer_id, '12AB' FROM customers WHERE email = 'feranmi@yopmail.com';
    RAISE EXCEPTION 'TEST FAILED: malformed account number was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS 2: malformed account number rejected';
END $$;

-- ---------- Test 3: a transaction amount must be positive (CHECK) ----------
DO $$
BEGIN
    INSERT INTO transactions (idempotency_key, txn_type, amount)
    VALUES ('txn-key-zero', 'TRANSFER', 0);
    RAISE EXCEPTION 'TEST FAILED: zero-amount transaction was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS 3: zero-amount transaction rejected';
END $$;

-- ---------- Test 4: a REVERSAL must reference an original (CHECK) ----------
DO $$
BEGIN
    INSERT INTO transactions (idempotency_key, txn_type, amount)
    VALUES ('txn-key-rev', 'REVERSAL', 10);
    RAISE EXCEPTION 'TEST FAILED: reversal without an original was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS 4: reversal without original rejected';
END $$;

-- ---------- Test 5: email must be unique (UNIQUE) ----------
DO $$
BEGIN
    INSERT INTO customers (first_name, last_name, email, phone, customer_type)
    VALUES ('Bo', 'Eze', 'feranmi@yopmail.com', '08099999999', 'MERCHANT');
    RAISE EXCEPTION 'TEST FAILED: duplicate email was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 5: duplicate email rejected';
END $$;

-- ---------- Test 6: idempotency key stops a double-applied request (UNIQUE) ----------
DO $$
BEGIN
    INSERT INTO transactions (idempotency_key, txn_type, amount)
    VALUES ('txn-key-001', 'DEPOSIT', 500);
    RAISE EXCEPTION 'TEST FAILED: repeated idempotency key was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 6: repeated idempotency key rejected';
END $$;

-- ---------- Test 7: an account needs a real customer (FOREIGN KEY) ----------
DO $$
BEGIN
    INSERT INTO accounts (customer_id, account_number) VALUES (999999, '1111111111');
    RAISE EXCEPTION 'TEST FAILED: account for a missing customer was accepted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 7: account for unknown customer rejected';
END $$;

-- ---------- Test 8: a customer with accounts cannot be deleted (ON DELETE RESTRICT) ----------
DO $$
BEGIN
    DELETE FROM customers WHERE email = 'feranmi@yopmail.com';
    RAISE EXCEPTION 'TEST FAILED: customer with financial history was deleted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 8: deleting a customer with accounts is blocked';
END $$;

-- ---------- Test 9: fraud risk score must be 0 to 100 (CHECK) ----------
DO $$
BEGIN
    INSERT INTO fraud_flags (transaction_id, reason, risk_score)
    SELECT transaction_id, 'test', 150 FROM transactions WHERE idempotency_key = 'txn-key-001';
    RAISE EXCEPTION 'TEST FAILED: risk score 150 was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS 9: out-of-range risk score rejected';
END $$;

-- ---------- Test 10: same account cannot be credited twice in one transaction (UNIQUE) ----------
DO $$
BEGIN
    INSERT INTO ledger_entries (transaction_id, account_id, direction, amount, balance_after)
    SELECT t.transaction_id, a.account_id, 'CREDIT', 500, 1000
    FROM transactions t, accounts a
    WHERE t.idempotency_key = 'txn-key-001' AND a.account_number = '0123456789';
    RAISE EXCEPTION 'TEST FAILED: duplicate ledger line was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 10: duplicate ledger line rejected';
END $$;

-- ---------- Cleanup: remove the test rows so later portfolios start clean ----------
TRUNCATE customers, transactions RESTART IDENTITY CASCADE;