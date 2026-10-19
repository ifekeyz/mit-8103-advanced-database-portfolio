// =====================================================================
// Portfolio 4 - Step 2: seed MongoDB for the same 5,000 NairaPay customers
// that exist in PostgreSQL (customer_id 1..5000 in Portfolio 2's seed;
// the settlement customer is not included).
//   mongosh "$MONGODB_URI" --file portfolio-4-nosql/02_seed_data.js
//
// Creates 5,000 KYC profiles and 100,000 audit events.
// Re-runnable: it empties the collections first. Takes about 30-90 s on
// the free tier (network round trips).
// =====================================================================

const nosql = db.getSiblingDB('nairapay_nosql');
const CUSTOMERS = 5000;
const EVENTS = 100000;
const BATCH = 5000;

// Small deterministic random generator, so every student gets the same
// shape of data (same idea as setseed() in the PostgreSQL seed).
let seedState = 42;
function rnd() {
    seedState = (seedState * 1664525 + 1013904223) % 4294967296;
    return seedState / 4294967296;
}
function randInt(lo, hi) { return lo + Math.floor(rnd() * (hi - lo + 1)); }
function pick(arr) { return arr[Math.floor(rnd() * arr.length)]; }
function digits(n) {
    let s = '';
    for (let i = 0; i < n; i++) s += String(Math.floor(rnd() * 10));
    return s;
}

const NOW = Date.now();
const DAY = 24 * 60 * 60 * 1000;
const CITIES = ['Lagos', 'Abuja', 'Port Harcourt', 'Ibadan', 'Kano', 'Enugu', 'Benin City'];
const STATES = ['Lagos', 'FCT', 'Rivers', 'Oyo', 'Kano', 'Enugu', 'Edo'];
const DEVICES = ['Android', 'iPhone', 'Web'];
const DISCOS = ['Ikeja Electric', 'Eko Disco', 'AEDC', 'PHED'];

nosql.kyc_profiles.deleteMany({});
nosql.audit_events.deleteMany({});

// ---------------------------------------------------------------------
// KYC profiles. The tier decides how many documents exist, and each
// document type has its own fields.
// ---------------------------------------------------------------------
function makeDocument(type) {
    switch (type) {
        case 'BVN':
            return { type: 'BVN', number: digits(11), verified_with: 'NIBSS' };
        case 'NIN':
            return { type: 'NIN', number: digits(11), verified_with: 'NIMC' };
        case 'PASSPORT':
            return {
                type: 'PASSPORT', number: 'A' + digits(8), country: 'NG',
                expiry: new Date(NOW + randInt(200, 3000) * DAY)
            };
        case 'DRIVERS_LICENCE':
            return {
                type: 'DRIVERS_LICENCE', number: 'ABC' + digits(8) + 'XY',
                state_of_issue: pick(STATES), expiry: new Date(NOW + randInt(100, 1500) * DAY)
            };
        default:
            return {
                type: 'UTILITY_BILL', number: 'UB' + digits(8),
                provider: pick(DISCOS), issued_on: new Date(NOW - randInt(5, 80) * DAY)
            };
    }
}

let profiles = [];
for (let id = 1; id <= CUSTOMERS; id++) {
    const r = rnd();
    const tier = r < 0.55 ? 1 : (r < 0.88 ? 2 : 3);
    const docs = [makeDocument('BVN')];
    if (tier >= 2) docs.push(makeDocument(pick(['NIN', 'DRIVERS_LICENCE'])));
    if (tier >= 3) {
        docs.push(makeDocument(pick(['PASSPORT', 'DRIVERS_LICENCE'])));
        docs.push(makeDocument('UTILITY_BILL'));
    }
    const profile = {
        customer_id: id,
        tier: tier,
        status: rnd() < 0.93 ? 'VERIFIED' : (rnd() < 0.5 ? 'PENDING' : 'REJECTED'),
        documents: docs,
        created_at: new Date(NOW - randInt(30, 700) * DAY)
    };
    // Optional fields: only SOME documents have them. A SQL table would
    // need a mostly-NULL column; here the field simply does not exist.
    if (tier === 3) profile.risk_notes = 'Enhanced due diligence completed';
    if (rnd() < 0.2) profile.devices = [{ platform: pick(DEVICES), first_seen: new Date(NOW - randInt(1, 400) * DAY) }];
    profiles.push(profile);
}
nosql.kyc_profiles.insertMany(profiles);
profiles = null;
print('kyc_profiles inserted: ' + nosql.kyc_profiles.countDocuments({}));

// ---------------------------------------------------------------------
// Audit events over the last 90 days. `details` differs per event type.
// ---------------------------------------------------------------------
function makeEvent() {
    const customer_id = randInt(1, CUSTOMERS);
    const ts = new Date(NOW - Math.floor(rnd() * 90 * DAY));
    const r = rnd();
    let event_type, details;
    if (r < 0.40) {
        event_type = 'LOGIN_SUCCESS';
        details = {
            ip: '102.89.' + randInt(0, 255) + '.' + randInt(1, 254),
            device: pick(DEVICES), city: pick(CITIES)
        };
    } else if (r < 0.55) {
        event_type = 'LOGIN_FAILED';
        details = {
            ip: '41.58.' + randInt(0, 255) + '.' + randInt(1, 254),
            reason: pick(['WRONG_PIN', 'WRONG_PIN', 'DEVICE_NOT_RECOGNISED', 'ACCOUNT_LOCKED'])
        };
    } else if (r < 0.60) {
        event_type = 'PIN_CHANGED';
        details = { channel: pick(['APP', 'USSD']) };
    } else if (r < 0.90) {
        event_type = 'TRANSFER_INITIATED';
        details = {
            reference: 'ref-' + digits(10),
            amount: NumberDecimal((randInt(500, 500000) / 100).toFixed(2)),
            channel: pick(['APP', 'USSD', 'WEB'])
        };
    } else if (r < 0.95) {
        event_type = 'KYC_UPGRADED';
        const from = randInt(1, 2);
        details = { from_tier: from, to_tier: from + 1 };
    } else {
        event_type = 'FRAUD_FLAG';
        details = {
            rule: pick(['VELOCITY', 'NEW_DEVICE_LARGE_AMOUNT', 'MANY_FAILED_LOGINS']),
            score: randInt(40, 99)
        };
    }
    return { customer_id: customer_id, event_type: event_type, ts: ts, details: details };
}

for (let done = 0; done < EVENTS; done += BATCH) {
    const batch = [];
    for (let i = 0; i < BATCH; i++) batch.push(makeEvent());
    nosql.audit_events.insertMany(batch, { ordered: false });
    print('audit_events inserted so far: ' + (done + BATCH));
}

// ---------------------------------------------------------------------
// Verification
// ---------------------------------------------------------------------
print('');
print('=== Verification ===');
print('kyc_profiles : ' + nosql.kyc_profiles.countDocuments({}) + '  (expected ' + CUSTOMERS + ')');
print('audit_events : ' + nosql.audit_events.countDocuments({}) + '  (expected ' + EVENTS + ')');
print('Events by type:');
nosql.audit_events.aggregate([
    { $group: { _id: '$event_type', n: { $sum: 1 } } },
    { $sort: { n: -1 } }
]).forEach(function (d) { print('  ' + d._id + ': ' + d.n); });
print('Sample KYC profile (tier 3):');
printjson(nosql.kyc_profiles.findOne({ tier: 3 }));