-- Quote Reposts are authored posts, not aliases for their source Drop.
-- All four interactions below refer to redrops.id, never redrops.drop_id.
-- Existing original Drop likes/comments/redrops/saves are intentionally untouched.
begin;

create table if not exists public.quote_likes (
  quote_id uuid not null references public.redrops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (quote_id, user_id)
);
create index if not exists quote_likes_user_idx on public.quote_likes(user_id,created_at desc);
alter table public.quote_likes enable row level security;
drop policy if exists "Visible quote likes" on public.quote_likes;
create policy "Visible quote likes" on public.quote_likes
  for select to authenticated
  using (exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null));
drop policy if exists "Like visible quotes as self" on public.quote_likes;
create policy "Like visible quotes as self" on public.quote_likes
  for insert to authenticated with check (
    auth.uid()=user_id
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false
    and exists (select 1 from public.redrops q where q.id=quote_id
      and q.quote_text is not null and not internal.is_blocked_either_way(auth.uid(),q.redropper_id))
  );
drop policy if exists "Unlike own quotes" on public.quote_likes;
create policy "Unlike own quotes" on public.quote_likes
  for delete to authenticated using (auth.uid()=user_id);

create table if not exists public.quote_comments (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.redrops(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  text_content text not null,
  created_at timestamptz not null default now(),
  constraint quote_comments_text_length check (char_length(btrim(text_content)) between 1 and 500)
);
create index if not exists quote_comments_quote_created_idx
  on public.quote_comments(quote_id,created_at asc);
alter table public.quote_comments enable row level security;
drop policy if exists "Read visible quote comments" on public.quote_comments;
create policy "Read visible quote comments" on public.quote_comments
  for select to authenticated using (
    not internal.is_blocked_either_way(auth.uid(),author_id)
    and exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null)
  );
drop policy if exists "Comment on visible quotes as self" on public.quote_comments;
create policy "Comment on visible quotes as self" on public.quote_comments
  for insert to authenticated with check (
    auth.uid()=author_id
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false
    and not internal.is_posting_blocked(auth.uid())
    and exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null
      and not internal.is_blocked_either_way(auth.uid(),q.redropper_id)
      and internal.comment_allowed(q.redropper_id,auth.uid()))
  );
drop policy if exists "Delete own quote comments" on public.quote_comments;
create policy "Delete own quote comments" on public.quote_comments
  for delete to authenticated using (auth.uid()=author_id);

-- A standard repost of a Quote is a separate operation from reposting
-- that Quote's original Drop. This relation never creates a redrops row.
create table if not exists public.quote_reposts (
  quote_id uuid not null references public.redrops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (quote_id,user_id)
);
create index if not exists quote_reposts_user_idx
  on public.quote_reposts(user_id,created_at desc);
alter table public.quote_reposts enable row level security;
drop policy if exists "Read visible quote reposts" on public.quote_reposts;
create policy "Read visible quote reposts" on public.quote_reposts
  for select to authenticated using (
    exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null)
  );
drop policy if exists "Repost visible quotes as self" on public.quote_reposts;
create policy "Repost visible quotes as self" on public.quote_reposts
  for insert to authenticated with check (
    auth.uid()=user_id
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false
    and not internal.is_posting_blocked(auth.uid())
    and exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null
      and not internal.is_blocked_either_way(auth.uid(),q.redropper_id))
  );
drop policy if exists "Undo own quote reposts" on public.quote_reposts;
create policy "Undo own quote reposts" on public.quote_reposts
  for delete to authenticated using (auth.uid()=user_id);

create table if not exists public.quote_saves (
  quote_id uuid not null references public.redrops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (quote_id,user_id)
);
create index if not exists quote_saves_user_idx
  on public.quote_saves(user_id,created_at desc);
alter table public.quote_saves enable row level security;
drop policy if exists "Read own quote saves" on public.quote_saves;
create policy "Read own quote saves" on public.quote_saves
  for select to authenticated using (auth.uid()=user_id);
drop policy if exists "Save visible quotes as self" on public.quote_saves;
create policy "Save visible quotes as self" on public.quote_saves
  for insert to authenticated with check (
    auth.uid()=user_id
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false
    and exists (select 1 from public.redrops q where q.id=quote_id and q.quote_text is not null)
  );
drop policy if exists "Remove own quote saves" on public.quote_saves;
create policy "Remove own quote saves" on public.quote_saves
  for delete to authenticated using (auth.uid()=user_id);

revoke all on public.quote_likes,public.quote_comments,public.quote_reposts,public.quote_saves from public,anon;
grant select,insert,delete on public.quote_likes,public.quote_comments,public.quote_reposts,public.quote_saves to authenticated;

-- Batch counts + viewer flags for feed, Profile and direct quote links.
-- SECURITY INVOKER ensures invisible/blocked Quotes produce no rows.
create or replace function public.get_quote_engagement(p_quote_ids uuid[])
returns table (
  quote_id uuid,
  like_count bigint,
  comment_count bigint,
  redrop_count bigint,
  liked_by_me boolean,
  saved_by_me boolean,
  redropped_by_me boolean
)
language sql stable security invoker set search_path=public
as $$
  select q.id,
    (select count(*) from public.quote_likes l where l.quote_id=q.id),
    (select count(*) from public.quote_comments c where c.quote_id=q.id),
    (select count(*) from public.quote_reposts rp where rp.quote_id=q.id),
    exists(select 1 from public.quote_likes l where l.quote_id=q.id and l.user_id=auth.uid()),
    exists(select 1 from public.quote_saves sv where sv.quote_id=q.id and sv.user_id=auth.uid()),
    exists(select 1 from public.quote_reposts rp where rp.quote_id=q.id and rp.user_id=auth.uid())
  from (select distinct unnest(coalesce(p_quote_ids,'{}'::uuid[])) as id limit 100) ids
  join public.redrops q on q.id=ids.id and q.quote_text is not null;
$$;
revoke all on function public.get_quote_engagement(uuid[]) from public,anon;
grant execute on function public.get_quote_engagement(uuid[]) to authenticated;

commit;
