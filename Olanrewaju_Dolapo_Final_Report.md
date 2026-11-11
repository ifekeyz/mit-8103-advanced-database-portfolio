# Final Synthesis Report: Advanced Database Systems Portfolio

**Course:** MIT 8103 – Advanced Database Systems  
**Session:** 2026/2027 Academic Session (September Cohort)  
**Institution:** Miva Open University — School of Post Graduate Studies  
**Assessment Type:** Individual Practical Database Portfolio (40 Marks Continuous Assessment)  
**Student Surname:** Olanrewaju  
**Student First Name:** Dolapo  
**Student ID:** 301911958  
**Student University Email:** dolapo.olanrewaju@miva.university  
**Chosen Case Study:** **NairaPay Technologies Limited** (Simulated Nigerian Digital Wallet & Payment Platform)  
**GitHub Repository URL:** https://github.com/ifekeyz/MIVA.git  

---

## 1. Executive Summary & Enterprise Case Study Profile

Digital financial technology in Nigeria operates under unique environmental, architectural, and statutory demands. Peer-to-peer (P2P) transfers, bill payments, and merchant settlement operations run over distributed networks characterized by intermittent connectivity, aggressive client retries, and high concurrency on shared wallets. Simultaneously, platforms must adhere to statutory mandates established by the Central Bank of Nigeria (CBN)—including tiered Know-Your-Customer (KYC) onboarding, the Nigeria Uniform Bank Account Number (NUBAN) format, and strict auditability under the Nigeria Data Protection Act (NDPA).

**NairaPay Technologies Limited** is a simulated high-growth Nigerian mobile payment service provider. To support millions of daily transactions without financial drift, NairaPay requires an enterprise data architecture combining:
1. **An Immutable Relational Core:** PostgreSQL 16 enforcing strict 3NF modeling, double-entry bookkeeping, ACID transaction isolation, and deterministic row locking.
2. **A Scalable Semi-Structured Document Store:** MongoDB 7 (local container and managed multi-AZ cloud replica set on MongoDB Atlas) handling polymorphic identity verification documents, append-only security audit streams, and ephemeral login sessions.

This final synthesis report consolidates the five practical portfolio modules executed across the semester, demonstrating end-to-end database engineering from initial conceptual schema design to distributed cloud replication and high-availability failover.

---

## 2. Synthesis of Portfolio Deliverables (Portfolios 1 to 5)

### Portfolio 1: Relational Database Design and Data Modelling
- **Objective:** Establish the foundational schema for `nairapay_db` adhering to strict Third Normal Form (3NF), ACID constraints, and double-entry accounting principles.
- **Implementation & Invariants:**
  - Designed an 8-table relational schema: `customers`, `kyc_records`, `accounts`, `beneficiaries`, `transactions`, `ledger_entries`, `cards`, and `fraud_flags`.
  - Financial quantities are strictly typed as `NUMERIC(19,4)` to prevent IEEE-754 floating-point rounding corruption.
  - Implemented immutable double-entry bookkeeping: every financial movement generates paired `DEBIT` and `CREDIT` rows in `ledger_entries`, with `accounts.balance` serving as an optimized cached projection of the ledger sum.
  - Enforced NUBAN account validation via regular expressions (`^[0-9]{10}$`), transaction idempotency keys (`UNIQUE`), and referential integrity via `ON DELETE RESTRICT` on all ledger tables to preserve financial audit history.
  - Verified robustness through a test suite of 10 negative constraint violations (e.g., overdraft attempts, duplicate emails, invalid risk scores, and orphan foreign keys), all rejected by PostgreSQL.

### Portfolio 2: Query Optimisation and Performance Tuning
- **Objective:** Profile execution plans, eliminate resource bottlenecks, and engineer targeted secondary B-Tree indexes across an enterprise dataset of **404,162 ledger entries**, **206,096 transactions**, and **6,003 accounts**.
- **Empirical Findings & Speedups:**
  - **Statement Retrieval (Q1):** Dropped from **242.70 ms** (Parallel Seq Scan + Quicksort) to **0.87 ms** (**279.9× speedup**) using an equality-first composite index on `(account_id, created_at DESC)`. Buffer page reads dropped by 99.6%.
  - **Elimination of Disk Spills (Q6):** Balance reconciliation previously forced an external merge sort spilling **19.7 MB** of temporary data to disk. Deploying index-assisted **Incremental Sort** completely eliminated temp disk I/O.
  - **Mathematical Proof of Join Fan-Out (Q9):** Empirically demonstrated that naive multi-table joins between unaggregated 1:N relations inflate financial ledger sums by exactly **2.0×**, reinforcing the necessity of subquery aggregation before joining.

### Portfolio 3: Transactions, Concurrency Control, and ACID Integrity
- **Objective:** Prevent race conditions, double-spending, and deadlocks under concurrent multi-session execution.
- **Architectural Breakthroughs:**
  - **The Lost Update Vulnerability:** Proved that checking balances in application code without row-level locking approves concurrent overdrafts with **zero database errors**, silently corrupting ledger balances.
  - **Deterministic Resource Ordering:** Resolved bidirectional transfer deadlocks in `transfer_funds()` by sorting account lock acquisitions numerically:
    $$\text{first\_id} = \min(\text{from\_id}, \text{to\_id}), \quad \text{second\_id} = \max(\text{from\_id}, \text{to\_id})$$
    Acquiring locks via `SELECT ... FOR UPDATE` on `first_id` then `second_id` mathematically eliminates Coffman's circular wait condition.
  - **High-Contention Stress Benchmarks (`pgbench`):** Running 10 concurrent clients across 20 hot wallets revealed that unordered locking suffered **56 deadlock aborts** and a **164.3× throughput collapse** down to **47.62 TPS** (due to 1-second `deadlock_timeout` stalls). In contrast, deterministic ordered locking executed **2,000 transactions with 0 failures** at **7,822.49 TPS**.
  - **Conservation of Money:** Verified that total currency remained invariant at **1,000,000,000,000.0000 NGN** (One Trillion Naira) across all stress runs with zero accounting drift.

