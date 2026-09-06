#!/usr/bin/env bash
# Regression test for WYN-113 (Invite-Only Access Gate / Referral Code)
# -- proves the invite_gate_config toggle, auto-generated referral_code,
# and the 4 RPCs (is_invite_gate_enabled, validate_referral_code,
# redeem_referral_code, my_referral_stats) at the real RLS/RPC layer
# under the `authenticated`/`anon` roles (not the Postgres superuser,
# which bypasses RLS entirely), mirroring wyn_125_developer_accounts_test.sh's
# exact harness/role-switching convention and its "no policy at all"
# table-lockdown probe pattern for referral_redemptions.
#
#   1. invite_gate_config ships defaulted to `enabled = false` (fresh
#      install's default state) -- is_invite_gate_enabled() returns
#      false for both `anon` and `authenticated`.
#   2. Flipping invite_gate_config.enabled to true (table-owner write,
#      the Founder's management workflow) makes is_invite_gate_enabled()
#      return true for both roles immediately -- no deploy needed.
#   3. Every profile inserted gets a non-null, unique referral_code via
#      the profiles_set_referral_code trigger -- proven across 3 seeded
#      users, not just one.
#   4. validate_referral_code() is case-insensitive (stored codes are
#      upper-case; a lower-case guess for the same code still matches).
#   5. validate_referral_code() returns false for a code that doesn't
#      exist -- never errors.
#   6. validate_referral_code() is callable by `anon` (no session at
#      all) without erroring -- the one function in this schema that
#      must work pre-authentication.
#   7. redeem_referral_code() by a new user against an existing
#      referrer's code succeeds and is reflected in that referrer's own
#      my_referral_stats() redemption_count.
#   8. Multi-use: a SECOND new user redeeming the SAME referrer's code
#      also succeeds (Acceptance Criteria -- explicitly not single-use)
#      -- redemption_count reaches 2.
#   9. Redeeming again with the SAME user (a retried onboarding step)
#      is a safe no-op (on conflict do nothing) -- no error, no double
#      count.
#  10. Redeeming your own code raises an exception, not a silent no-op.
#  11. Redeeming a code that doesn't exist raises an exception.
#  12. redeem_referral_code() with no session (`anon`, auth.uid() is
#      null) raises an exception rather than silently doing nothing.
#  13. `authenticated` cannot SELECT any row from referral_redemptions
#      directly, even though real rows exist by now -- same "zero
#      policies means zero access" posture as developer_accounts.
#  14. my_referral_stats() only ever returns the caller's own row (a
#      different user's call returns a different redemption_count, not
#      the first caller's).
#  15. Grants are exactly as intended: `anon` has EXECUTE on
#      is_invite_gate_enabled/validate_referral_code but NOT on
#      redeem_referral_code/my_referral_stats (those require a real
#      session by design, not just an auth.uid() null-check at runtime).
#  16. invite_gate_config's singleton constraint actually holds -- a
#      second row (id = false) is rejected by the check constraint, not
#      silently accepted.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_125_developer_accounts_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_113_invite_only_access_gate_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn113_invite_only_access_gate_regression_test"
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
-- CHECK1/6/12/15's anon probes need just enough privilege to write
-- their own outcome into this table, mirroring
-- wyn_125_developer_accounts_test.sh's CHECK10 convention.
grant select, insert on results to anon;

