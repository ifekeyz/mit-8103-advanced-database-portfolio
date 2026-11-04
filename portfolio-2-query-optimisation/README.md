# Portfolio 2: Query Optimisation and Performance Tuning

**Case study:** NairaPay, a simulated Nigerian fintech wallet and transfer platform  
**Course:** MIT 8103 – Advanced Database Systems  
**DBMS:** PostgreSQL 16.14 (Homebrew / aarch64-apple-darwin), managed with psql and pgAdmin 4  
**Database:** `nairapay_db`  
**Dataset Scale:** 404,162 ledger entries (~33 MB), 206,096 transactions (~25 MB), 6,003 accounts, 5,003 customers  
**Detailed Report:** [performance-analysis.md](performance-analysis.md)

---

## 1. Project Overview

In **Portfolio 1**, the foundational schema for `nairapay_db` was engineered and verified with strict ACID constraints, double-entry financial bookkeeping, and referential integrity. In accordance with proper benchmarking methodology, no non-primary performance indexes were deployed during Portfolio 1.

**Portfolio 2** executes comprehensive query optimisation, execution plan analysis, index engineering, and planner cost model evaluation. Using real-world fintech OLTP workloads (account statements, daily transaction aggregations, dispute investigations, AML fraud detection, balance reconciliation, and financial invariant auditing), this portfolio demonstrates:

1. **Before-and-After Execution Plan Analysis:** Measuring exact execution time, planner cost estimates, heap block scans, and memory/disk buffer usage via `EXPLAIN (ANALYZE, BUFFERS)`.
2. **Targeted Index Engineering:** Implementing composite B-Trees with equality-first sorting, foreign key indexing, partial indexes, and covering indexes with `INCLUDE` clauses.
3. **Planner Cost Model Validation:** Experimentally testing PostgreSQL cost estimation parameters (`random_page_cost`, `seq_page_cost`, correlation) and selectivity break-even thresholds.
4. **Trade-Off Analysis:** Quantifying write amplification, index storage footprints, and disk-spill mitigation vs. high-throughput OLTP ingestion costs.
5. **Relational Correctness:** Proving the Join Fan-Out trap inherent in double-entry financial models.

---

## 2. Repository Structure

```
portfolio-2-query-optimisation/
├── README.md                      # Project overview and quick reproduction guide (this file)
├── performance-analysis.md        # Comprehensive 360-degree technical and academic analysis
├── plans/                         # Raw benchmark outputs and planner execution logs
│   ├── before.txt                 # EXPLAIN (ANALYZE, BUFFERS) outputs before indexes
│   ├── after.txt                  # EXPLAIN (ANALYZE, BUFFERS) outputs after indexes
│   ├── planner.txt                # System configuration, forced-plan experiments, selectivity tests
│   └── results.txt                # Result sets and financial invariant audit verification
├── queries/                       # Standalone SQL queries representing core business use cases
│   ├── q01_account_statement.sql           # Recent wallet statement (OLTP customer app)
│   ├── q02_daily_transfer_totals.sql       # 30-day transfer metrics (Finance dashboard)
│   ├── q03_customer_largest_transfers.sql  # High-value transfers (Support dispute desk)
│   ├── q04_large_transfer_fraud.sql        # High-velocity transfer fraud (AML compliance)
│   ├── q05_idempotency_lookup.sql          # Control query (Unique constraint index)
│   ├── q06_balance_reconciliation.sql      # Cached vs ledger balance check (Invariant audit)
│   ├── q07_unbalanced_journals.sql         # Double-entry balance check (Invariant audit)
│   ├── q08_net_movement_reversals.sql      # Treasury report with reversals
│   └── q09_join_fanout_trap.sql            # Fan-out trap demonstration (Financial algebra)
├── screenshots/                   # Graphical evidence and plan visualisations
│   └── .gitkeep
└── sql/                           # Automated batch execution scripts
    ├── 01_capture_plans.sql       # Captures EXPLAIN (ANALYZE, BUFFERS) for Q1–Q8
    ├── 02_query_results.sql       # Executes all queries and outputs result rows
    ├── 03_create_indexes.sql      # Creates the 5 production indexes + runs ANALYZE
    ├── 04_drop_indexes.sql        # Cleanly removes all custom indexes + resets planner
    ├── 05_planner_experiments.sql  # Planner internals, cost settings, forced plans, selectivity
    └── 06_write_cost.sql          # Quantifies index storage footprint and insert write cost
```

---

## 3. Step-by-Step Reproduction Guide

All tests are fully reproducible against the `nairapay_db` database using `psql`:

### Step 1: Ensure Baseline State (No Secondary Indexes)
To ensure the database begins in the unindexed baseline state:
```bash
psql -d nairapay_db -f sql/04_drop_indexes.sql
```

### Step 2: Capture Baseline Execution Plans (Before)
Run all 8 benchmark queries without custom indexes and save the plans:
```bash
psql -d nairapay_db -f sql/01_capture_plans.sql > plans/before.txt
```

