# Distributed Database Systems, High Availability, and Cloud Persistence Analysis

**Course:** MIT 8103 – Advanced Database Systems  
**Module:** Portfolio 5 – Distributed Databases, Replication, and Cloud Deployment  
**System Under Test:** `nairapay_db` (PostgreSQL 16 Primary & Streaming Standby) & `nairapay_nosql` (MongoDB Atlas 3-Node Cloud Replica Set)  
**Enterprise Context:** NairaPay Technologies Limited (Simulated Nigerian Payment Service Provider)  
**Target Architecture:** Distributed Master-Standby Replication, Declarative Partitioning, High-Availability Failover, and Polyglot Cloud Integration  
**Accompanying Repository Artifacts:** [README.md](README.md), [docker-compose.yml](docker-compose.yml), [01_primary_checks.sql](01_primary_checks.sql), [02_replica_checks.sql](02_replica_checks.sql), [03_partitioning.sql](03_partitioning.sql), [04_atlas_cloud_check.js](04_atlas_cloud_check.js), [output/03_partitioning.txt](output/03_partitioning.txt)  

---

## 1. Executive Summary

Enterprise financial technology platforms operate in an environment characterized by relentless transaction growth, unpredictable network drops, and zero tolerance for data loss. In **Portfolios 1 through 3**, NairaPay's core relational engine was established on a single PostgreSQL node, proving mathematical conservation of funds, optimizing B-Tree access paths, and enforcing pessimistic transaction concurrency. In **Portfolio 4**, semi-structured KYC dossiers and security audit trails were offloaded to a polyglot document model.

**Portfolio 5** addresses the fundamental scaling, availability, and disaster-recovery limits of single-node database hosting. This report delivers an exhaustive theoretical and empirical analysis of:
1. **Physical Streaming Replication:** Implementing continuous binary Write-Ahead Log (WAL) streaming from an active primary (`nairapay-pg-primary`, port 5433) to a physical read replica (`nairapay-pg-replica`, port 5434) using persistent replication slots (`replica1_slot`).
2. **Replication Anomalies & Stale Reads:** Experimentally proving the occurrence of stale reads during replica network freezing and measuring recovery LSN catch-up.
3. **Consistency vs. Availability (CAP / PACELC):** Demonstrating the trade-offs of asynchronous vs. synchronous replication, including an empirical recreation of the synchronous "hung write" failure mode when standby nodes become unreachable.
4. **Declarative Hash Partitioning:** Evaluating a 4-way hash partitioning model on 412,058 ledger entries, demonstrating **100% Partition Pruning** for single-account access versus parallel **Scatter-Gather** scans for non-keyed reporting.
5. **High-Availability Failover & Split-Brain Dynamics:** Analyzing manual promotion, sequence number gaps, fencing protocols (STONITH), and recovery objectives (RPO and RTO).
6. **Managed Cloud Persistence:** Validating cloud replica set topology, `w: majority` write durability, and secondary read offloading on **MongoDB Atlas**.

```
+-------------------------------------------------------------------------------------------------------+
|                                    DISTRIBUTED CLUSTER BENCHMARK SUMMARY                              |
+------------------------------------+-----------------------------------+------------------------------+
| Architectural Dimension            | Relational Cluster (PostgreSQL 16)| Cloud Cluster (MongoDB Atlas)|
+------------------------------------+-----------------------------------+------------------------------+
| Topology                           | 1 Primary + 1 Streaming Standby   | 3-Node Multi-AZ Replica Set  |
| Replication Protocol               | Physical WAL Streaming (TCP)      | Raft-Style Consensus (Oplog) |
| Steady-State Replay Lag            | 00:00:00 (0 bytes LSN lag)        | Near real-time (< 50 ms)     |
| Partitioning / Sharding Scale      | 412,058 ledger rows / 4 shards    | Single collection / Multi-AZ |
| Single-Shard Pruning Speedup       | 1 partition scanned (vs. 4)       | Index-routed secondary reads |
| Write Durability Mechanism         | WAL Fsync / Synchronous Commit    | w: 'majority' (2 of 3 nodes) |
| Failover Recovery RTO              | Minutes (Manual Promotion)        | < 10 seconds (Automated Raft)|
+------------------------------------+-----------------------------------+------------------------------+
```

---

## 2. Distributed Systems Theory: CAP, PACELC, and Consensus

The architecture of distributed financial databases is governed by fundamental theorems in distributed systems theory.

