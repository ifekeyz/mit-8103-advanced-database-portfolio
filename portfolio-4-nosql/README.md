# Portfolio 4: NoSQL and Advanced Data Models (MongoDB)

**Case study:** NairaPay, a simulated Nigerian fintech wallet and transfer platform  
**Course:** MIT 8103 – Advanced Database Systems  
**DBMS:** MongoDB 7.0 (Docker container `nairapay-mongo`) & MongoDB Compass GUI  
**Relational Host:** PostgreSQL 16.14 (`nairapay_db`)  
**Database:** `nairapay_nosql`  
**Dataset Scale:** 5,000 KYC Profiles (~1.2 MB), 100,000 Audit Events (~14.5 MB), Ephemeral Login Sessions  

---

## 1. Executive Summary & Polyglot Architecture

Modern financial technology architectures require distinct storage paradigms for different data access patterns. In **Portfolios 1, 2, and 3**, NairaPay's core ledger, account balances, and double-entry transaction journals were engineered in PostgreSQL 16, enforcing strict ACID isolation, referential integrity, and deterministic row locking.

However, enterprise payment systems also ingest high-velocity semi-structured data:
- **Polymorphic KYC Documents:** Tiered Know-Your-Customer (KYC) records with heterogeneous schemas (passports with expiry dates and issuing countries; utility bills with Disco providers and meter numbers; BVNs and NINs with statutory verification metadata).
- **Append-Only Audit Trails:** High-throughput security, authentication, and fraud events where event payloads (`details`) vary dynamically per event type.
- **Transient Authentication Sessions:** High-churn login tokens requiring automatic time-to-live (TTL) expiration without manual batch cleanup scripts.

For these operational requirements, **Portfolio 4** implements a **Polyglot Persistence Architecture**, deploying **MongoDB 7** alongside PostgreSQL to store KYC profiles, security audit events, and login sessions.

```mermaid
flowchart TD
    subgraph Client & API Gateway
        User["Mobile App / Web Client"]
        AuthService["Auth & Security Service"]
        KYCService["Identity & Onboarding Service"]
        LedgerService["Core Ledger & Transfer Engine"]
    end

    subgraph Relational Database (PostgreSQL 16)
        nairapay_db[("nairapay_db<br/>• accounts<br/>• transactions<br/>• ledger_entries<br/>• customers")]
    end

    subgraph Document Database (MongoDB 7)
        nairapay_nosql[("nairapay_nosql<br/>• kyc_profiles<br/>• audit_events<br/>• login_sessions")]
    end

    User -->|Transfer Funds| LedgerService
    User -->|Upload ID / Tier Upgrade| KYCService
    User -->|Login / Authenticate| AuthService

    LedgerService -->|ACID Transfers & Double-Entry| nairapay_db
    KYCService -->|Polymorphic Documents| nairapay_nosql
    AuthService -->|Append Audit Logs & TTL Sessions| nairapay_nosql

    nairapay_db -.->|Logical Bridge: customer_id| nairapay_nosql
```

### 1.1 Data Placement Matrix

| Data Domain | Storage Engine | Modeling Pattern | Architectural Justification |
|---|---|---|---|
| **Wallets, Balances, Transfers, Ledger** | **PostgreSQL 16** | Relational 3NF with Double-Entry Journals | Requires multi-row ACID transactions, strict foreign keys, check constraints, and exact `NUMERIC(19,4)` arithmetic. A transfer must mutate two balances and append two ledger lines atomically or roll back completely. |
| **KYC Profiles (`kyc_profiles`)** | **MongoDB 7** | Embedded Document Model | Polymorphic schemas: each document type carries different attributes. Storing this in SQL requires dozens of nullable columns or an Anti-Pattern Entity-Attribute-Value (EAV) table. In MongoDB, the entire profile and its nested documents are fetched and updated in a single atomic I/O operation. |
| **Audit Trails (`audit_events`)** | **MongoDB 7** | Referenced Document Model | Append-only, high-write volume. Event payloads (`details`) differ dynamically per event type (`LOGIN_SUCCESS`, `FRAUD_FLAG`, `KYC_UPGRADED`). New event types require zero schema alterations (`ALTER TABLE`). |
| **User Sessions (`login_sessions`)** | **MongoDB 7** | Ephemeral TTL Collection | Short-lived authentication tokens. Native background TTL indexes automatically purge expired sessions after 3,600 seconds without scheduling cron cleanup jobs. |

