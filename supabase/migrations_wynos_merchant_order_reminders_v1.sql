-- WYNOS Merchant: re-notify stores about orders nobody has accepted
-- (Founder 2026-10-06: "ทำAก่อน ให้เสร็จเลย").
-- Phones only play the WYNOS order sound while Merchant is open; a closed
-- app gets one ordinary push. So while a paid (or slip-submitted) order
-- waits in pending_acceptance, the store's staff get one more push every
-- minute, at most 5, e.g. "WYNOS Merchant · ออเดอร์ #WF0015 รอรับ 3 นาทีแล้ว".
-- * Reminder state lives in food_order_merchant_reminders, so food_orders
--   (and its triggers) is never touched.
-- * Only orders from the last 3 hours, so old stuck orders never start
--   ringing when this ships.
-- * The text routes to WYNOS Merchant and opens the order (WYN-215 + #940).
-- * pg_cron runs internal.food_remind_waiting_orders() every minute.
-- ROLLBACK:
--   select cron.unschedule(jobid) from cron.job where jobname = 'wynos-merchant-order-reminders';
--   drop function internal.food_remind_waiting_orders();
--   drop table public.food_order_merchant_reminders;

create table if not exists public.food_order_merchant_reminders (
  order_id uuid primary key references public.food_orders(id) on delete cascade,
  sent integer not null default 0 check (sent between 0 and 5),
  last_sent_at timestamptz not null default now()
);

alter table public.food_order_merchant_reminders enable row level security;
revoke all on table public.food_order_merchant_reminders from public, anon, authenticated;

create or replace function internal.food_remind_waiting_orders()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_order record;
  v_minutes integer;
  v_count integer := 0;
begin
  for v_order in
    select o.id, o.store_id, o.order_number,
           greatest(o.created_at, coalesce(o.paid_at, o.created_at), o.updated_at) as waiting_since,
           coalesce(r.sent, 0) as sent,
           r.last_sent_at
    from public.food_orders o
    left join public.food_order_merchant_reminders r on r.order_id = o.id
    where o.status = 'pending_acceptance'
      and o.payment_status in ('submitted', 'paid')
      and o.created_at > now() - interval '3 hours'
      and coalesce(r.sent, 0) < 5
      and coalesce(r.last_sent_at, greatest(o.created_at, coalesce(o.paid_at, o.created_at), o.updated_at))
          <= now() - interval '55 seconds'
    for update of o skip locked
  loop
    v_minutes := greatest(1, floor(extract(epoch from (now() - v_order.waiting_since)) / 60)::integer);

    insert into public.notifications(recipient_id, actor_id, type, reason)
    select fs.user_id, null, 'system',
           'WYNOS Merchant · ออเดอร์ #' || v_order.order_number || ' รอรับ ' || v_minutes || ' นาทีแล้ว'
    from public.food_staff fs
    where fs.store_id = v_order.store_id and fs.active and fs.role in ('owner', 'staff');

    insert into public.food_order_merchant_reminders(order_id, sent, last_sent_at)
    values (v_order.id, 1, now())
    on conflict (order_id) do update
      set sent = public.food_order_merchant_reminders.sent + 1,
          last_sent_at = now();

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function internal.food_remind_waiting_orders() from public, anon, authenticated;

do $$
declare
  v_job bigint;
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    execute 'create extension if not exists pg_cron';
    if to_regclass('cron.job') is not null then
      for v_job in select jobid from cron.job where jobname = 'wynos-merchant-order-reminders' loop
        execute 'select cron.unschedule($1)' using v_job;
      end loop;
      execute 'select cron.schedule($1, $2, $3)'
        using 'wynos-merchant-order-reminders', '* * * * *', 'select internal.food_remind_waiting_orders();';
    end if;
  end if;
end;
$$;
