-- WYN-109a, part 1 of 2 -- the column only.
--
-- The combined migration failed on production:
--
--   ERROR: 42P16: cannot change name of view column "created_at"
--          to "author_is_verified"
--
-- `create or replace view` only permits *appending* columns; production's
-- public.home_feed has a different column list from this repo's
-- schema.sql, so redefining it from the repo's text is rejected. The
-- rehearsal did not catch that because it loaded schema.sql -- the
-- repo's idea of the view, not production's.
--
-- Nothing was applied by that failure: the file is one transaction, and
-- the error rolled all of it back.
--
-- This file is the half that has no such dependency. It adds the column
-- to `drops` and nothing else -- no view is touched, so production's
-- own shape is irrelevant to it.
--
-- WHAT WORKS AFTER THIS RUNS, AND WHAT DOES NOT
--   * Posting photos at a chosen ratio: works. The ratio is written to
--     `drops` and read back by post detail, profile and hashtag feeds,
--     which query the table directly.
--   * The Home feed: still draws every post at 4:5, because it reads
--     public.home_feed and that view does not carry the column yet.
--     Not a failure -- the client falls back to 4:5 when the key is
--     absent, exactly as it does for a pre-WYN-109 post.
--   * Part 2 adds the column to the view, and will be written against
--     production's real definition rather than this repo's.
--
-- SAFETY: additive only. One nullable column plus a CHECK that admits
-- NULL. Nothing dropped, retyped or backfilled. Re-runnable.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

alter table public.drops
  add column if not exists image_aspect_ratio text;

comment on column public.drops.image_aspect_ratio is
  'WYN-109: the aspect ratio the poster chose for this Drop''s photos, '
  'applied to all of them. NULL = posted before WYN-109; the client '
  'renders those at 4:5, which is what they were cropped to anyway.';

alter table public.drops
  drop constraint if exists drops_image_aspect_ratio_valid;

alter table public.drops
  add constraint drops_image_aspect_ratio_valid
  check (
    image_aspect_ratio is null
    or image_aspect_ratio in ('original', '1:1', '4:5', '16:9')
  );

commit;

-- VERIFY (run separately)
--
--   select column_name, data_type, is_nullable
--   from information_schema.columns
--   where table_schema = 'public'
--     and table_name = 'drops'
--     and column_name = 'image_aspect_ratio';
--
-- and that no existing post was touched -- untouched must equal total:
--
--   select count(*) filter (where image_aspect_ratio is null) as untouched,
--          count(*) as total
--   from public.drops;

-- ---------------------------------------------------------------------
-- VALIDATED 2026-09-04 against a scratch PostgreSQL 16.13 built to
-- reproduce the failure rather than to avoid it: this repo's schema.sql
-- as it stood before WYN-109, then public.home_feed deliberately
-- replaced with a *different* column list, standing in for the drift
-- production actually has. An existing Drop was seeded first.
--
--   * the combined migration fails on that database, with the same
--     42P16 "cannot change name of view column" production reported
--   * and leaves nothing behind: the column count is still 0 after it,
--     confirming the whole file rolls back
--   * this file applies clean on the same database        exit 0
--   * applying it a second time is a no-op                exit 0
--   * the seeded Drop is untouched      image_aspect_ratio NULL,
--                                       caption intact
--   * public.home_feed is not touched   still its own 7 columns
--   * the CHECK rejects '3:7' and accepts '16:9'
--
-- The first rehearsal missed this because it loaded schema.sql -- the
-- repo's idea of the view. A rehearsal that only proves a migration
-- works against the schema you wrote it from proves very little.
