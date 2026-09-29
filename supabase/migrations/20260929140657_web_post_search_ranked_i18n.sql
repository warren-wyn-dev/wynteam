-- WYN-192 — Ranked bilingual Post Search.
-- Thai uses direct substring/trigram matching; English also benefits from
-- simple full-text token matching. SECURITY INVOKER preserves Drops RLS.

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

create index if not exists drops_caption_trgm_active_idx
  on public.drops using gin (lower(coalesce(caption, '')) extensions.gin_trgm_ops)
  where deleted_at is null;

create index if not exists drops_caption_fts_active_idx
  on public.drops using gin (to_tsvector('simple', coalesce(caption, '')))
  where deleted_at is null;

create or replace function public.search_drop_ids_ranked(
  p_query text,
  p_limit integer default 21,
  p_offset integer default 0
)
returns table (id uuid)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with input as (
    select lower(regexp_replace(trim(coalesce(p_query, '')), '\s+', ' ', 'g')) as term
  )
  select d.id
  from public.drops d
  cross join input i
  where length(i.term) >= 2
    and d.deleted_at is null
    and coalesce(d.caption, '') <> ''
    and (
      lower(d.caption) like '%' || i.term || '%'
      or to_tsvector('simple', coalesce(d.caption, '')) @@ plainto_tsquery('simple', i.term)
      or (
        length(i.term) >= 3
        and extensions.similarity(lower(coalesce(d.caption, '')), i.term) >= 0.18
      )
    )
  order by
    case
      when lower(trim(d.caption)) = i.term then 0
      when lower(d.caption) like i.term || '%' then 1
      when lower(d.caption) like '%' || i.term || '%' then 2
      when to_tsvector('simple', coalesce(d.caption, '')) @@ plainto_tsquery('simple', i.term) then 3
      else 4
    end,
    ts_rank_cd(
      to_tsvector('simple', coalesce(d.caption, '')),
      plainto_tsquery('simple', i.term)
    ) desc,
    extensions.similarity(lower(coalesce(d.caption, '')), i.term) desc,
    d.created_at desc,
    d.id asc
  limit greatest(1, least(coalesce(p_limit, 21), 50))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.search_drop_ids_ranked(text, integer, integer) from public, anon;
grant execute on function public.search_drop_ids_ranked(text, integer, integer) to authenticated;
