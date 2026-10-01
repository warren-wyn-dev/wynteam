-- WYNOS Merchant Campaign Center v1.
-- Automatic best-campaign application for WYNOS Food orders.
-- Supports percentage, fixed amount and free-delivery campaigns, with optional
-- minimum spend, item scope, max discount, schedule and usage limits.

create table if not exists public.food_campaigns (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  name text not null,
  campaign_type text not null,
  scope text not null default 'store',
  discount_value numeric(10,2) not null default 0,
  min_subtotal numeric(10,2) not null default 0,
  max_discount numeric(10,2),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  usage_limit integer,
  usage_count integer not null default 0,
  is_active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_campaigns_name_length check (char_length(btrim(name)) between 2 and 80),
  constraint food_campaigns_type_check check (campaign_type in ('percentage','fixed','free_delivery')),
  constraint food_campaigns_scope_check check (scope in ('store','items')),
  constraint food_campaigns_discount_check check (
    (campaign_type='percentage' and discount_value > 0 and discount_value <= 100)
    or (campaign_type='fixed' and discount_value > 0)
    or (campaign_type='free_delivery' and discount_value = 0)
  ),
  constraint food_campaigns_min_subtotal_check check (min_subtotal >= 0),
  constraint food_campaigns_max_discount_check check (max_discount is null or max_discount > 0),
  constraint food_campaigns_dates_check check (ends_at is null or ends_at > starts_at),
  constraint food_campaigns_usage_limit_check check (usage_limit is null or usage_limit > 0),
  constraint food_campaigns_usage_count_check check (usage_count >= 0),
  constraint food_campaigns_free_delivery_scope_check check (campaign_type <> 'free_delivery' or scope='store')
);

create index if not exists food_campaigns_store_status_idx
  on public.food_campaigns(store_id,is_active,starts_at,ends_at)
  where deleted_at is null;

create table if not exists public.food_campaign_items (
  campaign_id uuid not null references public.food_campaigns(id) on delete cascade,
  menu_item_id uuid not null references public.food_menu_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (campaign_id,menu_item_id)
);

create index if not exists food_campaign_items_menu_idx
  on public.food_campaign_items(menu_item_id,campaign_id);

alter table public.food_orders
  add column if not exists campaign_id uuid references public.food_campaigns(id) on delete set null,
  add column if not exists campaign_name text,
  add column if not exists campaign_discount numeric(10,2) not null default 0,
  add column if not exists delivery_discount numeric(10,2) not null default 0;

alter table public.food_orders
  drop constraint if exists food_orders_campaign_discount_check;
alter table public.food_orders
  add constraint food_orders_campaign_discount_check
  check (campaign_discount >= 0 and campaign_discount <= subtotal);

alter table public.food_orders
  drop constraint if exists food_orders_delivery_discount_check;
alter table public.food_orders
  add constraint food_orders_delivery_discount_check
  check (delivery_discount >= 0 and delivery_discount <= delivery_fee);

create index if not exists food_orders_campaign_id_idx
  on public.food_orders(campaign_id)
  where campaign_id is not null;

create table if not exists public.food_order_campaigns (
  order_id uuid primary key references public.food_orders(id) on delete cascade,
  campaign_id uuid references public.food_campaigns(id) on delete set null,
  campaign_name text not null,
  campaign_type text not null,
  campaign_discount numeric(10,2) not null default 0,
  delivery_discount numeric(10,2) not null default 0,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  constraint food_order_campaigns_type_check check (campaign_type in ('percentage','fixed','free_delivery')),
  constraint food_order_campaigns_discount_check check (campaign_discount >= 0 and delivery_discount >= 0)
);

create index if not exists food_order_campaigns_campaign_idx
  on public.food_order_campaigns(campaign_id,created_at desc)
  where campaign_id is not null;

alter table public.food_campaigns enable row level security;
alter table public.food_campaign_items enable row level security;
alter table public.food_order_campaigns enable row level security;

revoke all on table public.food_campaigns from public, anon, authenticated;
revoke all on table public.food_campaign_items from public, anon, authenticated;
revoke all on table public.food_order_campaigns from public, anon, authenticated;

