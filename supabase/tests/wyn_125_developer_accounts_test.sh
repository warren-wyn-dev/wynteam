#!/usr/bin/env bash
# Regression test for WYN-125 (Staged Rollout -- Developer Account
# Allowlist / Feature-Flag System) -- proves the generic
# `developer_accounts`/`is_developer_account()` mechanism at the real
# RLS/RPC layer under the `authenticated`/`anon` roles (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_122_chat_lockdown_test.sh's exact harness/role-switching
# convention and wyn_048_audit_log_test.sh's/wyn_030_appeal_system_test.sh's
# "no policy at all" table-lockdown probe pattern.
#
#   1. Empty allowlist (fresh install's default state, before Founder
#      ever adds anyone): is_developer_account() returns false for a
#      regular user -- fail-safe, not fail-open.
#   2. is_developer_account() returns true only for the one user
#      actually inserted into developer_accounts (warren).
#   3. is_developer_account() returns false for a different regular
#      user (alice), even though the allowlist is no longer empty --
#      proves the check is per-caller (auth.uid()), not "is the
#      allowlist non-empty".
#   4. Same, for a second independent regular user (bob).
#   5. is_developer_account() returns false for a freshly created
#      "anonymous sign-in" user (diane) who was never added to
#      developer_accounts -- WYNOS's anonymous sign-in issues a real
#      `authenticated`-role session (Supabase Anonymous Auth), so this
#      is simply another authenticated uid absent from the allowlist,
#      not a special case the function needs to branch on.
#   6. `authenticated` role cannot SELECT any row from
#      developer_accounts directly, even though a row (warren's) exists
#      -- RLS with zero policies hides everything, not just other
#      people's rows.
#   7. `authenticated` role's INSERT into developer_accounts is
#      rejected (no INSERT policy exists to satisfy).
#   8. `authenticated` role's UPDATE against developer_accounts affects
#      zero rows (no USING policy for it to match against).
#   9. `authenticated` role's DELETE against developer_accounts affects
#      zero rows, same reason.
#  10. `anon` role (no JWT at all) cannot SELECT/INSERT/UPDATE/DELETE
#      developer_accounts either -- denied outright (no table-level
#      grant to `anon` exists in the first place, on top of RLS).
#  11. Regression: the table-owner read after every probe above still
#      shows exactly the one seeded row (warren) -- nothing was
#      actually inserted/altered/deleted by any of the rejected probes.
#  12. `anon` role calling is_developer_account() (allowed via
#      Postgres's default EXECUTE-to-PUBLIC grant, same as every other
#      public-schema function in this file) gets back `false`, not an
#      error -- auth.uid() is null for that role, so the function's own
#      `coalesce(..., false)` is what answers, not a permission denial.
#  13. `has_function_privilege('authenticated', 'public.is_developer_account()', 'EXECUTE')`
#      is true -- the explicit grant this task's own Handoff/QA-lesson
#      note (WYN-122 Round 1's "forgot to grant execute" bug class)
#      exists, checked directly rather than assumed from Postgres's
#      default-to-PUBLIC behavior.
#  14. That grant is a *real*, explicit grant to `authenticated` -- it
#      survives revoking PUBLIC's own default grant, and a real RPC
#      call (as the allowlisted user) still succeeds and returns `true`
#      afterward -- exactly the WYN-122 QA scenario, replayed here for
#      this function.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_122_chat_lockdown_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_125_developer_accounts_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn125_developer_accounts_regression_test"
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
-- CHECK10/12 below run as `anon`, which has no default privileges on
-- anything in schema public (unlike `authenticated`) -- grant it just
-- enough to write its own outcome into this table, mirroring
-- wyn_030_appeal_system_test.sh's CHECK22 convention.
grant select, insert on results to anon;