### 2.1 The CAP Theorem Applied to Fintech
Formulated by Eric Brewer (2000) and formally proven by Gilbert and Lynch (2002), the **CAP Theorem** states that a distributed data store can simultaneously provide at most two of the following three guarantees:
- **Consistency ($C$):** Equivalent to single-copy serializability; every read receives the most recent write or an error.
- **Availability ($A$):** Every non-failing node returns a non-error response for every received request (without guaranteeing it contains the most recent write).
- **Partition Tolerance ($P$):** The system continues to operate despite arbitrary message loss or network partitions.

In real-world networks—particularly across Nigerian telecommunications and interbank switching infrastructure (e.g., NIBSS)—**network partitions ($P$) are an unavoidable physical reality**. Routers drop packets, fiber cables are severed, and cloud availability zones experience transient network partitioning. Consequently, database architects cannot choose "CA"; they must choose between **Consistency ($CP$)** and **Availability ($AP$)** during a partition:

```mermaid
graph TD
    NetworkPartition["Network Partition (P) Occurs"]
    NetworkPartition --> ChoiceCP["Choice 1: CP (Consistency Priority)"]
    NetworkPartition --> ChoiceAP["Choice 2: AP (Availability Priority)"]
    
    ChoiceCP --> ImpactCP["Block writes on primary if replica cannot acknowledge.<br/>Preserves ledger truth; system becomes unavailable.<br/>*NairaPay Ledger Choice*"]
    ChoiceAP --> ImpactAP["Allow writes on primary and reads on stale replica.<br/>Preserves uptime; causes double-spending and ledger drift.<br/>*Unacceptable for Core Banking*"]
```

For NairaPay's core ledger, **Consistency ($CP$) is non-negotiable**. If a network partition prevents replication, allowing writes to continue without durability guarantees invites catastrophic financial loss. It is preferable for an automated transfer to fail cleanly with a service timeout than to acknowledge a deposit that vanishes during failover.

### 2.2 The PACELC Extension
Daniel Abadi (2012) expanded CAP into the **PACELC Theorem**, observing that trade-offs exist even during normal, partition-free operations:
- **If Partition ($P$):** Trade-off between Availability ($A$) and Consistency ($C$).
- **Else ($E$):** Trade-off between Latency ($L$) and Consistency ($C$).

Applying PACELC to NairaPay's deployment:
- **PostgreSQL Asynchronous Replication:** Evaluates to **PC/EC** in intent, but operates as **PA/EL** in default configuration. During normal operations, it optimizes for low latency ($EL$) by committing locally without waiting for the network; during a partition, it maintains availability ($PA$) on the primary at the cost of stale reads on the standby.
- **PostgreSQL Synchronous Replication:** Operates strictly as **PC/EC**. Normal writes incur network latency ($EC$) to guarantee consistency; during partitions, writes halt ($PC$) to prevent divergence.
- **MongoDB Atlas (`w: majority`):** Operates as **PC/EC**. Normal writes wait for majority quorum acknowledgment, and partitioned minorities refuse writes.

---

### 2.3 Distributed Consensus: 2PC vs. Raft/Paxos
Maintaining consistency across multiple nodes requires formal consensus protocols:

```mermaid
sequenceDiagram
    autonumber
    participant Coord as Coordinator / Primary
    participant NodeA as Storage Node A
    participant NodeB as Storage Node B

    Note over Coord,NodeB: Phase 1: Prepare Phase
    Coord->>NodeA: PREPARE Transaction T
    Coord->>NodeB: PREPARE Transaction T
    NodeA->>Coord: VOTE_COMMIT (Locked locally)
    NodeB->>Coord: VOTE_COMMIT (Locked locally)

    Note over Coord,NodeB: Phase 2: Commit Phase
    Coord->>NodeA: GLOBAL_COMMIT
    Coord->>NodeB: GLOBAL_COMMIT
    NodeA->>Coord: ACK
    NodeB->>Coord: ACK
```

#### Two-Phase Commit (2PC):
In distributed relational databases, cross-shard atomic transactions rely on 2PC:
1. **Prepare Phase:** The coordinator sends a `PREPARE` request to all participating nodes. Each node acquires local row locks, flushes undo/redo logs to disk, and votes `VOTE_COMMIT` or `VOTE_ABORT`.
2. **Commit Phase:** If all nodes vote commit, the coordinator writes a `GLOBAL_COMMIT` record to its WAL and broadcasts `COMMIT` to all participants.
- **Fatal Flaw of 2PC:** It is a **blocking protocol**. If the coordinator crashes after nodes have voted commit but before broadcasting the decision, participant nodes remain indefinitely locked ("in doubt"), unable to abort or commit, paralyzing the database.

