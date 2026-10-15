-- Zoky order chat, ISOLATED STAGING PROPOSAL ONLY.
-- Do not execute on Production or auto-deploy. Promote to a numbered migration
-- only after a dedicated staging project, RLS tests and merchant UX QA exist.
--
-- One conversation per real Food order: no arbitrary direct messaging.
-- WYNOS Account auth.uid() is the shared identity on both clients.
create table if not exists public.food_order_chat_messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null,
  body text not null,
  created_at timestamptz not null default now(),
  constraint food_order_chat_body_limit
    check (char_length(btrim(body)) between 1 and 1200),
  constraint food_order_chat_client_id_unique unique (sender_id, client_id)
);
create index if not exists food_order_chat_order_timeline_idx
  on public.food_order_chat_messages(order_id, created_at desc, id desc);
create index if not exists food_order_chat_sender_rate_idx
  on public.food_order_chat_messages(sender_id, created_at desc);

alter table public.food_order_chat_messages enable row level security;
revoke all on public.food_order_chat_messages from public, anon, authenticated;
grant select, insert (order_id, sender_id, client_id, body)
  on public.food_order_chat_messages to authenticated;

-- Defense-in-depth: buyer on the order or active owner/manager/orders/support
-- member of its assigned merchant account. Delivery personnel do not gain
-- order chat access by default.
drop policy if exists "Zoky order chat participant select" on public.food_order_chat_messages;
create policy "Zoky order chat participant select"
on public.food_order_chat_messages for select to authenticated
using (
  (select auth.uid()) is not null
  and exists (
    select 1 from public.food_orders o
    where o.id = food_order_chat_messages.order_id
      and (
        o.buyer_id = (select auth.uid())
        or public.merchant_has_store_role(
          o.store_id, array['owner','admin','manager','orders','support']::text[]
        )
      )
  )
);

drop policy if exists "Zoky order chat participant insert" on public.food_order_chat_messages;
create policy "Zoky order chat participant insert"
on public.food_order_chat_messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.food_orders o
    where o.id = food_order_chat_messages.order_id
      and (
        o.buyer_id = (select auth.uid())
        or public.merchant_has_store_role(
          o.store_id, array['owner','admin','manager','orders','support']::text[]
        )
      )
  )
);

-- Anti-spam. No direct UPDATE/DELETE grants or policies.
create or replace function public.food_order_chat_insert_guard()
returns trigger language plpgsql security invoker set search_path = ''
as $func$
begin
  if (select auth.uid()) is null or new.sender_id <> (select auth.uid()) then
    raise exception 'sender_not_authenticated' using errcode='42501';
  end if;
  new.body := btrim(new.body);
  if char_length(new.body) not between 1 and 1200 then
    raise exception 'invalid_chat_length';
  end if;
  -- Serialize sends for this sender to avoid racing around the rate limit.
  perform pg_advisory_xact_lock(hashtextextended(new.sender_id::text, 15061));
  if (
    select count(*) from public.food_order_chat_messages m
    where m.sender_id = new.sender_id
      and m.created_at >= now() - interval '1 minute'
  ) >= 20 then
    raise exception 'chat_rate_limited';
  end if;
  return new;
end;
$func$;
revoke all on function public.food_order_chat_insert_guard() from public, anon;
-- A trigger invokes it; client EXECUTE is not required.
drop trigger if exists food_order_chat_insert_guard_tr on public.food_order_chat_messages;
create trigger food_order_chat_insert_guard_tr
before insert on public.food_order_chat_messages
for each row execute function public.food_order_chat_insert_guard();

-- Deployment gates:
-- 1) independent disposable staging, merchant_has_store_role deployed
-- 2) buyer/merchant cross-tenant RLS, anon denied, rate-limit tests
-- 3) Android and Merchant UI feature flags enabled for staging only
-- 4) assess Realtime publication, retention, block/report, attachments,
--    notification deep links and support moderation before Production.
