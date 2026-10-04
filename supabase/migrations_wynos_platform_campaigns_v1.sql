-- WYN-206: WYNOS campaigns (designed by WYNOS Admin, joined by stores).
--
-- Founder: "แคมเปญ เป็นระบบไฮบริด แล้วแต่จะตั้งยังไง ขึ้นอยู่กับ WYNOS Admin
-- จะเป็นคนออกแคมเปญ". Admin sets, per campaign, how much of each discount
-- WYNOS funds (platform_share_percent, 0-100); the store funds the rest.
--
-- How it works:
-- * Admin designs a campaign in food_platform_campaigns.
-- * A store that joins gets its own food_campaigns row carrying
--   platform_campaign_id and the share, so the existing server-side pricing
--   (internal.food_campaign_candidates, food_quote_order, food_create_order,
--   cancel release) applies unchanged. Discounts never stack: the order gets
--   the single best saving, store promotion or WYNOS campaign.
-- * Each order snapshots WYNOS's part of the discount
--   (food_order_campaigns.platform_funded). Customers pay the store
--   directly, so that amount is owed to the store until Admin transfers it
--   and records a settlement.
-- * Only these RPCs change a joined campaign's terms; the store's own
--   promotion RPCs cannot (trigger guard), usage counting still works.

create table if not exists public.food_platform_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  campaign_type text not null,
  discount_value numeric(10,2) not null default 0,
  min_subtotal numeric(10,2) not null default 0,
  max_discount numeric(10,2),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  usage_limit_per_store integer,
  platform_share_percent numeric(5,2) not null default 0,
  join_open boolean not null default true,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_platform_campaigns_name_length check (char_length(btrim(name)) between 2 and 80),
  constraint food_platform_campaigns_description_length check (description is null or char_length(description) <= 300),
  constraint food_platform_campaigns_type_check check (campaign_type in ('percentage','fixed','free_delivery')),
  constraint food_platform_campaigns_discount_check check (
    (campaign_type='percentage' and discount_value > 0 and discount_value <= 100)
    or (campaign_type='fixed' and discount_value > 0)
    or (campaign_type='free_delivery' and discount_value = 0)
  ),
  constraint food_platform_campaigns_min_subtotal_check check (min_subtotal >= 0),
  constraint food_platform_campaigns_max_discount_check check (max_discount is null or max_discount > 0),
  constraint food_platform_campaigns_dates_check check (ends_at is null or ends_at > starts_at),
  constraint food_platform_campaigns_usage_check check (usage_limit_per_store is null or usage_limit_per_store > 0),
  constraint food_platform_campaigns_share_check check (platform_share_percent >= 0 and platform_share_percent <= 100)
);

create table if not exists public.food_platform_settlements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  amount numeric(12,2) not null,
  order_count integer not null,
  reference text not null,
  note text,
  settled_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint food_platform_settlements_amount_check check (amount > 0 and order_count > 0),
  constraint food_platform_settlements_reference_check check (char_length(btrim(reference)) between 1 and 120),
  constraint food_platform_settlements_note_check check (note is null or char_length(note) <= 300)
);

create index if not exists food_platform_settlements_store_idx
  on public.food_platform_settlements(store_id, created_at desc);

alter table public.food_campaigns
  add column if not exists platform_campaign_id uuid references public.food_platform_campaigns(id) on delete restrict,
  add column if not exists platform_share_percent numeric(5,2) not null default 0;

alter table public.food_campaigns drop constraint if exists food_campaigns_platform_share_check;
alter table public.food_campaigns add constraint food_campaigns_platform_share_check
  check (platform_share_percent >= 0 and platform_share_percent <= 100
         and (platform_campaign_id is not null or platform_share_percent = 0));

-- One live enrollment per store and campaign (leaving soft-deletes the row).
create unique index if not exists food_campaigns_platform_store_uidx
  on public.food_campaigns(platform_campaign_id, store_id)
  where platform_campaign_id is not null and deleted_at is null;

alter table public.food_order_campaigns
  add column if not exists platform_campaign_id uuid references public.food_platform_campaigns(id) on delete set null,
  add column if not exists platform_funded numeric(10,2) not null default 0,
  add column if not exists settlement_id uuid references public.food_platform_settlements(id) on delete set null;

