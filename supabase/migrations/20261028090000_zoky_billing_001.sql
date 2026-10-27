-- ZOKY-BILLING-001: fixed monthly store fee, paid by transfer + slip.
-- PRD: .wyn/docs/product/zoky-billing-001-monthly-fee.md (Founder approved 2026-10-27)
-- Design: .wyn/docs/engineering/zoky-billing-001-technical-design.md
--
-- Same pattern as the ad top-ups (migrations_wynos_food_ads_v1.sql):
-- * food_billing_settings (one row): fee, trial days, ZOKY's payment account,
--   receipt issuer and a master switch. Off until an Admin turns it on, so
--   applying this migration changes nothing for stores or customers.
-- * A store's cycle is anchored on the day it started selling plus the trial
--   (stores already selling at launch start on the launch day). Cycle n starts
--   at anchor + n months; PostgreSQL clamps to the month end.
-- * internal.food_billing_run() (daily, pg_cron) issues one full-month invoice
--   per store per cycle while the store is published and not suspended, and
--   reminds owner/admin at -3, 0, +3 and +7 days from the due date (7 days
--   after issue). It never suspends a store; Admins do that with the existing
--   store suspension, which hides the store from customers.
-- * Owner/admin upload the slip to food-private/billing/<store>/<invoice>/...,
--   an Admin with merchant:edit approves (receipt number) or rejects it.
-- GP is unchanged (0%, admin page kept).
-- Rollback: supabase/rollbacks/20261028090000_zoky_billing_001_rollback.sql

-- tables ----------------------------------------------------------------------------

create table if not exists public.food_billing_settings (
  id smallint primary key default 1,
  billing_enabled boolean not null default false,
  monthly_fee numeric(10,2),
  trial_days integer,
  zoky_promptpay_name text,
  zoky_promptpay_id text,
  zoky_bank_name text,
  zoky_bank_account_name text,
  zoky_bank_account_number text,
  receipt_issuer_name text,
  receipt_issuer_address text,
  receipt_issuer_tax_id text,
  launched_on date,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint food_billing_settings_singleton check (id = 1),
  constraint food_billing_settings_fee_check check (monthly_fee is null or (monthly_fee > 0 and monthly_fee <= 100000)),
  constraint food_billing_settings_trial_check check (trial_days is null or (trial_days >= 0 and trial_days <= 365)),
  constraint food_billing_settings_promptpay_check check (
    zoky_promptpay_id is null or zoky_promptpay_id ~ '^(0[0-9]{9}|[0-9]{13}|[0-9]{15})$'),
  constraint food_billing_settings_bank_number_check check (
    zoky_bank_account_number is null or zoky_bank_account_number ~ '^[0-9]{10,15}$'),
  constraint food_billing_settings_tax_id_check check (
    receipt_issuer_tax_id is null or receipt_issuer_tax_id ~ '^[0-9]{13}$'),
  constraint food_billing_settings_text_check check (
    coalesce(char_length(zoky_promptpay_name), 0) <= 160
    and coalesce(char_length(zoky_bank_name), 0) <= 120
    and coalesce(char_length(zoky_bank_account_name), 0) <= 160
    and coalesce(char_length(receipt_issuer_name), 0) <= 200
    and coalesce(char_length(receipt_issuer_address), 0) <= 500)
);
insert into public.food_billing_settings (id) values (1) on conflict (id) do nothing;

create table if not exists public.food_billing_price_history (
  id bigserial primary key,
  monthly_fee numeric(10,2),
  trial_days integer,
  set_by uuid references auth.users(id) on delete set null,
  set_at timestamptz not null default now()
);

create table if not exists public.food_store_billing (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  opened_on date not null,
  trial_days integer not null,
  cycle_anchor date not null,
  created_at timestamptz not null default now(),
  constraint food_store_billing_trial_check check (trial_days >= 0 and trial_days <= 365),
  constraint food_store_billing_anchor_check check (cycle_anchor = opened_on + trial_days)
);

