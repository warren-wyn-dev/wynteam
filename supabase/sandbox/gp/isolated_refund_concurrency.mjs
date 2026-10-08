#!/usr/bin/env node
// Concurrent Refund QA: only a throwaway LOCAL PostgreSQL container.
// Loads the EXACT refund math, append function and ledger DDL from Sandbox migrations.
// No Supabase API, Stripe call, secrets, production database or GP collection.
import {readFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {strict as assert} from 'node:assert';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const expectedDatabase='wynos_refund_isolated';
if (process.env.WYNOS_ISOLATED_PG_ACK !== expectedDatabase
 || process.env.PGDATABASE !== expectedDatabase
 || !['localhost','127.0.0.1','::1'].includes(process.env.PGHOST)
 || (process.env.PGPORT && process.env.PGPORT!=='5432')
 || !process.env.PGPASSWORD
 || process.env.PGHOSTADDR || process.env.PGSERVICE || process.env.PGSERVICEFILE
 || process.env.PGURI || process.env.DATABASE_URL) {
 throw new Error('Refusing SQL: explicit local-only ephemeral PostgreSQL QA target and acknowledgement required');
}

const load=name=>readFileSync(resolve(root,'supabase',name),'utf8');
const gp=load('migrations_wynos_food_gp_engine_sandbox_v1.sql');
const finance=load('migrations_wynos_food_finance_sandbox_v1.sql');
const refunds=load('migrations_wynos_food_finance_refunds_sandbox_v1.sql');
const guard=load('migrations_wynos_food_finance_refund_guard_sandbox_v2.sql');
function extractTable(source,name){
 const start=source.indexOf('create table if not exists public.'+name+' (');
 assert(start>=0,'Missing original QA table '+name);
 const end=source.indexOf('\n);',start);
 assert(end>=0,'Missing QA table end '+name);
 return source.slice(start,end+3);
}
function extractFunction(source,name){
 const start=source.indexOf('create or replace function public.'+name+'(');
 assert(start>=0,'Missing original QA function '+name);
 const end=source.indexOf('\n$$;',start);
 assert(end>=0,'Missing QA function end '+name);
 return source.slice(start,end+4);
}
const STORE='10000000-0000-4000-8000-000000000001';
const oid=i=>'10000000-0000-4000-8000-'+String(i).padStart(12,'0');
const scenarios=[1,2,3,4,5];
let bootstrap=`
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE public.food_stores(id uuid PRIMARY KEY);
CREATE TABLE public.food_orders(
 id uuid PRIMARY KEY,store_id uuid NOT NULL REFERENCES public.food_stores(id),
 order_number text NOT NULL,payment_status text,refund_status text,status text,
 payment_provider text,stripe_payment_intent_id text);
CREATE TABLE public.food_stripe_payments(
 order_id uuid PRIMARY KEY REFERENCES public.food_orders(id),
 store_id uuid REFERENCES public.food_stores(id),
 status text,payment_method text,livemode boolean,currency text,
 stripe_account_id text,payment_intent_id text,amount_satang bigint);
`+
 extractTable(gp,'food_gp_order_snapshots')+
 extractTable(finance,'food_finance_order_projections_qa')+
 extractTable(refunds,'food_finance_refund_adjustments_qa')+
 extractTable(refunds,'food_finance_refund_lines_qa')+
 extractFunction(refunds,'food_finance_refund_math_qa')+
 extractFunction(guard,'food_finance_append_refund_qa')+
 `
INSERT INTO public.food_stores(id) VALUES ('${STORE}');
`;
for(const i of scenarios){
 const order=oid(i);
 const pi='pi_isolated_only_'+i;
 bootstrap+=`
INSERT INTO public.food_orders(id,store_id,order_number,payment_status,refund_status,status,payment_provider,stripe_payment_intent_id)
 VALUES ('${order}','${STORE}','ISO-QA-${i}','paid','none','pending_acceptance','stripe','${pi}');
INSERT INTO public.food_stripe_payments(order_id,store_id,status,payment_method,livemode,currency,stripe_account_id,payment_intent_id,amount_satang)
 VALUES ('${order}','${STORE}','paid','promptpay',false,'thb','acct_isolated_fake','${pi}',5000);
INSERT INTO public.food_gp_order_snapshots(order_id,store_id,order_number,rate_bps,rate_configured_at,
  food_subtotal_satang,delivery_fee_satang,customer_paid_satang,order_discount_satang,
  estimated_gp_satang,estimated_store_food_satang,stripe_payment_intent_id)
 VALUES ('${order}','${STORE}','ISO-QA-${i}',750,now(),5000,0,5000,0,375,4625,'${pi}');
INSERT INTO public.food_finance_order_projections_qa(order_id,store_id,order_number,stripe_account_id,stripe_payment_intent_id,
  food_gross_satang,delivery_fee_satang,unallocated_discount_satang,customer_paid_satang,gp_rate_bps,
  estimated_platform_gp_satang,estimated_store_food_satang)
 VALUES ('${order}','${STORE}','ISO-QA-${i}','acct_isolated_fake','${pi}',5000,0,0,5000,750,375,4625);
`;
}

function run(sql,{onOutput}={}){
 return new Promise((resolve,reject)=>{
  let stdout='',stderr='';
  const c=spawn('psql',['-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-f','-'],
    {env:process.env,stdio:['pipe','pipe','pipe']});
  c.on('error',reject);
  c.stdout.on('data',d=>{stdout+=d.toString();if(onOutput)onOutput(stdout);});
  c.stderr.on('data',d=>{stderr+=d.toString();});
  c.on('close',code=>resolve({code,stdout,stderr}));
  c.stdin.end(sql);
 });
}
async function okSql(sql){
 const r=await run(sql);
 assert.equal(r.code,0,'SQL failure: '+r.stderr);
 return r.stdout.trim();
}
const fn=(id,key,amount)=>
  `public.food_finance_append_refund_qa('${oid(id)}','${key}',${amount},0,'Isolated concurrency verification')`;
async function parallel(id,keyA,amtA,keyB,amtB,{expectError=null,expectedA='adjusted',expectedB='already_adjusted'}={}){
 const barrier='__ISOLATED_LOCK_ACQUIRED__';
 let release, promiseB=null,startB=0;
 const completed=new Promise(r=>release=r);
 const sqlA=`BEGIN;
SET LOCAL statement_timeout='14s';
SELECT order_id FROM public.food_finance_order_projections_qa
 WHERE order_id='${oid(id)}' FOR UPDATE;
\\echo ${barrier}
SELECT pg_sleep(2);
SELECT ${fn(id,keyA,amtA)}->>'status';
COMMIT;`;
 const sqlB=`BEGIN;
SET LOCAL lock_timeout='9s';
SET LOCAL statement_timeout='14s';
SELECT ${fn(id,keyB,amtB)}->>'status';
COMMIT;`;
 const aPromise=run(sqlA,{onOutput:output=>{
   if(output.includes(barrier)&&!promiseB){
     startB=Date.now();
     promiseB=run(sqlB).then(r=>{release(r);return r});
   }
 }});
 const a=await aPromise;
 assert.equal(a.code,0,'Session A error: '+a.stderr);
 assert(a.stdout.includes(expectedA),'Unexpected Session A: '+a.stdout);
 assert(promiseB,'Session B never started');
 const b=await completed;
 assert(Date.now()-startB>=1100,'Session B did not appear to wait for Session A row lock');
 if(expectError){
   assert.notEqual(b.code,0,'Expected denied concurrent refund');
   assert(b.stderr.includes(expectError),'Wrong refusal: '+b.stderr);
 }else{
   assert.equal(b.code,0,'Session B error: '+b.stderr);
   assert(b.stdout.includes(expectedB),'Unexpected Session B: '+b.stdout);
 }
 return {a:a.stdout.trim(),b:b.stdout.trim()};
}
async function verify(id,count,refunded,gp){
 await okSql(`DO $$
DECLARE n int; r bigint;g bigint; unbalanced int;
BEGIN
 SELECT count(*),coalesce(sum(food_refund_satang),0),
  coalesce(sum(estimated_platform_gp_reversal_satang),0)
 INTO n,r,g FROM public.food_finance_refund_adjustments_qa WHERE order_id='${oid(id)}';
 IF n<>${count} OR r<>${refunded} OR g<>${gp} THEN
  RAISE EXCEPTION 'Mismatch for scenario ${id}: count %, food %, GP %',n,r,g;
 END IF;
 SELECT count(*) INTO unbalanced FROM (
   SELECT adjustment_id,book,sum(signed_amount_satang) AS amount
   FROM public.food_finance_refund_lines_qa
   GROUP BY adjustment_id,book HAVING sum(signed_amount_satang)<>0
 ) q;
 IF unbalanced<>0 THEN RAISE EXCEPTION 'Finance books do not balance';END IF;
 IF EXISTS(SELECT 1 FROM public.food_finance_refund_adjustments_qa
   WHERE actual_customer_refunded_satang<>0 OR actual_platform_gp_reversed_satang<>0
     OR stripe_refund_id IS NOT NULL OR mode<>'simulation_only') THEN
  RAISE EXCEPTION 'Test created alleged actual refunds';END IF;
END $$;`);
}
await okSql(bootstrap);
console.log('BOOTSTRAP PASS: exact QA refund implementation and original ledger table definitions');
await parallel(1,'ISO-SAME',2500,'ISO-SAME',2500);
await verify(1,1,2500,188);
console.log('PASS same-key idempotency under real row-lock contention');

await parallel(2,'ISO-FIRST',3333,'ISO-EXCESS',3333,{
 expectError:'refund exceeds remaining food or delivery'});
await verify(2,1,3333,250);
console.log('PASS different keys cannot exceed customer-paid balance');

await parallel(3,'ISO-PART1',3333,'ISO-PART2',1667,{expectedB:'adjusted'});
await verify(3,2,5000,375);
console.log('PASS distinct complementary refunds serialize; cumulative half-up GP 375 satang');

await parallel(4,'ISO-REPLAY',2000,'ISO-REPLAY',2001,{
 expectError:'simulation key replay payload mismatch'});
await verify(4,1,2000,150);
console.log('PASS conflicting replay payload rejected while first request commits');

const reqs=Array.from({length:10},()=>run(
 `SELECT ${fn(5,'ISO-LOAD',1000)}->>'status';`));
const all=await Promise.all(reqs);
assert(all.every(x=>x.code===0),JSON.stringify(all.filter(x=>x.code!==0)));
assert.equal(all.filter(x=>x.stdout.includes('adjusted')&&!x.stdout.includes('already_adjusted')).length,1,
 'Exactly one first adjustment needed');
assert.equal(all.filter(x=>x.stdout.includes('already_adjusted')).length,9,
 'All duplicate concurrent requests should be idempotent');
await verify(5,1,1000,75);
console.log('PASS 10 concurrent connections, one insert and nine idempotent replays');

await okSql(`DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.food_orders WHERE payment_status<>'paid' OR refund_status<>'none')
 THEN RAISE EXCEPTION 'Simulated refund mutated payment status';END IF;
 IF EXISTS(SELECT 1 FROM public.food_stripe_payments WHERE livemode OR status<>'paid')
 THEN RAISE EXCEPTION 'Simulated refund mutated fake Stripe payment';END IF;
END $$;`);
console.log('ALL 5 ISOLATED CONCURRENCY CASES PASS. Ephemeral database is destroyed by CI service cleanup.');
