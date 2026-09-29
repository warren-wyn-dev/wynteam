-- Notifications Developer Preview — 2026-09-29
-- Additive rollout: advanced Push controls and Realtime are consumed only by
-- allowlisted developer accounts in the web client / Edge Function.

alter table public.notification_settings
  add column if not exists push_likes boolean not null default true,
  add column if not exists push_comments boolean not null default true,
  add column if not exists push_follows boolean not null default true,
  add column if not exists push_messages boolean not null default true,
  add column if not exists push_club boolean not null default true,
  add column if not exists push_trending boolean not null default true,
  add column if not exists push_system boolean not null default true,
  add column if not exists push_quiet_enabled boolean not null default false,
  add column if not exists push_quiet_start time not null default '22:00',
  add column if not exists push_quiet_end time not null default '08:00',
  add column if not exists push_timezone text not null default 'UTC';

-- Restore the notification tables' original owner-only RLS contract. These
-- production-drift policies were broader than the source-of-truth policies.
drop policy if exists wyn157_permanent_insert on public.developer_accounts;
drop policy if exists wyn157_permanent_update on public.developer_accounts;
drop policy if exists wyn157_permanent_delete on public.developer_accounts;
drop policy if exists wyn157_permanent_insert on public.notification_settings;
drop policy if exists wyn157_permanent_update on public.notification_settings;
drop policy if exists wyn157_permanent_delete on public.notification_settings;
drop policy if exists wyn157_permanent_insert on public.notifications;
drop policy if exists wyn157_permanent_update on public.notifications;
drop policy if exists wyn157_permanent_delete on public.notifications;
drop policy if exists wyn157_permanent_insert on public.push_tokens;
drop policy if exists wyn157_permanent_update on public.push_tokens;
drop policy if exists wyn157_permanent_delete on public.push_tokens;

-- The allowlist is intentionally RPC-only. is_developer_account() is
-- SECURITY DEFINER, so removing direct table grants does not affect the gate.
revoke all on table public.developer_accounts from anon, authenticated;

create table if not exists public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  token_id uuid references public.push_tokens(id) on delete set null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  status text not null check (status in ('pending', 'retrying', 'sent', 'failed', 'skipped')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  next_retry_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_push_deliveries_notification_token_key unique (notification_id, token_id)
);

create index if not exists notification_push_deliveries_user_created_idx
  on public.notification_push_deliveries(user_id, created_at desc);
create index if not exists notification_push_deliveries_retry_idx
  on public.notification_push_deliveries(status, next_retry_at)
  where status = 'retrying';

alter table public.notification_push_deliveries enable row level security;
revoke all on table public.notification_push_deliveries from anon, authenticated;
grant select, insert, update, delete on table public.notification_push_deliveries to service_role;

-- Postgres Changes requires explicit publication membership. The client still
-- attaches this channel only after is_developer_account() resolves true.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end
$$;
