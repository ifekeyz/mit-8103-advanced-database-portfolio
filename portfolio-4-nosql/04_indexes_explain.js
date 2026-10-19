// =====================================================================
// Portfolio 4 - Step 4: indexes, explain() and a TTL index.
//   mkdir -p portfolio-4-nosql/output
//   mongosh "$MONGODB_URI" --file portfolio-4-nosql/04_indexes_explain.js \
//     | tee portfolio-4-nosql/output/04_indexes_explain.txt
//
// Same idea as Portfolio 2: measure BEFORE the index, create it, measure AFTER.
// Requires steps 1 and 2. Re-runnable.
// =====================================================================

const nosql = db.getSiblingDB('nairapay_nosql');

// Walk an explain plan and list every stage name, e.g. [ 'LIMIT', 'FETCH', 'IXSCAN' ].
function stageNames(plan) {
    const names = [];
    (function walk(node) {
        if (!node) return;
        if (node.stage) names.push(node.stage);
        if (node.inputStage) walk(node.inputStage);
        if (node.inputStages) node.inputStages.forEach(walk);
        if (node.queryPlan) walk(node.queryPlan);
    })(plan.queryPlanner.winningPlan);
    return names;
}

function report(label, cursor) {
    const ex = cursor.explain('executionStats');
    const s = ex.executionStats;
    print('  [' + label + ']');
    print('    plan stages        : ' + stageNames(ex).join(' > '));
    print('    documents examined : ' + s.totalDocsExamined);
    print('    index keys examined: ' + s.totalKeysExamined);
    print('    documents returned : ' + s.nReturned);
    print('    execution time (ms): ' + s.executionTimeMillis);
}

// Start from a clean slate: drop every index except the default _id one.
nosql.audit_events.dropIndexes();
nosql.kyc_profiles.dropIndexes();

// The three queries we care about.
const q1 = function () { return nosql.audit_events.find({ customer_id: 1001 }).sort({ ts: -1 }).limit(20); };
const q2 = function () { return nosql.audit_events.find({ event_type: 'FRAUD_FLAG', ts: { $gte: new Date(Date.now() - 7 * 86400000) } }); };
const q3 = function () { return nosql.kyc_profiles.find({ customer_id: 2500 }); };

print('############ BEFORE indexes ############');
print('Q1: latest 20 events for customer 1001'); report('before', q1());
print('Q2: FRAUD_FLAG events in the last 7 days'); report('before', q2());
print('Q3: KYC profile for customer 2500'); report('before', q3());

// ---------------------------------------------------------------------
// Create indexes
// ---------------------------------------------------------------------
print('\n############ Creating indexes ############');
// Q1: equality on customer_id, then newest-first on ts. One compound index serves
// both the filter and the sort (no in-memory sort needed).
print(nosql.audit_events.createIndex({ customer_id: 1, ts: -1 }, { name: 'idx_audit_customer_ts' }));
// Q2: equality on event_type, then a range on ts.
print(nosql.audit_events.createIndex({ event_type: 1, ts: -1 }, { name: 'idx_audit_type_ts' }));
// Q3: exactly one KYC profile per customer, so the index is UNIQUE. This is the
// closest MongoDB gets to a relational PRIMARY KEY / UNIQUE constraint.
print(nosql.kyc_profiles.createIndex({ customer_id: 1 }, { unique: true, name: 'uq_kyc_customer' }));

print('\n############ AFTER indexes ############');
print('Q1: latest 20 events for customer 1001'); report('after', q1());
print('Q2: FRAUD_FLAG events in the last 7 days'); report('after', q2());
print('Q3: KYC profile for customer 2500'); report('after', q3());

// ---------------------------------------------------------------------
// The unique index also protects us: a second profile for the same customer fails.
// ---------------------------------------------------------------------
print('\n############ Unique index in action ############');
try {
    nosql.kyc_profiles.insertOne({
        customer_id: 1, tier: 1, status: 'PENDING',
        documents: [{ type: 'BVN', number: '11111111111' }], created_at: new Date()
    });
    print('FAIL: duplicate profile accepted');
} catch (e) {
    print('PASS: duplicate customer_id rejected -> ' + 'code ' + e.code);
}

// ---------------------------------------------------------------------
// TTL index: documents delete themselves. Right for sessions, WRONG for the
// audit log (audit records must be kept), which is why only login_sessions has it.
// ---------------------------------------------------------------------
print('\n############ TTL index on login_sessions ############');
nosql.login_sessions.deleteMany({});
nosql.login_sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600, name: 'ttl_session_1h' });
nosql.login_sessions.insertMany([
    { customer_id: 1001, token: 'tok-recent', created_at: new Date() },
    { customer_id: 1002, token: 'tok-old', created_at: new Date(Date.now() - 2 * 3600 * 1000) }
]);
print('Inserted 2 sessions, one already older than the 1 hour limit.');
print('MongoDB checks TTL indexes about once a minute, so the old one disappears shortly.');
print('Run this to see it: mongosh "$MONGODB_URI" --eval "db.getSiblingDB(\'nairapay_nosql\').login_sessions.find()"');

print('\n############ Index sizes ############');
['audit_events', 'kyc_profiles'].forEach(function (c) {
    try {
        const st = nosql.getCollection(c).stats();
        print(c + ': data=' + (st.size / 1048576).toFixed(1) + ' MB, indexes=' + (st.totalIndexSize / 1048576).toFixed(1) + ' MB');
    } catch (e) {
        print(c + ': stats not available here (' + e.message + '). Use Atlas > Collections > Indexes tab instead.');
    }
});