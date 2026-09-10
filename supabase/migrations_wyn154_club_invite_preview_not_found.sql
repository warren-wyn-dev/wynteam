-- WYN-154 / BUG-004 follow-up: make club invite preview total for unknown codes.
--
-- WYN-136's preview query started from club_invite_links and RIGHT JOINed a
-- one-row request. When the table contained any invite rows but none matching
-- p_code, the WHERE clause filtered every row, so callers received zero rows
-- instead of the documented `not_found` sentinel. Start from the request row
-- and LEFT JOIN the matching invite so the RPC always returns exactly one row.

begin;

create or replace function public.preview_club_invite_link(p_code text)
returns table (
  status text,
  club_id uuid,
  club_name text,
  club_privacy text,
  club_icon_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when l.id is null then 'not_found'
      when l.revoked_at is not null then 'revoked'
      when l.expires_at is not null and l.expires_at < now() then 'expired'
      when l.max_uses is not null and l.use_count >= l.max_uses then 'exhausted'
      else 'valid'
    end,
    c.id,
    c.name,
    c.privacy,
    c.icon_url
  from (select p_code as code) req
  left join public.club_invite_links l on l.code = req.code
  left join public.clubs c on c.id = l.club_id
  limit 1;
$$;

-- Preview is intentionally available to both anonymous guests and signed-in
-- users. Remove the default PUBLIC grant so only the two application roles can
-- invoke it explicitly.
revoke all on function public.preview_club_invite_link(text) from public;
grant execute on function public.preview_club_invite_link(text) to anon, authenticated;

commit;