create sequence if not exists public.food_billing_receipt_seq;

create table if not exists public.food_billing_invoices (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  amount numeric(10,2) not null,
  issued_on date not null,
  due_on date not null,
  status text not null default 'unpaid',
  slip_path text,
  submitted_by uuid references auth.users(id) on delete set null,
  submitted_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  note text,
  receipt_no text unique,
  receipt_issuer jsonb,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  constraint food_billing_invoices_cycle unique (store_id, period_start),
  constraint food_billing_invoices_amount_check check (amount > 0 and amount <= 100000),
  constraint food_billing_invoices_period_check check (period_end >= period_start and due_on >= issued_on),
  constraint food_billing_invoices_status_check check (status in ('unpaid', 'slip_submitted', 'paid', 'rejected', 'waived')),
  constraint food_billing_invoices_note_check check (note is null or char_length(note) <= 300),
  constraint food_billing_invoices_slip_check check (status <> 'slip_submitted' or slip_path is not null),
  constraint food_billing_invoices_paid_check check (status <> 'paid' or (receipt_no is not null and paid_at is not null))
);

create index if not exists food_billing_invoices_store_idx on public.food_billing_invoices(store_id, period_start desc);
create index if not exists food_billing_invoices_open_idx on public.food_billing_invoices(due_on)
  where status in ('unpaid', 'rejected', 'slip_submitted');

create table if not exists public.food_billing_reminders (
  invoice_id uuid not null references public.food_billing_invoices(id) on delete cascade,
  offset_days smallint not null,
  sent_at timestamptz not null default now(),
  primary key (invoice_id, offset_days),
  constraint food_billing_reminders_offset_check check (offset_days in (-3, 0, 3, 7))
);

alter table public.food_billing_settings enable row level security;
alter table public.food_billing_price_history enable row level security;
alter table public.food_store_billing enable row level security;
alter table public.food_billing_invoices enable row level security;
alter table public.food_billing_reminders enable row level security;
revoke all on table public.food_billing_settings from public, anon, authenticated;
revoke all on table public.food_billing_price_history from public, anon, authenticated;
revoke all on table public.food_store_billing from public, anon, authenticated;
revoke all on table public.food_billing_invoices from public, anon, authenticated;
revoke all on table public.food_billing_reminders from public, anon, authenticated;
revoke all on sequence public.food_billing_price_history_id_seq from public, anon, authenticated;
revoke all on sequence public.food_billing_receipt_seq from public, anon, authenticated;

-- helpers ---------------------------------------------------------------------------

create or replace function internal.food_billing_today()
returns date
language sql
stable
set search_path = ''
as $$ select (now() at time zone 'Asia/Bangkok')::date $$;

-- Start of the cycle that contains p_day (p_day >= p_anchor).
create or replace function internal.food_billing_cycle_start(p_anchor date, p_day date)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_months integer := (extract(year from p_day)::int - extract(year from p_anchor)::int) * 12
    + extract(month from p_day)::int - extract(month from p_anchor)::int;
begin
  if (p_anchor + make_interval(months => v_months))::date > p_day then
    v_months := v_months - 1;
  end if;
  return (p_anchor + make_interval(months => greatest(v_months, 0)))::date;
end;
$$;

create or replace function internal.food_billing_next_cycle(p_anchor date, p_cycle_start date)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_months integer := (extract(year from p_cycle_start)::int - extract(year from p_anchor)::int) * 12
    + extract(month from p_cycle_start)::int - extract(month from p_anchor)::int;
begin
  return (p_anchor + make_interval(months => v_months + 1))::date;
end;
$$;

