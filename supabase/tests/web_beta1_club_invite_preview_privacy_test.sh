#!/usr/bin/env bash
# Web Beta1: isolated, anonymous RPC privacy regression.
# Fresh local database only; never touches production.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_web_beta1_club_invite_preview_privacy.sql"
DB_NAME="wyn_web_beta1_invite_preview_privacy_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

for required in "$SCHEMA_FILE" "$MIGRATION_FILE"; do
  if [ ! -f "$required" ]; then
    echo "FAIL: required file not found: $required" >&2
    exit 1
  fi
done

run_psql() {
  local db="$1"
  local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  fi
  # In CI, PostgreSQL is a service container. sudo resets PGHOST and masks
  # the original SQL failure with a misleading local socket error.
  if [[ -n "${PGHOST:-}" ]]; then
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  fi
  cat "$WORK_DIR/psql.out" >&2
  return 1
}

createdb_any() {
  local db="$1"
  if createdb "$db" >/dev/null 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres createdb "$db" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

dropdb_any() {
  local db="$1"
  dropdb --if-exists "$db" >/dev/null 2>&1 \
    || { command -v sudo >/dev/null 2>&1 && sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1; } \
    || true
}

cat > "$WORK_DIR/00_stub.sql" <<'EOF'
create extension if not exists pgcrypto;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid
);

create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$
  select string_to_array(name, '/')
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end
$$;

grant usage on schema public to authenticated, anon;
grant usage on schema storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
EOF


cat > "$WORK_DIR/10_seed.sql" <<'EOF'
\set ON_ERROR_STOP on
insert into auth.users (id,email) values
  ('11111111-1111-1111-1111-111111111111','owner@privacy.test');
insert into public.profiles (id,username,display_name,platform_role) values
  ('11111111-1111-1111-1111-111111111111','privacyqa','Privacy QA','user');
insert into public.clubs (id,name,privacy,owner_id,icon_url) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Private QA Club','private',
   '11111111-1111-1111-1111-111111111111','private/cover.png');
insert into public.club_invite_links
 (club_id,code,created_by,expires_at,max_uses,use_count,revoked_at) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-valid',
  '11111111-1111-1111-1111-111111111111',null,null,0,null),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-revoked',
  '11111111-1111-1111-1111-111111111111',null,null,0,now()-interval '1 hour'),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-expired',
  '11111111-1111-1111-1111-111111111111',now()-interval '1 hour',null,0,null),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-exhausted',
  '11111111-1111-1111-1111-111111111111',null,1,1,null);
EOF

cat > "$WORK_DIR/20_assert.sql" <<'EOF'
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- Test through the true PostgreSQL anon role, never the postgres role.
set role anon;
select 'CHECK1_valid_metadata_visible',
       coalesce((select status = 'valid'
         and club_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
         and club_name = 'Private QA Club'
         and club_privacy = 'private'
         and club_icon_url = 'private/cover.png'
         from public.preview_club_invite_link('qa-valid')), false)::text,
       'true';
select 'CHECK2_revoked_status_only',
       coalesce((select status = 'revoked'
         and club_id is null and club_name is null
         and club_privacy is null and club_icon_url is null
         from public.preview_club_invite_link('qa-revoked')), false)::text,
       'true';
select 'CHECK3_expired_status_only',
       coalesce((select status = 'expired'
         and club_id is null and club_name is null
         and club_privacy is null and club_icon_url is null
         from public.preview_club_invite_link('qa-expired')), false)::text,
       'true';
select 'CHECK4_exhausted_status_only',
       coalesce((select status = 'exhausted'
         and club_id is null and club_name is null
         and club_privacy is null and club_icon_url is null
         from public.preview_club_invite_link('qa-exhausted')), false)::text,
       'true';
select 'CHECK5_unknown_status_only',
       coalesce((select status = 'not_found'
         and club_id is null and club_name is null
         and club_privacy is null and club_icon_url is null
         from public.preview_club_invite_link('qa-never-exists')), false)::text,
       'true';
select 'CHECK6_null_code_status_only',
       coalesce((select status = 'not_found'
         and club_id is null and club_name is null
         and club_privacy is null and club_icon_url is null
         from public.preview_club_invite_link(null)), false)::text,
       'true';
select 'CHECK7_anon_access_preserved',
       has_function_privilege('anon',
         'public.preview_club_invite_link(text)'::regprocedure,'execute')::text,
       'true';
reset role;

set role authenticated;
select 'CHECK8_signed_in_valid_access',
       coalesce((select status = 'valid' and club_name = 'Private QA Club'
         from public.preview_club_invite_link('qa-valid')), false)::text,
       'true';
reset role;
EOF

echo "== Creating isolated club invite privacy QA database =="
dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database" >&2
  exit 1
fi
for file in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$MIGRATION_FILE" \
            "$WORK_DIR/10_seed.sql" "$WORK_DIR/20_assert.sql"; do
  if ! run_psql "$DB_NAME" "$file"; then
    echo "FAIL: SQL execution in $file" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
  if [ "$file" = "$WORK_DIR/20_assert.sql" ]; then
    cp "$WORK_DIR/psql.out" "$WORK_DIR/checks.out"
  fi
done

failures=0
checks=0
while IFS='|' read -r name actual expected; do
  case "$name" in
    CHECK*)
      checks=$((checks + 1))
      if [ "$actual" != "$expected" ]; then
        echo "FAIL $name expected=$expected actual=$actual"
        failures=$((failures + 1))
      else
        echo "PASS $name"
      fi
      ;;
  esac
done < "$WORK_DIR/checks.out"
dropdb_any "$DB_NAME"
if [ "$checks" -ne 8 ] || [ "$failures" -ne 0 ]; then
  echo "FAILED: $failures failures across $checks/8 checks"
  exit 1
fi
echo "ALL 8 ANONYMOUS INVITE PREVIEW PRIVACY CHECKS PASSED"
