-- REVIEWED-DESIGN CANDIDATE, NOT APPLIED. Do not run against shared production.
-- Requires disposable Postgres RLS/concurrency and Stripe regression tests first.
-- Zoky LINE only sends alerts for stores with an explicitly linked, active user.
create table public.zoky_line_link_requests (
  nonce_sha256 text primary key check (nonce_sha256 ~ '^[0-9a-f]{64}$'),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  check (expires_at > created_at and expires_at <= created_at + interval '11 minutes')
);
create index zoky_line_link_requests_expiry on public.zoky_line_link_requests(expires_at) where consumed_at is null;

create table public.zoky_line_connections (
  store_id uuid not null references public.food_stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  line_user_id text not null check (line_user_id ~ '^U[0-9a-f]{32}$'),
  linked_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (store_id,user_id)
);
create unique index zoky_line_active_user_idx on public.zoky_line_connections(store_id,line_user_id) where revoked_at is null;

create table public.zoky_line_delivery_queue (
  id bigint generated always as identity primary key,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  order_id uuid not null references public.food_orders(id) on delete cascade,
  line_user_id text not null check (line_user_id ~ '^U[0-9a-f]{32}$'),
  retry_key uuid not null default gen_random_uuid(),
  event_type text not null default 'order_ready' check (event_type='order_ready'),
  state text not null default 'pending' check (state in ('pending','claimed','delivered','failed')),
  attempts integer not null default 0 check (attempts between 0 and 10),
  next_attempt_at timestamptz not null default now(),
  claimed_at timestamptz,
  delivered_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  unique (order_id,line_user_id,event_type)
);
create index zoky_line_delivery_pending_idx on public.zoky_line_delivery_queue(state,next_attempt_at);

alter table public.zoky_line_link_requests enable row level security;
alter table public.zoky_line_connections enable row level security;
alter table public.zoky_line_delivery_queue enable row level security;
revoke all on public.zoky_line_link_requests,public.zoky_line_connections,public.zoky_line_delivery_queue from public,anon,authenticated;
grant select,insert,update,delete on public.zoky_line_link_requests,public.zoky_line_connections,public.zoky_line_delivery_queue to service_role;
grant usage, select on sequence public.zoky_line_delivery_queue_id_seq to service_role;

-- The official LINE account linking event must pass webhook HMAC validation.
-- Only service_role can invoke this function. Atomic row lock prevents replays.
create function public.zoky_line_complete_link(
  p_nonce_sha256 text, p_line_user_id text
) returns boolean language plpgsql security invoker set search_path = ''
as $$
declare pending public.zoky_line_link_requests%rowtype;
begin
  if p_nonce_sha256 is null or p_nonce_sha256 !~ '^[0-9a-f]{64}$'
     or p_line_user_id is null or p_line_user_id !~ '^U[0-9a-f]{32}$' then
    return false;
  end if;
  select * into pending from public.zoky_line_link_requests
    where nonce_sha256=p_nonce_sha256 and consumed_at is null
      and expires_at > clock_timestamp()
    for update;
  if not found then return false; end if;
  if not exists(
    select 1 from public.food_stores s where s.id=pending.store_id and (
      exists (select 1 from public.merchant_memberships mm where mm.merchant_account_id=s.merchant_account_id
        and mm.user_id=pending.user_id and mm.active
        and mm.role in ('owner','admin','manager','orders'))
      or exists(select 1 from public.food_staff fs where fs.store_id=s.id
        and fs.user_id=pending.user_id and fs.active and fs.role in ('owner','staff'))
    )
  ) then return false; end if;
  insert into public.zoky_line_connections(store_id,user_id,line_user_id,linked_at,revoked_at)
  values(pending.store_id,pending.user_id,p_line_user_id,clock_timestamp(),null)
  on conflict (store_id,user_id) do update
  set line_user_id=excluded.line_user_id, linked_at=excluded.linked_at,revoked_at=null;
  update public.zoky_line_link_requests set consumed_at=clock_timestamp()
    where nonce_sha256=p_nonce_sha256;
  return true;
end;
$$;
revoke all on function public.zoky_line_complete_link(text,text) from public,anon,authenticated;
grant execute on function public.zoky_line_complete_link(text,text) to service_role;

-- This transition is the same canonical state/payment lifecycle as
-- food_transition_order for a single pending_acceptance -> preparing/cancelled.
-- Triggers for Stripe refund jobs, notifications and audit must be regression-tested.
create function public.zoky_line_transition_order(
  p_line_user_id text, p_action text, p_order_id uuid
) returns jsonb language plpgsql security invoker set search_path = ''
as $$
declare o public.food_orders%rowtype;
  actor uuid; target text;
