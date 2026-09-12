#!/usr/bin/env bash
# WYN-156 regression: API-facing sensitive views are SELECT-only for signed-in
# callers and completely unavailable to the pre-auth `anon` role.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn156_view_privileges.sql"
DB_NAME="wyn156_view_privileges_test"
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
    || sudo -u postgres dropdb --if-exists "$1" >/dev/null 2>&1 \
    || true
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
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public, storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated, anon;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
do $$
declare
  v text;
  views text[] := array[
    'public.moderation_queue',
    'public.admin_user_moderation_history',
    'public.admin_audit_log',
    'public.my_effective_affinities'
  ];
begin
  foreach v in array views loop
    if has_table_privilege('anon', v, 'SELECT') then
      raise exception 'anon can SELECT from %', v;
    end if;
    if not has_table_privilege('authenticated', v, 'SELECT') then
      raise exception 'authenticated lost SELECT on %', v;
    end if;
    if has_table_privilege('authenticated', v, 'INSERT')
       or has_table_privilege('authenticated', v, 'UPDATE')
       or has_table_privilege('authenticated', v, 'DELETE') then
      raise exception 'authenticated retains DML on %', v;
    end if;
  end loop;
end $$;
SQL

echo "== WYN-156 sensitive-view privilege regression =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCHEMA_FILE"
psql_file "$DB_NAME" "$MIGRATION_FILE"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