-- Notify the store's active owner/admin members.
create or replace function internal.food_billing_notify(p_store_id uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system', left(p_reason, 500)
  from public.food_stores s
  join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
  where s.id = p_store_id and mm.active and mm.role in ('owner', 'admin');
$$;

-- Give every published store without a billing row one that opens today.
create or replace function internal.food_billing_backfill(p_today date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trial integer;
  v_count integer;
begin
  select coalesce(trial_days, 0) into v_trial from public.food_billing_settings where id = 1;
  insert into public.food_store_billing (store_id, opened_on, trial_days, cycle_anchor)
  select s.id, p_today, v_trial, p_today + v_trial
  from public.food_stores s
  where s.is_published
    and not exists (select 1 from public.food_store_billing b where b.store_id = s.id)
  on conflict (store_id) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- A store that starts selling after launch opens its billing that day.
create or replace function internal.food_billing_store_published()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settings public.food_billing_settings%rowtype;
  v_today date := internal.food_billing_today();
begin
  if new.is_published and (tg_op = 'INSERT' or not old.is_published) then
    select * into v_settings from public.food_billing_settings where id = 1;
    if v_settings.launched_on is not null then
      insert into public.food_store_billing (store_id, opened_on, trial_days, cycle_anchor)
      values (new.id, v_today, coalesce(v_settings.trial_days, 0), v_today + coalesce(v_settings.trial_days, 0))
      on conflict (store_id) do nothing;
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists food_stores_billing_published on public.food_stores;
create trigger food_stores_billing_published
after insert or update of is_published on public.food_stores
for each row execute function internal.food_billing_store_published();

-- daily job -------------------------------------------------------------------------

-- Idempotent: running it twice on one day changes nothing.
create or replace function internal.food_billing_run(p_today date default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := coalesce(p_today, internal.food_billing_today());
  v_settings public.food_billing_settings%rowtype;
  v_row record;
  v_cycle date;
  v_invoice_id uuid;
  v_offset smallint;
  v_issued integer := 0;
  v_reminded integer := 0;
begin
  select * into v_settings from public.food_billing_settings where id = 1;
  if not coalesce(v_settings.billing_enabled, false) or v_settings.monthly_fee is null then
    return jsonb_build_object('enabled', false);
  end if;

  perform internal.food_billing_backfill(v_today);

  -- One invoice per cycle, issued while the store can sell. A late run (up to
  -- 3 days into the cycle) still issues it; a cycle that starts while the
  -- store is unpublished or suspended is not billed.
  for v_row in
    select b.store_id, b.cycle_anchor, s.name
    from public.food_store_billing b
    join public.food_stores s on s.id = b.store_id
    where b.cycle_anchor <= v_today and s.is_published and s.admin_suspended_at is null
  loop
    v_cycle := internal.food_billing_cycle_start(v_row.cycle_anchor, v_today);
    continue when v_today - v_cycle > 3;
    insert into public.food_billing_invoices (store_id, period_start, period_end, amount, issued_on, due_on)
    values (v_row.store_id, v_cycle, internal.food_billing_next_cycle(v_row.cycle_anchor, v_cycle) - 1,
      v_settings.monthly_fee, v_today, v_today + 7)
    on conflict (store_id, period_start) do nothing
    returning id into v_invoice_id;
    if v_invoice_id is not null then
      v_issued := v_issued + 1;
      perform internal.food_billing_notify(v_row.store_id,
        'ZOKY ออกใบแจ้งค่าบริการร้าน ' || v_row.name || ' ' || to_char(v_settings.monthly_fee, 'FM999,999,990.00')
        || ' บาท ครบกำหนด ' || to_char(v_today + 7, 'DD/MM/YYYY'));
    end if;
    v_invoice_id := null;
  end loop;

  -- Reminders at -3, 0, +3, +7 days from the due date for unpaid or rejected
  -- invoices. After a missed day only the latest due reminder is sent.
  for v_row in
    select i.id, i.store_id, i.amount, i.due_on, s.name,
      (select max(o) from unnest(array[-3, 0, 3, 7]::smallint[]) o
        where i.due_on + o <= v_today and i.due_on + o >= i.issued_on
          and not exists (select 1 from public.food_billing_reminders r where r.invoice_id = i.id and r.offset_days >= o)
      ) as due_offset
    from public.food_billing_invoices i
    join public.food_stores s on s.id = i.store_id
    where i.status in ('unpaid', 'rejected') and i.due_on - 3 <= v_today
  loop
    continue when v_row.due_offset is null;
    v_offset := v_row.due_offset;
    insert into public.food_billing_reminders (invoice_id, offset_days)
    select v_row.id, o from unnest(array[-3, 0, 3, 7]::smallint[]) o where o <= v_offset
    on conflict do nothing;
    v_reminded := v_reminded + 1;
    perform internal.food_billing_notify(v_row.store_id,
      case
        when v_offset < 0 then 'ค่าบริการ ZOKY ของร้าน ' || v_row.name || ' จะครบกำหนดใน 3 วัน ('
          || to_char(v_row.due_on, 'DD/MM/YYYY') || ')'
        when v_offset = 0 then 'ค่าบริการ ZOKY ของร้าน ' || v_row.name || ' ครบกำหนดวันนี้ '
          || to_char(v_row.amount, 'FM999,999,990.00') || ' บาท'
        else 'ค่าบริการ ZOKY ของร้าน ' || v_row.name || ' เลยกำหนด ' || v_offset
          || ' วันแล้ว กรุณาชำระเพื่อไม่ให้ร้านถูกระงับ'
      end);
  end loop;

  return jsonb_build_object('enabled', true, 'issued', v_issued, 'reminded', v_reminded);
end;
$$;

revoke all on function internal.food_billing_today() from public, anon, authenticated;
revoke all on function internal.food_billing_cycle_start(date, date) from public, anon, authenticated;
revoke all on function internal.food_billing_next_cycle(date, date) from public, anon, authenticated;
revoke all on function internal.food_billing_notify(uuid, text) from public, anon, authenticated;
revoke all on function internal.food_billing_backfill(date) from public, anon, authenticated;
revoke all on function internal.food_billing_store_published() from public, anon, authenticated;
revoke all on function internal.food_billing_run(date) from public, anon, authenticated;

-- slips ---------------------------------------------------------------------------

-- Storage policy helper: owner/admin of the store, uploading for one of that
-- store's open invoices.
create or replace function public.food_billing_slip_upload_allowed(p_store_id uuid, p_invoice_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_store_id is not null and p_invoice_id is not null
    and public.merchant_has_store_role(p_store_id, array['owner','admin'])
    and exists (
      select 1 from public.food_billing_invoices i
      where i.id = p_invoice_id and i.store_id = p_store_id and i.status in ('unpaid', 'rejected'));
$$;

revoke all on function public.food_billing_slip_upload_allowed(uuid, uuid) from public, anon;
grant execute on function public.food_billing_slip_upload_allowed(uuid, uuid) to authenticated;

-- food-private/billing/<store_id>/<invoice_id>/<file>. Owner/admin upload and
-- read; platform admins already read all of food-private. No update/delete.
drop policy if exists "Food billing slips upload by store owner/admin" on storage.objects;
create policy "Food billing slips upload by store owner/admin"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'billing'
  and array_length(storage.foldername(name), 1) = 3
  and public.food_billing_slip_upload_allowed(
    public.food_path_uuid((storage.foldername(name))[2]), public.food_path_uuid((storage.foldername(name))[3]))
);

drop policy if exists "Food billing slips readable by store owner/admin" on storage.objects;
create policy "Food billing slips readable by store owner/admin"
on storage.objects for select to authenticated
using (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'billing'
  and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]), array['owner','admin'])
);