alter table public.food_order_campaigns drop constraint if exists food_order_campaigns_platform_funded_check;
alter table public.food_order_campaigns add constraint food_order_campaigns_platform_funded_check
  check (platform_funded >= 0 and platform_funded <= campaign_discount + delivery_discount);

create index if not exists food_order_campaigns_platform_owed_idx
  on public.food_order_campaigns(platform_campaign_id)
  where platform_funded > 0 and settlement_id is null;

alter table public.food_platform_campaigns enable row level security;
alter table public.food_platform_settlements enable row level security;
revoke all on table public.food_platform_campaigns from public, anon, authenticated;
revoke all on table public.food_platform_settlements from public, anon, authenticated;

-- guards ----------------------------------------------------------------------

-- Terms of a joined WYNOS campaign change only inside the RPCs below, which
-- set wyn.platform_campaign_write for their own transaction. usage_count
-- (order placed / cancelled) is not a term and always passes.
create or replace function internal.food_campaign_platform_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('wyn.platform_campaign_write', true), '') = 'on' then
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' then
    if new.platform_campaign_id is not null or new.platform_share_percent <> 0 then
      raise exception 'WYNOS campaigns can only be joined from the campaign page';
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    -- A store being deleted cascades here after its row is gone; allow that.
    if old.platform_campaign_id is not null
       and exists (select 1 from public.food_stores s where s.id = old.store_id) then
      raise exception 'WYNOS campaign terms are managed by WYNOS';
    end if;
    return old;
  end if;
  if old.platform_campaign_id is not null or new.platform_campaign_id is not null then
    if (to_jsonb(new) - 'usage_count' - 'updated_at') is distinct from (to_jsonb(old) - 'usage_count' - 'updated_at') then
      raise exception 'WYNOS campaign terms are managed by WYNOS';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_campaign_platform_guard() from public, anon, authenticated;

drop trigger if exists food_campaigns_platform_guard on public.food_campaigns;
create trigger food_campaigns_platform_guard
before insert or update or delete on public.food_campaigns
for each row execute function internal.food_campaign_platform_guard();

-- Items of a joined WYNOS campaign are never set (WYNOS campaigns are store-wide).
create or replace function internal.food_campaign_items_platform_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.food_campaigns c
    where c.id = coalesce(new.campaign_id, old.campaign_id) and c.platform_campaign_id is not null
  ) then
    raise exception 'WYNOS campaign terms are managed by WYNOS';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function internal.food_campaign_items_platform_guard() from public, anon, authenticated;

drop trigger if exists food_campaign_items_platform_guard on public.food_campaign_items;
create trigger food_campaign_items_platform_guard
before insert or update or delete on public.food_campaign_items
for each row execute function internal.food_campaign_items_platform_guard();

-- Snapshot WYNOS's part of the discount on every order that used a campaign.
create or replace function internal.food_order_campaign_platform_share()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_platform uuid;
  v_share numeric;
begin
  select c.platform_campaign_id, c.platform_share_percent into v_platform, v_share
  from public.food_campaigns c where c.id = new.campaign_id;
  new.platform_campaign_id := v_platform;
  new.platform_funded := case
    when v_platform is null then 0
    else round((new.campaign_discount + new.delivery_discount) * coalesce(v_share, 0) / 100, 2)
  end;
  new.settlement_id := null;
  return new;
end;
$$;

revoke all on function internal.food_order_campaign_platform_share() from public, anon, authenticated;

drop trigger if exists food_order_campaigns_platform_share on public.food_order_campaigns;
create trigger food_order_campaigns_platform_share
before insert on public.food_order_campaigns
for each row execute function internal.food_order_campaign_platform_share();

-- What WYNOS owes a store: its share of discounts on delivered, not refunded,
-- not yet settled orders.
create or replace function internal.food_platform_owed_rows(p_store_id uuid)
returns table (order_id uuid, platform_campaign_id uuid, amount numeric)
language sql
stable
set search_path = ''
as $$
  select foc.order_id, foc.platform_campaign_id, foc.platform_funded
  from public.food_order_campaigns foc
  join public.food_orders o on o.id = foc.order_id
  where o.store_id = p_store_id
    and foc.platform_funded > 0
    and foc.released_at is null
    and foc.settlement_id is null
    and o.status = 'delivered'
    and o.payment_status <> 'refunded'
$$;

