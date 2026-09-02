#!/usr/bin/env bash
# Regression test for WYN-083 (Wynos V1.0.0 Beta2, item 21 -- Founder:
# "การนับวิว จะนับตั้งแต่วินาทีแรก ที่มีคนเห็น รวมถึงเจ้าของโพสต์ด้วย
# นับไม่จำกัด"). Reverses 2 of wyn_038_view_counting_test.sh's original
# CHECK2/CHECK3 assertions -- see that file's now-updated header note.
#
#   1. A repeat View from the SAME viewer now increments the count
#      again (no more unique-viewer lifetime dedup).
#   2. The Drop's own author viewing their own Drop now counts too (no
#      more self-view exclusion).
#   3. Rate limit (20/60s per account) and velocity cap (50/10s per
#      Drop) are untouched -- still enforced, silently, never an error.
#
# This is a standalone/minimal harness (just profiles/drops/drop_views
# + record_drop_view()/drop_view_count(), copied verbatim from
# supabase/schema.sql), not the full schema.sql -- schema.sql
# currently fails to load fresh into an empty database due to a
# pre-existing, unrelated home_feed view migration-history conflict
# (see WYN-079's Coding Output notes and .wyn/company/DECISIONS.md,
# 2026-09-02). wyn_038_view_counting_test.sh (which exercises the same
# functions against the full schema.sql) could not be run or fully
# re-verified in this session for the same reason -- its header now has
# a note about that.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors every other
# supabase/tests/*.sh harness in this repo).
#
# Usage:
#   bash supabase/tests/wyn_083_view_count_owner_and_repeat_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

DB_NAME="wyn083_view_count_owner_repeat_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

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
-- Same auth.uid()/auth.role() stub every other supabase/tests/*.sh
-- harness in this repo uses.
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

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end
$$;

grant usage on schema public to authenticated;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function auth.role() to authenticated;
grant select on auth.users to authenticated;
EOF

cat > "$WORK_DIR/01_schema.sql" <<'EOF'
-- Verbatim from supabase/schema.sql's WYN-038/WYN-083 section (table +
-- record_drop_view()/drop_view_count()), not a paraphrase -- kept in
-- sync by hand since this harness can't load schema.sql itself (see
-- file header).
create table public.profiles (
  id uuid primary key default gen_random_uuid()
);
grant select on public.profiles to authenticated;

create table public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id),
  deleted_at timestamptz
);
grant select on public.drops to authenticated;

create table public.drop_views (
  id uuid not null default gen_random_uuid() primary key,
  drop_id uuid not null references public.drops (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.record_drop_view(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
  v_account_recent_count bigint;
  v_drop_recent_count bigint;
begin
  select * into v_drop from public.drops where id = p_drop_id;

  if v_drop is null or v_drop.deleted_at is not null then
    return;
  end if;

  select count(*) into v_account_recent_count
  from public.drop_views
  where viewer_id = v_me and created_at > now() - interval '60 seconds';
  if v_account_recent_count >= 20 then
    return;
  end if;

  select count(*) into v_drop_recent_count
  from public.drop_views
  where drop_id = p_drop_id and created_at > now() - interval '10 seconds';
  if v_drop_recent_count >= 50 then
    return;
  end if;

  insert into public.drop_views (drop_id, viewer_id)
  values (p_drop_id, v_me);
end;
$$;

grant execute on function public.record_drop_view(uuid) to authenticated;

create or replace function public.drop_view_count(p_drop_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.drop_views where drop_id = p_drop_id;
$$;

grant execute on function public.drop_view_count(uuid) to authenticated;
EOF

cat > "$WORK_DIR/02_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);

-- alice: Drop author. bob: a non-owner viewer. dave: dedicated
-- account for the rate-limit check (CHECK3).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'dave@test.local');

insert into public.profiles (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333');

insert into public.drops (id, author_id) values
  ('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

-- CHECK1: bob views the Drop 3 times (e.g. closing and reopening it) --
-- every call is now its own View, count goes to 3.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK1_repeat_views_from_same_viewer_all_count',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 3;
end
$$;

-- CHECK2: alice (the Drop's own author) views her own Drop -- now
-- counts too, count goes to 4.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK2_authors_own_view_counts',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 4;
end
$$;

-- CHECK3: rate limit is untouched -- one account hammering
-- record_drop_view across 25 distinct Drops is still capped at 20 new
-- rows in the trailing 60 seconds, never an exception.
do $$
declare
  v_drop_ids uuid[] := array(select gen_random_uuid() from generate_series(1, 25));
  i int;
  v_failed boolean := false;
begin
  for i in 1..25 loop
    insert into public.drops (id, author_id)
    values (v_drop_ids[i], '11111111-1111-1111-1111-111111111111');
  end loop;

  begin
    set role authenticated;
    set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
    set request.jwt.claim.role = 'authenticated';
    for i in 1..25 loop
      perform public.record_drop_view(v_drop_ids[i]);
    end loop;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results select 'CHECK3a_rate_limit_never_raises', case when v_failed then 0 else 1 end, 1;

  insert into results
  select 'CHECK3b_rate_limit_still_caps_at_20',
    (select count(*)::int from public.drop_views
     where viewer_id = '33333333-3333-3333-3333-333333333333'), 20;
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup failed" >&2
  cat "$WORK_DIR/psql.out" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/01_schema.sql"; then
  echo "FAIL: schema setup failed" >&2
  cat "$WORK_DIR/psql.out" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/02_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
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

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
