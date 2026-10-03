-- WYN-194: isolate WYNOS Food storage per store.
--
-- Before this migration the food-private and food-public write/read policies
-- used public.food_has_merchant_access(null), which is true for a member of ANY
-- store. Once a second store joins, its staff could read other stores' customer
-- payment slips and delivery photos, and overwrite or delete other stores'
-- public media, including the PromptPay QR customers pay to.
--
-- After this migration:
-- food-private
--   * customers keep their existing access (own <uid>/slips/... folder, and
--     delivery photos of their own orders);
--   * merchants read only slips and delivery photos of orders in their store;
--   * merchants upload only to delivery/<order_id>/ for an order of their store
--     that is out for delivery, with a delivery-capable role;
--   * nobody can update or delete private evidence (slips, delivery photos)
--     through the API any more; clients always upload a new object.
-- food-public
--   * public read is unchanged;
--   * writes are limited to stores/<store_id>/... for owner/admin/manager of
--     that store (the same roles that manage menu and store settings).
--
-- Only storage.objects policies are replaced or dropped, plus two small helper
-- functions. No object or row is changed.
-- Rollback: re-run the food-private policies from
-- migrations_wynos_food_customer_access_gate_v2.sql and the food-public write
-- policies from migrations_wynos_food_merchant_v1.sql, then
-- drop function public.food_store_media_writable(text), public.food_path_uuid(text).

-- helpers --------------------------------------------------------------------

-- A storage path segment as a uuid, or null when it is not one. Comparing
-- o.id = food_path_uuid(...) (instead of o.id::text = ...) lets the policies
-- use the food_orders primary key, and CASE never casts a non-uuid.
create or replace function public.food_path_uuid(p_segment text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when p_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then p_segment::uuid
  end;
$$;

revoke all on function public.food_path_uuid(text) from public, anon;
grant execute on function public.food_path_uuid(text) to authenticated;

-- Public store media lives under stores/<store_id>/...; only that store's
-- owner/admin/manager may write it. One definition for all three write policies.
create or replace function public.food_store_media_writable(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select (storage.foldername(p_name))[1] = 'stores'
    and public.merchant_has_store_role(
      public.food_path_uuid((storage.foldername(p_name))[2]),
      array['owner','admin','manager']
    );
$$;

revoke all on function public.food_store_media_writable(text) from public, anon;
grant execute on function public.food_store_media_writable(text) to authenticated;

-- food-private --------------------------------------------------------------

drop policy if exists "Food private media readable by rollout gate" on storage.objects;
create policy "Food private media readable by rollout gate"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id = public.food_path_uuid((storage.foldername(name))[2])
          and o.buyer_id = auth.uid()
      )
    )
    or (
      (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id = public.food_path_uuid((storage.foldername(name))[2])
          and public.food_has_merchant_access(o.store_id)
      )
    )
    -- Slips: <buyer>/slips/<order_id>/<file>, or the path the order points at
    -- (legacy <buyer>/slips/<file>). Not tied to buyer_id, which becomes null
    -- if the buyer's profile is deleted.
    or (
      (storage.foldername(name))[2] = 'slips'
      and (
        exists (
          select 1
          from public.food_orders o
          where o.id = public.food_path_uuid((storage.foldername(name))[3])
            and public.food_has_merchant_access(o.store_id)
        )
        or exists (
          select 1
          from public.food_orders o
          where o.payment_slip_path = name
            and public.food_has_merchant_access(o.store_id)
        )
      )
    )
  )
);

drop policy if exists "Food private upload by rollout gate" on storage.objects;
create policy "Food private upload by rollout gate"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-private'
  and (
    (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or (
      (storage.foldername(name))[1] = 'delivery'
      and array_length(storage.foldername(name), 1) = 2
      and exists (
        select 1
        from public.food_orders o
        where o.id = public.food_path_uuid((storage.foldername(name))[2])
          and o.status = 'out_for_delivery'
          and public.merchant_has_store_role(o.store_id, array['owner','admin','manager','orders','delivery'])
      )
    )
  )
);

-- Payment slips are evidence too: once uploaded, nobody edits or deletes them
-- through the API. Clients always upload a new object (upsert:false) and the
-- order points at it, so customers do not need update/delete either.
drop policy if exists "Food private update by rollout gate" on storage.objects;
drop policy if exists "Food private delete by rollout gate" on storage.objects;

-- food-public ---------------------------------------------------------------

drop policy if exists "Food public media merchant upload" on storage.objects;
create policy "Food public media merchant upload"
on storage.objects for insert to authenticated
with check (bucket_id='food-public' and public.food_store_media_writable(name));

drop policy if exists "Food public media merchant update" on storage.objects;
create policy "Food public media merchant update"
on storage.objects for update to authenticated
using (bucket_id='food-public' and public.food_store_media_writable(name))
with check (bucket_id='food-public' and public.food_store_media_writable(name));

drop policy if exists "Food public media merchant delete" on storage.objects;
create policy "Food public media merchant delete"
on storage.objects for delete to authenticated
using (bucket_id='food-public' and public.food_store_media_writable(name));