revoke all on function internal.food_platform_owed_rows(uuid) from public, anon, authenticated;

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
    'admin_platform_campaign_saved',
    'admin_platform_campaign_settled'
  ]) as t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end;
$$;

-- the store's own promotions list hides joined WYNOS campaigns ------------------

create or replace function public.merchant_food_campaigns(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_can_manage boolean;
  v_campaigns jsonb;
begin
  if not public.merchant_has_store_role(
    p_store_id,
    array['owner','admin','manager','orders','support','delivery']
  ) then
    raise exception 'merchant access required';
  end if;

  v_can_manage := public.merchant_has_store_role(
    p_store_id,
    array['owner','admin','manager']
  );

  select coalesce(jsonb_agg(x.payload order by x.created_at desc),'[]'::jsonb)
    into v_campaigns
  from (
    select
      c.created_at,
      jsonb_build_object(
        'id', c.id,
        'store_id', c.store_id,
        'name', c.name,
        'campaign_type', c.campaign_type,
        'scope', c.scope,
        'discount_value', c.discount_value,
        'min_subtotal', c.min_subtotal,
        'max_discount', c.max_discount,
        'starts_at', c.starts_at,
        'ends_at', c.ends_at,
        'usage_limit', c.usage_limit,
        'usage_count', c.usage_count,
        'is_active', c.is_active,
        'created_at', c.created_at,
        'updated_at', c.updated_at,
        'item_ids', coalesce((
          select jsonb_agg(ci.menu_item_id order by ci.menu_item_id::text)
          from public.food_campaign_items ci
          where ci.campaign_id=c.id
        ), '[]'::jsonb),
        'redeemed_count', (
          select count(*)
          from public.food_order_campaigns foc
          join public.food_orders o on o.id=foc.order_id
          where foc.campaign_id=c.id
            and foc.released_at is null
            and o.status <> 'cancelled'
        ),
        'delivered_orders', (
          select count(*)
          from public.food_order_campaigns foc
          join public.food_orders o on o.id=foc.order_id
          where foc.campaign_id=c.id
            and foc.released_at is null
            and o.status='delivered'
        ),
        'sales_total', coalesce((
          select sum(o.total)
          from public.food_order_campaigns foc
          join public.food_orders o on o.id=foc.order_id
          where foc.campaign_id=c.id
            and foc.released_at is null
            and o.status='delivered'
        ),0),
        'discount_total', coalesce((
          select sum(foc.campaign_discount + foc.delivery_discount)
          from public.food_order_campaigns foc
          join public.food_orders o on o.id=foc.order_id
          where foc.campaign_id=c.id
            and foc.released_at is null
            and o.status='delivered'
        ),0)
      ) as payload
    from public.food_campaigns c
    where c.store_id=p_store_id
      and c.deleted_at is null
      -- WYN-206: WYNOS campaigns the store joined are listed on their own page.
      and c.platform_campaign_id is null
  ) x;

  return jsonb_build_object(
    'can_manage', v_can_manage,
    'campaigns', coalesce(v_campaigns,'[]'::jsonb)
  );
end;
$$;

revoke all on function public.merchant_food_campaigns(uuid) from public, anon;
grant execute on function public.merchant_food_campaigns(uuid) to authenticated;

-- Merchant: list, join and leave WYNOS campaigns ---------------------------------

create or replace function public.merchant_platform_campaigns(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaigns jsonb;
  v_owed numeric;
  v_owed_orders integer;
  v_settlements jsonb;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders','support','delivery']) then
    raise exception 'merchant access required';
  end if;

  select coalesce(jsonb_agg(x.payload order by x.sort_key desc), '[]'::jsonb) into v_campaigns
  from (
    select
      coalesce(sc.created_at, pc.starts_at) as sort_key,
      jsonb_build_object(
        'id', pc.id,
        'name', pc.name,
        'description', pc.description,
        'campaign_type', pc.campaign_type,
        'discount_value', pc.discount_value,
        'min_subtotal', pc.min_subtotal,
        'max_discount', pc.max_discount,
        'starts_at', pc.starts_at,
        'ends_at', pc.ends_at,
        'usage_limit_per_store', pc.usage_limit_per_store,
        'platform_share_percent', pc.platform_share_percent,
        'join_open', pc.join_open,
        'is_active', pc.is_active,
        'joined', sc.id is not null,
        'joined_at', sc.created_at,
        'usage_count', coalesce(sc.usage_count, 0),
        'delivered_orders', coalesce(st.delivered_orders, 0),
        'discount_total', coalesce(st.discount_total, 0),
        'platform_funded_total', coalesce(st.platform_funded_total, 0)
      ) as payload
    from public.food_platform_campaigns pc
    left join public.food_campaigns sc
      on sc.platform_campaign_id = pc.id and sc.store_id = p_store_id and sc.deleted_at is null
    left join lateral (
      select
        count(*)::integer as delivered_orders,
        sum(foc.campaign_discount + foc.delivery_discount) as discount_total,
        sum(foc.platform_funded) as platform_funded_total
      from public.food_order_campaigns foc
      join public.food_orders o on o.id = foc.order_id
      where foc.platform_campaign_id = pc.id
        and o.store_id = p_store_id
        and foc.released_at is null
        and o.status = 'delivered'
    ) st on true
    where sc.id is not null
       or (pc.is_active and pc.join_open and (pc.ends_at is null or pc.ends_at > now()))
  ) x;

  select coalesce(sum(r.amount), 0), count(*)::integer into v_owed, v_owed_orders
  from internal.food_platform_owed_rows(p_store_id) r;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'amount', s.amount, 'order_count', s.order_count,
    'reference', s.reference, 'note', s.note, 'created_at', s.created_at
  ) order by s.created_at desc), '[]'::jsonb) into v_settlements
  from (
    select * from public.food_platform_settlements
    where store_id = p_store_id
    order by created_at desc
    limit 20
  ) s;

  return jsonb_build_object(
    'can_manage', public.merchant_has_store_role(p_store_id, array['owner','admin','manager']),
    'campaigns', v_campaigns,
    'owed', v_owed,
    'owed_orders', v_owed_orders,
    'settlements', v_settlements
  );
