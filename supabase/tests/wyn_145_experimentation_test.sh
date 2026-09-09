#!/usr/bin/env bash
# Regression test for WYN-145 Experimentation & A/B Testing.
# Uses a throwaway local database and never touches deployed data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn145_experimentation_regression_test"
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

cat > "$WORK_DIR/10_assert.sql" <<'SQL'
\pset tuples_only on
\pset format unaligned
\set ON_ERROR_STOP on
begin;
create table results(name text primary key,actual int,expected int);
insert into auth.users(id,email) select
 ('70000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'experiment'||i||'@test.com' from generate_series(1,30)i;
insert into public.profiles(id,username) select id,split_part(email,'@',1)
from auth.users;

insert into results select 'CHECK1_stable_hash',
 (internal.experiment_bucket('mix',1,'70000000-0000-0000-0000-000000000001')=
  internal.experiment_bucket('mix',1,'70000000-0000-0000-0000-000000000001'))::int,1;
insert into results select 'CHECK2_version_rebuckets',
 (internal.experiment_bucket('mix',1,'70000000-0000-0000-0000-000000000001')<>
  internal.experiment_bucket('mix',2,'70000000-0000-0000-0000-000000000001'))::int,1;
insert into results select 'CHECK3_users_distribute',
 (count(distinct internal.experiment_bucket('mix',1,id)/5000)>1)::int,1
from public.profiles;

insert into public.feed_experiments(experiment_key,version,status,start_at,end_at,
 allocation_basis_points,primary_metric,secondary_metrics)
values('home_mix',1,'draft',now()-interval '1 hour',now()+interval '1 day',
 10000,'qualified_view_rate',array['hide_rate','report_rate']);
insert into public.feed_experiment_variants values(
 'home_mix',1,'treatment',10000,
 '{"home.source_mix":{"following":30,"recommended":25,"trending":10,"latest":10,"club":10,"new_creator":10,"exploration":5}}');
update public.feed_experiments set status='active'
where experiment_key='home_mix' and version=1;

set role authenticated;
set request.jwt.claim.sub='70000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
create temporary table resolutions as
select public.resolve_home_feed_experiments('home') first,
 public.resolve_home_feed_experiments('home') second;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
insert into results select 'CHECK4_same_assignment_repeated',(first=second)::int,1
from resolutions;
insert into results select 'CHECK5_treatment_applied',
 ((first->'home.source_mix'->>'following')::int=30)::int,1 from resolutions;
insert into results select 'CHECK5A_assignment_alone_not_exposure',count(*)::int,0
from public.feed_experiment_exposures;
set role authenticated;
set request.jwt.claim.sub='70000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
select public.record_home_feed_experiment_exposures(
 array['home_mix:v1:treatment'],'home');
select public.record_home_feed_experiment_exposures(
 array['home_mix:v1:treatment'],'home');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
insert into results select 'CHECK6_unique_exposure_dedup',
 (count(*)=1 and max(request_count)=2)::int,1
from public.feed_experiment_exposures where experiment_key='home_mix';

-- Assignment alone has no side effect; outcomes require a prior exposure.
insert into public.drops(id,author_id,caption) values(
 '71000000-0000-0000-0000-000000000001',
 '70000000-0000-0000-0000-000000000003','#test');
insert into public.drop_likes(drop_id,user_id) values(
 '71000000-0000-0000-0000-000000000001',
 '70000000-0000-0000-0000-000000000002');
insert into results select 'CHECK7_no_outcome_without_exposure',count(*)::int,0
from public.feed_experiment_outcomes;
insert into public.drop_likes(drop_id,user_id) values(
 '71000000-0000-0000-0000-000000000001',
 '70000000-0000-0000-0000-000000000001');
insert into results select 'CHECK7A_outcome_after_exposure_attributed',
 count(*)::int,1 from public.feed_experiment_outcomes where outcome_type='like';

-- Invalid totals fail activation and production remains available.
insert into public.feed_experiments values(
 'invalid',1,'draft',now()-interval '1 hour',now()+interval '1 day',10000,
 array['personalized'],null,array[]::text[],now(),now());
insert into public.feed_experiment_variants values('invalid',1,'a',4000,'{}'),
 ('invalid',1,'b',4000,'{}');
do $$ begin
  begin update public.feed_experiments set status='active'
    where experiment_key='invalid';
  exception when others then null; end;
end $$;
insert into results select 'CHECK8_invalid_weights_fail_closed',
 (status='draft')::int,1 from public.feed_experiments where experiment_key='invalid';
insert into public.feed_experiments values(
 'invalid_config',1,'draft',now()-interval '1 hour',now()+interval '1 day',10000,
 array['personalized'],null,array[]::text[],now(),now());
insert into public.feed_experiment_variants values(
 'invalid_config',1,'bad',10000,
 '{"home.source_mix":{"following":-1,"recommended":21,"trending":10,"latest":10,"club":10,"new_creator":10,"exploration":40}}');
do $$ begin
  begin update public.feed_experiments set status='active'
    where experiment_key='invalid_config';
  exception when others then null; end;
end $$;
insert into results select 'CHECK8A_invalid_config_fail_closed',
 (status='draft')::int,1 from public.feed_experiments
 where experiment_key='invalid_config';

-- Future/expired/zero-rollout definitions never apply.
insert into public.feed_experiments values
 ('future',1,'draft',now()+interval '1 day',now()+interval '2 days',10000,
  array['zero_history','sparse','learning','personalized'],null,array[]::text[],now(),now()),
 ('expired',1,'draft',now()-interval '2 days',now()-interval '1 day',10000,
  array['zero_history','sparse','learning','personalized'],null,array[]::text[],now(),now()),
 ('zero_rollout',1,'draft',now()-interval '1 day',now()+interval '1 day',0,
  array['zero_history','sparse','learning','personalized'],null,array[]::text[],now(),now());
insert into public.feed_experiment_variants values
 ('future',1,'a',10000,'{}'),('expired',1,'a',10000,'{}'),
 ('zero_rollout',1,'a',10000,'{}');
update public.feed_experiments set status='active'
where experiment_key in('future','expired','zero_rollout');
insert into results select 'CHECK9_boundaries_and_rollout',
 (count(*)=0)::int,1 from public.feed_experiment_exposures
where experiment_key in('future','expired','zero_rollout');

-- Overlapping config ownership is rejected; independent keys coexist.
insert into public.feed_experiments values
 ('conflict',1,'draft',now()-interval '1 hour',now()+interval '1 day',10000,
  array['zero_history','sparse','learning','personalized'],null,array[]::text[],now(),now()),
 ('independent',1,'draft',now()-interval '1 hour',now()+interval '1 day',10000,
  array['zero_history','sparse','learning','personalized'],null,array[]::text[],now(),now());
insert into public.feed_experiment_variants values
 ('conflict',1,'a',10000,'{"home.source_mix":{"following":35,"recommended":20,"trending":10,"latest":10,"club":10,"new_creator":10,"exploration":5}}'),
 ('independent',1,'a',10000,'{"fatigue.creator_factor":0.7}');
do $$ begin
  begin update public.feed_experiments set status='active'
    where experiment_key='conflict'; exception when others then null; end;
end $$;
update public.feed_experiments set status='active' where experiment_key='independent';
insert into results select 'CHECK10_conflict_rejected_independent_allowed',
 (count(*) filter(where experiment_key='conflict' and status='draft')=1
  and count(*) filter(where experiment_key='independent' and status='active')=1)::int,1
from public.feed_experiments;

-- Kill switch immediately restores production once all active experiments pause.
update public.feed_experiments set status='paused'
where experiment_key in('home_mix','independent');
set role authenticated;
set request.jwt.claim.sub='70000000-0000-0000-0000-000000000001';
set request.jwt.claim.role='authenticated';
insert into results select 'CHECK11_pause_returns_production',
 (public.resolve_home_feed_experiments('home')='{"_assignments": []}'::jsonb)::int,1;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- Ordinary clients cannot edit definitions or inspect telemetry.
insert into results select 'CHECK12_rls_private',
 ((has_table_privilege('authenticated','public.feed_experiments','INSERT')=false
  and has_table_privilege('authenticated','public.feed_experiment_exposures','SELECT')=false)::int),1;
insert into results select 'CHECK13_no_active_seed',
 (count(*)=0)::int,1 from public.feed_experiments
where experiment_key not in('home_mix','future','expired','zero_rollout',
 'invalid','invalid_config','conflict','independent');

select name,actual,expected from results order by name;
rollback;
SQL

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi
for file in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/10_assert.sql"; do
  if ! run_psql "$DB_NAME" "$file"; then
    cat "$WORK_DIR/psql.out" >&2; dropdb_any "$DB_NAME"; exit 1
  fi
done
cat "$WORK_DIR/psql.out"
FAILURES=0
while IFS='|' read -r name actual expected; do
  case "$name" in CHECK*) [ "$actual" = "$expected" ] || { echo "FAIL: $name"; FAILURES=$((FAILURES+1)); };; esac
done < "$WORK_DIR/psql.out"
dropdb_any "$DB_NAME"
[ "$FAILURES" -eq 0 ] || exit 1
echo "ALL CHECKS PASSED"
