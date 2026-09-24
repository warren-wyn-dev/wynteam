-- Narrow, pre-auth username availability check for Web Beta1 signup.
-- Does not expose user IDs, emails, profile rows, or profile SELECT to anon.
-- Existing public usernames are discoverable in authenticated WYNOS search;
-- this endpoint returns a single boolean, not profile data or a list.
-- Apply in controlled release BEFORE deploying the web client.
begin;

create or replace function public.is_signup_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_username is null or length(p_username) > 20 or p_username !~ '^[a-z0-9_]{3,20}$'
      then false
    when p_username = any(array[
      'admin','administrator','support','help','wynos','wyn',
      'official','root','api','moderator','staff','security','system',
      'null','undefined','everyone','here','channel','settings',
      'about','terms','privacy','www','app', 'zoky'
    ]) then false
    else not exists (
      select 1 from public.profiles where username = p_username
    )
  end;
$$;

revoke all on function public.is_signup_username_available(text) from public;
grant execute on function public.is_signup_username_available(text) to anon, authenticated;

commit;