-- Merchant (owner/admin) -----------------------------------------------------------

create or replace function public.merchant_billing(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_settings public.food_billing_settings%rowtype;
  v_billing public.food_store_billing%rowtype;
  v_today date := internal.food_billing_today();
  v_next date;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin']) then
    raise exception 'billing owner/admin access required';
  end if;
  select * into v_settings from public.food_billing_settings where id = 1;
  select * into v_billing from public.food_store_billing where store_id = p_store_id;
  if v_billing.store_id is not null then
    v_next := case when v_billing.cycle_anchor > v_today then v_billing.cycle_anchor
      else internal.food_billing_next_cycle(v_billing.cycle_anchor,
        internal.food_billing_cycle_start(v_billing.cycle_anchor, v_today)) end;
  end if;

  return jsonb_build_object(
    'enabled', coalesce(v_settings.billing_enabled, false),
    'monthly_fee', v_settings.monthly_fee,
    'opened_on', v_billing.opened_on,
    'trial_ends_on', v_billing.cycle_anchor,
    'in_trial', v_billing.cycle_anchor is not null and v_billing.cycle_anchor > v_today,
    'next_cycle_on', v_next,
    'today', v_today,
    'account', jsonb_build_object(
      'promptpay_name', v_settings.zoky_promptpay_name, 'promptpay_id', v_settings.zoky_promptpay_id,
      'bank_name', v_settings.zoky_bank_name, 'bank_account_name', v_settings.zoky_bank_account_name,
      'bank_account_number', v_settings.zoky_bank_account_number),
    'invoices', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'period_start', i.period_start, 'period_end', i.period_end,
        'amount', i.amount, 'status', i.status, 'issued_on', i.issued_on, 'due_on', i.due_on,
        'overdue_days', case when i.status in ('unpaid', 'rejected') and i.due_on < v_today then v_today - i.due_on else 0 end,
        'note', i.note, 'receipt_no', i.receipt_no, 'paid_at', i.paid_at, 'submitted_at', i.submitted_at)
        order by i.period_start desc)
      from (select * from public.food_billing_invoices where store_id = p_store_id order by period_start desc limit 12) i
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.merchant_billing(uuid) from public, anon;
grant execute on function public.merchant_billing(uuid) to authenticated;