end;
$$;

revoke all on function public.merchant_platform_campaigns(uuid) from public, anon;
grant execute on function public.merchant_platform_campaigns(uuid) to authenticated;

create or replace function public.merchant_join_platform_campaign(p_store_id uuid, p_campaign_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pc public.food_platform_campaigns%rowtype;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) then
    raise exception 'merchant manager access required';
  end if;
  if exists (select 1 from public.food_stores s where s.id = p_store_id and s.admin_suspended_at is not null) then
    raise exception 'store is suspended';
  end if;
  select * into v_pc from public.food_platform_campaigns where id = p_campaign_id for share;
  if not found or not v_pc.is_active or not v_pc.join_open or (v_pc.ends_at is not null and v_pc.ends_at <= now()) then
    raise exception 'campaign is not open for joining';
  end if;
  if exists (
    select 1 from public.food_campaigns c
    where c.platform_campaign_id = p_campaign_id and c.store_id = p_store_id and c.deleted_at is null
  ) then
    return;
  end if;

  perform set_config('wyn.platform_campaign_write', 'on', true);
  insert into public.food_campaigns (
    store_id, created_by, name, campaign_type, scope, discount_value, min_subtotal, max_discount,
    starts_at, ends_at, usage_limit, is_active, platform_campaign_id, platform_share_percent
  ) values (
    p_store_id, auth.uid(), v_pc.name, v_pc.campaign_type, 'store', v_pc.discount_value, v_pc.min_subtotal, v_pc.max_discount,
    v_pc.starts_at, v_pc.ends_at, v_pc.usage_limit_per_store, true, v_pc.id, v_pc.platform_share_percent
  );
  perform set_config('wyn.platform_campaign_write', '', true);
end;
$$;

revoke all on function public.merchant_join_platform_campaign(uuid, uuid) from public, anon;
grant execute on function public.merchant_join_platform_campaign(uuid, uuid) to authenticated;

create or replace function public.merchant_leave_platform_campaign(p_store_id uuid, p_campaign_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) then
    raise exception 'merchant manager access required';
  end if;
  perform set_config('wyn.platform_campaign_write', 'on', true);
  update public.food_campaigns
  set is_active = false, deleted_at = now()
  where platform_campaign_id = p_campaign_id and store_id = p_store_id and deleted_at is null;
  perform set_config('wyn.platform_campaign_write', '', true);
end;
$$;

revoke all on function public.merchant_leave_platform_campaign(uuid, uuid) from public, anon;
grant execute on function public.merchant_leave_platform_campaign(uuid, uuid) to authenticated;

