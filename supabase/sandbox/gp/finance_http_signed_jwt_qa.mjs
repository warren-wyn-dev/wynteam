#!/usr/bin/env node
// WYNOS Finance signed-JWT HTTP QA authorization checks.
// Run ONLY against https://pcatuxtenluqzjzzwsvl.supabase.co using existing
// legitimately authenticated QA users and their short-lived access tokens.
// No token/secret is logged, stored or committed. HTTP tests are read-only.
const projectRef = 'pcatuxtenluqzjzzwsvl';
const qaUrl = 'https://' + projectRef + '.supabase.co';
const required = [
  'WYNOS_QA_HTTP_ACK', 'WYNOS_QA_ANON_KEY',
  'WYNOS_QA_OWNER_JWT', 'WYNOS_QA_UNRELATED_JWT',
  'WYNOS_QA_OWNER_STORE_ID', 'WYNOS_QA_OTHER_STORE_ID'
];
for (const key of required) {
  if (!process.env[key]) {
    process.stderr.write('MISSING ' + key + ' (no requests sent)\n');
    process.exitCode = 2;
  }
}
if (process.exitCode) process.exit();
if (process.env.WYNOS_QA_HTTP_ACK !== projectRef
    || (process.env.WYNOS_QA_SUPABASE_URL && process.env.WYNOS_QA_SUPABASE_URL !== qaUrl)) {
  throw new Error('Refusing non-QA endpoint; no requests sent');
}
const ownerStore = process.env.WYNOS_QA_OWNER_STORE_ID;
const otherStore = process.env.WYNOS_QA_OTHER_STORE_ID;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!uuid.test(ownerStore) || !uuid.test(otherStore) || ownerStore === otherStore) {
  throw new Error('Store IDs must be distinct valid QA UUIDs; no requests sent');
}
const from = new Date(Date.now() - 86400000).toISOString();
const to = new Date(Date.now() + 86400000).toISOString();
const range = {p_from: from, p_to: to};
const keys = Object.freeze({
  owner: process.env.WYNOS_QA_OWNER_JWT,
  unrelated: process.env.WYNOS_QA_UNRELATED_JWT,
  admin: process.env.WYNOS_QA_APPROVED_ADMIN_JWT || null
});
let passed = 0, failed = 0, skipped = 0;
async function request(method, endpoint, role, body) {
  const auth = role === 'anon' ? null : keys[role];
  const headers = {
    apikey: process.env.WYNOS_QA_ANON_KEY,
    'content-type': 'application/json',
    'accept': 'application/json'
  };
  if (auth) headers.Authorization = 'Bearer ' + auth;
  const response = await fetch(qaUrl + endpoint, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error',
    signal: AbortSignal.timeout(12000)
  });
  const parsed = await response.json().catch(() => null);
  return {status: response.status, data: parsed};
}
function ensureReport(data, storeId = null) {
  if (!data || data.mode !== 'simulation_only'
      || data.merchant_net_payout_satang !== null
      || data.stripe_processing_fee_satang !== null
      || data.merchant_payout_status !== 'not_reconciled') return false;
  return storeId === null || (data.selected_store_id === storeId
    && Array.isArray(data.stores) && data.stores.every(s => s.store_id === storeId));
}
async function test(label, predicate, method, endpoint, role, body) {
  try {
    const res = await request(method, endpoint, role, body);
    if (!predicate(res)) throw new Error('Unexpected HTTP status/shape: ' + res.status);
    passed++;
    process.stdout.write('PASS ' + label + '\n');
  } catch (e) {
    failed++;
    process.stderr.write('FAIL ' + label + ': ' + e.message + '\n');
  }
}
const denied = r => [401,403].includes(r.status);
const valid = r => r.status === 200 && ensureReport(r.data,ownerStore);
const validEvents = r => r.status === 200 && r.data && r.data.mode === 'simulation_only'
  && Array.isArray(r.data.events) && r.data.events.every(x => x.store_id === ownerStore)
  && !/recipient_phone|shipping_address|stripe_payment_intent_id/.test(JSON.stringify(r.data.events));

await test('QA store owner can read own report',valid,'POST',
  '/rest/v1/rpc/merchant_food_finance_report_qa','owner',
  {p_store_id:ownerStore,...range});
await test('QA store owner can read own events',validEvents,'POST',
  '/rest/v1/rpc/merchant_food_finance_events_qa','owner',
  {p_store_id:ownerStore,...range,p_limit:20,p_offset:0});
await test('QA store owner cannot read a different store',denied,'POST',
  '/rest/v1/rpc/merchant_food_finance_report_qa','owner',
  {p_store_id:otherStore,...range});
await test('QA unrelated user cannot read owner store',denied,'POST',
  '/rest/v1/rpc/merchant_food_finance_report_qa','unrelated',
  {p_store_id:ownerStore,...range});
await test('QA unrelated user cannot read Admin report',denied,'POST',
  '/rest/v1/rpc/admin_food_finance_report_qa','unrelated',
  {...range,p_store_id:null});
await test('Anonymous request cannot read finance reporting',denied,'POST',
  '/rest/v1/rpc/merchant_food_finance_report_qa','anon',
  {p_store_id:ownerStore,...range});
await test('QA store owner cannot read raw finance projections',denied,'GET',
  '/rest/v1/food_finance_order_projections_qa?select=order_id&limit=1','owner');
await test('QA unrelated user cannot read raw refund adjustments',denied,'GET',
  '/rest/v1/food_finance_refund_adjustments_qa?select=id&limit=1','unrelated');
await test('Anonymous request cannot access internal finance core',r => [401,403,404].includes(r.status),'POST',
  '/rest/v1/rpc/food_finance_report_core_qa','anon',
  {...range,p_store_id:null});
if (keys.admin) {
  await test('QA allowlisted Admin can read report',
    r => r.status === 200 && ensureReport(r.data),'POST',
    '/rest/v1/rpc/admin_food_finance_report_qa','admin',
    {...range,p_store_id:null});
} else {
  skipped++;
  process.stdout.write('SKIP QA Admin allowlisted positive test (no approved JWT)\n');
}
process.stdout.write('HTTP QA RESULTS pass=' + passed + ' fail=' + failed + ' skip=' + skipped + '\n');
if (failed) process.exitCode = 1;
