#!/usr/bin/env bash
# Regression test for WYN-141 Trending to Top100 integration.
# Uses a throwaway local database and never touches deployed data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn141_top100_integration_regression_test"
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
-- Mirror the platform grants that make Supabase's auth helpers callable by
-- request roles.  Without these, PostgreSQL fails before the RLS behavior
-- under test is reached when get_top100_candidates() calls auth.uid().
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.role() to authenticated, anon;
grant select on auth.users to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
begin;

create table results (check_name text primary key, actual int, expected int);

-- Formula-level separation: Trending is capped at 25% of organic score,
-- cannot create score without organic engagement, and sustained broad quality
-- can beat a short spike even when the spike has extreme momentum.
do $$
declare
  o double precision; b double precision; t double precision;
  o2 double precision; b2 double precision; t2 double precision;
begin
  select * into o,b,t from public.calculate_top100_score(
    10,5,2,2,5,15,24,1,1000000,0,false);
  insert into results values ('CHECK1_trend_bonus_bounded', (b <= o*0.25)::int, 1);

  select * into o2,b2,t2 from public.calculate_top100_score(
    0,0,0,0,0,0,0,1,1000000,0,false);
  insert into results values ('CHECK2_trending_alone_cannot_create_rank', (t2=0)::int, 1);

  select * into o,b,t from public.calculate_top100_score(
    80,40,30,20,100,120,270,72,2,0,false);
  select * into o2,b2,t2 from public.calculate_top100_score(
    5,2,1,1,5,8,14,0.3,1000000,0,false);
  insert into results values ('CHECK3_sustained_can_beat_spike', (t>t2)::int, 1);

  select * into o,b,t from public.calculate_top100_score(
    10,5,2,2,5,15,24,1,0,0,false);
  select * into o2,b2,t2 from public.calculate_top100_score(
    10,5,2,2,5,15,24,1,100,0,false);
  insert into results values ('CHECK4_momentum_helps_same_organic', (t2>t)::int, 1);

  select * into o,b,t from public.calculate_top100_score(
    30,10,5,5,20,40,70,24,10,0,false);
  select * into o2,b2,t2 from public.calculate_top100_score(
    30,10,5,5,20,2,70,24,10,0,false);
  insert into results values ('CHECK5_unique_audience_wins', (t>t2)::int, 1);

  select * into o,b,t from public.calculate_top100_score(
    30,10,5,5,20,40,70,24,10,0,false);
  select * into o2,b2,t2 from public.calculate_top100_score(
    30,10,5,5,20,40,70,24,10,1,false);
  insert into results values ('CHECK6_reports_strongly_reduce', (t2<t*0.21)::int, 1);
end
$$;

insert into auth.users (id,email)
select ('50000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
       'top' || i || '@test.com' from generate_series(1,8) i;
insert into public.profiles (id,username,created_at)
select id,split_part(email,'@',1),now()-interval '30 days' from auth.users;

insert into public.drops (id,author_id,image_url,caption,created_at) values
('51000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','https://example/a.jpg','spike',now()-interval '20 minutes'),
('51000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000001','https://example/b.jpg','sustained',now()-interval '3 days'),
('51000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','https://example/c.jpg','self only',now()-interval '1 day');

-- Spike is a Phase 2 candidate but still needs genuine organic participation.
insert into public.trending_scores (
  drop_id,creator_id,trend_score,observed_at,content_age_hours
) values
('51000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',1000000,now(),0.3);

insert into public.drop_likes (drop_id,user_id,created_at) values
('51000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002',now()-interval '5 minutes'),
('51000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001',now()-interval '1 hour');
insert into public.redrops (drop_id,redropper_id,created_at)
select '51000000-0000-0000-0000-000000000002',
 ('50000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
 now()-interval '2 days' from generate_series(2,8) i;
insert into public.drop_comments (drop_id,author_id,text_content,created_at)
select '51000000-0000-0000-0000-000000000002',
 ('50000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
 'quality comment',now()-interval '1 day' from generate_series(2,8) i;

-- Repeated views in one hour from one identity collapse to one Top100 view.
insert into public.drop_views (drop_id,viewer_id,created_at)
select '51000000-0000-0000-0000-000000000001',
 '50000000-0000-0000-0000-000000000003',now()-interval '4 minutes'
from generate_series(1,20);

select public.refresh_top100_scores(now());
insert into results select 'CHECK7_trending_candidate_enters_pool',count(*)::int,1
from public.top100_scores where drop_id='51000000-0000-0000-0000-000000000001';
insert into results select 'CHECK8_trending_not_automatic_number_one',
 (select current_rank from public.top100_scores where drop_id='51000000-0000-0000-0000-000000000001'),2;
insert into results select 'CHECK9_sustained_is_number_one',
 (select current_rank from public.top100_scores where drop_id='51000000-0000-0000-0000-000000000002'),1;
insert into results select 'CHECK10_views_are_hourly_identity_capped',qualified_views_7d,1
from public.top100_scores where drop_id='51000000-0000-0000-0000-000000000001';
insert into results select 'CHECK11_self_only_content_is_excluded',count(*)::int,0
from public.top100_scores where drop_id='51000000-0000-0000-0000-000000000003';

create temporary table score_before as
select drop_id,top100_score from public.top100_scores;
select public.refresh_top100_scores(now());
insert into results select 'CHECK12_refresh_does_not_inflate_score',
 count(*)::int,0 from public.top100_scores current
join score_before old using(drop_id)
where current.top100_score <> old.top100_score;
insert into results select 'CHECK13_refresh_does_not_duplicate_rows',
 count(*)::int,2 from public.top100_scores;

-- Distribution/impression tables are not dependencies of the refresh formula.
insert into results select 'CHECK14_no_impression_feedback_loop',
 (position('analytics_events' in pg_get_functiondef(
   'public.refresh_top100_scores(timestamptz)'::regprocedure))=0)::int,1;
insert into results select 'CHECK15_hard_restriction_checked',
 (position('is_posting_blocked' in pg_get_functiondef(
   'public.refresh_top100_scores(timestamptz)'::regprocedure))>0)::int,1;

with inserted as (
  insert into public.drops (author_id,image_url,caption,created_at)
  select '50000000-0000-0000-0000-000000000001',
    'https://example/extra.jpg','candidate-' || i,now()-interval '1 day'
  from generate_series(1,105) i
  returning id,author_id
), numbered as (
  select id,author_id,row_number() over(order by id)::integer as n from inserted
)
insert into public.top100_scores (
  drop_id,creator_id,top100_score,organic_score,trend_bonus,current_rank,
  first_entered_at,observed_at
)
select id,author_id,0.1,0.1,0,2+n,now(),now() from numbered;
insert into results select 'CHECK16_candidate_pool_can_exceed_100',
 (count(*)>100)::int,1 from public.top100_scores;

set role authenticated;
set request.jwt.claim.sub='50000000-0000-0000-0000-000000000002';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK17_result_is_capped_at_100',count(*)::int,100
from public.get_top100_candidates(1000);
reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.role;

select check_name,actual,expected from results order by check_name;
commit;
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