-- WYNOS Admin: design campaigns, see what is owed, record transfers --------------

create or replace function public.admin_platform_campaigns()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;
  select coalesce(jsonb_agg(to_jsonb(pc) || jsonb_build_object(
    'joined_stores', (select count(*) from public.food_campaigns c where c.platform_campaign_id = pc.id and c.deleted_at is null),
    'delivered_orders', coalesce(st.delivered_orders, 0),
    'discount_total', coalesce(st.discount_total, 0),
    'platform_funded_total', coalesce(st.platform_funded_total, 0)
  ) order by pc.created_at desc), '[]'::jsonb) into v_rows
  from public.food_platform_campaigns pc
  left join lateral (
    select count(*)::integer as delivered_orders,
           sum(foc.campaign_discount + foc.delivery_discount) as discount_total,
           sum(foc.platform_funded) as platform_funded_total
    from public.food_order_campaigns foc
    join public.food_orders o on o.id = foc.order_id
    where foc.platform_campaign_id = pc.id and foc.released_at is null and o.status = 'delivered'
  ) st on true;
  return v_rows;
end;
$$;

revoke all on function public.admin_platform_campaigns() from public, anon;
grant execute on function public.admin_platform_campaigns() to authenticated;

create or replace function public.admin_upsert_platform_campaign(
  p_campaign_id uuid,
  p_name text,
  p_description text,
  p_campaign_type text,
  p_discount_value numeric,
  p_min_subtotal numeric,
  p_max_discount numeric,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_usage_limit_per_store integer,
  p_platform_share_percent numeric,
  p_join_open boolean,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_id uuid;
  v_type text := lower(btrim(coalesce(p_campaign_type, '')));
  v_value numeric := case when lower(btrim(coalesce(p_campaign_type, ''))) = 'free_delivery' then 0 else coalesce(p_discount_value, 0) end;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS campaigns';
  end if;

  if p_campaign_id is null then
    insert into public.food_platform_campaigns (
      name, description, campaign_type, discount_value, min_subtotal, max_discount, starts_at, ends_at,
      usage_limit_per_store, platform_share_percent, join_open, is_active, created_by
    ) values (
      btrim(coalesce(p_name, '')), nullif(btrim(coalesce(p_description, '')), ''), v_type, v_value,
      coalesce(p_min_subtotal, 0), p_max_discount, coalesce(p_starts_at, now()), p_ends_at,
      p_usage_limit_per_store, coalesce(p_platform_share_percent, 0), coalesce(p_join_open, true), coalesce(p_is_active, true), v_admin
    ) returning id into v_id;
  else
    update public.food_platform_campaigns set
      name = btrim(coalesce(p_name, '')),
      description = nullif(btrim(coalesce(p_description, '')), ''),
      campaign_type = v_type,
      discount_value = v_value,
      min_subtotal = coalesce(p_min_subtotal, 0),
      max_discount = p_max_discount,
      starts_at = coalesce(p_starts_at, starts_at),
      ends_at = p_ends_at,
      usage_limit_per_store = p_usage_limit_per_store,
      platform_share_percent = coalesce(p_platform_share_percent, 0),
      join_open = coalesce(p_join_open, true),
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_campaign_id
    returning id into v_id;
    if v_id is null then
      raise exception 'campaign not found';
    end if;

    -- Stores that joined follow the new terms for their next orders; orders
    -- already placed keep the share they were placed with.
    perform set_config('wyn.platform_campaign_write', 'on', true);
    update public.food_campaigns c set
      name = pc.name,
      campaign_type = pc.campaign_type,
      discount_value = pc.discount_value,
      min_subtotal = pc.min_subtotal,
      max_discount = pc.max_discount,
      starts_at = pc.starts_at,
      ends_at = pc.ends_at,
      usage_limit = pc.usage_limit_per_store,
      platform_share_percent = pc.platform_share_percent,
      is_active = pc.is_active
    from public.food_platform_campaigns pc
    where pc.id = v_id and c.platform_campaign_id = v_id and c.deleted_at is null;
    perform set_config('wyn.platform_campaign_write', '', true);
  end if;

  perform internal.log_audit_event(
    v_admin, 'admin_platform_campaign_saved', null,
    jsonb_build_object('campaign_id', v_id, 'name', btrim(coalesce(p_name, '')), 'campaign_type', v_type,
      'discount_value', v_value, 'platform_share_percent', coalesce(p_platform_share_percent, 0),
      'is_active', coalesce(p_is_active, true), 'join_open', coalesce(p_join_open, true))
  );
  return v_id;
end;
$$;

revoke all on function public.admin_upsert_platform_campaign(uuid,text,text,text,numeric,numeric,numeric,timestamptz,timestamptz,integer,numeric,boolean,boolean) from public, anon;
grant execute on function public.admin_upsert_platform_campaign(uuid,text,text,text,numeric,numeric,numeric,timestamptz,timestamptz,integer,numeric,boolean,boolean) to authenticated;

create or replace function public.admin_platform_owed()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view WYNOS campaign payouts';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'store_id', s.id,
    'store_name', s.name,
    'promptpay_name', s.promptpay_name,
    'promptpay_id', s.promptpay_id,
    'bank_name', s.bank_name,
    'bank_account_name', s.bank_account_name,
    'bank_account_number', s.bank_account_number,
    'owed', o.owed,
    'owed_orders', o.owed_orders,
    'last_settled_at', (select max(ps.created_at) from public.food_platform_settlements ps where ps.store_id = s.id)
  ) order by o.owed desc), '[]'::jsonb) into v_rows
  from public.food_stores s
  join lateral (
    select sum(r.amount) as owed, count(*)::integer as owed_orders
    from internal.food_platform_owed_rows(s.id) r
  ) o on o.owed_orders > 0;
  return v_rows;
