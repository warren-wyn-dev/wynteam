drop policy if exists "Users can view their own daily follow suggestions"
  on public.daily_follow_suggestion_deliveries;

create policy "Users can view their own daily follow suggestions"
  on public.daily_follow_suggestion_deliveries
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    and coalesce(
      (select ((auth.jwt() ->> 'is_anonymous')::boolean)),
      false
    ) is false
  );

create or replace function public.mark_daily_follow_suggestion_opened(
  p_delivery_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    (select ((auth.jwt() ->> 'is_anonymous')::boolean)),
    false
  );
begin
  if v_uid is null or v_is_anonymous then
    raise exception 'Permanent account required';
  end if;

  update public.daily_follow_suggestion_deliveries
  set opened_at = coalesce(opened_at, now()),
      updated_at = now()
  where id = p_delivery_id
    and user_id = v_uid
    and status = 'sent';

  return found;
end;
$$;

revoke all on function public.mark_daily_follow_suggestion_opened(uuid)
  from public, anon;
grant execute on function public.mark_daily_follow_suggestion_opened(uuid)
  to authenticated;
