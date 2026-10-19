// =====================================================================
// Portfolio 4 - Step 1: create the collections with schema validation.
//   mongosh "$MONGODB_URI" --file portfolio-4-nosql/01_schema_validation.js
//
// MongoDB is "schema-flexible", not "schema-less": we still enforce the
// fields that MUST exist, and leave the rest of each document free to vary.
// Safe to re-run: it drops and recreates the three collections.
// =====================================================================

const nosql = db.getSiblingDB('nairapay_nosql');

['kyc_profiles', 'audit_events', 'login_sessions'].forEach(function (name) {
    nosql.getCollection(name).drop();
});

// ---------------------------------------------------------------------
// kyc_profiles: one document per customer. The `documents` array holds
// identity documents, and each document type has DIFFERENT fields
// (a passport has an expiry date, a BVN does not). That variety is the
// reason this data does not fit neatly into one SQL table.
// customer_id points at customers.customer_id in PostgreSQL.
// ---------------------------------------------------------------------
nosql.createCollection('kyc_profiles', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'tier', 'status', 'documents', 'created_at'],
            properties: {
                customer_id: {
                    bsonType: 'number', minimum: 1,
                    description: 'must match customers.customer_id in PostgreSQL'
                },
                tier: { bsonType: 'number', minimum: 1, maximum: 3 },
                status: { enum: ['PENDING', 'VERIFIED', 'REJECTED'] },
                documents: {
                    bsonType: 'array',
                    minItems: 1,
                    items: {
                        bsonType: 'object',
                        required: ['type', 'number'],
                        properties: {
                            type: { enum: ['BVN', 'NIN', 'PASSPORT', 'DRIVERS_LICENCE', 'UTILITY_BILL'] },
                            number: { bsonType: 'string' }
                        }
                    }
                },
                created_at: { bsonType: 'date' }
            }
        }
    },
    validationAction: 'error'
});

// ---------------------------------------------------------------------
// audit_events: an append-only log of what happened. Different event
// types carry different `details`, and new event types can be added
// without altering a table.
// ---------------------------------------------------------------------
nosql.createCollection('audit_events', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'event_type', 'ts', 'details'],
            properties: {
                customer_id: { bsonType: 'number', minimum: 1 },
                event_type: {
                    enum: ['LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGED',
                        'TRANSFER_INITIATED', 'KYC_UPGRADED', 'FRAUD_FLAG']
                },
                ts: { bsonType: 'date' },
                details: { bsonType: 'object' }
            }
        }
    },
    validationAction: 'error'
});

// ---------------------------------------------------------------------
// login_sessions: short-lived data. A TTL index deletes each document
// automatically one hour after created_at. (Created in step 4's demo.)
// ---------------------------------------------------------------------
nosql.createCollection('login_sessions');

print('Collections now in nairapay_nosql:');
nosql.getCollectionNames().forEach(function (n) { print('  - ' + n); });

// ---------------------------------------------------------------------
// Prove the validator works: this insert is missing required fields and
// has an invalid status, so MongoDB must reject it.
// ---------------------------------------------------------------------
try {
    nosql.kyc_profiles.insertOne({ customer_id: 1, status: 'MAYBE' });
    print('FAIL: the invalid document was accepted');
} catch (e) {
    print('PASS: invalid KYC document rejected -> ' + e.codeName + ' (code ' + e.code + ')');
}