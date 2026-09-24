-- Isolated QA database: production data is never read or modified.
\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
grant usage on schema public to anon, authenticated;
create table public.profiles(id uuid primary key, username text unique);
insert into public.profiles(id,username) values ('11111111-1111-1111-1111-111111111111','taken_name');
\ir ../migrations_web_beta1_username_preflight.sql

-- The public role has no direct access to profile rows.
do $$ begin
  if has_table_privilege('anon', 'public.profiles', 'SELECT') then
    raise exception 'anon must not gain profile SELECT';
  end if;
  if has_function_privilege('public','public.is_signup_username_available(text)','EXECUTE') then
    raise exception 'PUBLIC must not execute username lookup';
  end if;
end $$;

set role anon;
do $$ begin
  if public.is_signup_username_available('taken_name') then raise exception 'taken username leaked as available'; end if;
  if not public.is_signup_username_available('free_name') then raise exception 'free username rejected'; end if;
  if public.is_signup_username_available('admin') then raise exception 'reserved username accepted'; end if;
  if public.is_signup_username_available('bad-name!') then raise exception 'invalid username accepted'; end if;
  if public.is_signup_username_available(null) then raise exception 'null username accepted'; end if;
  if public.is_signup_username_available(repeat('x',2000)) then raise exception 'oversized username accepted'; end if;
end $$;
reset role;
set role authenticated;
do $$ begin
  if public.is_signup_username_available('taken_name') then raise exception 'authenticated duplicate accepted'; end if;
  if not public.is_signup_username_available('fresh_name') then raise exception 'authenticated free name rejected'; end if;
end $$;
reset role;
select 'ALL USERNAME PREFLIGHT SQL CHECKS PASSED' as result;
