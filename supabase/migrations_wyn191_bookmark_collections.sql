-- WYN-191: private bookmark collections for WYNOS Web Beta1 Phase 3.
-- Staged upgrade. Deploy this migration before setting
-- NEXT_PUBLIC_WYNOS_BOOKMARK_COLLECTIONS=1 on a web deployment.
-- Non-destructive; unsaving a Drop/Quote removes its collection membership.
create table if not exists public.bookmark_collections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (
    name=btrim(name) and char_length(name) between 1 and 48
    and name !~ '[[:cntrl:]]'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,owner_id)
);
create unique index if not exists bookmark_collections_owner_name_idx
  on public.bookmark_collections(owner_id, lower(name));
create index if not exists bookmark_collections_owner_created_idx
  on public.bookmark_collections(owner_id,created_at desc);
alter table public.bookmark_collections enable row level security;
drop policy if exists "Owner reads bookmark collections" on public.bookmark_collections;
create policy "Owner reads bookmark collections"
  on public.bookmark_collections for select to authenticated
  using (owner_id=auth.uid());
drop policy if exists "Owner creates bookmark collections" on public.bookmark_collections;
create policy "Owner creates bookmark collections"
  on public.bookmark_collections for insert to authenticated
  with check (owner_id=auth.uid());
drop policy if exists "Owner renames bookmark collections" on public.bookmark_collections;
create policy "Owner renames bookmark collections"
  on public.bookmark_collections for update to authenticated
  using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists "Owner deletes bookmark collections" on public.bookmark_collections;
create policy "Owner deletes bookmark collections"
  on public.bookmark_collections for delete to authenticated
  using (owner_id=auth.uid());

create table if not exists public.bookmark_collection_items (
  collection_id uuid not null,
  owner_id uuid not null,
  content_type text not null check (content_type in ('drop','quote')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(collection_id,content_type,content_id),
  foreign key(collection_id,owner_id)
    references public.bookmark_collections(id,owner_id) on delete cascade
);
create index if not exists bookmark_collection_items_owner_idx
  on public.bookmark_collection_items(owner_id,content_type,content_id);
alter table public.bookmark_collection_items enable row level security;
drop policy if exists "Owner reads bookmark items" on public.bookmark_collection_items;
create policy "Owner reads bookmark items"
  on public.bookmark_collection_items for select to authenticated
  using (owner_id=auth.uid());
drop policy if exists "Owner adds only their saved items" on public.bookmark_collection_items;
create policy "Owner adds only their saved items"
  on public.bookmark_collection_items for insert to authenticated
  with check (
    owner_id=auth.uid() and (
      (content_type='drop' and exists(
        select 1 from public.saves s
        where s.user_id=auth.uid() and s.content_type='drop' and s.content_id=content_id
      ))
      or
      (content_type='quote' and exists(
        select 1 from public.quote_saves q
        where q.user_id=auth.uid() and q.quote_id=content_id
      ))
    )
  );
drop policy if exists "Owner removes bookmark items" on public.bookmark_collection_items;
create policy "Owner removes bookmark items"
  on public.bookmark_collection_items for delete to authenticated
  using (owner_id=auth.uid());

revoke all on public.bookmark_collections,public.bookmark_collection_items from public,anon,authenticated;
grant select,delete on public.bookmark_collections,public.bookmark_collection_items to authenticated;
grant insert (owner_id,name) on public.bookmark_collections to authenticated;
grant update (name) on public.bookmark_collections to authenticated;
grant insert (collection_id,owner_id,content_type,content_id)
  on public.bookmark_collection_items to authenticated;

-- Let existing RLS govern cleanup as the same user removes their own save.
-- Service-role maintenance can also clean orphan memberships without broad
-- public-table access. These helper functions are not exposed as an RPC.
create or replace function internal.cleanup_collection_on_unsave()
returns trigger language plpgsql security invoker set search_path=''
as $cleanup$
begin
  if TG_TABLE_NAME='saves' and OLD.content_type='drop' then
    delete from public.bookmark_collection_items
    where owner_id=OLD.user_id and content_type='drop' and content_id=OLD.content_id;
  elsif TG_TABLE_NAME='quote_saves' then
    delete from public.bookmark_collection_items
    where owner_id=OLD.user_id and content_type='quote' and content_id=OLD.quote_id;
  end if;
  return OLD;
end
$cleanup$;
revoke all on function internal.cleanup_collection_on_unsave() from public,anon,authenticated;
drop trigger if exists bookmark_collection_cleanup_on_drop_unsave on public.saves;
create trigger bookmark_collection_cleanup_on_drop_unsave
after delete on public.saves for each row
execute function internal.cleanup_collection_on_unsave();
drop trigger if exists bookmark_collection_cleanup_on_quote_unsave on public.quote_saves;
create trigger bookmark_collection_cleanup_on_quote_unsave
after delete on public.quote_saves for each row
execute function internal.cleanup_collection_on_unsave();
