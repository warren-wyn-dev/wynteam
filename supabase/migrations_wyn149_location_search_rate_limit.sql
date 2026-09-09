-- WYN-149 / BUG-003: race-free LocationIQ rate-limit reservation.
-- One advisory lock per user serializes the count+insert decision so 20
-- concurrent requests cannot all observe the same pre-insert count.

create index if not exists location_search_requests_user_requested_at_idx
  on public.location_search_requests (user_id, requested_at desc);

create or replace function public.reserve_location_search_request(
  p_user_id uuid,
  p_limit integer default 20,
  p_window_seconds integer default 60
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_recent integer;
begin
  if p_user_id is null or p_limit < 1 or p_window_seconds < 1 then
    raise exception 'Invalid rate-limit reservation parameters';
  end if;

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'Unknown user';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('location-search:' || p_user_id::text, 0)
  );

  select count(*)::integer into v_recent
  from public.location_search_requests
  where user_id = p_user_id
    and requested_at >= now() - make_interval(secs => p_window_seconds);

  if v_recent >= p_limit then
    return false;
  end if;

  insert into public.location_search_requests(user_id) values (p_user_id);
  return true;
end;
$$;

revoke all on function public.reserve_location_search_request(uuid,integer,integer)
  from public, anon, authenticated;
grant execute on function public.reserve_location_search_request(uuid,integer,integer)
  to service_role;