#### Raft / Paxos Consensus:
Modern cloud systems (including MongoDB Atlas and Patroni) avoid 2PC's blocking nature by utilizing quorum-based consensus (Raft or Paxos):
- Consensus is reached when a **simple majority ($\lfloor N/2 \rfloor + 1$)** of nodes acknowledge an entry.
- A cluster of $2F + 1$ nodes can survive $F$ node failures without blocking.
- In a 3-node MongoDB Atlas replica set, any 2 nodes constitute a quorum. If one secondary dies, the primary and remaining secondary continue processing writes with zero downtime.

---

## 3. PostgreSQL Physical Streaming Replication Internals

Physical streaming replication in PostgreSQL 16 operates at the storage layer below the SQL parser, streaming raw binary byte offsets of the Write-Ahead Log.

```mermaid
flowchart LR
    subgraph Primary Server [nairapay-pg-primary :5433]
        AppWrite["Application Write<br/>(INSERT/UPDATE)"] --> Backend["Postgres Backend"]
        Backend --> WALBuffer["WAL Buffers"]
        WALBuffer --> WALFile["Physical WAL Segments<br/>(16 MB files in pg_wal)"]
        WALFile --> WalSender["walsender Process<br/>(Reads from replica1_slot)"]
    end

    subgraph Replica Server [nairapay-pg-replica :5434]
        WalSender -->|"TCP Stream (Port 5432)"| WalReceiver["walreceiver Process"]
        WalReceiver --> StandbyWAL["Standby WAL Buffers"]
        StandbyWAL --> StartupProc["Startup / Redo Process"]
        StartupProc --> StandbyHeap["Shared Buffers / Heap Pages<br/>(Read-Only Hot Standby)"]
    end
```

### 3.1 The Replication Architecture
1. **The Log Sequence Number (LSN):** Every database mutation appends a record to the WAL, indexed by a 64-bit integer called the LSN (e.g., `0/18000060`), representing the exact byte offset in the transaction log stream.
2. **`walsender` Process:** When `nairapay-pg-replica` connects, the primary forks a dedicated `walsender` daemon. This process reads committed and uncommitted WAL records from memory or disk and transmits them over a TCP socket.
3. **`walreceiver` Process:** The standby background process that receives WAL frames from the primary, writes them to the standby's log files, and flushes them to disk.
4. **Startup / Redo Process:** Continuously reads the standby's received WAL stream and applies the physical binary diffs directly to the standby's data pages in shared memory, mirroring the primary's state bit-for-bit.
5. **Hot Standby Mode (`hot_standby = on`):** Allows client read queries to execute against the standby while the startup process is actively replaying WAL logs.

---

### 3.2 Persistent Replication Slots (`replica1_slot`)
In legacy PostgreSQL deployments, standby nodes relied on `wal_keep_size` to retain WAL files on the primary. If the standby disconnected for longer than the buffer duration, the primary recycled older WAL files, resulting in catastrophic replication failure:
```
FATAL: could not receive data from WAL stream: ERROR: requested WAL segment has already been removed
```
Resolving this required taking a complete physical base backup from scratch.

PostgreSQL **Replication Slots** solve this failure mode natively:
- A replication slot guarantees that the primary server **will never delete, overwrite, or recycle any WAL segment** until the standby associated with that slot has confirmed that it has received and replayed the segment.
- Telemetry from `01_primary_checks.sql` confirms the active slot:
  ```
     slot_name   | slot_type | active | restart_lsn 
  ---------------+-----------+--------+-------------
   replica1_slot | physical  | t      | 0/18000060
  ```
- **Operational Risk:** If a standby is permanently decommissioned without dropping its replication slot, the primary will retain WAL segments indefinitely, eventually consuming 100% of the disk volume and causing a catastrophic database crash. Monitoring `pg_replication_slots.restart_lsn` is a mandatory operational requirement.

---

### 3.3 Replication Telemetry Analysis

Querying `pg_stat_replication` on the primary provides real-time distributed synchronization metrics:

```sql
SELECT application_name, client_addr, state, sync_state,
       sent_lsn, write_lsn, flush_lsn, replay_lsn, replay_lag
FROM pg_stat_replication;
```

#### Diagnostic Breakdown:
- **`state = streaming`:** The standby is actively receiving live WAL frames over the TCP connection.
- **`sync_state = async`:** Operating in asynchronous replication mode; the primary does not wait for standby confirmation before acknowledging client commits.
- **LSN Progression Tracking:**
  - `sent_lsn`: The latest byte offset transmitted across the network by `walsender`.
  - `write_lsn`: The offset written to the standby OS file cache by `walreceiver`.
  - `flush_lsn`: The offset flushed to physical disk (`fsync`) by the standby.
  - `replay_lsn`: The offset successfully applied to heap pages by the standby redo engine.
- In our steady-state benchmark, `sent_lsn == replay_lsn == 0/18000060`, confirming **zero byte lag and sub-millisecond replication latency**.

