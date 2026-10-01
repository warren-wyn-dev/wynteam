-- WYNOS Merchant core completion hardening v1
-- Add indexes for new foreign keys and remove overlapping staff SELECT policies.

create index if not exists food_orders_refund_updated_by_idx
  on public.food_orders(refund_updated_by)
  where refund_updated_by is not null;

create index if not exists merchant_activity_actor_idx
  on public.merchant_activity_log(actor_id)
  where actor_id is not null;

drop policy if exists "Food staff managed by merchant" on public.food_staff;
drop policy if exists "Food staff inserted by merchant" on public.food_staff;
drop policy if exists "Food staff updated by merchant" on public.food_staff;
drop policy if exists "Food staff deleted by merchant" on public.food_staff;

create policy "Food staff inserted by merchant"
on public.food_staff
for insert to authenticated
with check (public.merchant_has_store_role(store_id, array['owner','admin']));

create policy "Food staff updated by merchant"
on public.food_staff
for update to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin']))
with check (public.merchant_has_store_role(store_id, array['owner','admin']));

create policy "Food staff deleted by merchant"
on public.food_staff
for delete to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin']));
