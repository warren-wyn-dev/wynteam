-- WYNOS Merchant notification test center v1.
-- Sends a self-only test event through Merchant In-App/Realtime and the existing
-- notifications -> Database Webhook -> FCM path. No real Food order is created.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'merchant_notifications'
  ) then
    alter publication supabase_realtime add table public.merchant_notifications;
  end if;
end
$$;

alter table public.notification_push_deliveries enable row level security;

drop policy if exists "Users can view own push deliveries" on public.notification_push_deliveries;
create policy "Users can view own push deliveries"
on public.notification_push_deliveries
for select to authenticated
using (user_id = (select auth.uid()));

revoke all on public.notification_push_deliveries from anon, authenticated;
grant select on public.notification_push_deliveries to authenticated;

create or replace function public.merchant_send_test_notification(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_account_id uuid;
  v_merchant_notification_id uuid;
  v_push_notification_id uuid;
  v_created_at timestamptz := clock_timestamp();
begin
  if v_user is null then
    raise exception 'authentication_required';
  end if;

  select fs.merchant_account_id
    into v_account_id
  from public.food_stores fs
  where fs.id = p_store_id;

  if v_account_id is null then
    raise exception 'merchant_store_not_found';
  end if;

  if not exists (
    select 1
    from public.merchant_memberships mm
    where mm.merchant_account_id = v_account_id
      and mm.user_id = v_user
      and mm.active
  ) then
    raise exception 'merchant_access_denied';
  end if;

  -- Explicit user action only, but keep a server-side guard so the test
  -- endpoint cannot be abused as a Push spam loop.
  if exists (
    select 1
    from public.merchant_notifications mn
    where mn.merchant_account_id = v_account_id
      and mn.recipient_user_id = v_user
      and mn.type = 'system'
      and mn.reason = 'ทดสอบการแจ้งเตือน · WYNOS Merchant'
      and mn.created_at > now() - interval '3 seconds'
  ) then
    raise exception 'notification_test_rate_limited';
  end if;

  insert into public.merchant_notifications(
    merchant_account_id,
    recipient_user_id,
    type,
    reason,
    created_at
  )
  values (
    v_account_id,
    v_user,
    'system',
    'ทดสอบการแจ้งเตือน · WYNOS Merchant',
    v_created_at
  )
  returning id into v_merchant_notification_id;

  -- Reuse the production Push delivery path. Mark this transport-only test
  -- row read immediately so it does not add to the normal Social unread badge.
  insert into public.notifications(
    recipient_id,
    actor_id,
    type,
    reason,
    is_read,
    created_at
  )
  values (
    v_user,
    null,
    'system',
    'WYNOS Merchant · ทดสอบการแจ้งเตือน',
    true,
    v_created_at
  )
  returning id into v_push_notification_id;

  return jsonb_build_object(
    'merchant_notification_id', v_merchant_notification_id,
    'push_notification_id', v_push_notification_id,
    'created_at', v_created_at
  );
end;
$$;

revoke all on function public.merchant_send_test_notification(uuid) from public, anon;
grant execute on function public.merchant_send_test_notification(uuid) to authenticated;
