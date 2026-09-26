#!/usr/bin/env bash
# WYN-189: isolated, role-based audit projection and raw audit privacy regression.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="wyn189_staff_audit_invoker_test"
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
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated,anon;
SQL

cat > "$WORK_DIR/fresh_schema_check.sql" <<'SQL'
DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE oid='public.admin_audit_log'::regclass
      AND 'security_invoker=true' = ANY(reloptions)
  ) THEN
    RAISE EXCEPTION 'Canonical schema omitted WYN-189 invoker view';
  END IF;
END
$verify$;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
create table results (label text primary key, actual int, expected int);
insert into auth.users(id,email) values
 ('90000000-0000-0000-0000-000000000021','staff@test.invalid'),
 ('90000000-0000-0000-0000-000000000022','admin@test.invalid'),
 ('90000000-0000-0000-0000-000000000023','user@test.invalid'),
 ('90000000-0000-0000-0000-000000000024','noprofile@test.invalid');
insert into public.profiles(id,username,platform_role) values
 ('90000000-0000-0000-0000-000000000021','wyn189_mod','moderator'),
 ('90000000-0000-0000-0000-000000000022','wyn189_admin','admin'),
 ('90000000-0000-0000-0000-000000000023','wyn189_user','user');
insert into public.audit_log(actor_id,actor_username_snapshot,event_type,target_id,detail)
values (
 '90000000-0000-0000-0000-000000000021','wyn189_mod',
 'data_exported','90000000-0000-0000-0000-000000000023',
 '{"test":true}'::jsonb
);

insert into results values
 ('anonymous_view_denied',has_table_privilege('anon','public.admin_audit_log','SELECT')::int,0),
 ('authenticated_view_select',has_table_privilege('authenticated','public.admin_audit_log','SELECT')::int,1),
 ('unauthenticated_internal_schema_denied',has_schema_privilege('anon','internal','USAGE')::int,0),
 ('raw_audit_has_no_select_policy',
  (select count(*)::int from pg_policies where schemaname='public'
   and tablename='audit_log' and cmd in('SELECT','ALL')),0),
 ('audit_projection_helper_not_public',
   has_function_privilege('anon','internal.wyn189_staff_audit_rows()','EXECUTE')::int,0),
 ('audit_projection_helper_auth',
   has_function_privilege('authenticated','internal.wyn189_staff_audit_rows()','EXECUTE')::int,1);

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000021';
set request.jwt.claim.role='authenticated';
insert into results select 'moderator_sees_audit',count(*)::int,1
from public.admin_audit_log;
insert into results select 'moderator_raw_audit_is_empty',count(*)::int,0
from public.audit_log;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000022';
set request.jwt.claim.role='authenticated';
insert into results select 'admin_sees_audit',count(*)::int,1
from public.admin_audit_log;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000023';
set request.jwt.claim.role='authenticated';
insert into results select 'user_sees_no_audit',count(*)::int,0
from public.admin_audit_log;
insert into results select 'user_helper_sees_no_audit',count(*)::int,0
from internal.wyn189_staff_audit_rows();
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000024';
set request.jwt.claim.role='authenticated';
insert into results select 'no_profile_sees_no_audit',count(*)::int,0
from public.admin_audit_log;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

DO $verify$
BEGIN
  IF EXISTS(SELECT 1 FROM results WHERE actual IS DISTINCT FROM expected) THEN
    RAISE EXCEPTION 'WYN-189 failed: %',
      (SELECT string_agg(label||'='||actual||'/'||expected,', ')
       FROM results WHERE actual IS DISTINCT FROM expected);
  END IF;
END
$verify$;
SQL

echo "== WYN-189 staff audit projection privacy =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../schema.sql"
psql_file "$DB_NAME" "$WORK_DIR/fresh_schema_check.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn189_staff_audit_projection.sql"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
