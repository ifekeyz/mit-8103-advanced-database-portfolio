// =====================================================================
// Portfolio 4 - Step 3: CRUD operations and aggregation pipelines.
//   mongosh "$MONGODB_URI" --file portfolio-4-nosql/03_crud_and_aggregation.js \
//     | tee portfolio-4-nosql/output/03_crud_and_aggregation.txt
//
// Requires steps 1 and 2. Re-runnable (it cleans up its own test customer).
// =====================================================================

const nosql = db.getSiblingDB('nairapay_nosql');
const TEST_ID = 999999;   // a customer that exists only for this demo
nosql.kyc_profiles.deleteMany({ customer_id: TEST_ID });

print('############ CRUD ############');

// ---- CREATE -----------------------------------------------------------
print('\n--- CREATE: onboard a new customer with a passport (nested fields)');
nosql.kyc_profiles.insertOne({
    customer_id: TEST_ID,
    tier: 2,
    status: 'PENDING',
    documents: [
        { type: 'BVN', number: '22212345678', verified_with: 'NIBSS' },
        { type: 'PASSPORT', number: 'A12345678', country: 'NG', expiry: new Date('2031-05-01') }
    ],
    created_at: new Date()
});
printjson(nosql.kyc_profiles.findOne({ customer_id: TEST_ID }, { _id: 0 }));

// ---- READ -------------------------------------------------------------
print('\n--- READ: tier 3 customers who hold a PASSPORT (query inside an array)');
print('count = ' + nosql.kyc_profiles.countDocuments({ tier: 3, 'documents.type': 'PASSPORT' }));

print('\n--- READ: passports expiring in the next 365 days (nested field filter)');
print('count = ' + nosql.kyc_profiles.countDocuments({
    documents: { $elemMatch: { type: 'PASSPORT', expiry: { $lt: new Date(Date.now() + 365 * 86400000) } } }
}));

print('\n--- READ: last 3 audit events for customer 1001 (newest first)');
nosql.audit_events.find({ customer_id: 1001 }, { _id: 0 }).sort({ ts: -1 }).limit(3)
    .forEach(function (d) { printjson(d); });

// ---- UPDATE -----------------------------------------------------------
print('\n--- UPDATE: verify the customer and upgrade to tier 3 ($set) and add a document ($push)');
nosql.kyc_profiles.updateOne(
    { customer_id: TEST_ID },
    {
        $set: { status: 'VERIFIED', tier: 3 },
        $push: { documents: { type: 'UTILITY_BILL', number: 'UB99999999', provider: 'Eko Disco', issued_on: new Date() } }
    }
);
const updated = nosql.kyc_profiles.findOne({ customer_id: TEST_ID });
print('status=' + updated.status + ', tier=' + updated.tier + ', documents=' + updated.documents.length);

print('\n--- UPDATE: record the change in the audit log (append-only: we insert, never edit)');
nosql.audit_events.insertOne({
    customer_id: TEST_ID, event_type: 'KYC_UPGRADED', ts: new Date(),
    details: { from_tier: 2, to_tier: 3 }
});

// ---- DELETE -----------------------------------------------------------
print('\n--- DELETE: remove the demo customer profile');
const del = nosql.kyc_profiles.deleteOne({ customer_id: TEST_ID });
print('deleted = ' + del.deletedCount);
nosql.audit_events.deleteMany({ customer_id: TEST_ID });   // clean up the demo event only

print('\n############ AGGREGATION ############');

// ---- 1. Events per type, last 30 days --------------------------------
print('\n--- Aggregation 1: events per type in the last 30 days');
nosql.audit_events.aggregate([
    { $match: { ts: { $gte: new Date(Date.now() - 30 * 86400000) } } },
    { $group: { _id: '$event_type', events: { $sum: 1 } } },
    { $sort: { events: -1 } }
]).forEach(function (d) { print('  ' + d._id + ': ' + d.events); });

// ---- 2. Daily transfer-initiated amounts ------------------------------
print('\n--- Aggregation 2: total TRANSFER_INITIATED amount per day (latest 5 days)');
nosql.audit_events.aggregate([
    { $match: { event_type: 'TRANSFER_INITIATED' } },
    {
        $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$ts' } },
            transfers: { $sum: 1 },
            total_amount: { $sum: '$details.amount' }
        }
    },
    { $sort: { _id: -1 } },
    { $limit: 5 }
]).forEach(function (d) {
    print('  ' + d._id + '  transfers=' + d.transfers + '  total=' + d.total_amount);
});

// ---- 3. $lookup: join audit events to KYC profile ---------------------
print('\n--- Aggregation 3: top 5 customers by failed logins, with their KYC tier ($lookup = a JOIN)');
nosql.audit_events.aggregate([
    { $match: { event_type: 'LOGIN_FAILED' } },
    { $group: { _id: '$customer_id', failed_logins: { $sum: 1 } } },
    { $sort: { failed_logins: -1, _id: 1 } },
    { $limit: 5 },
    { $lookup: { from: 'kyc_profiles', localField: '_id', foreignField: 'customer_id', as: 'kyc' } },
    { $unwind: '$kyc' },
    { $project: { _id: 0, customer_id: '$_id', failed_logins: 1, tier: '$kyc.tier', status: '$kyc.status' } }
]).forEach(function (d) { printjson(d); });

// ---- 4. Documents per tier -------------------------------------------
print('\n--- Aggregation 4: average number of documents per KYC tier ($size)');
nosql.kyc_profiles.aggregate([
    { $group: { _id: '$tier', customers: { $sum: 1 }, avg_documents: { $avg: { $size: '$documents' } } } },
    { $sort: { _id: 1 } }
]).forEach(function (d) { print('  tier ' + d._id + ': customers=' + d.customers + ', avg documents=' + d.avg_documents); });