create or replace function public.merchant_submit_billing_slip(p_invoice_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.food_billing_invoices%rowtype;
begin
  select * into v_invoice from public.food_billing_invoices where id = p_invoice_id for update;
  if not found or not public.merchant_has_store_role(v_invoice.store_id, array['owner','admin']) then
    raise exception 'billing owner/admin access required';
  end if;
  if v_invoice.status not in ('unpaid', 'rejected') then
    raise exception 'invoice is not waiting for payment';
  end if;
  if p_slip_path is null or char_length(p_slip_path) > 300 or p_slip_path like '%..%'
     or p_slip_path not like 'billing/' || v_invoice.store_id::text || '/' || v_invoice.id::text || '/_%'
     or p_slip_path like 'billing/' || v_invoice.store_id::text || '/' || v_invoice.id::text || '/%/%' then
    raise exception 'slip must be uploaded for this invoice';
  end if;
  update public.food_billing_invoices
  set status = 'slip_submitted', slip_path = p_slip_path, submitted_by = auth.uid(), submitted_at = now(), note = null
  where id = p_invoice_id;
end;
$$;

revoke all on function public.merchant_submit_billing_slip(uuid, text) from public, anon;
grant execute on function public.merchant_submit_billing_slip(uuid, text) to authenticated;

create or replace function public.merchant_billing_receipt(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_invoice public.food_billing_invoices%rowtype;
  v_store public.food_stores%rowtype;
begin
  select * into v_invoice from public.food_billing_invoices where id = p_invoice_id;
  if not found or not public.merchant_has_store_role(v_invoice.store_id, array['owner','admin']) then
    raise exception 'billing owner/admin access required';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'receipt is available after payment is confirmed';
  end if;
  select * into v_store from public.food_stores where id = v_invoice.store_id;
  return jsonb_build_object(
    'receipt_no', v_invoice.receipt_no, 'paid_at', v_invoice.paid_at, 'amount', v_invoice.amount,
    'period_start', v_invoice.period_start, 'period_end', v_invoice.period_end,
    'issuer', v_invoice.receipt_issuer,
    'store', jsonb_build_object('name', v_store.name,
      'legal_name', v_store.tax_legal_name, 'address', coalesce(v_store.tax_address, v_store.address))
  );
end;
$$;

revoke all on function public.merchant_billing_receipt(uuid) from public, anon;
grant execute on function public.merchant_billing_receipt(uuid) to authenticated;

-- ZOKY Admin ---------------------------------------------------------------------------

create or replace function public.admin_billing_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := internal.food_billing_today();
begin
  if not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;
  return jsonb_build_object(
    'today', v_today,
    'settings', (select to_jsonb(s) - 'id' from public.food_billing_settings s where s.id = 1),
    'price_history', coalesce((
      select jsonb_agg(jsonb_build_object('monthly_fee', h.monthly_fee, 'trial_days', h.trial_days, 'set_at', h.set_at)
        order by h.set_at desc)
      from (select * from public.food_billing_price_history order by set_at desc limit 20) h
    ), '[]'::jsonb),
    'stores', jsonb_build_object(
      'in_trial', (select count(*) from public.food_store_billing where cycle_anchor > v_today),
      'billed', (select count(*) from public.food_store_billing where cycle_anchor <= v_today)),
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'store_id', i.store_id, 'store_name', s.name, 'amount', i.amount,
        'period_start', i.period_start, 'period_end', i.period_end, 'due_on', i.due_on,
        'slip_path', i.slip_path, 'submitted_at', i.submitted_at) order by i.submitted_at)
      from public.food_billing_invoices i join public.food_stores s on s.id = i.store_id
      where i.status = 'slip_submitted'
    ), '[]'::jsonb),
    'overdue', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'store_id', i.store_id, 'store_name', s.name, 'amount', i.amount,
        'status', i.status, 'due_on', i.due_on, 'overdue_days', v_today - i.due_on, 'note', i.note,
        'suspended', s.admin_suspended_at is not null) order by i.due_on)
      from public.food_billing_invoices i join public.food_stores s on s.id = i.store_id
      where i.status in ('unpaid', 'rejected') and i.due_on < v_today
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'store_id', r.store_id, 'store_name', r.store_name, 'amount', r.amount,
        'status', r.status, 'period_start', r.period_start, 'due_on', r.due_on, 'receipt_no', r.receipt_no,
        'note', r.note) order by r.created_at desc)
      from (select i.*, s.name as store_name from public.food_billing_invoices i
        join public.food_stores s on s.id = i.store_id order by i.created_at desc limit 50) r
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_billing_overview() from public, anon;
grant execute on function public.admin_billing_overview() to authenticated;

