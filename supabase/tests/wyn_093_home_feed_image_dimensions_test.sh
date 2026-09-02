#!/usr/bin/env bash
# Regression test for WYN-093 (Wynos V1.0.0 Beta2, item 19 -- dynamic-
# height/aspect-fit images in the feed): verifies the schema.sql change
# that appends `image_width`/`image_height` to `public.drops` and to
# the *last* (effective) `public.home_feed` view definition's 3
# UNION ALL branches (drop / pop / redrop-of-drop).
#
# What this checks:
#   1. `alter table ... add column if not exists` for the 2 new
#      columns on `drops` is idempotent (safe to re-run/already
#      applied), same convention as every other additive column in
#      this file.
#   2. The exact risk class that caused the pre-existing production P0
#      incidents (WYN-071/072, see .wyn/company/DECISIONS.md) and the
#      still-unfixed schema.sql-fails-to-load-fresh issue (WYN-079's
#      Coding Output notes) -- PostgreSQL's CREATE OR REPLACE VIEW
#      rejects reordering/renaming an existing column, but *does*
#      allow appending brand-new columns at the very end. CHECK1/2
#      prove the append-only technique this task's schema.sql edit
#      actually uses (image_width/image_height added as the last 2
#      columns of every branch, never interleaved) works.
#   3. A Drop-shaped row created *before* this migration (no width/
#      height) reads back as null through the view, not an error or a
#      default 0 -- the exact fallback HomeDropCard's client-side
#      clamp logic depends on to render the old fixed 1:1 square.
#   4. The pop-shaped branch's `null::integer as image_width/height`
#      placeholders type-check against the drop branch's real
#      `integer` columns across UNION ALL (Postgres requires every
#      branch to agree on column type).
#
# This is a structural analog of the real 3-way UNION ALL
# public.home_feed view (drop / pop / redrop-of-drop branches, same
# append-only column order), not a byte-for-byte copy -- reproducing
# every join (drop_likes/drop_comments/liked_by/top_reply/etc.) here
# would just re-implement half of schema.sql for no extra coverage of
# the actual risk this task introduces. See wyn_079's own test file
# for the identical reasoning/precedent, and its header for why this
# can't just load schema.sql itself (7 accumulated `create or replace
# view public.home_feed` statements, pre-existing and out of scope).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors every other
# supabase/tests/*.sh harness in this repo).
#
# Usage:
#   bash supabase/tests/wyn_093_home_feed_image_dimensions_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

DB_NAME="wyn093_home_feed_image_dimensions_regression_test"
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
grant select on auth.users to authenticated;
EOF

cat > "$WORK_DIR/01_schema.sql" <<'EOF'
-- Minimal drops/pops/redrops/profiles shape -- just enough columns
-- for the 3-branch UNION ALL structure this task actually changed
-- (id, content_type, image_url, image_width, image_height), not the
-- full home_feed view's every join.
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  username text not null
);

create table public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id),
  image_url text,
  created_at timestamptz not null default now()
);

create table public.pops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.redrops (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id),
  redropper_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

-- STEP A: the "before this migration" shape -- home_feed_stub exists
-- already, same as it would in a real production database prior to
-- this task's deploy.
create view public.home_feed_stub as
select d.id, 'drop'::text as content_type, d.image_url
from public.drops d
union all
select p.id, 'pop'::text as content_type, null::text as image_url
from public.pops p
union all
select d.id, 'drop'::text as content_type, d.image_url
from public.redrops r
join public.drops d on d.id = r.drop_id;

-- STEP B: this task's actual schema.sql change, verbatim technique --
-- `alter table ... add column if not exists` (idempotent, CHECK1
-- below re-runs it) then `create or replace view` appending the 2 new
-- columns at the very end of every branch (never interleaved with
-- existing columns), exactly like the real schema.sql edit.
alter table public.drops add column if not exists image_width integer;
alter table public.drops add column if not exists image_height integer;
alter table public.drops add column if not exists image_width integer;
alter table public.drops add column if not exists image_height integer;

create or replace view public.home_feed_stub as
select d.id, 'drop'::text as content_type, d.image_url,
  d.image_width, d.image_height
from public.drops d
union all
select p.id, 'pop'::text as content_type, null::text as image_url,
  null::integer as image_width, null::integer as image_height
from public.pops p
union all
select d.id, 'drop'::text as content_type, d.image_url,
  d.image_width, d.image_height
from public.redrops r
join public.drops d on d.id = r.drop_id;

grant select on public.home_feed_stub to authenticated;
grant select on public.drops, public.pops, public.redrops, public.profiles to authenticated;
EOF

cat > "$WORK_DIR/02_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'me@test.local');
insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'me');

-- A Drop created *after* this migration -- real dimensions known.
insert into public.drops (id, author_id, image_url, image_width, image_height) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
   'https://example.com/new.jpg', 1080, 1350);

-- A Drop created *before* this migration -- no metadata, must stay
-- null through the view (never a crash, never a fabricated default).
insert into public.drops (id, author_id, image_url) values
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001',
   'https://example.com/old.jpg');

insert into public.pops (id, author_id) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

select 'CHECK1_new_drop_has_real_dimensions' as check_name,
  (select image_width from public.home_feed_stub where id = '10000000-0000-0000-0000-000000000001')::text as actual,
  '1080' as expected;

select 'CHECK2_old_drop_falls_back_to_null' as check_name,
  coalesce((select image_width::text from public.home_feed_stub where id = '10000000-0000-0000-0000-000000000002'), 'NULL') as actual,
  'NULL' as expected;

select 'CHECK3_pop_branch_type_checks_as_null' as check_name,
  coalesce((select image_height::text from public.home_feed_stub where id = '30000000-0000-0000-0000-000000000001'), 'NULL') as actual,
  'NULL' as expected;

select 'CHECK4_view_row_count_unaffected' as check_name,
  (select count(*) from public.home_feed_stub)::text as actual,
  '3' as expected;
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