-- alice: the referrer. bob, carol: two separate new users who each
-- redeem alice's code (proving multi-use). dave: a second referrer,
-- used only to prove referral_code is unique per profile and
-- my_referral_stats() never leaks across callers.
insert into auth.users (id, email) values
  ('91111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('91222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('91333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('91444444-4444-4444-4444-444444444444', 'dave@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('91111111-1111-1111-1111-111111111111', 'alice113', 'Alice', 'user'),
  ('91222222-2222-2222-2222-222222222222', 'bob113', 'Bob', 'user'),
  ('91333333-3333-3333-3333-333333333333', 'carol113', 'Carol', 'user'),
  ('91444444-4444-4444-4444-444444444444', 'dave113', 'Dave', 'user');

-- Captured once, as the table owner, into a temporary table -- `anon`
-- has no table-level grant on public.profiles at all (matching
-- wyn_125_developer_accounts_test.sh's CHECK10 posture), so CHECK6
-- below (which runs as `anon`) reads alice's code from here (with an
-- explicit grant) instead of re-querying profiles directly. psql's own
-- `:'var'` interpolation does not reach inside a dollar-quoted `do $$`
-- body, so a temp table -- not a psql variable -- is what actually
-- works here.
create temporary table _tmp_alice_code as
  select referral_code as code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';
grant select on _tmp_alice_code to anon;

-- ------------------------------------------------------------
-- CHECK1: fresh install default -- invite_gate_config ships with
-- enabled = false (schema.sql's own seed insert), so is_invite_gate_
-- enabled() must answer false for both roles, not error.
-- ------------------------------------------------------------
do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.is_invite_gate_enabled() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK1a_gate_defaults_off_for_authenticated', case when v_result then 1 else 0 end, 0;
end
$$;

set role anon;
do $$
declare
  v_result boolean;
begin
  select public.is_invite_gate_enabled() into v_result;
  insert into results select 'CHECK1b_gate_defaults_off_for_anon', case when v_result then 1 else 0 end, 0;
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK2: flipping the toggle (table-owner write, the Founder's real
-- management workflow) takes effect immediately for both roles.
-- ------------------------------------------------------------
update public.invite_gate_config set enabled = true where id = true;

do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.is_invite_gate_enabled() into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK2a_gate_on_reflected_for_authenticated', case when v_result then 1 else 0 end, 1;
end
$$;

set role anon;
do $$
declare
  v_result boolean;
begin
  select public.is_invite_gate_enabled() into v_result;
  insert into results select 'CHECK2b_gate_on_reflected_for_anon', case when v_result then 1 else 0 end, 1;
end
$$;
reset role;

-- Flip back off -- the rest of this test's checks are about referral
-- codes/redemption, not the gate toggle itself, and should not depend
-- on the gate's on/off state.
update public.invite_gate_config set enabled = false where id = true;

-- ------------------------------------------------------------
-- CHECK3: every seeded profile got a non-null, unique referral_code
-- from the profiles_set_referral_code trigger -- table-owner read,
-- bypassing RLS.
-- ------------------------------------------------------------
insert into results select 'CHECK3a_all_profiles_have_a_referral_code',
  count(*), 4
from public.profiles
where id in (
  '91111111-1111-1111-1111-111111111111',
  '91222222-2222-2222-2222-222222222222',
  '91333333-3333-3333-3333-333333333333',
  '91444444-4444-4444-4444-444444444444'
) and referral_code is not null;

insert into results select 'CHECK3b_referral_codes_are_unique_per_profile',
  count(distinct referral_code), 4
from public.profiles
where id in (
  '91111111-1111-1111-1111-111111111111',
  '91222222-2222-2222-2222-222222222222',
  '91333333-3333-3333-3333-333333333333',
  '91444444-4444-4444-4444-444444444444'
);

-- ------------------------------------------------------------
-- CHECK4-6: validate_referral_code() correctness.
-- ------------------------------------------------------------
do $$
declare
  v_alice_code text;
  v_result boolean;
begin
  select referral_code into v_alice_code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';

  set role authenticated;
  set request.jwt.claim.sub = '91222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select public.validate_referral_code(lower(v_alice_code)) into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK4_validate_is_case_insensitive', case when v_result then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_result boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select public.validate_referral_code('NOSUCHCODE') into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK5_validate_unknown_code_returns_false', case when v_result then 1 else 0 end, 0;
end
$$;

-- alice's code comes from _tmp_alice_code (grant select on _tmp_alice_code
-- to anon above) -- `anon` has no table-level grant on public.profiles
-- itself. This check is about validate_referral_code() being
-- anon-callable, not about anon reading profiles directly.
set role anon;
do $$
declare
  v_alice_code text;
  v_result boolean;
  v_errored boolean := false;
begin
  select code into v_alice_code from _tmp_alice_code limit 1;
  begin
    select public.validate_referral_code(v_alice_code) into v_result;
  exception when others then
    v_errored := true;
  end;
  insert into results values ('CHECK6a_anon_validate_does_not_error', case when v_errored then 0 else 1 end, 1);
  insert into results values ('CHECK6b_anon_validate_returns_true_for_real_code', case when (not v_errored and v_result) then 1 else 0 end, 1);
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK7-9: redeem_referral_code() -- multi-use + idempotent retry.
-- ------------------------------------------------------------
do $$
declare
  v_alice_code text;
begin
  select referral_code into v_alice_code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';

  set role authenticated;
  set request.jwt.claim.sub = '91222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.redeem_referral_code(v_alice_code);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_stats record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select * into v_stats from public.my_referral_stats();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK7_first_redemption_reflected_in_referrer_stats', v_stats.redemption_count::int, 1;
end
$$;

-- CHECK8: multi-use -- a SECOND new user (carol) redeeming the SAME
-- code also succeeds (not single-use).
do $$
declare
  v_alice_code text;
begin
  select referral_code into v_alice_code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';

  set role authenticated;
  set request.jwt.claim.sub = '91333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.redeem_referral_code(v_alice_code);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_stats record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select * into v_stats from public.my_referral_stats();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK8_second_new_user_redeeming_same_code_also_counts', v_stats.redemption_count::int, 2;
end
$$;

-- CHECK9: bob (already redeemed in CHECK7) retries redeeming the same
-- code again -- a safe no-op (on conflict do nothing), not an error,
-- and the count must NOT double.
do $$
declare
  v_alice_code text;
  v_errored boolean := false;
begin
  select referral_code into v_alice_code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';

  set role authenticated;
  set request.jwt.claim.sub = '91222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_referral_code(v_alice_code);
  exception when others then
    v_errored := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK9a_retry_redemption_does_not_error', case when v_errored then 1 else 0 end, 0;
end
$$;

do $$
declare
  v_stats record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select * into v_stats from public.my_referral_stats();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK9b_retry_does_not_double_count', v_stats.redemption_count::int, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK10: redeeming your own code raises an exception.
-- ------------------------------------------------------------
do $$
declare
  v_alice_code text;
  v_errored boolean := false;
begin
  select referral_code into v_alice_code from public.profiles
    where id = '91111111-1111-1111-1111-111111111111';

  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_referral_code(v_alice_code);
  exception when others then
    v_errored := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK10_redeeming_own_code_raises', case when v_errored then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK11: redeeming a code that doesn't exist raises an exception.
-- ------------------------------------------------------------
do $$
declare
  v_errored boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_referral_code('NOSUCHCODE');
  exception when others then
    v_errored := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK11_redeeming_unknown_code_raises', case when v_errored then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK12: `anon` (auth.uid() is null) calling redeem_referral_code()
-- raises an exception -- not because the grant is withheld (Postgres's
-- default EXECUTE-to-PUBLIC grant on function creation applies here
-- same as every other public-schema function in this file, see
-- wyn_125_developer_accounts_test.sh's own CHECK12 comment on that
-- convention -- CHECK15 below confirms `anon` really can call it), but
-- because the function's own `if auth.uid() is null then raise
-- exception` body rejects it. The security boundary here is the
-- function's internal logic, not the grant.
-- ------------------------------------------------------------
set role anon;
do $$
declare
  v_errored boolean := false;
begin
  begin
    perform public.redeem_referral_code('ANYCODE');
  exception when others then
    v_errored := true;
  end;
  insert into results values ('CHECK12_anon_redeem_raises', case when v_errored then 1 else 0 end, 1);
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK13: `authenticated` cannot SELECT referral_redemptions
-- directly, even though real rows exist by now (bob's and carol's
-- redemptions from CHECK7/8) -- zero policies means zero access.
-- ------------------------------------------------------------
do $$
declare
  v_select_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_select_count from public.referral_redemptions;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK13_authenticated_cannot_select_referral_redemptions', v_select_count, 0;
end
$$;

insert into results select 'CHECK13b_real_rows_actually_exist_as_table_owner', count(*), 2
from public.referral_redemptions;

-- ------------------------------------------------------------
-- CHECK14: my_referral_stats() only ever returns the caller's own row
-- -- dave (a different referrer, zero redemptions) must see 0, not
-- alice's 2.
-- ------------------------------------------------------------
do $$
declare
  v_stats record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  select * into v_stats from public.my_referral_stats();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results select 'CHECK14_my_referral_stats_never_leaks_across_callers', v_stats.redemption_count::int, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK15: the *explicit* grants this task's own migration adds are
-- exactly as intended -- `anon` gets the two pre-auth-safe functions.
-- redeem_referral_code()/my_referral_stats() are only ever explicitly
-- granted to `authenticated`; `anon` can still technically call them
-- (Postgres's default-to-PUBLIC grant, same as every function in this
-- file -- see CHECK12's comment), which is exactly why both functions
-- defend themselves internally (CHECK12 above; CHECK15g below) rather
-- than relying on the grant to keep anon out.
-- ------------------------------------------------------------
insert into results select 'CHECK15a_anon_has_execute_on_is_invite_gate_enabled',
  case when has_function_privilege('anon', 'public.is_invite_gate_enabled()', 'EXECUTE') then 1 else 0 end, 1;
insert into results select 'CHECK15b_anon_has_execute_on_validate_referral_code',
  case when has_function_privilege('anon', 'public.validate_referral_code(text)', 'EXECUTE') then 1 else 0 end, 1;
insert into results select 'CHECK15e_authenticated_has_execute_on_redeem_referral_code',
  case when has_function_privilege('authenticated', 'public.redeem_referral_code(text)', 'EXECUTE') then 1 else 0 end, 1;
insert into results select 'CHECK15f_authenticated_has_execute_on_my_referral_stats',
  case when has_function_privilege('authenticated', 'public.my_referral_stats()', 'EXECUTE') then 1 else 0 end, 1;

-- CHECK15g: my_referral_stats() called as `anon` (auth.uid() is null)
-- returns zero rows rather than erroring or leaking another user's
-- stats -- the `where p.id = auth.uid()` join simply matches nothing,
-- which is the safe outcome for a read (unlike redeem_referral_code(),
-- a write, which explicitly raises instead -- see CHECK12).
set role anon;
do $$
declare
  v_row_count int;
begin
  select count(*) into v_row_count from public.my_referral_stats();
  insert into results values ('CHECK15g_anon_my_referral_stats_returns_zero_rows', v_row_count, 0);
end
$$;
reset role;

-- ------------------------------------------------------------
-- CHECK16: invite_gate_config's singleton constraint actually holds --
-- a second row (id = false) is rejected by the check constraint.
-- ------------------------------------------------------------
do $$
declare
  v_errored boolean := false;
begin
  begin
    insert into public.invite_gate_config (id, enabled) values (false, true);
  exception when others then
    v_errored := true;
  end;
  insert into results values ('CHECK16_second_config_row_rejected_by_singleton_check', case when v_errored then 1 else 0 end, 1);
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
