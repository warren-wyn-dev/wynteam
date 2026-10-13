#!/usr/bin/env bash
# Throwaway database only. Use a local wrapper or CI's ephemeral PostgreSQL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_checkout_test_$$"
$PSQL -X -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB"
trap '$PSQL -X -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
q() { run -At -c "$1" | tail -1; }
eq() { [[ "$1" == "$2" ]] || { echo "FAIL $3: got $1 expected $2"; exit 1; }; echo "ok - $3"; }
fails() { local result; if result=$(run -c "$1" 2>&1); then echo "FAIL expected error: $2"; exit 1; fi
  [[ "$result" == *"$2"* ]] || { echo "FAIL wrong error: $result"; exit 1; }; echo "ok - $2"; }
DEV=00000000-0000-0000-0000-000000000001
BUYER=00000000-0000-0000-0000-000000000002
STORE=00000000-0000-0000-0000-000000000003
KEY=00000000-0000-4000-8000-000000000004
AUTH="set role authenticated; set test.uid='$DEV';"
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create function public.is_developer_account() returns boolean language sql stable as $$ select auth.uid()='00000000-0000-0000-0000-000000000001'::uuid $$;
create function public.food_is_permanent_account() returns boolean language sql stable as $$ select auth.uid() is not null $$;
create table public.food_orders(id uuid primary key default gen_random_uuid(),buyer_id uuid,store_id uuid,
  subtotal numeric(10,2), total numeric(10,2),created_at timestamptz default now());
create table public.food_order_events(order_id uuid,event_type text,note text,actor_id uuid);
create table public.fixture_menu(price numeric,available boolean);
insert into public.fixture_menu values(59.99,true);
-- Legacy boundary stub. Real legacy RPC tests are run separately. Client
-- amounts are ignored; price comes from the menu row, discount/delivery are
-- deterministic fixtures to exercise the new wrapper's calculation base.
create function public.food_quote_order_v2(uuid,jsonb,double precision,double precision,text)
returns jsonb language sql security definer set search_path='' as $$
  select jsonb_build_object('subtotal',m.price,'total',m.price-10+20,'campaign_discount',10,'delivery_fee',20)
  from public.fixture_menu m $$;
