#!/usr/bin/env bash
# Admin delivery: permissions, stale-write protection, live settings and audit.
# Runs in a throwaway PostgreSQL database. Never touches production.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_delivery_live_test_$$"
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
create table public.food_stores(
 id uuid primary key, name text, is_published boolean default true, latitude double precision, longitude double precision,
 delivery_fee numeric not null default 0 check(delivery_fee>=0),
 delivery_radius_km numeric not null default 5 check(delivery_radius_km > 0 and delivery_radius_km<=50),
 delivery_base_km numeric not null default 2 check(delivery_base_km>=0 and delivery_base_km<=50),
 delivery_fee_per_km numeric not null default 0 check(delivery_fee_per_km>=0 and delivery_fee_per_km<=1000)
);
create table public.audit_log(actor_id uuid, event_type text, target_id uuid, detail jsonb);
create function internal.log_audit_event(p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb)
 returns void language sql as $$
 insert into public.audit_log(actor_id,event_type,target_id,detail) values (p_actor_id,p_event_type,p_target_id,p_detail)
$$;
insert into public.admin_permissions values
 ('00000000-0000-0000-0000-0000000000a1','view'),
 ('00000000-0000-0000-0000-0000000000a2','edit');
insert into public.food_stores(id,name,latitude,longitude,delivery_fee,delivery_radius_km,delivery_base_km,delivery_fee_per_km)
 values ('00000000-0000-0000-0000-0000000000b1','Test Store',13.7,100.5,10,5,2,8);
SQL

run >/dev/null < "$ROOT/supabase/migrations/20261013161500_admin_merchant_delivery_live.sql"
# Idempotency.
run >/dev/null < "$ROOT/supabase/migrations/20261013161500_admin_merchant_delivery_live.sql"

expect_eq() {
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 got=$got expected=$3"; exit 1; }
}
expect_fail() {
 local output
 if output="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
   echo "FAIL expected exception $3"; exit 1
 fi
 [[ "$output" == *"$4"* ]] || { echo "FAIL $3 wrong error $output"; exit 1; }
}
VIEW=00000000-0000-0000-0000-0000000000a1
EDIT=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
STORE=00000000-0000-0000-0000-0000000000b1
OLD='{"delivery_fee":10,"delivery_radius_km":5,"delivery_base_km":2,"delivery_fee_per_km":8}'
NEW='{"delivery_fee":12,"delivery_radius_km":7,"delivery_base_km":2,"delivery_fee_per_km":9}'
UPDATE="select public.admin_update_merchant_delivery('$STORE','$OLD'::jsonb,12,7,2,9,'approved delivery change')"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_merchant_delivery_stores())" "1" "merchant view lists stores"
expect_fail "$NONE" "select public.admin_merchant_delivery_stores()" "outsider denied list" "Not authorized"
expect_fail "$VIEW" "$UPDATE" "merchant:view cannot edit" "Not authorized"
expect_fail "$EDIT" "select public.admin_update_merchant_delivery('$STORE','$OLD'::jsonb,12,-2,2,9,'approved delivery change')" "invalid radius" "out of range"
expect_fail "$EDIT" "select public.admin_update_merchant_delivery('$STORE','$OLD'::jsonb,12,7,2,9,'x')" "reason required" "reason"
expect_eq "$EDIT" "select (public.admin_update_merchant_delivery('$STORE','$OLD'::jsonb,12,7,2,9,'approved delivery change')->>'delivery_fee')::numeric" "12" "live store update"
expect_eq "$EDIT" "select delivery_radius_km||'|'||delivery_fee_per_km from public.food_stores where id='$STORE'" "7|9" "real store values updated"
expect_fail "$EDIT" "$UPDATE" "optimistic version check" "settings changed"
expect_eq "$EDIT" "select count(*) from audit_log where event_type='merchant_store_updated' and detail->>'reason'='approved delivery change'" "1" "one audited modification"
expect_eq "$EDIT" "select count(*) from audit_log where detail->'before'->>'delivery_fee'='10' and detail->'after'->>'delivery_fee'='12'" "1" "before and after captured"
expect_fail "$NONE" "select public.admin_update_merchant_delivery('$STORE','$NEW'::jsonb,13,7,2,9,'no permission change')" "outsider cannot edit" "Not authorized"
expect_eq "$EDIT" "select has_function_privilege('anon','public.admin_update_merchant_delivery(uuid,jsonb,numeric,numeric,numeric,numeric,text)','EXECUTE')" "f" "anonymous no execute"
echo "PASS Admin Merchant delivery - permission, validation, stale-write guard, audit, real update"
