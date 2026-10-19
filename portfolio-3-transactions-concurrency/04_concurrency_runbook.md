# Portfolio 3 Runbook: Concurrency Experiments

Five experiments that show what goes wrong when two sessions touch the same wallet at the
same time, and how locking and isolation levels fix it.

## Before you start

1. All commands run from the repo root (`MIT8103`). Check with `pwd`.
2. Load the function and demo wallets once:

   ```bash
   psql -d nairapay_db -f portfolio-3-transactions-concurrency/01_transfer_function.sql
   psql -d nairapay_db -f portfolio-3-transactions-concurrency/02_demo_setup.sql
   ```
3. Open **two or three terminal tabs** in Antigravity (the **+** button in the terminal panel).
   Call them **Terminal A**, **Terminal B** and **Terminal C**. In each one, start a session:

   ```bash
   psql -d nairapay_db
   ```

   Each terminal is a separate database session. That is what makes these experiments real.
4. **Reset before every experiment** (in any terminal):

   ```sql
   \i portfolio-3-transactions-concurrency/02_demo_setup.sql
   ```

   That puts Demo Alice (`9000000001`) and Demo Bob (`9000000002`) back to 500.00 each.
5. For evidence, put the terminals side by side and screenshot after each experiment.
   Save screenshots in `portfolio-3-transactions-concurrency/screenshots/`.

Type one step at a time and follow the order in the tables. The order across terminals is what
matters.

---

## Experiment 1: Lost update (no locking)

**The story:** Alice has 500. Two apps each check her balance, see 500, and approve a
400 withdrawal. Each app computes 500 - 400 = 100 itself and writes 100 back.

| Step | Terminal | Type this |
|---|---|---|
| 1 | A | `BEGIN;` then `SELECT balance FROM accounts WHERE account_number = '9000000001';` |
| 2 | B | `BEGIN;` then `SELECT balance FROM accounts WHERE account_number = '9000000001';` |
| 3 | A | `UPDATE accounts SET balance = 100 WHERE account_number = '9000000001';` then `COMMIT;` |
| 4 | B | `UPDATE accounts SET balance = 100 WHERE account_number = '9000000001';` then `COMMIT;` |
| 5 | any | `SELECT balance FROM accounts WHERE account_number = '9000000001';` |

**Expected:** both A and B read `500.0000` in steps 1 and 2. The final balance is `100.0000`.

**What it shows:** 800 was approved against a balance of 500, but the balance only fell by 400.
One withdrawal was lost (a **lost update**). Nothing errored, which is why this bug is dangerous.

---

## Experiment 2: The fix with `SELECT ... FOR UPDATE`

**The story:** the same situation, but each session locks the wallet row before reading it.

Reset first (`\i .../02_demo_setup.sql`).

| Step | Terminal | Type this |
|---|---|---|
| 1 | A | `BEGIN;` then `SELECT balance FROM accounts WHERE account_number = '9000000001' FOR UPDATE;` |
| 2 | B | `BEGIN;` then the **same** `SELECT ... FOR UPDATE;` (**it hangs, which is the point**) |
| 3 | C | `SELECT pid, state, wait_event_type, wait_event, left(query, 50) AS query FROM pg_stat_activity WHERE datname = 'nairapay_db' AND wait_event_type = 'Lock';` |
| 4 | A | `UPDATE accounts SET balance = balance - 400 WHERE account_number = '9000000001';` then `COMMIT;` |
| 5 | B | (it unblocks and prints a balance) then `ROLLBACK;` |

**Expected:** step 3 shows B waiting with `wait_event_type = Lock`. In step 5, B sees
`100.0000`, not 500, so the app sees that 400 is more than the balance and refuses the
withdrawal. The final balance is 100: one withdrawal succeeded and one was refused.

**What it shows:** the row lock makes the second session wait for the first to finish and
then read the up-to-date balance. Screenshot step 3 and step 5.

---

## Experiment 3: Isolation levels

PostgreSQL's default is **READ COMMITTED**. Compare it with **REPEATABLE READ**.

### 3a. READ COMMITTED (non-repeatable read)

Reset first.

| Step | Terminal | Type this |
|---|---|---|
| 1 | A | `BEGIN;` then `SELECT balance FROM accounts WHERE account_number = '9000000001';` |
| 2 | B | `UPDATE accounts SET balance = balance - 100 WHERE account_number = '9000000001';` |
| 3 | A | `SELECT balance FROM accounts WHERE account_number = '9000000001';` then `COMMIT;` |

**Expected:** A reads `500.0000`, then `400.0000` **inside the same transaction**. The same
query returned two different answers (a **non-repeatable read**).

### 3b. REPEATABLE READ

Reset first.