### 1.2 Cross-Database Referential Integrity

The logical link between PostgreSQL and MongoDB is the surrogate key `customer_id` (`customers.customer_id` in PostgreSQL equals `customer_id` in `kyc_profiles` and `audit_events`). 

Because foreign key constraints cannot cross database network boundaries, distributed data divergence is an inherent risk:
- **Potential Failure Mode:** A customer record is committed in PostgreSQL, but a network drop or crash prevents the KYC profile insertion in MongoDB (creating an orphan customer without verification records). Conversely, a customer deletion in PostgreSQL could leave dangling audit events in MongoDB.
- **Fintech Remediation Strategy:** Production architectures implement the **Transactional Outbox Pattern** or a **Saga Orchestrator**. Customer mutations write an outbox event into a PostgreSQL table within the primary ACID transaction. A reliable CDC worker (e.g., Debezium) streams the event to an Apache Kafka topic, which feeds MongoDB via idempotent consumer workers.

---

## 2. Repository Structure

```
portfolio-4-nosql/
├── README.md                      # Comprehensive project documentation and benchmark analysis (this file)
├── docker-compose.yml             # Local MongoDB 7 container orchestration with persistent volume
├── 00_docker_setup.md             # Container startup and mongosh connection instructions
├── 01_schema_validation.js        # Collection initialization with $jsonSchema validators
├── 02_seed_data.js                # Deterministic seed generator (5,000 KYC profiles, 100,000 audit events)
├── 03_crud_and_aggregation.js     # CRUD operations, nested updates, and 4 advanced aggregation pipelines
├── 04_indexes_explain.js          # Index creation, explain() executionStats, unique & TTL validation
├── output/                        # Raw terminal outputs and benchmark logs
│   ├── 03_crud_and_aggregation.txt# Verified execution log of CRUD operations and aggregation results
│   └── 04_indexes_explain.txt     # Verified before/after explain() statistics and index footprints
└── screenshots/                   # Graphical evidence from terminal runs and MongoDB Compass
    ├── 01_schema_validation.png   # Terminal execution of 01_schema_validation.js ($jsonSchema rejection)
    ├── 02_seed_verification.png   # Terminal output confirming 5,000 profiles & 100,000 events seeded
    ├── 03_crud_output.png         # Terminal execution of 03_crud_and_aggregation.js
    ├── 05_indexes_explain.png     # Terminal execution of 04_indexes_explain.js (COLLSCAN vs IXSCAN)
    ├── 06_ttl_result.png          # Terminal verification of automated TTL session expiration
    ├── 07_compass_kyc_document.png# MongoDB Compass view of an expanded polymorphic KYC document
    ├── 08_compass_audit_event.png # MongoDB Compass view of structured audit event documents
    ├── 09_compass_indexes.png     # MongoDB Compass view of deployed indexes on audit_events
    └── 10_compass_validation.png  # MongoDB Compass view of active JSON Schema validation rules
```

---

## 3. Data Modeling: Embedding vs. Referencing

MongoDB document modeling requires deliberate architectural trade-offs between embedded subdocuments and referenced relationships:

```mermaid
classDiagram
    class Customer_PostgreSQL {
        BIGINT customer_id (PK)
        VARCHAR first_name
        VARCHAR last_name
        VARCHAR email (UQ)
    }

    class KYC_Profile_MongoDB {
        ObjectId _id
        Number customer_id (Ref)
        Number tier
        String status
        Array documents [Embedded]
        Date created_at
    }

    class Audit_Event_MongoDB {
        ObjectId _id
        Number customer_id (Ref)
        String event_type
        Date ts
        Object details
    }

    class Login_Session_MongoDB {
        ObjectId _id
        Number customer_id (Ref)
        String token
        Date created_at (TTL 1h)
    }

    Customer_PostgreSQL <.. KYC_Profile_MongoDB : Logical Reference
    Customer_PostgreSQL <.. Audit_Event_MongoDB : Logical Reference
    Customer_PostgreSQL <.. Login_Session_MongoDB : Logical Reference
```