create or replace function public.admin_update_billing_settings(
  p_enabled boolean,
  p_monthly_fee numeric,
  p_trial_days integer,
  p_promptpay_name text,
  p_promptpay_id text,
  p_bank_name text,
  p_bank_account_name text,
  p_bank_account_number text,
  p_issuer_name text,
  p_issuer_address text,
  p_issuer_tax_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_old public.food_billing_settings%rowtype;
  v_new public.food_billing_settings%rowtype;
  v_today date := internal.food_billing_today();
  v_backfilled integer := 0;
begin
  if not internal.has_admin_permission('merchant', 'edit') then
    raise exception 'Not authorized';
  end if;
  select * into v_old from public.food_billing_settings where id = 1 for update;

  v_new := v_old;
  v_new.billing_enabled := coalesce(p_enabled, false);
  v_new.monthly_fee := round(p_monthly_fee, 2);
  v_new.trial_days := p_trial_days;
  v_new.zoky_promptpay_name := nullif(btrim(coalesce(p_promptpay_name, '')), '');
  v_new.zoky_promptpay_id := nullif(regexp_replace(coalesce(p_promptpay_id, ''), '[\s-]', '', 'g'), '');
  v_new.zoky_bank_name := nullif(btrim(coalesce(p_bank_name, '')), '');
  v_new.zoky_bank_account_name := nullif(btrim(coalesce(p_bank_account_name, '')), '');
  v_new.zoky_bank_account_number := nullif(regexp_replace(coalesce(p_bank_account_number, ''), '[\s-]', '', 'g'), '');
  v_new.receipt_issuer_name := nullif(btrim(coalesce(p_issuer_name, '')), '');
  v_new.receipt_issuer_address := nullif(btrim(coalesce(p_issuer_address, '')), '');
  v_new.receipt_issuer_tax_id := nullif(regexp_replace(coalesce(p_issuer_tax_id, ''), '[\s-]', '', 'g'), '');

  if v_new.billing_enabled then
    if v_new.monthly_fee is null or v_new.trial_days is null then
      raise exception 'set the monthly fee and trial days before turning billing on';
    end if;
    if not ((v_new.zoky_promptpay_id is not null and v_new.zoky_promptpay_name is not null)
        or (v_new.zoky_bank_name is not null and v_new.zoky_bank_account_name is not null
            and v_new.zoky_bank_account_number is not null)) then
      raise exception 'set the ZOKY payment account before turning billing on';
    end if;
    if v_new.receipt_issuer_name is null then
      raise exception 'set the receipt issuer before turning billing on';
    end if;
    v_new.launched_on := coalesce(v_old.launched_on, v_today);
  end if;

  update public.food_billing_settings set
    billing_enabled = v_new.billing_enabled, monthly_fee = v_new.monthly_fee, trial_days = v_new.trial_days,
    zoky_promptpay_name = v_new.zoky_promptpay_name, zoky_promptpay_id = v_new.zoky_promptpay_id,
    zoky_bank_name = v_new.zoky_bank_name, zoky_bank_account_name = v_new.zoky_bank_account_name,
    zoky_bank_account_number = v_new.zoky_bank_account_number,
    receipt_issuer_name = v_new.receipt_issuer_name, receipt_issuer_address = v_new.receipt_issuer_address,
    receipt_issuer_tax_id = v_new.receipt_issuer_tax_id, launched_on = v_new.launched_on,
    updated_by = v_admin, updated_at = now()
  where id = 1;

  if v_new.monthly_fee is distinct from v_old.monthly_fee or v_new.trial_days is distinct from v_old.trial_days then
    insert into public.food_billing_price_history (monthly_fee, trial_days, set_by)
    values (v_new.monthly_fee, v_new.trial_days, v_admin);
  end if;

  -- Stores selling when billing turns on open their billing today (Q4).
  if v_new.billing_enabled then
    v_backfilled := internal.food_billing_backfill(v_today);
  end if;

  perform internal.log_audit_event(v_admin, 'admin_billing_settings_updated', null,
    jsonb_build_object('enabled', v_new.billing_enabled, 'monthly_fee', v_new.monthly_fee,
      'trial_days', v_new.trial_days, 'launched_on', v_new.launched_on,
      'promptpay_set', v_new.zoky_promptpay_id is not null, 'bank_set', v_new.zoky_bank_account_number is not null,
      'stores_opened', v_backfilled));
end;
$$;

revoke all on function public.admin_update_billing_settings(boolean, numeric, integer, text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.admin_update_billing_settings(boolean, numeric, integer, text, text, text, text, text, text, text, text) to authenticated;

create or replace function public.admin_review_billing_invoice(p_invoice_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_invoice public.food_billing_invoices%rowtype;
  v_settings public.food_billing_settings%rowtype;
  v_store_name text;
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
  v_receipt text;
begin
  if not internal.has_admin_permission('merchant', 'edit') then
    raise exception 'Not authorized';
  end if;
  if p_approve is null then
    raise exception 'choose approve or reject';
  end if;
  select * into v_invoice from public.food_billing_invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'invoice not found';
  end if;
  if v_invoice.status <> 'slip_submitted' then
    raise exception 'invoice has no slip waiting for review';
  end if;
  if not p_approve and v_note is null then
    raise exception 'a reason is required to reject';
  end if;
  select * into v_settings from public.food_billing_settings where id = 1;
  select name into v_store_name from public.food_stores where id = v_invoice.store_id;

  if p_approve then
    v_receipt := 'ZK-' || to_char(internal.food_billing_today(), 'YYYYMM') || '-'
      || lpad(nextval('public.food_billing_receipt_seq')::text, 6, '0');
    update public.food_billing_invoices
    set status = 'paid', paid_at = now(), receipt_no = v_receipt, note = v_note,
        reviewed_by = v_admin, reviewed_at = now(),
        receipt_issuer = jsonb_build_object('name', v_settings.receipt_issuer_name,
          'address', v_settings.receipt_issuer_address, 'tax_id', v_settings.receipt_issuer_tax_id)
    where id = p_invoice_id;
    perform internal.food_billing_notify(v_invoice.store_id,
      'ZOKY ยืนยันการชำระค่าบริการร้าน ' || v_store_name || ' แล้ว ใบเสร็จเลขที่ ' || v_receipt);
  else
    update public.food_billing_invoices
    set status = 'rejected', note = v_note, reviewed_by = v_admin, reviewed_at = now()
    where id = p_invoice_id;
    perform internal.food_billing_notify(v_invoice.store_id,
      'ZOKY ตรวจสลิปค่าบริการร้าน ' || v_store_name || ' ไม่ผ่าน: ' || v_note || ' กรุณาแนบสลิปใหม่');
  end if;

  perform internal.log_audit_event(v_admin, 'admin_billing_invoice_reviewed', null,
    jsonb_build_object('invoice_id', p_invoice_id, 'store_id', v_invoice.store_id, 'store_name', v_store_name,
      'amount', v_invoice.amount, 'approved', p_approve, 'receipt_no', v_receipt, 'note', v_note));
end;
$$;

revoke all on function public.admin_review_billing_invoice(uuid, boolean, text) from public, anon;
grant execute on function public.admin_review_billing_invoice(uuid, boolean, text) to authenticated;

create or replace function public.admin_waive_billing_invoice(p_invoice_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_invoice public.food_billing_invoices%rowtype;
  v_store_name text;
  v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
begin
  if not internal.has_admin_permission('merchant', 'edit') then
    raise exception 'Not authorized';
  end if;
  if v_reason is null then
    raise exception 'a reason is required to waive';
  end if;
  select * into v_invoice from public.food_billing_invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'invoice not found';
  end if;
  if v_invoice.status not in ('unpaid', 'rejected', 'slip_submitted') then
    raise exception 'invoice is already closed';
  end if;
  select name into v_store_name from public.food_stores where id = v_invoice.store_id;
  update public.food_billing_invoices
  set status = 'waived', note = v_reason, reviewed_by = v_admin, reviewed_at = now()
  where id = p_invoice_id;
  perform internal.food_billing_notify(v_invoice.store_id,
    'ZOKY ยกเว้นค่าบริการร้าน ' || v_store_name || ' รอบ ' || to_char(v_invoice.period_start, 'DD/MM/YYYY')
    || ': ' || v_reason);
  perform internal.log_audit_event(v_admin, 'admin_billing_invoice_waived', null,
    jsonb_build_object('invoice_id', p_invoice_id, 'store_id', v_invoice.store_id, 'store_name', v_store_name,
      'amount', v_invoice.amount, 'previous_status', v_invoice.status, 'reason', v_reason));
end;
$$;

revoke all on function public.admin_waive_billing_invoice(uuid, text) from public, anon;
grant execute on function public.admin_waive_billing_invoice(uuid, text) to authenticated;

-- schedule ------------------------------------------------------------------------------

-- 08:05 Bangkok. The job does nothing until an Admin turns billing on.
do $$
declare v_job bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for v_job in select jobid from cron.job where jobname = 'zoky-billing-daily' loop
      perform cron.unschedule(v_job);
    end loop;
    perform cron.schedule('zoky-billing-daily', '5 1 * * *', 'select internal.food_billing_run();');
  else
    raise exception 'pg_cron is required for the daily billing job';
  end if;
end;
$$;
