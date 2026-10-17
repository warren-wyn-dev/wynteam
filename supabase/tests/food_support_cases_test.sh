#!/usr/bin/env bash
# Isolated PostgreSQL integration: no credentials, production data or network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="food_support_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function public.is_developer_account() returns boolean language sql stable as $$select coalesce(nullif(current_setting('test.developer',true),''),'true')::boolean and auth.uid() is not null$$;
create table public.profiles(id uuid primary key);
create table public.admin_permissions(user_id uuid primary key,level text);
create function internal.has_admin_permission(p_system text,p_level text) returns boolean language sql stable as $$
 select p_system='food' and exists(select 1 from public.admin_permissions where user_id=auth.uid() and (level='edit' or p_level='view'))$$;
create table public.food_stores(id uuid primary key,name text);
create table public.food_orders(id uuid primary key,order_number text,store_id uuid,buyer_id uuid,status text,payment_status text);
create table public.food_order_items(id uuid primary key,order_id uuid,item_name text);
insert into public.profiles select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,7) n;
insert into public.admin_permissions values
 ('00000000-0000-0000-0000-000000000003','view'),
 ('00000000-0000-0000-0000-000000000004','edit'),
 ('00000000-0000-0000-0000-000000000005','edit');
insert into public.food_stores values ('10000000-0000-0000-0000-000000000001','Synthetic store');
insert into public.food_orders values
 ('20000000-0000-0000-0000-000000000001','WF001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','delivered','paid'),
 ('20000000-0000-0000-0000-000000000002','WF002','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','preparing','paid');
