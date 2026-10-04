-- WYN-207: WYNOS Food ads, pay per click, controlled from WYNOS Admin.
--
-- Founder decisions:
-- * ads are paid per click and WYNOS Admin controls them;
-- * stores pay WYNOS by PromptPay transfer plus a slip, and Admin approves;
-- * ads show as recommended stores on the Food home page and first in
--   store search, always labelled "โฆษณา".
--
-- How it works:
-- * food_ad_settings (one row): price per click, minimum top-up, WYNOS's
--   PromptPay, and a master switch (off until Admin turns it on).
-- * A store tops up credit: it uploads its transfer slip to
--   food-private/ads/<store_id>/..., requests a top-up, and Admin approves or
--   rejects it. Approval adds the amount to food_ad_accounts.balance.
-- * An ad is live while ads are on, the store's ad account is active, its
--   balance covers one click, and the store is published and not suspended.
-- * food_ad_click charges one click on the server: once per customer per
--   store per Bangkok day, never for the store's own team, and only while
--   live. The balance never goes below zero.
-- * Admin can stop a store's ads (with a reason) and start them again.

create table if not exists public.food_ad_settings (
  id smallint primary key default 1,
  cost_per_click numeric(10,2) not null default 2,
  min_topup numeric(10,2) not null default 100,
  wynos_promptpay_name text,
  wynos_promptpay_id text,
  ads_enabled boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint food_ad_settings_singleton check (id = 1),
  constraint food_ad_settings_cpc_check check (cost_per_click > 0 and cost_per_click <= 1000),
  constraint food_ad_settings_min_topup_check check (min_topup > 0 and min_topup <= 100000),
  constraint food_ad_settings_promptpay_check check (
    (wynos_promptpay_name is null or char_length(wynos_promptpay_name) <= 120)
    and (wynos_promptpay_id is null or wynos_promptpay_id ~ '^[0-9-]{10,20}$')
  )
);
insert into public.food_ad_settings (id) values (1) on conflict (id) do nothing;

create table if not exists public.food_ad_accounts (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  balance numeric(12,2) not null default 0,
  total_spent numeric(12,2) not null default 0,
  status text not null default 'active',
  stop_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_ad_accounts_balance_check check (balance >= 0 and total_spent >= 0),
  constraint food_ad_accounts_status_check check (status in ('active', 'paused', 'stopped')),
  constraint food_ad_accounts_reason_check check (stop_reason is null or char_length(stop_reason) <= 300)
);

create table if not exists public.food_ad_topups (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  amount numeric(12,2) not null,
  slip_path text not null,
  status text not null default 'pending',
  note text,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint food_ad_topups_amount_check check (amount > 0 and amount <= 100000),
  constraint food_ad_topups_status_check check (status in ('pending', 'approved', 'rejected')),
  constraint food_ad_topups_note_check check (note is null or char_length(note) <= 300)
);

create index if not exists food_ad_topups_store_idx on public.food_ad_topups(store_id, created_at desc);
create index if not exists food_ad_topups_pending_idx on public.food_ad_topups(created_at) where status = 'pending';

create table if not exists public.food_ad_clicks (
  id bigserial primary key,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  click_day date not null default ((now() at time zone 'Asia/Bangkok')::date),
  placement text not null,
  cost numeric(10,2) not null,
  created_at timestamptz not null default now(),
  constraint food_ad_clicks_placement_check check (placement in ('home', 'search')),
  constraint food_ad_clicks_cost_check check (cost > 0),
  constraint food_ad_clicks_once_per_day unique (store_id, viewer_id, click_day)
);

create index if not exists food_ad_clicks_store_day_idx on public.food_ad_clicks(store_id, click_day desc);

alter table public.food_ad_settings enable row level security;
alter table public.food_ad_accounts enable row level security;
alter table public.food_ad_topups enable row level security;
alter table public.food_ad_clicks enable row level security;
revoke all on table public.food_ad_settings from public, anon, authenticated;
revoke all on table public.food_ad_accounts from public, anon, authenticated;
revoke all on table public.food_ad_topups from public, anon, authenticated;
revoke all on table public.food_ad_clicks from public, anon, authenticated;
revoke all on sequence public.food_ad_clicks_id_seq from public, anon, authenticated;

-- Slips for ad top-ups: food-private/ads/<store_id>/<file>. The store's
-- owner/admin/manager uploads; the store team reads; platform admins already
-- read all of food-private (WYN-203). Nobody updates or deletes them.
drop policy if exists "Food ad slips upload by store managers" on storage.objects;
create policy "Food ad slips upload by store managers"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'ads'
  and array_length(storage.foldername(name), 1) = 2
  and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]), array['owner','admin','manager'])
);