### Step 3: Deploy Targeted Production Indexes
Apply the 5 engineered indexes and gather fresh optimizer statistics:
```bash
psql -d nairapay_db -f sql/03_create_indexes.sql
```

### Step 4: Capture Optimised Execution Plans (After)
Run the identical benchmark queries against the indexed schema:
```bash
psql -d nairapay_db -f sql/01_capture_plans.sql > plans/after.txt
```

### Step 5: Execute Planner & Cost Model Experiments
Run configuration probes, forced sequential scan comparisons, and selectivity threshold experiments:
```bash
psql -d nairapay_db -f sql/05_planner_experiments.sql > plans/planner.txt
```

### Step 6: Verify Query Correctness and Invariants
Execute all queries to confirm exact numerical consistency and verify accounting integrity:
```bash
psql -d nairapay_db -f sql/02_query_results.sql > plans/results.txt
```

### Step 7: Quantify Write Overhead & Storage Footprint
Simulate bulk write costs and measure index disk utilization:
```bash
psql -d nairapay_db -f sql/06_write_cost.sql
```

---

## 4. Benchmark Summary (The 9 Queries)

The table below summarizes the quantitative performance delta captured before and after index implementation across all 9 queries on a dataset of 404,162 ledger entries and 206,096 transactions.

| Query | Business Use Case | Plan Before | Plan After | Latency (Before) | Latency (After) | Speedup / Impact | Buffer I/O Reduction |
|---|---|---|---|---|---|---|---|
| **Q1** | Account Statement (Recent 50 lines) | Parallel Seq Scan + Quicksort | Index Scan (`account_id, created_at DESC`) | **242.70 ms** | **0.87 ms** | **~280× faster** | **94.2%** (4,416 → 256 hits) |
| **Q2** | Daily Transfer Totals (30 days) | Parallel Seq Scan + Quicksort | Covering Index Only Scan | **117.35 ms** | **34.25 ms** | **~3.4× faster** | **98.1%** (3,221 → 62 hits) |
| **Q3** | Customer Top Outgoing Transfers | Hash Join + 2× Seq Scans | Index Scan on FK + Bitmap Index Scan | **25.39 ms** | **1.75 ms** | **~14.5× faster** | **96.2%** (4,767 → 179 hits) |
| **Q4** | High-Velocity AML Fraud Detection | Parallel Seq Scan (131k rows filtered) | Partial Covering Index Only Scan | **26.76 ms** | **17.80 ms** | **~1.5× faster** | **96.2%** (4,548 → 175 hits) |
| **Q5** | Idempotency Lookup (Control) | Index Scan (Unique Constraint) | Index Scan (Unique Constraint) | **0.72 ms** | **0.08 ms** | Baseline Control | Preserved sub-ms lookup |
| **Q6** | Balance Reconciliation (Cache vs Ledger) | Seq Scan + **External Disk Merge Sort (19.7 MB)** | Index Scan + **Incremental Sort (26 kB RAM)** | 306.91 ms | 326.87 ms | **Zero Disk Spill** | **100% Temp Disk I/O eliminated** |
| **Q7** | Unbalanced Journal Audit | Index Merge Left Join | Index Merge Left Join | 302.02 ms | 266.72 ms | **0 Invariant Errors** | Scans 404k lines in 266 ms |
| **Q8** | Treasury Net Movement & Reversals | Parallel Seq Scan (52k rows filtered) | Composite Covering Index Only Scan | **23.18 ms** | **13.18 ms** | **~1.76× faster** | **87.2%** (3,147 → 402 hits) |
| **Q9** | Join Fan-Out Trap Demonstration | N/A (Relational Trap Proof) | N/A (Relational Trap Proof) | N/A | N/A | **Algebraic Proof** | Fan-out total is exactly 2.0× correct |

---

## 5. Key Indexing Strategies Deployed

### 1. Composite B-Tree with Equality-First Sorting (`idx_ledger_account_created`)
```sql
CREATE INDEX idx_ledger_account_created ON ledger_entries (account_id, created_at DESC);
```
- **Rationale:** Powers Q1 and Q3. Placing the equality filter (`account_id`) leading the index allows PostgreSQL to seek directly to the customer's wallet entries and traverse them in pre-sorted reverse chronological order (`created_at DESC`), completely eliminating in-memory or disk sorting and supporting `LIMIT 50` short-circuiting.

### 2. Foreign Key B-Tree Indexing (`idx_accounts_customer`)
```sql
CREATE INDEX idx_accounts_customer ON accounts (customer_id);
```
- **Rationale:** PostgreSQL automatically creates indexes on `PRIMARY KEY` and `UNIQUE` constraints, but **never automatically indexes foreign keys**. Without this index, joining `accounts` to `customers` in Q3 forced a full table scan on `accounts` (6,003 rows).

