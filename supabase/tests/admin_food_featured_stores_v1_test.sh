#!/usr/bin/env bash
# Food featured stores: RBAC, scheduled public list, optimistic version and audit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_food_featured_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key,level text);
create function internal.has_admin_permission(p_system text,p_level text)
returns boolean language sql stable security definer as $$
 select p_system='food' and exists(
 select 1 from public.admin_permissions p
 where p.user_id=auth.uid() and (p.level='edit' or p_level='view'))
$$;
create table public.food_stores(
 id uuid primary key,name text not null,
 is_published boolean not null default true,
 admin_suspended_at timestamptz
);
insert into auth.users values
('00000000-0000-0000-0000-0000000000a1'),
('00000000-0000-0000-0000-0000000000a2');
insert into public.admin_permissions values
('00000000-0000-0000-0000-0000000000a1','edit'),
('00000000-0000-0000-0000-0000000000a2','view');
insert into public.food_stores values
('00000000-0000-0000-0000-0000000000b1','Test Restaurant',true,null);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013194500_admin_food_featured_stores_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013194500_admin_food_featured_stores_v1.sql"
expect_eq() {
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 (got=$got expected=$3)"; exit 1; }
}
expect_fail() {
 local out
 if out="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
   echo "FAIL expected exception $3"; exit 1
 fi
 [[ "$out" == *"$4"* ]] || { echo "FAIL $3 unexpected error $out"; exit 1; }
}
EDIT=00000000-0000-0000-0000-0000000000a1
VIEW=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
STORE=00000000-0000-0000-0000-0000000000b1
expect_eq "$NONE" "select jsonb_array_length(public.food_active_featured_stores())" 0 "no recommended stores by default"
expect_eq "$EDIT" "select jsonb_array_length(public.admin_food_featured_stores())" 0 "admin initially empty"
expect_fail "$NONE" "select public.admin_food_featured_stores()" "unauthorized list" "Not authorized"
expect_fail "$VIEW" "select public.admin_save_food_featured_store('$STORE',null,1,true,now()-interval '1 day',null,'owner approved')" "viewer blocked" "Not authorized"
expect_fail "$EDIT" "select public.admin_save_food_featured_store('$STORE',null,0,true,now(),null,'owner approved')" "invalid priority" "Invalid featured"
expect_fail "$EDIT" "select public.admin_save_food_featured_store('$STORE',null,1,true,now(),null,'x')" "reason required" "Reason"
expect_eq "$EDIT" "select (public.admin_save_food_featured_store('$STORE',null,1,true,now()-interval '1 day',null,'owner approved')->>'version')::integer" 1 "create priority placement"
expect_eq "$NONE" "select jsonb_array_length(public.food_active_featured_stores())" 1 "visible restaurant"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_food_featured_stores())" 1 "view can list"
expect_fail "$EDIT" "select public.admin_save_food_featured_store('$STORE',null,2,true,now(),null,'owner approved')" "stale insert" "Featured placement changed"
expect_fail "$EDIT" "select public.admin_save_food_featured_store('$STORE',2,2,false,now(),null,'owner approved')" "stale version" "Featured placement changed"
expect_eq "$EDIT" "select (public.admin_save_food_featured_store('$STORE',1,2,false,now(),null,'owner requested pause')->>'version')::integer" 2 "version bump"
expect_eq "$NONE" "select jsonb_array_length(public.food_active_featured_stores())" 0 "paused restaurant hidden"
expect_eq "$EDIT" "select count(*) from public.food_featured_store_edits where store_id='$STORE'" 2 "two audit entries"
expect_eq "$EDIT" "select has_function_privilege('anon','public.admin_save_food_featured_store(uuid,integer,integer,boolean,timestamptz,timestamptz,text)','EXECUTE')" f "anon cannot write"
echo "PASS Food featured stores: permission, schedule, stale edits, history"
