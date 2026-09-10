-- WYN-141 — Founder final UI: profile cover metadata.
-- The existing public `avatars` bucket is reused; no storage policy changes.

begin;

alter table public.profiles
  add column if not exists cover_url text;

commit;
