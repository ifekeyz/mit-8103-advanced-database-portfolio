# Portfolio 2: Query Processing and Optimisation, Performance Analysis

> Template. Fill in every blank from YOUR OWN measurements and write the explanations
> in your own words. Numbers from anyone else's machine will not match yours.

## Environment

- PostgreSQL version: ___ (run `SELECT version();`)
- Machine: ___ (for example MacBook Pro, Apple M1)
- Data volume: ___ customers, ___ accounts, ___ transactions, ___ ledger entries
  (from `02_verify_seed.sql`)
- Method: each query run twice with `EXPLAIN (ANALYZE, BUFFERS)`; the second run is recorded
  so cold-cache disk reads do not distort the result.

## Results

| Query | Business purpose | Before: main plan node | Before (ms) | Index added | After: main plan node | After (ms) | Speed-up |
|---|---|---|---|---|---|---|---|
| Q1 | Account statement | ___ | ___ | `idx_ledger_account_created` | ___ | ___ | ___x |
| Q2 | Daily transfer totals | ___ | ___ | `idx_txn_completed_transfers_time` | ___ | ___ | ___x |
| Q3 | Customer's largest transfers | ___ | ___ | `idx_accounts_customer` and `idx_ledger_account_created` | ___ | ___ | ___x |
| Q4 | Large-transfer fraud pattern | ___ | ___ | `idx_ledger_large_debits` | ___ | ___ | ___x |
| Q5 | Idempotency key lookup (control) | ___ | ___ | none (UNIQUE constraint) | ___ | ___ | ___x |

Raw plans: `plans/before.txt` and `plans/after.txt`.
Speed-up = before ms divided by after ms.

## How to read the plans (check you understand each term)

- **Seq Scan:** reads every row of the table.
- **Index Scan:** follows the index to the matching rows.
- **Bitmap Index/Heap Scan:** collects matching row locations from the index, then reads the
  table pages in order. Used when a medium number of rows match.
- **Index Only Scan:** answers the query from the index alone, without visiting the table.
- **actual time / rows / loops:** the real cost per loop and how many times the node ran.
- **Buffers shared hit/read:** pages found in memory versus read from disk.

## Analysis (write in your own words)

For each of Q1 to Q4, answer:

1. Which scan did the planner use before, and why was it the best choice without an index?
2. Which index did you add, and why do its columns appear in that order?
3. What does the "after" plan do differently, and where does the time saving come from?

**Q5 (control):** why is it already fast, and what does this show about primary key and
`UNIQUE` constraints?

## Trade-offs of indexing

| Index | Size (from `04_create_indexes.sql` output) | Speeds up |
|---|---|---|
| `idx_ledger_account_created` | ___ | Q1, Q3 |
| `idx_accounts_customer` | ___ | Q3 |
| `idx_txn_completed_transfers_time` | ___ | Q2 |
| `idx_ledger_large_debits` | ___ | Q4 |

Discuss: every index uses disk space and must be updated on every insert. For a payments
ledger that is written constantly, why were the **partial** indexes (only completed transfers,
only large debits) a better choice than indexing every row?

## Limitations and honest notes

- Timings vary from run to run. State how many times you ran each query.
- Gains grow with data size. Say what you would expect with 100 times more rows.
- Q2 and Q4 improved less than Q1 and Q3. Explain why (they read many matching rows, so
  they cannot stop early the way a `LIMIT 50` query can).

## Reflection

_Add your own short reflection here: what surprised you, what you would do differently._