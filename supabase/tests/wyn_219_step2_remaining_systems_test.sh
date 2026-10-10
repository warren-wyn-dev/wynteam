#!/usr/bin/env bash
# WYN-219 Phase 2 step 2 for the remaining systems:
#   supabase/migrations/2026101017{0000_merchant,0100_food,0200_social,0300_account,0400_central}_*.sql
#
#   1. Every one of the 41 rewritten PL/pgSQL admin RPCs lets through exactly the
#      right callers: the super admin; holders of that system at the needed level
#      (edit includes view); moderators only for Social (seeded social:edit);
#      dashboards for anyone with any permission. Other platform admins and plain
#      users are refused with the function's own authorization error.
#   2. public.food_is_platform_admin() is food:edit or merchant:edit.
#   3. The audit log view shows rows to the super admin only.
#   4. SQL functions, views and policies use the expected permission; no live
#      role check remains in any rewritten object.
#   5. Each migration is idempotent; rolling all five back restores the role checks.
#
# "Pass" = the role check let the call through (it may then fail on data this
# test does not load); "refused" = the function raised its own auth error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
FOUNDATION_FILE="$SCRIPT_DIR/../migrations/20261010150000_wyn219_admin_permissions_foundation.sql"
MIG_DIR="$SCRIPT_DIR/../migrations"
RB_DIR="$SCRIPT_DIR/../rollbacks"
SYSTEMS="merchant food social account central"
mig_for() { case "$1" in merchant) echo 20261010170000_wyn219_step2_merchant_permissions;; food) echo 20261010170100_wyn219_step2_food_permissions;; social) echo 20261010170200_wyn219_step2_social_permissions;; account) echo 20261010170300_wyn219_step2_account_permissions;; central) echo 20261010170400_wyn219_step2_central_permissions;; esac; }
DB_NAME="wyn_219_step2_remaining_test"
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
  email text,
  last_sign_in_at timestamptz
);

-- Supabase keeps one row per signed-in device; updated_at moves when the
-- app refreshes its session.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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
grant select, insert, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF


cat > "$WORK_DIR/05_pre.sql" <<'EOF'
\set ON_ERROR_STOP on
-- %rowtype targets used by the Food/Merchant RPCs (resolved before the role check runs).
create table if not exists public.food_stores (id uuid primary key);
create table if not exists public.food_orders (id uuid primary key);
create table if not exists public.food_ad_topups (id uuid primary key);
create table if not exists public.food_platform_campaigns (id uuid primary key);
create table if not exists public.merchant_applications (id uuid primary key);
create table if not exists public.merchant_memberships (id uuid primary key);
insert into storage.buckets (id, name) values ('appeal-evidence', 'appeal-evidence') on conflict do nothing;

-- schema.sql has drifted from production for some of these objects (e.g.
-- admin_dashboard_metrics returns more columns in production). Drop the
-- schema.sql versions so the migrations create the production definitions.
drop view if exists public.moderation_queue, public.admin_user_moderation_history, public.admin_audit_log cascade;
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = any (array['admin_activity_trend', 'admin_ad_overview', 'admin_apply_user_action', 'admin_count_inactive_users', 'admin_dashboard_metrics', 'admin_dashboard_trends', 'admin_feed_algorithm_dashboard', 'admin_food_coupon_list', 'admin_food_coupon_set_active', 'admin_food_first_order_set_active', 'admin_food_issue_coupon', 'admin_food_order_detail', 'admin_food_orders', 'admin_food_overview', 'admin_food_promo_cancel', 'admin_food_promo_list', 'admin_food_promo_schedule', 'admin_food_store_detail', 'admin_food_stores', 'admin_get_drop', 'admin_merchant_applications', 'admin_platform_campaigns', 'admin_platform_owed', 'admin_remove_drop', 'admin_restore_drop', 'admin_review_ad_topup', 'admin_review_merchant_application', 'admin_search_drops', 'admin_send_announcement', 'admin_send_inactive_reminder', 'admin_set_ad_account_status', 'admin_set_food_store_member_active', 'admin_set_food_store_suspension', 'admin_settle_platform_store', 'admin_signup_counts', 'admin_unban_user', 'admin_update_ad_settings', 'admin_upsert_platform_campaign', 'admin_user_directory', 'apply_moderation_action', 'decide_appeal', 'food_is_platform_admin', 'get_message_for_moderation', 'send_system_notification'])
  loop
    execute format('drop function %s cascade', r.sig);
  end loop;
end $$;

