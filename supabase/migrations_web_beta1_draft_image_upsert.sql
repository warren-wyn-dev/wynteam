-- Web Beta1: owner-only repeated draft image upload using Storage upsert:true.
-- Existing SELECT/INSERT policies remain in force; never allow publication overwrites.
begin;
drop policy if exists "Owners can update their own draft images" on storage.objects;
create policy "Owners can update their own draft images"
on storage.objects for update to authenticated
using (
  bucket_id='drop-images'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and (storage.foldername(name))[2]='drafts'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),false) is false
)
with check (
  bucket_id='drop-images'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and (storage.foldername(name))[2]='drafts'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),false) is false
);
commit;
