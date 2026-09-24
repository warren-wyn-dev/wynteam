-- Web Beta1 security hardening: only a currently valid invite link may disclose
-- the club's identifying metadata to a public/anonymous preview caller.
-- Preserve the existing status contract for revoked/expired/exhausted links,
-- and the WYN-154 one-row "not_found" behavior for unknown codes.
--
-- Staged for review: do not apply to production until explicit Founder approval.
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
  with matched as (
    select
      case
        when l.id is null then 'not_found'
        when l.revoked_at is not null then 'revoked'
        when l.expires_at is not null and l.expires_at < now() then 'expired'
        when l.max_uses is not null and l.use_count >= l.max_uses then 'exhausted'
        else 'valid'
      end as invite_status,
      c.id as target_club_id,
      c.name as target_club_name,
      c.privacy as target_club_privacy,
      c.icon_url as target_club_icon_url
    from (select p_code as code) req
    left join public.club_invite_links l on l.code = req.code
    left join public.clubs c on c.id = l.club_id
    limit 1
  )
  select
    m.invite_status,
    case when m.invite_status = 'valid' then m.target_club_id end,
    case when m.invite_status = 'valid' then m.target_club_name end,
    case when m.invite_status = 'valid' then m.target_club_privacy end,
    case when m.invite_status = 'valid' then m.target_club_icon_url end
  from matched m;
$$;

-- Preserve the intentional three-function pre-auth allowlist.
revoke all on function public.preview_club_invite_link(text) from public;
grant execute on function public.preview_club_invite_link(text) to anon, authenticated;

commit;