-- alice, bob: regular users, never added to developer_accounts.
-- warren: the one developer account seeded below. diane: a freshly
-- created "anonymous sign-in" user (WYNOS's current auth mode) --
-- has a real profiles row and a real authenticated-role session, but
-- was never added to developer_accounts either.
insert into auth.users (id, email) values
  ('91111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('91222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('91333333-3333-3333-3333-333333333333', 'warren@test.com'),
  ('91444444-4444-4444-4444-444444444444', 'diane@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('91111111-1111-1111-1111-111111111111', 'alice124', 'Alice', 'user'),
  ('91222222-2222-2222-2222-222222222222', 'bob124', 'Bob', 'user'),
  ('91333333-3333-3333-3333-333333333333', 'warren124', 'Warren', 'admin'),
  ('91444444-4444-4444-4444-444444444444', 'diane124', 'Diane', 'user');

-- ------------------------------------------------------------
-- CHECK1: allowlist is completely empty at this point -- a regular
-- user must get `false`, not an error and not `true` (fail-safe, not
-- fail-open, exactly what an empty table means for every future user
-- too, not just today's).
-- ------------------------------------------------------------
do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.is_developer_account() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_empty_allowlist_returns_false', case when v_result then 1 else 0 end, 0;
end
$$;

-- ------------------------------------------------------------
-- Seed the one developer account (warren) -- table-owner write,
-- bypassing RLS, mirroring how every other allowlist fixture in this
-- suite (chat_lockdown_allowlist in wyn_122) seeds data directly.
-- ------------------------------------------------------------
insert into public.developer_accounts (user_id, label) values
  ('91333333-3333-3333-3333-333333333333', 'Founder');

-- ------------------------------------------------------------
-- CHECK2-5: correctness of is_developer_account() per caller, now
-- that the allowlist is non-empty.
-- ------------------------------------------------------------
do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select public.is_developer_account() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK2_allowlisted_user_returns_true', case when v_result then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.is_developer_account() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK3_non_allowlisted_user_alice_returns_false', case when v_result then 1 else 0 end, 0;
end
$$;

do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select public.is_developer_account() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK4_non_allowlisted_user_bob_returns_false', case when v_result then 1 else 0 end, 0;
end
$$;

do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  select public.is_developer_account() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK5_fresh_anonymous_signin_user_returns_false', case when v_result then 1 else 0 end, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK6-9: `authenticated` role cannot read/write developer_accounts
-- directly at all -- zero policies means zero access, in every
-- direction, even though warren's row genuinely exists.
-- ------------------------------------------------------------
do $$
declare
  v_select_count int;
  v_insert_failed boolean := false;
  v_update_rows int;
  v_delete_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';

  select count(*) into v_select_count from public.developer_accounts;

  begin
    insert into public.developer_accounts (user_id, label)
    values ('91111111-1111-1111-1111-111111111111', 'self-added');
  exception when others then
    v_insert_failed := true;
  end;

  update public.developer_accounts set label = 'tampered' where user_id = '91333333-3333-3333-3333-333333333333';
  get diagnostics v_update_rows = row_count;

  delete from public.developer_accounts where user_id = '91333333-3333-3333-3333-333333333333';
  get diagnostics v_delete_rows = row_count;

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6_authenticated_cannot_select_developer_accounts', v_select_count, 0;
  insert into results select 'CHECK7_authenticated_insert_is_rejected', case when v_insert_failed then 1 else 0 end, 1;
  insert into results select 'CHECK8_authenticated_update_affects_zero_rows', v_update_rows, 0;
  insert into results select 'CHECK9_authenticated_delete_affects_zero_rows', v_delete_rows, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK10: `anon` role (no JWT at all) cannot SELECT/INSERT/UPDATE/
-- DELETE developer_accounts either -- denied outright (no table-level
-- grant to `anon` exists in the first place, on top of RLS).
-- ------------------------------------------------------------
set role anon;
do $$
begin
  begin
    perform 1 from public.developer_accounts limit 1;
    insert into results values ('CHECK10a_anon_select_denied', 0, 1);
  exception when others then
    insert into results values ('CHECK10a_anon_select_denied', 1, 1);
  end;

  begin
    insert into public.developer_accounts (user_id, label)
    values ('91222222-2222-2222-2222-222222222222', 'anon-added');
    insert into results values ('CHECK10b_anon_insert_denied', 0, 1);
  exception when others then
    insert into results values ('CHECK10b_anon_insert_denied', 1, 1);
  end;

  begin
    update public.developer_accounts set label = 'anon-tampered' where user_id = '91333333-3333-3333-3333-333333333333';
    insert into results values ('CHECK10c_anon_update_denied', 0, 1);
  exception when others then
    insert into results values ('CHECK10c_anon_update_denied', 1, 1);
  end;

  begin
    delete from public.developer_accounts where user_id = '91333333-3333-3333-3333-333333333333';
    insert into results values ('CHECK10d_anon_delete_denied', 0, 1);
  exception when others then
    insert into results values ('CHECK10d_anon_delete_denied', 1, 1);
  end;
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK11: regression -- none of the rejected probes above (CHECK6-10)
-- actually inserted/altered/deleted anything. Exactly one row (warren,
-- still labeled 'Founder') exists, read as the table owner (bypasses
-- RLS entirely).
-- ------------------------------------------------------------
insert into results select 'CHECK11a_exactly_one_row_survives_all_probes', count(*), 1
from public.developer_accounts;
insert into results select 'CHECK11b_surviving_row_is_warren_unaltered',
  case when exists (
    select 1 from public.developer_accounts
    where user_id = '91333333-3333-3333-3333-333333333333' and label = 'Founder'
  ) then 1 else 0 end,
  1;

-- ------------------------------------------------------------
-- CHECK12: `anon` role calling is_developer_account() directly --
-- allowed to execute at all (Postgres's default EXECUTE-to-PUBLIC
-- grant on function creation, same as every other public-schema
-- function in this file -- see the WYN-027 internal-schema comment
-- above), but must answer `false`, not error and not `true` --
-- auth.uid() is null under this role, so coalesce(..., false) is what
-- actually answers.
-- ------------------------------------------------------------
set role anon;
do $$
declare
  v_result boolean;
  v_errored boolean := false;
begin
  begin
    select public.is_developer_account() into v_result;
  exception when others then
    v_errored := true;
  end;
  insert into results values ('CHECK12a_anon_call_does_not_error', case when v_errored then 0 else 1 end, 1);
  insert into results values ('CHECK12b_anon_call_returns_false', case when (not v_errored and v_result) then 1 else 0 end, 0);
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK13: `authenticated` has an explicit EXECUTE grant on
-- is_developer_account() -- the exact bug class WYN-122 Round 1 found
-- (internal.chat_pair_allowed() missing this same grant), checked
-- directly instead of assumed from Postgres's default-to-PUBLIC
-- behavior.
-- ------------------------------------------------------------
insert into results
select 'CHECK13_authenticated_has_explicit_execute_grant',
  case when has_function_privilege('authenticated', 'public.is_developer_account()', 'EXECUTE')
       then 1 else 0 end,
  1;

-- CHECK14: prove it's a *real* grant, not just relying on the PUBLIC
-- default -- revoking PUBLIC's own default grant must not remove
-- `authenticated`'s explicit one, and a real RPC call (as the
-- allowlisted user) must still succeed and return `true` afterward.
-- Restores PUBLIC's grant immediately after so this throwaway
-- database's own end state doesn't matter either way (it gets dropped
-- regardless), but keeps the check honest about what it's actually
-- proving.
revoke execute on function public.is_developer_account() from public;
insert into results
select 'CHECK14a_authenticated_grant_survives_revoking_public_default',
  case when has_function_privilege('authenticated', 'public.is_developer_account()', 'EXECUTE')
       then 1 else 0 end,
  1;
do $$
declare
  v_result boolean;
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '91333333-3333-3333-3333-333333333333';
    set request.jwt.claim.role = 'authenticated';
    select public.is_developer_account() into v_result;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK14b_rpc_survives_public_default_revoked', case when (not v_failed and v_result) then 1 else 0 end, 1;
end
$$;
grant execute on function public.is_developer_account() to public;

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
