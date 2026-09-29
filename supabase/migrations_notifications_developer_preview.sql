-- Notifications Developer Preview (2026-09-29)
-- Additive only: regular accounts keep the existing notification behavior.
-- Advanced Push preferences and Realtime are consumed only by allowlisted
-- developer accounts in the web/Edge code.

alter table public.notification_settings
  add column if not exists push_likes boolean not null default true,
  add column if not exists push_comments boolean not null default true,
  add column if not exists push_follows boolean not null default true,
  add column if not exists push_messages boolean not null default true,
  add column if not exists push_club boolean not null default true,
  add column if not exists push_trending boolean not null default true,
  add column if not exists push_system boolean not null default true,
  add column if not exists push_quiet_enabled boolean not null default false,
  add column if not exists push_quiet_start time without time zone not null default '22:00',
  add column if not exists push_quiet_end time without time zone not null default '08:00',
  add column if not exists push_timezone text not null default 'UTC';

create table if not exists public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  device_token_id uuid,
  platform text,
  channel text not null default 'push' check (channel in ('push')),
  status text not null check (status in ('sent', 'failed', 'retrying', 'skipped')),
  attempt smallint not null default 1 check (attempt between 0 and 10),
  http_status integer,
  provider_status text,
  detail text,
  created_at timestamptz not null default now()
);

create index if not exists notification_delivery_attempts_notification_idx
  on public.notification_delivery_attempts(notification_id, created_at desc);
create index if not exists notification_delivery_attempts_recipient_idx
  on public.notification_delivery_attempts(recipient_id, created_at desc);

alter table public.notification_delivery_attempts enable row level security;
revoke all on table public.notification_delivery_attempts from anon, authenticated;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select, insert on table public.notification_delivery_attempts to service_role;
  end if;
end
$$;

-- Realtime publication is safe to enable globally because RLS still scopes rows.
-- The Web client attaches this channel only after is_developer_account() returns true.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;
