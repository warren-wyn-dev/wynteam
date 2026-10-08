import test from "node:test";
import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {dirname,join} from "node:path";
import {fileURLToPath} from "node:url";

const path=join(dirname(fileURLToPath(import.meta.url)),"finance_qa_password_auth_runner.mjs");
const env={
 WYNOS_QA_HTTP_ACK:"pcatuxtenluqzjzzwsvl",
 WYNOS_QA_SUPABASE_URL:"https://pcatuxtenluqzjzzwsvl.supabase.co",
 WYNOS_QA_STRICT_AUTH_GATE:"true",
 WYNOS_QA_PASSWORD_GRANT_ACK:"existing-three-qa-users-only",
 WYNOS_QA_ANON_KEY:"sb_publishable_ci_dummy_nonnetwork",
 WYNOS_QA_OWNER_EMAIL:"owner@qa-invalid.test", WYNOS_QA_OWNER_PASSWORD:"dummy-owner-secret",
 WYNOS_QA_UNRELATED_EMAIL:"unrelated@qa-invalid.test",WYNOS_QA_UNRELATED_PASSWORD:"dummy-unrelated-secret",
 WYNOS_QA_APPROVED_ADMIN_EMAIL:"admin@qa-invalid.test",WYNOS_QA_APPROVED_ADMIN_PASSWORD:"dummy-admin-secret",
 WYNOS_QA_OWNER_STORE_ID:"10000000-0000-4000-8000-000000000001",
 WYNOS_QA_OTHER_STORE_ID:"10000000-0000-4000-8000-000000000002"
};
const cases=[
 ["refuse wrong project ack",{WYNOS_QA_HTTP_ACK:"prod-reference"},"Missing exact QA project"],
 ["refuse missing strict authorization gate",{WYNOS_QA_STRICT_AUTH_GATE:"false"},"Missing exact QA project"],
 ["refuse missing password grant authorization",{WYNOS_QA_PASSWORD_GRANT_ACK:""},"Missing exact QA project"],
 ["refuse missing QA account",{WYNOS_QA_APPROVED_ADMIN_EMAIL:""},"Missing QA-only environment"],
 ["refuse same Admin and owner",{WYNOS_QA_APPROVED_ADMIN_EMAIL:env.WYNOS_QA_OWNER_EMAIL},"must be different accounts"],
 ["refuse secret service API key",{WYNOS_QA_ANON_KEY:"sb_secret_invalid"},"Refusing service/secret"],
 ["refuse store id reuse",{WYNOS_QA_OTHER_STORE_ID:env.WYNOS_QA_OWNER_STORE_ID},"must be valid and distinct"]
];
for(const [name,patch,expected] of cases){
 test("password Auth QA preflight "+name,()=>{
  const run=spawnSync(process.execPath,[path],{
    env:{...process.env,...env,...patch},encoding:"utf8",timeout:3500,
  });
  assert.notEqual(run.status,0);
  assert.equal(run.signal,null);
  const output=run.stderr+"\n"+run.stdout;
  assert.ok(output.includes(expected),"wrong preflight error");
  for(const secret of [env.WYNOS_QA_OWNER_PASSWORD,env.WYNOS_QA_UNRELATED_PASSWORD,env.WYNOS_QA_APPROVED_ADMIN_PASSWORD]){
    assert.ok(!output.includes(secret),"QA credentials printed to log");
  }
  assert.ok(!output.includes("Auth sign-in succeeded"));
 });
}