begin
  if p_line_user_id is null or p_line_user_id !~ '^U[0-9a-f]{32}$'
     or p_order_id is null or p_action not in ('accept','reject') then
    return jsonb_build_object('ok',false,'reason','invalid');
  end if;
  select * into o from public.food_orders where id=p_order_id for update;
  if not found or o.status <> 'pending_acceptance' then
    return jsonb_build_object('ok',false,'reason','already_handled');
  end if;
  select c.user_id into actor from public.zoky_line_connections c
    join public.food_stores s on s.id=c.store_id
    where c.store_id=o.store_id and c.line_user_id=p_line_user_id
      and c.revoked_at is null
      and (exists (select 1 from public.merchant_memberships m
        where m.merchant_account_id=s.merchant_account_id and m.user_id=c.user_id
          and m.active and m.role in ('owner','admin','manager','orders'))
        or exists (select 1 from public.food_staff fs where fs.store_id=o.store_id
          and fs.user_id=c.user_id and fs.active and fs.role in ('owner','staff')))
    order by c.linked_at asc limit 1;
  if actor is null then return jsonb_build_object('ok',false,'reason','forbidden'); end if;
  -- Avoid accepting/rejecting unconfirmed bank-transfer or unpaid Stripe orders.
  if o.payment_status <> 'paid' and o.payment_method <> 'cod' then
    return jsonb_build_object('ok',false,'reason','payment_not_ready');
  end if;
  target := case when p_action='accept' then 'preparing' else 'cancelled' end;
  update public.food_orders
    set status=target,
        accepted_at=case when target='preparing' then coalesce(accepted_at,now()) else accepted_at end,
        cancelled_at=case when target='cancelled' then now() else cancelled_at end,
        refund_status=case when target='cancelled' and o.payment_status='paid' then 'pending' else refund_status end,
        refund_requested_at=case when target='cancelled' and o.payment_status='paid'
           then coalesce(refund_requested_at,now()) else refund_requested_at end
    where id=o.id;
  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
    values(o.id,'status_changed',o.status,target,'LINE Merchant OA',actor);
  return jsonb_build_object('ok',true,'status',target);
end;
$$;
revoke all on function public.zoky_line_transition_order(text,text,uuid) from public,anon,authenticated;
grant execute on function public.zoky_line_transition_order(text,text,uuid) to service_role;

-- Queue only for stores that have explicitly opted in by linking LINE.
-- No automatic outbound LINE call is made inside an order transaction.
create function public.zoky_line_queue_order() returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.status='pending_acceptance'
    and (new.payment_status='paid' or new.payment_method='cod') then
    insert into public.zoky_line_delivery_queue(store_id,order_id,line_user_id)
      select new.store_id,new.id,c.line_user_id
      from public.zoky_line_connections c join public.food_stores s on s.id=c.store_id
      where c.store_id=new.store_id and c.revoked_at is null and
        (exists(select 1 from public.merchant_memberships m
           where m.merchant_account_id=s.merchant_account_id and m.user_id=c.user_id
              and m.active and m.role in ('owner','admin','manager','orders'))
         or exists(select 1 from public.food_staff f
           where f.store_id=s.id and f.user_id=c.user_id and f.active and f.role in ('owner','staff')))
      on conflict (order_id,line_user_id,event_type) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.zoky_line_queue_order() from public,anon,authenticated;
create trigger zoky_line_order_ready_trigger
  after insert or update of status,payment_status,payment_method
  on public.food_orders for each row execute function public.zoky_line_queue_order();

-- Revoke functions so browser auth cannot claim/confirm queue messages.
create function public.zoky_line_claim_deliveries(p_limit integer default 20)
returns table(id bigint,line_user_id text,order_id uuid,order_number text,store_name text,total numeric,retry_key uuid)
language sql security invoker set search_path = ''
as $$
  with eligible as (
    select q.id from public.zoky_line_delivery_queue q
      join public.food_orders o on o.id=q.order_id
      join public.zoky_line_connections c on c.store_id=q.store_id and c.line_user_id=q.line_user_id
      join public.food_stores s on s.id=q.store_id
      where q.state in ('pending','claimed') and q.attempts < 5
        and q.next_attempt_at <= now()
        and (q.state='pending' or q.claimed_at < now()-interval '2 minutes')
        and o.status='pending_acceptance'
        and (o.payment_status='paid' or o.payment_method='cod')
        and c.revoked_at is null
        and (exists(select 1 from public.merchant_memberships m where m.merchant_account_id=s.merchant_account_id
          and m.user_id=c.user_id and m.active and m.role in ('owner','admin','manager','orders'))
         or exists(select 1 from public.food_staff f where f.store_id=s.id and f.user_id=c.user_id
          and f.active and f.role in ('owner','staff')))
      order by q.id limit least(greatest(coalesce(p_limit,20),1),25)
      for update of q skip locked
  ), claimed as (
    update public.zoky_line_delivery_queue q
      set state='claimed',claimed_at=now(),attempts=q.attempts+1,
          next_attempt_at=now()+interval '2 minutes'
      from eligible e where q.id=e.id returning q.*
  )
  select c.id,c.line_user_id,c.order_id,o.order_number::text,s.name::text,o.total,c.retry_key
    from claimed c join public.food_orders o on o.id=c.order_id
      join public.food_stores s on s.id=c.store_id;
$$;
revoke all on function public.zoky_line_claim_deliveries(integer) from public,anon,authenticated;
grant execute on function public.zoky_line_claim_deliveries(integer) to service_role;

-- Staging candidate only; do not apply to shared production.
