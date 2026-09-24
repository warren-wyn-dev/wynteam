-- Isolated PostgreSQL integration: no production users or follows touched.
\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema internal;
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
create table auth.users(id uuid primary key, created_at timestamptz not null default clock_timestamp(), is_anonymous boolean not null default false);
create table public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  is_private boolean not null default false
);
create table public.follows(
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id,following_id),
  constraint follows_no_self_follow check(follower_id <> following_id)
);
create table public.blocks(blocker_id uuid not null, blocked_id uuid not null);
create table public.notifications(recipient_id uuid, actor_id uuid, type text);
create function internal.notification_enabled(p_user uuid, p_key text)
returns boolean language sql stable as $$ select true $$;
create function public.notify_follow()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin
  if internal.notification_enabled(new.following_id,'follows') then
    insert into public.notifications(recipient_id,actor_id,type)
    values(new.following_id,new.follower_id,'follow');
  end if;
  return new;
end $$;
create trigger follows_notify after insert on public.follows
for each row execute function public.notify_follow();

-- Official and a legacy account exist before feature activation.
insert into auth.users(id,created_at) values
  ('00000000-0000-4000-8000-000000000001','2020-01-01 UTC'),
  ('00000000-0000-4000-8000-000000000002','2020-01-01 UTC');
insert into public.profiles(id,username) values
  ('00000000-0000-4000-8000-000000000001','wynos_s'),
  ('00000000-0000-4000-8000-000000000002','legacy_member');
\ir ../migrations_web_beta1_official_autofollow.sql

-- A new deployment must never start auto-following before the web disclosure
-- has been deployed and Founder has approved the separate activation.
do $
begin
  if (select enabled_at from internal.official_autofollow_settings where singleton)
     is distinct from 'infinity'::timestamptz then
    raise exception 'first-follow must default to disabled until explicit activation';
  end if;
end $;

-- Mimic real permanent user profile insert through authenticated RLS.
grant usage on schema public to authenticated,anon;
grant select,insert,update,delete on public.profiles,public.follows to authenticated;
alter table public.profiles enable row level security;
create policy profiles_own_write on public.profiles to authenticated
using (auth.uid()=id) with check(auth.uid()=id);
alter table public.follows enable row level security;
create policy follows_own_write on public.follows to authenticated
using(auth.uid()=follower_id) with check(auth.uid()=follower_id);

-- A genuine registration while the feature is disabled stays unmodified,
-- including after a later profile edit when this Auth account predates activation.
insert into auth.users(id,created_at)
values('00000000-0000-4000-8000-000000000007',clock_timestamp());
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000007',false);
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000007','before_activation');
reset role;
do $
begin
  if exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000007')
     or exists(select 1 from internal.official_autofollow_processed
               where user_id='00000000-0000-4000-8000-000000000007') then
    raise exception 'disabled follow gate modified a genuine signup';
  end if;
end $;

-- Test-only activation, performed explicitly after the disclosure check.
-- Production remains disabled; this isolated fixture has no production access.
update internal.official_autofollow_settings set enabled_at=clock_timestamp()
where singleton is true;
update public.profiles set username='before_activation_renamed'
where id='00000000-0000-4000-8000-000000000007';
do $
begin
  if exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000007') then
    raise exception 'a user who joined before activation must not be backfilled';
  end if;
end $;

-- Record a new user with Auth creation after feature activation.
insert into auth.users(id,created_at) values
  ('00000000-0000-4000-8000-000000000003',clock_timestamp()+interval '1 second'),
  ('00000000-0000-4000-8000-000000000004',clock_timestamp()+interval '1 second'),
  ('00000000-0000-4000-8000-000000000005','2020-01-01 UTC'),
  ('00000000-0000-4000-8000-000000000006',clock_timestamp()+interval '1 second');
update auth.users set is_anonymous=true where id='00000000-0000-4000-8000-000000000006';

set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000003','new_member');
reset role;

do $$
begin
  if not exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000003'
    and following_id='00000000-0000-4000-8000-000000000001') then
    raise exception 'new permanent user missing first-time official follow';
  end if;
  if exists(select 1 from public.notifications where recipient_id='00000000-0000-4000-8000-000000000001') then
    raise exception 'auto-follow must be silent for Official';
  end if;
  if not exists(select 1 from internal.official_autofollow_processed where user_id='00000000-0000-4000-8000-000000000003') then
    raise exception 'one-time marker must persist';
  end if;
  if exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000002') then
    raise exception 'existing users must not be backfilled';
  end if;
end $$;

-- Explicit user unfollow and profile update/recreate cannot auto-refollow.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
delete from public.follows where follower_id='00000000-0000-4000-8000-000000000003';
update public.profiles set username='new_member_renamed'
where id='00000000-0000-4000-8000-000000000003';
reset role;
delete from public.profiles where id='00000000-0000-4000-8000-000000000003';
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000003','new_member_again');
reset role;

-- Username can be set later (Google OAuth or interrupted signup).
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000004',null);
update public.profiles set username='oauth_member'
where id='00000000-0000-4000-8000-000000000004';
-- Even a new profile on an old Auth user is NOT eligible.
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000005','old_auth_new_profile');
insert into public.profiles(id,username)
values('00000000-0000-4000-8000-000000000006','anonymous_profile');

do $$
begin
  if exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000003') then
    raise exception 'opt-out or account recreation caused repeat auto-follow';
  end if;
  if not exists(select 1 from public.follows where follower_id='00000000-0000-4000-8000-000000000004') then
    raise exception 'username-later onboarding did not auto-follow';
  end if;
  if exists(select 1 from public.follows where follower_id in
    ('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000007')) then
    raise exception 'legacy/anonymous/pre-activation user was auto-followed';
  end if;
  if (select count(*) from internal.official_autofollow_processed) <> 2 then
    raise exception 'unexpected one-time marker count';
  end if;
  if has_table_privilege('authenticated','internal.official_autofollow_processed','SELECT')
    or has_table_privilege('anon','internal.official_autofollow_processed','SELECT') then
    raise exception 'processed markers must not be exposed';
  end if;
end $$;

-- Manual re-follow after an opt-out must behave like a normal follow,
-- including the standard notification hook.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
insert into public.follows(follower_id,following_id)
values('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001');
reset role;
do $$
begin
  if (select count(*) from public.notifications
      where recipient_id='00000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'manual re-follow notification was suppressed';
  end if;
end $$;

select 'OFFICIAL AUTOFOLLOW SECURITY AND OPT-OUT CHECKS PASSED' as result;
