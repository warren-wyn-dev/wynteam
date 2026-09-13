#!/usr/bin/env bash
# WYN-157 regression: every function covered by the system-audit search-path
# hardening must have an explicit search_path after the migration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn157_function_search_path.sql"
DB_NAME="wyn157_function_search_path_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

psql_file() {
  local db="$1" file="$2"
  psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null 2>&1 \
    || sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null
}
createdb_any() {
  createdb "$1" >/dev/null 2>&1 || sudo -u postgres createdb "$1" >/dev/null
}
dropdb_any() {
  dropdb --if-exists "$1" >/dev/null 2>&1 \
    || sudo -u postgres dropdb --if-exists "$1" >/dev/null 2>&1 \
    || true
}

cat > "$WORK_DIR/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.role', true), '') $$;
create schema if not exists storage;
create table if not exists storage.buckets (id text primary key, name text not null, public boolean not null default false);
create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public, storage to authenticated, anon;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
do $$
declare
  missing_count int;
  wrong_path_count int;
begin
  select count(*) into missing_count
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname,p.proname) in (
    ('internal','experiment_bucket'),
    ('internal','repetition_adjust_source_scores'),
    ('internal','get_wynos_ranked_feed_base_v1'),
    ('public','prevent_cross_conversation_reply'),
    ('public','valid_poll_options'),
    ('public','valid_draft_poll_options'),
    ('public','get_wynos_ranked_feed'),
    ('public','club_event_rsvp_counts'),
    ('public','generate_referral_code'),
    ('public','set_referral_code_on_profile'),
    ('public','prevent_cross_channel_message_reply'),
    ('public','calculate_feed_quality_score'),
    ('public','calculate_trend_score'),
    ('public','get_trending_candidates'),
    ('public','calculate_top100_score'),
    ('public','get_top100_candidates')
  ) and p.proconfig is null;

  if missing_count <> 0 then
    raise exception '% audited function(s) still have no proconfig', missing_count;
  end if;

  select count(*) into wrong_path_count
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname,p.proname) in (
    ('internal','experiment_bucket'),
    ('internal','repetition_adjust_source_scores'),
    ('internal','get_wynos_ranked_feed_base_v1'),
    ('public','prevent_cross_conversation_reply'),
    ('public','valid_poll_options'),
    ('public','valid_draft_poll_options'),
    ('public','get_wynos_ranked_feed'),
    ('public','club_event_rsvp_counts'),
    ('public','generate_referral_code'),
    ('public','set_referral_code_on_profile'),
    ('public','prevent_cross_channel_message_reply'),
    ('public','calculate_feed_quality_score'),
    ('public','calculate_trend_score'),
    ('public','get_trending_candidates'),
    ('public','calculate_top100_score'),
    ('public','get_top100_candidates')
  ) and not exists (
    select 1 from unnest(p.proconfig) cfg
    where cfg = 'search_path=pg_catalog, public, internal, auth, pg_temp'
  );

  if wrong_path_count <> 0 then
    raise exception '% audited function(s) have an unexpected search_path', wrong_path_count;
  end if;
end $$;
SQL

echo "== WYN-157 function search_path regression =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCHEMA_FILE"
psql_file "$DB_NAME" "$MIGRATION_FILE"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