create or replace function internal.food_campaign_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function internal.food_campaign_touch_updated_at() from public, anon, authenticated;

drop trigger if exists trg_food_campaigns_touch on public.food_campaigns;
create trigger trg_food_campaigns_touch
before update on public.food_campaigns
for each row execute function internal.food_campaign_touch_updated_at();

create or replace function internal.food_campaign_candidates(
  p_store_id uuid,
  p_subtotal numeric,
  p_delivery_fee numeric,
  p_item_totals jsonb
)
returns table (
  campaign_id uuid,
  campaign_name text,
  campaign_type text,
  campaign_discount numeric,
  delivery_discount numeric,
  saving numeric
)
language sql
stable
set search_path = ''
as $$
  with base as (
    select
      c.id,
      c.name,
      c.campaign_type,
      c.discount_value,
      c.max_discount,
      c.scope,
      case
        when c.scope='store' then greatest(coalesce(p_subtotal,0),0)
        else greatest(coalesce(scoped.item_subtotal,0),0)
      end as eligible_subtotal
    from public.food_campaigns c
    left join lateral (
      select coalesce(sum((e.value)::numeric),0) as item_subtotal
      from jsonb_each_text(coalesce(p_item_totals,'{}'::jsonb)) as e(key,value)
      join public.food_campaign_items ci
        on ci.campaign_id=c.id
       and ci.menu_item_id=(e.key)::uuid
    ) scoped on true
    where c.store_id=p_store_id
      and c.deleted_at is null
      and c.is_active
      and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
      and (c.usage_limit is null or c.usage_count < c.usage_limit)
      and greatest(coalesce(p_subtotal,0),0) >= c.min_subtotal
  ),
  calc as (
    select
      id,
      name,
      campaign_type,
      case
        when campaign_type='percentage' and eligible_subtotal > 0 then
          round(
            least(
              eligible_subtotal * discount_value / 100,
              coalesce(max_discount, eligible_subtotal * discount_value / 100),
              eligible_subtotal
            ),
            2
          )
        when campaign_type='fixed' and eligible_subtotal > 0 then
          round(least(discount_value,eligible_subtotal),2)
        else 0::numeric
      end as campaign_discount,
      case
        when campaign_type='free_delivery' then round(greatest(coalesce(p_delivery_fee,0),0),2)
        else 0::numeric
      end as delivery_discount
    from base
  )
  select
    id as campaign_id,
    name as campaign_name,
    campaign_type,
    campaign_discount,
    delivery_discount,
    campaign_discount + delivery_discount as saving
  from calc
  where campaign_discount + delivery_discount > 0
  order by saving desc, id
$$;

revoke all on function internal.food_campaign_candidates(uuid,numeric,numeric,jsonb)
  from public, anon, authenticated;

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
  ) x;

  return jsonb_build_object(
    'can_manage', v_can_manage,
    'campaigns', coalesce(v_campaigns,'[]'::jsonb)
  );
end;
$$;

revoke all on function public.merchant_food_campaigns(uuid) from public, anon;
grant execute on function public.merchant_food_campaigns(uuid) to authenticated;

