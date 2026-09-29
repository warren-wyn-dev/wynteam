-- WYN-191 — Ranked People Search
-- Exact username -> username prefix -> exact display name -> display-name prefix
-- -> substring similarity. Blocked relationships never appear.

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

create index if not exists profiles_username_trgm_idx
  on public.profiles using gin (lower(username) extensions.gin_trgm_ops);

create index if not exists profiles_display_name_trgm_idx
  on public.profiles using gin (lower(coalesce(display_name, '')) extensions.gin_trgm_ops);

create or replace function public.search_profiles_ranked(
  p_query text,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  username text,
  display_name text,
  bio text,
  avatar_url text,
  cover_url text,
  platform_role text,
  is_private boolean,
  is_verified boolean,
  dm_permission text,
  mention_permission text,
  comment_permission text,
  likes_visibility text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with input as (
    select lower(regexp_replace(trim(coalesce(p_query, '')), '^@+', '')) as term
  )
  select
    p.id,
    p.username,
    p.display_name,
    p.bio,
    p.avatar_url,
    p.cover_url,
    p.platform_role,
    p.is_private,
    p.is_verified,
    p.dm_permission,
    p.mention_permission,
    p.comment_permission,
    p.likes_visibility
  from public.profiles p
  cross join input i
  where length(i.term) >= 2
    and (
      lower(coalesce(p.username, '')) like '%' || i.term || '%'
      or lower(coalesce(p.display_name, '')) like '%' || i.term || '%'
    )
    and (
      auth.uid() is null
      or p.id = auth.uid()
      or not internal.is_blocked_either_way(auth.uid(), p.id)
    )
  order by
    case
      when lower(coalesce(p.username, '')) = i.term then 0
      when lower(coalesce(p.username, '')) like i.term || '%' then 1
      when lower(coalesce(p.display_name, '')) = i.term then 2
      when lower(coalesce(p.display_name, '')) like i.term || '%' then 3
      else 4
    end,
    greatest(
      extensions.similarity(lower(coalesce(p.username, '')), i.term),
      extensions.similarity(lower(coalesce(p.display_name, '')), i.term)
    ) desc,
    p.is_verified desc,
    lower(coalesce(p.username, '')) asc,
    p.id asc
  limit greatest(1, least(coalesce(p_limit, 30), 50))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.search_profiles_ranked(text, integer, integer) from public, anon;
grant execute on function public.search_profiles_ranked(text, integer, integer) to authenticated;
