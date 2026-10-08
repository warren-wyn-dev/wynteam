#!/usr/bin/env node
// Non-destructive TWO-INDEPENDENT-SESSION QA lock probe.
// This verifies lock contention on an existing QA order row, not actual
// concurrent finance refund correctness. BOTH DB sessions ROLLBACK.
// Run only on QA with psql and a PostgreSQL QA credential in the local env.
import {spawn} from 'node:child_process';
const project='pcatuxtenluqzjzzwsvl';
if (process.env.WYNOS_QA_LOCK_ACK !== project || !process.env.WYNOS_QA_DB_URL) {
  throw new Error('QA acknowledgement and database URL required; no database requests sent');
}
const u=new URL(process.env.WYNOS_QA_DB_URL);
if (!['postgresql:','postgres:'].includes(u.protocol) ||
    u.hostname !== 'db.'+project+'.supabase.co') {
  throw new Error('Refusing non-QA direct database hostname; no database requests sent');
}
const childEnv={...process.env,PGDATABASE:process.env.WYNOS_QA_DB_URL};
delete childEnv.WYNOS_QA_DB_URL;
function start(sql, name) {
  const c=spawn('psql',['-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-f','-'],
    {env:childEnv,stdio:['pipe','pipe','pipe']});
  let stdout='',stderr='';
  c.stdout.on('data',d=>{stdout+=d.toString(); if(name==='A' && stdout.includes('__QA_ORDER_LOCK_ACQUIRED__'))startB();});
  c.stderr.on('data',d=>{stderr+=d.toString();});
  const finished=new Promise((resolve,reject)=>{
    c.once('error',reject);
    c.once('close',code=>resolve({code,stdout,stderr}));
  });
  c.stdin.end(sql);
  return finished;
}
let startedB=false, promiseB=null;
function startB(){
 if(startedB)return;
 startedB=true;
 const bSql=`BEGIN;
SET LOCAL lock_timeout = '700ms';
DO $$$$
DECLARE blocked boolean := false;
BEGIN
  BEGIN
    PERFORM id FROM public.food_orders WHERE order_number='WF000005' FOR UPDATE;
  EXCEPTION WHEN lock_not_available THEN
    blocked := true;
  END;
  IF NOT blocked THEN
    RAISE EXCEPTION 'QA lock contention was NOT observed';
  END IF;
  RAISE NOTICE 'QA_LOCK_CONTENTION_PASS';
END;$$$$;
ROLLBACK;`;
 promiseB=start(bSql,'B');
}
const aSql=`BEGIN;
SET LOCAL lock_timeout = '7s';
SELECT id FROM public.food_orders WHERE order_number='WF000005' FOR UPDATE;
\\echo __QA_ORDER_LOCK_ACQUIRED__
SELECT pg_sleep(5);
ROLLBACK;`;
const timer=setTimeout(()=>{process.stderr.write('FAIL probe timed out\n');process.exit(1)},20000);
let a,b;
try{
 a=await start(aSql,'A');
 if(!startedB)throw new Error('QA Session A never acquired lock');
 b=await promiseB;
 if(a.code!==0||b.code!==0||!b.stderr.includes('QA_LOCK_CONTENTION_PASS')) {
   throw new Error('Lock contention was not confirmed; sessions exited with '+a.code+'/'+b.code);
 }
 process.stdout.write('PASS two independent QA DB sessions contended on WF000005 row; both ROLLBACK\n');
 process.stdout.write('NOT TESTED: simultaneous food_finance_append_refund_qa under two sessions\n');
}catch(e){process.stderr.write('NOT VERIFIED: '+e.message+'\n');process.exitCode=1;}
finally{clearTimeout(timer);}
