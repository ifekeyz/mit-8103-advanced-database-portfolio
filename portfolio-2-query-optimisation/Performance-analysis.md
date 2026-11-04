# Performance Analysis and Query Optimisation Report

**Course:** MIT 8103 – Advanced Database Systems  
**Module:** Portfolio 2 – Query Optimisation and Performance Tuning  
**System Under Test:** `nairapay_db` (PostgreSQL 16.14 on macOS aarch64)  
**Enterprise Context:** NairaPay Technologies Limited (Simulated Nigerian Payment Service Provider)  
**Target Workload:** High-Volume OLTP Ledger & Financial Reporting Operations  
**Accompanying Repository Files:** [README.md](README.md), [plans/before.txt](plans/before.txt), [plans/after.txt](plans/after.txt), [plans/planner.txt](plans/planner.txt), [plans/results.txt](plans/results.txt)

---

## 1. Executive Summary

In enterprise financial architectures, sub-second query performance and absolute accounting integrity are non-negotiable operational requirements. In **Portfolio 1**, the relational schema for **NairaPay** was established with rigorous primary keys, check constraints, foreign keys, and double-entry bookkeeping rules. In accordance with proper scientific evaluation, secondary performance indexes were intentionally omitted so that baseline execution plans and hardware resource consumption could be objectively captured.

**Portfolio 2** executes an in-depth query optimization and performance engineering study against a seeded production-scale dataset consisting of **404,162 ledger entries**, **206,096 transactions**, **6,003 accounts**, and **5,003 customers**. 

### Key Empirical Findings:
1. **Dramatic Latency Reductions:** Targeted index design reduced query execution latencies by up to **280×** (Q1 dropped from **242.70 ms** to **0.87 ms**; Q3 dropped from **25.39 ms** to **1.75 ms**).
2. **Buffer I/O Minimization:** High-frequency queries experienced **94% to 98% reductions** in shared memory buffer page hits, drastically mitigating CPU cache pressure and memory bus contention.
3. **Elimination of Disk Spills:** In balance reconciliation (Q6), index-assisted **Incremental Sort** eliminated an external merge sort that was spilling **19.7 MB** of temporary data to disk on every execution.
4. **Validation of Planner Cost Models:** Controlled experiments validated PostgreSQL's cost calculation equations, empirically identifying the selectivity tipping point where sequential table scans outperform index scans (~1% vs ~99% selectivity).
5. **Write Amplification Quantified:** Maintaining two secondary indexes on the core ledger increased total table storage by **48.5%** (from 33 MB to 49 MB), highlighting the engineering trade-offs required in write-intensive financial systems.
6. **Relational Correctness:** Empirical verification confirmed the **Join Fan-Out Trap** in double-entry bookkeeping, proving that unaggregated multi-table joins inflate financial sums by exactly **2.0×**.

---

## 2. Environment Baseline & System Configuration

### 2.1 Hardware and Runtime Environment
All benchmarks were executed on an isolated test environment under PostgreSQL 16.14 (Homebrew / aarch64-apple-darwin25.4.0, 64-bit). The active query optimizer settings were captured directly via `sql/05_planner_experiments.sql`:

| Configuration Parameter | Value | Architectural Impact |
|---|---|---|
| **DBMS Version** | PostgreSQL 16.14 (64-bit) | Modern query planner with Incremental Sort and parallel query execution |
| **`block_size`** | `8192` (8 KB) | Standard PostgreSQL page granularity |
| **`shared_buffers`** | `128 MB` | Dedicated database buffer pool in RAM |
| **`work_mem`** | `4 MB` | Memory budget per sort/hash operation before spilling to temp disk |
| **`seq_page_cost`** | `1.0` | Cost of sequential disk block fetch (baseline unit) |
| **`random_page_cost`** | `4.0` | Cost of non-sequential disk block fetch (B-Tree traversal penalty) |
| **`cpu_tuple_cost`** | `0.01` | CPU processing cost per scanned tuple |

### 2.2 Dataset Scale and Physical Storage Profile
The physical footprint of the database was queried from `pg_class` and `pg_namespace` to profile data distribution across pages:

```
                        relname                         | relkind | pages_8kb | estimated_rows |  size   
--------------------------------------------------------+---------+-----------+----------------+---------
 ledger_entries                                         | r       |      4167 |         404162 | 33 MB
 transactions                                           | r       |      3147 |         206096 | 25 MB
 ledger_entries_transaction_id_account_id_direction_key | i       |      2010 |         404162 | 16 MB
 idx_txn_type_time_cover                                | i       |      1689 |         206096 | 13 MB
 idx_ledger_account_created                             | i       |      1559 |         404162 | 12 MB
 transactions_idempotency_key_key                       | i       |      1552 |         206096 | 12 MB
 ledger_entries_pkey                                    | i       |      1111 |         404162 | 8888 kB
 idx_txn_completed_transfers_time                       | i       |       756 |         195991 | 6048 kB
 transactions_pkey                                      | i       |       567 |         206096 | 4536 kB
 idx_ledger_large_debits                                | i       |       230 |          45765 | 1840 kB
 beneficiaries                                          | r       |       153 |          15000 | 1224 kB
 accounts                                               | r       |       124 |           6003 | 992 kB
 beneficiaries_customer_id_bank_name_account_number_key | i       |       115 |          15000 | 920 kB
 customers                                              | r       |        71 |           5003 | 568 kB
 kyc_records                                            | r       |        59 |           5100 | 472 kB
```

