#!/usr/bin/env bash
# Food homepage banner permissions, schedule, audit, version and media checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_food_banner_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key, level text);
create function internal.has_admin_permission(p_system text,p_level text) returns boolean language sql stable security definer as $$
  select p_system='food' and exists (
    select 1 from public.admin_permissions a
    where a.user_id=auth.uid() and (a.level='edit' or p_level='view')
  ) $$;
create table public.food_stores(id uuid primary key,name text,is_published boolean,admin_suspended_at timestamptz);
create table storage.buckets(
  id text primary key,name text not null,public boolean not null,
  file_size_limit bigint,allowed_mime_types text[]
);
create table storage.objects(
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,name text not null
);
alter table storage.objects enable row level security;
create unique index on storage.objects(bucket_id,name);
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2');
insert into public.admin_permissions values
('00000000-0000-0000-0000-0000000000a1','edit'),
('00000000-0000-0000-0000-0000000000a2','view');
insert into public.food_stores values
('00000000-0000-0000-0000-0000000000b1','Test Restaurant',true,null);
insert into storage.buckets values
('other','other',true,null,null);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013190000_admin_food_banners_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013190000_admin_food_banners_v1.sql"
expect_eq(){
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 (got $got expected $3)"; exit 1; }
}
expect_fail(){
 local got
 if got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
  echo "FAIL $3 expected error";exit 1
 fi
 [[ "$got" == *"$4"* ]] || { echo "FAIL $3 unexpected error $got";exit 1; }
}
EDIT=00000000-0000-0000-0000-0000000000a1
VIEW=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
STORE=00000000-0000-0000-0000-0000000000b1
IMAGE='banners/00000000-0000-0000-0000-0000000000c1.png'
expect_eq "$EDIT" "select jsonb_array_length(public.admin_food_home_banners())" 0 "no banner initially"
expect_eq "$NONE" "select jsonb_array_length(public.food_active_home_banners())" 0 "public has no active banners"
expect_fail "$NONE" "select public.admin_food_home_banners()" "outsider list" "Not authorized"
expect_fail "$VIEW" "select public.admin_save_food_home_banner(null,null,'My Offer',null,'$IMAGE',null,1,now()-interval '1 hour',null,true,'approved banner')" "view-only write" "Not authorized"
run -c "insert into storage.objects(bucket_id,name) values ('food-banners','$IMAGE')" >/dev/null
SAVE="select public.admin_save_food_home_banner(null,null,'My Offer','Food Deals','$IMAGE','$STORE',10,now()-interval '1 hour',now()+interval '1 day',true,'approved banner')"
expect_fail "$EDIT" "select public.admin_save_food_home_banner(null,null,'My Offer',null,'banners/invalid.png',null,1,now(),null,false,'approved banner')" "invalid media" "Invalid banner"
expect_eq "$EDIT" "select ($SAVE)->>'title'" "My Offer" "admin creates banner"
expect_eq "$NONE" "select jsonb_array_length(public.food_active_home_banners())" 1 "live banner shown"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_food_home_banners())" 1 "view sees banners"
expect_eq "$EDIT" "select count(*) from public.food_home_banner_edits where before_state is null" 1 "audit insert"
ID="$(run -At -c "select id from public.food_home_banners limit 1" | tail -n1)"
expect_fail "$EDIT" "select public.admin_save_food_home_banner('$ID',99,'Updated Offer',null,'$IMAGE',null,9,now(),null,true,'approved banner')" "stale edit" "Banner changed"
expect_eq "$EDIT" "select (public.admin_save_food_home_banner('$ID',1,'Updated Offer',null,'$IMAGE',null,9,now(),null,false,'approved pause')->>'version')::integer" 2 "version advanced"
expect_eq "$NONE" "select jsonb_array_length(public.food_active_home_banners())" 0 "paused banner hidden"
expect_eq "$EDIT" "select count(*) from public.food_home_banner_edits where banner_id='$ID'" 2 "audit edit"
expect_eq "$NONE" "select has_function_privilege('anon','public.admin_save_food_home_banner(uuid,integer,text,text,text,uuid,integer,timestamptz,timestamptz,boolean,text)','EXECUTE')" f "anon no write execute"
expect_eq "$NONE" "select count(*) from pg_policies where schemaname='storage' and tablename='objects' and policyname='Food banner Admin upload'" 1 "upload policy exists"
echo "PASS Admin Food banners: schedule, auth, immutable images, audit, no accidental publish"
