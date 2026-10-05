-- WYNOS Merchant operations completion: scheduled orders + receipt/tax snapshots.
-- Founder requested production rollout 2026-10-05.
-- Additive and backwards-compatible: existing Food order RPC remains unchanged.

alter table public.food_stores
  add column if not exists scheduled_orders_enabled boolean not null default false,
  add column if not exists scheduled_min_notice_minutes integer not null default 30,
  add column if not exists scheduled_max_days integer not null default 7,
  add column if not exists tax_invoice_enabled boolean not null default false,
  add column if not exists tax_legal_name text,
  add column if not exists tax_id text,
  add column if not exists tax_branch text,
  add column if not exists tax_address text;

alter table public.food_stores
  drop constraint if exists food_stores_scheduled_notice_check,
  add constraint food_stores_scheduled_notice_check
    check (scheduled_min_notice_minutes between 15 and 1440),
  drop constraint if exists food_stores_scheduled_max_days_check,
  add constraint food_stores_scheduled_max_days_check
    check (scheduled_max_days between 1 and 30),
  drop constraint if exists food_stores_tax_legal_name_length,
  add constraint food_stores_tax_legal_name_length
    check (tax_legal_name is null or char_length(tax_legal_name) <= 200),
  drop constraint if exists food_stores_tax_id_length,
  add constraint food_stores_tax_id_length
    check (tax_id is null or char_length(tax_id) <= 40),
  drop constraint if exists food_stores_tax_branch_length,
  add constraint food_stores_tax_branch_length
    check (tax_branch is null or char_length(tax_branch) <= 120),
  drop constraint if exists food_stores_tax_address_length,
  add constraint food_stores_tax_address_length
    check (tax_address is null or char_length(tax_address) <= 800);

alter table public.food_orders
  add column if not exists scheduled_for timestamptz,
  add column if not exists receipt_legal_name text,
  add column if not exists receipt_tax_id text,
  add column if not exists receipt_tax_branch text,
  add column if not exists receipt_tax_address text;

alter table public.food_orders
  drop constraint if exists food_orders_scheduled_after_created_check,
  add constraint food_orders_scheduled_after_created_check
    check (scheduled_for is null or scheduled_for > created_at);

create index if not exists food_orders_store_scheduled_idx
  on public.food_orders(store_id, scheduled_for)
  where scheduled_for is not null and status not in ('delivered','cancelled');

create or replace function internal.food_order_receipt_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
begin
  select * into v_store from public.food_stores where id = new.store_id;
  if found and v_store.tax_invoice_enabled then
    new.receipt_legal_name := nullif(trim(coalesce(v_store.tax_legal_name, v_store.name)), '');
    new.receipt_tax_id := nullif(trim(coalesce(v_store.tax_id, '')), '');
    new.receipt_tax_branch := nullif(trim(coalesce(v_store.tax_branch, '')), '');
    new.receipt_tax_address := nullif(trim(coalesce(v_store.tax_address, v_store.address, '')), '');
  end if;
  return new;
end;
$$;

revoke all on function internal.food_order_receipt_snapshot() from public, anon, authenticated;

drop trigger if exists trg_food_order_receipt_snapshot on public.food_orders;
create trigger trg_food_order_receipt_snapshot
before insert on public.food_orders
for each row execute function internal.food_order_receipt_snapshot();

create or replace function public.food_create_scheduled_order(
  p_store_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb,
  p_scheduled_for timestamptz,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_order_id uuid;
  v_min timestamptz;
  v_max timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select * into v_store from public.food_stores where id = p_store_id;
  if not found then raise exception 'store not found'; end if;
  if not v_store.scheduled_orders_enabled then raise exception 'scheduled orders are not enabled'; end if;
  if p_scheduled_for is null then raise exception 'scheduled time is required'; end if;

  v_min := now() + make_interval(mins => v_store.scheduled_min_notice_minutes);
  v_max := now() + make_interval(days => v_store.scheduled_max_days);
  if p_scheduled_for < v_min then raise exception 'scheduled time is too soon'; end if;
  if p_scheduled_for > v_max then raise exception 'scheduled time is too far'; end if;

  v_order_id := public.food_create_order(
    p_store_id,
    p_recipient_name,
    p_recipient_phone,
    p_shipping_address,
    p_customer_note,
    p_items,
    p_latitude,
    p_longitude
  );

  update public.food_orders
  set scheduled_for = p_scheduled_for
  where id = v_order_id and buyer_id = auth.uid();

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (
    v_order_id,
    'scheduled',
    left('นัดรับ/จัดส่ง ' || to_char(p_scheduled_for at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI'),1000),
    auth.uid()
  );

  return v_order_id;
end;
$$;

revoke all on function public.food_create_scheduled_order(uuid,text,text,text,text,jsonb,timestamptz,double precision,double precision) from public, anon;
grant execute on function public.food_create_scheduled_order(uuid,text,text,text,text,jsonb,timestamptz,double precision,double precision) to authenticated;