drop policy if exists "Food ad slips readable by store team" on storage.objects;
create policy "Food ad slips readable by store team"
on storage.objects for select to authenticated
using (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'ads'
  and public.food_has_merchant_access(public.food_path_uuid((storage.foldername(name))[2]))
);

-- live ads ------------------------------------------------------------------------

create or replace function internal.food_ad_is_live(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.food_ad_accounts a
    join public.food_ad_settings st on st.id = 1
    join public.food_stores s on s.id = a.store_id
    where a.store_id = p_store_id
      and st.ads_enabled
      and a.status = 'active'
      and a.balance >= st.cost_per_click
      and s.is_published
      and s.admin_suspended_at is null
  )
$$;

revoke all on function internal.food_ad_is_live(uuid) from public, anon, authenticated;

-- audit event types (keep every existing type) -------------------------------

do $$
declare
  v_def text;
  v_types text[];
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conname = 'audit_log_event_type_check'
    and c.conrelid = 'public.audit_log'::regclass;

  select coalesce(array_agg(distinct t), '{}') into v_types
  from regexp_matches(coalesce(v_def, ''), '''([^'']*)''', 'g') as m,
       unnest(string_to_array(btrim(m[1], '{}'), ',')) as raw,
       btrim(raw, ' "') as t
  where t ~ '^[a-z0-9_]+$';

  select array_agg(distinct t order by t) into v_types
  from unnest(v_types || array[
    'admin_ad_settings_updated',
    'admin_ad_topup_reviewed',
    'admin_ad_account_status'
  ]) as t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end;
$$;

-- WYNOS Food: store directory (ads first) and click charging ------------------------

