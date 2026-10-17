#!/usr/bin/env bash
# Synthetic real-Postgres authorization, attribution, retry, concurrency and bounds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="food_home_analytics_test_$$"
$PSQL -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run(){ $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key,level text);
create function internal.has_admin_permission(p_system text,p_level text) returns boolean language sql stable security definer as $$
select p_system='food' and exists(select 1 from public.admin_permissions p
where p.user_id=auth.uid() and (p.level='edit' or p_level='view')) $$;
create table public.food_stores(id uuid primary key,name text,is_published boolean,admin_suspended_at timestamptz);
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;
insert into auth.users values('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_permissions values('00000000-0000-0000-0000-0000000000a1','view');
insert into public.food_stores values
('00000000-0000-0000-0000-0000000000b1','Synthetic published',true,null),
('00000000-0000-0000-0000-0000000000b2','Synthetic suspended',true,now()),
('00000000-0000-0000-0000-0000000000b3','Synthetic draft',false,null);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013190000_admin_food_banners_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013194500_admin_food_featured_stores_v1.sql"
MIGRATION="$ROOT/supabase/migrations/20261014023345_food_home_placement_analytics_v1.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"
run >/dev/null <<'SQL'
insert into public.food_home_banners(id,title,image_path,destination_store_id,is_active,starts_at,ends_at) values
('00000000-0000-0000-0000-0000000000d1','Live banner','banners/00000000-0000-0000-0000-0000000000c1.png','00000000-0000-0000-0000-0000000000b1',true,now()-interval '1h',null),
('00000000-0000-0000-0000-0000000000d2','Info banner','banners/00000000-0000-0000-0000-0000000000c1.png',null,true,now()-interval '1h',null),
('00000000-0000-0000-0000-0000000000d3','Paused banner','banners/00000000-0000-0000-0000-0000000000c1.png',null,false,now()-interval '1h',null),
('00000000-0000-0000-0000-0000000000d4','Future banner','banners/00000000-0000-0000-0000-0000000000c1.png',null,true,now()+interval '1h',null),
('00000000-0000-0000-0000-0000000000d5','Expired banner','banners/00000000-0000-0000-0000-0000000000c1.png',null,true,now()-interval '2h',now()-interval '1h'),
('00000000-0000-0000-0000-0000000000d6','Suspended banner','banners/00000000-0000-0000-0000-0000000000c1.png','00000000-0000-0000-0000-0000000000b2',true,now()-interval '1h',null);
insert into public.food_featured_stores(store_id,active,starts_at) values
('00000000-0000-0000-0000-0000000000b1',true,now()-interval '1h'),
('00000000-0000-0000-0000-0000000000b2',true,now()-interval '1h'),
('00000000-0000-0000-0000-0000000000b3',true,now()-interval '1h');
SQL
VIEW=00000000-0000-0000-0000-0000000000a1
BANNER=00000000-0000-0000-0000-0000000000d1
STORE=00000000-0000-0000-0000-0000000000b1
EXPOSURE=00000000-0000-0000-0000-0000000000e1
eq(){
 local got;got="$(run -At -c "$1" | tail -n1)"
 [[ "$got" == "$2" ]] || { echo "FAIL $3 (got=$got expected=$2)";exit 1; }
}
fail(){
 local out
 if out="$(run -At -c "$1" 2>&1)";then echo "FAIL $2 expected rejection";exit 1;fi
 [[ "$out" == *"$3"* ]] || { echo "FAIL $2 unexpected error $out";exit 1; }
}
record(){ echo "select public.food_record_home_placement_event('$1','$2','$3','$4')"; }
eq "set role authenticated;select set_config('test.uid','$VIEW',false);select public.admin_food_home_placement_analytics('banner',30)->>'impressions'" 0 'genuine zero events'
fail "set role anon;select public.admin_food_home_placement_analytics('banner',30)" 'anon admin read' 'permission denied'
fail "set role authenticated;select public.admin_food_home_placement_analytics('banner',30)" 'non-admin read' 'Not authorized'
for table in food_home_placement_receipts food_home_placement_daily food_home_analytics_budget;do
 for role in anon authenticated;do
  fail "set role $role;select * from internal.$table" "$role raw read $table" 'permission denied'
  fail "set role $role;delete from internal.$table" "$role raw delete $table" 'permission denied'
  fail "set role $role;update internal.$table set made_up_column=1" "$role raw update $table" 'permission denied'
 done
done
fail "set role anon;insert into internal.food_home_placement_receipts(exposure_id,placement_kind,placement_id) values(gen_random_uuid(),'banner','$BANNER')" 'anon raw insert' 'permission denied'
eq "set role anon;$(record banner "$BANNER" "$EXPOSURE" impression)->>'recorded'" true 'guest impression'
eq "set role anon;$(record banner "$BANNER" "$EXPOSURE" impression)->>'reason'" duplicate 'retry impression dedupe'
eq "set role anon;$(record banner "$BANNER" "$EXPOSURE" click)->>'recorded'" true 'attributed click'
eq "set role anon;$(record banner "$BANNER" "$EXPOSURE" click)->>'reason'" duplicate 'retry click dedupe'
eq "$(record featured "$STORE" "$EXPOSURE" impression)->>'reason'" invalid 'cross-placement receipt misuse'
eq "$(record banner "$BANNER" '00000000-0000-0000-0000-0000000000e2' click)->>'reason'" missing_impression 'click requires exposure'
eq "$(record banner '00000000-0000-0000-0000-0000000000d2' '00000000-0000-0000-0000-0000000000e2' click)->>'reason'" invalid 'informational banner cannot click'
for id in d3 d4 d5 d6;do
 eq "$(record banner "00000000-0000-0000-0000-0000000000$id" '00000000-0000-0000-0000-0000000000e2' impression)->>'reason'" invalid "ineligible banner $id"
done
for id in b2 b3;do
 eq "$(record featured "00000000-0000-0000-0000-0000000000$id" '00000000-0000-0000-0000-0000000000e2' impression)->>'reason'" invalid "ineligible featured $id"
done
eq "select public.food_record_home_placement_event(null,null,null,null)->>'reason'" invalid 'null event rejected'
eq "select public.food_record_home_placement_event('banner','$BANNER',gen_random_uuid(),'purchase')->>'reason'" invalid 'event allowlist'
eq "set role authenticated;select set_config('test.uid','$VIEW',false);select public.admin_food_home_placement_analytics('banner',30)->>'ctr_pct'" 100.00 'same counters and CTR'
fail "select set_config('test.uid','$VIEW',false);select public.admin_food_home_placement_analytics('banner',365)" 'bounded range' 'Invalid analytics range'
# Concurrent duplicate retries must add exactly one aggregate impression.
run -c "begin;select pg_advisory_xact_lock(1142,1);select pg_sleep(2);commit" >/dev/null &
lock_pid=$!
for _ in $(seq 1 100);do
 if [[ "$(run -At -c "select exists(select 1 from pg_locks where locktype='advisory' and classid=1142 and objid=1 and granted)")" == t ]];then break;fi
 sleep 0.02
done
eq "set role anon;set statement_timeout='500ms';$(record featured "$STORE" '00000000-0000-0000-0000-0000000000e3' impression)->>'reason'" limited 'contended telemetry drops without queuing'
wait "$lock_pid"
for _ in 1 2 3 4;do run -c "set role anon;$(record featured "$STORE" '00000000-0000-0000-0000-0000000000e3' impression)" >/dev/null & done
wait
eq "select impressions from internal.food_home_placement_daily where placement_kind='featured' and placement_id='$STORE'" 1 'concurrent dedupe'
# A click after midnight belongs to the impression's UTC day, not today's views.
run -c "update internal.food_home_placement_receipts set created_at=(((now() at time zone 'UTC')::date-1)+interval '23h59m') at time zone 'UTC' where exposure_id='00000000-0000-0000-0000-0000000000e3';update internal.food_home_placement_daily set day=(now() at time zone 'UTC')::date-1 where placement_kind='featured'" >/dev/null
eq "$(record featured "$STORE" '00000000-0000-0000-0000-0000000000e3' click)->>'recorded'" true 'midnight attributed click'
eq "select clicks from internal.food_home_placement_daily where placement_kind='featured' and day=(now() at time zone 'UTC')::date-1" 1 'click attributed to impression day'
# Replay/volume guard uses a bounded singleton, not personal identifiers.
run -c "update internal.food_home_analytics_budget set used=3000,window_started_at=date_trunc('minute',clock_timestamp())" >/dev/null
eq "$(record banner "$BANNER" '00000000-0000-0000-0000-0000000000e4' impression)->>'reason'" limited 'minute budget'
run -c "update internal.food_home_analytics_budget set used=0,retained_receipts=200000" >/dev/null
eq "$(record banner "$BANNER" '00000000-0000-0000-0000-0000000000e4' impression)->>'reason'" limited 'hard receipt bound'
# Expired receipts/aggregates are pruned in bounded ingestion maintenance.
run -c "update internal.food_home_analytics_budget set retained_receipts=2,maintained_at=now()-interval '2min';update internal.food_home_placement_receipts set created_at=now()-interval '3days';insert into internal.food_home_placement_daily values(current_date-100,'banner',gen_random_uuid(),1,0)" >/dev/null
eq "$(record banner "$BANNER" '00000000-0000-0000-0000-0000000000e4' impression)->>'recorded'" true 'maintenance makes room'
eq "select count(*) from internal.food_home_placement_receipts where created_at<now()-interval '48h'" 0 'receipt expiry'
eq "select count(*) from internal.food_home_placement_daily where day<current_date-89" 0 'aggregate expiry'
eq "select count(*) from information_schema.columns where table_schema='internal' and table_name like 'food_home_%' and column_name in ('user_id','ip','latitude','longitude','session_id','email')" 0 'no personal telemetry fields'
run >/dev/null < "$ROOT/supabase/rollbacks/20261014023345_food_home_placement_analytics_v1_rollback.sql"
eq "select count(*) from internal.food_home_placement_receipts" 1 'rollback preserves data'
run >/dev/null < "$MIGRATION"
eq "select count(*) from internal.food_home_placement_receipts" 1 'reapply preserves data'
echo 'PASS Food home analytics: roles, eligible placement, dedupe, concurrency, caps, retention and rollback'
