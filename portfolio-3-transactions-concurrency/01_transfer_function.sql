-- =====================================================================
-- Portfolio 3: safe fund transfer for NairaPay
-- Run on nairapay_db. Safe to re-run (CREATE OR REPLACE).
--
-- transfer_funds() moves money between two wallets as ONE atomic unit:
--   * idempotent: a retried request (same key) is applied only once
--   * deadlock-safe: both wallets are locked in a fixed order (lowest
--     account_id first), so two opposite transfers cannot wait on each other
--   * race-safe: balances are read AFTER the row locks are held
--   * double-entry: writes one DEBIT and one CREDIT ledger line
--   * all-or-nothing: any error rolls back the whole transfer, including
--     the transactions row that was registered at the start
--
-- Usage:   SELECT transfer_funds('2200001001', '2200001002', 100.00, 'my-unique-key');
-- Returns: the transaction_id.
--
-- Note: ledger timestamps use clock_timestamp() (real time), not now()
-- (transaction start time). Under concurrency, now() could place a later
-- ledger line before an earlier one in the account statement.
-- =====================================================================

CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_account TEXT,
    p_to_account   TEXT,
    p_amount       NUMERIC,
    p_key          VARCHAR,
    p_reference    VARCHAR DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id   BIGINT;
    v_to_id     BIGINT;
    v_first_id  BIGINT;
    v_second_id BIGINT;
    v_from_bal  NUMERIC(19,4);
    v_to_bal    NUMERIC(19,4);
    v_txn_id    BIGINT;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: amount must be greater than zero';
    END IF;
    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION 'SAME_ACCOUNT: cannot transfer to the same account';
    END IF;

    -- 1. Idempotency. Register the request first. If the key already exists,
    --    nothing is inserted and the original transaction id is returned.
    INSERT INTO transactions (idempotency_key, txn_type, status, amount, reference)
    VALUES (p_key, 'TRANSFER', 'PENDING', p_amount, p_reference)
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_txn_id;

    IF v_txn_id IS NULL THEN
        SELECT transaction_id INTO v_txn_id
        FROM transactions WHERE idempotency_key = p_key;
        RETURN v_txn_id;
    END IF;

    -- 2. Resolve the account ids (no locks yet).
    SELECT account_id INTO v_from_id FROM accounts WHERE account_number = p_from_account;
    SELECT account_id INTO v_to_id   FROM accounts WHERE account_number = p_to_account;
    IF v_from_id IS NULL OR v_to_id IS NULL THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_FOUND: check the account numbers';
    END IF;

    -- 3. Lock both wallets in a fixed order (lowest account_id first).
    --    If every transfer locks in the same order, a deadlock cycle is impossible.
    v_first_id  := LEAST(v_from_id, v_to_id);
    v_second_id := GREATEST(v_from_id, v_to_id);
    PERFORM 1 FROM accounts WHERE account_id = v_first_id  FOR UPDATE;
    PERFORM 1 FROM accounts WHERE account_id = v_second_id FOR UPDATE;

    -- 4. Read the balances now that the locks are held, then validate.
    SELECT balance INTO v_from_bal FROM accounts WHERE account_id = v_from_id;
    SELECT balance INTO v_to_bal   FROM accounts WHERE account_id = v_to_id;

    IF EXISTS (SELECT 1 FROM accounts
               WHERE account_id IN (v_from_id, v_to_id) AND status <> 'ACTIVE') THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE: both accounts must be ACTIVE';
    END IF;
    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS: balance % is less than %', v_from_bal, p_amount;
    END IF;

    -- 5. Apply the transfer: balances, double-entry ledger lines, status.
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = v_from_id;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = v_to_id;

    INSERT INTO ledger_entries (transaction_id, account_id, direction, amount, balance_after, created_at)
    VALUES (v_txn_id, v_from_id, 'DEBIT',  p_amount, v_from_bal - p_amount, clock_timestamp()),
           (v_txn_id, v_to_id,   'CREDIT', p_amount, v_to_bal   + p_amount, clock_timestamp());

    UPDATE transactions
    SET status = 'COMPLETED', completed_at = clock_timestamp()
    WHERE transaction_id = v_txn_id;

    RETURN v_txn_id;
END;
$$;

-- =====================================================================
-- FOR DEMONSTRATION ONLY: the same function but WITHOUT ordered locking.
-- It locks the sender first and the receiver second, so two opposite
-- transfers can deadlock. It exists only so the stress test can show the
-- problem that ordered locking prevents. Never use it for real work.
-- =====================================================================
CREATE OR REPLACE FUNCTION transfer_funds_unordered(
    p_from_account TEXT,
    p_to_account   TEXT,
    p_amount       NUMERIC,
    p_key          VARCHAR,
    p_reference    VARCHAR DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id  BIGINT;
    v_to_id    BIGINT;
    v_from_bal NUMERIC(19,4);
    v_to_bal   NUMERIC(19,4);
    v_txn_id   BIGINT;
BEGIN
    INSERT INTO transactions (idempotency_key, txn_type, status, amount, reference)
    VALUES (p_key, 'TRANSFER', 'PENDING', p_amount, p_reference)
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_txn_id;
    IF v_txn_id IS NULL THEN
        SELECT transaction_id INTO v_txn_id FROM transactions WHERE idempotency_key = p_key;
        RETURN v_txn_id;
    END IF;

    SELECT account_id INTO v_from_id FROM accounts WHERE account_number = p_from_account;
    SELECT account_id INTO v_to_id   FROM accounts WHERE account_number = p_to_account;

    -- Locks taken in the order "sender, then receiver": this is the flaw.
    PERFORM 1 FROM accounts WHERE account_id = v_from_id FOR UPDATE;
    PERFORM pg_sleep(0.01);   -- widens the window so the deadlock shows up reliably
    PERFORM 1 FROM accounts WHERE account_id = v_to_id   FOR UPDATE;

    SELECT balance INTO v_from_bal FROM accounts WHERE account_id = v_from_id;
    SELECT balance INTO v_to_bal   FROM accounts WHERE account_id = v_to_id;
    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS: balance % is less than %', v_from_bal, p_amount;
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = v_from_id;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = v_to_id;
    INSERT INTO ledger_entries (transaction_id, account_id, direction, amount, balance_after, created_at)
    VALUES (v_txn_id, v_from_id, 'DEBIT',  p_amount, v_from_bal - p_amount, clock_timestamp()),
           (v_txn_id, v_to_id,   'CREDIT', p_amount, v_to_bal   + p_amount, clock_timestamp());
    UPDATE transactions SET status = 'COMPLETED', completed_at = clock_timestamp()
    WHERE transaction_id = v_txn_id;
    RETURN v_txn_id;
END;
$$;