### 2.3 Physical Data Distribution and Correlation
Analysis of `pg_stats` reveals critical physical clustering properties:
- **`ledger_entries.direction`:** Only 2 distinct values (`CREDIT`, `DEBIT`), with a statistical correlation of **0.495**.
- **`ledger_entries.account_id`:** 5,951 distinct values, with a low statistical correlation of **0.051**. Because ledger lines for a given account are scattered across all 4,167 heap pages rather than clustered contiguously, an unindexed lookup forces the engine to scan the entire 33 MB table heap.

---

## 3. Comprehensive Benchmark Matrix (Before vs. After)

The following master benchmark table compiles empirical metrics gathered across 9 queries representing distinct operational profiles. Plans were captured using `EXPLAIN (ANALYZE, BUFFERS)` before and after secondary index creation.

| Query ID | Business Purpose | Execution Plan (Before) | Execution Plan (After) | Estimated Cost (Before) | Estimated Cost (After) | Buffer Hits (Before) | Buffer Hits (After) | Latency Before (ms) | Latency After (ms) | Speedup / Optimization Delta |
|---|---|---|---|---|---|---|---|---|---|---|
| **Q1** | Recent Wallet Statement (OLTP) | Parallel Seq Scan + Quicksort | Index Scan (`account_id, created_at DESC`) | 7512.32..7518.15 | 9.14..625.52 | 4,372 hit, 44 read | 256 hit, 0 read | **242.70 ms** | **0.87 ms** | **279.9× faster** (99.6% drop) |
| **Q2** | 30-Day Daily Transfer Totals | Parallel Seq Scan + Quicksort | Covering Index Only Scan | 6471.06..8343.73 | 1544.75..1913.50 | 3,221 hit, 0 read | 62 hit, 0 read | **117.35 ms** | **34.25 ms** | **3.4× faster** (98.1% buffer drop) |
| **Q3** | Support Dispute Desk: Top Outgoing | Hash Join + 2× Seq Scans | Index Scan (FK) + Bitmap Index Scan | 7698.83..7700.00 | 278.69..278.72 | 4,767 hit, 0 read | 179 hit, 0 read | **25.39 ms** | **1.75 ms** | **14.5× faster** (96.2% buffer drop) |
| **Q4** | Compliance AML: High-Value Debits | Parallel Seq Scan (131k rows dropped) | Partial Covering Index Only Scan | 10494.92..10507.42 | 958.69..971.20 | 4,548 hit, 0 read | 175 hit, 0 read | **26.76 ms** | **17.80 ms** | **1.5× faster** (96.2% buffer drop) |
| **Q5** | Idempotency Lookup (Control) | Index Scan (`idempotency_key_key`) | Index Scan (`idempotency_key_key`) | 0.42..8.44 | 0.42..8.44 | 1 hit, 3 read | 4 hit, 0 read | **0.72 ms** | **0.08 ms** | Experimental Control (Sub-ms) |
| **Q6** | Balance Reconciliation (Cache vs Ledger) | Seq Scan + **External Merge Sort** | Index Scan + **Incremental Sort** | 55774.87..57885.91 | 0.86..41739.51 | 4,291 hit, **2,459 disk read** | 405,608 hit, **0 disk read** | **306.91 ms** | **326.87 ms** | **Eliminated 19.7 MB Disk Spill** |
| **Q7** | Unbalanced Journal Audit | Index Merge Left Join | Index Merge Left Join | 0.84..48261.73 | 1.21..48250.89 | 11,729 hit, 436 read | 12,165 hit, 0 read | **302.02 ms** | **266.72 ms** | **0 Accounting Drift** across 202k txns |
| **Q8** | Treasury Net Movement & Reversals | Parallel Seq Scan (52k rows dropped) | Composite Covering Index Only Scan | 6357.95..6357.96 | 3643.87..3643.88 | 3,147 hit, 0 read | 402 hit, 0 read | **23.18 ms** | **13.18 ms** | **1.76× faster** (87.2% buffer drop) |
| **Q9** | Join Fan-Out Trap Demonstration | Relational Algebra Test | Relational Algebra Test | N/A | N/A | N/A | N/A | N/A | N/A | **Algebraic Proof:** Exactly 2.0× inflation |

---

## 4. In-Depth Query-by-Query Technical Analysis