---

## 4. Empirical Concurrency & Replication Experiments

### 4.1 Experiment 1: The Asynchronous Stale Read Window
- **Hypothesis:** Under asynchronous replication, if the standby network is interrupted or frozen, the standby will serve outdated historical data (violating Read-Your-Own-Writes consistency) without throwing an error.
- **Visual Evidence:** [`screenshots/05_stale_read.png`](screenshots/05_stale_read.png), [`screenshots/06_caught_up.png`](screenshots/06_caught_up.png), [`screenshots/freeze_the_replica.png`](screenshots/freeze_the_replica.png), [`screenshots/marker_table.png`](screenshots/marker_table.png).

#### Experimental Execution:
1. **Inducing Standby Freeze:** The replica container was paused:
   ```bash
   docker pause nairapay-pg-replica
   ```
   *Mechanism:* The Linux kernel suspends the `walreceiver` process; incoming TCP packets are buffered in the OS socket queue.
2. **Primary Mutation:** A marker table representing a recent financial deposit was committed to the primary:
   ```sql
   CREATE TABLE p5_stale_test (id INT, note TEXT, written_at TIMESTAMPTZ);
   INSERT INTO p5_stale_test VALUES (1, 'Alice deposit 50,000 NGN', clock_timestamp());
   ```
3. **Querying the Standby:** Querying the replica on port 5434 yielded:
   ```
   ERROR: relation "p5_stale_test" does not exist
   LINE 1: SELECT * FROM p5_stale_test;
   ```
4. **Resuming Standby & Catch-Up:** Running `docker unpause nairapay-pg-replica` allowed the `walreceiver` to resume. The standby replayed all backlog LSN segments within 1.4 seconds, making the table visible.

#### Financial Engineering Implications:
This experiment proves that **wallet balance checks must never be routed to asynchronous read replicas**. If Alice receives a transfer on the primary, opens her mobile app, and her balance query hits an asynchronous replica lagging by even 500 milliseconds, she will see her pre-transfer balance. Worse, if she attempts to spend funds that were just deducted, an asynchronous replica might report sufficient funds, permitting an overdraft.

---

### 4.2 Experiment 2: The Synchronous Replication Availability Collapse
- **Hypothesis:** Under synchronous replication, if the single standby fails or hangs, the primary will sacrifice 100% of write availability to uphold the consistency guarantee ($C \implies \neg A$).
- **Visual Evidence:** [`screenshots/07_sync_hang.png`](screenshots/07_sync_hang.png), [`screenshots/08_sync_warning.png`](screenshots/08_sync_warning.png).

#### Experimental Execution:
1. **Enabling Strict Synchronous Replication:**
   ```sql
   ALTER SYSTEM SET synchronous_commit = 'on';
   ALTER SYSTEM SET synchronous_standby_names = 'replica1_slot';
   SELECT pg_reload_conf();
   ```
2. **Inducing Standby Outage:** Paused `nairapay-pg-replica`.
3. **Executing Write on Primary:**
   ```sql
   INSERT INTO accounts (customer_id, account_number, balance)
   VALUES (1001, '9876543210', 1000.00);
   ```
4. **Empirical Behavior:** The query hung completely. The primary successfully wrote the tuple and flushed its local WAL, but refused to release locks or return a `COMMIT` acknowledgment to the client application.
5. **Client Abort & Warning:** After 30 seconds of blocking, client connections threw lock wait and network timeout exceptions.

#### Engineering Conclusion:
Operating synchronous replication with a single standby creates a fatal **Single Point of Failure (SPOF)**. Any routine maintenance, OS patching, or transient network hiccup on the standby instantly halts all payment processing globally. Therefore, production financial systems must deploy **Quorum Synchronous Replication** (`synchronous_standby_names = 'ANY 1 (standby1, standby2)'`) across at least two independent standby nodes.

---

## 5. Horizontal Partitioning vs. Distributed Sharding

When financial datasets expand into hundreds of millions of ledger entries, vertical scaling reaches hardware boundaries. Partitioning and sharding divide massive relational tables into smaller, manageable subsets.

### 5.1 Single-Node Hash Partitioning Implementation
In `03_partitioning.sql`, NairaPay's core ledger was re-engineered from an unpartitioned table into a 4-way declarative hash partitioned table:

```mermaid
flowchart TD
    ClientQuery["INSERT / SELECT Query<br/>(account_id = 1001)"] --> Routing{"Hash Routing Engine<br/>hash(account_id) % 4"}
    
    Routing -- "Remainder 0" --> Shard0["ledger_shard_0<br/>(105,512 rows / 25.6%)"]
    Routing -- "Remainder 1" --> Shard1["ledger_shard_1<br/>(103,260 rows / 25.1%)"]
    Routing -- "Remainder 2" --> Shard2["ledger_shard_2<br/>(103,340 rows / 25.1%)"]
    Routing -- "Remainder 3" --> Shard3["ledger_shard_3<br/>(99,946 rows / 24.3%)"]
```

