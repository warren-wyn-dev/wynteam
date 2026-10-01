-- WYNOS Food orders only v1.
-- New Merchant orders must originate from the customer-facing WYNOS Food flow.
-- Historical manual/social rows remain readable; only new inserts are restricted.

revoke execute on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text)
  from public, anon, authenticated;

-- Client roles should never insert Food orders directly. The customer RPC is
-- SECURITY DEFINER and remains the single production creation path.
revoke insert on table public.food_orders from anon, authenticated;

create or replace function internal.food_order_wynos_food_only_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.source <> 'app' then
    raise exception 'new orders must be created through WYNOS Food';
  end if;

  if new.buyer_id is null
     or new.created_by is null
     or new.buyer_id <> new.created_by then
    raise exception 'WYNOS Food customer identity is required';
  end if;

  return new;
end;
$$;

revoke all on function internal.food_order_wynos_food_only_guard()
  from public, anon, authenticated;

drop trigger if exists trg_food_orders_wynos_food_only on public.food_orders;
create trigger trg_food_orders_wynos_food_only
before insert on public.food_orders
for each row
execute function internal.food_order_wynos_food_only_guard();
