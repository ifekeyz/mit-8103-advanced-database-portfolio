================================================================================
MIVA OPEN UNIVERSITY — SCHOOL OF POST GRADUATE STUDIES
MIT 8103: ADVANCED DATABASE SYSTEMS (40 MARKS CONTINUOUS ASSESSMENT)
2026/2027 ACADEMIC SESSION — SEPTEMBER COHORT
================================================================================

STUDENT SUBMISSION CATALOG & STANDALONE README
--------------------------------------------------------------------------------
Student Surname        : Olanrewaju
Student First Name     : Dolapo
Student ID Number      : 301911958
University Email       : dolapo.olanrewaju@miva.university
Chosen Case Study      : NairaPay Technologies Limited (Nigerian Fintech Wallet)
GitHub Repository URL  : https://github.com/ifekeyz/mit-8103-advanced-database-portfolio
Primary Branch         : main
Archive Package Name   : Olanrewaju_Dolapo_301911958.zip
Standalone ReadME File : Olanrewaju_Dolapo_README.txt

================================================================================
1. EXECUTIVE SUMMARY OF CASE STUDY & ARCHITECTURE
================================================================================
NairaPay Technologies Limited is a simulated high-growth Nigerian digital mobile
money and payment service provider. The platform provides peer-to-peer (P2P)
wallet transfers, merchant collection tools, and utility payments.

The architecture solves critical financial database challenges:
1. Strict ACID Relational Core (PostgreSQL 16):
   - 3NF relational schema with 8 core tables: customers, kyc_records, accounts,
     beneficiaries, transactions, ledger_entries, cards, and fraud_flags.
   - All financial quantities use NUMERIC(19,4) to prevent floating-point drift.
   - Double-entry bookkeeping: every transaction creates paired DEBIT and CREDIT
     lines in ledger_entries.
   - Strict referential integrity: ON DELETE RESTRICT on financial histories.
2. Advanced Query Optimisation:
   - 404,162 ledger lines and 206,096 transactions tuned using B-Tree composite,
     partial, and covering indexes.
   - 280x speedup on mobile statement lookups (242.7 ms to 0.87 ms).
   - Eliminated 19.7 MB external disk spills during balance reconciliations.
3. Concurrency Control & Deadlock Prevention:
   - Eliminated silent Lost Update double-spending via SELECT ... FOR UPDATE.
   - Eliminated deadlocks via deterministic resource ordering (LEAST/GREATEST).
   - Stress-tested at 7,822.49 TPS with 0 failures under pgbench load.
   - Preserved 1,000,000,000,000.0000 NGN (1 Trillion NGN) currency invariance.
4. Polyglot Persistence Layer (MongoDB 7):
   - Offloaded polymorphic KYC dossiers (BVN, NIN, Passports, Utility Bills)
     using embedded document models governed by $jsonSchema validation.
   - High-throughput append-only audit trail (100,000 events) indexed for 65x
     query speedups (65 ms to 1 ms).
   - Ephemeral authentication sessions with automated 1-hour TTL expiration.
5. Distributed Databases & Cloud Resilience:
   - Master-standby physical streaming replication (WAL over replica1_slot).
   - Demonstrations of stale reads and synchronous replication availability blocks.
   - 4-way declarative hash partitioning with partition pruning.
   - MongoDB Atlas 3-node multi-availability-zone replica set with w: majority.

================================================================================
2. COMPREHENSIVE SUBMISSION FILE MANIFEST & RUBRIC MAPPING
================================================================================
All files in the submission folder Olanrewaju_Dolapo_301911958/ adhere strictly to
the university naming constraint (Surname_Firstname_DocumentType, NO SPACES):

