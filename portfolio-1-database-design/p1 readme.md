# Portfolio 1: Database Design and Modelling

**Case study:** NairaPay, a simulated Nigerian fintech wallet and transfer platform
(see [case-study.md](case-study.md)).
**DBMS:** PostgreSQL 16, managed with pgAdmin 4. **Database:** `nairapay_db`.

## Files, in the order they are run

| File | Purpose |
|---|---|
| `00_create_database.sql` | Creates `nairapay_db` (run while connected to the default `postgres` database) |
| `01_verify_setup.sql` | Confirms the connection: version, database and user |
| `02_create_tables.sql` | Creates the 8 tables with primary keys, foreign keys and `CHECK`/`UNIQUE` constraints, in one transaction |
| `03_constraint_tests.sql` | 10 negative tests proving the database rejects invalid data, then cleans up |
| `nairapay.dbml` | ER model source (paste into dbdiagram.io to redraw the diagram) |
| `er-diagram.png` | Exported ER diagram |
| `normalisation.md` | 1NF to 3NF explanation, including deliberate departures from 3NF |

## How to run

1. In pgAdmin, connect to the local server and run `00_create_database.sql` on the `postgres` database.
2. Open a Query Tool on `nairapay_db` and run `01_verify_setup.sql`, then `02_create_tables.sql`.
3. Run `03_constraint_tests.sql` in one go and read `PASS 1` to `PASS 10` in the Messages tab.

## How it was tested

- `02_create_tables.sql` finishes with `COMMIT` and creates 8 tables (screenshot below).
- `03_constraint_tests.sql` attempts 10 invalid operations (negative balance, malformed account
  number, zero amount, reversal with no original, duplicate email, repeated idempotency key,
  orphan foreign key, deleting a customer with accounts, out-of-range risk score, duplicate
  ledger line). All are rejected.

## Evidence

- `screenshots/01-setup.png`: connection and version check
- `screenshots/02-tables-created.png`: the 8 tables in pgAdmin
- `screenshots/03-constraint-tests.png`: `PASS 1` to `PASS 10`
- `er-diagram.png`: entity relationship diagram

## Key design decisions

- **Money is `NUMERIC(19,4)`, never `FLOAT`**, so there are no rounding errors.
- **Double-entry ledger:** every transaction has debit and credit lines in `ledger_entries`.
  `accounts.balance` is a cached total of the ledger.
- **`idempotency_key` is unique**, so a retried request cannot be applied twice.
- **Reversals are new transactions** linked through `reversal_of`. History is never edited.
- **`ON DELETE RESTRICT`** on financial tables protects history; `CASCADE` is used only for
  beneficiaries, which are disposable.
- **No performance indexes yet.** They are added in Portfolio 2 so execution plans can be
  compared before and after.

## Reflection

_Add your own short reflection here: what you chose and why, what went wrong, what you learned._