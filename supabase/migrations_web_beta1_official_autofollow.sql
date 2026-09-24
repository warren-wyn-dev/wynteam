-- Web Beta1: first-time official follow for newly registered permanent users.
-- Additive and forward-only. Install while DISABLED; show the signup disclosure in production
-- before enabling the follow gate by an explicitly approved, separate DB operation.
-- Existing accounts are not backfilled. A persisted marker survives profile deletion
-- so re-creating a profile, logging in, or unfollowing can NEVER auto-follow again.
begin;

-- Abort deployment if the single public official handle is absent/private.
do $$
begin
  if (select count(*) from public.profiles where username = 'wynos_s' and is_private is false) <> 1 then
    raise exception 'Verified public official @wynos_s is required before enabling new-user auto-follow';
  end if;
end
$$;

create table if not exists internal.official_autofollow_settings (
  singleton boolean primary key default true check (singleton),
  enabled_at timestamptz not null default 'infinity'::timestamptz
);
-- Correct the column default on databases where the table was pre-staged.
-- Do not overwrite any existing enabled_at value; the live project already
-- has this infrastructure with enabled_at = infinity and must stay disabled.
alter table internal.official_autofollow_settings
  alter column enabled_at set default 'infinity'::timestamptz;
insert into internal.official_autofollow_settings(singleton) values(true)
on conflict (singleton) do nothing;

create table if not exists internal.official_autofollow_processed (
  user_id uuid primary key references auth.users(id) on delete cascade,
  processed_at timestamptz not null default now()
);

revoke all on internal.official_autofollow_settings from public, anon, authenticated;
revoke all on internal.official_autofollow_processed from public, anon, authenticated;

-- Suppress ONLY the automatic welcome follow's notification to the Official
-- account. Regular manual follows keep their existing notification behavior.
create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if current_setting('wynos.silent_official_autofollow', true) is distinct from 'on'
     and internal.notification_enabled(new.following_id, 'follows') then
    insert into public.notifications(recipient_id, actor_id, type)
    values(new.following_id, new.follower_id, 'follow');
  end if;
  return new;
end
$$;

create or replace function internal.auto_follow_official_on_first_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_official uuid;
  v_activated timestamptz;
  v_old_flag text;
begin
  if new.username is null or new.username = 'wynos_s' then return new; end if;

  select enabled_at into v_activated
  from internal.official_autofollow_settings where singleton is true;

  -- Both email signup and Google OAuth eventually set profiles.username.
  -- A legacy account that first edits/creates its profile after launch does
  -- NOT become a new account; eligibility is its original Auth creation time.
  if not exists (
    select 1 from auth.users u
    where u.id = new.id
      and u.created_at >= v_activated
      and u.is_anonymous is false
  ) then return new; end if;

  select id into v_official from public.profiles
  where username = 'wynos_s' and is_private is false;

  if v_official is null or v_official = new.id then return new; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = new.id and b.blocked_id = v_official)
       or (b.blocker_id = v_official and b.blocked_id = new.id)
  ) then return new; end if;

  -- Persist before the follow insert. ON CONFLICT guarantees that even a
  -- retried UPDATE, recreated profile, or manual unfollow cannot auto-refollow.
  begin
    insert into internal.official_autofollow_processed(user_id) values(new.id)
    on conflict (user_id) do nothing;
    if not found then return new; end if;

    v_old_flag := current_setting('wynos.silent_official_autofollow', true);
    perform set_config('wynos.silent_official_autofollow', 'on', true);
    insert into public.follows(follower_id, following_id)
    values(new.id, v_official)
    on conflict (follower_id, following_id) do nothing;
    perform set_config('wynos.silent_official_autofollow', coalesce(v_old_flag, ''), true);
  exception when others then
    perform set_config('wynos.silent_official_autofollow', coalesce(v_old_flag, ''), true);
    -- An optional onboarding action must never block account registration.
    -- The inner subtransaction reverts both the marker and any failed insert.
    raise warning 'WYNOS official auto-follow skipped; SQLSTATE %', SQLSTATE;
  end;
  return new;
end
$$;

revoke all on function internal.auto_follow_official_on_first_profile()
from public, anon, authenticated;

drop trigger if exists profiles_official_autofollow_first_time on public.profiles;
create trigger profiles_official_autofollow_first_time
after insert or update of username on public.profiles
for each row
when (new.username is not null)
execute function internal.auto_follow_official_on_first_profile();

commit;
