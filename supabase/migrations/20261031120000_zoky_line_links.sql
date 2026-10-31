-- ZOKY-LINE-001: link a ZOKY account to LINE for LINE OA notifications.
--
-- Founder approval (2026-10-31, .wyn/tasks/approved/ZOKY-LINE-001-line-oa-notifications-liff.md):
--   * LINE OA is an additional notification channel for ZOKY customers
--     (audience 'food') and stores (audience 'merchant'); Web Push is unchanged.
--   * Two OAs: one per audience, so each audience has its own friend state.
--
-- Additive only. Rows are written exclusively by the line-link and
-- line-webhook Edge Functions with the service role, after the LINE ID token
-- (link) or the X-Line-Signature (follow/unfollow) has been verified server
-- side. Signed-in users may only read and delete their own rows.
--
-- Test: supabase/tests/zoky_line_links_test.sh
-- Rollback: supabase/rollbacks/20261031120000_zoky_line_links_rollback.sql

create table if not exists public.line_links (
  user_id uuid not null references auth.users(id) on delete cascade,
  audience text not null check (audience in ('food', 'merchant')),
  -- LINE userId for the provider that owns both OAs: U + 32 hex chars.
  line_user_id text not null check (line_user_id ~ '^U[0-9a-f]{32}$'),
  friend_status text not null default 'unknown'
    check (friend_status in ('unknown', 'friend', 'not_friend')),
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, audience),
  -- One LINE account receives one ZOKY account's messages per OA.
  unique (audience, line_user_id)
);

comment on table public.line_links is
  'ZOKY-LINE-001: ZOKY account <-> LINE userId per OA. Written only by Edge Functions (service role).';

alter table public.line_links enable row level security;

revoke all on table public.line_links from anon, authenticated;
grant select (audience, friend_status, linked_at, updated_at), delete
  on table public.line_links to authenticated;

drop policy if exists line_links_select_own on public.line_links;
create policy line_links_select_own on public.line_links
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists line_links_delete_own on public.line_links;
create policy line_links_delete_own on public.line_links
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- No insert/update policy: clients can never create or retarget a link.
