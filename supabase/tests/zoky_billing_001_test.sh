#!/usr/bin/env bash
# ZOKY-BILLING-001: monthly store fee. Loads the live food_stores shape
# (fixtures/), small stubs for roles/notifications/audit, then the migration,
# and exercises settings, cycles, invoices, reminders, slips and permissions.
# Synthetic data only; no production database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
DB="zoky_billing_001_test_$$"
MIGRATION="$ROOT/supabase/migrations/20261028090000_zoky_billing_001.sql"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
as() { db "set test.uid='$1'; $2"; }
expect() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_as() { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail_as() { local err; if err="$(run -c "set test.uid='$1'; $2" 2>&1)"; then echo "FAIL (expected error): $4"; exit 1; fi; [[ "$err" == *"$3"* ]] || { echo "FAIL: $4 (wrong error: $err)"; exit 1; }; }

STORE=00000000-0000-0000-0000-0000000000a1
STORE2=00000000-0000-0000-0000-0000000000a2
STORE3=00000000-0000-0000-0000-0000000000a3
ACCT=00000000-0000-0000-0000-0000000000f1
ACCT2=00000000-0000-0000-0000-0000000000f2
OWNER=00000000-0000-0000-0000-0000000000c1
SADMIN=00000000-0000-0000-0000-0000000000c2
MANAGER=00000000-0000-0000-0000-0000000000c3
OWNER2=00000000-0000-0000-0000-0000000000c4
EDITOR=00000000-0000-0000-0000-0000000000e1
VIEWER=00000000-0000-0000-0000-0000000000e2
NOBODY=00000000-0000-0000-0000-0000000000e3

run >/dev/null <<'SQL'
create extension if not exists pgcrypto;
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
create table storage.objects(bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql immutable as
  $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
SQL
run -f "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_stub_schema.sql" >/dev/null

run >/dev/null <<'SQL'
create table public.notifications(recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true);
create table public.test_admins(user_id uuid primary key, level text);
create table public.audit_log(actor uuid, event_type text, target uuid, meta jsonb,
  constraint audit_log_event_type_check check (event_type in ('admin_ad_settings_updated', 'admin_gp_rate_set')));
create table public.merchant_notifications(merchant_account_id uuid, recipient_user_id uuid, type text check (type in ('system', 'order', 'payment', 'staff')), reason text);
create function public.merchant_has_store_role(p_store uuid, p_roles text[]) returns boolean language sql stable security definer as
  $$ select exists(select 1 from public.food_stores s join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
     where s.id = p_store and m.user_id = auth.uid() and m.active and m.role = any(p_roles)) $$;
create function internal.has_admin_permission(p_area text, p_level text) returns boolean language sql stable as
  $$ select p_area = 'merchant' and exists(select 1 from public.test_admins a where a.user_id = auth.uid()
     and (a.level = 'edit' or p_level = 'view')) $$;
create function internal.log_audit_event(p_actor uuid, p_action text, p_target uuid, p_meta jsonb) returns void language sql as
  $$ insert into public.audit_log values (p_actor, p_action, p_target, p_meta) $$;
create function public.food_path_uuid(p_segment text) returns uuid language sql immutable as
  $$ select case when p_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then p_segment::uuid end $$;
SQL

# The schedule block needs pg_cron, which this test database does not have.
grep -q "cron.schedule('zoky-billing-daily', '5 1 \* \* \*', 'select internal.food_billing_run();')" "$MIGRATION" \
  || { echo "FAIL: daily schedule missing"; exit 1; }
sed '/^-- schedule ---/,$d' "$MIGRATION" | run >/dev/null

expect "select pg_get_constraintdef(oid) ~ 'admin_billing_invoice_waived' and pg_get_constraintdef(oid) ~ 'admin_gp_rate_set' from pg_constraint where conname = 'audit_log_event_type_check'" "t" "audit allowlist extended, existing values kept"

run >/dev/null <<SQL
insert into auth.users values ('$OWNER'), ('$SADMIN'), ('$MANAGER'), ('$OWNER2'), ('$EDITOR'), ('$VIEWER'), ('$NOBODY');
insert into public.merchant_memberships values
  ('$ACCT', '$OWNER', 'owner', true), ('$ACCT', '$SADMIN', 'admin', true), ('$ACCT', '$MANAGER', 'manager', true),
  ('$ACCT2', '$OWNER2', 'owner', true);
insert into public.test_admins values ('$EDITOR', 'edit'), ('$VIEWER', 'view');
insert into public.food_stores (id, slug, name, share_code, merchant_account_id, is_published, address)
values ('$STORE', 's1', 'ร้านหนึ่ง', 'abcde2', '$ACCT', true, 'ที่อยู่ 1'),
       ('$STORE2', 's2', 'ร้านสอง', 'abcde3', '$ACCT2', true, 'ที่อยู่ 2'),
       ('$STORE3', 's3', 'ร้านสาม', 'abcde4', '$ACCT2', false, null);
SQL

# Cycle maths: anchored, clamped to the month end, no drift.
expect "select internal.food_billing_cycle_start('2026-01-31', '2026-02-28')" "2026-02-28" "Feb clamps to the month end"
expect "select internal.food_billing_cycle_start('2026-01-31', '2026-03-30')" "2026-02-28" "before the 31st stays in Feb cycle"
expect "select internal.food_billing_cycle_start('2026-01-31', '2026-03-31')" "2026-03-31" "Mar 31 from the anchor, not from Feb 28"
expect "select internal.food_billing_cycle_start('2026-01-15', '2026-01-15')" "2026-01-15" "first day of the first cycle"
expect "select internal.food_billing_next_cycle('2026-01-31', '2026-02-28')" "2026-03-31" "next cycle from the anchor"

# Off by default: nothing happens, no store billing rows, no invoices.
expect "select internal.food_billing_run('2026-11-01')::text" '{"enabled": false}' "job is idle while billing is off"
expect "select count(*) from public.food_store_billing" "0" "no billing rows before launch"
expect "select count(*) from public.notifications" "0" "no notifications before launch"

# Settings: only merchant:edit; enabling needs fee, trial, account, issuer.
ARGS="true, 499, 30, 'ZOKY', '0812345678', null, null, null, 'บริษัท โซกี้ จำกัด', 'กรุงเทพฯ', '1234567890123'"
expect_fail_as "$VIEWER" "select public.admin_update_billing_settings($ARGS)" "Not authorized" "view-only admin cannot change billing"
expect_fail_as "$OWNER" "select public.admin_update_billing_settings($ARGS)" "Not authorized" "store owner cannot change billing"
expect_fail_as "$EDITOR" "select public.admin_update_billing_settings(true, null, 30, 'ZOKY', '0812345678', null, null, null, 'X', null, null)" \
  "monthly fee and trial days" "fee required to enable"
expect_fail_as "$EDITOR" "select public.admin_update_billing_settings(true, 499, 30, null, null, null, null, null, 'X', null, null)" \
  "payment account" "account required to enable"
expect_fail_as "$EDITOR" "select public.admin_update_billing_settings(true, 499, 30, 'ZOKY', '0812345678', null, null, null, null, null, null)" \
  "receipt issuer" "issuer required to enable"
expect_fail_as "$EDITOR" "select public.admin_update_billing_settings(true, 499, 30, 'ZOKY', '1812345678', null, null, null, 'X', null, null)" \
  "food_billing_settings_promptpay_check" "PromptPay format is enforced"
expect_as "$VIEWER" "select (public.admin_billing_overview()->'settings'->>'billing_enabled')" "false" "view-only admin reads the overview"
expect_fail_as "$OWNER" "select public.admin_billing_overview()" "Not authorized" "store owner cannot read the admin overview"

# Launch: stores already selling open today with the trial (Q4); unpublished do not.
TODAY=$(db "select internal.food_billing_today()")
as "$EDITOR" "select public.admin_update_billing_settings($ARGS)" >/dev/null
expect "select launched_on = internal.food_billing_today() from public.food_billing_settings" "t" "launch date recorded"
expect "select count(*) from public.food_store_billing" "2" "published stores opened at launch"
expect "select cycle_anchor - opened_on from public.food_store_billing where store_id = '$STORE'" "30" "trial snapshot"
expect "select count(*) from public.food_billing_price_history" "1" "price history recorded"
expect "select count(*) from public.audit_log where event_type = 'admin_billing_settings_updated'" "1" "settings audited"
# Re-saving keeps the launch date and does not duplicate history.
db "update public.food_billing_settings set launched_on = '2026-01-01'" >/dev/null
as "$EDITOR" "select public.admin_update_billing_settings($ARGS)" >/dev/null
expect "select launched_on from public.food_billing_settings" "2026-01-01" "launch date never moves"
expect "select count(*) from public.food_billing_price_history" "1" "unchanged price adds no history"

# A store that starts selling later opens that day.
db "update public.food_stores set is_published = true where id = '$STORE3'" >/dev/null
expect "select opened_on = internal.food_billing_today() from public.food_store_billing where store_id = '$STORE3'" "t" "new store opens on its publish day"
db "update public.food_stores set is_published = false where id = '$STORE3'" >/dev/null
db "update public.food_stores set is_published = true where id = '$STORE3'" >/dev/null
expect "select count(*) from public.food_store_billing where store_id = '$STORE3'" "1" "republish does not reopen billing"

# Fixed anchors for the cycle tests.
db "update public.food_store_billing set opened_on = '2026-09-01', trial_days = 30, cycle_anchor = '2026-10-01' where store_id = '$STORE'" >/dev/null
db "update public.food_store_billing set opened_on = '2026-09-01', trial_days = 30, cycle_anchor = '2026-10-01' where store_id = '$STORE2'" >/dev/null
db "update public.food_store_billing set opened_on = '2026-10-01', trial_days = 50, cycle_anchor = '2026-11-20' where store_id = '$STORE3'" >/dev/null
db "update public.food_stores set admin_suspended_at = now() where id = '$STORE2'" >/dev/null

# STORE3 still in trial, STORE2 suspended: only STORE is billed (its 2nd cycle).
expect "select internal.food_billing_run('2026-11-01')->>'issued'" "1" "only the sellable store in a cycle is billed"
expect "select period_start || ' ' || period_end || ' ' || amount || ' ' || issued_on || ' ' || due_on from public.food_billing_invoices where store_id = '$STORE'" \
  "2026-11-01 2026-11-30 499.00 2026-11-01 2026-11-08" "full month, due 7 days after issue"
expect "select count(*) from public.food_billing_invoices where store_id = '$STORE2'" "0" "suspended store not billed"
expect "select count(*) from public.notifications where reason like 'ZOKY ออกใบแจ้งค่าบริการร้าน ร้านหนึ่ง%'" "2" "issue push notice to owner and admin only"
expect "select count(*) || ' ' || min(type) from public.merchant_notifications where reason like 'ZOKY ออกใบแจ้งค่าบริการร้าน ร้านหนึ่ง%' and recipient_user_id in ('$OWNER', '$SADMIN')" "2 payment" "issue notice in the Merchant inbox"
expect "select internal.food_billing_run('2026-11-01')->>'issued'" "0" "idempotent on the same day"
expect "select count(*) from public.food_billing_invoices" "1" "no duplicate invoice"
expect "select reason from public.food_billing_skipped_cycles where store_id = '$STORE2' and period_start = '2026-11-01'" "suspended" "suspended cycle recorded as skipped"
# Unsuspended within the 3-day window: the cycle that started suspended stays unbilled.
db "update public.food_stores set admin_suspended_at = null where id = '$STORE2'" >/dev/null
expect "select internal.food_billing_run('2026-11-02')->>'issued'" "0" "unsuspend within 3 days does not bill a suspended cycle"
# Unsuspended more than 3 days into the cycle: that cycle stays unbilled.
expect "select internal.food_billing_run('2026-11-05')->>'issued'" "0" "late unsuspend does not bill the cycle"
db "update public.food_stores set admin_suspended_at = now() where id = '$STORE2'" >/dev/null

# Reminders: -3 (Nov 5), 0 (Nov 8), +3, +7; latest only after a missed day.
db "delete from public.notifications" >/dev/null
db "delete from public.food_billing_invoices where store_id <> '$STORE'" >/dev/null
db "delete from public.food_billing_reminders" >/dev/null
expect "select internal.food_billing_run('2026-11-04')->>'reminded'" "0" "no reminder before -3"
expect "select internal.food_billing_run('2026-11-05')->>'reminded'" "1" "-3 reminder"
expect "select internal.food_billing_run('2026-11-05')->>'reminded'" "0" "reminder not repeated"
expect "select internal.food_billing_run('2026-11-12')->>'reminded'" "1" "missed day: send the latest due (+3)"
expect "select string_agg(offset_days::text, ',' order by offset_days) from public.food_billing_reminders" "-3,0,3" "earlier offsets marked sent"
expect "select count(*) from public.notifications where reason like '%เลยกำหนด 3 วัน%'" "2" "+3 text to owner/admin"

# Merchant access: owner/admin only, own store only.
INV=$(db "select id from public.food_billing_invoices where store_id = '$STORE'")
expect_as "$OWNER" "select public.merchant_billing('$STORE')->'invoices'->0->>'overdue_days'" "$(db "select greatest(internal.food_billing_today() - date '2026-11-08', 0)")" "owner sees the invoice"
expect_as "$SADMIN" "select jsonb_array_length(public.merchant_billing('$STORE')->'invoices')" "1" "store admin sees billing"
expect_fail_as "$MANAGER" "select public.merchant_billing('$STORE')" "billing owner/admin access required" "manager cannot see billing"
expect_fail_as "$OWNER2" "select public.merchant_billing('$STORE')" "billing owner/admin access required" "other store cannot see billing"
expect_fail_as "$NOBODY" "select public.merchant_billing('$STORE')" "billing owner/admin access required" "stranger cannot see billing"

# Slip upload policy helper and submit.
expect_as "$OWNER" "select public.food_billing_slip_upload_allowed('$STORE', '$INV')" "t" "owner may upload for an open invoice"
# The storage policies themselves, under RLS as the authenticated role.
db "alter table storage.objects enable row level security; grant usage on schema storage, public to authenticated; grant select, insert on storage.objects to authenticated" >/dev/null
obj() { run -c "set test.uid='$1'; set role authenticated; insert into storage.objects values ('food-private', '$2')" 2>&1; }
obj "$OWNER" "billing/$STORE/$INV/slip.jpg" >/dev/null || { echo "FAIL: owner upload refused by policy"; exit 1; }
for case in "$OWNER2|billing/$STORE/$INV/x.jpg" "$MANAGER|billing/$STORE/$INV/x.jpg" "$OWNER|billing/$STORE/x.jpg" \
            "$OWNER|billing/$STORE2/$INV/x.jpg" "$OWNER|billing/$STORE/$INV/a/x.jpg" "$OWNER|billing/$STORE/not-a-uuid/x.jpg"; do
  err="$(obj "${case%%|*}" "${case#*|}")" && { echo "FAIL: policy allowed ${case}"; exit 1; }
  [[ "$err" == *"row-level security"* ]] || { echo "FAIL: unexpected error for ${case}: $err"; exit 1; }
done
expect "select count(*) from storage.objects" "1" "only the owner's slip was stored"
seen() { db "set test.uid='$1'; set role authenticated; select count(*) from storage.objects where name like 'billing/%'"; }
[[ "$(seen "$OWNER")" == 1 && "$(seen "$SADMIN")" == 1 && "$(seen "$OWNER2")" == 0 && "$(seen "$MANAGER")" == 0 ]] \
  || { echo "FAIL: slip read policy"; exit 1; }
expect_as "$OWNER2" "select public.food_billing_slip_upload_allowed('$STORE', '$INV')" "f" "other store may not upload"
expect_as "$OWNER2" "select public.food_billing_slip_upload_allowed('$STORE2', '$INV')" "f" "invoice must belong to the folder's store"
expect_as "$MANAGER" "select public.food_billing_slip_upload_allowed('$STORE', '$INV')" "f" "manager may not upload"
expect_fail_as "$OWNER2" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/a.jpg')" "billing owner/admin access required" "other store cannot submit"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE2/$INV/a.jpg')" "uploaded for this invoice" "path for another store refused"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/../x.jpg')" "uploaded for this invoice" "path traversal refused"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/x/y.jpg')" "uploaded for this invoice" "nested path refused"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'ads/$STORE/a.jpg')" "uploaded for this invoice" "other area refused"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/a.jpg')" "uploaded for this invoice" "slip file must exist"
db "insert into storage.objects values ('food-private', 'billing/$STORE/$INV/a.jpg'), ('food-private', 'billing/$STORE/$INV/c.jpg')" >/dev/null
as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/a.jpg')" >/dev/null
expect "select status from public.food_billing_invoices where id = '$INV'" "slip_submitted" "slip submitted"
expect_fail_as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/b.jpg')" "not waiting for payment" "no second slip while in review"
expect_as "$OWNER" "select public.food_billing_slip_upload_allowed('$STORE', '$INV')" "f" "no upload while in review"
expect "select internal.food_billing_run('2026-11-15')->>'reminded'" "0" "no reminders while the slip is in review"
expect_fail_as "$OWNER" "select public.merchant_billing_receipt('$INV')" "after payment is confirmed" "no receipt before payment"

# Review: merchant:edit only, reason to reject, receipt on approve.
expect_fail_as "$VIEWER" "select public.admin_review_billing_invoice('$INV', true)" "Not authorized" "view-only admin cannot review"
expect_fail_as "$OWNER" "select public.admin_review_billing_invoice('$INV', true)" "Not authorized" "store cannot approve itself"
expect_fail_as "$EDITOR" "select public.admin_review_billing_invoice('$INV', false, '  ')" "reason is required" "reject needs a reason"
as "$EDITOR" "select public.admin_review_billing_invoice('$INV', false, 'ยอดไม่ตรง')" >/dev/null
expect "select status || ' ' || note from public.food_billing_invoices where id = '$INV'" "rejected ยอดไม่ตรง" "rejected with reason"
expect "select internal.food_billing_run('2026-11-15')->>'reminded'" "1" "reminders resume after rejection (+7)"
as "$OWNER" "select public.merchant_submit_billing_slip('$INV', 'billing/$STORE/$INV/c.jpg')" >/dev/null
expect "select note is null from public.food_billing_invoices where id = '$INV'" "t" "new slip clears the reject note"
as "$EDITOR" "select public.admin_review_billing_invoice('$INV', true)" >/dev/null
expect "select status || ' ' || (receipt_no ~ '^ZK-[0-9]{6}-000001$') || ' ' || (receipt_issuer->>'name') from public.food_billing_invoices where id = '$INV'" \
  "paid true บริษัท โซกี้ จำกัด" "paid with receipt number and issuer snapshot"
expect_fail_as "$EDITOR" "select public.admin_review_billing_invoice('$INV', true)" "no slip waiting" "cannot review twice"
expect_as "$OWNER" "select (public.merchant_billing_receipt('$INV')->'store'->>'name') || ' ' || (public.merchant_billing_receipt('$INV')->>'amount')" "ร้านหนึ่ง 499.00" "owner gets the receipt"
expect_fail_as "$OWNER2" "select public.merchant_billing_receipt('$INV')" "billing owner/admin access required" "other store cannot read the receipt"
expect "select count(*) from public.audit_log where event_type = 'admin_billing_invoice_reviewed'" "2" "reviews audited"

# Waive.
db "insert into public.food_billing_invoices (id, store_id, period_start, period_end, amount, issued_on, due_on)
    values ('00000000-0000-0000-0000-000000000099', '$STORE2', '2026-12-01', '2026-12-31', 499, '2026-12-01', '2026-12-08')" >/dev/null
expect_fail_as "$EDITOR" "select public.admin_waive_billing_invoice('00000000-0000-0000-0000-000000000099', '')" "reason is required" "waive needs a reason"
expect_fail_as "$VIEWER" "select public.admin_waive_billing_invoice('00000000-0000-0000-0000-000000000099', 'x')" "Not authorized" "view-only admin cannot waive"
as "$EDITOR" "select public.admin_waive_billing_invoice('00000000-0000-0000-0000-000000000099', 'ร้านปิดซ่อม')" >/dev/null
expect "select status from public.food_billing_invoices where id = '00000000-0000-0000-0000-000000000099'" "waived" "waived"
expect_fail_as "$EDITOR" "select public.admin_waive_billing_invoice('$INV', 'x')" "already closed" "paid invoice cannot be waived"

# A price change only affects invoices issued afterwards.
as "$EDITOR" "select public.admin_update_billing_settings(true, 599, 30, 'ZOKY', '0812345678', null, null, null, 'บริษัท โซกี้ จำกัด', null, null)" >/dev/null
expect "select amount from public.food_billing_invoices where id = '$INV'" "499.00" "issued invoice keeps its amount"
expect "select internal.food_billing_run('2026-12-01')->>'issued'" "1" "next cycle issued"
expect "select amount from public.food_billing_invoices where store_id = '$STORE' and period_start = '2026-12-01'" "599.00" "new price on the next cycle"
expect "select count(*) from public.food_billing_price_history" "2" "price change in history"

# Turning billing off stops the job.
as "$EDITOR" "select public.admin_update_billing_settings(false, 599, 30, null, null, null, null, null, null, null, null)" >/dev/null
expect "select internal.food_billing_run('2027-01-01')::text" '{"enabled": false}' "off stops invoices"

# Grants: tables closed, internal job not callable.
expect "select has_table_privilege('authenticated', 'public.food_billing_invoices', 'select')" "f" "invoices table closed"
expect "select has_function_privilege('authenticated', 'internal.food_billing_run(date)', 'execute')" "f" "job not callable"
expect "select has_function_privilege('anon', 'public.merchant_billing(uuid)', 'execute')" "f" "anon cannot call merchant billing"

# Rollback removes everything the migration added.
run -f "$ROOT/supabase/rollbacks/20261028090000_zoky_billing_001_rollback.sql" >/dev/null
expect "select count(*) from pg_proc where proname like '%billing%'" "0" "rollback drops the functions"
expect "select to_regclass('public.food_billing_invoices') is null and to_regclass('public.food_billing_settings') is null" "t" "rollback drops the tables"
expect "select count(*) from pg_trigger where tgname = 'food_stores_billing_published'" "0" "rollback drops the trigger"
db "update public.food_stores set is_published = false" >/dev/null

echo "zoky_billing_001: all checks passed"
