-- Rollback for 20261104100000_zoky_merchant_busy_mode.sql.
-- Restores the ZOKY-FULFILL-001 pickup slots (pinned migration d8370d06) and
-- removes busy mode.

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
  v_day := (p_now at time zone 'Asia/Bangkok')::date;
  v_t := to_timestamp(ceil(extract(epoch from p_now + v_prep) / 900) * 900);
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

drop function if exists public.food_store_set_busy(uuid, integer, integer);
drop trigger if exists food_stores_busy_guard on public.food_stores;
drop function if exists internal.food_stores_busy_guard();
drop function if exists internal.food_store_busy_extra(integer, timestamptz, timestamptz);
alter table public.food_stores drop constraint if exists food_stores_busy_extra_minutes_check;
alter table public.food_stores drop column if exists busy_until, drop column if exists busy_extra_minutes;
