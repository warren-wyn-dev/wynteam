-- WYNOS Food: order-status push for customers and share-link results for
-- stores (Founder 2026-10-05: "ทำทุกข้อเลย อนุมัติ ทุกอย่าง").
--
-- 1. Order status notifications (new trigger; food_order_notify untouched):
--    * customer: store accepted (with ETA), out for delivery, cancelled by
--      the store. "Delivered" already comes from food_complete_delivery.
--    * store: the customer cancelled.
--    Texts start with "ออเดอร์ #WF..." / "WYNOS Merchant · " so
--    send-push-notification routes them to Wynos Food / WYNOS Merchant.
-- 2. Share-link results:
--    * food_share_link_opens: per-store daily count of short-link opens,
--      recorded by food_record_share_open(code) (anon; published stores only).
--    * food_orders.from_share_link: set by the buyer within 15 minutes of
--      creating the order (food_mark_order_from_share), only for their own order.
--    * food_share_stats(store, days): opens, orders and sales from share
--      links for people with Merchant access to that store.
-- Additive only.
-- ROLLBACK:
--   drop trigger food_orders_status_notify on public.food_orders;
--   drop function internal.food_order_status_notify();
--   drop function public.food_record_share_open(text);
--   drop function public.food_mark_order_from_share(uuid);
--   drop function public.food_share_stats(uuid, integer);
--   drop table public.food_share_link_opens;
--   alter table public.food_orders drop column from_share_link;

-- 1. Order status notifications -------------------------------------------

create or replace function internal.food_order_status_notify()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  v_actor uuid := auth.uid();
  v_account_id uuid;
  v_reason text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'preparing' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (
      new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร'
        || case when new.eta_minutes is not null then ' (ประมาณ ' || new.eta_minutes || ' นาที)' else '' end
    );
  elsif new.status = 'out_for_delivery' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system', 'ออเดอร์ #' || new.order_number || ' กำลังจัดส่ง · เตรียมรับอาหารได้เลย');
  elsif new.status = 'cancelled' then
    if new.buyer_id is not null and v_actor is not distinct from new.buyer_id then
      -- The customer cancelled: tell the store.
      v_reason := 'WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #' || new.order_number;
      select s.merchant_account_id into v_account_id from public.food_stores s where s.id = new.store_id;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'order', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id = v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (
        new.buyer_id, null, 'system',
        'ออเดอร์ #' || new.order_number || ' ถูกร้านยกเลิก'
          || case when new.payment_status = 'paid' then ' · ร้านจะคืนเงินให้คุณ' else '' end
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function internal.food_order_status_notify() from public, anon, authenticated;

drop trigger if exists food_orders_status_notify on public.food_orders;
create trigger food_orders_status_notify
after update of status on public.food_orders
for each row execute function internal.food_order_status_notify();

-- 2. Share-link results ----------------------------------------------------

create table if not exists public.food_share_link_opens (
  store_id uuid not null references public.food_stores(id) on delete cascade,
  day date not null,
  opens integer not null default 0 check (opens >= 0),
  primary key (store_id, day)
);

alter table public.food_share_link_opens enable row level security;
revoke all on table public.food_share_link_opens from public, anon, authenticated;

alter table public.food_orders add column if not exists from_share_link boolean not null default false;

create index if not exists food_orders_store_share_created_idx
  on public.food_orders (store_id, created_at)
  where from_share_link;

-- Called by the /s/<code> route for people (not link-preview crawlers).
create or replace function public.food_record_share_open(p_code text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_store uuid := public.food_store_id_by_share_code(p_code);
  v_day date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if v_store is null then
    return;
  end if;
  insert into public.food_share_link_opens(store_id, day, opens)
  values (v_store, v_day, 1)
  on conflict (store_id, day) do update set opens = public.food_share_link_opens.opens + 1;
end;
$$;

revoke all on function public.food_record_share_open(text) from public;
grant execute on function public.food_record_share_open(text) to anon, authenticated;

-- The buyer marks their own just-created order as coming from a share link.
create or replace function public.food_mark_order_from_share(p_order_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.food_orders
  set from_share_link = true
  where id = p_order_id
    and buyer_id = auth.uid()
    and auth.uid() is not null
    and created_at > now() - interval '15 minutes'
    and not from_share_link
$$;

revoke all on function public.food_mark_order_from_share(uuid) from public, anon;
grant execute on function public.food_mark_order_from_share(uuid) to authenticated;

create or replace function public.food_share_stats(p_store_id uuid, p_days integer default 7)
returns table (opens bigint, orders bigint, sales numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 7), 1), 90);
  v_from date := (now() at time zone 'Asia/Bangkok')::date - (v_days - 1);
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;
  return query
  select
    coalesce((select sum(o.opens) from public.food_share_link_opens o
              where o.store_id = p_store_id and o.day >= v_from), 0)::bigint,
    (select count(*) from public.food_orders f
     where f.store_id = p_store_id and f.from_share_link and f.status <> 'cancelled'
       and (f.created_at at time zone 'Asia/Bangkok')::date >= v_from)::bigint,
    coalesce((select sum(f.total) from public.food_orders f
              where f.store_id = p_store_id and f.from_share_link and f.status <> 'cancelled'
                and (f.created_at at time zone 'Asia/Bangkok')::date >= v_from), 0)::numeric;
end;
$$;

revoke all on function public.food_share_stats(uuid, integer) from public, anon;
grant execute on function public.food_share_stats(uuid, integer) to authenticated;
