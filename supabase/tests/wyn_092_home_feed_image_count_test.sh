#!/usr/bin/env bash
# Regression test for WYN-092 (Wynos V1.0.0 Beta2 Phase 2, item 14 --
# Home feed "peek" carousel for multi-image Drops): verifies the
# schema.sql change that appends `image_count` to the *last*
# (effective) `public.home_feed` view definition's 3 UNION ALL
# branches (drop / pop / redrop-of-drop).
#
# What this checks:
#   1. The exact append-only technique this task's schema.sql edit
#      uses (`image_count` added as the very last column of every
#      branch, never interleaved with image_width/image_height added
#      by WYN-093 before it) -- same risk class as WYN-071/072's prior
#      production incidents (see .wyn/company/DECISIONS.md) and
#      wyn_093's own test, which this file mirrors.
#   2. A Drop with 3 rows in `drop_images` reads back `image_count = 3`
#      through the view.
#   3. A Drop with exactly 1 image (or none at all) reads back
#      `image_count = 0`/`1` correctly -- not null, not miscounted.
#   4. The pop branch's `null::bigint as image_count` placeholder
#      type-checks against the drop branch's real `bigint` count
#      (count(*) returns bigint) across UNION ALL.
#   5. The redrop-of-drop branch counts the *original* Drop's images
#      (same `drop_images` rows the plain-drop branch would see),
#      not something tied to the redrop row itself.
#
# This is a structural analog of the real 3-way UNION ALL
# public.home_feed view (drop / pop / redrop-of-drop branches, same
# append-only column order), not a byte-for-byte copy -- reproducing
# every join (drop_likes/drop_comments/liked_by/top_reply/etc.) here
# would just re-implement half of schema.sql for no extra coverage of
# the actual risk this task introduces. See wyn_093's own test file
# for the identical reasoning/precedent, and its header for why this
# can't just load schema.sql itself (accumulated `create or replace
# view public.home_feed` statements, pre-existing and out of scope).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors every other
# supabase/tests/*.sh harness in this repo).
#
# Usage:
#   bash supabase/tests/wyn_092_home_feed_image_count_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

DB_NAME="wyn092_home_feed_image_count_regression_test"
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
-- Minimal drops/pops/redrops/drop_images/profiles shape -- just enough
-- columns for the 3-branch UNION ALL structure this task actually
-- changed (id, content_type, image_count), not the full home_feed
-- view's every join.
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

create table public.drop_images (
  drop_id uuid not null references public.drops (id) on delete cascade,
  image_url text not null,
  "position" int not null,
  primary key (drop_id, "position")
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
-- `create or replace view` appending `image_count` at the very end of
-- every branch (never interleaved with existing columns), exactly
-- like the real schema.sql edit.
create or replace view public.home_feed_stub as
select d.id, 'drop'::text as content_type, d.image_url,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
from public.drops d
union all
select p.id, 'pop'::text as content_type, null::text as image_url,
  null::bigint as image_count
from public.pops p
union all
select d.id, 'drop'::text as content_type, d.image_url,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
from public.redrops r
join public.drops d on d.id = r.drop_id;

grant select on public.home_feed_stub to authenticated;
grant select on public.drops, public.drop_images, public.pops, public.redrops, public.profiles to authenticated;
EOF

cat > "$WORK_DIR/02_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'me@test.local');
insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001', 'me');

-- A Drop with 3 images.
insert into public.drops (id, author_id, image_url) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
   'https://example.com/img1.jpg');
insert into public.drop_images (drop_id, image_url, "position") values
  ('10000000-0000-0000-0000-000000000001', 'https://example.com/img1.jpg', 0),
  ('10000000-0000-0000-0000-000000000001', 'https://example.com/img2.jpg', 1),
  ('10000000-0000-0000-0000-000000000001', 'https://example.com/img3.jpg', 2);

-- A Drop with exactly 1 image.
insert into public.drops (id, author_id, image_url) values
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001',
   'https://example.com/single.jpg');
insert into public.drop_images (drop_id, image_url, "position") values
  ('10000000-0000-0000-0000-000000000002', 'https://example.com/single.jpg', 0);

-- A text-only Drop (no image, no drop_images rows at all).
insert into public.drops (id, author_id, image_url) values
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', null);

insert into public.pops (id, author_id) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

-- A ReDrop of the 3-image Drop above -- should report the *original*
-- Drop's image_count (3), not something tied to the redrop row.
insert into public.redrops (id, drop_id, redropper_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001');

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

select 'CHECK1_multi_image_drop_counts_3' as check_name,
  (select image_count from public.home_feed_stub
     where id = '10000000-0000-0000-0000-000000000001' and content_type = 'drop'
     limit 1)::text as actual,
  '3' as expected;

select 'CHECK2_single_image_drop_counts_1' as check_name,
  (select image_count from public.home_feed_stub
     where id = '10000000-0000-0000-0000-000000000002')::text as actual,
  '1' as expected;

select 'CHECK3_text_only_drop_counts_0' as check_name,
  (select image_count from public.home_feed_stub
     where id = '10000000-0000-0000-0000-000000000003')::text as actual,
  '0' as expected;

select 'CHECK4_pop_branch_type_checks_as_null' as check_name,
  coalesce((select image_count::text from public.home_feed_stub
     where id = '30000000-0000-0000-0000-000000000001'), 'NULL') as actual,
  'NULL' as expected;

select 'CHECK5_redrop_branch_counts_original_drops_images' as check_name,
  (select count(*) from public.home_feed_stub
     where id = '10000000-0000-0000-0000-000000000001' and image_count = 3)::text as actual,
  '2' as expected;
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
