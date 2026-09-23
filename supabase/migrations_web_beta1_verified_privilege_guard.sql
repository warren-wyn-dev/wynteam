-- WYNOS Web Beta1: prevent end users from awarding or removing Verified.
-- Data-preserving, repeatable security fix; no frontend or version change.
-- RLS limits profile rows, not which profile columns a user may write.
-- Keep all existing application profile writes except is_verified.
revoke insert, update on table public.profiles from anon, authenticated;
revoke insert (is_verified), update (is_verified)
  on table public.profiles from anon, authenticated;

grant insert (
  id, username, created_at, display_name, bio, avatar_url,
  platform_role, is_private, dm_permission, mention_permission,
  comment_permission, likes_visibility, referral_code, cover_url, social_links
) on table public.profiles to authenticated;

grant update (
  id, username, created_at, display_name, bio, avatar_url,
  platform_role, is_private, dm_permission, mention_permission,
  comment_permission, likes_visibility, referral_code, cover_url, social_links
) on table public.profiles to authenticated;

-- Defense in depth if another migration accidentally restores broad grants.
-- Trusted service_role and owner-operated SQL retain Verified administration.
-- Do not grant service_role keys to any browser/client.
create or replace function internal.profiles_guard_verified()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $function$
begin
  if current_user not in ('postgres', 'service_role') then
    if tg_op = 'INSERT' and new.is_verified is distinct from false then
      raise exception 'Only trusted server roles may set profiles.is_verified'
        using errcode = '42501';
    elsif tg_op = 'UPDATE' and new.is_verified is distinct from old.is_verified then
      raise exception 'Only trusted server roles may modify profiles.is_verified'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function internal.profiles_guard_verified() from public, anon, authenticated;

drop trigger if exists profiles_guard_verified on public.profiles;
create trigger profiles_guard_verified
  before insert or update on public.profiles
  for each row execute function internal.profiles_guard_verified();
