-- Sandbox-only store-scoped media access. No production records.
create policy "WYNOS sandbox food public read" on storage.objects
for select using (bucket_id = 'food-public');
create policy "WYNOS sandbox food public insert" on storage.objects
for insert to authenticated with check (
 bucket_id = 'food-public' and (storage.foldername(name))[1] = 'stores'
 and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]),array['owner','admin','manager'])
);
create policy "WYNOS sandbox food public update" on storage.objects
for update to authenticated using (
 bucket_id = 'food-public' and (storage.foldername(name))[1] = 'stores'
 and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]),array['owner','admin','manager'])
) with check (
 bucket_id = 'food-public' and (storage.foldername(name))[1] = 'stores'
 and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]),array['owner','admin','manager'])
);
create policy "WYNOS sandbox food public delete" on storage.objects
for delete to authenticated using (
 bucket_id = 'food-public' and (storage.foldername(name))[1] = 'stores'
 and public.merchant_has_store_role(public.food_path_uuid((storage.foldername(name))[2]),array['owner','admin','manager'])
);
