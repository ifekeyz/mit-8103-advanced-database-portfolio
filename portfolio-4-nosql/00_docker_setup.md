# Local MongoDB Setup Guide (Docker & MongoDB Compass)

This guide details how to spin up, connect to, and manage the local MongoDB 7 container for **Portfolio 4: NoSQL and Advanced Data Models**.

---

## 1. Prerequisites

Ensure the following tools are installed on your host machine:
- **Docker Desktop** (or Docker Engine with Compose V2)
- **mongosh** (MongoDB Shell CLI): `brew install mongosh`
- *(Optional)* **MongoDB Compass** (Official GUI Client)

---

## 2. Starting the Container

From the repository root (`MIT8103`), execute:

```bash
docker compose -f portfolio-4-nosql/docker-compose.yml up -d
```

### Verification
Check that the container `nairapay-mongo` is healthy and listening on port `27017`:

```bash
docker compose -f portfolio-4-nosql/docker-compose.yml ps
```

Expected output:
```
NAME             IMAGE     COMMAND                  SERVICE   CREATED         STATUS                   PORTS
nairapay-mongo   mongo:7   "docker-entrypoint.s…"   mongo     5 seconds ago   Up 4 seconds (healthy)   0.0.0.0:27017->27017/tcp
```

---

## 3. Connection Parameters

| Parameter | Value |
|---|---|
| **Host** | `localhost` (or `127.0.0.1`) |
| **Port** | `27017` |
| **Username** | `nairapay_user` |
| **Password** | `nairapay_pass` |
| **Authentication Database** | `admin` |
| **Target Database** | `nairapay_nosql` |

### Environment Variable Setup
Export the standard connection URI in your terminal:

```bash
export MONGODB_URI="mongodb://nairapay_user:nairapay_pass@localhost:27017/nairapay_nosql?authSource=admin"
```

---

## 4. Connecting via `mongosh` CLI

To launch an interactive session:

```bash
mongosh "$MONGODB_URI"
```

Run a quick status check inside the shell:
```javascript
db.runCommand({ ping: 1 });
// Output: { ok: 1 }
```

---

## 5. Connecting via MongoDB Compass GUI

1. Open **MongoDB Compass**.
2. In the connection string field, paste:
   ```
   mongodb://nairapay_user:nairapay_pass@localhost:27017/nairapay_nosql?authSource=admin
   ```
3. Click **Connect**.
4. You will see the database `nairapay_nosql` and its collections:
   - `kyc_profiles`
   - `audit_events`
   - `login_sessions`

---

## 6. Running Portfolio 4 Scripts

Execute the four scripts in sequential order from the repository root:

```bash
# 1. Initialize collections with $jsonSchema validation
mongosh "$MONGODB_URI" --file portfolio-4-nosql/01_schema_validation.js

# 2. Seed 5,000 KYC profiles and 100,000 audit events (~30-60s)
mongosh "$MONGODB_URI" --file portfolio-4-nosql/02_seed_data.js

# 3. Execute CRUD operations and aggregation pipelines
mongosh "$MONGODB_URI" --file portfolio-4-nosql/03_crud_and_aggregation.js | tee portfolio-4-nosql/output/03_crud_and_aggregation.txt

# 4. Create secondary indexes, benchmark query plans, and test TTL
mongosh "$MONGODB_URI" --file portfolio-4-nosql/04_indexes_explain.js | tee portfolio-4-nosql/output/04_indexes_explain.txt
```

---

## 7. Container Lifecycle Management

### Stop Container (Persists Data)
```bash
docker compose -f portfolio-4-nosql/docker-compose.yml down
```

### Reset / Wipe All Data
```bash
docker compose -f portfolio-4-nosql/docker-compose.yml down -v
```
*(The `-v` flag deletes the named volume `nairapay_mongo_data`, allowing a completely clean restart).*

