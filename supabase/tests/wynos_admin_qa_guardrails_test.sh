#!/usr/bin/env bash
# Isolated Admin-only PostgreSQL QA. Never connects to production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PSQL="$(printenv PSQL || echo psql)"
DB="wyn_admin_qa_guardrails_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal; create schema cron;
create function auth.uid() returns uuid language sql stable
  as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.profiles(id uuid primary key,username text,platform_role text);
create function internal.current_platform_role() returns text language sql stable security definer set search_path='public'
  as $$ select platform_role from public.profiles where id=auth.uid() $$;
create table cron.job(jobname text primary key,active boolean not null);
create table public.food_coupon_codes(id uuid primary key,is_active boolean);
create table public.food_promo_broadcasts(id uuid primary key default gen_random_uuid(),
  title text,body text,coupon_id uuid,audience text,scheduled_at timestamptz,created_by uuid);
create table public.reports(id uuid primary key,target_type text,target_id uuid,category text,detail text,status text,created_at timestamptz);
create table public.moderation_actions(id uuid primary key,target_user_id uuid,action_type text,reason text,
  duration_days int,expires_at timestamptz,overturned_at timestamptz,created_at timestamptz,
  reviewer_id uuid,target_content_type text,target_content_id uuid);
create table public.audit_log(id bigint generated always as identity primary key,
  actor_id uuid,actor_username_snapshot text,event_type text,target_id uuid,detail jsonb,created_at timestamptz);
grant usage on schema public,auth,internal to authenticated,anon;
insert into public.profiles values
 ('00000000-0000-0000-0000-0000000000a0','admin','admin'),
 ('00000000-0000-0000-0000-0000000000b0','mod','moderator'),
 ('00000000-0000-0000-0000-0000000000c0','user','user'),
 ('00000000-0000-0000-0000-0000000000d0','partner','partner');
insert into public.reports values
 ('00000000-0000-0000-0000-000000000001','drop','00000000-0000-0000-0000-000000000002','spam','test','pending',now());
insert into public.moderation_actions(id,reviewer_id) values
 ('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000b0');
insert into public.audit_log(event_type) values ('qa');
insert into cron.job values ('wynos-food-promotions-5min',false);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261009140000_admin_qa_guardrails.sql"
run >/dev/null -c "grant select on public.moderation_queue,public.admin_user_moderation_history,public.admin_audit_log to authenticated"
ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
USER=00000000-0000-0000-0000-0000000000c0
PARTNER=00000000-0000-0000-0000-0000000000d0
NO_PROFILE=00000000-0000-0000-0000-0000000000e0
as() { run -At -c "select set_config('test.uid','$1',false)" -c "set role authenticated" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
eq() {
  local got
  got="$(as "$1" "$2")"
  [[ "$got" == "$3" ]] || { echo "FAIL $4: got '$got' expected '$3'"; exit 1; }
}
eq_db() {
  local got
  got="$(db "$1")"
  [[ "$got" == "$2" ]] || { echo "FAIL $3: got '$got' expected '$2'"; exit 1; }
}
deny() {
  local err
  if err="$(run -c "select set_config('test.uid','$1',false)" -c "set role authenticated" -c "$2" 2>&1)"; then
    echo "FAIL allowed: $3"; exit 1
  fi
  [[ "$err" == *"$4"* ]] || { echo "FAIL $3: $err"; exit 1; }
}
for view in moderation_queue admin_user_moderation_history admin_audit_log; do
  eq "$ADMIN" "select count(*) from public.$view" "1" "admin sees $view"
  eq "$MOD" "select count(*) from public.$view" "1" "moderator sees $view"
  eq "$USER" "select count(*) from public.$view" "0" "user denied $view"
  eq "$PARTNER" "select count(*) from public.$view" "0" "unknown role denied $view"
  eq "$NO_PROFILE" "select count(*) from public.$view" "0" "no-profile user denied $view"
done
eq "$ADMIN" "select public.admin_food_promo_scheduler_status()->>'active'" "false" "paused scheduler"
eq "$MOD" "select public.admin_food_promo_scheduler_status()->>'active'" "false" "moderator reads health"
deny "$USER" "select public.admin_food_promo_scheduler_status()" "user cannot read health" "Admin access required"
deny "$NO_PROFILE" "select public.admin_food_promo_scheduler_status()" "no-profile user cannot read health" "Admin access required"
deny "$ADMIN" "select public.admin_food_promo_schedule('Test','Message test')" "disabled scheduler denies enqueue" "food_promo_scheduler_disabled"
eq_db "select count(*) from public.food_promo_broadcasts" "0" "no queue insertion"
run >/dev/null -c "update cron.job set active=true where jobname='wynos-food-promotions-5min'"
eq "$ADMIN" "select public.admin_food_promo_scheduler_status()->>'active'" "true" "scheduler active"
deny "$MOD" "select public.admin_food_promo_schedule('Test','Message test')" "moderator denied" "Only admins"
deny "$NO_PROFILE" "select public.admin_food_promo_schedule('Test','Message test')" "no-profile user cannot enqueue" "Only admins"
eq "$ADMIN" "select (public.admin_food_promo_schedule('Test','Message test') is not null)::text" "true" "admin can queue"
eq_db "select count(*) from public.food_promo_broadcasts" "1" "one queue record"
eq_db "select has_function_privilege('anon','public.admin_food_promo_scheduler_status()','execute')::text" "false" "anonymous role denied"
eq_db "select has_function_privilege('anon','public.admin_food_promo_schedule(text,text,uuid,text,timestamptz)','execute')::text" "false" "anonymous cannot enqueue"
echo "PASS: Admin-only cron, queue and staff-view authorization"