insert into public.food_order_items values
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Rice bowl'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Noodles');
SQL
MIGRATION="$ROOT/supabase/migrations/20261014072555_food_support_cases.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"
A=00000000-0000-0000-0000-000000000001
B=00000000-0000-0000-0000-000000000002
VIEW=00000000-0000-0000-0000-000000000003
EDIT=00000000-0000-0000-0000-000000000004
OTHER=00000000-0000-0000-0000-000000000005
ORDER=20000000-0000-0000-0000-000000000001
ITEM=30000000-0000-0000-0000-000000000001
CHECKS=0
eq(){
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4: got $got expected $3";exit 1; }
 CHECKS=$((CHECKS+1))
}
fail(){
 local got
 if got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
  echo "FAIL $3: expected error";exit 1
 fi
 [[ "$got" == *"$4"* ]] || { echo "FAIL $3: unexpected $got";exit 1; }
 CHECKS=$((CHECKS+1))
}
fail "" "select public.food_support_cases()" 'signed-out cases' 'Not authorized'
fail "$A" "set test.developer='false';select public.food_support_cases()" 'nondeveloper customer queue' 'Not authorized'
fail "$A" "set test.developer='false';select public.food_create_support_case('$ORDER','order','Missing item','Missing rice bowl')" 'nondeveloper direct intake' 'Not authorized'
fail "$B" "select public.food_create_support_case('$ORDER','order','Missing item','Missing rice bowl')" 'cross buyer intake' 'Order not available'
fail "$A" "select public.food_create_support_case('$ORDER','order','Missing item','Missing rice bowl','30000000-0000-0000-0000-000000000002')" 'cross-order evidence' 'Evidence not available'
fail "$A" "select public.food_create_support_case('$ORDER','fraud','Missing item','Missing rice bowl')" 'kind allowlist' 'Invalid support input'
fail "$A" "select public.food_create_support_case('$ORDER','order','x','Missing rice bowl')" 'short subject' 'Invalid support input'
eq "$A" "select public.food_create_support_case('$ORDER','order','Missing item','Call 0812345678 or test@example.com for missing rice','$ITEM',true)->>'status'" open 'intake'
CASE="$(run -At -c 'select id from public.food_support_cases limit 1' | tail -n1)"
eq "$A" "select public.food_support_case_detail('$CASE')->>'compensation_requested'" true 'compensation request flag only'
eq "$A" "select public.food_support_case_detail('$CASE')->>'evidence_item_name'" 'Rice bowl' 'order evidence reference'
eq "$A" "select public.food_support_case_detail('$CASE')::text like '%0812345678%' or public.food_support_case_detail('$CASE')::text like '%test@example.com%'" f 'stored contact redaction'
eq "$A" "select public.food_support_case_detail('$CASE') ? 'buyer_id'" f 'no buyer ID disclosure'
eq "$A" "select jsonb_array_length(public.food_support_cases())" 1 'customer queue'
eq "$B" "select jsonb_array_length(public.food_support_cases())" 0 'other customer queue'
fail "$B" "select public.food_support_case_detail('$CASE')" 'cross buyer detail' 'Not authorized'
fail "$B" "select public.food_reply_support_case('$CASE',1,'Try to edit other case')" 'cross buyer reply' 'Not authorized'
fail "$A" "select public.admin_food_support_cases()" 'customer agent queue' 'Not authorized'
eq "$VIEW" "select jsonb_array_length(public.admin_food_support_cases())" 1 'view queue'
fail "$VIEW" "select public.admin_update_food_support_case('$CASE',1,'resolved','We reviewed the case','Reviewed carefully',true)" 'view cannot write' 'Not authorized'
fail "$EDIT" "select public.admin_update_food_support_case('$CASE',1,'in_progress','','Reviewed carefully',false)" 'must claim' 'Claim case'
eq "$EDIT" "select public.admin_update_food_support_case('$CASE',1,'in_progress','','Reviewing case',true)->>'version'" 2 'claim'
fail "$OTHER" "select public.admin_update_food_support_case('$CASE',2,'in_progress','Another response','Trying to claim',true)" 'agent ownership' 'another agent'
fail "$EDIT" "select public.admin_update_food_support_case('$CASE',1,'resolved','We reviewed the case','Reviewed carefully',false)" 'stale admin edit' 'Case changed'
fail "$EDIT" "select public.admin_update_food_support_case('$CASE',2,'resolved','','Reviewed carefully',false)" 'resolution requires response' 'Customer response required'
eq "$EDIT" "select public.admin_update_food_support_case('$CASE',2,'waiting_customer','Please describe which item is missing','Need order information')->>'version'" 3 'request info'
eq "$A" "select public.food_reply_support_case('$CASE',3,'The rice bowl was missing')->>'status'" in_progress 'customer response resumes case'
fail "$A" "select public.food_reply_support_case('$CASE',3,'Resend an old response')" 'stale customer reply' 'Case changed'
eq "$EDIT" "select public.admin_update_food_support_case('$CASE',4,'resolved','Your request was recorded for human review','Reviewed order evidence')->>'version'" 5 'resolve'
fail "$A" "select public.food_reply_support_case('$CASE',5,'Please reconsider the evidence')" 'closed case requires appeal' 'requires appeal'
eq "$A" "select public.food_reply_support_case('$CASE',5,'Please reconsider the missing item',true)->>'status'" appealed 'appeal'
fail "$EDIT" "select public.admin_update_food_support_case('$CASE',6,'in_progress','','Review appeal evidence')" 'appeal human response' 'Appeal response required'
eq "$EDIT" "select public.admin_update_food_support_case('$CASE',6,'resolved','We reviewed the appeal evidence with a human','Appeal reviewed by agent')->>'version'" 7 'appeal resolution'
fail "$A" "select public.food_reply_support_case('$CASE',7,'Appeal again please',true)" 'appeal limit' 'Appeal not available'
eq "$EDIT" "select count(*) from public.food_support_events where case_id='$CASE'" 7 'append-only state audit'
eq "$A" "select status||':'||payment_status from public.food_orders where id='$ORDER'" delivered:paid 'original order preserved'
eq "$A" "select has_table_privilege('authenticated','public.food_support_cases','SELECT')" f 'direct case denied'
eq "$A" "select has_table_privilege('authenticated','public.food_support_events','UPDATE')" f 'audit immutable'
eq "$A" "select has_function_privilege('anon','public.food_support_case_detail(uuid)','EXECUTE')" f 'anon denied'
eq "$A" "select has_function_privilege('authenticated','internal.food_support_case_json(uuid,boolean)','EXECUTE')" f 'internal helper denied'
eq "$A" "select public.food_create_support_case('$ORDER','safety','Safety concern','Please review safety concern')->>'status'" open 'safety request no punishment'
fail "$A" "select public.food_create_support_case('$ORDER','safety','Safety concern','Duplicate safety case')" 'duplicate intake' 'Active case already exists'
eq "$A" "select public.food_create_support_case('$ORDER','other','Packaging issue','Please review packaging')->>'status'" open 'third intake'
fail "$A" "select public.food_create_support_case('$ORDER','review','Review concern','Please review review concern')" 'intake rate limit' 'Support rate limit'
run >/dev/null < "$ROOT/supabase/rollbacks/20261014072555_food_support_cases_rollback.sql"
eq "$A" "select has_function_privilege('authenticated','public.food_support_case_detail(uuid)','EXECUTE')" f 'rollback disables API'
eq "$EDIT" "select count(*) from public.food_support_events where case_id='$CASE'" 7 'rollback preserves audit'
run >/dev/null < "$MIGRATION"
eq "$A" "select public.food_support_case_detail('$CASE')->>'status'" resolved 'reapply restores preserved case'
run -c "delete from public.profiles where id in ('$A','$EDIT')" >/dev/null
eq "$B" "select buyer_id is null and assigned_to is null from public.food_support_cases where id='$CASE'" t 'account deletion anonymizes case'
eq "$B" "select count(*) from public.food_support_messages where case_id='$CASE' and actor_id is not null" 0 'account deletion anonymizes conversation actors'
eq "$B" "select count(*) from public.food_support_events where case_id='$CASE' and actor_id is not null" 0 'account deletion anonymizes audit actors'
fail "$B" "select public.food_support_case_detail('$CASE')" 'deleted buyer case inaccessible' 'Not authorized'
echo "PASS Food support: $CHECKS integration assertions"
