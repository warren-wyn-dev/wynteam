#!/usr/bin/env bash
# Merchant operations: authenticated permission, validation, concurrency and audit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_merchant_operations_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth;
create schema internal;
create function auth.uid() returns uuid language sql stable as
 $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key,level text);
create function internal.has_admin_permission(p_system text,p_level text)
 returns boolean language sql stable as
 $$ select p_system='merchant' and exists(
  select 1 from public.admin_permissions a
  where a.user_id=auth.uid() and (a.level='edit' or p_level='view')
 ) $$;
create table public.food_stores (
 id uuid primary key,name text not null,is_published boolean default true,admin_suspended_at timestamptz,
 is_open boolean not null default false,temporary_closed_until timestamptz,temporary_closed_reason text,
 prep_time_min_minutes integer not null default 15,
 prep_time_max_minutes integer not null default 30,
 check(prep_time_min_minutes between 1 and 240 and prep_time_max_minutes between prep_time_min_minutes and 240)
);
create table public.audit_log(actor_id uuid,event_type text,target_id uuid,detail jsonb);
create function internal.log_audit_event(p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb)
 returns void language sql as
 $$ insert into public.audit_log(actor_id,event_type,target_id,detail)
 values(p_actor_id,p_event_type,p_target_id,p_detail) $$;
insert into public.admin_permissions values
 ('00000000-0000-0000-0000-0000000000a1','view'),
 ('00000000-0000-0000-0000-0000000000a2','edit');
insert into public.food_stores(id,name,is_open) values
 ('00000000-0000-0000-0000-0000000000b1','Test Store',true);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013163000_admin_merchant_store_operations.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013163000_admin_merchant_store_operations.sql"
expect_eq(){
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 actual=$got expected=$3";exit 1; }
}
expect_fail(){
 local output
 if output="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)";then
 echo "FAIL $3 expected error";exit 1;fi
 [[ "$output" == *"$4"* ]] || { echo "FAIL $3 got=$output";exit 1; }
}
VIEW=00000000-0000-0000-0000-0000000000a1
EDIT=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
STORE=00000000-0000-0000-0000-0000000000b1
OLD='{"is_open":true,"temporary_closed_until":null,"temporary_closed_reason":null,"prep_time_min_minutes":15,"prep_time_max_minutes":30}'
SAVE="select public.admin_update_merchant_store_operations('$STORE','$OLD'::jsonb,false,null,null,20,40,'owner approved pause')"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_merchant_store_operations())" 1 "viewer read"
expect_fail "$NONE" "select public.admin_merchant_store_operations()" "outsider read" "Not authorized"
expect_fail "$VIEW" "$SAVE" "view-only write" "Not authorized"
expect_fail "$EDIT" "select public.admin_update_merchant_store_operations('$STORE','$OLD'::jsonb,false,null,null,250,40,'owner approved pause')" "invalid prep time" "Invalid preparation"
expect_fail "$EDIT" "select public.admin_update_merchant_store_operations('$STORE','$OLD'::jsonb,false,null,'bad reason',20,40,'owner approved pause')" "orphan reason" "Clear temporary"
expect_fail "$EDIT" "select public.admin_update_merchant_store_operations('$STORE','$OLD'::jsonb,false,null,null,20,40,'no')" "audit reason" "Admin change reason"
expect_eq "$EDIT" "select (public.admin_update_merchant_store_operations('$STORE','$OLD'::jsonb,false,null,null,20,40,'owner approved pause')->>'is_open')::boolean" f "pause store"
expect_eq "$EDIT" "select is_open::text||'|'||prep_time_min_minutes||'|'||prep_time_max_minutes from public.food_stores where id='$STORE'" "false|20|40" "persisted fields"
expect_fail "$EDIT" "$SAVE" "stale write" "Store availability changed"
expect_eq "$EDIT" "select count(*) from public.audit_log where event_type='merchant_store_updated' and detail->>'admin_availability_override'='true'" 1 "audited admin override"
expect_eq "$EDIT" "select count(*) from public.audit_log where detail->'before'->>'is_open'='true' and detail->'after'->>'is_open'='false'" 1 "before after"
expect_eq "$NONE" "select has_function_privilege('anon','public.admin_update_merchant_store_operations(uuid,jsonb,boolean,timestamptz,text,integer,integer,text)','EXECUTE')" f "anon not callable"
echo "PASS Merchant operational controls and audit"
