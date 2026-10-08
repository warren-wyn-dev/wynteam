#!/usr/bin/env node
// One-run disposable Supabase QA Finance Admin fixture lifecycle.
// Manual sandbox GitHub Actions environment only. Server-side legacy QA
// service_role secret is used ONLY for createUser, scoped allowlist grant,
// and removal. Never used by the Finance HTTP/Bearer authorization tests.
import {randomBytes} from "node:crypto";
import {readFileSync,writeFileSync,unlinkSync,existsSync} from "node:fs";
import {join} from "node:path";
import {spawn} from "node:child_process";

const PROJECT="pcatuxtenluqzjzzwsvl";
const QA="https://"+PROJECT+".supabase.co";
const REPO="warren-wyn-dev/wynteam";
const BRANCH="refs/heads/sandbox/stripe-testmode-20261008";
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const env=process.env;
const missing=(names)=>names.filter(k=>!env[k]);
function fail(message){throw Error(message);}
function assertScope(){
  if(env.CI!=="true" || env.GITHUB_ACTIONS!=="true"
    || env.GITHUB_REPOSITORY!==REPO || env.GITHUB_REF!==BRANCH
    || env.GITHUB_EVENT_NAME!=="workflow_dispatch"
    || !/^\d{6,}$/.test(env.GITHUB_RUN_ID||"")
    || !/^\d+$/.test(env.GITHUB_RUN_ATTEMPT||"")
    || env.WYNOS_QA_HTTP_ACK!==PROJECT || env.WYNOS_QA_SUPABASE_URL!==QA
    || env.WYNOS_QA_STRICT_AUTH_GATE!=="true"
    || env.WYNOS_QA_TEMP_ADMIN_APPROVED!=="true"
    || env.WYNOS_QA_EPHEMERAL_ADMIN_ENABLED!=="true"){
    fail("Refusing Finance Admin lifecycle outside explicitly approved manual QA GitHub run");
  }
  if(!env.RUNNER_TEMP || !env.RUNNER_TEMP.startsWith("/")){
    fail("Missing isolated GitHub Runner temporary directory");
  }
}
function service(){
  const token=env.WYNOS_QA_SERVICE_ROLE_LEGACY_JWT;
  if(typeof token!=="string" || token.split(".").length!==3 || !token.startsWith("eyJ")){
    fail("Missing QA legacy service-role JWT (environment secret), no actions performed");
  }
  let claims;
  try{claims=JSON.parse(Buffer.from(token.split(".")[1],"base64url").toString("utf8"));}
  catch{fail("Malformed QA provisioning credential, no actions performed");}
  if(claims.role!=="service_role" || (typeof claims.exp==="number" && claims.exp <=Date.now()/1000)){
    fail("Refusing non-service/expired QA provisioning credential");
  }
  return token;
}
const statePath=()=>{
  return join(env.RUNNER_TEMP,"wynos-finance-admin-"+env.GITHUB_RUN_ID+"-"+env.GITHUB_RUN_ATTEMPT+".json");
};
const prefix="finance-qa-"+(env.GITHUB_RUN_ID||"")+"-";
function headers(key,extra={}){
  return {apikey:key,Authorization:"Bearer "+key,accept:"application/json",...extra};
}
async function call(url,key,method,body,label,queryHeaders={}){
  const response=await fetch(QA+url,{
    method,
    headers:headers(key,body===undefined?queryHeaders:
      {"content-type":"application/json",...queryHeaders}),
    body:body===undefined?undefined:JSON.stringify(body),
    redirect:"error",
    signal:AbortSignal.timeout(15000)
  });
  if(!response.ok){
    fail(label+" failed with HTTP "+response.status+" (credential and response hidden)");
  }
  if(response.status===204) return null;
  const content=await response.text();
  return content?JSON.parse(content):null;
}
function saveState(state){
  writeFileSync(statePath(),JSON.stringify(state),{mode:0o600,flag:"w"});
}
function loadState(){
  if(!existsSync(statePath()))return null;
  const state=JSON.parse(readFileSync(statePath(),"utf8"));
  if(state.project!==PROJECT || state.runId!==env.GITHUB_RUN_ID
    || state.attempt!==env.GITHUB_RUN_ATTEMPT
    || !uuid.test(state.id||"")
    || !String(state.email).startsWith(prefix)
    || !String(state.email).endsWith("@wynos.online")){
    fail("Refusing unsafe or corrupted Finance QA cleanup state");
  }
  return state;
}
async function cleanup(key){
  const st=loadState();
  if(!st){console.log("Finance QA cleanup: no created admin fixture in this CI job");return;}
  const filter=encodeURIComponent(st.id);
  // Revoke the persistent Finance allowlist first. If it fails, refuse
  // to claim success; separate workflow always-cleanup step will retry.
  await call("/rest/v1/food_gp_admin_allowlist?user_id=eq."+filter,key,"DELETE",
    undefined,"Revoke temporary Finance QA allowlist");
  const remains=await call("/rest/v1/food_gp_admin_allowlist?user_id=eq."+filter+
    "&select=user_id",key,"GET",undefined,"Verify Finance QA allowlist cleanup");
  if(!Array.isArray(remains)||remains.length!==0){
    fail("Finance QA admin allowlist still present, refusing successful cleanup claim");
  }
  // Never delete a preexisting Auth user; check created ID and exact
  // freshly generated CI-only email immediately before deletion.
  const target=await call("/auth/v1/admin/users/"+filter,key,"GET",
    undefined,"Read-only verification of synthetic Auth identity");
  const user=target?.user||target;
  if(!user || user.id!==st.id || user.email!==st.email){
    fail("Refusing Auth deletion: synthesized account identity does not match");
  }
  await call("/auth/v1/admin/users/"+filter,key,"DELETE",
    undefined,"Delete just-created ephemeral Supabase QA Auth user");
  unlinkSync(statePath());
  console.log("PASS: revoked ephemeral Finance QA admin grant and deleted just-created Auth account");
}
async function preflight(){
  const need=[
    "WYNOS_QA_ANON_KEY","WYNOS_QA_OWNER_EMAIL","WYNOS_QA_OWNER_PASSWORD",
    "WYNOS_QA_UNRELATED_EMAIL","WYNOS_QA_UNRELATED_PASSWORD",
    "WYNOS_QA_OWNER_STORE_ID","WYNOS_QA_OTHER_STORE_ID"
  ];
  const m=missing(need);
  if(m.length) fail("QA-only runner setup incomplete: "+m.join(", "));
  if(env.WYNOS_QA_OWNER_EMAIL.trim().toLowerCase()===
     env.WYNOS_QA_UNRELATED_EMAIL.trim().toLowerCase()){
    fail("Owner and unrelated QA test users must be distinct");
  }
  if(env.WYNOS_QA_ANON_KEY.startsWith("sb_secret_") ||
    !/^(sb_publishable_|eyJ)/.test(env.WYNOS_QA_ANON_KEY)){
    fail("Refusing secret or unexpected QA public API key");
  }
  if(!uuid.test(env.WYNOS_QA_OWNER_STORE_ID)
    || !uuid.test(env.WYNOS_QA_OTHER_STORE_ID)
    || env.WYNOS_QA_OWNER_STORE_ID===env.WYNOS_QA_OTHER_STORE_ID){
    fail("QA store IDs must be valid and distinct");
  }
  if(env.WYNOS_QA_PASSWORD_GRANT_ACK!=="existing-three-qa-users-only"){
    fail("Password Auth test approval not present");
  }
}
async function runTest(email,password){
  // Existing helper authenticates all three independently against QA Auth,
  // then performs strictly read-only HTTPS Finance RPC tests as USERs.
  // Full service-role credentials never reach this child process.
  const childEnv={...env,WYNOS_QA_APPROVED_ADMIN_EMAIL:email,
    WYNOS_QA_APPROVED_ADMIN_PASSWORD:password};
  delete childEnv.WYNOS_QA_SERVICE_ROLE_LEGACY_JWT;
  delete childEnv.WYNOS_QA_OWNER_JWT;
  delete childEnv.WYNOS_QA_UNRELATED_JWT;
  delete childEnv.WYNOS_QA_APPROVED_ADMIN_JWT;
  return await new Promise((resolve,reject)=>{
    const child=spawn(process.execPath,
      ["supabase/sandbox/gp/finance_qa_password_auth_runner.mjs"],
      {env:childEnv,stdio:"inherit"});
    child.on("error",reject);
    child.on("close",(code,signal)=>
      resolve({ok:code===0&&!signal,code,signal}));
  });
}
async function main(){
  assertScope();
  const key=service();
  if(process.argv[2]==="--cleanup"){
    await cleanup(key);
    return;
  }
  if(process.argv.length>2)fail("Unknown Finance QA lifecycle mode");
  await preflight();
  if(existsSync(statePath()))fail("Stale QA fixture state from this job: cleanup required before creating another");
  // No provisioning HTTP call happens before EVERY scope/credential preflight.
  const password=randomBytes(36).toString("base64url")+"!Aa7";
  const email=prefix+randomBytes(8).toString("hex")+"@wynos.online";
  let provisioned=false;let outcome=null;let cleanupError=null;
  try{
    const created=await call("/auth/v1/admin/users",key,"POST",{
      email,password,email_confirm:true,
      app_metadata:{wynos_finance_ephemeral_qa:true,github_run_id:env.GITHUB_RUN_ID}
    },"Create one ephemeral QA Auth Admin test identity");
    const u=created?.user||created;
    if(!u || !uuid.test(u.id||"") || u.email!==email){
      fail("Unexpected QA Auth creation response; operator must inspect for possible orphaned synthetic user");
    }
    saveState({project:PROJECT,runId:env.GITHUB_RUN_ID,
      attempt:env.GITHUB_RUN_ATTEMPT,id:u.id,email});
    provisioned=true;
    const note="WYNOS Finance QA ephemeral GitHub Actions run "+env.GITHUB_RUN_ID+" attempt "+env.GITHUB_RUN_ATTEMPT;
    await call("/rest/v1/food_gp_admin_allowlist",key,"POST",
      [{user_id:u.id,note}],
      "Grant ONLY ephemeral Finance QA Admin access",
      {Prefer:"return=representation"});
    const entries=await call("/rest/v1/food_gp_admin_allowlist?user_id=eq."+
       encodeURIComponent(u.id)+"&select=user_id,note",key,"GET",
       undefined,"Verify ephemeral Finance QA Admin allowlist grant");
    if(!Array.isArray(entries)||entries.length!==1||entries[0].note!==note){
      fail("Ephemeral Finance QA Admin allowlist grant verification failed");
    }
    console.log("PASS: created one synthetic QA-only Auth user and temporary scoped Finance Admin allowlist entry");
    outcome=await runTest(email,password);
    if(!outcome.ok)fail("Signed-JWT HTTP Finance authorization gate failed");
    console.log("PASS: real Finance Auth owner/outsider/ephemeral-admin HTTP test");
  }finally{
    if(provisioned){
      try{await cleanup(key);}catch(e){
        cleanupError=e;
        console.error("FAIL: Finance QA cleanup requires immediate protected retry: "+e.message);
      }
    }
    if(cleanupError)process.exitCode=1;
  }
}
try{await main();}catch(e){
  // Do not print tokens, credentials, users' emails, or remote API bodies.
  console.error("FAIL: "+e.message);
  process.exitCode=1;
}