insert into auth.users (id, email) values
  ('92200000-0000-0000-0000-000000000001', 'sa@test.invalid'),
  ('92200000-0000-0000-0000-000000000002', 'adm@test.invalid'),
  ('92200000-0000-0000-0000-000000000003', 'mod@test.invalid'),
  ('92200000-0000-0000-0000-000000000004', 'usr@test.invalid'),
  ('92200000-0000-0000-0000-000000000011', 'm_v@test.invalid'),
  ('92200000-0000-0000-0000-000000000012', 'm_e@test.invalid'),
  ('92200000-0000-0000-0000-000000000013', 'f_v@test.invalid'),
  ('92200000-0000-0000-0000-000000000014', 'f_e@test.invalid'),
  ('92200000-0000-0000-0000-000000000015', 's_v@test.invalid'),
  ('92200000-0000-0000-0000-000000000016', 's_e@test.invalid'),
  ('92200000-0000-0000-0000-000000000017', 'a_v@test.invalid'),
  ('92200000-0000-0000-0000-000000000018', 'a_e@test.invalid');
insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('92200000-0000-0000-0000-000000000001', 'r_sa', 'sa', 'admin', false),
  ('92200000-0000-0000-0000-000000000002', 'r_adm', 'adm', 'admin', false),
  ('92200000-0000-0000-0000-000000000003', 'r_mod', 'mod', 'moderator', false),
  ('92200000-0000-0000-0000-000000000004', 'r_usr', 'usr', 'user', false),
  ('92200000-0000-0000-0000-000000000011', 'r_m_v', 'm_v', 'user', false),
  ('92200000-0000-0000-0000-000000000012', 'r_m_e', 'm_e', 'user', false),
  ('92200000-0000-0000-0000-000000000013', 'r_f_v', 'f_v', 'user', false),
  ('92200000-0000-0000-0000-000000000014', 'r_f_e', 'f_e', 'user', false),
  ('92200000-0000-0000-0000-000000000015', 'r_s_v', 's_v', 'user', false),
  ('92200000-0000-0000-0000-000000000016', 'r_s_e', 's_e', 'user', false),
  ('92200000-0000-0000-0000-000000000017', 'r_a_v', 'a_v', 'user', false),
  ('92200000-0000-0000-0000-000000000018', 'r_a_e', 'a_e', 'user', false);
EOF

cat > "$WORK_DIR/07_grants.sql" <<'EOF'
\set ON_ERROR_STOP on
insert into internal.platform_super_admins (user_id) values ('92200000-0000-0000-0000-000000000001');
insert into public.admin_permissions (user_id, system, level) values
  ('92200000-0000-0000-0000-000000000011', 'merchant', 'view'),
  ('92200000-0000-0000-0000-000000000012', 'merchant', 'edit'),
  ('92200000-0000-0000-0000-000000000013', 'food', 'view'),
  ('92200000-0000-0000-0000-000000000014', 'food', 'edit'),
  ('92200000-0000-0000-0000-000000000015', 'social', 'view'),
  ('92200000-0000-0000-0000-000000000016', 'social', 'edit'),
  ('92200000-0000-0000-0000-000000000017', 'account', 'view'),
  ('92200000-0000-0000-0000-000000000018', 'account', 'edit');
insert into public.audit_log (actor_id, event_type, detail) values (null, 'system_notification_sent', '{}'::jsonb);
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
create table results (check_name text primary key, actual int, expected int);
grant all on results to authenticated;

