-- WYNOS Food: compatible order operations and development-only proposal records.
-- Apply after 20261013045900_food_checkout_integrity.sql and existing Merchant
-- core / structured availability migrations. No cron, provider calls or payouts.
-- All new operational capabilities start OFF. Acceptance deadlines are metadata
-- only; no timeout duration is assumed and paid orders are never auto-cancelled.
begin;

insert into public.food_development_features(name, enabled, developer_only)
values ('busy_mode', false, true), ('order_modifications', false, true),
       ('acceptance_timeout_reporting', false, true), ('auto_accept', false, true),
       ('customer_pickup', false, true), ('wynos_rider', false, true)
on conflict (name) do nothing;

create or replace function public.food_order_operations_features(p_store_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  return jsonb_build_object(
    'order_modifications', internal.food_development_feature_enabled('order_modifications'),
    'busy_mode', internal.food_development_feature_enabled('busy_mode'),
    'acceptance_timeout_reporting', internal.food_development_feature_enabled('acceptance_timeout_reporting'),
    'can_manage_orders', p_store_id is not null and public.merchant_has_store_role(p_store_id,array['owner','admin','manager','orders']) is true,
    'can_manage_store', p_store_id is not null and public.merchant_has_store_role(p_store_id,array['owner','admin','manager']) is true,
    'auto_accept', false, 'customer_pickup', false, 'wynos_rider', false,
    'modification_execution', false
  );
end;
$$;
revoke all on function public.food_order_operations_features(uuid) from public, anon;
grant execute on function public.food_order_operations_features(uuid) to authenticated;

alter table public.food_stores
  add column if not exists auto_accept_enabled boolean not null default false,
  add column if not exists acceptance_timeout_minutes integer,
  add column if not exists busy_mode text not null default 'off';

alter table public.food_stores
  drop constraint if exists food_stores_acceptance_timeout_positive,
  add constraint food_stores_acceptance_timeout_positive
    check (acceptance_timeout_minutes is null or acceptance_timeout_minutes > 0),
  drop constraint if exists food_stores_busy_mode_valid,
  add constraint food_stores_busy_mode_valid check (busy_mode in ('off','prep','pause'));

comment on column public.food_stores.auto_accept_enabled is
  'Reserved configuration only. No auto-accept executor exists; keep false.';
comment on column public.food_stores.acceptance_timeout_minutes is
  'Optional merchant acceptance deadline after payment verification. NULL means unconfigured. No automatic cancellation executor.';

alter table public.food_orders
  add column if not exists fulfillment_mode text not null default 'merchant_delivery',
  add column if not exists acceptance_due_at timestamptz,
  add column if not exists cancellation_reason text;

alter table public.food_orders
  drop constraint if exists food_orders_fulfillment_mode_valid,
  add constraint food_orders_fulfillment_mode_valid
    check (fulfillment_mode in ('merchant_delivery','customer_pickup','wynos_rider')),
  drop constraint if exists food_orders_cancellation_reason_length,
  add constraint food_orders_cancellation_reason_length
    check (cancellation_reason is null or char_length(cancellation_reason) between 1 and 1000);

create index if not exists food_orders_acceptance_due_idx
  on public.food_orders(store_id, acceptance_due_at)
  where status = 'pending_acceptance' and acceptance_due_at is not null;

-- Do not guess a deadline or backfill existing orders. A newly verified payment
-- starts an explicitly configured acceptance deadline; no job acts on it.
create or replace function internal.food_order_operations_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_minutes integer;
begin
  if new.fulfillment_mode is distinct from 'merchant_delivery' then
    raise exception 'fulfillment mode is not implemented';
  end if;
  if tg_op = 'UPDATE' and new.fulfillment_mode is distinct from old.fulfillment_mode then
    raise exception 'fulfillment snapshot is immutable';
  end if;
  if internal.food_development_feature_enabled('acceptance_timeout_reporting') is true
     and new.status = 'pending_acceptance' and new.payment_status = 'paid'
     and new.acceptance_due_at is null then
    if tg_op = 'INSERT' then
      select acceptance_timeout_minutes into v_minutes
      from public.food_stores where id = new.store_id;
    elsif old.payment_status is distinct from 'paid' then
      select acceptance_timeout_minutes into v_minutes
      from public.food_stores where id = new.store_id;
    end if;
    if v_minutes is not null then
      new.acceptance_due_at := clock_timestamp() + make_interval(mins => v_minutes);
    end if;
  end if;
  return new;
end;
$$;
revoke all on function internal.food_order_operations_snapshot() from public, anon, authenticated;
drop trigger if exists food_orders_operations_snapshot on public.food_orders;
create trigger food_orders_operations_snapshot
before insert or update of payment_status, fulfillment_mode on public.food_orders
for each row execute function internal.food_order_operations_snapshot();

-- A single state guard covers Merchant RPCs, customer cancellation, worker
-- cancellation and privileged updates. Existing payment/refund states remain
-- separate. Delivery proof is still validated by food_complete_delivery.
create or replace function internal.food_order_guard_state_transition()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.status is null then raise exception 'invalid order transition'; end if;
  if new.status is not distinct from old.status then return new; end if;
  if not coalesce(case old.status
    when 'pending_acceptance' then new.status in ('preparing','cancelled')
    when 'preparing' then new.status in ('ready_for_delivery','cancelled')
    when 'ready_for_delivery' then new.status in ('out_for_delivery','cancelled')
    when 'out_for_delivery' then new.status in ('delivered','cancelled')
    else false
  end, false) then raise exception 'invalid order transition'; end if;
  if old.status = 'pending_acceptance' and new.status = 'preparing'
     and new.payment_status is distinct from 'paid' then
    raise exception 'payment must be verified first';
  end if;
  if new.status = 'cancelled' and (old.payment_status = 'paid' or old.paid_at is not null)
     and current_setting('wynos.food_auto_cancel', true) = 'on' then
    raise exception 'paid order requires manual cancellation and refund review';
  end if;
  if new.status = 'cancelled' and new.payment_status = 'paid' then
    -- This records the existing manual refund obligation only. It never claims
    -- that funds were returned and never initiates a provider transaction.
    new.refund_status := 'pending';
    new.refund_requested_at := coalesce(new.refund_requested_at, clock_timestamp());
  end if;
  return new;
end;
$$;
revoke all on function internal.food_order_guard_state_transition() from public, anon, authenticated;
drop trigger if exists food_orders_guard_state_transition on public.food_orders;
create trigger food_orders_guard_state_transition before update of status on public.food_orders
for each row execute function internal.food_order_guard_state_transition();

-- Preserve the existing RPC signature, roles, status vocabulary and optional
-- cancellation note for older clients. New Merchant clients must use the strict
-- food_reject_order RPC below. A mandatory-note gate for all legacy callers
-- needs a client rollout audit before release.
create or replace function public.food_transition_order(
  p_order_id uuid, p_status text, p_eta_minutes integer default null, p_note text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_order public.food_orders%rowtype;
  v_roles text[];
  v_note text := nullif(btrim(coalesce(p_note, ''), E' \t\r\n'), '');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found then raise exception 'order not found'; end if;
  v_roles := case when p_status = 'out_for_delivery'
    then array['owner','admin','manager','orders','delivery']
    else array['owner','admin','manager','orders'] end;
  if public.merchant_has_store_role(v_order.store_id, v_roles) is not true then
    raise exception 'order management role required';
  end if;
  if p_status is null or not coalesce(case v_order.status
    when 'pending_acceptance' then p_status in ('preparing','cancelled')
    when 'preparing' then p_status in ('ready_for_delivery','cancelled')
    when 'ready_for_delivery' then p_status in ('out_for_delivery','cancelled')
    when 'out_for_delivery' then p_status = 'cancelled'
    else false end, false) then raise exception 'invalid order transition'; end if;
  if p_eta_minutes is not null and (p_eta_minutes < 1 or p_eta_minutes > 240) then
    raise exception 'invalid ETA';
  end if;
  if char_length(v_note) > 1000 then raise exception 'order note too long'; end if;
  if v_order.status = 'pending_acceptance' and p_status = 'preparing'
     and v_order.payment_status is distinct from 'paid' then
    raise exception 'payment must be verified first';
  end if;
  update public.food_orders set
    status = p_status,
    eta_minutes = coalesce(p_eta_minutes, eta_minutes),
    accepted_at = case when p_status = 'preparing' then coalesce(accepted_at, now()) else accepted_at end,
    ready_at = case when p_status = 'ready_for_delivery' then now() else ready_at end,
    out_for_delivery_at = case when p_status = 'out_for_delivery' then now() else out_for_delivery_at end,
    cancelled_at = case when p_status = 'cancelled' then now() else cancelled_at end,
    cancellation_reason = case when p_status = 'cancelled' then v_note else cancellation_reason end,
    refund_status = case when p_status = 'cancelled' and payment_status = 'paid' then 'pending' else refund_status end,
    refund_requested_at = case when p_status = 'cancelled' and payment_status = 'paid'
      then coalesce(refund_requested_at, now()) else refund_requested_at end
  where id = p_order_id;
  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (p_order_id,'status_changed',v_order.status,p_status,v_note,auth.uid());
end;
$$;
revoke all on function public.food_transition_order(uuid,text,integer,text) from public, anon;
grant execute on function public.food_transition_order(uuid,text,integer,text) to authenticated;

create or replace function public.food_reject_order(p_order_id uuid, p_reason text)
returns void language plpgsql set search_path = '' as $$
declare v_reason text := nullif(btrim(coalesce(p_reason, ''), E' \t\r\n'), '');
begin
  if v_reason is null or char_length(v_reason) > 1000 then
    raise exception 'rejection reason is required (maximum 1000 characters)';
  end if;
  perform public.food_transition_order(p_order_id, 'cancelled', null, v_reason);
end;
$$;
revoke all on function public.food_reject_order(uuid,text) from public, anon;
grant execute on function public.food_reject_order(uuid,text) to authenticated;

create or replace function public.food_adjust_preparation_time(p_order_id uuid, p_eta_minutes integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_order public.food_orders%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) is not true then
    raise exception 'order management role required';
  end if;
  if v_order.status is distinct from 'preparing' then raise exception 'order is not preparing'; end if;
  if p_eta_minutes is null or p_eta_minutes not between 1 and 240 then raise exception 'invalid ETA'; end if;
  update public.food_orders set eta_minutes = p_eta_minutes where id = p_order_id;
  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'preparation_time_changed',p_eta_minutes::text,auth.uid());
end;
$$;
revoke all on function public.food_adjust_preparation_time(uuid,integer) from public, anon;
grant execute on function public.food_adjust_preparation_time(uuid,integer) to authenticated;

-- Busy controls reuse the canonical preparation range / temporary closure,
-- so existing Food availability and checkout guards see the same state.
create or replace function public.merchant_set_food_busy_mode(
  p_store_id uuid, p_mode text, p_prep_min integer default null,
  p_prep_max integer default null, p_pause_until timestamptz default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_store public.food_stores%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) is not true then
    raise exception 'store management role required';
  end if;
  if internal.food_development_feature_enabled('busy_mode') is not true then
    raise exception 'busy mode is not enabled';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then raise exception 'store not found'; end if;
  if p_mode is null or p_mode not in ('off','prep','pause') then raise exception 'invalid busy mode'; end if;
  if (p_prep_min is null) <> (p_prep_max is null)
     or (p_prep_min is not null and (p_prep_min not between 1 and 240 or p_prep_max not between p_prep_min and 240)) then
    raise exception 'invalid preparation range';
  end if;
  if p_mode = 'prep' and (p_prep_min is null
     or p_prep_min < v_store.prep_time_min_minutes or p_prep_max < v_store.prep_time_max_minutes) then
    raise exception 'busy preparation time must not decrease';
  end if;
  if p_mode = 'pause' and (p_pause_until is null or p_pause_until <= clock_timestamp()) then
    raise exception 'future pause deadline required';
  end if;
  if p_mode = 'pause' and (v_store.busy_mode <> 'pause'
       or v_store.temporary_closed_reason is distinct from 'ร้านกำลังยุ่ง · พักรับออเดอร์ชั่วคราว')
     and v_store.temporary_closed_until > clock_timestamp() then
    raise exception 'store already has a temporary closure';
  end if;
  update public.food_stores set
    busy_mode = p_mode,
    prep_time_min_minutes = coalesce(p_prep_min, prep_time_min_minutes),
    prep_time_max_minutes = coalesce(p_prep_max, prep_time_max_minutes),
    temporary_closed_until = case when p_mode = 'pause' then p_pause_until
      when v_store.busy_mode = 'pause'
       and v_store.temporary_closed_reason = 'ร้านกำลังยุ่ง · พักรับออเดอร์ชั่วคราว'
       then null else temporary_closed_until end,
    temporary_closed_reason = case when p_mode = 'pause' then 'ร้านกำลังยุ่ง · พักรับออเดอร์ชั่วคราว'
      when v_store.busy_mode = 'pause'
       and v_store.temporary_closed_reason = 'ร้านกำลังยุ่ง · พักรับออเดอร์ชั่วคราว'
       then null else temporary_closed_reason end
  where id = p_store_id;
end;
$$;
revoke all on function public.merchant_set_food_busy_mode(uuid,text,integer,integer,timestamptz) from public, anon;
grant execute on function public.merchant_set_food_busy_mode(uuid,text,integer,integer,timestamptz) to authenticated;

create or replace function public.merchant_food_acceptance_overdue(p_store_id uuid)
returns table(order_id uuid, acceptance_due_at timestamptz, payment_status text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders']) is not true then
    raise exception 'order management role required';
  end if;
  if internal.food_development_feature_enabled('acceptance_timeout_reporting') is not true then
    raise exception 'acceptance timeout reporting is not enabled';
  end if;
  return query select o.id, o.acceptance_due_at, o.payment_status
  from public.food_orders o where o.store_id = p_store_id and o.status = 'pending_acceptance'
    and o.acceptance_due_at < now()
  order by o.acceptance_due_at, o.id limit 100;
end;
$$;
revoke all on function public.merchant_food_acceptance_overdue(uuid) from public, anon;
grant execute on function public.merchant_food_acceptance_overdue(uuid) to authenticated;

-- These rows record customer consent only. No mutation/repricing/charging/
-- refunding is implemented. An accepted request remains explicitly unapplied.
create table if not exists public.food_order_modifications (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id) on delete restrict,
  request_key uuid not null,
  requested_by uuid references public.profiles(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 800),
  proposed_items jsonb not null check (jsonb_typeof(proposed_items) = 'array'),
  order_snapshot jsonb not null check (jsonb_typeof(order_snapshot) = 'object'),
  status text not null default 'pending_customer'
    check (status in ('pending_customer','accepted_pending_execution','rejected','withdrawn')),
  responded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (order_id, request_key)
);
create unique index if not exists food_order_modifications_one_active_idx
  on public.food_order_modifications(order_id)
  where status in ('pending_customer','accepted_pending_execution');
alter table public.food_order_modifications enable row level security;
drop policy if exists "Food modification participants can view" on public.food_order_modifications;
create policy "Food modification participants can view" on public.food_order_modifications
for select to authenticated using (public.food_can_view_order(order_id));
revoke all on table public.food_order_modifications from public, anon, authenticated;
grant select on table public.food_order_modifications to authenticated;

create or replace function public.merchant_propose_food_order_modification(
  p_order_id uuid, p_request_key uuid, p_reason text, p_items jsonb
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_order public.food_orders%rowtype;
  v_line public.food_order_items%rowtype;
  v_request public.food_order_modifications%rowtype;
  v_input jsonb;
  v_id uuid;
  v_quantity integer;
  v_ids uuid[] := '{}';
  v_items jsonb := '[]';
  v_changed boolean := false;
  v_reason text := nullif(btrim(coalesce(p_reason, ''), E' \t\r\n'), '');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) is not true then
    raise exception 'order management role required';
  end if;
  if internal.food_development_feature_enabled('order_modifications') is not true then
    raise exception 'order modifications are not enabled';
  end if;
  if p_request_key is null or v_reason is null or char_length(v_reason) > 800 then
    raise exception 'request key and reason are required';
  end if;
  if v_order.buyer_id is null or v_order.status not in ('pending_acceptance','preparing') then
    raise exception 'order cannot be modified';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) not between 1 and 100 then
    raise exception 'invalid modification items';
  end if;
  for v_input in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_input) <> 'object'
       or coalesce(v_input->>'quantity', '') !~ '^(0|[1-9][0-9]?)$' then
      raise exception 'invalid modification item';
    end if;
    begin
      v_id := (v_input->>'order_item_id')::uuid;
      v_quantity := (v_input->>'quantity')::integer;
    exception when invalid_text_representation then
      raise exception 'invalid modification item';
    end;
    if v_id is null or v_id = any(v_ids) then raise exception 'invalid modification item'; end if;
    v_ids := array_append(v_ids, v_id);
    select * into v_line from public.food_order_items where id = v_id and order_id = p_order_id;
    if not found or v_quantity > v_line.quantity then raise exception 'only quantity reductions are supported'; end if;
    v_changed := v_changed or v_quantity < v_line.quantity;
    -- Names/options/prices are captured from the existing order, never supplied
    -- by the Merchant client. Price effects are deliberately not computed here.
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'order_item_id', v_id, 'item_name', v_line.item_name,
      'original_quantity', v_line.quantity, 'quantity', v_quantity,
      'unit_price', v_line.unit_price, 'selected_options', v_line.selected_options));
  end loop;
  if not v_changed then raise exception 'modification must change a quantity'; end if;
  select coalesce(jsonb_agg(value order by value->>'order_item_id'), '[]') into v_items
  from jsonb_array_elements(v_items);
  select * into v_request from public.food_order_modifications
  where order_id = p_order_id and request_key = p_request_key;
  if found then
    if v_request.requested_by is distinct from auth.uid()
       or v_request.reason is distinct from v_reason or v_request.proposed_items is distinct from v_items then
      raise exception 'modification request key was reused with different input';
    end if;
    return v_request.id;
  end if;
  if exists (select 1 from public.food_order_modifications where order_id = p_order_id
             and status in ('pending_customer','accepted_pending_execution')) then
    raise exception 'order already has an active modification';
  end if;
  insert into public.food_order_modifications(order_id, request_key, requested_by, reason, proposed_items, order_snapshot)
  values (p_order_id,p_request_key,auth.uid(),v_reason,v_items,jsonb_build_object(
    'status',v_order.status,'payment_status',v_order.payment_status,'total',v_order.total,
    'applied',false,'pricing_supported',false)) returning id into v_id;
  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'modification_proposed',v_id::text,auth.uid());
  return v_id;
