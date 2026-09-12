#!/usr/bin/env bash
# Regression test for WYN-143 Cold Start & New User Feed.
# Uses a throwaway local database and never touches deployed data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn143_cold_start_regression_test"
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
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.role() to authenticated, anon;
grant usage on schema storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
begin;
create table results(check_name text primary key,actual int,expected int);

insert into auth.users(id,email)
select ('60000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'personal' || i || '@test.com' from generate_series(1,10)i;
insert into public.profiles(id,username,created_at)
select id,split_part(email,'@',1),now()-interval '1 year' from auth.users;
insert into public.drops(id,author_id,image_url,caption,created_at) values
('61000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','https://example/g.jpg','#gaming setup',now()-interval '1 hour'),
('61000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000004','https://example/f.jpg','#fashion look',now()-interval '1 hour');

-- Same candidates, opposite actions: profiles must diverge.
insert into public.drop_likes(drop_id,user_id,created_at) values
('61000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001',now()),
('61000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000002',now());
insert into results select 'CHECK1_topic_affinity_created',count(*)::int,2
from public.user_affinities where dimension_type='topic';
insert into results select 'CHECK2_profiles_are_user_specific',
 (count(distinct user_id)=2)::int,1 from public.user_affinities
where dimension_type='topic';

set role authenticated;
set request.jwt.claim.sub='60000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK2A_gaming_user_prefers_gaming',
  (((select (row_data->'feed_source_scores'->>'recommended')::float
      from public.get_wynos_ranked_feed() where row_data->>'id'=
        '61000000-0000-0000-0000-000000000001')
    >
    (select (row_data->'feed_source_scores'->>'recommended')::float
      from public.get_wynos_ranked_feed() where row_data->>'id'=
        '61000000-0000-0000-0000-000000000002'))::int),1;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='60000000-0000-0000-0000-000000000002';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK2B_fashion_user_prefers_fashion',
  (((select (row_data->'feed_source_scores'->>'recommended')::float
      from public.get_wynos_ranked_feed() where row_data->>'id'=
        '61000000-0000-0000-0000-000000000002')
    >
    (select (row_data->'feed_source_scores'->>'recommended')::float
      from public.get_wynos_ranked_feed() where row_data->>'id'=
        '61000000-0000-0000-0000-000000000001'))::int),1;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- Save (4) and ReDrop (5) are stronger than Like (2).
insert into public.saves(user_id,content_type,content_id,created_at) values
('60000000-0000-0000-0000-000000000005','drop','61000000-0000-0000-0000-000000000001',now());
insert into public.redrops(drop_id,redropper_id,created_at) values
('61000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000006',now());
insert into results select 'CHECK3_save_stronger_than_like',
 ((select recent_score from public.user_affinities where user_id='60000000-0000-0000-0000-000000000005' and dimension_type='topic')>
  (select recent_score from public.user_affinities where user_id='60000000-0000-0000-0000-000000000001' and dimension_type='topic'))::int,1;
insert into results select 'CHECK4_share_stronger_than_save',
 ((select recent_score from public.user_affinities where user_id='60000000-0000-0000-0000-000000000006' and dimension_type='topic')>
  (select recent_score from public.user_affinities where user_id='60000000-0000-0000-0000-000000000005' and dimension_type='topic'))::int,1;

insert into public.follows(follower_id,following_id,created_at) values
('60000000-0000-0000-0000-000000000007','60000000-0000-0000-0000-000000000003',now());
insert into results select 'CHECK5_follow_is_strong_creator_prior',
 (recent_score=8)::int,1 from public.user_affinities
where user_id='60000000-0000-0000-0000-000000000007'
 and dimension_type='creator' and dimension_key='60000000-0000-0000-0000-000000000003';

-- One skip is weak; repetition accumulates; explicit negative is strong.
insert into public.feed_signals(user_id,signal_type,target_type,target_id,created_at) values
('60000000-0000-0000-0000-000000000008','fast_skip','drop','61000000-0000-0000-0000-000000000001',now()),
('60000000-0000-0000-0000-000000000008','fast_skip','drop','61000000-0000-0000-0000-000000000001',now()+interval '1 second'),
('60000000-0000-0000-0000-000000000008','fast_skip','drop','61000000-0000-0000-0000-000000000001',now()+interval '2 seconds');
insert into results select 'CHECK6_repeated_skips_accumulate',
 (recent_score < -2.9)::int,1 from public.user_affinities
where user_id='60000000-0000-0000-0000-000000000008' and dimension_type='topic';
insert into public.feed_signals(user_id,signal_type,target_type,target_id,created_at) values
('60000000-0000-0000-0000-000000000008','not_interested','drop','61000000-0000-0000-0000-000000000002',now());
insert into results select 'CHECK7_not_interested_is_strong_negative',
 (recent_score=-10)::int,1 from public.user_affinities
where user_id='60000000-0000-0000-0000-000000000008'
 and dimension_type='topic' and dimension_key='fashion';

-- Replay the exact event key; count and values must not move.
select internal.learn_from_drop('replay-fixture','60000000-0000-0000-0000-000000000001',
 '61000000-0000-0000-0000-000000000001',2,now(),null);
create temporary table before_replay as select * from public.user_affinities
where user_id='60000000-0000-0000-0000-000000000001' and dimension_type='topic';
select internal.learn_from_drop('replay-fixture','60000000-0000-0000-0000-000000000001',
 '61000000-0000-0000-0000-000000000001',2,now(),null);
insert into results select 'CHECK8_event_replay_is_idempotent',
 count(*)::int,0 from public.user_affinities current join before_replay old
 using(user_id,dimension_type,dimension_key)
 where current.signal_count<>old.signal_count or current.recent_score<>old.recent_score;

-- Decay and hard bounds are properties of the normalized client-safe view.
insert into results select 'CHECK9_effective_scores_are_bounded',
 count(*)::int,0 from public.my_effective_affinities
where abs(effective_score)>1;
insert into results select 'CHECK10_recent_score_exceeds_long_term_increment',
 count(*)::int,0 from public.user_affinities
where abs(long_term_score)>abs(recent_score);
select internal.apply_affinity_signal(
 '60000000-0000-0000-0000-000000000009','topic','travel',5,
 now()-interval '60 days');
select internal.apply_affinity_signal(
 '60000000-0000-0000-0000-000000000010','topic','travel',5,now());
insert into results select 'CHECK10A_recent_interest_outweighs_stale',
 (((select recent_score * power(0.5,
       extract(epoch from (now()-updated_at))/3600/168)
     from public.user_affinities
     where user_id='60000000-0000-0000-0000-000000000009'
       and dimension_type='topic' and dimension_key='travel')
   <
   (select recent_score from public.user_affinities
     where user_id='60000000-0000-0000-0000-000000000010'
       and dimension_type='topic' and dimension_key='travel'))::int),1;
insert into results select 'CHECK10B_long_term_interest_survives_decay',
 (long_term_score>0)::int,1 from public.user_affinities
where user_id='60000000-0000-0000-0000-000000000009'
 and dimension_type='topic' and dimension_key='travel';
insert into results select 'CHECK11_impression_is_not_a_learning_signal',
 (position('impression' in pg_get_constraintdef(oid))=0)::int,1
from pg_constraint where conname='feed_signals_signal_type_check';

-- Production ranking no longer scans raw interaction history and emits
-- per-source scores without exposing raw affinity values.
insert into results select 'CHECK12_no_request_time_interaction_scan',
 (position('my_interactions' in pg_get_functiondef(
  'public.get_wynos_ranked_feed()'::regprocedure))=0)::int,1;
insert into results select 'CHECK13_precomputed_affinity_join',
 (position('my_effective_affinities' in pg_get_functiondef(
  'public.get_wynos_ranked_feed()'::regprocedure))>0)::int,1;
insert into results select 'CHECK14_global_trending_not_personalized',
 (position('my_effective_affinities' in pg_get_functiondef(
  'public.get_trending_candidates(integer)'::regprocedure))=0)::int,1;
insert into results select 'CHECK15_top100_not_personalized',
 (position('my_effective_affinities' in pg_get_functiondef(
  'public.get_top100_candidates(integer)'::regprocedure))=0)::int,1;

-- Maturity is signal-based, bounded, and changes gradually.
set role authenticated;
set request.jwt.claim.sub='60000000-0000-0000-0000-000000000004';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK16_zero_history_without_profile_data',
  (maturity_state='zero_history' and confidence=0)::int,1
from public.get_my_personalization_maturity();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='60000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK17_one_like_does_not_overfit',
  (confidence>0 and confidence<0.25 and maturity_state='sparse')::int,1
from public.get_my_personalization_maturity();
insert into results select 'CHECK18_feed_emits_safe_maturity_not_confidence',
  (count(*)>0 and bool_and(row_data ? 'feed_maturity_state')
    and bool_and(not row_data ? 'personalization_confidence'))::int,1
from public.get_wynos_ranked_feed();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

insert into results select 'CHECK19_global_contracts_remain_unpersonalized',
 ((position('get_my_personalization_maturity' in pg_get_functiondef(
   'public.get_trending_candidates(integer)'::regprocedure))=0
   and position('get_my_personalization_maturity' in pg_get_functiondef(
   'public.get_top100_candidates(integer)'::regprocedure))=0)::int),1;
insert into results select 'CHECK20_top100_is_bounded_quality_signal',
 ((position('top100_quality_bonus' in pg_get_functiondef(
   'public.get_wynos_ranked_feed()'::regprocedure))>0
   and position('(101 - t100.current_rank) / 10.0' in pg_get_functiondef(
   'public.get_wynos_ranked_feed()'::regprocedure))>0)::int),1;
insert into results select 'CHECK21_no_impression_confidence',
 (position('impression' in pg_get_functiondef(
   'public.get_my_personalization_maturity()'::regprocedure))=0)::int,1;

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
