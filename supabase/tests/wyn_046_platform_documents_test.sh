#!/usr/bin/env bash
# Regression test for WYN-046 (Platform Documents + Acceptance Flow) --
# proves the core guarantees at the database layer under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_044_notification_settings_test.sh's exact
# harness/role-switching convention.
#
#   1. All 6 seeded platform_documents rows (version 1) are readable by
#      an ordinary authenticated user.
#   2. No `authenticated` user can INSERT a row into platform_documents
#      (RLS blocks it -- content only ever changes via migration).
#   3. No `authenticated` user can UPDATE a row in platform_documents.
#   4. No `authenticated` user can DELETE a row in platform_documents.
#   5. A user can INSERT her own user_document_acceptances row and read
#      it back.
#   6. A different user cannot SELECT that row (RLS).
#   7. A different user cannot UPDATE that row (RLS).
#   8. Upserting the same (user_id, document_type) pair with a new
#      version replaces the version -- proves the "re-accept on version
#      bump" mechanism works at the data layer.
#   9. A brand-new user with no public.profiles row yet (AuthGate shows
#      this screen before UsernameSetupScreen) can still accept the
#      mandatory documents, via PlatformDocumentRepository's own stub
#      profiles upsert -- and that stub upsert never clobbers a
#      username the user has since set.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_044_notification_settings_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_046_platform_documents_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn046_platform_documents_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi

run_psql() {
  local db="$1"
  local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  else
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
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
-- Stub of Supabase platform pieces that schema.sql assumes already exist.
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

alter table storage.objects enable row level security;

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
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);

