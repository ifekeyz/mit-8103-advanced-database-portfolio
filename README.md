# MIT 8103: Advanced Database Systems Master Portfolio

**Academic Institution:** MIVA Open University  
**Degree Programme:** Master of Science in Information Technology / Computing  
**Course Code & Title:** MIT 8103 – Advanced Database Systems  
**Enterprise Case Study:** **NairaPay Technologies Limited** (Simulated Nigerian Digital Wallet & Payments Platform)  
**Primary Database Engine:** PostgreSQL 16.14 (Homebrew & Dockerized Linux)  
**Secondary Database Engine:** MongoDB 7.0 (Local Container & MongoDB Atlas Cloud Replica Set)  

---

## Executive Overview: The NairaPay Architecture

Operating a high-growth financial technology service provider in sub-Saharan Africa introduces profound database engineering challenges: network volatility, high-concurrency P2P wallet collisions, stringent regulatory mandates (CBN KYC tiers, NUBAN compliance, NDPA data protection), and the non-negotiable imperative of **zero financial drift**.

This master portfolio encapsulates five modular engineering deliverables, tracing the end-to-end design, optimization, isolation, polyglot persistence, and distributed cloud deployment of the **NairaPay** core banking platform:

```mermaid
flowchart TD
    subgraph Client Application Layer
        Mobile["Consumer Mobile App<br/>(iOS / Android)"]
        Web["Merchant Portal & Web App"]
        Switch["National Settlement Switch<br/>(NIBSS Webhooks)"]
        Admin["Compliance & Audit Desk"]
    end

    subgraph Relational OLTP Core (PostgreSQL 16)
        PrimaryDB[("Primary Database (:5433 / :5432)<br/>• Double-Entry Ledger (412k lines)<br/>• Wallets & Balances (6k accounts)<br/>• ACID Transactions (206k txns)")]
        ReplicaDB[("Streaming Read Replica (:5434)<br/>• End-of-Day Reconciliation<br/>• Historical Statements (>24h)<br/>• Read-Only Analytics")]
        PrimaryDB -->|"Physical Streaming WAL<br/>(replica1_slot)"| ReplicaDB
    end

    subgraph Document Cloud Storage (MongoDB Atlas)
        AtlasCluster[("MongoDB Atlas 3-Node Replica Set<br/>• Polymorphic KYC Profiles (5k)<br/>• Append-Only Audit Trail (100k)<br/>• Ephemeral Sessions (TTL 1h)")]
    end

    Mobile -->|"P2P Transfers (transfer_funds)"| PrimaryDB
    Web -->|"Balance Checks & Idempotency"| PrimaryDB
    Switch -->|"Settlement Webhooks"| PrimaryDB
    Admin -->|"Read-Only Compliance Audits"| ReplicaDB
    
    Mobile -->|"Onboarding & Document Upload"| AtlasCluster
    Admin -->|"Security Surveillance Stream"| AtlasCluster

    PrimaryDB -.->|"Logical Bridge: customer_id"| AtlasCluster
```

---

## Master Portfolio Index

| Portfolio Module | Domain & Focus | Key Deliverables & Reports | Primary Technologies |
|---|---|---|---|
| [**Portfolio 1: Database Design & Modelling**](portfolio-1-database-design/README.md) | Relational 3NF architecture, double-entry bookkeeping, strict ACID check constraints, and referential integrity. | • [`case-study.md`](portfolio-1-database-design/case-study.md)<br>• [`normalisation.md`](portfolio-1-database-design/normalisation.md)<br>• [`03_constraint_tests.sql`](portfolio-1-database-design/03_constraint_tests.sql)<br>• [`nairapay.dbml`](portfolio-1-database-design/nairapay.dbml) | PostgreSQL 16, pgAdmin 4, DBML |
| [**Portfolio 2: Query Optimisation & Tuning**](portfolio-2-query-optimisation/README.md) | `EXPLAIN (ANALYZE, BUFFERS)` execution plan profiling, composite/covering B-Tree indexing, planner cost modeling, and disk-spill elimination. | • [`performance-analysis.md`](portfolio-2-query-optimisation/performance-analysis.md)<br>• 9 Production Queries (`queries/`)<br>• Benchmark logs (`plans/`) | PostgreSQL 16, B-Tree Indexes, psql |
| [**Portfolio 3: Transactions & Concurrency**](portfolio-3-transactions-concurrency/README.md) | Multi-session concurrency control, row-level locking (`SELECT ... FOR UPDATE`), deadlock prevention via deterministic ordering, and high-contention stress testing. | • [`analysis.md`](portfolio-3-transactions-concurrency/analysis.md)<br>• [`01_transfer_function.sql`](portfolio-3-transactions-concurrency/01_transfer_function.sql)<br>• [`04_concurrency_runbook.md`](portfolio-3-transactions-concurrency/04_concurrency_runbook.md)<br>• `pgbench` benchmarks (`output/`) | PostgreSQL 16, PL/pgSQL, pgbench |
| [**Portfolio 4: NoSQL & Advanced Data Models**](portfolio-4-nosql/README.md) | Polyglot persistence, polymorphic document modeling (embedding vs. referencing), `$jsonSchema` validation, distributed aggregation pipelines, and TTL indexing. | • [`README.md`](portfolio-4-nosql/README.md)<br>• [`00_docker_setup.md`](portfolio-4-nosql/00_docker_setup.md)<br>• CRUD & Aggregations (`03_crud...js`)<br>• `explain()` benchmarks (`output/`) | MongoDB 7, mongosh, MongoDB Compass |
| [**Portfolio 5: Distributed & Cloud Databases**](portfolio-5-distributed-cloud/README.md) | Master-standby physical streaming replication, stale read dynamics, sync vs. async CAP trade-offs, declarative hash partitioning, failover, and MongoDB Atlas cloud deployment. | • [`README.md`](portfolio-5-distributed-cloud/README.md)<br>• `docker-compose.yml`<br>• Hash Partitioning (`03_partitioning.sql`)<br>• Cloud checks (`04_atlas...js`) | Docker Compose, PostgreSQL Standby, MongoDB Atlas |

