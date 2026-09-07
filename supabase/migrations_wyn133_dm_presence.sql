-- WYN-133: DM Presence -- Typing Indicator + Online/Last Seen
--
-- Adds `public.user_presence` (deliberately a table separate from
-- `profiles` -- that table's own SELECT policy is `using (true)`, so a
-- `last_seen_at`/`show_online_status` column living there directly
-- would leak with no reciprocal check at all) + `touch_my_presence()`/
-- `get_conversation_partner_presence()` RPCs. The Typing Indicator and
-- live Online status themselves are Supabase Realtime Presence
-- channels, not part of this migration at all -- see
-- .wyn/docs/design/wyn-133-dm-presence-typing-online.md's own
-- "Presence Channel Design" section.
--
-- See .wyn/tasks/active/WYN-133-dm-presence-typing-online.md for the
-- full spec.
--
-- SAFETY: purely additive -- 1 brand new table, 2 new RPCs, no existing
-- table/column touched. Re-runnable throughout (`if not exists`/
-- `or replace`).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

-- Deliberately a table separate from `profiles` -- that table's own
-- SELECT policy is `using (true)` (every authenticated user can read
-- every column of every row), so a `last_seen_at`/`show_online_status`
-- column living there directly would leak with no reciprocal check at
-- all. Mirrors `notification_settings`'s own shape: a table with a
-- strict "your own row only" SELECT policy, read-others only via a
-- SECURITY DEFINER RPC that enforces the real rule server-side.

create table if not exists public.user_presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  show_online_status boolean not null default true,
  last_seen_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_presence enable row level security;

drop policy if exists "Users can view their own presence row" on public.user_presence;
create policy "Users can view their own presence row"
  on public.user_presence
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own presence row" on public.user_presence;
create policy "Users can insert their own presence row"
  on public.user_presence
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own presence row" on public.user_presence;
create policy "Users can update their own presence row"
  on public.user_presence
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- touch_my_presence(): persists this user's own last_seen_at -- called
-- on AppLifecycleState.paused/detached (best-effort, same posture as
-- every other lifecycle hook in this app -- a killed-outright app
-- misses this call, an accepted known limitation).
create or replace function public.touch_my_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_presence (user_id, last_seen_at)
  values (auth.uid(), now())
  on conflict (user_id) do update
    set last_seen_at = excluded.last_seen_at, updated_at = now();
end;
$$;

grant execute on function public.touch_my_presence() to authenticated;

-- get_conversation_partner_presence(): the one place a client can read
-- another user's presence -- enforces the reciprocal privacy check
-- (Requirement, WhatsApp-standard: turning your own visibility off also
-- hides everyone else's from you) in the same statement, so there is
-- exactly one place this rule can ever be wrong.
create or replace function public.get_conversation_partner_presence(p_conversation_id uuid)
returns table (show_online boolean, last_seen_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_other uuid;
  v_my_show boolean;
  v_other_show boolean;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  select case when user_a_id = v_me then user_b_id
              when user_b_id = v_me then user_a_id end
  into v_other
  from public.conversations
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if v_other is null then
    raise exception 'Conversation not found, or you are not a participant';
  end if;

  select coalesce(up.show_online_status, true) into v_my_show
  from public.user_presence up where up.user_id = v_me;
  select coalesce(up.show_online_status, true) into v_other_show
  from public.user_presence up where up.user_id = v_other;

  if coalesce(v_my_show, true) = false or coalesce(v_other_show, true) = false then
    return query select false, null::timestamptz;
    return;
  end if;

  -- Coding-time fix vs. the design doc's literal SQL (a `from
  -- user_presence where user_id = v_other` here returns *zero* rows,
  -- not a row with a null last_seen_at, for a partner who has never had
  -- a user_presence row written at all yet -- e.g. a brand new account
  -- that has been online continuously since signup and never once
  -- backgrounded the app to trigger touch_my_presence()). The design
  -- doc's own Edge Cases section explicitly expects a returned row with
  -- last_seen_at = null in that case ("last_seen_at เป็น null จริง"), not
  -- an empty result -- a scalar subquery guarantees exactly one row is
  -- always returned once reciprocal-check has passed, with last_seen_at
  -- naturally null when no row exists yet.
  return query
    select true, (select up.last_seen_at from public.user_presence up where up.user_id = v_other);
end;
$$;

grant execute on function public.get_conversation_partner_presence(uuid) to authenticated;

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.user_presence; -- expect 0 rows right after apply