### 3. Partial + Covering Index (`idx_txn_completed_transfers_time`)
```sql
CREATE INDEX idx_txn_completed_transfers_time
    ON transactions (initiated_at) INCLUDE (amount)
    WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED';
```
- **Rationale:** Powers Q2. By indexing only successful transfers (`WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED'`), the index size is drastically reduced to 6,048 kB. Adding `INCLUDE (amount)` allows the engine to compute `count(*)` and `sum(amount)` directly from index pages via an **Index Only Scan**, achieving 0 heap fetches and a 98.1% drop in buffer reads.

### 4. High-Selectivity Partial Index (`idx_ledger_large_debits`)
```sql
CREATE INDEX idx_ledger_large_debits
    ON ledger_entries (created_at) INCLUDE (account_id, amount)
    WHERE direction = 'DEBIT' AND amount >= 4000;
```
- **Rationale:** Powers AML fraud detection in Q4. Of 404,162 ledger entries, only 45,765 qualify as large debits (≥ 4,000 NGN). This partial index occupies just 1,840 kB (compared to 12 MB for a full index) and satisfies the 90-day filter without touching the underlying table heap.

### 5. Multi-Status Covering Index (`idx_txn_type_time_cover`)
```sql
CREATE INDEX idx_txn_type_time_cover
    ON transactions (txn_type, initiated_at) INCLUDE (status, amount);
```
- **Rationale:** Powers Q8. Because Q8 aggregates across `COMPLETED`, `REVERSED`, and `FAILED` statuses, it cannot use the partial index from Q2. This broad covering index allows the planner to execute an Index Only Scan across 48k rows in 13.18 ms without heap fetches.

---

## 6. Planner Experiments & Key Insights

1. **Planner Cost Model Accuracy:**
   - Forcing sequential scans via `SET enable_indexscan = off` in `05_planner_experiments.sql` showed that PostgreSQL estimated the sequential plan at cost **11,805.81** vs **625.41** for the index plan. The actual execution times validated this prediction: **64.60 ms** (sequential) vs **0.87 ms** (index).
2. **Selectivity Tipping Point:**
   - In `customers(status)`, querying a rare value (`SUSPENDED`, 50 rows / ~1% selectivity) triggered an **Index Scan** (0.057 ms).
   - Querying a common value (`ACTIVE`, 4,953 rows / ~99% selectivity) prompted the planner to bypass the index in favor of a **Parallel Sequential Scan** (0.476 ms).
   - This empirically demonstrates the optimizer's tipping point: when a large portion of a table is accessed, the sequential page cost (`seq_page_cost = 1.0`) is significantly cheaper than repeated random lookups (`random_page_cost = 4.0`).
3. **Storage vs. Write Performance Trade-Off:**
   - Running `06_write_cost.sql` demonstrated that adding 2 indexes to `ledger_entries` increased table relation size from **33 MB to 49 MB (+48.5% storage overhead)**.
   - In high-throughput fintech ledgers, indexes cannot be applied indiscriminately. Every index adds synchronous CPU and disk I/O overhead on `INSERT` and `UPDATE` statements.

---

## 7. Financial Invariant & Correctness Auditing

Financial databases require mathematical guarantees of correctness. Three queries verified these core invariants:

- **Balance Reconciliation (Q6):** Confirmed **0 discrepancy rows** between cached account balances (`accounts.balance`) and the latest double-entry ledger state (`ledger_entries.balance_after`).
- **Journal Integrity (Q7):** Confirmed **0 unbalanced transactions** across all 202,081 completed/reversed operations ($\sum \text{Debits} = \sum \text{Credits}$).
- **The Join Fan-Out Trap (Q9):** Demonstrated that improperly joining `transactions` directly to `ledger_entries` results in exactly double the expected aggregate ($77,030,783.16$ NGN vs $38,515,391.58$ NGN), proving why double-entry ledgers require pre-aggregation or directional filters.

---

## 8. Reflection

Query optimisation in financial ledgers is fundamentally an exercise in navigating trade-offs between read latency, storage amplification, write throughput, and algorithmic invariants:

- **The Power of Equality-First Indexing:** Structuring composite indexes with equality columns preceding sort columns (`account_id, created_at DESC`) yields the most dramatic performance gains (280× speedup on Q1), transforming high-frequency OLTP bottlenecks into instant point-lookups.
- **Covering and Partial Indexes as Superpowers:** By using partial indexes (`WHERE amount >= 4000`) and payload inclusion (`INCLUDE (amount)`), we eliminated 96–98% of buffer page fetches and enabled zero-heap Index Only Scans while keeping index sizes under 2–6 MB.
- **The Invisible Hazard of Disk Spilling:** High cost is not always reflected in execution time alone. In Q6, eliminating a 19.7 MB external disk merge sort protected the disk subsystem from I/O thrashing under concurrent load, which is far more critical in production than raw millisecond gains.
- **Architectural Discipline:** Because write amplification adds ~48.5% storage overhead to the core ledger, indexing must be deliberate, targeted, and backed by empirical query plans rather than speculative intuition.
