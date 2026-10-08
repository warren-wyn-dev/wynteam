import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// These only exercise REJECTED credential configurations, never live HTTP.
// JWT parts here are intentionally NOT SIGNED and never used for real QA access.
const script = join(dirname(fileURLToPath(import.meta.url)), "finance_http_signed_jwt_qa.mjs");
const qa = "https://pcatuxtenluqzjzzwsvl.supabase.co";
const makeJwt = (sub,overrides={}) => [
  Buffer.from(JSON.stringify({alg:"HS256",typ:"JWT"})).toString("base64url"),
  Buffer.from(JSON.stringify({
    iss:qa+"/auth/v1",role:"authenticated",aud:"authenticated",
    sub,exp:Math.floor(Date.now()/1000)+3600,...overrides,
  })).toString("base64url"),
  "not-a-real-signature",
].join(".");
const owner="10000000-0000-4000-8000-000000000001";
const outsider="10000000-0000-4000-8000-000000000002";
const base={
  WYNOS_QA_HTTP_ACK:"pcatuxtenluqzjzzwsvl",
  WYNOS_QA_SUPABASE_URL:qa,
  WYNOS_QA_ANON_KEY:"sb_publishable_local_invalid_preflight_only",
  WYNOS_QA_OWNER_JWT:makeJwt(owner),
  WYNOS_QA_UNRELATED_JWT:makeJwt(outsider),
  WYNOS_QA_OWNER_STORE_ID:"10000000-0000-4000-8000-000000000011",
  WYNOS_QA_OTHER_STORE_ID:"10000000-0000-4000-8000-000000000012",
};
const cases=[
  ["wrong QA URL",{WYNOS_QA_SUPABASE_URL:"https://not-a-wynos-qa.supabase.co"},"Refusing non-QA endpoint"],
  ["privileged API key",{WYNOS_QA_ANON_KEY:"sb_secret_nope"},"QA secret API key forbidden"],
  ["owner from another project",{WYNOS_QA_OWNER_JWT:makeJwt(owner,{iss:"https://wrong-project.supabase.co/auth/v1"})},"Unsafe/expired/wrong-project owner"],
  ["service role user JWT",{WYNOS_QA_OWNER_JWT:makeJwt(owner,{role:"service_role"})},"Unsafe/expired/wrong-project owner"],
  ["expired owner JWT",{WYNOS_QA_OWNER_JWT:makeJwt(owner,{exp:1})},"Unsafe/expired/wrong-project owner"],
  ["duplicate owner/unrelated identity",{WYNOS_QA_UNRELATED_JWT:makeJwt(owner)},"Use separate QA identities"],
  ["wrong API project key format",{WYNOS_QA_ANON_KEY:"sk-live-invalid"},"Unexpected publishable API key format"],
  ["wrong store selection",{WYNOS_QA_OTHER_STORE_ID:base.WYNOS_QA_OWNER_STORE_ID},"Store IDs must be distinct"],
];
for(const [label,envPatch,expected] of cases){
 test("QA HTTP credential preflight refuses "+label,()=>{
   const result=spawnSync(process.execPath,[script],{
     env:{...process.env,...base,...envPatch},timeout:5000,encoding:"utf8",
   });
   assert.notEqual(result.status,0,"preflight failed to reject bad credentials");
   const output=result.stderr+result.stdout;
   assert.ok(output.includes(expected),"wrong rejection reason: "+output);
   assert.ok(!output.includes("HTTP QA RESULTS"),"a network test started unexpectedly");
   assert.ok(!output.includes(base.WYNOS_QA_OWNER_JWT),"JWT leaked to stdout");
 });
}