create function public.food_create_order_v2(p_store uuid,p_name text,p_phone text,p_address text,p_note text,p_items jsonb,
  p_lat double precision,p_lng double precision,p_coupon text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid; price numeric; available boolean;
begin
  select m.price,m.available into price,available from public.fixture_menu m for update;
  if not available then raise exception 'menu item is unavailable'; end if;
  insert into public.food_orders(buyer_id,store_id,subtotal,total) values(auth.uid(),p_store,price,price-10+20) returning id into result;
  return result;
end $$;
grant usage on schema auth,internal to authenticated,anon;
SQL
run -f "$ROOT/supabase/migrations/20261013045900_food_checkout_integrity.sql" >/dev/null
run -f "$ROOT/supabase/migrations/20261013045900_food_checkout_integrity.sql" >/dev/null
echo 'ok - additive migration applies twice'
fails "$AUTH select public.food_quote_order_v3('$STORE','[]');" 'food_feature_disabled'
run -c "update public.food_development_features set enabled=true" >/dev/null
fails "set role authenticated; set test.uid='$BUYER'; select public.food_quote_order_v3('$STORE','[]');" 'food_feature_disabled'
fails "set role anon; select public.food_checkout_features();" 'permission denied'
eq "$(q "$AUTH select (public.food_quote_order_v3('$STORE','[]')->>'small_order_fee');")" '15' 'fee on food subtotal 59.99'
eq "$(q "$AUTH select (public.food_quote_order_v3('$STORE','[]')->>'total');")" '84.99' 'fee not reduced by discount or based on delivery'
run -c 'update public.fixture_menu set price=60' >/dev/null
eq "$(q "$AUTH select (public.food_quote_order_v3('$STORE','[]')->>'small_order_fee');")" '0' '60 boundary no fee'
run -c 'update public.fixture_menu set price=100' >/dev/null
eq "$(q "$AUTH select (public.food_quote_order_v3('$STORE','[]')->>'small_order_fee');")" '0' '100 food remains no fee after discount'
run -c 'update public.fixture_menu set price=59.99' >/dev/null
CREATE="select public.food_create_order_v3('$STORE','Name','0800000000','Address','', '[{\"client_total\":1}]','$KEY',null,null,null,84.99);"
ID="$(q "$AUTH $CREATE")"
eq "$(q "$AUTH $CREATE")" "$ID" 'retry returns same order'
eq "$(q "$AUTH select public.food_resolve_checkout_request('$KEY')")" "$ID" 'lookup recovers committed intent'
eq "$(q "set role authenticated; set test.uid='$BUYER'; select public.food_resolve_checkout_request('$KEY') is null")" 't' 'lookup isolates same key from another buyer'
eq "$(q "$AUTH select public.food_resolve_checkout_request(gen_random_uuid()) is null")" 't' 'lookup of unused intent is empty'
run -c "update public.food_development_features set enabled=false where name='checkout_v3'" >/dev/null
eq "$(q "$AUTH select public.food_resolve_checkout_request('$KEY')")" "$ID" 'known intent resolves after feature disabled'
run -c "update public.food_development_features set enabled=true where name='checkout_v3'" >/dev/null
eq "$(q 'select count(*) from public.food_orders')" '1' 'no duplicated order'
eq "$(q "select small_order_fee||':'||total from public.food_orders where id='$ID'")" '15.00:84.99' 'final server snapshot includes fee at insert'
fails "$AUTH select public.food_create_order_v3('$STORE','Changed','0800000000','Address','','[]','$KEY');" 'idempotency_key_conflict'
fails "$AUTH select public.food_create_order_v3('$STORE','Name','0800000000','Address','','[]',null);" 'idempotency_key_required'
fails "$AUTH select public.food_create_order_v3('$STORE','Name','0800000000','Address','','[]',gen_random_uuid(),null,null,null,1);" 'food_quote_changed'
eq "$(q 'select count(*) from public.food_orders')" '1' 'quote mismatch rolls back created order'
fails "$AUTH select * from public.food_checkout_requests;" 'permission denied'
eq "$(q "select public.food_create_order_v2('$STORE','N','P','A','','[]',null,null,null) is not null")" 't' 'legacy create stays usable'
eq "$(q "select small_order_fee from public.food_orders where id<>'$ID'")" '0.00' 'v3 context does not leak to legacy orders'
run -c 'update public.fixture_menu set available=false' >/dev/null
fails "$AUTH select public.food_create_order_v3('$STORE','N','P','A','','[]',gen_random_uuid());" 'menu item is unavailable'
run -c 'update public.fixture_menu set available=true' >/dev/null
KEY2=00000000-0000-4000-8000-000000000005
CONCURRENT="select public.food_create_order_v3('$STORE','N','P','A','','[]','$KEY2');"
run -At -c "$AUTH begin; $CONCURRENT select pg_sleep(0.2); commit;" > /tmp/wyn-checkout-a-$$ &
FIRST=$!
run -At -c "$AUTH $CONCURRENT" > /tmp/wyn-checkout-b-$$ &
SECOND=$!
wait "$FIRST" "$SECOND"
eq "$(q "select count(*) from public.food_checkout_requests where idempotency_key='$KEY2'")" '1' 'concurrent same intent committed once'
rm -f /tmp/wyn-checkout-a-$$ /tmp/wyn-checkout-b-$$
run -f "$ROOT/supabase/migrations/20261013045901_food_option_minimum.sql" >/dev/null
OPTION_GROUPS='[{"id":"t","required":false,"max_select":3,"min_select":2,"choices":[{"id":"a","name":"A","price":10},{"id":"b","name":"B","price":20}]}]'
PICKS='[{"group_id":"t","choice_id":"a"},{"group_id":"t","choice_id":"b"}]'
eq "$(q "select surcharge from internal.food_resolve_menu_options('$OPTION_GROUPS','$PICKS')")" '30.00' 'minimum resolver prices actual choices'
fails "select * from internal.food_resolve_menu_options('$OPTION_GROUPS','[{\"group_id\":\"t\",\"choice_id\":\"a\"}]');" 'required menu option missing'
fails "select * from internal.food_resolve_menu_options('[{\"id\":\"t\",\"min_select\":3,\"max_select\":2,\"choices\":[]}]','[]');" 'invalid menu option limits'
echo 'PASS food checkout/minimum integrity (local boundary fixtures)'
