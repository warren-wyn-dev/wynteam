-- WYN-161: Wynii — one shared brand pet per 1:1 conversation.
-- Rule: after Wynii is started, both participants must send at least one
-- message within the same rolling 24-hour cycle. A successful cycle adds
-- exactly +1 age day. Successful cycles are rate-limited to at most one
-- completion per rolling 24 hours. Missing a cycle never decreases age.

create table if not exists public.conversation_wynii (
  conversation_id uuid primary key references public.conversations(id) on delete cascade,
  user_a_id uuid not null references public.profiles(id) on delete cascade,
  user_b_id uuid not null references public.profiles(id) on delete cascade,
  age_days integer not null default 0 check (age_days >= 0),
  cycle_started_at timestamptz,
  user_a_done boolean not null default false,
  user_b_done boolean not null default false,
  next_cycle_at timestamptz not null default now(),
  last_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_a_id < user_b_id),
  check (cycle_started_at is not null or (user_a_done = false and user_b_done = false))
);

comment on table public.conversation_wynii is
  'WYN-161 shared Wynii lifecycle state for one-to-one conversations.';

alter table public.conversation_wynii enable row level security;

revoke all on public.conversation_wynii from anon;
revoke insert, update, delete on public.conversation_wynii from authenticated;
grant select on public.conversation_wynii to authenticated;

drop policy if exists "Participants can view their Wynii" on public.conversation_wynii;
create policy "Participants can view their Wynii"
on public.conversation_wynii
for select
to authenticated
using (
  coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is false
  and (auth.uid() = user_a_id or auth.uid() = user_b_id)
  and internal.chat_pair_allowed(user_a_id, user_b_id)
);

create or replace function public.start_conversation_wynii(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_user_a uuid;
  v_user_b uuid;
  v_status text;
  v_is_anonymous boolean := coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
begin
  if v_uid is null or v_is_anonymous then
    raise exception 'authentication required';
  end if;

  select c.user_a_id, c.user_b_id, c.status
    into v_user_a, v_user_b, v_status
  from public.conversations c
  where c.id = p_conversation_id;

  if not found then
    raise exception 'conversation not found';
  end if;

  if v_uid <> v_user_a and v_uid <> v_user_b then
    raise exception 'not a conversation participant';
  end if;

  if v_status <> 'active' then
    raise exception 'conversation must be active';
  end if;

  if not internal.chat_pair_allowed(v_user_a, v_user_b) then
    raise exception 'conversation unavailable';
  end if;

  insert into public.conversation_wynii (
    conversation_id,
    user_a_id,
    user_b_id,
    age_days,
    next_cycle_at
  ) values (
    p_conversation_id,
    v_user_a,
    v_user_b,
    0,
    clock_timestamp()
  )
  on conflict (conversation_id) do nothing;
end;
$$;

revoke execute on function public.start_conversation_wynii(uuid) from public, anon;
grant execute on function public.start_conversation_wynii(uuid) to authenticated;

create or replace function public.advance_conversation_wynii()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pet public.conversation_wynii%rowtype;
  v_now timestamptz := clock_timestamp();
  v_a_done boolean;
  v_b_done boolean;
begin
  select *
    into v_pet
  from public.conversation_wynii
  where conversation_id = new.conversation_id
  for update;

  if not found then
    return new;
  end if;

  if new.sender_id <> v_pet.user_a_id and new.sender_id <> v_pet.user_b_id then
    return new;
  end if;

  -- A completed cycle locks the next possible +1 for a full rolling 24h.
  if v_now < v_pet.next_cycle_at then
    return new;
  end if;

  -- No active cycle, or the previous one expired: this message starts a
  -- fresh 24-hour window. The missed window never reduces age.
  if v_pet.cycle_started_at is null
     or v_now > v_pet.cycle_started_at + interval '24 hours' then
    update public.conversation_wynii
       set cycle_started_at = v_now,
           user_a_done = (new.sender_id = v_pet.user_a_id),
           user_b_done = (new.sender_id = v_pet.user_b_id),
           updated_at = v_now
     where conversation_id = new.conversation_id;
    return new;
  end if;

  v_a_done := v_pet.user_a_done or new.sender_id = v_pet.user_a_id;
  v_b_done := v_pet.user_b_done or new.sender_id = v_pet.user_b_id;

  if v_a_done and v_b_done then
    update public.conversation_wynii
       set age_days = age_days + 1,
           cycle_started_at = null,
           user_a_done = false,
           user_b_done = false,
           next_cycle_at = v_now + interval '24 hours',
           last_completed_at = v_now,
           updated_at = v_now
     where conversation_id = new.conversation_id;
  else
    update public.conversation_wynii
       set user_a_done = v_a_done,
           user_b_done = v_b_done,
           updated_at = v_now
     where conversation_id = new.conversation_id;
  end if;

  return new;
end;
$$;

-- Trigger-only helper. It must not be callable as an exposed RPC.
revoke execute on function public.advance_conversation_wynii() from public, anon, authenticated;

drop trigger if exists messages_advance_conversation_wynii on public.messages;
create trigger messages_advance_conversation_wynii
after insert on public.messages
for each row
execute function public.advance_conversation_wynii();

create index if not exists conversation_wynii_participants_idx
  on public.conversation_wynii (user_a_id, user_b_id);
