# NoSQL Architecture, Document Modeling, and Polyglot Persistence Analysis

**Course:** MIT 8103 – Advanced Database Systems  
**Module:** Portfolio 4 – NoSQL and Advanced Data Models  
**System Under Test:** `nairapay_nosql` (MongoDB 7.0 via Docker container `nairapay-mongo` and MongoDB Compass) & `nairapay_db` (PostgreSQL 16)  
**Enterprise Context:** NairaPay Technologies Limited (Simulated Nigerian Payment Service Provider)  
**Target Workload:** Heterogeneous KYC Verification Records, High-Volume Security Audit Streams, and Ephemeral Sessions  
**Accompanying Repository Artifacts:** [README.md](README.md), [00_docker_setup.md](00_docker_setup.md), [01_schema_validation.js](01_schema_validation.js), [02_seed_data.js](02_seed_data.js), [03_crud_and_aggregation.js](03_crud_and_aggregation.js), [04_indexes_explain.js](04_indexes_explain.js), [output/03_crud_and_aggregation.txt](output/03_crud_and_aggregation.txt), [output/04_indexes_explain.txt](output/04_indexes_explain.txt)  

---

## 1. Executive Summary

Enterprise financial platforms handle data domains with starkly contrasting consistency, mutation, and structural requirements. While core accounting ledgers demand rigid 3NF relational schemas, multi-row ACID guarantees, and strict referential integrity (as engineered in **Portfolios 1, 2, and 3**), surrounding operational subsystems face different data management challenges:
- **Polymorphic KYC Verification:** Customer onboarding dossiers contain heterogeneous identification documents (BVNs, NINs, Nigerian International Passports, Driver's Licenses, and Disco Utility Bills), each with unique metadata attributes.
- **High-Velocity Audit Logging:** Security surveillance records (logins, IP geolocation, device fingerprints, and fraud evaluation flags) arrive at high write frequencies with dynamic event payloads.
- **Ephemeral Authentication Sessions:** Transient JWT tokens and login states require automated lifecycle termination without invoking costly table maintenance batch jobs.

To address these requirements without compromising relational ledger integrity, **Portfolio 4** implements a **Polyglot Persistence Architecture**, deploying **MongoDB 7** alongside PostgreSQL.

```
+----------------------------------------------------------------------------------------------------+
|                                    KEY NOSQL BENCHMARK HIGHLIGHTS                                  |
+------------------------------------+--------------------------------+------------------------------+
| Metric                             | Before Indexing (COLLSCAN)     | After Indexing (IXSCAN)      |
+------------------------------------+--------------------------------+------------------------------+
| Q1 Audit Events Latency            | 65 ms                          | 1 ms (65.0x speedup)         |
| Q1 Scanned Documents               | 100,000 documents examined     | 20 documents examined        |
| Q1 In-Memory Sort Overhead         | SORT Stage Active              | Eliminated by B-Tree Index   |
| Q2 Fraud Flag Scanned Documents    | 100,000 documents examined     | 373 documents examined       |
| Q3 Unique Constraint Enforcement   | Non-enforced (COLLSCAN)        | Hard Reject: Error Code 11000|
| Automated Session Expiration       | Requires manual cron / DELETE  | Native Background TTL Purge  |
| Schema Invariant Rejection         | Schema-Flexible                | Hard Reject: Error Code 121  |
+------------------------------------+--------------------------------+------------------------------+
```

---

## 2. Theoretical Foundations: Relational vs. Document Data Modeling

The relational model (Codd, 1970) and the document model represent two distinct paradigms for organizing and querying enterprise information.

### 2.1 The Impedance Mismatch in Financial Data
In relational systems, entities are decomposed into normalized two-dimensional relations (tables) linked via primary and foreign keys. When modeling nested, real-world hierarchies (such as a customer and their various identity documents), relational databases encounter the **Object-Relational Impedance Mismatch**:
1. **The Sparse Column Problem:** Modeling identity documents in a single SQL table (`kyc_documents`) requires numerous columns (`passport_expiry`, `passport_country`, `drivers_licence_state`, `disco_provider`, `meter_number`). For any given document type, the majority of columns are `NULL`, wasting disk space and complicating query predicates.
2. **The Entity-Attribute-Value (EAV) Anti-Pattern:** Attempting to achieve schema flexibility in SQL by using an EAV table (`document_id, attribute_key, attribute_val`) destroys data typing, bypasses check constraints, and requires complex multi-table self-joins for basic reporting.
3. **Join Latency at Scale:** Reconstructing a customer's verification dossier requires multi-table relational joins across `customers`, `kyc_records`, `documents`, and `verification_logs`, increasing buffer contention during high-volume customer lookups.

### 2.2 The Document Model: Atomicity via Encapsulation
The document model resolves the impedance mismatch by representing data as self-contained, hierarchical BSON (Binary JSON) documents:
- **Data Locality:** All data attributes required to represent a customer's KYC profile reside within a contiguous block of disk and memory.
- **Single-Document Atomicity:** In MongoDB, all write operations on a single document are **atomic at the storage engine level (WiredTiger)**, even when modifying nested arrays and subdocuments. Promoting a customer to Tier 3, updating their status to `VERIFIED`, and appending a utility bill executes as an indivisible atomic operation without the overhead of multi-row relational locks.

---

## 3. Polyglot Architecture & Cross-Database Consistency

NairaPay adopts a **Polyglot Persistence Pattern**, assigning data workloads to the database engine specifically optimized for their operational profile:

```mermaid
flowchart TD
    subgraph Client Applications
        MobileApp["Mobile Wallet App"]
        AdminDesk["Risk & Compliance Desk"]
    end

    subgraph Relational Core (PostgreSQL 16)
        PG_DB[("PostgreSQL: nairapay_db<br/>• accounts<br/>• transactions<br/>• ledger_entries<br/>• customers")]
    end

    subgraph Document Store (MongoDB 7)
        Mongo_DB[("MongoDB: nairapay_nosql<br/>• kyc_profiles<br/>• audit_events<br/>• login_sessions")]
    end

    MobileApp -->|"P2P Transfers & Invariant Balances<br/>(Strict Multi-Row ACID)"| PG_DB
    MobileApp -->|"Onboarding & KYC Document Uploads<br/>(Polymorphic BSON)"| Mongo_DB
    MobileApp -->|"Authentication & Session Creation<br/>(1-Hour TTL)"| Mongo_DB
    AdminDesk -->|"Security Event Surveillance<br/>(Append-Only Audit Stream)"| Mongo_DB

    PG_DB -.->|"Logical Link: customer_id<br/>(Transactional Outbox / CDC)"| Mongo_DB
```

### 3.1 Managing Cross-Database Referential Boundaries
Because foreign keys cannot cross database network boundaries between PostgreSQL and MongoDB, distributed architectures risk data divergence:
- **Failure Mode:** A customer record is inserted and committed in PostgreSQL, but an application crash or network timeout prevents the KYC document from being created in MongoDB, leaving an orphaned customer unable to onboard.
- **Enterprise Solution: Transactional Outbox Pattern:**
  1. When a customer is created in PostgreSQL, an outbox record is inserted into `outbox_events` within the **exact same ACID transaction**.
  2. A Change Data Capture (CDC) worker (such as Debezium or an asynchronous background daemon) reads the outbox table via PostgreSQL WAL logical replication.
  3. The worker publishes the event to an Apache Kafka topic, which feeds MongoDB consumer services with at-least-once, idempotent delivery guarantees.

---

## 4. Document Modeling Strategy: Embedding vs. Referencing

A core design decision in document database engineering is choosing between **Embedded Subdocuments** and **Normalized References**.

```mermaid
classDiagram
    class KYC_Profile {
        ObjectId _id
        Number customer_id
        Number tier
        String status
        Array documents [Embedded]
        Date created_at
    }

    class Document_Subdocument {
        String type
        String number
        String verified_with
        Date expiry
        String provider
    }

    class Audit_Event {
        ObjectId _id
        Number customer_id [Referenced]
        String event_type
        Date ts
        Object details
    }

    KYC_Profile *-- Document_Subdocument : Embeds (1:Few Bounded)
    KYC_Profile <.. Audit_Event : References (1:Unbounded)
```

### 4.1 Embedding: `kyc_profiles.documents`
- **Relationship:** 1:Few bounded cardinality.
- **Implementation:** Identity documents are embedded directly inside an array in `kyc_profiles`.
- **Architectural Rationale:**
  - A customer rarely possesses more than 4 or 5 identity documents. The document size remains well below MongoDB's **16 MB BSON size limit** ($\approx 1.5 \text{ KB}$ per profile).
  - The profile and its documents are always retrieved together by verification personnel; embedding eliminates join overhead and ensures atomic updates.

### 4.2 Referencing: `audit_events`
- **Relationship:** 1:Unbounded cardinality.
- **Implementation:** Audit events are stored in a separate collection containing a `customer_id` scalar reference.
- **Architectural Rationale:**
  - An active customer generates tens of thousands of security, authentication, and transaction events over years of platform use.
  - Embedding events into the customer document would quickly breach the 16 MB boundary and cause massive memory fragmentation as WiredTiger continuously reallocates growing documents on disk.
  - Storing events in a dedicated collection allows high-throughput append-only writes and broad time-series range scans across all platform users.

---

## 5. Schema Validation Engine ($jsonSchema)

A persistent myth in database systems is that NoSQL implies "schema-less." In enterprise software, unstructured data quickly leads to silent corruption. MongoDB provides **Schema Flexibility with Structural Governance** via `$jsonSchema` validators.

### 5.1 Enforced Invariants in `01_schema_validation.js`
In `01_schema_validation.js`, collections are instantiated with explicit validation rules:
- **Mandatory Attributes:** `customer_id`, `tier`, `status`, `documents`, and `created_at` must exist on every document.
- **Range Constraints:** `tier` must be an integer between 1 and 3; `customer_id` must be $\ge 1$.
- **Enum Governance:** `status` is strictly limited to `['PENDING', 'VERIFIED', 'REJECTED']`.
- **Nested Array Invariants:** The `documents` array must contain at least one item (`minItems: 1`). Every embedded object must contain a valid `type` enum (`BVN`, `NIN`, `PASSPORT`, `DRIVERS_LICENCE`, `UTILITY_BILL`) and a string `number`.
- **Rejection Enforcement:** `validationAction: 'error'` instructs the engine to immediately reject non-conforming writes.

### 5.2 Empirical Verification
When an invalid document (`{ customer_id: 1, status: 'MAYBE' }`) was submitted:
```
MongoServerError: Document failed validation
  code: 121
  codeName: 'DocumentValidationFailure'
```
*Visual Evidence:* [`screenshots/01_schema_validation.png`](screenshots/01_schema_validation.png) and [`screenshots/10_compass_validation.png`](screenshots/10_compass_validation.png) confirm that invalid writes are intercepted and blocked at the storage engine layer.

---

## 6. Analytical Aggregation Pipelines (MQL Deep Dive)

MongoDB's Aggregation Framework provides a declarative data processing pipeline modeled after Unix pipes, transforming streams of BSON documents through sequential stages.

### 6.1 Dissecting Aggregation 3: Correlated `$lookup` Join
Aggregation Pipeline 3 detects credential stuffing attacks by identifying the top 5 customers with the most failed logins and joining their audit profile with their KYC verification record:

```javascript
nosql.audit_events.aggregate([
    { $match: { event_type: 'LOGIN_FAILED' } },
    { $group: { _id: '$customer_id', failed_logins: { $sum: 1 } } },
    { $sort: { failed_logins: -1, _id: 1 } },
    { $limit: 5 },
    { $lookup: { from: 'kyc_profiles', localField: '_id', foreignField: 'customer_id', as: 'kyc' } },
    { $unwind: '$kyc' },
    { $project: { _id: 0, customer_id: '$_id', failed_logins: 1, tier: '$kyc.tier', status: '$kyc.status' } }
]);
```

#### Pipeline Stage Optimization Analysis:
1. **Early Filtering (`$match`):** Placed at stage 1 to filter out 95,000+ non-failure events immediately, minimizing memory allocation in the pipeline buffer.
2. **Hash Aggregation (`$group`):** Accumulates failure counts per `customer_id` into an in-memory hash table.
3. **Pipeline Top-N Optimization (`$sort` + `$limit`):** When `$sort` is immediately followed by `$limit`, MongoDB does not sort the entire intermediate dataset; it maintains a bounded top-N heap buffer of size 5, reducing memory complexity to $O(N \log 5)$.
4. **Correlated Distributed Join (`$lookup`):** Executes an equality join from `audit_events._id` to `kyc_profiles.customer_id`. Because `kyc_profiles.customer_id` is indexed with a unique B-Tree, each join lookup executes in $O(\log M)$ time rather than performing a full collection scan.

#### Verified Output:
```json
{ "customer_id": 4744, "failed_logins": 12, "tier": 1, "status": "VERIFIED" }
{ "customer_id": 820,  "failed_logins": 11, "tier": 2, "status": "VERIFIED" }
{ "customer_id": 1485, "failed_logins": 11, "tier": 2, "status": "VERIFIED" }
{ "customer_id": 2768, "failed_logins": 10, "tier": 1, "status": "REJECTED" }
{ "customer_id": 3919, "failed_logins": 10, "tier": 1, "status": "PENDING" }
```

---

## 7. Index Engineering and WiredTiger Query Plan Analysis

Query optimization in MongoDB's WiredTiger storage engine operates on B-Tree index structures, following the same fundamental access-path principles explored in PostgreSQL.

### 7.1 Empirical Performance Evaluation (Before vs. After)
*Data extracted directly from verified benchmark log [`output/04_indexes_explain.txt`](output/04_indexes_explain.txt):*

| Query Profile | Predicates & Sort | Before Plan | After Plan | Docs Scanned (Before) | Docs Scanned (After) | Latency Before | Latency After | Speedup Factor |
|---|---|---|---|---|---|---|---|---|
| **Q1: Customer Events** | `customer_id: 1001`, `sort(ts: -1)` | `SORT > COLLSCAN` | `LIMIT > FETCH > IXSCAN` | **100,000** | **20** | **65 ms** | **1 ms** | **65.0× faster** |
| **Q2: Recent Fraud** | `event_type: 'FRAUD_FLAG'`, `ts >= 7d` | `COLLSCAN` | `FETCH > IXSCAN` | **100,000** | **373** | **64 ms** | **2 ms** | **32.0× faster** |
| **Q3: KYC Profile** | `customer_id: 2500` | `COLLSCAN` | `EXPRESS_IXSCAN` | **5,000** | **1** | **3 ms** | **1 ms** | **3.0× faster** |

```
QUERY 1 EXECUTION PLAN STAGES (WiredTiger Engine)
Before Index: [COLLSCAN (100k docs)] -> [SORT (in-memory)] -> [LIMIT 20] -> 65 ms
After Index:  [IXSCAN (20 keys)] -> [FETCH (20 docs)] -> [LIMIT 20]      -> 1 ms (65x faster)
```

### 7.2 Technical Mechanics of Sort Elimination
In Query 1, the compound index `{ customer_id: 1, ts: -1 }` demonstrates **Index Sort Elimination**:
- **Without Index:** WiredTiger must scan every document in the collection (`COLLSCAN`), filter for `customer_id: 1001`, load all matching documents into an in-memory sort buffer, execute an expensive quicksort, and return the top 20 documents. If the sort buffer exceeds 33 MB, MongoDB aborts the query unless disk-spilling is explicitly enabled.
- **With Compound Index:** The B-Tree stores leaf nodes sorted primarily by `customer_id` ascending, and secondarily by `ts` descending. The query planner traverses the B-Tree directly to the `customer_id: 1001` entry and reads the first 20 leaf pointers. Because the keys are physically ordered by timestamp descending, **no in-memory sort stage is executed**. The engine streams the first 20 records and terminates immediately.

---

### 7.3 Automated Document Lifecycle: TTL Indexes
Managing session expiration in relational databases requires scheduled cron jobs executing `DELETE FROM login_sessions WHERE expires_at < NOW()`, causing deadlocks and index fragmentation.

MongoDB provides native **Time-To-Live (TTL) Indexes**:
```javascript
nosql.login_sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600, name: 'ttl_session_1h' });
```
- **WiredTiger Engine Mechanics:** A background thread in `mongod` awakes once every 60 seconds, inspects the TTL index on `created_at`, identifies keys where $\text{created\_at} + 3600\text{s} < \text{current\_time}$, and purges the expired documents in the background.
- **Empirical Validation:** Two sessions were inserted (`tok-recent` and `tok-old` created 2 hours prior). Within 60 seconds, `tok-old` was automatically deleted by the background thread, while `tok-recent` remained untouched ([`screenshots/06_ttl_result.png`](screenshots/06_ttl_result.png)).

---

## 8. Physical Storage Overheads and Write Amplification

Secondary indexes are not zero-cost abstractions. In write-intensive systems, maintaining multiple B-Trees consumes storage and introduces write amplification.

### 8.1 Physical Footprint Analysis
*Measured via `collStats` across the seeded collections:*

| Collection Name | Document Count | Raw Data Size | Index Storage Size | Total Footprint | Index-to-Data Ratio |
|---|---|---|---|---|---|
| **`audit_events`** | 100,000 | 14.5 MB | 5.3 MB | 19.8 MB | **36.6%** |
| **`kyc_profiles`** | 5,000 | 1.2 MB | 0.3 MB | 1.5 MB | **25.0%** |

- On `audit_events`, maintaining two compound indexes (`idx_audit_customer_ts` and `idx_audit_type_ts`) adds **5.3 MB of storage**, representing a **36.6% storage overhead**.
- Every incoming `audit_event` insert requires three discrete disk writes: one to the collection heap, one to `idx_audit_customer_ts`, and one to `idx_audit_type_ts`.
- **Fintech Justification:** For an audit surveillance platform, paying a 36.6% storage penalty and minor insert write overhead is fully justified by the **6,400% query latency reduction (65 ms to 1 ms)**, which is critical for real-time automated fraud detection.

---

## 9. Academic Reflection & Conclusion

### 9.1 Reflection on Polyglot Architecture
Implementing Portfolio 4 demonstrated that database engineering is not about selecting a single "best" database engine, but about matching data structures and access patterns to the optimal storage paradigm:
1. **Relational Invariance for Financial Balances:** PostgreSQL's strict schema, foreign key cascades, check constraints, and multi-row ACID locking make it irreplaceable for the double-entry financial ledger. Moving the core ledger to MongoDB would introduce severe consistency risks.
2. **Document Encapsulation for KYC Dossiers:** Attempting to force polymorphic identity documents into relational tables leads to sparse columns, nullable foreign keys, or EAV anti-patterns. MongoDB's document model represents tiered KYC records naturally and cleanly.
3. **Automated Lifecycle Management:** Utilizing native database primitives like TTL indexes eliminates brittle application-level maintenance cron jobs.

### 9.2 Conclusion
By deploying MongoDB alongside PostgreSQL, NairaPay establishes a resilient, production-ready polyglot architecture. The relational core provides an immutable financial source of truth, while the document layer delivers scalable, schema-flexible storage for identity verification, audit trails, and ephemeral sessions.

---

## 10. References and Standards

1. **Codd, E. F. (1970).** *A Relational Model of Data for Large Shared Data Banks.* Communications of the ACM, 13(6), pp. 377–387.
2. **MongoDB Inc. (2024).** *MongoDB Manual: Data Models and Schema Validation.* Available at: https://www.mongodb.com/docs/manual/core/data-modeling-introduction/
3. **WiredTiger Inc. (2024).** *WiredTiger Architecture and Storage Engine Internals.* Available at: https://source.wiredtiger.com/
4. **Fowler, M. (2011).** *Polyglot Persistence.* MartinFowler.com.
5. **Central Bank of Nigeria (CBN).** *Circular on Tiered Know Your Customer (KYC) Requirements.* Circular FPR/DIR/GEN/CIR/01/014.

