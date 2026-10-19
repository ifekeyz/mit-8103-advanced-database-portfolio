-- =====================================================================
-- Portfolio 1: NairaPay schema (PostgreSQL)
-- Run while connected to nairapay_db.
-- Tables are created in dependency order: parents before children.
-- The whole script is one transaction, so a failure leaves no half-built schema.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- customers: individuals and merchants who own wallets
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL UNIQUE,
    phone          VARCHAR(20)  NOT NULL UNIQUE,
    customer_type  VARCHAR(20)  NOT NULL
                   CHECK (customer_type IN ('INDIVIDUAL', 'MERCHANT')),
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- kyc_records: identity verification submissions.
-- One customer can resubmit, so this is one-to-many.
-- ---------------------------------------------------------------------
CREATE TABLE kyc_records (
    kyc_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         BIGINT      NOT NULL
                        REFERENCES customers (customer_id) ON DELETE RESTRICT,
    id_type             VARCHAR(30) NOT NULL
                        CHECK (id_type IN ('NIN', 'BVN', 'PASSPORT', 'DRIVERS_LICENCE')),
    id_number           VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    submitted_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    verified_at         TIMESTAMPTZ,
    -- a record can only have a verification time once it is no longer pending
    CHECK (verified_at IS NULL OR verification_status <> 'PENDING')
);

-- ---------------------------------------------------------------------
-- accounts: naira wallets. balance is a cached total of the ledger.
-- NUMERIC (never FLOAT) avoids rounding errors on money.
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    BIGINT        NOT NULL
                   REFERENCES customers (customer_id) ON DELETE RESTRICT,
    account_number CHAR(10)      NOT NULL UNIQUE
                   CHECK (account_number ~ '^[0-9]{10}$'),
    currency       CHAR(3)       NOT NULL DEFAULT 'NGN',
    balance        NUMERIC(19,4) NOT NULL DEFAULT 0
                   CHECK (balance >= 0),
    status         VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    opened_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- beneficiaries: saved transfer recipients
-- ---------------------------------------------------------------------
CREATE TABLE beneficiaries (
    beneficiary_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    BIGINT       NOT NULL
                   REFERENCES customers (customer_id) ON DELETE CASCADE,
    bank_name      VARCHAR(100) NOT NULL,
    account_number CHAR(10)     NOT NULL
                   CHECK (account_number ~ '^[0-9]{10}$'),
    account_name   VARCHAR(150) NOT NULL,
    -- the same recipient cannot be saved twice by one customer
    UNIQUE (customer_id, bank_name, account_number)
);

-- ---------------------------------------------------------------------
-- cards: only the last four digits are stored, never the full card number
-- ---------------------------------------------------------------------
CREATE TABLE cards (
    card_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id  BIGINT      NOT NULL
                REFERENCES accounts (account_id) ON DELETE RESTRICT,
    last_four   CHAR(4)     NOT NULL CHECK (last_four ~ '^[0-9]{4}$'),
    card_type   VARCHAR(20) NOT NULL CHECK (card_type IN ('DEBIT', 'VIRTUAL')),
    expiry_date DATE        NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                CHECK (status IN ('ACTIVE', 'BLOCKED', 'EXPIRED'))
);

-- ---------------------------------------------------------------------
-- transactions: one row per business event.
-- idempotency_key stops a retried request from being applied twice.
-- reversal_of links a reversal to the original (history is never edited).
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key VARCHAR(64)   NOT NULL UNIQUE,
    txn_type        VARCHAR(20)   NOT NULL
                    CHECK (txn_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER',
                                        'BILL_PAYMENT', 'REVERSAL')),
    status          VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),
    amount          NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    reference       VARCHAR(100),
    reversal_of     BIGINT REFERENCES transactions (transaction_id) ON DELETE RESTRICT,
    initiated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    -- a transaction is a REVERSAL if and only if it points at an original
    CHECK ((txn_type = 'REVERSAL') = (reversal_of IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- ledger_entries: double-entry lines. Every transaction produces at least
-- one DEBIT and one CREDIT. This table also resolves the many-to-many
-- relationship between accounts and transactions.
-- ---------------------------------------------------------------------
CREATE TABLE ledger_entries (
    entry_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id BIGINT        NOT NULL
                   REFERENCES transactions (transaction_id) ON DELETE RESTRICT,
    account_id     BIGINT        NOT NULL
                   REFERENCES accounts (account_id) ON DELETE RESTRICT,
    direction      VARCHAR(6)    NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount         NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    balance_after  NUMERIC(19,4) NOT NULL CHECK (balance_after >= 0),
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- an account appears at most once per direction within one transaction
    UNIQUE (transaction_id, account_id, direction)
);

-- ---------------------------------------------------------------------
-- fraud_flags: suspicious activity raised against a transaction
-- ---------------------------------------------------------------------
CREATE TABLE fraud_flags (
    flag_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id BIGINT       NOT NULL
                   REFERENCES transactions (transaction_id) ON DELETE RESTRICT,
    reason         VARCHAR(200) NOT NULL,
    risk_score     SMALLINT     NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    status         VARCHAR(20)  NOT NULL DEFAULT 'OPEN'
                   CHECK (status IN ('OPEN', 'UNDER_REVIEW', 'CLEARED', 'CONFIRMED')),
    flagged_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- NOTE: performance indexes (for example on ledger_entries.account_id and
-- transactions.initiated_at) are deliberately NOT created here. They are
-- added in Portfolio 2 so the before/after execution plans can be compared.

COMMIT;

-- Verification: should list the 8 NairaPay tables.
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' ORDER BY table_name;