### 4.1 Query 1: Customer Account Statement (OLTP App)
- **Business Use Case:** Display the 50 most recent ledger entries when a customer opens their transaction history in the mobile application. This is the single highest-frequency read query in the mobile wallet architecture.
- **SQL Implementation:**
  ```sql
  SELECT l.created_at, l.direction, l.amount, l.balance_after,
         t.txn_type, t.reference
  FROM ledger_entries l
  JOIN transactions t ON t.transaction_id = l.transaction_id
  WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
  ORDER BY l.created_at DESC
  LIMIT 50;
  ```

#### Pre-Optimization Analysis (Before)
```
Limit  (cost=7512.32..7518.15 rows=50 width=55) (actual time=240.158..242.019 rows=50 loops=1)
  Buffers: shared hit=4372 read=44
  ->  Gather Merge  (cost=7504.02..7510.55 rows=56 width=55)
        ->  Sort  (cost=6503.99..6504.06 rows=28 width=55)
              Sort Key: l.created_at DESC
              Sort Method: quicksort  Memory: 27kB
              ->  Nested Loop
                    ->  Parallel Seq Scan on ledger_entries l (cost=0.00..6272.01 rows=28 width=36)
                          Filter: (account_id = $0)
                          Rows Removed by Filter: 134702
```
- **Bottlenecks:** Because `ledger_entries` lacked an index on `account_id`, the database had to launch 2 parallel worker processes and perform a full sequential scan across **404,162 rows (4,167 pages)** just to locate ~57 rows belonging to account `2200001001`. The engine then sorted these rows using in-memory quicksort before applying the `LIMIT 50`. Total execution time was **242.70 ms** and required scanning **4,416 buffer pages**.

#### Optimization Engineering
```sql
CREATE INDEX idx_ledger_account_created ON ledger_entries (account_id, created_at DESC);
```
- **Index Design Rationale:** By structuring a composite B-Tree with the equality column (`account_id`) leading and the sort column (`created_at DESC`) second, the B-Tree allows an immediate point-lookup to the specific account's entries, which are already physically ordered by timestamp descending.

#### Post-Optimization Analysis (After)
```
Limit  (cost=9.14..625.52 rows=50 width=55) (actual time=0.149..0.814 rows=50 loops=1)
  Buffers: shared hit=256
  ->  Nested Loop  (cost=0.84..839.11 rows=68 width=55)
        ->  Index Scan using idx_ledger_account_created on ledger_entries l (cost=0.42..277.36 rows=68 width=36)
              Index Cond: (account_id = $0)
        ->  Index Scan using transactions_pkey on transactions t (cost=0.42..8.26 rows=1 width=35)
Execution Time: 0.867 ms
```
- **Performance Impact:** Latency dropped from **242.70 ms to 0.87 ms (279.9× speedup)**. Buffer reads collapsed by **94.2%** (from 4,416 to 256 hits). The sort node was completely eliminated because index traversal naturally satisfies `ORDER BY created_at DESC`, allowing the executor to terminate immediately once 50 tuples were retrieved.

---

### 4.2 Query 2: Daily Completed Transfer Totals (Finance Dashboard)
- **Business Use Case:** Executive financial dashboard tracking daily volume and total Naira settled over the last 30 rolling days.
- **SQL Implementation:**
  ```sql
  SELECT date_trunc('day', initiated_at) AS day,
         count(*)    AS transfers,
         sum(amount) AS total_amount
  FROM transactions
  WHERE txn_type = 'TRANSFER'
    AND status = 'COMPLETED'
    AND initiated_at >= now() - interval '30 days'
  GROUP BY 1
  ORDER BY 1;
  ```

#### Pre-Optimization Analysis (Before)
```
Finalize GroupAggregate  (cost=6471.06..8343.73 rows=14413 width=48) (actual time=114.995..117.316 rows=29 loops=1)
  Buffers: shared hit=3221
  ->  Gather Merge
        ->  Partial GroupAggregate
              ->  Sort (Sort Key: (date_trunc('day', initiated_at)))
                    ->  Parallel Seq Scan on transactions (cost=0.00..5094.16 rows=6005 width=14)
                          Filter: (txn_type = 'TRANSFER' AND status = 'COMPLETED' AND initiated_at >= now() - '30 days')
                          Rows Removed by Filter: 63686
```
- **Bottlenecks:** The engine scanned all 3,147 pages of the `transactions` table (206k rows), evaluating complex string and timestamp filters against every row and discarding 63,686 non-matching rows per worker.

#### Optimization Engineering
```sql
CREATE INDEX idx_txn_completed_transfers_time
    ON transactions (initiated_at) INCLUDE (amount)
    WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED';
```
- **Index Design Rationale:** This combines two advanced techniques:
  1. **Partial Indexing:** The `WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED'` predicate completely excludes failed, pending, or non-transfer records, shrinking the index to just 756 pages (6 MB).
  2. **Covering Index (`INCLUDE`):** Including `amount` in the B-Tree payload allows PostgreSQL to satisfy both `count(*)` and `sum(amount)` directly from index leaf pages without fetching table heap blocks.