create or replace function public.merchant_upsert_food_campaign(
  p_store_id uuid,
  p_name text,
  p_campaign_type text,
  p_scope text,
  p_discount_value numeric default 0,
  p_min_subtotal numeric default 0,
  p_max_discount numeric default null,
  p_starts_at timestamptz default now(),
  p_ends_at timestamptz default null,
  p_usage_limit integer default null,
  p_item_ids uuid[] default '{}'::uuid[],
  p_campaign_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_account_id uuid;
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_scope text := lower(trim(coalesce(p_scope,'')));
  v_type text := lower(trim(coalesce(p_campaign_type,'')));
  v_name text := trim(coalesce(p_name,''));
  v_start timestamptz := coalesce(p_starts_at,now());
  v_item_count integer := 0;
begin
  if v_actor is null then raise exception 'authentication required'; end if;
  if not public.merchant_has_store_role(p_store_id,array['owner','admin','manager']) then
    raise exception 'campaign management role required';
  end if;
  if char_length(v_name) not between 2 and 80 then raise exception 'invalid campaign name'; end if;
  if v_type not in ('percentage','fixed','free_delivery') then raise exception 'invalid campaign type'; end if;
  if v_scope not in ('store','items') then raise exception 'invalid campaign scope'; end if;
  if v_type='free_delivery' and v_scope<>'store' then raise exception 'free delivery must apply to the whole store'; end if;
  if v_type='percentage' and (coalesce(p_discount_value,0) <= 0 or p_discount_value > 100) then
    raise exception 'invalid percentage discount';
  end if;
  if v_type='fixed' and coalesce(p_discount_value,0) <= 0 then raise exception 'invalid fixed discount'; end if;
  if coalesce(p_min_subtotal,0) < 0 then raise exception 'invalid minimum subtotal'; end if;
  if p_max_discount is not null and p_max_discount <= 0 then raise exception 'invalid maximum discount'; end if;
  if p_ends_at is not null and p_ends_at <= v_start then raise exception 'campaign end must be after start'; end if;
  if p_usage_limit is not null and p_usage_limit <= 0 then raise exception 'invalid usage limit'; end if;

  if v_scope='items' then
    select count(distinct x) into v_item_count
    from unnest(coalesce(p_item_ids,'{}'::uuid[])) x;
    if v_item_count=0 then raise exception 'select at least one menu item'; end if;
    if v_item_count <> (
      select count(*)
      from public.food_menu_items mi
      where mi.store_id=p_store_id
        and mi.id=any(coalesce(p_item_ids,'{}'::uuid[]))
    ) then
      raise exception 'invalid campaign menu item';
    end if;
  end if;

  select s.merchant_account_id into v_account_id
  from public.food_stores s
  where s.id=p_store_id;
  if v_account_id is null then raise exception 'merchant account not found'; end if;

  if p_campaign_id is null then
    insert into public.food_campaigns(
      store_id,created_by,name,campaign_type,scope,discount_value,
      min_subtotal,max_discount,starts_at,ends_at,usage_limit,is_active
    ) values (
      p_store_id,v_actor,v_name,v_type,v_scope,
      case when v_type='free_delivery' then 0 else round(coalesce(p_discount_value,0),2) end,
      round(coalesce(p_min_subtotal,0),2),
      case when v_type='percentage' then p_max_discount else null end,
      v_start,p_ends_at,p_usage_limit,true
    )
    returning id into v_id;
  else
    select c.id into v_id
    from public.food_campaigns c
    where c.id=p_campaign_id
      and c.store_id=p_store_id
      and c.deleted_at is null
    for update;
    if v_id is null then raise exception 'campaign not found'; end if;

    update public.food_campaigns
    set name=v_name,
        campaign_type=v_type,
        scope=v_scope,
        discount_value=case when v_type='free_delivery' then 0 else round(coalesce(p_discount_value,0),2) end,
        min_subtotal=round(coalesce(p_min_subtotal,0),2),
        max_discount=case when v_type='percentage' then p_max_discount else null end,
        starts_at=v_start,
        ends_at=p_ends_at,
        usage_limit=p_usage_limit
    where id=v_id;
  end if;

  delete from public.food_campaign_items where campaign_id=v_id;
  if v_scope='items' then
    insert into public.food_campaign_items(campaign_id,menu_item_id)
    select v_id,x
    from (select distinct unnest(coalesce(p_item_ids,'{}'::uuid[])) as x) q;
  end if;

  select p.username into v_actor_name from public.profiles p where p.id=v_actor;
  insert into public.merchant_activity_log(
    merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
  ) values (
    v_account_id,v_actor,v_actor_name,
    case when p_campaign_id is null then 'campaign_created' else 'campaign_updated' end,
    'food_campaign',v_id,
    jsonb_build_object('name',v_name,'type',v_type,'scope',v_scope)
  );

  return v_id;
end;
$$;

revoke all on function public.merchant_upsert_food_campaign(uuid,text,text,text,numeric,numeric,numeric,timestamptz,timestamptz,integer,uuid[],uuid)
  from public, anon;
grant execute on function public.merchant_upsert_food_campaign(uuid,text,text,text,numeric,numeric,numeric,timestamptz,timestamptz,integer,uuid[],uuid)
  to authenticated;

create or replace function public.merchant_set_food_campaign_active(
  p_store_id uuid,
  p_campaign_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_name text;
begin
  if v_actor is null then raise exception 'authentication required'; end if;
  if not public.merchant_has_store_role(p_store_id,array['owner','admin','manager']) then
    raise exception 'campaign management role required';
  end if;

  update public.food_campaigns c
  set is_active=coalesce(p_active,false)
  where c.id=p_campaign_id
    and c.store_id=p_store_id
    and c.deleted_at is null
  returning c.name into v_name;
  if v_name is null then raise exception 'campaign not found'; end if;

  select s.merchant_account_id into v_account_id from public.food_stores s where s.id=p_store_id;
  select p.username into v_actor_name from public.profiles p where p.id=v_actor;

  insert into public.merchant_activity_log(
    merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
  ) values (
    v_account_id,v_actor,v_actor_name,'campaign_active_changed','food_campaign',p_campaign_id,
    jsonb_build_object('name',v_name,'active',coalesce(p_active,false))
  );
end;
$$;

revoke all on function public.merchant_set_food_campaign_active(uuid,uuid,boolean) from public, anon;
grant execute on function public.merchant_set_food_campaign_active(uuid,uuid,boolean) to authenticated;

create or replace function public.merchant_delete_food_campaign(
  p_store_id uuid,
  p_campaign_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_name text;
begin
  if v_actor is null then raise exception 'authentication required'; end if;
  if not public.merchant_has_store_role(p_store_id,array['owner','admin','manager']) then
    raise exception 'campaign management role required';
  end if;

  update public.food_campaigns c
  set is_active=false, deleted_at=now()
  where c.id=p_campaign_id
    and c.store_id=p_store_id
    and c.deleted_at is null
  returning c.name into v_name;
  if v_name is null then raise exception 'campaign not found'; end if;

  select s.merchant_account_id into v_account_id from public.food_stores s where s.id=p_store_id;
  select p.username into v_actor_name from public.profiles p where p.id=v_actor;

  insert into public.merchant_activity_log(
    merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
  ) values (
    v_account_id,v_actor,v_actor_name,'campaign_deleted','food_campaign',p_campaign_id,
    jsonb_build_object('name',v_name)
  );
end;
$$;

revoke all on function public.merchant_delete_food_campaign(uuid,uuid) from public, anon;
grant execute on function public.merchant_delete_food_campaign(uuid,uuid) to authenticated;

create or replace function public.food_quote_order(
  p_store_id uuid,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_line jsonb;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_total numeric(10,2);
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store from public.food_stores where id=p_store_id;
  if not found
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id and store_id=p_store_id and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    v_subtotal := v_subtotal + (v_item.price * v_qty);
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_item.price * v_qty)
    );
  end loop;

  select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
    into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
  from internal.food_campaign_candidates(
    p_store_id,v_subtotal,v_store.delivery_fee,v_item_totals
  ) c
  limit 1;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  v_total := greatest(v_subtotal - v_campaign_discount + v_store.delivery_fee - v_delivery_discount,0);

  return jsonb_build_object(
    'subtotal',v_subtotal,
    'delivery_fee',v_store.delivery_fee,
    'campaign_discount',v_campaign_discount,
    'delivery_discount',v_delivery_discount,
    'total',v_total,
    'campaign_id',v_campaign_id,
    'campaign_name',v_campaign_name,
    'campaign_type',v_campaign_type
  );
end;
$$;

revoke all on function public.food_quote_order(uuid,jsonb) from public, anon;
grant execute on function public.food_quote_order(uuid,jsonb) to authenticated;

create or replace function public.food_create_order(
  p_store_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_campaign public.food_campaigns%rowtype;
  v_line jsonb;
  v_order_id uuid;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2);
  v_count integer := 0;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(trim(p_recipient_name)),0)=0
     or coalesce(char_length(trim(p_recipient_phone)),0)=0
     or coalesce(char_length(trim(p_shipping_address)),0)=0 then
    raise exception 'recipient information is required';
  end if;

  if jsonb_typeof(p_items)<>'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store from public.food_stores where id=p_store_id;
  if not found
     or not v_store.is_open
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id
      and store_id=p_store_id
      and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    v_subtotal := v_subtotal + (v_item.price * v_qty);
    v_count := v_count + 1;
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_item.price * v_qty)
    );
  end loop;

  if v_count=0 or v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

  -- Select the best promotion, lock it, then re-check under the lock.
  -- If another checkout consumed its final limited use while we waited,
  -- retry so the customer can still receive the next-best eligible campaign.
  loop
    v_campaign_id := null;
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;

    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_store.delivery_fee,v_item_totals
    ) c
    limit 1;

    exit when v_campaign_id is null;

    select * into v_campaign
    from public.food_campaigns c
    where c.id=v_campaign_id
    for update;

    v_campaign_id := null;
    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_store.delivery_fee,v_item_totals
    ) c
    where c.campaign_id=v_campaign.id
    limit 1;

    exit when v_campaign_id is not null;
  end loop;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  if v_campaign_id is null then
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;
  end if;

  v_total := greatest(v_subtotal - v_campaign_discount + v_store.delivery_fee - v_delivery_discount,0);

  insert into public.food_orders(
    store_id,buyer_id,created_by,source,status,payment_status,
    recipient_name,recipient_phone,shipping_address,customer_note,
    subtotal,delivery_fee,campaign_id,campaign_name,campaign_discount,delivery_discount,total
  ) values (
    p_store_id,
    auth.uid(),
    auth.uid(),
    'app',
    'pending_acceptance',
    'pending',
    left(trim(p_recipient_name),120),
    left(trim(p_recipient_phone),50),
    left(trim(p_shipping_address),800),
    nullif(left(trim(coalesce(p_customer_note,'')),800),''),
    v_subtotal,
    v_store.delivery_fee,
    v_campaign_id,
    v_campaign_name,
    v_campaign_discount,
    v_delivery_discount,
    v_total
  )
  returning id into v_order_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id and store_id=p_store_id;

    insert into public.food_order_items(
      order_id,menu_item_id,item_name,unit_price,quantity,selected_options,item_note
    ) values (
      v_order_id,
      v_item.id,
      v_item.name,
      v_item.price,
      v_qty,
      case
        when jsonb_typeof(v_line->'selected_options')='array' then v_line->'selected_options'
        else '[]'::jsonb
      end,
      nullif(left(trim(coalesce(v_line->>'note','')),500),'')
    );
  end loop;

  if v_campaign_id is not null then
    insert into public.food_order_campaigns(
      order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount
    ) values (
      v_order_id,v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    );

    update public.food_campaigns
    set usage_count=usage_count+1
    where id=v_campaign_id;

    insert into public.food_order_events(order_id,event_type,note,actor_id)
    values (
      v_order_id,'campaign_applied',
      left(v_campaign_name || ' · ลด ฿' || trim(to_char(v_campaign_discount+v_delivery_discount,'FM999999990.00')),1000),
      auth.uid()
    );
  end if;

  insert into public.food_order_events(order_id,event_type,to_status,note,actor_id)
  values (v_order_id,'created','pending_acceptance','สร้างคำสั่งซื้อ',auth.uid());

  return v_order_id;
end;
$$;

revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;

create or replace function internal.food_campaign_release_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign_id uuid;
begin
  if new.status='cancelled' and old.status is distinct from 'cancelled' then
    update public.food_order_campaigns
    set released_at=now()
    where order_id=new.id
      and released_at is null
    returning campaign_id into v_campaign_id;

    if v_campaign_id is not null then
      update public.food_campaigns
      set usage_count=greatest(usage_count-1,0)
      where id=v_campaign_id;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_campaign_release_on_cancel() from public, anon, authenticated;

drop trigger if exists trg_food_campaign_release_on_cancel on public.food_orders;
create trigger trg_food_campaign_release_on_cancel
after update of status on public.food_orders
for each row execute function internal.food_campaign_release_on_cancel();
