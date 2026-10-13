#!/usr/bin/env bash
# Admin Merchant menu editing: authorization, stale write and before/after audit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_merchant_menu_live_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key, level text);
create function internal.has_admin_permission(p_system text,p_level text) returns boolean language sql stable as $$
 select p_system = 'merchant' and exists (
 select 1 from public.admin_permissions a where a.user_id = auth.uid() and (a.level='edit' or p_level='view'))
$$;
create table public.food_stores(id uuid primary key,name text not null);
create table public.food_menu_items(
 id uuid primary key,store_id uuid references food_stores(id),
 name text not null,category text not null,description text,price numeric(10,2) not null,
 is_available boolean not null, daily_stock_limit integer, sold_out_until timestamptz,
 sort_order integer default 0, updated_at timestamptz default now()
);
create table public.audit_log(actor_id uuid,event_type text,target_id uuid,detail jsonb);
create function internal.log_audit_event(p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb)
 returns void language sql as $$
 insert into public.audit_log(actor_id,event_type,target_id,detail) values(p_actor_id,p_event_type,p_target_id,p_detail)
$$;
insert into public.admin_permissions values
('00000000-0000-0000-0000-0000000000a1','view'),
('00000000-0000-0000-0000-0000000000a2','edit');
insert into public.food_stores values('00000000-0000-0000-0000-0000000000b1','Test Shop');
insert into public.food_menu_items(id,store_id,name,category,description,price,is_available,daily_stock_limit)
values('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1',
 'Rice','Main',null,55,true,null);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013183000_admin_merchant_menu_live.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013183000_admin_merchant_menu_live.sql"
expect_eq() {
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 got=$got expected=$3"; exit 1; }
}
expect_fail(){
 local out
 if out="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
  echo "FAIL expected exception $3"; exit 1
 fi
 [[ "$out" == *"$4"* ]] || { echo "FAIL $3 error=$out";exit 1; }
}
VIEW=00000000-0000-0000-0000-0000000000a1
EDIT=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
ITEM=00000000-0000-0000-0000-0000000000c1
OLD='{"name":"Rice","category":"Main","description":null,"price":55,"is_available":true,"daily_stock_limit":null}'
CHANGE="select public.admin_update_merchant_menu_item('$ITEM','$OLD'::jsonb,'Rice Bowl','Main','Fresh',59,false,20,'owner approved')"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_merchant_menu_items(null))" "1" "merchant view lists menu"
expect_fail "$NONE" "select public.admin_merchant_menu_items(null)" "outsider denied list" "Not authorized"
expect_fail "$VIEW" "$CHANGE" "view denied update" "Not authorized"
expect_fail "$EDIT" "select public.admin_update_merchant_menu_item('$ITEM','$OLD'::jsonb,'Rice Bowl','Main','Fresh',-1,false,20,'owner approved')" "negative price denied" "Invalid menu"
expect_fail "$EDIT" "select public.admin_update_merchant_menu_item('$ITEM','$OLD'::jsonb,'Rice Bowl','Main','Fresh',59,false,20,'x')" "reason required" "reason"
expect_eq "$EDIT" "select (public.admin_update_merchant_menu_item('$ITEM','$OLD'::jsonb,'Rice Bowl','Main','Fresh',59,false,20,'owner approved')->>'price')::numeric" "59" "updates price"
expect_eq "$EDIT" "select name||'|'||price||'|'||is_available||'|'||daily_stock_limit from public.food_menu_items where id='$ITEM'" "Rice Bowl|59.00|false|20" "real menu updated"
expect_fail "$EDIT" "$CHANGE" "stale edit denied" "Menu item changed"
expect_eq "$EDIT" "select count(*) from audit_log where event_type='merchant_menu_updated' and detail->>'admin_menu_override'='true'" "1" "one audit"
expect_eq "$EDIT" "select count(*) from audit_log where detail->'before'->>'price'='55' and detail->'after'->>'price'='59'" "1" "price history"
expect_fail "$NONE" "$CHANGE" "outsider denied update" "Not authorized"
expect_eq "$EDIT" "select has_function_privilege('anon','public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text)','EXECUTE')" "f" "anon no execute"
echo "PASS Admin Merchant menu read/write, permission, price, stale conflicts, audit"