end;
$$;
revoke all on function public.merchant_propose_food_order_modification(uuid,uuid,text,jsonb) from public, anon;
grant execute on function public.merchant_propose_food_order_modification(uuid,uuid,text,jsonb) to authenticated;

create or replace function public.food_respond_order_modification(p_modification_id uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_request public.food_order_modifications%rowtype;
  v_order public.food_orders%rowtype;
  v_order_id uuid;
  v_status text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  -- Always lock parent order before request, matching the proposal lock order.
  select order_id into v_order_id from public.food_order_modifications where id = p_modification_id;
  select * into v_order from public.food_orders where id = v_order_id for update;
  if not found or v_order.buyer_id is distinct from auth.uid() then raise exception 'modification not found'; end if;
  if internal.food_development_feature_enabled('order_modifications') is not true then
    raise exception 'order modifications are not enabled';
  end if;
  if p_accept is null then raise exception 'customer decision is required'; end if;
  select * into v_request from public.food_order_modifications where id = p_modification_id for update;
  v_status := case when p_accept then 'accepted_pending_execution' else 'rejected' end;
  if v_request.status = v_status and v_request.responded_by = auth.uid() then return v_status; end if;
  if v_request.status <> 'pending_customer' then raise exception 'modification already answered'; end if;
  if p_accept and (v_order.status not in ('pending_acceptance','preparing')
    or v_order.status is distinct from v_request.order_snapshot->>'status'
    or v_order.payment_status is distinct from v_request.order_snapshot->>'payment_status'
    or v_order.total is distinct from (v_request.order_snapshot->>'total')::numeric
    or exists (select 1 from jsonb_array_elements(v_request.proposed_items) proposed
      left join public.food_order_items item on item.id = (proposed->>'order_item_id')::uuid
      where item.order_id is distinct from v_order.id
        or item.quantity is distinct from (proposed->>'original_quantity')::integer
        or item.unit_price is distinct from (proposed->>'unit_price')::numeric
        or item.selected_options is distinct from proposed->'selected_options')) then
    raise exception 'order changed; a new proposal is required';
  end if;
  update public.food_order_modifications set status = v_status, responded_by = auth.uid(), responded_at = now()
  where id = p_modification_id;
  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (v_order.id,case when p_accept then 'modification_accepted_pending_execution' else 'modification_rejected' end,
    p_modification_id::text,auth.uid());
  return v_status;
end;
$$;
revoke all on function public.food_respond_order_modification(uuid,boolean) from public, anon;
grant execute on function public.food_respond_order_modification(uuid,boolean) to authenticated;

-- Realtime uses the existing audited food_order_events publication, so these
-- events work with current reconnect/reload flows without a second push path.
-- Replacement menus, applying consent, promotion repricing, extra charges and
-- partial refunds remain unsupported until provider approval/reconciliation is
-- implemented and tested. No feature flag can make this migration perform them.
commit;
