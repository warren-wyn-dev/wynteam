#!/usr/bin/env bash
# WYN-190: throwaway PostgreSQL proof of private report and affinity projections.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="wyn190_private_projections_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

psql_file() {
  local db="$1" file="$2"
  psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null 2>&1 \
    || sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null
}
createdb_any() {
  createdb "$1" >/dev/null 2>&1 || sudo -u postgres createdb "$1" >/dev/null
}
dropdb_any() {
  dropdb --if-exists "$1" >/dev/null 2>&1 \
    || sudo -u postgres dropdb --if-exists "$1" >/dev/null 2>&1 || true
}

cat > "$WORK_DIR/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key default gen_random_uuid(),email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
create schema if not exists storage;
create table if not exists storage.buckets(id text primary key,name text not null,public boolean not null default false);
create table if not exists storage.objects(id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),name text,owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable
as $$ select string_to_array(name,'/') $$;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public,storage to authenticated,anon;
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated,anon;
SQL

cat > "$WORK_DIR/schema_check.sql" <<'SQL'
DO $check$
BEGIN
  IF NOT EXISTS(
    SELECT 1 FROM pg_class
    WHERE oid='public.moderation_queue'::regclass
      AND 'security_invoker=true'=ANY(reloptions)
  ) OR NOT EXISTS(
    SELECT 1 FROM pg_class
    WHERE oid='public.my_effective_affinities'::regclass
      AND 'security_invoker=true'=ANY(reloptions)
      AND 'security_barrier=true'=ANY(reloptions)
  ) THEN RAISE EXCEPTION 'Canonical schema did not apply WYN-190 projections'; END IF;
END
$check$;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
create table results(label text primary key,actual int,expected int);
insert into auth.users(id,email) values
 ('90000000-0000-0000-0000-000000000031','reporter@test.invalid'),
 ('90000000-0000-0000-0000-000000000032','moderator@test.invalid'),
 ('90000000-0000-0000-0000-000000000033','userb@test.invalid'),
 ('90000000-0000-0000-0000-000000000034','admin@test.invalid'),
 ('90000000-0000-0000-0000-000000000035','noprofile@test.invalid');
insert into public.profiles(id,username,platform_role) values
 ('90000000-0000-0000-0000-000000000031','wyn190_a','user'),
 ('90000000-0000-0000-0000-000000000032','wyn190_mod','moderator'),
 ('90000000-0000-0000-0000-000000000033','wyn190_b','user'),
 ('90000000-0000-0000-0000-000000000034','wyn190_admin','admin');
insert into public.reports(id,reporter_id,target_type,target_id,category,detail)
values (
 '90000000-0000-0000-0000-000000000036',
 '90000000-0000-0000-0000-000000000031',
 'drop','90000000-0000-0000-0000-000000000037','spam','WYN-190 seeded report'
);
insert into public.user_affinities
(user_id,dimension_type,dimension_key,recent_score,long_term_score,updated_at)
values
 ('90000000-0000-0000-0000-000000000031','topic','topic-for-A',8,3,now()),
 ('90000000-0000-0000-0000-000000000033','topic','topic-for-B',4,2,now());

insert into results values
 ('anon_queue_denied',has_table_privilege('anon','public.moderation_queue','SELECT')::int,0),
 ('anon_affinity_denied',has_table_privilege('anon','public.my_effective_affinities','SELECT')::int,0),
 ('raw_affinity_not_directly_selectable',
   has_table_privilege('authenticated','public.user_affinities','SELECT')::int,0),
 ('reporter_only_report_policy_still_present',
   (select count(*)::int from pg_policies where schemaname='public'
    and tablename='reports' and cmd='SELECT'
    and position('reporter_id' in qual)>0),1),
 ('queue_has_no_reporter_id',
   (select count(*)::int from information_schema.columns
    where table_schema='public' and table_name='moderation_queue'
      and column_name='reporter_id'),0),
 ('anon_cannot_call_report_helper',
   has_function_privilege('anon','internal.wyn190_staff_report_rows()','EXECUTE')::int,0),
 ('anon_cannot_call_affinity_helper',
   has_function_privilege('anon','internal.wyn190_my_affinity_rows()','EXECUTE')::int,0);

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000032';
set request.jwt.claim.role='authenticated';
insert into results select 'moderator_sees_all_reports',count(*)::int,1
from public.moderation_queue;
insert into results select 'moderator_raw_report_denied',count(*)::int,0
from public.reports;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000034';
set request.jwt.claim.role='authenticated';
insert into results select 'admin_sees_all_reports',count(*)::int,1
from public.moderation_queue;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000031';
set request.jwt.claim.role='authenticated';
insert into results select 'reporter_cannot_see_staff_queue',count(*)::int,0
from public.moderation_queue;
insert into results select 'reporter_can_see_own_raw_report',count(*)::int,1
from public.reports;
insert into results select 'A_sees_only_own_affinity',count(*)::int,1
from public.my_effective_affinities where dimension_key='topic-for-A';
insert into results select 'A_does_not_see_B_affinity',count(*)::int,0
from public.my_effective_affinities where dimension_key='topic-for-B';
insert into results select 'A_score_bounded',count(*)::int,0
from public.my_effective_affinities where abs(effective_score)>1;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000033';
set request.jwt.claim.role='authenticated';
insert into results select 'B_queue_denied',count(*)::int,0
from public.moderation_queue;
insert into results select 'B_only_own_affinity',count(*)::int,1
from public.my_effective_affinities where dimension_key='topic-for-B';
insert into results select 'B_not_A_affinity',count(*)::int,0
from public.my_effective_affinities where dimension_key='topic-for-A';
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000035';
set request.jwt.claim.role='authenticated';
insert into results select 'no_profile_queue_empty',count(*)::int,0
from public.moderation_queue;
insert into results select 'no_profile_affinity_empty',count(*)::int,0
from public.my_effective_affinities;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

DO $verify$
BEGIN
 IF EXISTS(SELECT 1 FROM results WHERE actual IS DISTINCT FROM expected) THEN
   RAISE EXCEPTION 'WYN-190 failed: %',
     (SELECT string_agg(label||'='||actual||'/'||expected,', ')
      FROM results WHERE actual IS DISTINCT FROM expected);
 END IF;
END
$verify$;
SQL

echo "== WYN-190 moderation/affinity privacy =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../schema.sql"
psql_file "$DB_NAME" "$WORK_DIR/schema_check.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn156_view_privileges.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn190_private_views.sql"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
