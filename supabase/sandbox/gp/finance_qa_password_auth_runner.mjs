#!/usr/bin/env node
// Ephemeral Supabase QA Auth login for Finance signed-JWT HTTP regression.
// Existing QA test accounts ONLY. Creates no users, memberships, admin grants,
// finance fixtures, or Stripe refunds. Does not print credentials or JWTs.
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';

const project = 'pcatuxtenluqzjzzwsvl';
const api = 'https://' + project + '.supabase.co';
const keys = [
  'WYNOS_QA_ANON_KEY',
  'WYNOS_QA_OWNER_EMAIL','WYNOS_QA_OWNER_PASSWORD',
  'WYNOS_QA_UNRELATED_EMAIL','WYNOS_QA_UNRELATED_PASSWORD',
  'WYNOS_QA_APPROVED_ADMIN_EMAIL','WYNOS_QA_APPROVED_ADMIN_PASSWORD',
  'WYNOS_QA_OWNER_STORE_ID','WYNOS_QA_OTHER_STORE_ID'
];

const fail = (message) => { throw new Error(message + '; no QA HTTP finance tests were sent'); };
if (process.env.WYNOS_QA_HTTP_ACK !== project ||
    process.env.WYNOS_QA_SUPABASE_URL !== api ||
    process.env.WYNOS_QA_PASSWORD_GRANT_ACK !== 'existing-three-qa-users-only' ||
    process.env.WYNOS_QA_STRICT_AUTH_GATE !== 'true') {
  fail('Missing exact QA project/password grant/strict-gate acknowledgement');
}
const missing = keys.filter(key => !process.env[key]);
if (missing.length) fail('Missing QA-only environment variable(s): ' + missing.join(', '));
const key = process.env.WYNOS_QA_ANON_KEY;
if (key.startsWith('sb_secret_') ||
  !(key.startsWith('sb_publishable_') || key.startsWith('eyJ'))) {
  fail('Refusing service/secret or invalid QA API key');
}
const emails = [
  process.env.WYNOS_QA_OWNER_EMAIL,
  process.env.WYNOS_QA_UNRELATED_EMAIL,
  process.env.WYNOS_QA_APPROVED_ADMIN_EMAIL,
];
if (new Set(emails.map(e => e.trim().toLowerCase())).size !== 3) {
  fail('QA owner, outsider and independently allowlisted Admin must be different accounts');
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (![process.env.WYNOS_QA_OWNER_STORE_ID,process.env.WYNOS_QA_OTHER_STORE_ID].every(v=>uuid.test(v))
 || process.env.WYNOS_QA_OWNER_STORE_ID === process.env.WYNOS_QA_OTHER_STORE_ID) {
  fail('QA store UUIDs must be valid and distinct');
}
// Passwords are sent only to the verified Supabase QA Auth endpoint over TLS.
// Do not return response error bodies: they might inadvertently contain PII.
async function signIn(label, email, password) {
  const response = await fetch(api + '/auth/v1/token?grant_type=password', {
    method:'POST',
    headers:{apikey:key,'content-type':'application/json','accept':'application/json'},
    body:JSON.stringify({email,password}),
    redirect:'error',
    signal:AbortSignal.timeout(12000),
  });
  if (!response.ok) fail('QA ' + label + ' sign-in failed (HTTP ' + response.status + ')');
  const data = await response.json();
  const token = data?.access_token;
  if (typeof token !== 'string' || token.split('.').length!==3) {
    fail('QA ' + label + ' Auth did not return a signed access token');
  }
  let claims;
  try { claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString('utf8')); }
  catch { fail('QA ' + label + ' returned malformed JWT'); }
  if (claims.iss !== api + '/auth/v1' || claims.role !== 'authenticated'
   || !uuid.test(claims.sub || '') || !Number.isSafeInteger(claims.exp)
   || claims.exp < Date.now()/1000 + 30) {
    fail('QA ' + label + ' returned wrong-project/expired/nonuser JWT');
  }
  // The Supabase QA Auth endpoint is the sole issuer; the runner will send
  // each token BACK to Supabase to verify its signature and authorization.
  return {jwt:token,userId:claims.sub};
}
const owner=await signIn('owner',process.env.WYNOS_QA_OWNER_EMAIL,process.env.WYNOS_QA_OWNER_PASSWORD);
const unrelated=await signIn('unrelated',process.env.WYNOS_QA_UNRELATED_EMAIL,process.env.WYNOS_QA_UNRELATED_PASSWORD);
const admin=await signIn('allowlisted admin',process.env.WYNOS_QA_APPROVED_ADMIN_EMAIL,process.env.WYNOS_QA_APPROVED_ADMIN_PASSWORD);
if(new Set([owner.userId,unrelated.userId,admin.userId]).size !== 3){
  fail('QA Auth unexpectedly signed into duplicate identities');
}
const childEnv={...process.env,
  WYNOS_QA_OWNER_JWT:owner.jwt,
  WYNOS_QA_UNRELATED_JWT:unrelated.jwt,
  WYNOS_QA_APPROVED_ADMIN_JWT:admin.jwt
};
for(const k of Object.keys(childEnv)){
  if(k.endsWith('_PASSWORD')||k.endsWith('_EMAIL')) delete childEnv[k];
}
console.log('QA owner/outsider/admin Auth sign-in succeeded (credentials and tokens not logged)');
const testScript=join(dirname(fileURLToPath(import.meta.url)),'finance_http_signed_jwt_qa.mjs');
const result=spawnSync(process.execPath,[testScript],{
  env:childEnv,encoding:'utf8',timeout:200000,maxBuffer:1024*1024
});
if(result.stdout)process.stdout.write(result.stdout);
if(result.stderr)process.stderr.write(result.stderr);
if(result.error)throw new Error('Signed-JWT HTTP QA child runner failed without disclosing credentials');
process.exitCode=result.status === null ? 1 : result.status;