| Step | Terminal | Type this |
|---|---|---|
| 1 | A | `BEGIN ISOLATION LEVEL REPEATABLE READ;` then `SELECT balance FROM accounts WHERE account_number = '9000000001';` |
| 2 | B | `UPDATE accounts SET balance = balance - 100 WHERE account_number = '9000000001';` |
| 3 | A | `SELECT balance FROM accounts WHERE account_number = '9000000001';` |
| 4 | A | `UPDATE accounts SET balance = balance - 50 WHERE account_number = '9000000001';` |
| 5 | A | `ROLLBACK;` |

**Expected:** step 3 still shows `500.0000` (A keeps its snapshot). Step 4 fails with
`ERROR: could not serialize access due to concurrent update`.

**What it shows:** REPEATABLE READ gives a stable view, but refuses to overwrite data that
changed after the snapshot. The application must catch this error and **retry** the transaction.

---

## Experiment 4: Deadlock

**The story:** A moves money from Alice to Bob while B moves money from Bob to Alice. Each
locks its own sender first, then waits for the other's row.

Reset first.

| Step | Terminal | Type this |
|---|---|---|
| 1 | A | `BEGIN;` then `UPDATE accounts SET balance = balance - 10 WHERE account_number = '9000000001';` |
| 2 | B | `BEGIN;` then `UPDATE accounts SET balance = balance - 10 WHERE account_number = '9000000002';` |
| 3 | A | `UPDATE accounts SET balance = balance + 10 WHERE account_number = '9000000002';` (waits for B) |
| 4 | B | `UPDATE accounts SET balance = balance + 10 WHERE account_number = '9000000001';` |

**Expected:** after about a second, one session gets `ERROR: deadlock detected` with a
`DETAIL` line saying which process waits for which. PostgreSQL aborts that session and the
other one continues. Type `ROLLBACK;` in the aborted session and `COMMIT;` in the other.

**What it shows:** a circular wait. Neither session can ever finish, so the database kills one.

**The fix:** always lock rows in the same order. `transfer_funds()` locks the lower
`account_id` first, so two opposite transfers can never wait on each other in a circle.
Experiment 5 proves it under load.

---

## Experiment 5: Stress test with `pgbench`

`pgbench` runs many sessions at once. Each client moves a random amount between two random
wallets from a hot set of 20 wallets, so the sessions collide constantly.

Check it is installed: `pgbench --version`. If the command is not found, run
`export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"` and try again.

```bash
mkdir -p portfolio-3-transactions-concurrency/output

# Integrity BEFORE
psql -d nairapay_db -f portfolio-3-transactions-concurrency/07_integrity_check.sql \
  -o portfolio-3-transactions-concurrency/output/integrity_before.txt

# Ordered locking: 10 clients x 200 transfers each
pgbench -n -c 10 -j 4 -t 200 -f portfolio-3-transactions-concurrency/05_stress_ordered.pgbench nairapay_db \
  | tee portfolio-3-transactions-concurrency/output/stress_ordered.txt

psql -d nairapay_db -f portfolio-3-transactions-concurrency/07_integrity_check.sql \
  -o portfolio-3-transactions-concurrency/output/integrity_after_ordered.txt

# Unordered locking: the same workload with the flawed function
pgbench -n -c 10 -j 4 -t 200 -f portfolio-3-transactions-concurrency/06_stress_unordered.pgbench nairapay_db \
  | tee portfolio-3-transactions-concurrency/output/stress_unordered.txt

psql -d nairapay_db -f portfolio-3-transactions-concurrency/07_integrity_check.sql \
  -o portfolio-3-transactions-concurrency/output/integrity_after_unordered.txt
```

**Expected (reference run; your numbers will differ):**

| Run | Failed transactions | Throughput |
|---|---|---|
| Ordered locking | 0 of 2000 | hundreds of transfers per second |
| Unordered locking | dozens fail with `deadlock detected` | far lower, because each deadlock waits about a second to be detected |

In **all three** integrity checks:

- `total_money_in_system` is **identical** (money is never created or lost).
- `unbalanced_transactions`, `mismatched_accounts` and `stuck_pending_transactions` are all **0**.

**What it shows:** deadlock victims roll back completely, so even the failing version never
corrupts the ledger (**atomicity**). Ordered locking removes the failures entirely.

---

## Questions you must be able to answer

1. Why does Experiment 1 produce no error at all, and why is that worse than an error?
2. What does `FOR UPDATE` do, and what does the second session see when it finally runs?
3. What is the difference between READ COMMITTED and REPEATABLE READ, and why must an
   application retry after the serialization error?
4. What are the four conditions that make a deadlock possible, and which one does ordered
   locking break?
5. Why does `transfer_funds()` register the transaction row first (idempotency), lock second,
   and read balances third?
6. After a rolled-back transfer, the transaction ids have gaps. Why?
7. Why does the ledger use `clock_timestamp()` instead of `now()`?

## Reflection

_Add your own short reflection here: what surprised you, what you would do differently._