import test from "node:test";
import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {mkdtempSync,rmSync} from "node:fs";
import {tmpdir} from "node:os";
import {join,dirname} from "node:path";
import {fileURLToPath} from "node:url";

const script=join(dirname(fileURLToPath(import.meta.url)),"finance_qa_ephemeral_admin_lifecycle.mjs");
const fakeJwt=(role)=>{
  const h=Buffer.from(JSON.stringify({alg:"HS256"})).toString("base64url");
  const p=Buffer.from(JSON.stringify({role,iss:"supabase"})).toString("base64url");
  return h+"."+p+".not-an-authentic-signature";
};
const temp=mkdtempSync(join(tmpdir(),"wynos-finance-security-preflight-"));
const defaultEnv={
  CI:"true",GITHUB_ACTIONS:"true",GITHUB_EVENT_NAME:"workflow_dispatch",
  GITHUB_REPOSITORY:"warren-wyn-dev/wynteam",
  GITHUB_REF:"refs/heads/sandbox/stripe-testmode-20261008",
  GITHUB_RUN_ID:"999999991",GITHUB_RUN_ATTEMPT:"1",RUNNER_TEMP:temp,
  WYNOS_QA_HTTP_ACK:"pcatuxtenluqzjzzwsvl",
  WYNOS_QA_SUPABASE_URL:"https://pcatuxtenluqzjzzwsvl.supabase.co",
  WYNOS_QA_STRICT_AUTH_GATE:"true",
  WYNOS_QA_TEMP_ADMIN_APPROVED:"true",
  WYNOS_QA_EPHEMERAL_ADMIN_ENABLED:"true",
  WYNOS_QA_PASSWORD_GRANT_ACK:"existing-three-qa-users-only",
  WYNOS_QA_SERVICE_ROLE_LEGACY_JWT:fakeJwt("service_role"),
  WYNOS_QA_ANON_KEY:"sb_publishable_dummy_offline_only",
  WYNOS_QA_OWNER_EMAIL:"qa-owner@example.invalid",
  WYNOS_QA_OWNER_PASSWORD:"dummy-owner-ci-secret",
  WYNOS_QA_UNRELATED_EMAIL:"qa-outsider@example.invalid",
  WYNOS_QA_UNRELATED_PASSWORD:"dummy-outsider-ci-secret",
  WYNOS_QA_OWNER_STORE_ID:"10000000-0000-4000-8000-000000000001",
  WYNOS_QA_OTHER_STORE_ID:"10000000-0000-4000-8000-000000000002"
};
function attempt(patch={},args=[]){
  return spawnSync(process.execPath,[script,...args],{
    encoding:"utf8",
    timeout:3500,
    env:{...process.env,...defaultEnv,...patch},
  });
}
const cases=[
  ["wrong project",{WYNOS_QA_HTTP_ACK:"wrong-project"},"Refusing Finance Admin lifecycle"],
  ["production branch",{GITHUB_REF:"refs/heads/main"},"Refusing Finance Admin lifecycle"],
  ["unapproved repo",{GITHUB_REPOSITORY:"other-owner/other-repo"},"Refusing Finance Admin lifecycle"],
  ["push event forbidden",{GITHUB_EVENT_NAME:"push"},"Refusing Finance Admin lifecycle"],
  ["no human approval",{WYNOS_QA_TEMP_ADMIN_APPROVED:"false"},"Refusing Finance Admin lifecycle"],
  ["wrong QA host",{WYNOS_QA_SUPABASE_URL:"https://supabase-not-qa.invalid"},"Refusing Finance Admin lifecycle"],
  ["missing high-privilege secret",{WYNOS_QA_SERVICE_ROLE_LEGACY_JWT:""},"Missing QA legacy service-role JWT"],
  ["wrong key role",{WYNOS_QA_SERVICE_ROLE_LEGACY_JWT:fakeJwt("anon")},"Refusing non-service"],
  ["missing existing owner password",{WYNOS_QA_OWNER_PASSWORD:""},"runner setup incomplete"],
  ["owner and unrelated are identical",{WYNOS_QA_UNRELATED_EMAIL:defaultEnv.WYNOS_QA_OWNER_EMAIL},"must be distinct"],
  ["public API secret key",{WYNOS_QA_ANON_KEY:"sb_secret_wrong"},"Refusing secret"],
  ["same store IDs",{WYNOS_QA_OTHER_STORE_ID:defaultEnv.WYNOS_QA_OWNER_STORE_ID},"must be valid and distinct"]
];
for(const [label,patch,expected] of cases){
  test("provisioning safeguards reject "+label,()=>{
    const r=attempt(patch);
    assert.equal(r.signal,null,"possible network attempt/timeout");
    assert.notEqual(r.status,0);
    const log=r.stdout+r.stderr;
    assert.ok(log.includes(expected),"unexpected failure reason");
    assert.ok(!log.includes(defaultEnv.WYNOS_QA_OWNER_PASSWORD),"leaked test password");
    assert.ok(!log.includes(defaultEnv.WYNOS_QA_SERVICE_ROLE_LEGACY_JWT),"leaked service key");
    assert.ok(!log.includes("created one synthetic QA-only Auth user"),"attempted provisioning");
  });
}
test("cleanup with no lifecycle state is an idempotent no-op without network",()=>{
  const r=attempt({},["--cleanup"]);
  assert.equal(r.signal,null);
  assert.equal(r.status,0,"cleanup should safely skip with no state");
  assert.match(r.stdout,/no created admin fixture/);
});
test.after(()=>{rmSync(temp,{recursive:true,force:true});});
