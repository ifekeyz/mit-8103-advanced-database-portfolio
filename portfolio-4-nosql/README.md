# Portfolio 4: NoSQL and Advanced Data Models (MongoDB Atlas)

> Draft structure. Rewrite every section in your own words and fill in your own numbers and
> screenshots. You may be asked to explain any line of this.

## 1. What I stored in MongoDB, and why

NairaPay keeps money in PostgreSQL. MongoDB holds data whose shape varies or that grows fast
and is rarely updated.

| Data | Where | Why |
|---|---|---|
| Wallets, balances, transfers, ledger | PostgreSQL | Needs multi-row ACID transactions, foreign keys and exact `NUMERIC` arithmetic. A transfer must change two balances and write two ledger lines or none of them. |
| KYC profiles (`kyc_profiles`) | MongoDB | Each document type has different fields (passport expiry, BVN lookup source, utility bill provider). The profile is read and written as one unit. In SQL this needs many mostly-NULL columns or an EAV table. |
| Audit events (`audit_events`) | MongoDB | Append-only, high volume, and `details` differs per event type. New event types need no `ALTER TABLE`. |
| Login sessions (`login_sessions`) | MongoDB (TTL) | Short-lived. The TTL index removes expired sessions automatically. |

**Link between the two systems:** `customer_id` in MongoDB equals `customers.customer_id` in
PostgreSQL. There is no foreign key across databases, so the application must keep them
consistent. _(Write: what could go wrong, and one way to handle it.)_

## 2. Data model

_(Insert a screenshot of one `kyc_profiles` document and one `audit_events` document from Compass or the script output.)_

Embedding versus referencing:
- **Embedded:** `documents` live inside the KYC profile because they are always read with it and
  have no meaning alone.
- **Referenced:** audit events are separate documents that point to the customer by `customer_id`,
  because there are many per customer and they grow without limit (a document may not exceed 16 MB).

## 3. Schema validation

`01_schema_validation.js` uses `$jsonSchema` validators. The script proves that an invalid KYC
document is rejected (`DocumentValidationFailure`, code 121). _(Explain schema-flexible versus schema-less.)_

## 4. CRUD and aggregation

`03_crud_and_aggregation.js` shows create, read, update (`$set`, `$push`), delete, and four
aggregation pipelines including `$lookup` (the MongoDB equivalent of a JOIN).
_(Pick one pipeline and explain each stage in your own words. Compare it with the SQL you would write.)_

## 5. Indexing and performance

`04_indexes_explain.js` measures three queries before and after indexing.

| Query | Before: docs examined / ms | After: docs examined / ms | Index |
|---|---|---|---|
| Q1 latest 20 events for a customer | _fill in_ | _fill in_ | `{customer_id:1, ts:-1}` |
| Q2 FRAUD_FLAG events, last 7 days | _fill in_ | _fill in_ | `{event_type:1, ts:-1}` |
| Q3 KYC profile by customer | _fill in_ | _fill in_ | unique `{customer_id:1}` |

_(Explain COLLSCAN versus IXSCAN, and why the compound index also removes the sort. Note that the
index sizes are the cost you pay.)_

## 6. SQL versus MongoDB for NairaPay

_(Your own analysis, 150 to 250 words. Points to cover: ACID and multi-document transactions,
joins, schema flexibility, horizontal scaling, consistency model (BASE versus ACID), and why you
would NOT move the ledger to MongoDB.)_

## 7. Reproducing this

See `00_atlas_setup.md`. Run scripts `01` to `04` in order with `mongosh`.

## 8. Reflection

_(What was easier or harder than PostgreSQL? What would you change?)_

## AI use

_(Tool used, what for, and how you checked the result. Example: Claude generated the first
draft of the scripts; I ran each one on my own Atlas cluster and compared the output with the
expected results.)_