### 3.1 Embedded Pattern: `kyc_profiles.documents`
- **Pattern:** Identity documents are embedded directly inside the `kyc_profiles` document as an array of subdocuments.
- **Architectural Rationale:**
  1. **Strict 1:Few Bounded Cardinality:** A customer will possess at most 3 to 5 identification documents (BVN, NIN, Passport, Driver's License, Utility Bill). The document will never approach MongoDB's hard **16 MB BSON document size limit**.
  2. **Single Atomic Read/Write:** When compliance personnel or the KYC verification engine evaluates a customer, the complete verification dossier is retrieved in a single disk read without requiring relational joins.
  3. **No Independent Lifecycle:** An identity document has no meaning outside the context of the customer's KYC profile.

```json
{
  "_id": {"$oid": "671343760bc56a578d655f2b"},
  "customer_id": 1001,
  "tier": 3,
  "status": "VERIFIED",
  "documents": [
    {
      "type": "BVN",
      "number": "22210492831",
      "verified_with": "NIBSS"
    },
    {
      "type": "PASSPORT",
      "number": "A08492018",
      "country": "NG",
      "expiry": {"$date": "2031-08-14T00:00:00.000Z"}
    },
    {
      "type": "UTILITY_BILL",
      "number": "UB92847102",
      "provider": "Eko Disco",
      "issued_on": {"$date": "2026-09-12T00:00:00.000Z"}
    }
  ],
  "created_at": {"$date": "2026-01-15T08:30:00.000Z"}
}
```

### 3.2 Referenced Pattern: `audit_events`
- **Pattern:** Audit events are stored in a separate collection, each holding a `customer_id` foreign reference.
- **Architectural Rationale:**
  1. **Unbounded Growth:** A high-frequency customer generates thousands of events over their lifetime (logins, transfers, PIN changes, fraud checks). Embedding events into the customer document would quickly exceed the 16 MB limit and cause massive memory fragmentation as documents repeatedly reallocate on disk.
  2. **Append-Only Write Performance:** Inserting an audit event is an append-only operation at the tail of the collection, avoiding page re-writes.
  3. **Time-Series Querying:** Audit investigations query across time windows, event types, or high-risk IP subnets across *all* customers simultaneously.

```json
{
  "_id": {"$oid": "671343820bc56a578d658210"},
  "customer_id": 1001,
  "event_type": "LOGIN_SUCCESS",
  "ts": {"$date": "2026-10-15T08:42:34.362Z"},
  "details": {
    "ip": "102.89.115.88",
    "device": "Web",
    "city": "Abuja"
  }
}
```

---

## 4. Schema Validation: Enforcing Integrity with `$jsonSchema`

A common misconception is that NoSQL databases are "schema-less." In enterprise software, unstructured data quickly devolves into corrupted data. MongoDB is **schema-flexible**: it permits heterogeneous document shapes while strictly enforcing essential structural invariants at the database level.

In `01_schema_validation.js`, collections are instantiated with explicit `$jsonSchema` validators and `validationAction: 'error'`.

### 4.1 Schema Rules for `kyc_profiles`
The validator enforces that:
1. `customer_id`, `tier`, `status`, `documents`, and `created_at` are mandatory.
2. `tier` must be an integer between 1 and 3.
3. `status` is constrained to the enum `['PENDING', 'VERIFIED', 'REJECTED']`.
4. `documents` must be an array with at least 1 item (`minItems: 1`).
5. Every item in `documents` must contain a valid `type` enum (`BVN`, `NIN`, `PASSPORT`, `DRIVERS_LICENCE`, `UTILITY_BILL`) and a string `number`.

### 4.2 Empirical Verification of Rejection
When an invalid document missing mandatory attributes and containing an illegal status enum is submitted:
```javascript
nosql.kyc_profiles.insertOne({ customer_id: 1, status: 'MAYBE' });
```
MongoDB immediately rejects the write with a hard validation failure:
```
MongoServerError: Document failed validation
  code: 121
  codeName: 'DocumentValidationFailure'
```
*Visual Evidence:* `screenshots/01_schema_validation.png` confirms `PASS: invalid KYC document rejected -> code 121`.

---

## 5. CRUD Operations and Aggregation Pipelines

The script `03_crud_and_aggregation.js` executes comprehensive data manipulation and analytical aggregation pipelines against the seeded dataset.

### 5.1 CRUD Lifecycle
- **Create:** Inserts onboarding profile for customer `999999` with nested BVN and International Passport.
- **Read (Array Filter):** Queries tier 3 customers holding a `PASSPORT` (`count = 316`).
- **Read (Nested Expiry Filter):** Uses `$elemMatch` to identify passports expiring within 365 days (`count = 21`).
- **Update (Atomic `$set` and `$push`):** Atomically promotes the customer to tier 3, marks status as `VERIFIED`, and appends an `Eko Disco` utility bill to the `documents` array:
  ```javascript
  nosql.kyc_profiles.updateOne(
      { customer_id: TEST_ID },
      {
          $set: { status: 'VERIFIED', tier: 3 },
          $push: { documents: { type: 'UTILITY_BILL', number: 'UB99999999', provider: 'Eko Disco', issued_on: new Date() } }
      }
  );
  ```
- **Append Audit Log:** Appends a `KYC_UPGRADED` event recording `{ from_tier: 2, to_tier: 3 }` without altering historical documents.
- **Delete:** Removes demo customer `999999` cleanly (`deletedCount = 1`).

---

### 5.2 Deep Dive: Aggregation 3 ($lookup Join with KYC Tiers)

Aggregation Pipeline 3 identifies the top 5 customers with the highest frequency of failed logins, joining the audit data with their KYC onboarding profile to assess credential stuffing risk.

#### The Aggregation Pipeline:
```javascript
nosql.audit_events.aggregate([
    // Stage 1: Filter only failed login events
    { $match: { event_type: 'LOGIN_FAILED' } },

    // Stage 2: Group by customer and count occurrences
    { $group: { _id: '$customer_id', failed_logins: { $sum: 1 } } },

    // Stage 3: Sort by highest failures descending, then customer_id ascending
    { $sort: { failed_logins: -1, _id: 1 } },

    // Stage 4: Take the top 5 most attacked customers
    { $limit: 5 },

    // Stage 5: Distributed Left Outer Join to kyc_profiles
    { 
        $lookup: { 
            from: 'kyc_profiles', 
            localField: '_id', 
            foreignField: 'customer_id', 
            as: 'kyc' 
        } 
    },

    // Stage 6: Flatten the joined array
    { $unwind: '$kyc' },

    // Stage 7: Project final clean reporting shape
    { 
        $project: { 
            _id: 0, 
            customer_id: '$_id', 
            failed_logins: 1, 
            tier: '$kyc.tier', 
            status: '$kyc.status' 
        } 
    }
]);
```

#### Pipeline Stage Analysis:
1. **`$match`:** Scans `audit_events` and discards all non-failure records early in the pipeline to minimize memory usage in downstream stages.
2. **`$group`:** Builds an in-memory hash table accumulating the failure count per `customer_id`.
3. **`$sort` & `$limit`:** Performs a top-N sort, keeping only the 5 worst-hit customer accounts. Placing `$limit` immediately after `$sort` allows the engine to optimize the sort buffer.
4. **`$lookup`:** Executes a correlated left outer join against `kyc_profiles`, matching `audit_events._id` (the grouped `customer_id`) against `kyc_profiles.customer_id`.
5. **`$unwind` & `$project`:** Deconstructs the single-element `kyc` array and formats a clean JSON payload for security operations.

#### Verified Output:
```json
{ "customer_id": 4744, "failed_logins": 12, "tier": 1, "status": "VERIFIED" }
{ "customer_id": 820,  "failed_logins": 11, "tier": 2, "status": "VERIFIED" }
{ "customer_id": 1485, "failed_logins": 11, "tier": 2, "status": "VERIFIED" }
{ "customer_id": 2768, "failed_logins": 10, "tier": 1, "status": "REJECTED" }
{ "customer_id": 3919, "failed_logins": 10, "tier": 1, "status": "PENDING" }
```

#### Relational SQL Equivalent:
In PostgreSQL, this identical query requires an explicit aggregation subquery or Common Table Expression (CTE) joined against `kyc_records`:
```sql
WITH top_failed_logins AS (
    SELECT customer_id, count(*) AS failed_logins
    FROM audit_events
    WHERE event_type = 'LOGIN_FAILED'
    GROUP BY customer_id
    ORDER BY failed_logins DESC, customer_id ASC
    LIMIT 5
)
SELECT t.customer_id, t.failed_logins, k.tier, k.status
FROM top_failed_logins t
JOIN kyc_records k ON k.customer_id = t.customer_id;
```
*Comparison:* In SQL, the relational optimizer uses an indexed Merge or Hash Join. In MongoDB, `$lookup` performs an index lookup on `kyc_profiles.customer_id` for each of the 5 candidate keys passed through the pipeline.

---

### 5.3 Additional Aggregation Pipelines Summary
- **Aggregation 1 (30-Day Event Distribution):** Groups 33,306 recent events by type:
  `LOGIN_SUCCESS` (13,425), `TRANSFER_INITIATED` (9,996), `LOGIN_FAILED` (4,911), `KYC_UPGRADED` (1,689), `FRAUD_FLAG` (1,664), and `PIN_CHANGED` (1,621).
- **Aggregation 2 (Daily Initiated Transfer Volume):** Evaluates financial velocity over the latest 5 days, grouping by formatted date strings (`$dateToString`):
  - `2026-10-18`: 319 transfers, 765,530.31 NGN
  - `2026-10-17`: 322 transfers, 817,420.28 NGN
  - `2026-10-16`: 333 transfers, 806,164.40 NGN
  - `2026-10-15`: 331 transfers, 841,442.70 NGN
- **Aggregation 4 (Document Density per KYC Tier):** Calculates the average document payload using `$size`:
  - **Tier 1 (Basic):** 2,741 customers, average **1 document** (BVN or NIN).
  - **Tier 2 (Medium):** 1,660 customers, average **2 documents** (BVN + Utility Bill).
  - **Tier 3 (High-Value):** 599 customers, average **4 documents** (BVN + NIN + Passport + Driver's License).

---

## 6. Indexing, Performance Tuning & Explain Analysis

Query optimization in MongoDB mirrors the B-Tree principles explored in Portfolio 2. The script `04_indexes_explain.js` captures execution metrics using `cursor.explain('executionStats')` before and after secondary index creation.

### 6.1 Empirical Benchmark Matrix (Before vs. After)
*Data extracted directly from verified benchmark log [output/04_indexes_explain.txt](output/04_indexes_explain.txt):*

| Query ID | Business Use Case | Before Index: Plan Stage | After Index: Plan Stage | Before: Docs Examined | After: Docs Examined | Keys Examined (After) | Execution Latency Before | Execution Latency After | Performance Optimization Factor |
|---|---|---|---|---|---|---|---|---|---|
| **Q1** | Latest 20 audit events for customer 1001 | `SORT > COLLSCAN` | `LIMIT > FETCH > IXSCAN` | **100,000** | **20** | 20 | **65 ms** | **1 ms** | **65.0× faster** (5,000× scan reduction) |
| **Q2** | `FRAUD_FLAG` events in last 7 days | `COLLSCAN` | `FETCH > IXSCAN` | **100,000** | **373** | 373 | **64 ms** | **2 ms** | **32.0× faster** (268× scan reduction) |
| **Q3** | KYC profile lookup for customer 2500 | `COLLSCAN` | `EXPRESS_IXSCAN` | **5,000** | **1** | 1 | **3 ms** | **1 ms** | **3.0× faster** (5,000× scan reduction) |

```
QUERY 1 DOCUMENTS EXAMINED (Lower is Better)
Before Index [==================================================] 100,000 docs
After Index  [=] 20 docs (5,000x reduction)

QUERY 1 EXECUTION LATENCY (ms - Lower is Better)
Before Index [==================================================] 65 ms
After Index  [=] 1 ms (65x faster)
```

---

### 6.2 Technical Analysis of Execution Plans

#### 1. Query 1: Compound Equality-First B-Tree (`idx_audit_customer_ts`)
- **Query:** `db.audit_events.find({ customer_id: 1001 }).sort({ ts: -1 }).limit(20)`
- **Before:** Without an index, MongoDB executes a **Collection Scan (`COLLSCAN`)**, reading all 100,000 documents from disk into memory. It then executes a blocking **In-Memory Sort (`SORT`)** across all records for customer 1001 before applying the limit. Latency: **65 ms**.
- **Engineered Index:** `{ customer_id: 1, ts: -1 }`
- **After:** The engine performs an **Index Scan (`IXSCAN`)** directly to the `customer_id: 1001` branch of the B-Tree. Because the index keys are already pre-sorted in descending order of `ts`, the index satisfies the sort order natively, **completely eliminating the in-memory SORT stage**. The engine traverses the first 20 index keys, performs 20 precise heap fetches (**`FETCH`**), and terminates immediately (**`LIMIT`**). Latency drops to **1 ms**.

#### 2. Query 2: Equality-Range Compound B-Tree (`idx_audit_type_ts`)
- **Query:** `db.audit_events.find({ event_type: 'FRAUD_FLAG', ts: { $gte: ISODate(...) } })`
- **Before:** Evaluates all 100,000 documents via `COLLSCAN`, filtering rows through CPU predicate checking. Latency: **64 ms**.
- **Engineered Index:** `{ event_type: 1, ts: -1 }`
- **After:** Enforces equality-first indexing on `event_type`, followed by a contiguous range scan on `ts`. Only 373 index keys and 373 heap documents are examined. Latency drops to **2 ms**.

#### 3. Query 3: Unique Index Constraint (`uq_kyc_customer`)
- **Query:** `db.kyc_profiles.find({ customer_id: 2500 })`
- **Engineered Index:** `db.kyc_profiles.createIndex({ customer_id: 1 }, { unique: true })`
- **After:** The query executes an **`EXPRESS_IXSCAN`**, examining exactly 1 index key and returning 1 document.
- **Integrity Enforcement:** In addition to search acceleration, the `unique: true` property provides database-level constraint enforcement. When a duplicate profile for customer `1` is inserted, MongoDB aborts with a duplicate key error:
  ```
  MongoServerError: E11000 duplicate key error collection: nairapay_nosql.kyc_profiles index: uq_kyc_customer dup key: { customer_id: 1 }
  ```
  *Evidence:* Confirmed in [output/04_indexes_explain.txt](output/04_indexes_explain.txt) (`PASS: duplicate customer_id rejected -> code 11000`).

---

### 6.3 Automated Document Lifecycle: TTL Index on `login_sessions`
In financial platforms, managing active JWT tokens and mobile sessions in relational tables requires scheduled batch deletion scripts (`DELETE FROM sessions WHERE expires_at < NOW()`), which cause table bloat and lock contention.

MongoDB provides native **Time-To-Live (TTL) Indexes**:
```javascript
nosql.login_sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600, name: 'ttl_session_1h' });
```
- **Mechanism:** MongoDB's internal background thread runs once every 60 seconds, reading the B-Tree index on `created_at` and automatically purging documents where $\text{created\_at} + 3600\text{s} < \text{current\_time}$.
- **Verification:** Two sessions were inserted (`tok-recent` and `tok-old` created 2 hours prior). Within 60 seconds, `tok-old` was automatically purged from the collection, while `tok-recent` remained active.
- *Visual Evidence:* `screenshots/06_ttl_result.png` displays `login_sessions.find()` returning only the active session.

---

### 6.4 Storage Overhead & Write Amplification
Secondary indexes are not free; they introduce physical disk footprint and write amplification overhead:

| Collection | Data Volume | Index Overhead | Total Storage Footprint | Index-to-Data Ratio |
|---|---|---|---|---|
| **`audit_events`** (100k docs) | 14.5 MB | 5.3 MB | 19.8 MB | **36.6%** |
| **`kyc_profiles`** (5k docs) | 1.2 MB | 0.3 MB | 1.5 MB | **25.0%** |

Maintaining two compound B-Trees on `audit_events` adds **5.3 MB** of memory/disk overhead. However, in return for this 36.6% storage trade-off, query latency improved by **6,400% (65 ms to 1 ms)**, an essential investment for real-time fraud monitoring.

---

## 7. Architectural Debate: Relational (PostgreSQL) vs. Document (MongoDB)

A central architectural question for NairaPay is: **Should the core financial ledger be migrated to MongoDB?**

### Comparative Architectural Matrix

| Dimension | Relational Model (PostgreSQL 16) | Document Model (MongoDB 7) | Optimal Engine for NairaPay |
|---|---|---|---|
| **Consistency Paradigm** | **ACID** (Pessimistic Locking, WAL, Strict Serializability) | **BASE** (Eventual consistency default; optional multi-document ACID) | **PostgreSQL** for Ledger; **MongoDB** for Logs |
| **Transaction Boundaries** | Multi-table, multi-row atomic transactions natively optimized | Multi-document ACID transactions available, but introduce heavy distributed lock overhead | **PostgreSQL** |
| **Data Integrity** | Declarative Foreign Keys (`ON DELETE RESTRICT`), Check constraints | `$jsonSchema` validation, application-level referential integrity | **PostgreSQL** for Financial Invariants |
| **Schema Evolution** | Structured, requires `ALTER TABLE` migrations | Schema-flexible, permits polymorphic nested attributes natively | **MongoDB** for KYC & Audit Payloads |
| **Horizontal Scalability** | Vertical scale-up, read replicas, table partitioning | Native horizontal sharding (hash-based, range-based) | **MongoDB** for High-Volume Telemetry |

### Rationale: Why the Ledger Must NEVER Move to MongoDB
While MongoDB 4.0+ supports multi-document ACID transactions, migrating NairaPay's core ledger to MongoDB would be an architectural anti-pattern for three critical reasons:

1. **Transaction Overhead & Distributed Lock Latency:** In PostgreSQL, row-level locks on `accounts` and journal appends in `ledger_entries` occur within a highly optimized local engine using Write-Ahead Logging. MongoDB multi-document transactions incur substantial latency penalties, snapshot overhead, and stricter transaction lifetime limits (default 60 seconds).
2. **Absence of Cross-Collection Foreign Key Constraints:** In financial ledgers, orphaned records represent regulatory failure. PostgreSQL guarantees that a ledger entry cannot point to a non-existent account (`ON DELETE RESTRICT`). MongoDB does not support declarative foreign key constraints across collections; relational integrity must be enforced by application logic, creating vulnerabilities to race conditions.
3. **Exact Decimal Arithmetic vs. BSON Overhead:** Financial ledgers demand exact arbitrary-precision mathematics (`NUMERIC(19,4)`). While MongoDB supports `Decimal128`, relational SQL provides native mathematical set operations and declarative check constraints (`balance >= 0`) that prevent negative balances at the physical storage layer.

**Conclusion:** The **Polyglot Persistence Architecture** deployed here represents the optimal industry paradigm: PostgreSQL serves as the immutable financial source of truth, while MongoDB delivers high-throughput, schema-flexible storage for identity verification, audit logs, and ephemeral sessions.

---

## 8. Step-by-Step Reproduction Guide

All configurations and benchmarks are fully reproducible using Docker Compose and `mongosh`.

### Step 1: Start MongoDB Container
From the repository root (`MIT8103`):
```bash
docker compose -f portfolio-4-nosql/docker-compose.yml up -d
```
Verify the container is healthy:
```bash
docker compose -f portfolio-4-nosql/docker-compose.yml ps
```

### Step 2: Set MongoDB Connection String
Export the URI pointing to the local container:
```bash
export MONGODB_URI="mongodb://nairapay_user:nairapay_pass@localhost:27017/nairapay_nosql?authSource=admin"
```

### Step 3: Initialize Collections with Schema Validation
Run script 01 to instantiate collections and verify validation enforcement:
```bash
mongosh "$MONGODB_URI" --file portfolio-4-nosql/01_schema_validation.js
```
*Expected: Prints collections and outputs `PASS: invalid KYC document rejected -> code 121`.*

### Step 4: Seed Dataset (5,000 Customers & 100,000 Audit Events)
Run script 02 to populate the database:
```bash
mongosh "$MONGODB_URI" --file portfolio-4-nosql/02_seed_data.js
```
*Expected: Takes ~30–60 seconds, outputting progress batches.*

### Step 5: Execute CRUD Operations & Aggregation Pipelines
Run script 03 and capture output:
```bash
mongosh "$MONGODB_URI" --file portfolio-4-nosql/03_crud_and_aggregation.js \
  | tee portfolio-4-nosql/output/03_crud_and_aggregation.txt
```

### Step 6: Benchmark Indexes & Validate TTL Expiration
Run script 04 to evaluate query plans and measure execution stats:
```bash
mongosh "$MONGODB_URI" --file portfolio-4-nosql/04_indexes_explain.js \
  | tee portfolio-4-nosql/output/04_indexes_explain.txt
```

---

## 9. Photographic Evidence Inventory

High-resolution visual evidence of all terminal runs and MongoDB Compass GUI inspections is catalogued in `screenshots/`:

| Screenshot File | Description & Visual Evidence |
|---|---|
| `screenshots/01_schema_validation.png` | Terminal execution of `01_schema_validation.js` showing schema validator creation and rejection of invalid KYC document (`code 121`). |
| `screenshots/02_seed_verification.png` | Terminal output confirming 5,000 KYC profiles and 100,000 audit events successfully seeded. |
| `screenshots/03_crud_output.png` | Terminal execution of `03_crud_and_aggregation.js` displaying CRUD results and 4 aggregation outputs. |
| `screenshots/05_indexes_explain.png` | Terminal benchmark output showing before/after executionStats for Q1–Q3, unique index enforcement, and index storage sizes. |
| `screenshots/06_ttl_result.png` | Terminal query verifying the automated background deletion of the expired login session. |
| `screenshots/07_compass_kyc_document.png` | MongoDB Compass document viewer displaying an expanded `kyc_profiles` record with nested identity documents. |
| `screenshots/08_compass_audit_event.png` | MongoDB Compass document viewer showing polymorphic `audit_events` with dynamic `details` payloads. |
| `screenshots/09_compass_indexes.png` | MongoDB Compass Indexes tab displaying active indexes (`idx_audit_customer_ts`, `idx_audit_type_ts`) and sizes. |
| `screenshots/10_compass_validation.png` | MongoDB Compass Validation tab showing the deployed `$jsonSchema` rules for `kyc_profiles`. |

---

## 10. Academic Reflection & Tooling Attribution

### 10.1 Academic Reflection
Working across relational (PostgreSQL) and document-oriented (MongoDB) database systems highlights the core tenets of database engineering: **there is no single database model that solves all operational problems optimally**.

Modeling polymorphic identity documents in PostgreSQL required complex multi-table inheritance or deeply nested joins that imposed significant query friction. In MongoDB, document embedding represented a far more natural and performant representation for KYC dossiers. Conversely, the absence of declarative cross-collection foreign keys reinforced why financial ledgers require relational foundations. 

Additionally, observing the transformation of Query 1 from a **65 ms `COLLSCAN > SORT`** to a **1 ms `IXSCAN > FETCH > LIMIT`** demonstrated that B-Tree indexing fundamentals (equality-first ordering and sort elimination) remain universally vital regardless of data model.

### 10.2 AI Use Disclosure
In accordance with course academic integrity policies:
- AI tools (Claude Code & Antigravity) were utilized as pair-programming assistants to draft initial script templates and structure documentation formatting.
- All Docker container configurations, JavaScript queries, aggregation pipelines, and index benchmarks were executed, verified, and captured locally against a live MongoDB 7 instance on macOS aarch64.
- All benchmark metrics, execution plan stages, document counts, and latencies reported in this document reflect verified empirical outputs.