---

## Core Technical Highlights Across Modules

### 1. Mathematical Conservation of Financial Truth (Portfolios 1, 2, 3)
Across all multi-user stress tests, deadlock aborts, and index reorganizations, NairaPay's financial core maintained absolute mathematical invariance:
- **Total System Currency:** Perfectly constant at **`1,000,000,000,000.0000 NGN`** (One Trillion Naira) across all 412,000+ ledger entries.
- **Double-Entry Equilibrium:** Every completed transaction contains exactly paired debits and credits ($\sum \text{Debits} - \sum \text{Credits} = 0$).
- **Cache Reconciliation:** The cached balance in `accounts` matches the historical sum of ledger lines with **0 accounting drift**.

### 2. Radical Query Optimization & Buffer Tuning (Portfolio 2)
- Statement queries for customer mobile apps dropped from **242.70 ms** down to **0.87 ms** (**279.9× speedup**).
- Shared buffer hits dropped by **94% to 98%**, drastically freeing CPU cache lines.
- Eliminated an external merge sort spilling **19.7 MB** of temporary data to disk during daily balance reconciliations.

### 3. Concurrency Control & Deadlock Elimination (Portfolio 3)
- Under high-contention stress testing (10 clients hammering 20 hot wallets), unordered locking suffered a catastrophic performance collapse to **47.62 TPS** with **56 deadlocks** due to 1-second engine detection timeouts.
- Implementing deterministic resource ordering ($\min(\text{from}, \text{to})$ then $\max(\text{from}, \text{to})$) completely eliminated circular wait cycles, sustaining **7,822.49 TPS** with **0 failures** (**164.3× higher throughput**).

### 4. Polyglot Document Modeling & Real-Time Aggregations (Portfolio 4)
- Deployed MongoDB alongside PostgreSQL, replacing fragile SQL EAV anti-patterns with clean, embedded polymorphic subdocuments for multi-tier KYC documents.
- Compound B-Tree indexing on 100,000 audit records reduced query latency from **65 ms** (`COLLSCAN > SORT`) to **1 ms** (`IXSCAN > FETCH > LIMIT`), reducing scanned documents from **100,000 to 20** (**5,000× scan reduction**).

### 5. High-Availability Streaming Replication & Partitioning (Portfolio 5)
- Orchestrated containerized master-standby PostgreSQL streaming replication over dedicated replication slots (`replica1_slot`), demonstrating sub-millisecond WAL replay and stale read recovery.
- Implemented 4-way declarative hash partitioning on the ledger, demonstrating **Partition Pruning** for single-wallet lookups vs. parallel **Scatter-Gather** scans for non-keyed queries.
- Deployed a production-ready 3-node replica set on **MongoDB Atlas**, verifying `w: majority` write durability and secondary read offloading.

---

## Technology Stack & Environment

| Layer | Technology | Version | Purpose in Architecture |
|---|---|---|---|
| **Host System** | macOS (Apple Silicon aarch64) | Darwin 25.4.0 | Primary development and benchmarking platform |
| **Relational Core** | PostgreSQL | 16.14 (Homebrew / Docker) | Authoritative ACID ledger, accounts, and transactions |
| **Document Store** | MongoDB Community | 7.0 (Docker container) | Local development for KYC profiles and audit trails |
| **Cloud Database** | MongoDB Atlas | 7.0 (M0 Sandbox) | Managed 3-node multi-AZ cloud replica set |
| **Container Engine**| Docker Desktop / Docker Compose | V2 | Cluster orchestration (primary, replica, local mongo) |
| **Benchmarking** | `pgbench` & PostgreSQL `EXPLAIN` | 16.14 | Transaction load generation and query plan profiling |
| **Client Tooling** | `psql`, `mongosh`, pgAdmin 4, MongoDB Compass | Latest | Database administration, querying, and GUI inspection |

---

## Academic Integrity & Authorship Declaration

This repository represents the original coursework submission for **MIT 8103 – Advanced Database Systems** at **MIVA Open University**.

- **AI-Assisted Engineering:** Generative AI tools (Claude Code & Antigravity) were utilized as intelligent pair-programming assistants to support initial script scaffolding, Docker entrypoint configuration, and documentation formatting.
- **Verification & Validation:** All schema definitions, SQL scripts, PL/pgSQL functions, MongoDB aggregation pipelines, Docker environments, and benchmarking runs were independently executed, debugged, and validated against live local and cloud database engines. Every benchmark metric, execution plan, and screenshot cited across all portfolio modules reflects genuine, reproducible empirical telemetry.
