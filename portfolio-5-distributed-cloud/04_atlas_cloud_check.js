// Portfolio 5 - cloud evidence: MongoDB Atlas replica set.
// Run against your ATLAS cluster (not a local single-node MongoDB).
// Atlas free clusters are always a 3-node replica set (1 primary + 2 secondaries).

const nosql = db.getSiblingDB('nairapay_nosql');
const h = db.hello();

print('=== 1. Topology: what did I connect to?');
if (!h.setName) {
    print('This is a STANDALONE server (no replica set). Run this script against your Atlas URI.');
} else {
    print('replica set name : ' + h.setName);
    print('members          : ' + h.hosts.join(', '));
    print('primary          : ' + h.primary);
    print('served by        : ' + h.me + (h.isWritablePrimary ? '  (this is the PRIMARY)' : '  (this is a SECONDARY)'));
}

print('\n=== 2. Write concern: wait until a MAJORITY of nodes have the write');
const t0 = Date.now();
const res = nosql.getCollection('p5_marker').insertOne(
    { note: 'written with w:majority', at: new Date() },
    { writeConcern: { w: 'majority', wtimeout: 5000 } }
);
print('acknowledged     : ' + res.acknowledged + ' (took ' + (Date.now() - t0) + ' ms)');

print('\n=== 3. Read preference: read from a SECONDARY instead of the primary');
try {
    const ex = nosql.kyc_profiles.find({}, { _id: 1 }).readPref('secondary').explain('queryPlanner');
    const host = ex.serverInfo ? ex.serverInfo.host : 'unknown';
    print('this read was served by : ' + host + (host === String(h.primary).split(':')[0] ? '  (the PRIMARY)' : '  (a SECONDARY)'));
    print('kyc_profiles visible on that node : ' + nosql.kyc_profiles.find({}, { _id: 1 }).readPref('secondary').itcount());
} catch (e) {
    print('secondary read failed: ' + e.message);
}

print('\n=== 4. Read concern: only return data that is acknowledged by a majority');
const rc = nosql.getCollection('p5_marker').find({}).readConcern('majority').limit(1).toArray();
print('majority read returned ' + rc.length + ' document(s)');

nosql.getCollection('p5_marker').drop();
print('\nCleaned up the p5_marker collection.');