#### Hash Uniformity Evaluation:
*Empirical row counts extracted from [`output/03_partitioning.txt`](output/03_partitioning.txt):*

| Physical Partition Table | Assigned Hash Remainder | Actual Row Count | Percentage Distribution |
|---|---|---|---|
| `ledger_shard_0` | `MODULUS 4, REMAINDER 0` | 105,512 | **25.61%** |
| `ledger_shard_1` | `MODULUS 4, REMAINDER 1` | 103,260 | **25.06%** |
| `ledger_shard_2` | `MODULUS 4, REMAINDER 2` | 103,340 | **25.08%** |
| `ledger_shard_3` | `MODULUS 4, REMAINDER 3` | 99,946 | **24.25%** |
| **Total Partitioned Rows** | | **412,058** | **100.00%** |
| **Original Table Rows** | | **412,058** | **Exact 1:1 Parity** |

The hash distribution achieved near-perfect uniformity ($\approx 25.0\% \pm 0.6\%$), proving that PostgreSQL's internal MurmurHash-based hash partitioner prevents data skew across account IDs.

---

### 5.2 Query Plan Execution Analysis

#### 1. Partition Pruning (Keyed Query):
```sql
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded 
WHERE account_id = 1001 
ORDER BY created_at DESC LIMIT 10;
```
**Execution Plan Output:**
```
Limit
  -> Sort
        Sort Key: ledger_entries_sharded.created_at DESC
        -> Bitmap Heap Scan on ledger_shard_0 ledger_entries_sharded
              Recheck Cond: (account_id = 1001)
              -> Bitmap Index Scan on ledger_shard_0_pkey
                    Index Cond: (account_id = 1001)
```
- **Engine Mechanics:** The query planner evaluates the constant `account_id = 1001`, computes its hash value, and statically eliminates Shards 1, 2, and 3 during plan compilation. The query scans **only 1 out of 4 physical tables**, achieving a **75% reduction in disk block inspection** and eliminating lock contention on unrelated shards.

#### 2. Scatter-Gather Scan (Non-Keyed Query):
```sql
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded 
WHERE transaction_id = 12345;
```
**Execution Plan Output:**
```
Gather
  Workers Planned: 2
  -> Parallel Append
        -> Parallel Seq Scan on ledger_shard_0
              Filter: (transaction_id = 12345)
        -> Parallel Seq Scan on ledger_shard_1
              Filter: (transaction_id = 12345)
        -> Parallel Seq Scan on ledger_shard_2
              Filter: (transaction_id = 12345)
        -> Parallel Seq Scan on ledger_shard_3
              Filter: (transaction_id = 12345)
```
- **Engine Mechanics:** Because `transaction_id` is not the partition key, the query planner cannot deduce which partition holds the record. It is forced to initiate a **Scatter-Gather** operation: the query coordinates two background worker threads executing a `Parallel Append` that sequentially scans all 4 physical tables. 

---

### 5.3 Distributed Sharding Architecture for NairaPay

While declarative partitioning operates on a single PostgreSQL server, running NairaPay across multiple independent physical database instances introduces distinct architectural requirements:

```mermaid
flowchart TD
    subgraph Sharded Architecture
        ClientApp["NairaPay Transfer Service"] --> ShardRouter["Shard Coordinator / Citus / Saga Orchestrator"]
        
        ShardRouter -->|"Hash(1001) -> Shard A"| ShardA[("Shard A (PostgreSQL)<br/>Wallets 0..2499")]
        ShardRouter -->|"Hash(3500) -> Shard B"| ShardB[("Shard B (PostgreSQL)<br/>Wallets 2500..4999")]
    end
```

1. **Shard Key Selection:** Selecting `account_id` as the primary shard key ensures that all ledger lines, balance caches, and statement records for a single wallet co-locate on the same physical server. An account statement query remains a purely local, single-shard operation.
2. **Cross-Shard P2P Transfers:** A transfer moving funds from Alice on Shard A to Bob on Shard B cannot use local ACID transactions. It requires:
   - **Two-Phase Commit (2PC):** Supported natively by PostgreSQL Foreign Data Wrappers (`postgres_fdw`) or the Citus extension. However, 2PC introduces heavy blocking coordinator overhead.
   - **Saga Orchestration Pattern:** Preferred in enterprise fintech. An asynchronous orchestrator reserves funds on Shard A (`PENDING_DEBIT`), emits an event to Kafka, and asynchronously credits Shard B (`CREDIT`). If Shard B fails, a compensating transaction unfreezes funds on Shard A.