create or replace function public.food_store_directory(p_query text default null)
returns table (
  id uuid,
  slug text,
  name text,
  logo_path text,
  cover_path text,
  business_hours text,
  delivery_fee numeric,
  is_open boolean,
  is_ad boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food access required';
  end if;
  return query
  select s.id, s.slug, s.name, s.logo_path, s.cover_path, s.business_hours, s.delivery_fee::numeric, s.is_open,
         internal.food_ad_is_live(s.id) as is_ad
  from public.food_stores s
  where s.is_published
    and s.admin_suspended_at is null
    and (v_query is null
      or s.name ilike '%' || replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%')
  order by internal.food_ad_is_live(s.id) desc, s.is_open desc, s.name
  limit 50;
end;
$$;

revoke all on function public.food_store_directory(text) from public, anon;
grant execute on function public.food_store_directory(text) to authenticated;

create or replace function public.food_ad_click(p_store_id uuid, p_placement text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viewer uuid := auth.uid();
  v_cpc numeric;
  v_account public.food_ad_accounts%rowtype;
  v_click_id bigint;
begin
  if v_viewer is null or not public.food_customer_access_enabled() then
    raise exception 'food access required';
  end if;
  if p_placement not in ('home', 'search') then
    raise exception 'invalid placement';
  end if;
  -- The store's own team never pays for its own clicks.
  if public.food_has_merchant_access(p_store_id) then
    return 'own_store';
  end if;

  select * into v_account from public.food_ad_accounts where store_id = p_store_id for update;
  if not found or not internal.food_ad_is_live(p_store_id) then
    return 'not_live';
  end if;
  select cost_per_click into v_cpc from public.food_ad_settings where id = 1;

  insert into public.food_ad_clicks (store_id, viewer_id, placement, cost)
  values (p_store_id, v_viewer, p_placement, v_cpc)
  on conflict on constraint food_ad_clicks_once_per_day do nothing
  returning id into v_click_id;
  if v_click_id is null then
    return 'repeat';
  end if;

  update public.food_ad_accounts
  set balance = balance - v_cpc, total_spent = total_spent + v_cpc, updated_at = now()
  where store_id = p_store_id;
  return 'charged';
end;
$$;

revoke all on function public.food_ad_click(uuid, text) from public, anon;
grant execute on function public.food_ad_click(uuid, text) to authenticated;

-- Wynos Merchant ------------------------------------------------------------------------

create or replace function public.merchant_ad_account(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_settings public.food_ad_settings%rowtype;
  v_account public.food_ad_accounts%rowtype;
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders','support','delivery']) then
    raise exception 'merchant access required';
  end if;
  select * into v_settings from public.food_ad_settings where id = 1;
  select * into v_account from public.food_ad_accounts where store_id = p_store_id;

  return jsonb_build_object(
    'can_manage', public.merchant_has_store_role(p_store_id, array['owner','admin','manager']),
    'ads_enabled', coalesce(v_settings.ads_enabled, false),
    'cost_per_click', v_settings.cost_per_click,
    'min_topup', v_settings.min_topup,
    'wynos_promptpay_name', v_settings.wynos_promptpay_name,
    'wynos_promptpay_id', v_settings.wynos_promptpay_id,
    'balance', coalesce(v_account.balance, 0),
    'total_spent', coalesce(v_account.total_spent, 0),
    'status', coalesce(v_account.status, 'none'),
    'stop_reason', v_account.stop_reason,
    'live', internal.food_ad_is_live(p_store_id),
    'clicks_today', (select count(*) from public.food_ad_clicks c where c.store_id = p_store_id and c.click_day = v_today),
    'clicks_7d', (select count(*) from public.food_ad_clicks c where c.store_id = p_store_id and c.click_day > v_today - 7),
    'spend_7d', coalesce((select sum(c.cost) from public.food_ad_clicks c where c.store_id = p_store_id and c.click_day > v_today - 7), 0),
    'topups', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'amount', t.amount, 'status', t.status, 'note', t.note,
        'created_at', t.created_at, 'reviewed_at', t.reviewed_at) order by t.created_at desc)
      from (select * from public.food_ad_topups where store_id = p_store_id order by created_at desc limit 20) t
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.merchant_ad_account(uuid) from public, anon;
grant execute on function public.merchant_ad_account(uuid) to authenticated;

create or replace function public.merchant_request_ad_topup(p_store_id uuid, p_amount numeric, p_slip_path text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settings public.food_ad_settings%rowtype;
  v_id uuid;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) then
    raise exception 'merchant manager access required';
  end if;
  select * into v_settings from public.food_ad_settings where id = 1;
  if not v_settings.ads_enabled or v_settings.wynos_promptpay_id is null then
    raise exception 'ads are not open yet';
  end if;
  if p_amount is null or p_amount < v_settings.min_topup then
    raise exception 'top-up is below the minimum';
  end if;
  if p_slip_path is null or p_slip_path not like 'ads/' || p_store_id::text || '/%' or p_slip_path like '%..%' then
    raise exception 'slip must be uploaded for this store';
  end if;
  if (select count(*) from public.food_ad_topups where store_id = p_store_id and status = 'pending') >= 3 then
    raise exception 'too many pending top-ups';
  end if;

  insert into public.food_ad_accounts (store_id) values (p_store_id) on conflict (store_id) do nothing;
  insert into public.food_ad_topups (store_id, amount, slip_path, requested_by)
  values (p_store_id, round(p_amount, 2), p_slip_path, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.merchant_request_ad_topup(uuid, numeric, text) from public, anon;
grant execute on function public.merchant_request_ad_topup(uuid, numeric, text) to authenticated;

create or replace function public.merchant_set_ad_active(p_store_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) then
    raise exception 'merchant manager access required';
  end if;
  select status into v_status from public.food_ad_accounts where store_id = p_store_id for update;
  if not found then
    raise exception 'top up before starting ads';
  end if;
  if v_status = 'stopped' then
    raise exception 'ads stopped by WYNOS';
  end if;
  update public.food_ad_accounts
  set status = case when p_active then 'active' else 'paused' end, updated_at = now()
  where store_id = p_store_id;
end;
$$;

revoke all on function public.merchant_set_ad_active(uuid, boolean) from public, anon;
grant execute on function public.merchant_set_ad_active(uuid, boolean) to authenticated;

-- WYNOS Admin (admin only: this is money) -------------------------------------------------

create or replace function public.admin_ad_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  return jsonb_build_object(
    'settings', (select to_jsonb(s) - 'id' from public.food_ad_settings s where s.id = 1),
    'pending_topups', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'store_id', t.store_id, 'store_name', s.name, 'amount', t.amount,
        'slip_path', t.slip_path, 'created_at', t.created_at) order by t.created_at)
      from public.food_ad_topups t join public.food_stores s on s.id = t.store_id
      where t.status = 'pending'
    ), '[]'::jsonb),
    'accounts', coalesce((
      select jsonb_agg(jsonb_build_object('store_id', a.store_id, 'store_name', s.name, 'balance', a.balance,
        'total_spent', a.total_spent, 'status', a.status, 'stop_reason', a.stop_reason,
        'live', internal.food_ad_is_live(a.store_id),
        'clicks_7d', (select count(*) from public.food_ad_clicks c where c.store_id = a.store_id and c.click_day > v_today - 7),
        'spend_7d', coalesce((select sum(c.cost) from public.food_ad_clicks c where c.store_id = a.store_id and c.click_day > v_today - 7), 0)
      ) order by a.balance desc)
      from public.food_ad_accounts a join public.food_stores s on s.id = a.store_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_ad_overview() from public, anon;
grant execute on function public.admin_ad_overview() to authenticated;

create or replace function public.admin_update_ad_settings(
  p_cost_per_click numeric,
  p_min_topup numeric,
  p_wynos_promptpay_name text,
  p_wynos_promptpay_id text,
  p_ads_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_promptpay text := nullif(btrim(coalesce(p_wynos_promptpay_id, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  if coalesce(p_ads_enabled, false) and v_promptpay is null then
    raise exception 'set the WYNOS PromptPay before turning ads on';
  end if;
  update public.food_ad_settings set
    cost_per_click = p_cost_per_click,
    min_topup = p_min_topup,
    wynos_promptpay_name = nullif(btrim(coalesce(p_wynos_promptpay_name, '')), ''),
    wynos_promptpay_id = v_promptpay,
    ads_enabled = coalesce(p_ads_enabled, false),
    updated_by = v_admin,
    updated_at = now()
  where id = 1;
  perform internal.log_audit_event(v_admin, 'admin_ad_settings_updated', null,
    jsonb_build_object('cost_per_click', p_cost_per_click, 'min_topup', p_min_topup,
      'ads_enabled', coalesce(p_ads_enabled, false), 'promptpay_set', v_promptpay is not null));
end;
$$;

revoke all on function public.admin_update_ad_settings(numeric, numeric, text, text, boolean) from public, anon;
grant execute on function public.admin_update_ad_settings(numeric, numeric, text, text, boolean) to authenticated;

create or replace function public.admin_review_ad_topup(p_topup_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_topup public.food_ad_topups%rowtype;
  v_store public.food_stores%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review ad top-ups';
  end if;
  select * into v_topup from public.food_ad_topups where id = p_topup_id for update;
  if not found then
    raise exception 'top-up not found';
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'top-up already reviewed';
  end if;
  if not p_approve and v_note is null then
    raise exception 'a reason is required to reject';
  end if;
  select * into v_store from public.food_stores where id = v_topup.store_id;

  update public.food_ad_topups
  set status = case when p_approve then 'approved' else 'rejected' end,
      note = v_note, reviewed_by = v_admin, reviewed_at = now()
  where id = p_topup_id;

  if p_approve then
    insert into public.food_ad_accounts (store_id, balance) values (v_topup.store_id, v_topup.amount)
    on conflict (store_id) do update set balance = public.food_ad_accounts.balance + excluded.balance, updated_at = now();
  end if;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_approve
      then 'WYNOS เติมเครดิตโฆษณาร้าน ' || v_store.name || ' แล้ว ' || to_char(v_topup.amount, 'FM999,999,990.00') || ' บาท'
      else 'WYNOS ไม่อนุมัติการเติมเครดิตโฆษณาร้าน ' || v_store.name || ': ' || v_note
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin', 'manager');

  perform internal.log_audit_event(v_admin, 'admin_ad_topup_reviewed', null,
    jsonb_build_object('topup_id', p_topup_id, 'store_id', v_topup.store_id, 'store_name', v_store.name,
      'amount', v_topup.amount, 'approved', p_approve, 'note', v_note));
end;
$$;

revoke all on function public.admin_review_ad_topup(uuid, boolean, text) from public, anon;
grant execute on function public.admin_review_ad_topup(uuid, boolean, text) to authenticated;

create or replace function public.admin_set_ad_account_status(p_store_id uuid, p_stop boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
  v_store public.food_stores%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage ads';
  end if;
  if p_stop and v_reason is null then
    raise exception 'a reason is required to stop ads';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store not found';
  end if;
  insert into public.food_ad_accounts (store_id) values (p_store_id) on conflict (store_id) do nothing;
  -- Starting again leaves the ads paused; the store switches them back on.
  update public.food_ad_accounts
  set status = case when p_stop then 'stopped' else 'paused' end,
      stop_reason = case when p_stop then v_reason else null end,
      updated_at = now()
  where store_id = p_store_id;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_stop
      then 'WYNOS หยุดโฆษณาร้าน ' || v_store.name || ': ' || v_reason
      else 'WYNOS เปิดให้ร้าน ' || v_store.name || ' ลงโฆษณาได้อีกครั้ง'
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin', 'manager');

  perform internal.log_audit_event(v_admin, 'admin_ad_account_status', null,
    jsonb_build_object('store_id', p_store_id, 'store_name', v_store.name, 'stopped', p_stop, 'reason', v_reason));
end;
$$;

revoke all on function public.admin_set_ad_account_status(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_ad_account_status(uuid, boolean, text) to authenticated;
