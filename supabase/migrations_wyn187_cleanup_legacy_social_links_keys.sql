-- Follow-up to migrations_wyn187_profile_external_link_validation.sql
-- (applied to production earlier today, see
-- .wyn/logs/deployments/2026-09-21-wyn-185-wynos-web-beta1-fixes-deploy.md).
--
-- Bug: that migration's trigger (profiles_validate_social_links) only
-- allows the keys website/instagram/twitter/youtube in `social_links`, and
-- raises on any other key. It validates the FULL resulting row on every
-- UPDATE (Postgres populates NEW with the whole row, not just the changed
-- columns), so a profile whose `social_links` already contains a
-- non-conforming key from before the trigger existed now fails on EVERY
-- update to that row -- not just ones that touch social_links. Confirmed
-- live: a profile with social_links containing `__wynos_note` got
-- "social_links has an unrecognized key: __wynos_note" trying to save an
-- unrelated Privacy setting (dm_permission/comment_permission/is_private),
-- because the trigger re-validates the untouched social_links value on
-- every save regardless.
--
-- Fix: one-time data cleanup, not a trigger/logic change. Strips any key
-- outside the allowlist from every existing `social_links` value so no
-- profile stays blocked. Going forward the trigger already prevents new
-- non-conforming keys from being written at all, so this shouldn't recur
-- unless another stray key slips in through some other write path.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it; no
-- AI applies production SQL (per AGENTS.md Change Control).
--
-- Safe to run more than once (idempotent -- a second run finds nothing left
-- to strip). Read-only diagnostic first if you want to see affected rows
-- before applying:
--
--   select id, username, social_links
--   from public.profiles
--   where exists (
--     select 1 from jsonb_object_keys(social_links) k(key)
--     where k.key <> all (array['website', 'instagram', 'twitter', 'youtube'])
--   );

update public.profiles
set social_links = (
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from jsonb_each(social_links) as entries(key, value)
  where key = any (array['website', 'instagram', 'twitter', 'youtube'])
)
where exists (
  select 1 from jsonb_object_keys(social_links) k(key)
  where k.key <> all (array['website', 'instagram', 'twitter', 'youtube'])
);