3. **Hot Shards Mitigation:** High-volume merchant accounts (e.g., Jumia or Uber collections) receive millions of transfers, threatening to overwhelm a single physical shard. To resolve this, merchant accounts must utilize **virtual sharding / balance slotting**, dividing the merchant's balance across 16 sub-accounts distributed across all shards, aggregated nightly.
4. **PostgreSQL vs. MongoDB Sharding:** In PostgreSQL, multi-node sharding requires extensions (Citus) or application-level routing. In contrast, MongoDB provides native sharding out of the box: client drivers connect to lightweight `mongos` routing routers, which consult a dedicated `configdb` cluster and automatically balance 64 MB chunks across shard replica sets with zero application-level routing code.

---

## 6. High-Availability Failover & Disaster Recovery

When a primary database crashes, maintaining platform continuity requires promoting a read replica to master status.

```mermaid
stateDiagram-v2
    [*] --> StandbyRecovery : Booted with standby.signal
    StandbyRecovery --> Promoting : pg_ctl promote / Signal
    Promoting --> ReadWriteMaster : Replay final WAL, increment timeline, open R/W
    ReadWriteMaster --> ActiveMaster : Serving Client Writes
    ActiveMaster --> SplitBrainHazard : Old Primary Restarts (Divergence!)
    ActiveMaster --> [*]
```

### 6.1 The Manual Promotion Mechanism
In Experiment 7, primary failure was simulated by terminating the primary container:
```bash
docker stop nairapay-pg-primary
```
The replica was promoted inside the container:
```bash
docker exec -it nairapay-pg-replica gosu postgres pg_ctl promote -D /var/lib/postgresql/data
```
- **Engine Recovery Trace:** The standby stopped its redo loop, replayed the final pending WAL records, wrote an **End-of-Recovery Record**, incremented its internal **Timeline ID** (from Timeline 1 to Timeline 2), deleted `standby.signal`, and opened its storage engine for read-write transactions.
- Running `SELECT pg_is_in_recovery();` transitioned from `t` to `f`.
- *Visual Evidence:* [`screenshots/10_failover.png`](screenshots/10_failover.png).

---

### 6.2 Failure Hazards in Failover Engineering

#### 1. The Sequence Jump Phenomenon:
PostgreSQL sequence generators (`BIGSERIAL`, `IDENTITY`) allocate ID blocks in memory (default 32 values) to prevent WAL contention on high-frequency inserts. During an abrupt ungraceful crash and failover:
- Any sequence numbers cached in the failed primary's memory that were not written to disk are permanently lost.
- Upon promotion, the new primary resumes sequences from the next checkpoint block.
- **Impact:** `transaction_id` and `entry_id` values exhibit non-contiguous numerical gaps (e.g., jumping from `206150` to `206200`). This is fully compliant with financial audit standards; true continuity is audited via cryptographic hashes and timestamps rather than contiguous sequence integers.

#### 2. The Split-Brain Disaster:
- **Scenario:** The primary was partitioned from the replica due to a switch failure, but remained reachable by a subset of client API servers.
- **The Failure:** If the replica is promoted while the original primary is still running, **two independent nodes accept writes simultaneously**.
- **Consequence:** Both nodes issue conflicting updates to the same account balances. Their physical WAL histories diverge into conflicting timelines. Re-merging them requires manual, record-by-record forensic reconciliation.
- **Remediation via Fencing (STONITH):** High-availability clusters enforce **STONITH ("Shoot The Other Node In The Head")**. Before a replica is permitted to promote, hardware fencing devices (IPMI, network PDU power cutters, or cloud IAM revocation) physically power off or isolate the old primary server.

#### 3. RPO and RTO Quantification:

| Disaster Recovery Metric | NairaPay Manual Setup | Enterprise Production Standard (Patroni) |
|---|---|---|
| **Recovery Point Objective (RPO)** | **$\approx 0$ to 50 ms** (bounded by async replication lag). | **0 seconds** (Quorum synchronous replication across 2 AZs). |
| **Recovery Time Objective (RTO)** | **Several Minutes** (Manual engineer alerting, container execution, connection reconfiguration). | **< 10 seconds** (Automated Raft consensus, etcd heartbeat failure detection, VIP/DNS repointing). |

---

## 7. Cloud Persistence Architecture: MongoDB Atlas

To evaluate cloud-native managed database persistence, NairaPay deployed a 3-node replica set on **MongoDB Atlas**.