-- alice: owns her own user_document_acceptances rows.
-- bob: tries to read/write platform_documents and alice's rows.
insert into auth.users (id, email) values
  ('62000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('62000000-0000-0000-0000-000000000002', 'bob@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('62000000-0000-0000-0000-000000000001', 'alice046', 'alice', 'user', false),
  ('62000000-0000-0000-0000-000000000002', 'bob046', 'bob', 'user', false);

-- ------------------------------------------------------------
-- CHECK 1: all 6 seeded platform_documents rows (version 1) are
-- readable by an ordinary authenticated user.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.platform_documents where version = 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK01_all_6_documents_readable', v_count, 6;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: no authenticated user can INSERT a platform_documents row.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.platform_documents (type, version, title, content, effective_at)
    values ('terms_of_service', 999, 'hack', 'hack', now());
    insert into results values ('CHECK02_insert_denied', 0, 1);
  exception when insufficient_privilege or others then
    insert into results values ('CHECK02_insert_denied', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: no authenticated user can UPDATE a platform_documents row.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  update public.platform_documents set title = 'hacked' where type = 'terms_of_service' and version = 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.platform_documents
  where type = 'terms_of_service' and version = 1 and title = 'hacked';

  insert into results select 'CHECK03_update_denied', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: no authenticated user can DELETE a platform_documents row.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  delete from public.platform_documents where type = 'terms_of_service' and version = 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select count(*) into v_count from public.platform_documents
  where type = 'terms_of_service' and version = 1;

  insert into results select 'CHECK04_delete_denied', v_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: alice can INSERT her own user_document_acceptances row and
-- read it back.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.user_document_acceptances (user_id, document_type, version) values
    ('62000000-0000-0000-0000-000000000001', 'terms_of_service', 1),
    ('62000000-0000-0000-0000-000000000001', 'privacy_policy', 1),
    ('62000000-0000-0000-0000-000000000001', 'community_guidelines', 1);

  select count(*) into v_count from public.user_document_acceptances
  where user_id = '62000000-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK05_own_insert_and_readback', v_count, 3;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: bob cannot SELECT alice's user_document_acceptances rows.
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.user_document_acceptances
  where user_id = '62000000-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK06_other_user_cannot_select', v_count, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: bob cannot UPDATE alice's user_document_acceptances rows.
-- ------------------------------------------------------------
do $$
declare
  v_version int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  update public.user_document_acceptances set version = 999
  where user_id = '62000000-0000-0000-0000-000000000001' and document_type = 'terms_of_service';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select version into v_version from public.user_document_acceptances
  where user_id = '62000000-0000-0000-0000-000000000001' and document_type = 'terms_of_service';

  insert into results select 'CHECK07_other_user_cannot_update', case when v_version = 1 then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: upserting the same (user_id, document_type) pair with a
-- new version replaces the version (proves the "re-accept on version
-- bump" mechanism works at the data layer). Simulates: Founder ships
-- terms_of_service v2, alice re-accepts.
-- ------------------------------------------------------------
insert into public.platform_documents (type, version, title, content, effective_at) values
  ('terms_of_service', 2, 'ข้อกำหนดการใช้งาน (v2)', 'placeholder v2', now());

do $$
declare
  v_version int;
  v_row_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  insert into public.user_document_acceptances (user_id, document_type, version)
  values ('62000000-0000-0000-0000-000000000001', 'terms_of_service', 2)
  on conflict (user_id, document_type) do update set version = excluded.version, accepted_at = now();

  select version into v_version from public.user_document_acceptances
  where user_id = '62000000-0000-0000-0000-000000000001' and document_type = 'terms_of_service';

  select count(*) into v_row_count from public.user_document_acceptances
  where user_id = '62000000-0000-0000-0000-000000000001' and document_type = 'terms_of_service';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK08a_upsert_replaces_version', v_version, 2;
  insert into results select 'CHECK08b_upsert_does_not_duplicate_row', v_row_count, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: a brand-new user (auth.users row exists, but no
-- public.profiles row yet -- AuthGate shows DocumentAcceptanceScreen
-- *before* UsernameSetupScreen, see auth_gate.dart's doc comment) can
-- still accept the mandatory documents. Proves
-- PlatformDocumentRepository.acceptMandatoryDocuments()'s own stub
-- `profiles` upsert (added alongside this check -- `id` only, no
-- username) satisfies user_document_acceptances.user_id's FK to
-- public.profiles(id) instead of failing with a foreign-key violation,
-- and that it doesn't clobber an existing profile's username on a
-- later re-accept (CHECK09c).
-- ------------------------------------------------------------
insert into auth.users (id, email) values
  ('62000000-0000-0000-0000-000000000003', null);

do $$
declare
  v_profile_exists boolean;
  v_username_still_null boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '62000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';

  -- Mirrors acceptMandatoryDocuments()'s own sequence exactly: stub
  -- profiles upsert (id only) first, then the acceptance upsert.
  insert into public.profiles (id) values ('62000000-0000-0000-0000-000000000003')
  on conflict (id) do nothing;

  insert into public.user_document_acceptances (user_id, document_type, version) values
    ('62000000-0000-0000-0000-000000000003', 'terms_of_service', 1),
    ('62000000-0000-0000-0000-000000000003', 'privacy_policy', 1),
    ('62000000-0000-0000-0000-000000000003', 'community_guidelines', 1)
  on conflict (user_id, document_type) do update set version = excluded.version, accepted_at = now();

  -- Re-running the same stub upsert (as a later re-accept on a version
  -- bump would) must not touch a username the user has since set.
  update public.profiles set username = 'newuser046' where id = '62000000-0000-0000-0000-000000000003';
  insert into public.profiles (id) values ('62000000-0000-0000-0000-000000000003')
  on conflict (id) do nothing;

  select username is null into v_username_still_null from public.profiles
  where id = '62000000-0000-0000-0000-000000000003';

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select exists(
    select 1 from public.user_document_acceptances
    where user_id = '62000000-0000-0000-0000-000000000003'
  ) into v_profile_exists;

  insert into results select 'CHECK09a_new_user_stub_profile_then_accept_succeeds',
    case when v_profile_exists then 1 else 0 end, 1;
  insert into results select 'CHECK09b_all_3_mandatory_types_accepted',
    (select count(*) from public.user_document_acceptances
     where user_id = '62000000-0000-0000-0000-000000000003'), 3;
  insert into results select 'CHECK09c_stub_upsert_does_not_clobber_existing_username',
    case when v_username_still_null then 0 else 1 end, 1;
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql errored while loading" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"
  actual="$(echo "$actual" | xargs)"
  expected="$(echo "$expected" | xargs)"
  [ -z "$name" ] && continue
  case "$name" in
    CHECK*)
      if [ "$actual" != "$expected" ]; then
        echo "FAIL: $name -- expected $expected, got $actual"
        FAILURES=$((FAILURES + 1))
      else
        echo "PASS: $name (expected $expected, got $actual)"
      fi
      ;;
  esac
done < "$WORK_DIR/psql.out"

dropdb_any "$DB_NAME"

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
