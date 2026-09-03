-- WYNOS Beta2 audit (2026-09-03) -- database indexes.
--
-- READY TO APPLY. Additive only: creates nine indexes, changes no
-- table, column, constraint, policy or data. Every statement is
-- `if not exists`, so re-running it is a no-op. Nothing here alters
-- what any query returns -- only how Postgres finds the rows.
--
-- To roll back, drop the nine indexes by name; no data is affected.
--
-- This file is a verbatim copy of the block at the end of
-- supabase/schema.sql, which remains the source of truth. It exists
-- separately so it can be pasted into the Supabase SQL Editor on its
-- own, without re-running the whole schema.

-- 1. The Home feed's own ordering: `order by created_at desc` on
--    home_feed, every tab, every page.
create index if not exists drops_created_at_idx
  on public.drops (created_at desc);

-- 2. Profile's post grid and count (fetchByAuthor / countByAuthor:
--    `author_id = ? order by created_at desc`), and the Following
--    feed's `author_id in (...)`.
create index if not exists drops_author_created_idx
  on public.drops (author_id, created_at desc);

-- 3. Profile's "ถูกใจ" tab -- fetch_liked_drop_ids() runs
--    `user_id = ? order by created_at desc offset ? limit 21`. The PK
--    is (drop_id, user_id), so a user-first read could use neither the
--    filter nor the sort; this serves both.
create index if not exists drop_likes_user_idx
  on public.drop_likes (user_id, created_at desc);

-- 4. Every comment list (`drop_id = ? order by created_at`), plus the
--    comment_count and top_reply subqueries inside home_feed itself,
--    which run per feed row.
create index if not exists drop_comments_drop_created_idx
  on public.drop_comments (drop_id, created_at);

-- 5. Follower lists and follower_count() (`following_id = ? order by
--    created_at desc`), plus the suggested-users ranking's
--    `count(*) where following_id = p.id`. The PK is
--    (follower_id, following_id) -- only the "who do I follow"
--    direction.
create index if not exists follows_following_idx
  on public.follows (following_id, created_at desc);

-- 6. The incoming follow-request list and its badge count
--    (`target_id = ? order by created_at desc`), and the trigger that
--    clears requests when an account goes public. Same PK-direction
--    problem: the PK is (requester_id, target_id).
create index if not exists follow_requests_target_idx
  on public.follow_requests (target_id, created_at desc);

-- 7. content_save_count() is `count(*) from saves where content_id = ?`
--    with no user_id at all -- a full scan of saves on every call,
--    since the PK leads with user_id. Indexed on content_id alone:
--    an earlier draft used (content_type, content_id), whose leading
--    column has about three distinct values and so would not have
--    served this lookup well.
create index if not exists saves_content_idx
  on public.saves (content_id);

-- 8. A Club's post list -- `club_id = ? order by pinned desc,
--    created_at desc`. club_posts had no index of any kind beyond its
--    own id. Column order matches the query's sort exactly.
create index if not exists club_posts_club_pinned_created_idx
  on public.club_posts (club_id, pinned desc, created_at desc);

-- 9. A Club post's comment list (`club_post_id = ? order by
--    created_at`) -- the Club-side counterpart of index 4.
create index if not exists club_post_comments_post_created_idx
  on public.club_post_comments (club_post_id, created_at);