```mermaid
flowchart TD
    subgraph Client Driver
        AppClient["NairaPay Microservice"]
    end

    subgraph MongoDB Atlas Cloud Architecture (AWS / GCP)
        PrimaryNode["Primary Node (AWS AZ-1)<br/>• Accepts all writes<br/>• Writes to local oplog"]
        Secondary1["Secondary Node 1 (AWS AZ-2)<br/>• Replicates oplog<br/>• Serves readPref('secondary')"]
        Secondary2["Secondary Node 2 (AWS AZ-3)<br/>• Replicates oplog<br/>• Voting Member"]

        PrimaryNode <-->|"Heartbeat & Consensus"| Secondary1
        PrimaryNode <-->|"Heartbeat & Consensus"| Secondary2
        Secondary1 <-->|"Heartbeat"| Secondary2
    end

    AppClient -->|"Write: w: 'majority', wtimeout: 5000"| PrimaryNode
    PrimaryNode -.->|"Async Oplog Replication"| Secondary1
    PrimaryNode -.->|"Async Oplog Replication"| Secondary2
    Secondary1 -.->|"Acknowledge Flush"| PrimaryNode
    PrimaryNode -->|"Acknowledge Write (184 ms)"| AppClient
    AppClient -->|"Read: readPref('secondary')"| Secondary1
```

### 7.1 Distributed Topology & Verification Telemetry
Executing `04_atlas_cloud_check.js` against the live cloud cluster validated topology and operational guarantees:

*Verified Cloud Telemetry:*
```
=== 1. Topology: what did I connect to?
replica set name : atlas-14a5b-shard-0
members          : ac-xxx-shard-00-00.mongodb.net:27017, ac-xxx-shard-00-01.mongodb.net:27017, ac-xxx-shard-00-02.mongodb.net:27017
primary          : ac-xxx-shard-00-01.mongodb.net:27017
served by        : ac-xxx-shard-00-01.mongodb.net:27017  (this is the PRIMARY)

=== 2. Write concern: wait until a MAJORITY of nodes have the write
acknowledged     : true (took 184 ms)

=== 3. Read preference: read from a SECONDARY instead of the primary
this read was served by : ac-xxx-shard-00-00.mongodb.net  (a SECONDARY)
kyc_profiles visible on that node : 5000

=== 4. Read concern: only return data that is acknowledged by a majority
majority read returned 1 document(s)
Cleaned up the p5_marker collection.
```
*Visual Evidence:* [`screenshots/11_atlas_cluster.png`](screenshots/11_atlas_cluster.png) and [`screenshots/12_atlas_check_output.png`](screenshots/12_atlas_check_output.png).

---

### 7.2 Cloud Consistency & Durability Guarantees

#### 1. Write Concern `w: majority`:
- **Mechanism:** The driver blocks until the write has committed to the Write-Ahead Oplog of at least **2 out of 3 replica set members**.
- **Latency Analysis:** The write completed in **184 ms**, reflecting international public Internet round-trip latency (Nigeria/macOS host to AWS/GCP cloud region) plus cross-AZ inter-node replication handshakes.
- **Durability Guarantee:** If the primary node experiences sudden power failure, one of the two secondaries that acknowledged the write is guaranteed to possess the update, ensuring **zero data rollback during automated leader election**.

#### 2. Read Preference Routing (`readPref('secondary')`):
- Non-critical read queries (such as compliance officers reviewing KYC documents or browsing audit event histories) are routed directly to secondary nodes.
- **Impact:** Eliminates read competition on the primary node, preserving 100% of the primary's memory and CPU resources for write ingestion.

#### 3. Read Concern `majority`:
- Guarantees that the query reads data that has already been acknowledged by a majority of nodes. This prevents client applications from observing "dirty writes" that could be rolled back if the primary were partitioned before replicating the write.

---

## 8. Production Hardening Blueprint for NairaPay

To transition the prototype evaluated in Portfolio 5 into a tier-1 banking-grade platform, the following enterprise infrastructure blueprint is recommended:

```mermaid
flowchart TD
    subgraph Multi-AZ Cloud VPC (AWS eu-west-1)
        subgraph Availability Zone A
            Pri["PostgreSQL Primary (Active Master)"]
            PoolA["PgBouncer Pooler (Transaction Mode)"]
            ConsulA["etcd / Consul Node 1"]
        end

        subgraph Availability Zone B
            Standby1["PostgreSQL Standby 1 (Sync Quorum)"]
            PoolB["PgBouncer Pooler (Read-Only)"]
            ConsulB["etcd / Consul Node 2"]
        end

        subgraph Availability Zone C
            Standby2["PostgreSQL Standby 2 (Sync Quorum)"]
            ConsulC["etcd / Consul Node 3"]
        end

        Patroni["Patroni HA Supervisor Engine"]
        Backup["pgBackRest Continuous WAL Archive -> S3"]
    end

    PoolA --> Pri
    PoolB --> Standby1
    Pri -->|"Quorum Sync WAL"| Standby1
    Pri -->|"Quorum Sync WAL"| Standby2
    Patroni --> ConsulA
    Patroni --> ConsulB
    Patroni --> ConsulC
    Pri --> Backup
```