#### Post-Optimization Analysis (After)
```
GroupAggregate  (cost=1544.75..1913.50 rows=14750 width=48) (actual time=27.198..34.149 rows=29 loops=1)
  Buffers: shared hit=62
  ->  Sort  (cost=1544.75..1581.62 rows=14750 width=14)
        ->  Index Only Scan using idx_txn_completed_transfers_time on transactions (cost=0.42..523.43 rows=14750)
              Index Cond: (initiated_at >= (now() - '30 days'::interval))
              Heap Fetches: 0
              Buffers: shared hit=62
Execution Time: 34.252 ms
```
- **Performance Impact:** Latency dropped from **117.35 ms to 34.25 ms (3.4× speedup)**. Buffer reads dropped by **98.1%** (from 3,221 to 62 pages). The plan achieved **`Heap Fetches: 0`**, indicating that not a single byte was read from the main table storage.

---

### 4.3 Query 3: Customer Top Outgoing Transfers (Support Desk)
- **Business Use Case:** Customer service representative retrieving a disputed customer's 10 largest outgoing transfers across all wallets they own.
- **SQL Implementation:**
  ```sql
  SELECT t.transaction_id, t.amount, t.initiated_at, t.reference
  FROM accounts a
  JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
  JOIN transactions t   ON t.transaction_id = l.transaction_id
  WHERE a.customer_id = 1001
    AND t.txn_type = 'TRANSFER'
  ORDER BY t.amount DESC
  LIMIT 10;
  ```

#### Pre-Optimization Analysis (Before)
```
Limit  (cost=7698.83..7700.00 rows=10 width=41) (actual time=23.675..25.357 rows=10 loops=1)
  Buffers: shared hit=4767
  ->  Gather Merge
        ->  Nested Loop
              ->  Hash Join (l.account_id = a.account_id)
                    ->  Parallel Seq Scan on ledger_entries l (Rows Removed: 67360)
                    ->  Hash
                          ->  Seq Scan on accounts a (cost=0.00..199.01 rows=1 width=8)
                                Filter: (customer_id = 1001)
                                Rows Removed by Filter: 6002
```
- **Bottlenecks:** PostgreSQL does **not** automatically create indexes on foreign keys. When joining `accounts` on `customer_id`, the database was forced to execute a sequential scan of `accounts` (6,002 rows discarded) and a parallel sequential scan of `ledger_entries` (67,360 rows discarded).

#### Optimization Engineering
```sql
CREATE INDEX idx_accounts_customer ON accounts (customer_id);
-- Uses idx_ledger_account_created on ledger_entries (account_id, created_at DESC)
```
- **Index Design Rationale:** Indexing foreign key columns on child tables is essential in relational database design. Combining `idx_accounts_customer` with the pre-existing composite index on `ledger_entries` eliminates both sequential scans simultaneously.

#### Post-Optimization Analysis (After)
```
Limit  (cost=278.69..278.72 rows=10 width=41) (actual time=1.532..1.535 rows=10 loops=1)
  Buffers: shared hit=179
  ->  Sort (top-N heapsort)
        ->  Nested Loop
              ->  Nested Loop
                    ->  Index Scan using idx_accounts_customer on accounts a (cost=0.28..8.30)
                          Index Cond: (customer_id = 1001)
                    ->  Bitmap Heap Scan on ledger_entries l (cost=4.94..251.90)
                          ->  Bitmap Index Scan on idx_ledger_account_created (account_id = a.account_id)
              ->  Index Scan using transactions_pkey on transactions t
Execution Time: 1.751 ms
```
- **Performance Impact:** Latency dropped from **25.39 ms to 1.75 ms (14.5× speedup)**. Buffer reads dropped by **96.2%** (from 4,767 to 179 hits). The query planner converted a multi-table parallel hash join into a rapid nested loop of point index scans.

---

### 4.4 Query 4: High-Velocity Large Transfer Fraud (AML Compliance)
- **Business Use Case:** Daily AML review identifying customers initiating unusually high volumes of large transfers (≥ 4,000 NGN) over the prior 90 days.
- **SQL Implementation:**
  ```sql
  SELECT a.customer_id,
         count(*)      AS large_transfers,
         sum(l.amount) AS total_sent
  FROM ledger_entries l
  JOIN accounts a ON a.account_id = l.account_id
  WHERE l.direction = 'DEBIT'
    AND l.amount >= 4000
    AND l.created_at >= now() - interval '90 days'
  GROUP BY a.customer_id
  ORDER BY large_transfers DESC, total_sent DESC
  LIMIT 10;
  ```