create temp table calls (fn text, system text, level text, sql text, refusal text);
insert into calls values
  ('admin_merchant_applications', 'merchant', 'view', 'select public.admin_merchant_applications(null::text, null::integer)', 'Not authorized'),
  ('admin_review_merchant_application', 'merchant', 'edit', 'select public.admin_review_merchant_application(null::uuid, null::text, null::text)', 'Only admins can review merchant applications'),
  ('admin_food_overview', 'food', 'view', 'select public.admin_food_overview()', 'Not authorized'),
  ('admin_food_stores', 'food', 'view', 'select public.admin_food_stores(null::text)', 'Not authorized'),
  ('admin_food_store_detail', 'food', 'view', 'select public.admin_food_store_detail(null::uuid)', 'Not authorized'),
  ('admin_platform_campaigns', 'food', 'view', 'select public.admin_platform_campaigns()', 'Not authorized'),
  ('admin_food_promo_list', 'food', 'view', 'select public.admin_food_promo_list()', 'Admin access required'),
  ('admin_food_order_detail', 'food', 'edit', 'select public.admin_food_order_detail(null::uuid)', 'Only admins can view Food orders'),
  ('admin_food_orders', 'food', 'edit', 'select public.admin_food_orders(null::uuid, null::text, null::text, null::integer)', 'Only admins can view Food orders'),
  ('admin_set_food_store_member_active', 'food', 'edit', 'select public.admin_set_food_store_member_active(null::uuid, null::uuid, null::boolean)', 'Only admins can change store teams'),
  ('admin_set_food_store_suspension', 'food', 'edit', 'select public.admin_set_food_store_suspension(null::uuid, null::boolean, null::text)', 'Only admins can suspend stores'),
  ('admin_food_coupon_set_active', 'food', 'edit', 'select public.admin_food_coupon_set_active(null::uuid, null::boolean)', 'Only admins can manage WYNOS Food coupons'),
  ('admin_food_issue_coupon', 'food', 'edit', 'select public.admin_food_issue_coupon(null::uuid, null::text, null::integer, null::integer, null::timestamp with time zone, null::timestamp with time zone)', 'Only admins can manage WYNOS Food coupons'),
  ('admin_food_first_order_set_active', 'food', 'edit', 'select public.admin_food_first_order_set_active(null::boolean)', 'Only admins can manage WYNOS first-order promotions'),
  ('admin_food_promo_cancel', 'food', 'edit', 'select public.admin_food_promo_cancel(null::uuid)', 'Only admins can cancel Food promotions'),
  ('admin_food_promo_schedule', 'food', 'edit', 'select public.admin_food_promo_schedule(null::text, null::text, null::uuid, null::text, null::timestamp with time zone)', 'Only admins can send Food promotions'),
  ('admin_ad_overview', 'food', 'edit', 'select public.admin_ad_overview()', 'Only admins can manage ads'),
  ('admin_update_ad_settings', 'food', 'edit', 'select public.admin_update_ad_settings(null::numeric, null::numeric, null::text, null::text, null::boolean)', 'Only admins can manage ads'),
  ('admin_review_ad_topup', 'food', 'edit', 'select public.admin_review_ad_topup(null::uuid, null::boolean, null::text)', 'Only admins can review ad top-ups'),
  ('admin_set_ad_account_status', 'food', 'edit', 'select public.admin_set_ad_account_status(null::uuid, null::boolean, null::text)', 'Only admins can manage ads'),
  ('admin_upsert_platform_campaign', 'food', 'edit', 'select public.admin_upsert_platform_campaign(null::uuid, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::timestamp with time zone, null::timestamp with time zone, null::integer, null::numeric, null::boolean, null::boolean)', 'Only admins can manage WYNOS campaigns'),
  ('admin_settle_platform_store', 'food', 'edit', 'select public.admin_settle_platform_store(null::uuid, null::text, null::numeric, null::integer, null::text)', 'Only admins can record WYNOS campaign payouts'),
  ('admin_platform_owed', 'food', 'edit', 'select public.admin_platform_owed()', 'Only admins can view WYNOS campaign payouts'),
  ('admin_search_drops', 'social', 'view', 'select public.admin_search_drops(null::text)', 'Not authorized'),
  ('admin_get_drop', 'social', 'view', 'select public.admin_get_drop(null::uuid)', 'Not authorized'),
  ('admin_feed_algorithm_dashboard', 'social', 'view', 'select public.admin_feed_algorithm_dashboard(null::integer)', 'Not authorized'),
  ('admin_remove_drop', 'social', 'edit', 'select public.admin_remove_drop(null::uuid, null::text)', 'Not authorized'),
  ('admin_restore_drop', 'social', 'edit', 'select public.admin_restore_drop(null::uuid, null::text)', 'Not authorized'),
  ('admin_apply_user_action', 'social', 'edit', 'select public.admin_apply_user_action(null::uuid, null::text, null::text, null::integer)', 'Not authorized'),
  ('admin_unban_user', 'social', 'edit', 'select public.admin_unban_user(null::uuid, null::text)', 'Not authorized'),
  ('admin_send_announcement', 'social', 'edit', 'select public.admin_send_announcement(null::text, null::text, null::text)', 'Only admins can send announcements'),
  ('send_system_notification', 'social', 'edit', 'select public.send_system_notification(null::uuid, null::text)', 'Only admins can send system notifications'),
  ('apply_moderation_action', 'social', 'edit', 'select public.apply_moderation_action(null::uuid, null::text, null::text, null::integer)', 'Not authorized'),
  ('decide_appeal', 'social', 'edit', 'select public.decide_appeal(null::uuid, null::boolean, null::text)', 'Not authorized'),
  ('admin_user_directory', 'account', 'view', 'select public.admin_user_directory(null::text, null::text, null::text, null::integer)', 'Not permitted to view the user directory'),
  ('admin_count_inactive_users', 'account', 'edit', 'select public.admin_count_inactive_users(null::integer)', 'Only admins can send inactive reminders'),
  ('admin_send_inactive_reminder', 'account', 'edit', 'select public.admin_send_inactive_reminder(null::integer, null::text)', 'Only admins can send inactive reminders'),
  ('admin_dashboard_metrics', '*any*', 'any', 'select public.admin_dashboard_metrics()', 'Not permitted to view admin dashboard metrics'),
  ('admin_dashboard_trends', '*any*', 'any', 'select public.admin_dashboard_trends()', 'Not permitted to view admin dashboard trends'),
  ('admin_signup_counts', '*any*', 'any', 'select public.admin_signup_counts()', 'Not permitted to view signup counts'),
  ('admin_activity_trend', '*any*', 'any', 'select public.admin_activity_trend(null::integer)', 'Not permitted to view admin activity trend');