### Key Architectural Recommendations:
1. **Automated HA via Patroni & etcd:** Replace manual `pg_ctl promote` with **Patroni**. Patroni runs as a sidecar supervisor on every database node, maintaining dynamic leader locks in an **etcd** Raft consensus cluster. If the primary misses heartbeats for 10 seconds, Patroni automatically fences the failed primary and elects the standby with the most advanced LSN, achieving an **RTO < 10 seconds with zero split-brain risk**.
2. **Quorum Synchronous Standby Configuration:**
   ```ini
   synchronous_commit = 'on'
   synchronous_standby_names = 'ANY 1 (standby_az_b, standby_az_c)'
   ```
   Ensures **RPO = 0** while maintaining 100% write availability if any single standby node goes down for maintenance.
3. **Continuous WAL Archiving & Point-In-Time Recovery (PITR):** Deploy **`pgBackRest`** streaming continuous WAL segments to encrypted Amazon S3 buckets. This enables restoration to any arbitrary second within the past 30 days, protecting against catastrophic operational errors or ransomware.
4. **Mutual TLS (mTLS) Wire Encryption:** Enable SSL encryption (`ssl = on`, `ssl_ca_file`, `ssl_cert_file`) for all inter-node streaming replication and client connections, ensuring PCI-DSS and NDPA compliance.
5. **Connection Pooling Architecture:** Deploy **PgBouncer** in `pool_mode = transaction` colocated on client application hosts, multiplexing 10,000 mobile client connections into a controlled pool of 50 backend connections per database node.

---

## 9. Academic Reflection & Conclusion

### 9.1 Reflection on Distributed Database Engineering
The transition from single-node database tuning to distributed systems fundamentally challenges intuitive assumptions about data persistence. On a single server, issuing `COMMIT` provides an absolute guarantee that data is permanently secured. In a distributed network, a committed transaction is only as durable as the consensus protocol governing the nodes.

The empirical experiments in Portfolio 5 provided powerful practical lessons:
1. **The CAP Trade-off is Real and Visceral:** Witnessing the primary database freeze during the synchronous replication test demonstrated that absolute consistency comes at the direct cost of write availability.
2. **Replication Lag is a Business Hazard:** Observing the stale read window on the paused replica made it clear that read replicas cannot be treated as transparent drop-in read caches for balance-sensitive operations without introducing double-spending risks.
3. **Partitioning Solves Scale, but Introduces Coordination Costs:** Hash partitioning proved extraordinarily effective at pruning scans for single-wallet lookups. However, analyzing cross-shard transfers illuminated the complex engineering required to maintain double-entry financial invariants without single-node ACID transactions.

### 9.2 Conclusion
Portfolio 5 successfully delivers an enterprise-grade, distributed, high-availability architecture for NairaPay. By combining PostgreSQL physical streaming replication, declarative hash partitioning, automated failover planning, and MongoDB Atlas cloud durability, the platform achieves the optimal balance between strict relational financial integrity and cloud-scale availability.

---

## 10. References and Academic Literature

1. **Brewer, E. A. (2000).** *Towards Robust Distributed Systems.* Proceedings of the 19th ACM Symposium on Principles of Distributed Computing (PODC).
2. **Gilbert, S., & Lynch, N. (2002).** *Brewer's Conjecture and the Feasibility of Consistent, Available, Partition-Tolerant Web Services.* ACM SIGACT News, 33(2), pp. 51–59.
3. **Abadi, D. J. (2012).** *Consistency Tradeoffs in Modern Distributed Database System Design: CAP is Only Part of the Story.* Computer, 45(2), pp. 37–42.
4. **Ongaro, D., & Ousterhout, J. (2014).** *In Search of an Understandable Consensus Algorithm.* Proceedings of the 2014 USENIX Annual Technical Conference (USENIX ATC 14), pp. 305–319.
5. **Gray, J., & Reuter, A. (1993).** *Transaction Processing: Concepts and Techniques.* Morgan Kaufmann Publishers.
6. **PostgreSQL Global Development Group (2024).** *PostgreSQL 16.14 Documentation: Chapter 27 – High Availability, Load Balancing, and Replication.*
7. **MongoDB Inc. (2024).** *MongoDB Atlas Architecture Guide: High Availability and Disaster Recovery.* Available at: https://www.mongodb.com/docs/atlas/

