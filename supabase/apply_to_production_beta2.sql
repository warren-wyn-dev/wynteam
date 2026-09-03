-- =====================================================================
-- WYNOS v1.0.0 Beta2 — the ONLY statements to run against PRODUCTION
--
-- Paste this whole file into the Supabase SQL Editor and run it once.
-- Every statement is idempotent, so running it twice is harmless.
--
-- ---------------------------------------------------------------------
-- ⚠️ WHAT IS DELIBERATELY *NOT* IN THIS FILE
--
-- 1. SCHEMA-002 (the two `drop view if exists public.home_feed;` lines
--    added to schema.sql). Those exist ONLY to let schema.sql load
--    top-to-bottom into an EMPTY database -- each one is immediately
--    followed by a `create or replace view public.home_feed ...` that
--    rebuilds it.
--
--    Running those two lines on their own against production would DROP
--    THE home_feed VIEW AND NOT RECREATE IT, taking down Home, Search,
--    Saved, Profile feeds and the ranked feed RPC. Production already
--    has the correct final view. There is nothing to apply.
--
-- 2. supabase/pending_approval_rls_with_check.sql — NOT APPROVED for
--    Beta2 (Founder decision 2026-09-03). Do not run it.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- PART 1 of 2 — Indexes (9). Additive only: no table, column, policy or
-- data is touched, and no query changes what it returns -- only how
-- Postgres finds the rows. Verbatim copy of
-- supabase/migrations_beta2_indexes.sql.
--
-- On a large table `create index concurrently` avoids holding a write
-- lock, but cannot run inside a transaction block -- so it must be run
-- one statement at a time rather than as part of this file. At Beta2's
-- data volume the plain form below takes a fraction of a second.
-- ---------------------------------------------------------------------

-- 1. Home feed ordering: `order by created_at desc`, every tab, every page.
create index if not exists drops_created_at_idx
  on public.drops (created_at desc);

-- 2. Profile grid / post count, and the Following feed's author filter.
create index if not exists drops_author_created_idx
  on public.drops (author_id, created_at desc);

-- 3. Profile's "ถูกใจ" tab -- fetch_liked_drop_ids() reads user-first,
--    which the (drop_id, user_id) primary key cannot serve.
create index if not exists drop_likes_user_idx
  on public.drop_likes (user_id, created_at desc);

-- 4. Every comment list, plus the comment_count and top_reply subqueries
--    inside home_feed, which run once per feed row.
create index if not exists drop_comments_drop_created_idx
  on public.drop_comments (drop_id, created_at);

-- 5. Follower lists and follower_count() -- the PK only serves the
--    "who do I follow" direction.
create index if not exists follows_following_idx
  on public.follows (following_id, created_at desc);

-- 6. Incoming follow requests and their badge count.
create index if not exists follow_requests_target_idx
  on public.follow_requests (target_id, created_at desc);

-- 7. content_save_count() filters on content_id alone, while the PK
--    leads with user_id -- a full scan of saves on every call.
create index if not exists saves_content_idx
  on public.saves (content_id);

-- 8. A Club's post list. club_posts had no index beyond its own id;
--    column order matches the query's sort exactly.
create index if not exists club_posts_club_pinned_created_idx
  on public.club_posts (club_id, pinned desc, created_at desc);

-- 9. A Club post's comment list -- the Club-side counterpart of 4.
create index if not exists club_post_comments_post_created_idx
  on public.club_post_comments (club_post_id, created_at);

-- ---------------------------------------------------------------------
-- PART 2 of 2 — SCHEMA-003: drop the two obsolete create_poll_drop
-- overloads.
--
-- `create or replace function` only replaces a function with the SAME
-- signature. WYN-097 and WYN-098 each grew the parameter list, so each
-- created a new function instead of replacing the old one -- production
-- currently carries all three, every one SECURITY DEFINER and callable
-- by any authenticated user.
--
-- Safe: the app is the only caller in the repository and passes all ten
-- named parameters, matching the surviving overload exactly. The two
-- below are unreachable from the app and skip the audience (WYN-097)
-- and location (WYN-098) handling the current one performs.
-- ---------------------------------------------------------------------

drop function if exists public.create_poll_drop(text, text[], int, uuid[]);
drop function if exists public.create_poll_drop(text, text[], int, uuid[], text, uuid[]);

-- ---------------------------------------------------------------------
-- VERIFY -- run these three after the above and check each result.
-- ---------------------------------------------------------------------

-- (a) must return exactly 9 rows
select tablename, indexname from pg_indexes
where indexname in (
  'drops_created_at_idx','drops_author_created_idx','drop_likes_user_idx',
  'drop_comments_drop_created_idx','follows_following_idx',
  'follow_requests_target_idx','saves_content_idx',
  'club_posts_club_pinned_created_idx','club_post_comments_post_created_idx'
) order by tablename;

-- (b) must return exactly 1 row -- the ten-parameter overload
select p.oid::regprocedure as remaining_overload
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_poll_drop';

-- (c) must still return 6 rows. These are the UPDATE policies whose
--     WITH CHECK is left implicit -- PostgreSQL applies USING in its
--     place, which is why the "missing WITH CHECK" finding was wrong.
--     Fewer than 6 rows means the NOT-APPROVED migration was run by
--     mistake.
select tablename, policyname from pg_policies
where cmd = 'UPDATE' and with_check is null
  and (
    (schemaname = 'public' and tablename in
      ('profiles','profile_private','cart_items','clubs','club_posts'))
    or (schemaname = 'storage' and tablename = 'objects')
  )
order by 1;

-- (d) sanity check that home_feed is intact (must return 1 row).
select count(*) as home_feed_exists
from pg_views where schemaname = 'public' and viewname = 'home_feed';