grant select on calls to authenticated;

create temp table who (label text, id uuid);
insert into who values
  ('sa', '92200000-0000-0000-0000-000000000001'),
  ('adm', '92200000-0000-0000-0000-000000000002'),
  ('mod', '92200000-0000-0000-0000-000000000003'),
  ('usr', '92200000-0000-0000-0000-000000000004'),
  ('m_v', '92200000-0000-0000-0000-000000000011'),
  ('m_e', '92200000-0000-0000-0000-000000000012'),
  ('f_v', '92200000-0000-0000-0000-000000000013'),
  ('f_e', '92200000-0000-0000-0000-000000000014'),
  ('s_v', '92200000-0000-0000-0000-000000000015'),
  ('s_e', '92200000-0000-0000-0000-000000000016'),
  ('a_v', '92200000-0000-0000-0000-000000000017'),
  ('a_e', '92200000-0000-0000-0000-000000000018');
grant select on who to authenticated;

-- 1 = let through, 0 = refused with p_refusal.
create or replace function pg_temp.passes(p_user uuid, p_sql text, p_refusal text) returns int
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    execute p_sql;
  exception when others then
    perform set_config('role', 'postgres', true);
    return case when sqlerrm = p_refusal then 0 else 1 end;
  end;
  perform set_config('role', 'postgres', true);
  return 1;
end $$;

create or replace function pg_temp.expected(p_label text, p_system text, p_level text) returns int
language sql immutable as $$
  select case
    when p_label = 'sa' then 1
    when p_label in ('adm', 'usr') then 0
    when p_system = '*any*' then 1
    when p_label = 'mod' then (p_system = 'social')::int
    when left(p_label, 1) <> left(p_system, 1) then 0
    when p_label like '%\_e' then 1
    else (p_level = 'view')::int
  end
$$;

do $$
declare c record; w record;
begin
  for w in select * from who loop
    for c in select * from calls loop
      insert into results values (format('CHECK1_%s_%s', w.label, c.fn),
        pg_temp.passes(w.id, c.sql, c.refusal), pg_temp.expected(w.label, c.system, c.level));
    end loop;
  end loop;
end $$;

-- CHECK 2: food_is_platform_admin()
create or replace function pg_temp.fipa(p_user uuid) returns int language plpgsql as $$
declare v boolean;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  v := public.food_is_platform_admin();
  perform set_config('role', 'postgres', true);
  return v::int;
end $$;
insert into results select 'CHECK2_fipa_' || label, pg_temp.fipa(id),
  case when label in ('sa', 'f_e', 'm_e') then 1 else 0 end from who;

-- CHECK 3: audit log view.
create or replace function pg_temp.audit_rows(p_user uuid) returns int language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.admin_audit_log;
  perform set_config('role', 'postgres', true);
  return least(n, 1);
end $$;
insert into results select 'CHECK3_audit_log_' || label, pg_temp.audit_rows(id),
  case when label = 'sa' then 1 else 0 end from who;