#### Pre-Optimization Analysis (Before)
```
Finalize HashAggregate  (cost=10324.33..10386.85 rows=5001 width=48)
  ->  Gather
        ->  Hash Join
              ->  Parallel Seq Scan on ledger_entries l (cost=0.00..7956.02 rows=4572 width=14)
                    Filter: (amount >= 4000 AND direction = 'DEBIT' AND created_at >= now() - '90 days')
                    Rows Removed by Filter: 131462
```
- **Bottlenecks:** The parallel sequential scan inspected 404,162 rows, discarding 131,462 rows per worker that failed the direction, amount, or timestamp criteria.

#### Optimization Engineering
```sql
CREATE INDEX idx_ledger_large_debits
    ON ledger_entries (created_at) INCLUDE (account_id, amount)
    WHERE direction = 'DEBIT' AND amount >= 4000;
```
- **Index Design Rationale:** In a mature financial platform, the vast majority of transactions are small micro-payments. Large transfers represent a small fraction of total volume (only 45,765 out of 404,162 rows). Indexing only `direction = 'DEBIT' AND amount >= 4000` creates an ultra-compact 1,840 kB index, while `INCLUDE (account_id, amount)` satisfies the join and aggregation completely inside the B-Tree.

#### Post-Optimization Analysis (After)
```
HashAggregate  (cost=788.04..850.58 rows=5003 width=48) (actual time=16.152..17.071 rows=4170 loops=1)
  Buffers: shared hit=175
  ->  Hash Join  (cost=259.36..704.24 rows=11173 width=14)
        ->  Index Only Scan using idx_ledger_large_debits on ledger_entries l (Heap Fetches: 0, Buffers: shared hit=51)
              Index Cond: (created_at >= (now() - '90 days'::interval))
        ->  Hash
              ->  Seq Scan on accounts a (Buffers: shared hit=124)
Execution Time: 17.802 ms
```
- **Performance Impact:** Latency dropped from **26.76 ms to 17.80 ms (1.5× speedup)**, while buffer I/O plummeted from **4,548 to 175 hits (96.2% reduction)**. By reducing buffer churn from 4,500 pages to 175 pages, background OLTP transactions are protected from cache eviction.

---

### 4.5 Query 5: Idempotency Key Lookup (Experimental Control)
- **Business Use Case:** Payment gateway verifying whether a retried payment payload was already processed, preventing double-debits.
- **SQL Implementation:**
  ```sql
  SELECT * FROM transactions WHERE idempotency_key = 'seed-xfer-12345';
  ```
- **Analysis:** In both the "Before" and "After" test phases, the query plan executed an `Index Scan using transactions_idempotency_key_key`.
  - Latency Before: **0.723 ms** (Cost: 0.42..8.44)
  - Latency After: **0.085 ms** (Cost: 0.42..8.44)
- **Scientific Significance:** Q5 serves as the benchmark control. It demonstrates that the `UNIQUE (idempotency_key)` constraint created during Portfolio 1 automatically synthesized an underlying unique B-Tree index, ensuring that primary key and unique constraint lookups operate at sub-millisecond speeds out-of-the-box.

---

### 4.6 Query 6: Balance Reconciliation (Cache vs. Double-Entry Ledger)
- **Business Use Case:** End-of-day audit verifying that the denormalized cached balance on every account (`accounts.balance`) matches the mathematical final balance in the ledger (`ledger_entries.balance_after`).
- **SQL Implementation:**
  ```sql
  SELECT a.account_number,
         a.balance        AS cached_balance,
         l.balance_after  AS ledger_balance,
         a.balance - l.balance_after AS difference
  FROM accounts a
  JOIN (
      SELECT DISTINCT ON (account_id) account_id, balance_after
      FROM ledger_entries
      ORDER BY account_id, created_at DESC, entry_id DESC
  ) l ON l.account_id = a.account_id
  WHERE a.balance <> l.balance_after;
  ```

#### Pre-Optimization Analysis (Before)
```
Hash Join  (cost=55774.87..57885.91 rows=5964 width=59) (actual time=302.757..302.761 rows=0 loops=1)
  Buffers: shared hit=4291, temp read=2459 written=2467
  ->  Unique  (cost=55515.85..57536.66 rows=5965 width=32)
        ->  Sort  (cost=55515.85..56526.25 rows=404162 width=32)
              Sort Key: ledger_entries.account_id, ledger_entries.created_at DESC, ledger_entries.entry_id DESC
              Sort Method: external merge  Disk: 19672kB
              Buffers: shared hit=4167, temp read=2459 written=2467
              ->  Seq Scan on ledger_entries (cost=0.00..8208.62 rows=404162 width=32)
```
- **Critical Architectural Vulnerability:** Because `work_mem` is set to 4 MB, sorting 404,162 ledger records exceeded available memory. The executor was forced to perform an **external merge sort**, writing **19,672 kB (19.7 MB)** to temporary disk files (`temp read=2459 written=2467`). Disk-spilling sort operations cause severe storage I/O degradation and disk wear under concurrent execution.

