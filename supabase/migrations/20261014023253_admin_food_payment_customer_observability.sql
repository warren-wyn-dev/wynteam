-- Read-only Food payment observability and redacted customer order history.
-- Uses WYN-219 food:view / food:edit without introducing new financial authority.
-- No Stripe API calls, refunds, transfers, GP rates or operational data changes.
-- Dispute and partial-refund event receipt is NOT a reconciled gateway balance.
-- Rollback: supabase/rollbacks/20261014023253_admin_food_payment_customer_observability_rollback.sql

create index if not exists food_orders_admin_created_id_idx
  on public.food_orders(created_at desc, id desc);
create index if not exists food_stripe_webhook_events_order_received_idx
  on public.food_stripe_webhook_events(order_id, received_at desc) where order_id is not null;

-- Internal projection: no customer contacts, addresses, raw gateway identifiers,
-- provider errors, notes or webhook payloads are selected at all.
create or replace function internal.admin_food_payment_rows(
  p_from timestamptz, p_to timestamptz, p_query text, p_provider text
)
returns table(
  order_id uuid, order_number text, store_id uuid, store_name text,
  order_status text, payment_status text, refund_status text, provider text,
  expected_satang bigint, ledger_amount_satang bigint, ledger_status text,
  ledger_currency text, created_at timestamptz, updated_at timestamptz,
  refund_requested_at timestamptz, refunded_at timestamptz,
  latest_webhook_at timestamptz, latest_refund_event text,
  latest_dispute_event text, flags text[]
)
language sql stable security invoker set search_path = '' as $$
  select o.id, o.order_number::text, o.store_id, s.name,
    o.status, o.payment_status, o.refund_status,
    case when o.payment_provider = 'stripe' or o.stripe_checkout_session_id is not null
                   or p.order_id is not null then 'stripe' else 'manual' end,
    round(o.total * 100)::bigint, p.amount_satang, p.status, p.currency,
    o.created_at, o.updated_at, o.refund_requested_at, o.refunded_at,
    ev.latest_webhook_at, re.event_type, de.event_type,
    array_remove(array[
      case when (o.payment_provider = 'stripe' or o.stripe_checkout_session_id is not null)
                     and p.order_id is null then 'ledger_missing' end,
      case when p.order_id is not null and (p.amount_satang <> round(o.total * 100)::bigint
                  or p.currency <> 'thb' or p.store_id <> o.store_id) then 'amount_mismatch' end,
      case when p.order_id is not null and (
        (o.payment_status in ('paid','refunded') and p.status <> o.payment_status)
        or (p.status in ('paid','refunded') and o.payment_status <> p.status)
      ) then 'state_mismatch' end,
      case when o.refund_status = 'failed' then 'refund_failed' end,
      case when o.refund_status = 'pending'
        and coalesce(o.refund_requested_at, o.updated_at) < now() - interval '24 hours'
        then 'refund_waiting_24h' end,
      case when o.payment_status in ('pending','submitted','issue')
        and o.status not in ('cancelled','delivered') and o.created_at < now() - interval '24 hours'
        then 'payment_waiting_24h' end,
      case when o.status = 'cancelled' and o.payment_status = 'paid' and o.refund_status = 'none'
        then 'cancelled_paid' end,
      case when re.event_type = 'refund.failed' and o.refund_status <> 'refunded'
        then 'refund_event_review' end,
      case when de.event_type is not null then 'dispute_event_review' end
    ]::text[], null)
  from public.food_orders o
  join public.food_stores s on s.id = o.store_id
  left join public.food_stripe_payments p on p.order_id = o.id
  left join lateral (
    select max(e.received_at) as latest_webhook_at
    from public.food_stripe_webhook_events e where e.order_id = o.id
  ) ev on true
  left join lateral (
    select e.event_type from public.food_stripe_webhook_events e
    where e.order_id = o.id and (e.event_type like 'refund.%' or e.event_type = 'charge.refunded')
    order by e.received_at desc, e.event_id desc limit 1
  ) re on true
  left join lateral (
    select e.event_type from public.food_stripe_webhook_events e
    where e.order_id = o.id and e.event_type like 'charge.dispute.%'
    order by e.received_at desc, e.event_id desc limit 1
  ) de on true
  where o.created_at >= p_from and o.created_at < p_to
    and (p_query is null or strpos(lower(o.order_number::text), lower(p_query)) > 0
                        or strpos(lower(s.name), lower(p_query)) > 0)
    and (p_provider is null
      or (p_provider = 'stripe' and (o.payment_provider = 'stripe'
            or o.stripe_checkout_session_id is not null or p.order_id is not null))
      or (p_provider = 'manual' and o.payment_provider is distinct from 'stripe'
            and o.stripe_checkout_session_id is null and p.order_id is null));
$$;
revoke all on function internal.admin_food_payment_rows(timestamptz,timestamptz,text,text)
  from public, anon, authenticated;

