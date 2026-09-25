#!/usr/bin/env bash
# WYN-188: throwaway PostgreSQL role test for the invoker-only admin history view.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="wyn188_moderation_history_invoker_test"
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
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;
create schema if not exists storage;
create table if not exists storage.buckets (id text primary key, name text not null, public boolean not null default false);
create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$
  select string_to_array(name, '/')
$$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public, storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated, anon;
SQL

cat > "$WORK_DIR/schema_check.sql" <<'SQL'
DO $verify_schema$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE oid='public.admin_user_moderation_history'::regclass
      AND 'security_invoker=true' = ANY(reloptions)
  ) THEN
    RAISE EXCEPTION 'Canonical schema.sql omitted WYN-188 invoker setting';
  END IF;
END
$verify_schema$;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
create table results (label text primary key, actual int, expected int);
insert into auth.users (id,email) values
  ('90000000-0000-0000-0000-000000000011','moderator@example.test'),
  ('90000000-0000-0000-0000-000000000012','user@example.test'),
  ('90000000-0000-0000-0000-000000000013','no-profile@example.test');
insert into public.profiles (id,username,display_name,platform_role) values
  ('90000000-0000-0000-0000-000000000011','wyn188_mod','Mod','moderator'),
  ('90000000-0000-0000-0000-000000000012','wyn188_user','User','user');
insert into public.moderation_actions (id,target_user_id,reviewer_id,action_type,reason)
values ('90000000-0000-0000-0000-000000000014',
        '90000000-0000-0000-0000-000000000012',
        '90000000-0000-0000-0000-000000000011',
        'warning','fixture warning');

insert into results
select 'invoker_enabled',('security_invoker=true' = any(c.reloptions))::int,1
from pg_class c where c.oid='public.admin_user_moderation_history'::regclass;
insert into results values
 ('anon_cannot_select',
   has_table_privilege('anon','public.admin_user_moderation_history','SELECT')::int,0),
 ('authenticated_select_retained',
   has_table_privilege('authenticated','public.admin_user_moderation_history','SELECT')::int,1),
 ('reporter_only_raw_reports_rls_still_intact',
   (select count(*)::int from pg_policies
     where schemaname='public' and tablename='reports' and cmd='SELECT'
       and position('reporter_id' in qual)>0),1);

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000011';
set request.jwt.claim.role='authenticated';
insert into results
select 'moderator_sees_history', count(*)::int,1
from public.admin_user_moderation_history
where target_user_id='90000000-0000-0000-0000-000000000012';
insert into results
select 'moderator_underlying_policy_allows_history', count(*)::int,1
from public.moderation_actions
where target_user_id='90000000-0000-0000-0000-000000000012';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000012';
set request.jwt.claim.role='authenticated';
insert into results
select 'ordinary_user_history_empty',count(*)::int,0
from public.admin_user_moderation_history;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000013';
set request.jwt.claim.role='authenticated';
insert into results
select 'no_profile_history_empty',count(*)::int,0
from public.admin_user_moderation_history;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $assert$
begin
  if exists (select 1 from results where actual is distinct from expected) then
    raise exception 'WYN-188 FAILED: %',
      (select string_agg(label || '=' || actual::text || '/' || expected::text,', ')
       from results where actual is distinct from expected);
  end if;
end
$assert$;
SQL

echo "== WYN-188 security invoker moderation history =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../schema.sql"
psql_file "$DB_NAME" "$WORK_DIR/schema_check.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn156_view_privileges.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn188_moderation_history_invoker.sql"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