end;
$$;

revoke all on function public.admin_platform_owed() from public, anon;
grant execute on function public.admin_platform_owed() to authenticated;

create or replace function public.admin_settle_platform_store(p_store_id uuid, p_reference text, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_reference text := left(btrim(coalesce(p_reference, '')), 120);
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
  v_store public.food_stores%rowtype;
  v_amount numeric;
  v_count integer;
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can record WYNOS campaign payouts';
  end if;
  if v_reference = '' then
    raise exception 'transfer reference is required';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'store not found';
  end if;

  -- Lock the owed rows so two admins cannot settle the same orders twice.
  perform 1 from public.food_order_campaigns foc
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r)
  for update;

  select coalesce(sum(r.amount), 0), count(*)::integer into v_amount, v_count
  from internal.food_platform_owed_rows(p_store_id) r;
  if v_count = 0 then
    raise exception 'nothing to settle';
  end if;

  insert into public.food_platform_settlements (store_id, amount, order_count, reference, note, settled_by)
  values (p_store_id, v_amount, v_count, v_reference, v_note, v_admin)
  returning id into v_id;

  update public.food_order_campaigns foc set settlement_id = v_id
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r);

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    'WYNOS โอนส่วนลดแคมเปญคืนร้าน ' || v_store.name || ' แล้ว ' || to_char(v_amount, 'FM999,999,990.00') || ' บาท (' || v_count || ' ออเดอร์) อ้างอิง ' || v_reference
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin');

  perform internal.log_audit_event(
    v_admin, 'admin_platform_campaign_settled', null,
    jsonb_build_object('store_id', p_store_id, 'store_name', v_store.name, 'amount', v_amount,
      'order_count', v_count, 'reference', v_reference, 'settlement_id', v_id)
  );
  return v_id;
end;
$$;

revoke all on function public.admin_settle_platform_store(uuid, text, text) from public, anon;
grant execute on function public.admin_settle_platform_store(uuid, text, text) to authenticated;

-- WYNOS Food: badges for stores in a running WYNOS campaign -----------------------

create or replace function public.food_platform_campaign_badges()
returns table (store_id uuid, campaign_id uuid, campaign_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.store_id, pc.id, pc.name
  from public.food_campaigns c
  join public.food_platform_campaigns pc on pc.id = c.platform_campaign_id
  join public.food_stores s on s.id = c.store_id
  where c.deleted_at is null
    and c.is_active
    and pc.is_active
    and pc.starts_at <= now()
    and (pc.ends_at is null or pc.ends_at > now())
    and (c.usage_limit is null or c.usage_count < c.usage_limit)
    and s.is_published
    and s.admin_suspended_at is null
$$;

revoke all on function public.food_platform_campaign_badges() from public, anon;
grant execute on function public.food_platform_campaign_badges() to authenticated;