--------------------------------------------------------------------------------
SYNTHESIS & FINAL DOCUMENTATION (General Criteria & Documentation — 8 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_Final_Report.md
  Executive synthesis report covering case study, all 5 portfolios, reflection,
  and GitHub repository verification link.
• Olanrewaju_Dolapo_README.txt
  This standalone submission catalog and assessor verification guide.
• Olanrewaju_Dolapo_AI_Use_Declaration.md
  Formal academic integrity disclosure detailing tool usage and student ownership.
• Olanrewaju_Dolapo_References.md
  Scholarly academic and statutory references (Codd, Gray, Brewer, Abadi, CBN).

--------------------------------------------------------------------------------
PORTFOLIO 1: DATABASE DESIGN & MODELLING (Design Quality & Correctness — 14 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_P1_CaseStudy.md
  Enterprise requirements, regulatory framework (CBN, NUBAN, NDPA), and personas.
• Olanrewaju_Dolapo_P1_RelationalSchema.md
  Full relational data dictionary, column types, keys, and constraint definitions.
• Olanrewaju_Dolapo_P1_Normalisation.md
  Formal 1NF to 3NF normalization breakdown and intentional design decisions.
• Olanrewaju_Dolapo_P1_CreateSchema.sql
  DDL script creating database and 8 tables in one atomic transaction.
• Olanrewaju_Dolapo_P1_SeedData.sql
  Database initialization and seed verification scripts.
• Olanrewaju_Dolapo_P1_ConstraintTests.sql
  10 negative constraint tests proving rejection of invalid financial data.
• Olanrewaju_Dolapo_ERD.png
  High-resolution Entity-Relationship Diagram visual export.
• Olanrewaju_Dolapo_ERD.dbml
  Database Markup Language (DBML) source code to regenerate the ER diagram.
• Evidence Screenshots:
  - Olanrewaju_Dolapo_P1_Screen_Setup.png (Environment and connection check)
  - Olanrewaju_Dolapo_P1_Screen_Tables.png (8 tables created in pgAdmin)
  - Olanrewaju_Dolapo_P1_Screen_Constraints.png (PASS 1 to PASS 10 results)

--------------------------------------------------------------------------------
PORTFOLIO 2: QUERY OPTIMISATION & TUNING (Query & Performance Analysis — 5 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_P2_README.md
  Overview, step-by-step reproduction guide, and benchmark matrix.
• Olanrewaju_Dolapo_P2_PerformanceResults.md
  In-depth EXPLAIN (ANALYZE, BUFFERS) before/after report across 9 queries.
• Olanrewaju_Dolapo_P2_Queries.sql
  Batch execution capturing query results and invariant audits.
• Olanrewaju_Dolapo_P2_CapturePlans.sql
  Automated script capturing execution plans before and after indexing.
• Olanrewaju_Dolapo_P2_CreateIndexes.sql
  DDL script engineering 5 production B-Tree indexes + ANALYZE statistics.
• Olanrewaju_Dolapo_P2_DropIndexes.sql
  Clean teardown script to return database to unindexed baseline.
• Olanrewaju_Dolapo_P2_PlannerExperiments.sql
  Cost model validation (seq_page_cost, random_page_cost, correlation).
• Olanrewaju_Dolapo_P2_WriteCost.sql
  Storage footprint and insert write amplification quantification.
• Benchmark Output Files:
  - Olanrewaju_Dolapo_P2_Out_Before.txt (Unindexed execution plans)
  - Olanrewaju_Dolapo_P2_Out_After.txt (Optimized execution plans)
  - Olanrewaju_Dolapo_P2_Out_Planner.txt (Cost settings and forced plan results)
  - Olanrewaju_Dolapo_P2_Out_Results.txt (Query output rows and invariant checks)

--------------------------------------------------------------------------------
PORTFOLIO 3: TRANSACTIONS & CONCURRENCY (Advanced Concepts — 5 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_P3_README.md
  Project overview, architecture diagrams, and empirical stress test tables.
• Olanrewaju_Dolapo_P3_ConcurrencyAnalysis.md
  Theoretical report covering MVCC, Coffman conditions, and the 7 runbook questions.
• Olanrewaju_Dolapo_P3_Runbook.md
  Multi-terminal interactive runbook for Experiments 1 through 5.
• Olanrewaju_Dolapo_P3_TransactionScripts.sql
  Production transfer_funds() function with ordered locking and idempotency.
• Olanrewaju_Dolapo_P3_DemoSetup.sql
  Wallet reset script for Demo Alice and Bob.
• Olanrewaju_Dolapo_P3_CommitRollbackDemo.sql
  Batch demonstration of COMMIT, ROLLBACK, failure handling, and SAVEPOINT.
• Olanrewaju_Dolapo_P3_IntegrityCheck.sql
  Financial audit queries verifying 1 Trillion NGN zero-drift invariance.
• Olanrewaju_Dolapo_P3_StressOrdered.pgbench
  High-contention pgbench script using ordered locking (7,822 TPS, 0 deadlocks).
• Olanrewaju_Dolapo_P3_StressUnordered.pgbench
  High-contention script using unordered locking (47.6 TPS, 56 deadlocks).
• Benchmark Output Files:
  - Olanrewaju_Dolapo_P3_Out_CommitRollback.txt (Transaction primitives log)
  - Olanrewaju_Dolapo_P3_Out_StressOrdered.txt (7,822 TPS benchmark log)
  - Olanrewaju_Dolapo_P3_Out_StressUnordered.txt (Deadlock benchmark log)
  - Olanrewaju_Dolapo_P3_Out_IntegrityBefore.txt (Baseline currency audit)
  - Olanrewaju_Dolapo_P3_Out_IntegrityAfterOrdered.txt (Post-ordered audit)
  - Olanrewaju_Dolapo_P3_Out_IntegrityAfterUnordered.txt (Post-unordered audit)
• Evidence Screenshots:
  - Olanrewaju_Dolapo_P3_Screen_FunctionTest.png
  - Olanrewaju_Dolapo_P3_Screen_CommitRollback.png
  - Olanrewaju_Dolapo_P3_Screen_Exp1LostUpdate.png
  - Olanrewaju_Dolapo_P3_Screen_Exp2LockWaiting.png
  - Olanrewaju_Dolapo_P3_Screen_Exp2LockReleased.png
  - Olanrewaju_Dolapo_P3_Screen_Exp3aReadCommitted.png
  - Olanrewaju_Dolapo_P3_Screen_Exp3bRepeatableRead.png
  - Olanrewaju_Dolapo_P3_Screen_Exp4Deadlock.png
  - Olanrewaju_Dolapo_P3_Screen_StressResults.png
  - Olanrewaju_Dolapo_P3_Screen_IntegrityAudit.png

--------------------------------------------------------------------------------
PORTFOLIO 4: NOSQL & ADVANCED DATA MODELS (Practical Implementation — 8 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_P4_README.md
  Polyglot architecture, embedding vs. referencing, and benchmark matrices.
• Olanrewaju_Dolapo_P4_NoSQLAnalysis.md
  Academic paper on WiredTiger, MQL aggregation pipelines, and TTL indexes.
• Olanrewaju_Dolapo_P4_DockerSetup.md
  Step-by-step container orchestration and MongoDB Compass guide.
• Olanrewaju_Dolapo_P4_DockerCompose.yml
  Docker Compose manifest launching local MongoDB 7 with persistent volume.
• Olanrewaju_Dolapo_P4_SchemaValidation.js
  Collection initialization enforcing $jsonSchema validation rules.
• Olanrewaju_Dolapo_P4_SeedData.js
  Deterministic seed populating 5,000 KYC profiles and 100,000 audit events.
• Olanrewaju_Dolapo_P4_CrudAndAggregation.js
  CRUD operations, nested array queries, and 4 advanced aggregation pipelines.
• Olanrewaju_Dolapo_P4_IndexesExplain.js
  Secondary index engineering, explain() plans, unique index, and TTL test.
• Benchmark Output Files:
  - Olanrewaju_Dolapo_P4_Out_CrudAggregation.txt (CRUD and pipeline outputs)
  - Olanrewaju_Dolapo_P4_Out_IndexesExplain.txt (65x speedup benchmark logs)
• Evidence Screenshots:
  - Olanrewaju_Dolapo_P4_Screen_SchemaValidation.png
  - Olanrewaju_Dolapo_P4_Screen_SeedVerification.png
  - Olanrewaju_Dolapo_P4_Screen_CrudOutput.png
  - Olanrewaju_Dolapo_P4_Screen_IndexesExplain.png
  - Olanrewaju_Dolapo_P4_Screen_TtlResult.png
  - Olanrewaju_Dolapo_P4_Screen_CompassKycDoc.png
  - Olanrewaju_Dolapo_P4_Screen_CompassAuditEvent.png
  - Olanrewaju_Dolapo_P4_Screen_CompassIndexes.png
  - Olanrewaju_Dolapo_P4_Screen_CompassValidation.png

--------------------------------------------------------------------------------
PORTFOLIO 5: DISTRIBUTED & CLOUD DATABASES (Advanced Concepts — 5 Marks)
--------------------------------------------------------------------------------
• Olanrewaju_Dolapo_P5_README.md
  Hybrid cloud design, workload routing, replication mechanics, and 210-word essay.
• Olanrewaju_Dolapo_P5_DistributedAnalysis.md
  Academic paper on CAP/PACELC theorems, 2PC vs. Raft, and failover engineering.
• Olanrewaju_Dolapo_P5_DockerCompose.yml
  Cluster manifest for PostgreSQL Primary (5433) and Streaming Standby (5434).
• Olanrewaju_Dolapo_P5_ReplicaEntrypoint.sh
  Standby bootstrap script taking pg_basebackup and establishing replication.
• Olanrewaju_Dolapo_P5_PrimaryInit.sh
  Primary initialization script creating replicator role and pg_hba rules.
• Olanrewaju_Dolapo_P5_PrimaryChecks.sql
  Replication health query inspecting pg_stat_replication and slots.
• Olanrewaju_Dolapo_P5_ReplicaChecks.sql
  Standby health query inspecting pg_is_in_recovery() and write rejection.
• Olanrewaju_Dolapo_P5_Partitioning.sql
  Declarative hash partitioning script on 412,058 ledger entries.
• Olanrewaju_Dolapo_P5_AtlasCloudCheck.js
  MongoDB Atlas cloud script testing topology, w: majority, and secondary reads.
• Benchmark Output Files:
  - Olanrewaju_Dolapo_P5_Out_Partitioning.txt (Pruning vs. scatter-gather plans)
• Evidence Screenshots:
  - Olanrewaju_Dolapo_P5_Screen_DockerPs.png
  - Olanrewaju_Dolapo_P5_Screen_RowCounts.png
  - Olanrewaju_Dolapo_P5_Screen_PrimaryChecks.png
  - Olanrewaju_Dolapo_P5_Screen_ReplicaChecks.png
  - Olanrewaju_Dolapo_P5_Screen_StaleRead.png
  - Olanrewaju_Dolapo_P5_Screen_CaughtUp.png
  - Olanrewaju_Dolapo_P5_Screen_SyncHang.png
  - Olanrewaju_Dolapo_P5_Screen_SyncWarning.png
  - Olanrewaju_Dolapo_P5_Screen_Partitioning.png
  - Olanrewaju_Dolapo_P5_Screen_Failover.png
  - Olanrewaju_Dolapo_P5_Screen_AtlasCluster.png
  - Olanrewaju_Dolapo_P5_Screen_AtlasCheckOutput.png

================================================================================
3. STEP-BY-STEP INSTRUCTIONS FOR ASSESSOR VERIFICATION
================================================================================

PREREQUISITES:
• PostgreSQL 16 (psql, pg_dump, pgbench)
• Docker Desktop with Compose V2
• mongosh (MongoDB Shell CLI)

STEP 1: UNPACK AND INSPECT SUBMISSION ARCHIVE
  unzip Olanrewaju_Dolapo_301911958.zip
  cd Olanrewaju_Dolapo_301911958

STEP 2: VERIFY PORTFOLIO 1 (Database Design & Constraints)
  createdb nairapay_db
  psql -d nairapay_db -f Olanrewaju_Dolapo_P1_CreateSchema.sql
  psql -d nairapay_db -f Olanrewaju_Dolapo_P1_ConstraintTests.sql
  # Expected: Observe PASS 1 through PASS 10 in terminal output.

STEP 3: VERIFY PORTFOLIO 2 (Query Optimisation & Plans)
  psql -d nairapay_db -f Olanrewaju_Dolapo_P2_DropIndexes.sql
  psql -d nairapay_db -f Olanrewaju_Dolapo_P2_CapturePlans.sql > test_before.txt
  psql -d nairapay_db -f Olanrewaju_Dolapo_P2_CreateIndexes.sql
  psql -d nairapay_db -f Olanrewaju_Dolapo_P2_CapturePlans.sql > test_after.txt
  # Expected: Compare execution plans; verify Q1 latency drops from ~240ms to <1ms.

STEP 4: VERIFY PORTFOLIO 3 (Transactions, Locking & pgbench)
  psql -d nairapay_db -f Olanrewaju_Dolapo_P3_TransactionScripts.sql
  psql -d nairapay_db -f Olanrewaju_Dolapo_P3_DemoSetup.sql
  psql -d nairapay_db -f Olanrewaju_Dolapo_P3_CommitRollbackDemo.sql
  # Run ordered pgbench stress test:
  pgbench -n -c 10 -j 4 -t 200 -f Olanrewaju_Dolapo_P3_StressOrdered.pgbench nairapay_db
  # Run financial invariant audit:
  psql -d nairapay_db -f Olanrewaju_Dolapo_P3_IntegrityCheck.sql
  # Expected: 2,000 transactions processed, 0 failed, 1 Trillion NGN preserved.

STEP 5: VERIFY PORTFOLIO 4 (MongoDB NoSQL & Aggregations)
  docker compose -f Olanrewaju_Dolapo_P4_DockerCompose.yml up -d
  export MONGODB_URI="mongodb://nairapay_user:nairapay_pass@localhost:27017/nairapay_nosql?authSource=admin"
  mongosh "$MONGODB_URI" --file Olanrewaju_Dolapo_P4_SchemaValidation.js
  mongosh "$MONGODB_URI" --file Olanrewaju_Dolapo_P4_SeedData.js
  mongosh "$MONGODB_URI" --file Olanrewaju_Dolapo_P4_CrudAndAggregation.js
  mongosh "$MONGODB_URI" --file Olanrewaju_Dolapo_P4_IndexesExplain.js
  # Expected: Observe $jsonSchema rejection (code 121), unique index rejection (code 11000),
  # and Q1 latency drop from 65ms to 1ms.

STEP 6: VERIFY PORTFOLIO 5 (PostgreSQL Replication & Partitioning)
  docker compose -f Olanrewaju_Dolapo_P5_DockerCompose.yml up -d
  sleep 10
  # Check Primary (:5433) and Standby (:5434):
  psql -h localhost -p 5433 -U nairapay -d nairapay_db -f Olanrewaju_Dolapo_P5_PrimaryChecks.sql
  psql -h localhost -p 5434 -U nairapay -d nairapay_db -f Olanrewaju_Dolapo_P5_ReplicaChecks.sql
  # Run Hash Partitioning on Primary:
  psql -h localhost -p 5433 -U nairapay -d nairapay_db -f Olanrewaju_Dolapo_P5_Partitioning.sql
  # Expected: Output confirms 4 partitions, partition pruning on account_id, and scatter-gather on transaction_id.

================================================================================
END OF CATALOG — Olanrewaju Dolapo (Student ID: 301911958)
================================================================================

