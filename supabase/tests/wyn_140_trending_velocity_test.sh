#!/usr/bin/env bash
# Regression test for WYN-140 Trending Velocity Engine.
# Loads the full schema into a throwaway local database and verifies the
# authoritative scorer, identity-capped views, self-action exclusion, deleted
# content eligibility, and idempotent score refresh.
# Requires local PostgreSQL; it never connects to dev/staging/production.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn140_trending_velocity_regression_test"
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

-- Pure authoritative scorer checks: velocity, acceleration, smoothing,
-- uniqueness, freshness/decay, reports, and manipulation caps.
insert into results values
('CHECK1_fast_recent_beats_old_cumulative',
 (public.calculate_trend_score(4000,1000,170,10,1000,1000,0,0.25,false) >
  public.calculate_trend_score(0,5,60,5,1000,1000,0,168,false))::int, 1),
('CHECK2_higher_velocity_scores_higher',
 (public.calculate_trend_score(80,20,4,5,10,10,0,1,false) >
  public.calculate_trend_score(40,10,2,5,10,10,0,1,false))::int, 1),
('CHECK3_growth_contributes',
 (public.calculate_trend_score(40,20,4,1,10,10,0,1,false) >
  public.calculate_trend_score(40,20,4,20,10,10,0,1,false))::int, 1),
('CHECK4_zero_baseline_is_finite',
 (public.calculate_trend_score(40,20,4,0,10,10,0,1,false) between 0 and 1000000)::int, 1),
('CHECK5_growth_is_bounded',
 (public.calculate_trend_score(40,20,4,0,10,10,0,1,false) < 1000000)::int, 1),
('CHECK6_unique_users_beat_concentration',
 (public.calculate_trend_score(40,20,4,5,20,20,0,1,false) >
  public.calculate_trend_score(40,20,4,5,1,20,0,1,false))::int, 1),
('CHECK7_freshness_alone_scores_zero',
 (public.calculate_trend_score(0,0,0,0,0,0,0,0,false) = 0)::int, 1),
('CHECK8_old_content_decays',
 (public.calculate_trend_score(40,20,4,5,10,10,0,1,false) >
  public.calculate_trend_score(40,20,4,5,10,10,0,168,false))::int, 1),
('CHECK9_old_content_can_resurge',
 (public.calculate_trend_score(400,100,20,1,50,50,0,168,false) >
  public.calculate_trend_score(4,1,1,1,5,5,0,1,false))::int, 1),
('CHECK10_report_penalty_is_strong',
 (public.calculate_trend_score(40,20,4,5,10,10,1,1,false) <
  public.calculate_trend_score(40,20,4,5,10,10,0,1,false) * 0.21)::int, 1),
('CHECK11_suspicious_penalty',
 (public.calculate_trend_score(40,20,4,5,2,20,0,1,true) <
  public.calculate_trend_score(40,20,4,5,2,20,0,1,false))::int, 1);

insert into auth.users (id, email)
select ('40000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
       'trend' || i || '@test.com'
from generate_series(1, 8) i;
insert into public.profiles (id, username)
select id, split_part(email, '@', 1) from auth.users;

insert into public.drops (id, author_id, image_url, caption, created_at) values
('41000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','https://example/a.jpg','fast',now()-interval '20 minutes'),
('41000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','https://example/b.jpg','deleted',now()-interval '20 minutes');

-- Four repeated views by one viewer in one 15m bucket collapse to one;
-- the creator's self-like is excluded from organic aggregates.
insert into public.drop_views (drop_id, viewer_id, created_at)
select '41000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000002', now()-interval '5 minutes'
from generate_series(1,4);
insert into public.drop_views (drop_id, viewer_id, created_at) values
('41000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003',now()-interval '4 minutes');
insert into public.drop_likes (drop_id,user_id,created_at) values
('41000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',now()-interval '3 minutes'),
('41000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000004',now()-interval '2 minutes');
update public.drops set deleted_at=now()
where id='41000000-0000-0000-0000-000000000002';

select public.refresh_trending_scores(now());
insert into results select 'CHECK12_views_are_identity_bucket_capped', qualified_views_1h, 2
from public.trending_scores where drop_id='41000000-0000-0000-0000-000000000001';
insert into results select 'CHECK13_self_engagement_excluded', likes_1h, 1
from public.trending_scores where drop_id='41000000-0000-0000-0000-000000000001';
insert into results select 'CHECK14_deleted_content_ineligible',
  count(*)::int, 0 from public.trending_scores
  where drop_id='41000000-0000-0000-0000-000000000002';

select public.refresh_trending_scores(now());
insert into results select 'CHECK15_refresh_is_idempotent', count(*)::int, 1
from public.trending_scores
where drop_id='41000000-0000-0000-0000-000000000001';

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