create or replace function public.admin_food_payment_monitor(
  p_query text default null, p_filter text default 'all', p_provider text default null,
  p_from date default null, p_to date default null,
  p_limit integer default 25, p_offset integer default 0
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_from date := coalesce(p_from, (now() at time zone 'Asia/Bangkok')::date - 29);
  v_to date := coalesce(p_to, (now() at time zone 'Asia/Bangkok')::date);
  v_query text := nullif(btrim(p_query), '');
  v_result jsonb;
begin
  if auth.uid() is null or not internal.has_admin_permission('food', 'view') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if v_to < v_from or v_to - v_from > 365 then
    raise exception 'Invalid date range' using errcode = '22023';
  end if;
  if p_filter is null or p_filter not in ('all','review','refund','paid','dispute')
    or (p_provider is not null and p_provider not in ('stripe','manual'))
    or char_length(v_query) > 100 or p_limit is null or p_limit not between 1 and 100
    or p_offset is null or p_offset not between 0 and 100000 then
    raise exception 'Invalid monitor parameters' using errcode = '22023';
  end if;
  with filtered as materialized (
    select r.* from internal.admin_food_payment_rows(
      v_from::timestamp at time zone 'Asia/Bangkok',
      (v_to + 1)::timestamp at time zone 'Asia/Bangkok', v_query, p_provider
    ) r
    where p_filter = 'all'
      or (p_filter = 'review' and cardinality(r.flags) > 0)
      or (p_filter = 'refund' and r.refund_status <> 'none')
      or (p_filter = 'paid' and r.payment_status = 'paid')
      or (p_filter = 'dispute' and r.latest_dispute_event is not null)
  ), page as (
    select * from filtered order by created_at desc, order_id desc limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'rows', coalesce((select jsonb_agg(to_jsonb(page) order by created_at desc, order_id desc) from page), '[]'::jsonb),
    'total_count', (select count(*) from filtered),
    'review_count', (select count(*) from filtered where cardinality(flags) > 0),
    'offset', p_offset, 'page_size', p_limit, 'as_of', now(),
    'from', v_from, 'to', v_to, 'reconciliation', 'database_only'
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.admin_food_payment_monitor(text,text,text,date,date,integer,integer) from public, anon;
grant execute on function public.admin_food_payment_monitor(text,text,text,date,date,integer,integer) to authenticated;

-- Customer history intentionally excludes contacts and profile fields. Never
-- group anonymous/manual/deleted-buyer orders by their phone or address.
create or replace function public.admin_food_customer_history(
  p_buyer_id uuid default null, p_query text default null,
  p_limit integer default 25, p_offset integer default 0
)
returns jsonb language plpgsql stable security definer
-- Compilation dominated measured short global searches. Keep this local to
-- the read function; PostgreSQL restores the caller's JIT setting on return.
set search_path = '' set jit = off as $$
declare
  v_query text := nullif(btrim(p_query), '');
  v_result jsonb;
begin
  -- Customer history keeps the existing admin_food_orders food:edit boundary.
  if auth.uid() is null or not internal.has_admin_permission('food', 'edit') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if char_length(v_query) > 100 or p_limit is null or p_limit not between 1 and 100
    or p_offset is null or p_offset not between 0 and 100000 then
    raise exception 'Invalid history parameters' using errcode = '22023';
  end if;
  if p_buyer_id is null then
    with customers as materialized (
      select o.buyer_id,
        'ลูกค้า ' || upper(left(md5(o.buyer_id::text), 8)) as customer_label,
        count(*) as order_count,
        count(*) filter (where o.payment_status = 'paid') as paid_order_count,
        count(*) filter (where o.payment_status = 'refunded' or o.refund_status = 'refunded') as refunded_order_count,
        count(*) filter (where o.status = 'cancelled') as cancelled_order_count,
        sum(o.total) filter (where o.payment_status = 'paid') as paid_order_value,
        max(o.created_at) as last_order_at
      from public.food_orders o
      where o.buyer_id is not null
        and (v_query is null or o.buyer_id::text = v_query or exists (
          select 1 from public.food_orders matching where matching.buyer_id = o.buyer_id
            and strpos(lower(matching.order_number::text), lower(v_query)) > 0
        ))
      group by o.buyer_id
    ), page as (
      select * from customers order by last_order_at desc, buyer_id desc limit p_limit offset p_offset
    )
    select jsonb_build_object(
      'customers', coalesce((select jsonb_agg(to_jsonb(page) order by last_order_at desc, buyer_id desc) from page), '[]'::jsonb),
      'orders', '[]'::jsonb, 'total_count', (select count(*) from customers),
      'offset', p_offset, 'page_size', p_limit, 'as_of', now()
    ) into v_result;
  else
    with orders as materialized (
      select o.id as order_id, o.order_number::text, o.store_id, s.name as store_name,
        o.status as order_status, o.payment_status, o.refund_status, o.total, o.created_at
      from public.food_orders o join public.food_stores s on s.id = o.store_id
      where o.buyer_id = p_buyer_id
        and (v_query is null or strpos(lower(o.order_number::text), lower(v_query)) > 0)
    ), page as (
      select * from orders order by created_at desc, order_id desc limit p_limit offset p_offset
    )
    select jsonb_build_object(
      'customers', '[]'::jsonb,
      'orders', coalesce((select jsonb_agg(to_jsonb(page) order by created_at desc, order_id desc) from page), '[]'::jsonb),
      'customer_label', 'ลูกค้า ' || upper(left(md5(p_buyer_id::text), 8)),
      'total_count', (select count(*) from orders),
      'offset', p_offset, 'page_size', p_limit, 'as_of', now()
    ) into v_result;
  end if;
  return v_result;
end;
$$;
revoke all on function public.admin_food_customer_history(uuid,text,integer,integer) from public, anon;
grant execute on function public.admin_food_customer_history(uuid,text,integer,integer) to authenticated;

notify pgrst, 'reload schema';