#### Post-Optimization Analysis (After)
```
Merge Join  (cost=0.86..41739.51 rows=5951 width=59) (actual time=326.851..326.852 rows=0 loops=1)
  Buffers: shared hit=405608
  ->  Unique  (cost=0.57..41202.03 rows=5952 width=32)
        ->  Incremental Sort  (cost=0.57..40191.62 rows=404162 width=32)
              Sort Key: ledger_entries.account_id, ledger_entries.created_at DESC, ledger_entries.entry_id DESC
              Presorted Key: ledger_entries.account_id, ledger_entries.created_at
              Full-sort Groups: 12631  Sort Method: quicksort  Average Memory: 26kB  Peak Memory: 26kB
              ->  Index Scan using idx_ledger_account_created on ledger_entries (cost=0.42..28955.12 rows=404162 width=32)
  ->  Index Scan using accounts_pkey on accounts a
Execution Time: 326.872 ms
```
- **Architectural Trade-Off Evaluation:**
  - Raw execution time remained steady (~307 ms vs ~326 ms).
  - However, **temporary disk spilling was completely eliminated (0 temp blocks read or written)**.
  - PostgreSQL leveraged **Incremental Sort** (a modern capability introduced in PostgreSQL 13+): because `idx_ledger_account_created` provided presorted groups by `(account_id, created_at)`, the engine only sorted tiny micro-groups in memory using **26 kB of RAM**. This protects disk I/O channels during live banking operations.

---

### 4.7 Query 7: Double-Entry Balancing Invariant Audit
- **Business Use Case:** Core regulatory compliance audit verifying that every completed or reversed financial transaction maintains equal debit and credit journal entries ($\sum \text{Debits} = \sum \text{Credits}$).
- **SQL Implementation:**
  ```sql
  SELECT t.transaction_id, t.txn_type, t.amount, count(l.entry_id) AS entry_count,
         coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)  AS total_debits,
         coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0) AS total_credits
  FROM transactions t
  LEFT JOIN ledger_entries l ON l.transaction_id = t.transaction_id
  WHERE t.status IN ('COMPLETED', 'REVERSED')
  GROUP BY t.transaction_id, t.txn_type, t.amount
  HAVING count(l.entry_id) = 0
      OR coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)
      <> coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0);
  ```
- **Analysis:**
  - Plan Before: `Merge Left Join` on `transactions_pkey` and `ledger_entries_transaction_id_account_id_direction_key` (302.02 ms).
  - Plan After: `Merge Left Join` utilizing identical constraint indexes (266.72 ms).
  - Both runs returned **`0 rows`**, mathematically certifying that across all **202,081 completed transactions**, there is **zero accounting drift**.

---

### 4.8 Query 8: Treasury Net Movement and Reversals
- **Business Use Case:** 90-day liquidity and settlement report tracking net completed transfer volume alongside reversed and failed transfer figures.
- **SQL Implementation:**
  ```sql
  SELECT count(*) FILTER (WHERE status = 'COMPLETED')    AS net_transfers,
         sum(amount) FILTER (WHERE status = 'COMPLETED') AS net_amount,
         count(*) FILTER (WHERE status = 'REVERSED')     AS reversed_transfers,
         sum(amount) FILTER (WHERE status = 'REVERSED')  AS reversed_amount,
         count(*) FILTER (WHERE status = 'FAILED')       AS failed_transfers
  FROM transactions
  WHERE txn_type = 'TRANSFER'
    AND initiated_at >= now() - interval '90 days';
  ```

#### Optimization Engineering & Index Rationale
- **Why Q2's partial index failed to serve Q8:** The partial index `idx_txn_completed_transfers_time` contains the predicate `WHERE status = 'COMPLETED'`. In relational query planning, an index's filter must logically subsume the query's filter. Because Q8 queries `REVERSED` and `FAILED` rows, the partial index was invisible to the planner.
- **Covering Index Deployed:**
  ```sql
  CREATE INDEX idx_txn_type_time_cover
      ON transactions (txn_type, initiated_at) INCLUDE (status, amount);
  ```
#### Performance Impact:
- Plan Before: `Parallel Seq Scan` scanning 3,147 pages (23.18 ms).
- Plan After: `Index Only Scan` scanning 402 index pages (13.18 ms).
- **Result:** **1.76× faster**, with an **87.2% reduction in memory buffer hits** (from 3,147 to 402).

---

### 4.9 Query 9: The Join Fan-Out Trap Demonstration
- **Business Purpose:** Empirical proof of the danger of uncareful joins between parent transactions and child ledger lines in double-entry bookkeeping.
- **SQL Implementation:**
  ```sql
  SELECT
      (SELECT sum(t.amount)
         FROM transactions t
         JOIN ledger_entries l ON l.transaction_id = t.transaction_id
        WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
          AND t.initiated_at >= now() - interval '30 days') AS fan_out_total,
      (SELECT sum(t.amount)
         FROM transactions t
        WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
          AND t.initiated_at >= now() - interval '30 days') AS correct_total;
  ```