### Portfolio 4: NoSQL and Advanced Data Models (MongoDB)
- **Objective:** Implement polyglot persistence, deploying MongoDB 7 alongside PostgreSQL for heterogeneous and high-throughput semi-structured domains.
- **Design & Performance Results:**
  - **Embedded KYC Dossiers (`kyc_profiles`):** Replaced relational EAV anti-patterns by embedding polymorphic identity documents (passports, driver's licenses, utility bills) inside customer documents. Governed structural integrity via database-level `$jsonSchema` validators (`validationAction: 'error'`).
  - **Referenced Audit Trails (`audit_events`):** Modelled high-frequency security events as independent documents to prevent breaching the 16 MB BSON document limit.
  - **B-Tree Indexing:** Compound indexing on `{ customer_id: 1, ts: -1 }` transformed audit event queries from a **65 ms `COLLSCAN > SORT`** examining 100,000 documents into a **1 ms `IXSCAN > FETCH > LIMIT`** examining exactly 20 documents (**65× speedup**).
  - **Automated Lifecycle Management:** Deployed a Time-To-Live (TTL) index on `login_sessions` (`expireAfterSeconds: 3600`), delegating session purging to background database threads.

### Portfolio 5: Distributed Databases, Replication, and Cloud Deployment
- **Objective:** Engineer physical streaming replication, evaluate CAP/PACELC trade-offs, model horizontal sharding, and integrate a managed cloud replica set.
- **Distributed Discoveries:**
  - **Streaming Replication:** Configured master-standby WAL streaming from primary (`:5433`) to read replica (`:5434`) using persistent replication slots (`replica1_slot`), achieving sub-millisecond replay latency.
  - **The Stale Read Phenomenon:** Paused the standby container and proved that asynchronous replication introduces a stale read window where newly committed primary tables do not exist on the replica until WAL catch-up occurs.
  - **The Synchronous Write Hang:** Demonstrated that setting `synchronous_commit = on` with an unresponsive standby halts 100% of primary write availability, proving that financial architectures require quorum synchronous standby sets (`ANY 1 (standby1, standby2)`).
  - **Declarative Hash Partitioning:** Divided 412,058 ledger entries across 4 hash partitions on `account_id`, proving that keyed queries activate **Partition Pruning** (scanning only 1 partition), whereas non-keyed queries require parallel **Scatter-Gather** scans.
  - **Cloud Resilience (MongoDB Atlas):** Verified a 3-node multi-availability-zone replica set in the cloud, enforcing `w: majority` write durability (acknowledged across multiple availability zones in 184 ms) and secondary read offloading (`readPref('secondary')`).

---

## 3. Technical Reflection & Individual Understanding

Completing this advanced database systems portfolio fundamentally transformed my approach to software and data architecture. Before this course, I viewed database management systems primarily as passive data stores accessed through object-relational mappers (ORMs). Through rigorous empirical testing, I now appreciate the database engine as an active, highly sophisticated distributed operating system.

### Key Insights Acquired:
1. **The Fallacy of Application-Level Correctness:** Single-threaded application logic cannot guarantee financial invariants. As demonstrated in Portfolio 3, checking account balances in Python or JavaScript and issuing an `UPDATE` creates an exploitable double-spending vulnerability. Absolute correctness requires pushing constraints, row locks (`FOR UPDATE`), and atomic double-entry updates directly into database transactions.
2. **Deadlock Prevention vs. Resolution:** While PostgreSQL's deadlock detector correctly aborts circular waits, the 1-second timeout penalty causes catastrophic throughput collapse (164× drop). Preventing deadlocks architecturally through deterministic resource ordering ($\min$ then $\max$) is vastly superior to reactive engine resolution.
3. **Polyglot Persistence is Essential:** There is no single universal database. Forcing polymorphic KYC documents into relational tables creates maintenance nightmares, while moving the double-entry ledger to MongoDB sacrifices declarative foreign keys and transactional guarantees. The modern enterprise solution is polyglot persistence: PostgreSQL for financial truth and MongoDB for flexible documents and event streams.
4. **The CAP Trade-Off is an Operational Reality:** Simulating network partitions and standby outages in Portfolio 5 proved that distributed consistency has a physical cost. Understanding the difference between RPO and RTO, fencing against split-brain scenarios, and designing quorum-based consensus are essential competencies for any senior database engineer.

---

## 4. Academic Integrity & AI-Use Declaration

In compliance with Miva Open University's academic integrity policies:
- **AI Tool Utilization:** Generative AI tools (Claude Code & Antigravity) were used as pair-programming assistants for syntax scaffolding, Docker Compose debugging, benchmark script structuring, and report formatting.
- **Verification & Ownership:** Every SQL function, JavaScript script, Docker container, and `pgbench` stress test was executed, debugged, and validated locally on my macOS development workstation. Every performance metric, execution plan, row count, and terminal screenshot cited in this report represents verified, original empirical data generated against my live database environments.

---

## 5. Master Portfolio Repository & Verification Link

The complete source code, reproduction scripts, benchmark outputs, and high-resolution screenshot evidence are permanently cataloged on GitHub:
- **Repository URL:** https://github.com/ifekeyz/MIVA.git
- **Primary Branch:** `master`
- **Assessment Deliverable Root:** `MIT8103/`

