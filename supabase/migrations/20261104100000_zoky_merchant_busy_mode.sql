-- ZOKY Merchant busy mode.
-- A store under a rush adds extra preparation minutes for a limited time.
-- Customers see the longer estimate, the earliest pickup slot moves back by
-- the same amount, and the Merchant app suggests the longer time when it
-- accepts an order. It switches itself off when busy_until passes.
-- Rollback: supabase/rollbacks/20261104100000_zoky_merchant_busy_mode_rollback.sql

alter table public.food_stores
  add column if not exists busy_extra_minutes integer not null default 0,
  add column if not exists busy_until timestamptz;

alter table public.food_stores
  drop constraint if exists food_stores_busy_extra_minutes_check,
  add constraint food_stores_busy_extra_minutes_check check (busy_extra_minutes between 0 and 60);

-- Busy minutes in effect at p_at (0 when off or expired).
create or replace function internal.food_store_busy_extra(p_extra integer, p_until timestamptz, p_at timestamptz)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when p_until is not null and p_until > p_at then greatest(0, coalesce(p_extra, 0)) else 0 end;
$$;
revoke all on function internal.food_store_busy_extra(integer, timestamptz, timestamptz) from public, anon, authenticated;

-- Busy columns change only through food_store_set_busy. Service-role jobs
-- (no auth.uid()) are not affected.
create or replace function internal.food_stores_busy_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.busy_extra_minutes, new.busy_until) is distinct from (old.busy_extra_minutes, old.busy_until)
     and auth.uid() is not null
     and current_setting('wyn.food_busy_mode', true) is distinct from 'on' then
    raise exception 'use food_store_set_busy';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_stores_busy_guard() from public, anon, authenticated;
drop trigger if exists food_stores_busy_guard on public.food_stores;
create trigger food_stores_busy_guard
before update on public.food_stores
for each row execute function internal.food_stores_busy_guard();

-- Turn busy mode on (extra 5-60 minutes for 15-240 minutes) or off (extra 0).
-- Anyone who may handle the store's orders may use it.
create or replace function public.food_store_set_busy(
  p_store_id uuid, p_extra_minutes integer, p_duration_minutes integer default 60
) returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  perform 1 from public.food_stores where id = p_store_id for update;
  if not found then raise exception 'store not found'; end if;
  if p_extra_minutes is null or p_extra_minutes not between 0 and 60 then
    raise exception 'invalid_busy_minutes';
  end if;
  if p_extra_minutes > 0 then
    if p_extra_minutes < 5 then raise exception 'invalid_busy_minutes'; end if;
    if p_duration_minutes is null or p_duration_minutes not between 15 and 240 then
      raise exception 'invalid_busy_duration';
    end if;
    v_until := now() + make_interval(mins => p_duration_minutes);
  end if;
  perform set_config('wyn.food_busy_mode', 'on', true);
  update public.food_stores
  set busy_extra_minutes = p_extra_minutes, busy_until = v_until
  where id = p_store_id;
  perform set_config('wyn.food_busy_mode', '', true);
  return v_until;
end;
$$;
revoke all on function public.food_store_set_busy(uuid, integer, integer) from public, anon;
grant execute on function public.food_store_set_busy(uuid, integer, integer) to authenticated;

-- Pickup slots: same as ZOKY-FULFILL-001, but the first slot also waits for
-- the busy minutes in effect now.
create or replace function internal.food_pickup_slots(p_store_id uuid, p_now timestamptz default now())
returns setof timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_prep interval;
  v_wait interval;
  v_t timestamptz;
  v_day date;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  -- Only published stores that are open right now offer slots, the same
  -- rule the order insert guard applies.
  if not found or not v_store.pickup_enabled or not v_store.is_published
     or not internal.food_store_effectively_open(p_store_id, p_now)
     or jsonb_typeof(v_store.business_schedule->'weekly') is distinct from 'object' then
    return;
  end if;
  v_prep := make_interval(mins => v_store.pickup_prep_minutes);
  v_wait := v_prep + make_interval(mins => internal.food_store_busy_extra(v_store.busy_extra_minutes, v_store.busy_until, p_now));
  v_day := (p_now at time zone 'Asia/Bangkok')::date;
  v_t := to_timestamp(ceil(extract(epoch from p_now + v_wait) / 900) * 900);
  while (v_t at time zone 'Asia/Bangkok')::date = v_day loop
    if internal.food_store_effectively_open(p_store_id, v_t)
       and internal.food_store_effectively_open(p_store_id, v_t + v_prep - interval '1 minute') then
      return next v_t;
    end if;
    v_t := v_t + interval '15 minutes';
  end loop;
end;
$$;
revoke all on function internal.food_pickup_slots(uuid, timestamptz) from public, anon, authenticated;