-- CHECK 4: textual checks for SQL functions, views and policies.
insert into results values
  ('CHECK4a_coupon_list_food_edit', (select count(*) from pg_proc where proname = 'admin_food_coupon_list'
     and prosrc like '%has_admin_permission(''food'', ''edit'')%')::int, 1),
  ('CHECK4b_message_for_moderation_social_view', (select count(*) from pg_proc where proname = 'get_message_for_moderation'
     and prosrc like '%has_admin_permission(''social'', ''view'')%')::int, 1),
  ('CHECK4c_moderation_queue_social_view', (select count(*) from pg_views where viewname = 'moderation_queue'
     and definition like '%has_admin_permission(''social''::text, ''view''::text)%')::int, 1),
  ('CHECK4d_moderation_history_social_view', (select count(*) from pg_views where viewname = 'admin_user_moderation_history'
     and definition like '%has_admin_permission(''social''::text, ''view''::text)%')::int, 1),
  ('CHECK4e_social_policies_on_permission', (select count(*) from pg_policies where policyname in
     ('Moderators can view all appeals', 'Moderators can view moderation action history', 'Appellants and moderators can view appeal evidence')
     and qual like '%has_admin_permission(''social''::text, ''view''::text)%')::int, 3),
  ('CHECK4f_no_live_role_check_left', (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname in (select fn from calls union all select 'admin_food_coupon_list' union all select 'get_message_for_moderation')
       and (p.prosrc ~ 'current_platform_role\(\)' or p.prosrc like '%v_reviewer_role = ''user''%')
       and p.prosrc not like '%has_admin_permission%' and p.prosrc not like '%has_any_admin_permission%')::int, 0);

select check_name, actual, expected from results order by check_name;
EOF

cat > "$WORK_DIR/20_after_rollback.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
select 'CHECK5a_rollback_restores_role_checks' as check_name,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any (array['admin_merchant_applications', 'admin_review_merchant_application', 'admin_food_overview', 'admin_food_stores', 'admin_food_store_detail', 'admin_platform_campaigns', 'admin_food_promo_list', 'admin_food_order_detail', 'admin_food_orders', 'admin_set_food_store_member_active', 'admin_set_food_store_suspension', 'admin_food_coupon_set_active', 'admin_food_issue_coupon', 'admin_food_first_order_set_active', 'admin_food_promo_cancel', 'admin_food_promo_schedule', 'admin_ad_overview', 'admin_update_ad_settings', 'admin_review_ad_topup', 'admin_set_ad_account_status', 'admin_upsert_platform_campaign', 'admin_settle_platform_store', 'admin_platform_owed', 'admin_search_drops', 'admin_get_drop', 'admin_feed_algorithm_dashboard', 'admin_remove_drop', 'admin_restore_drop', 'admin_apply_user_action', 'admin_unban_user', 'admin_send_announcement', 'send_system_notification', 'apply_moderation_action', 'decide_appeal', 'admin_user_directory', 'admin_count_inactive_users', 'admin_send_inactive_reminder', 'admin_dashboard_metrics', 'admin_dashboard_trends', 'admin_signup_counts', 'admin_activity_trend', 'admin_food_coupon_list', 'get_message_for_moderation'])
      and p.prosrc not like '%has_admin_permission%' and p.prosrc not like '%has_any_admin_permission%')::int as actual,
  43 as expected
union all
select 'CHECK5b_rollback_restores_food_is_platform_admin',
  (select count(*) from pg_proc where proname = 'food_is_platform_admin' and prosrc like '%platform_role = ''admin''%')::int, 1
union all
select 'CHECK5c_rollback_drops_any_helper', (to_regprocedure('internal.has_any_admin_permission()') is null)::int, 1;
EOF

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

# Function bodies reference Food/Merchant tables this test does not load; skip
# body validation for every session on this throwaway database.
printf 'alter database %s set check_function_bodies = off;\n' "$DB_NAME" > "$WORK_DIR/01_settings.sql"
steps=("$WORK_DIR/01_settings.sql" "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/05_pre.sql" "$FOUNDATION_FILE" "$WORK_DIR/07_grants.sql")
for s in $SYSTEMS; do steps+=("$MIG_DIR/$(mig_for $s).sql" "$MIG_DIR/$(mig_for $s).sql"); done
steps+=("$WORK_DIR/10_assert.sql")
for step in "${steps[@]}"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done
cp "$WORK_DIR/psql.out" "$WORK_DIR/assert.out"
rb_steps=()
for s in central account social food merchant; do rb_steps+=("$RB_DIR/$(mig_for $s)_rollback.sql"); done
rb_steps+=("$WORK_DIR/20_after_rollback.sql")
for step in "${rb_steps[@]}"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done
cat "$WORK_DIR/psql.out" >> "$WORK_DIR/assert.out"
mv "$WORK_DIR/assert.out" "$WORK_DIR/psql.out"
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