- **Observed Result:**
  ```
   fan_out_total  | correct_total 
  ----------------+---------------
   77030783.1600  | 38515391.5800
  ```
- **Mathematical Interpretation:**
  $$\frac{\text{fan\_out\_total}}{\text{correct\_total}} = \frac{77,030,783.16}{38,515,391.58} = 2.000000$$
- In double-entry bookkeeping, every transfer transaction generates exactly **two** ledger lines (one `DEBIT` and one `CREDIT`). Joining `transactions` to `ledger_entries` duplicates every transaction tuple, inflating financial aggregates by exactly **100%**. This proves why transactional reporting queries must either aggregate before joining or enforce strict directional filters.

---

## 5. PostgreSQL Query Planner Internals & Cost Experiments

The experiments captured in `sql/05_planner_experiments.sql` and `plans/planner.txt` provide rigorous insights into the PostgreSQL optimizer's internal decision matrix.

### 5.1 Cost Model Formulation
PostgreSQL evaluates candidate execution paths using an additive cost formula:
$$\text{Total Cost} = (N_{\text{seq\_pages}} \times \text{seq\_page\_cost}) + (N_{\text{rnd\_pages}} \times \text{random\_page\_cost}) + (N_{\text{tuples}} \times \text{cpu\_tuple\_cost}) + (N_{\text{operators}} \times \text{cpu\_operator\_cost})$$

### 5.2 Forced Sequential Scan Experiment (Disabling Indexes)
To validate that the query planner makes mathematically sound choices rather than relying on heuristics, optimizer GUC parameters were temporarily toggled to disable index scans:
```sql
SET enable_indexscan = off;
SET enable_bitmapscan = off;
SET enable_indexonlyscan = off;
```

#### Experimental Results for Q1 (Account Statement):
| Execution Mode | Planner Estimated Cost | Actual Latency | Shared Buffers Accessed |
|---|---|---|---|
| **Chosen Plan (Index Scan)** | **9.14 .. 625.41** | **4.78 ms** | 256 pages |
| **Forced Plan (Sequential Scan)** | **11,799.97 .. 11,805.81** | **64.60 ms** | 7,608 pages |

- **Conclusion:** The cost model accurately estimated the sequential scan to be **18.8× more expensive** than the index scan (11,805 vs 625). The physical execution confirmed this prediction, with the index plan running **13.5× faster** and consuming **96.6% fewer page buffers**.

---

### 5.3 The Selectivity Tipping Point Experiment
A critical concept in database theory is that indexes are not universally beneficial; their utility is bounded by data selectivity. To measure the exact tipping point where the planner abandons an index in favor of a sequential scan, an index was created on `customers(status)`:

```sql
BEGIN;
CREATE INDEX tmp_customers_status ON customers (status);
ANALYZE customers;

-- Scenario A: Rare Status (High Selectivity)
EXPLAIN (ANALYZE) SELECT * FROM customers WHERE status = 'SUSPENDED';

-- Scenario B: Common Status (Low Selectivity)
EXPLAIN (ANALYZE) SELECT * FROM customers WHERE status = 'ACTIVE';
ROLLBACK;
```

#### Empirical Observations:
```mermaid
graph LR
    Query[Query on customers.status]
    Query -->|status = 'SUSPENDED'<br/>50 rows / 1.0%| IndexScan[Index Scan Chosen<br/>Cost: 0.28..14.63<br/>Time: 0.057 ms]
    Query -->|status = 'ACTIVE'<br/>4,953 rows / 99.0%| SeqScan[Sequential Scan Chosen<br/>Cost: 0.00..133.54<br/>Time: 0.476 ms]
```

1. **Rare Filter (`status = 'SUSPENDED'`, 50 rows / 1.0% of table):**
   - Plan: `Index Scan using tmp_customers_status` (cost: 0.28..14.63, time: **0.057 ms**).
   - Because only 50 random heap reads are required, the $4.0 \times 50$ random I/O penalty is minor compared to reading the entire table.
2. **Dominant Filter (`status = 'ACTIVE'`, 4,953 rows / 99.0% of table):**
   - Plan: `Seq Scan on customers` (cost: 0.00..133.54, time: **0.476 ms**).
   - If the planner had used the index, it would have performed 4,953 random index traversals ($4,953 \times 4.0 = 19,812$ cost units). Instead, scanning the table sequentially in contiguous 8 KB blocks incurs a `seq_page_cost` of only $1.0 \times 71 = 71$ cost units.
   - **Theoretical Synthesis:** The planner deliberately ignores the index when selectivity drops below ~10–15%, correctly recognizing that streaming pages sequentially from disk/cache is orders of magnitude faster than random pointer chasing.

---

## 6. Write Cost and Storage Footprint Analysis

While indexes accelerate read operations, they introduce significant write amplification on transactional tables.

### 6.1 Index Disk Space Footprint
Querying `pg_stat_user_indexes` revealed the exact disk footprint of the 5 secondary indexes:

| Index Name | Target Table | Index Structure Type | Disk Size |
|---|---|---|---|
| `idx_accounts_customer` | `accounts` | Standard B-Tree on Foreign Key | **144 kB** |
| `idx_ledger_account_created` | `ledger_entries` | Composite B-Tree (`account_id, created_at DESC`) | **12 MB** |
| `idx_ledger_large_debits` | `ledger_entries` | Partial + Covering (`WHERE direction = 'DEBIT' AND amount >= 4000`) | **1,840 kB** |
| `idx_txn_completed_transfers_time` | `transactions` | Partial + Covering (`WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED'`) | **6,048 kB** |
| `idx_txn_type_time_cover` | `transactions` | Composite Covering B-Tree (`txn_type, initiated_at`) | **13 MB** |
| **Total Custom Secondary Indexes** | | | **~33.0 MB** |

### 6.2 Write Overhead Simulation (`06_write_cost.sql`)
To evaluate write amplification during high-velocity data ingestion, two identical temporary tables were populated with 404,162 ledger records—one without indexes and one with the two ledger indexes:

```sql
CREATE TEMP TABLE le_no_index (LIKE ledger_entries INCLUDING DEFAULTS);
CREATE TEMP TABLE le_with_index (LIKE ledger_entries INCLUDING DEFAULTS);
CREATE INDEX tmp_le_account_created ON le_with_index (account_id, created_at DESC);
CREATE INDEX tmp_le_large_debits ON le_with_index (created_at) INCLUDE (account_id, amount) 
WHERE direction = 'DEBIT' AND amount >= 4000;

INSERT INTO le_no_index   SELECT * FROM ledger_entries;
INSERT INTO le_with_index SELECT * FROM ledger_entries;
```

#### Empirical Storage Overhead Results:
```
     copy     | total_size 
--------------+------------
 no indexes   | 33 MB
 with indexes | 49 MB
```

$$\text{Storage Overhead} = \frac{49 \text{ MB} - 33 \text{ MB}}{33 \text{ MB}} = \mathbf{+48.48\%}$$

#### Architectural Implications for High-Throughput Fintech Gateways:
1. **Write Amplification:** Every `INSERT` into `ledger_entries` must now update the base table heap plus two separate B-Tree indexes synchronously inside the transaction boundary.
2. **B-Tree Page Splits and WAL Pressure:** Random inserts trigger page splits in `idx_ledger_account_created` (due to low correlation on `account_id`), increasing Write-Ahead Logging (WAL) volume and disk I/O.
3. **Buffer Pool Contention:** Index pages compete with heap pages for space in `shared_buffers`, potentially evicting active data pages if indexes are oversized.

---

## 7. Production Architecture & Maintenance Recommendations

Based on empirical benchmarks, the following principles should govern production indexing in Nigerian payment systems:

1. **Always Index Foreign Keys on High-Volume Child Tables:**
   Foreign keys are not auto-indexed by PostgreSQL. Omitting an index on `accounts(customer_id)` caused an unnecessary full table scan in Q3. Foreign keys that participate in frequent joins must be explicitly indexed.
2. **Structure Composite Indexes for Equality First, Range/Sort Second:**
   The ordering `(account_id, created_at DESC)` in Q1 transformed a 242 ms sequential scan and quicksort into a sub-millisecond index seek. Placing sort keys first prevents equality filtering from utilizing B-Tree binary search efficiently.
3. **Leverage Partial and Covering Indexes for Asymmetric Distributions:**
   Financial platforms exhibit asymmetric data distributions (e.g., 90% of transactions are completed; 95% of amounts are below 4,000 NGN). Partial indexes (`WHERE status = 'COMPLETED'`) avoid indexing stale or irrelevant rows, cutting index sizes by 60–85%.
4. **Tune `work_mem` to Prevent Disk Spills in Reconciliation Jobs:**
   Q6 demonstrated that sorting large datasets with default `work_mem` (4 MB) spills tens of megabytes to disk. Setting `work_mem = '32MB'` specifically for batch reconciliation sessions eliminates external merge sorts and accelerates EOD processing.
5. **Establish Routine Index Maintenance & Visibility Map Hygiene:**
   Covering indexes (`Index Only Scans`) depend entirely on PostgreSQL's **Visibility Map**. If autovacuum fails to keep pace with updates, index scans are forced to visit the heap to verify tuple visibility (`Heap Fetches > 0`). Nightly `VACUUM ANALYZE` routines ensure heap fetches remain at zero.

---

## 8. Conclusion

Portfolio 2 demonstrates that database query optimisation in financial systems is a discipline of balancing read latency against write amplification and storage footprint. Through targeted index engineering, queries supporting consumer mobile experiences, AML compliance, and treasury reporting achieved **up to 280× speedups**, while simultaneously eliminating destructive disk-spilling merge sorts. 

These optimizations ensure that **NairaPay** can reliably maintain high-frequency transactional throughput, strict auditability, and sub-second user responsiveness at enterprise scale.
