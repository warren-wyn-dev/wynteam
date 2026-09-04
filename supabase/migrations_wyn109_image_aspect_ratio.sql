-- =====================================================================
-- DO NOT RUN THIS FILE. Superseded 2026-09-04.
--
-- It failed on production:
--   ERROR: 42P16: cannot change name of view column "created_at"
--          to "author_is_verified"
--
-- `create or replace view` only permits appending columns, and
-- production's public.home_feed has a different column list from the
-- one this file was written from (this repo's schema.sql). Nothing
-- was applied -- the file is one transaction and the error rolled all
-- of it back, confirmed by reproducing it on a scratch database.
--
-- Split in two:
--   Part 1, ready now: migrations_wyn109a_column_only.sql
--                      (the column; touches no view, so production's
--                      own shape cannot matter to it)
--   Part 2, pending:   the view, to be written against production's
--                      real definition once it is known -- not
--                      against this repo's.
-- =====================================================================

-- WYN-109 -- per-post photo aspect ratio.
--
-- Founder approved this column on 2026-09-04 ("อนุมัติเพิ่มคอลัมน์"), see
-- .wyn/company/APPROVALS.md. Design spec:
-- .wyn/docs/design/wyn-109-post-image-aspect-ratio.md
--
-- WHY THIS COLUMN EXISTS
-- Every photo posted through the app is center-cropped to a square on
-- upload, and the feed's card row then crops that square again to 4:5,
-- because `postCardAspectRatio` is a compile-time constant. The poster
-- controls neither crop. WYN-109 lets them choose the ratio instead --
-- but a choice the feed cannot read is not a choice, so the ratio has
-- to live on the post.
--
-- SAFETY
-- Additive only: one nullable column plus a CHECK that admits NULL.
-- Nothing is dropped, retyped, or backfilled. Every existing Drop stays
-- NULL and keeps rendering exactly as it does today (the client falls
-- back to 4:5 for NULL), so this file is a no-op for live content until
-- the app starts writing the column.
--
-- Re-runnable: every statement is `if not exists` / `drop ... if exists`
-- first, so applying it twice is harmless.
--
-- HOW TO APPLY
-- Run in the Supabase Dashboard SQL Editor. Per this project's standing
-- rule, no AI applies production SQL -- the Founder runs it.

begin;

-- 1. The column ------------------------------------------------------
-- Text rather than a number: 'original' is a real choice ("keep what
-- the camera gave me", rendered from the image_width/image_height this
-- table already carries) and has no single numeric value. The client
-- maps the other three to their ratios.
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

-- 2. Expose it on the feed view --------------------------------------
-- Appended after `image_count`, the current last column: `create or
-- replace view` accepts new columns only at the end of the select list,
-- so this needs no `drop view` (and must not get one -- SCHEMA-002 in
-- APPROVALS.md is about exactly that hazard).
--
-- The `pops` branch has no Drop to read from and selects NULL, the same
-- shape its image_width/image_height already use.
create or replace view public.home_feed
  with (security_invoker = true) as
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  d.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by dl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.drop_likes
      where drop_id = d.id
      order by created_at desc
      limit 3
    ) dl
    join public.profiles lp on lp.id = dl.user_id
  ) as liked_by,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.drop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.drop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.drop_id = d.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::boolean as redropper_is_verified,
  null::text as quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at,
  d.image_width,
  d.image_height,
  d.audience,
  d.location,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count,
  d.image_aspect_ratio
from public.drops d
join public.profiles prof on prof.id = d.author_id
left join public.drop_polls dp on dp.drop_id = d.id
where not exists (
  select 1 from public.mutes where muter_id = auth.uid() and muted_id = d.author_id
)
union all
select
  p.id,
  'pop'::text as content_type,
  p.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  p.created_at,
  p.caption,
  null::text as image_url,
  p.video_url,
  p.thumbnail_url,
  p.duration_seconds,
  p.view_count,
  (select count(*) from public.pop_likes where pop_id = p.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by pl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.pop_likes
      where pop_id = p.id
      order by created_at desc
      limit 3
    ) pl
    join public.profiles lp on lp.id = pl.user_id
  ) as liked_by,
  (select count(*) from public.pop_comments where pop_id = p.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.pop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.pop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.pop_id = p.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  null::bigint as redrop_count,
  null::uuid as redrop_id,
  null::uuid as redropper_id,
  null::text as redropper_username,
  null::text as redropper_display_name,
  null::text as redropper_avatar_url,
  null::boolean as redropper_is_verified,
  null::text as quote_text,
  null::uuid as poll_id,
  null::text[] as poll_options,
  null::timestamptz as poll_expires_at,
  null::integer as image_width,
  null::integer as image_height,
  'everyone'::text as audience,
  null::text as location,
  null::bigint as image_count,
  null::text as image_aspect_ratio
from public.pops p
join public.profiles prof on prof.id = p.author_id
where not exists (
  select 1 from public.mutes where muter_id = auth.uid() and muted_id = p.author_id
)
union all
select
  d.id,
  'drop'::text as content_type,
  d.author_id,
  prof.username as author_username,
  prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  prof.is_verified as author_is_verified,
  r.created_at,
  d.caption,
  d.image_url,
  null::text as video_url,
  null::text as thumbnail_url,
  null::integer as duration_seconds,
  public.drop_view_count(d.id) as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', lp.id,
      'username', lp.username,
      'display_name', lp.display_name,
      'avatar_url', lp.avatar_url
    ) order by dl.created_at desc), '[]'::jsonb)
    from (
      select user_id, created_at from public.drop_likes
      where drop_id = d.id
      order by created_at desc
      limit 3
    ) dl
    join public.profiles lp on lp.id = dl.user_id
  ) as liked_by,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (
    select jsonb_build_object(
      'author_username', tr.author_username,
      'author_display_name', tr.author_display_name,
      'text', tr.text_content
    )
    from (
      select
        c.text_content,
        cp.username as author_username,
        cp.display_name as author_display_name,
        c.created_at,
        (select count(*) from public.drop_comment_likes dcl where dcl.comment_id = c.id) as like_count
      from public.drop_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.drop_id = d.id and c.parent_comment_id is null
    ) tr
    where tr.like_count > 0
    order by tr.like_count desc, tr.created_at desc
    limit 1
  ) as top_reply,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id,
  r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  redropper.is_verified as redropper_is_verified,
  r.quote_text,
  dp.id as poll_id,
  dp.options as poll_options,
  dp.expires_at as poll_expires_at,
  d.image_width,
  d.image_height,
  d.audience,
  d.location,
  (select count(*) from public.drop_images where drop_id = d.id) as image_count,
  d.image_aspect_ratio
from public.redrops r
join public.drops d on d.id = r.drop_id
join public.profiles prof on prof.id = d.author_id
join public.profiles redropper on redropper.id = r.redropper_id
left join public.drop_polls dp on dp.drop_id = d.id
where not exists (
  select 1 from public.mutes
  where muter_id = auth.uid() and muted_id in (d.author_id, r.redropper_id)
);

commit;

-- VERIFY (run separately, expects one row each)
--
--   select column_name, data_type, is_nullable
--   from information_schema.columns
--   where table_schema = 'public'
--     and table_name = 'drops'
--     and column_name = 'image_aspect_ratio';
--
--   select column_name
--   from information_schema.columns
--   where table_schema = 'public'
--     and table_name = 'home_feed'
--     and column_name = 'image_aspect_ratio';
--
-- And that existing content is untouched -- every pre-WYN-109 Drop is
-- NULL, none were rewritten:
--
--   select count(*) filter (where image_aspect_ratio is null) as untouched,
--          count(*) as total
--   from public.drops;

-- ---------------------------------------------------------------------
-- VALIDATED 2026-09-04 against a scratch PostgreSQL 16.13, loaded from
-- this repo's own schema.sql as it stood *before* this change (i.e. a
-- stand-in for production), with an existing Drop seeded first:
--
--   * migration applies clean                       exit 0
--   * applying it a second time is a no-op          exit 0
--   * the seeded pre-WYN-109 Drop is untouched      image_aspect_ratio
--                                                   NULL, caption intact
--   * public.home_feed exposes the new column
--   * the CHECK rejects '3:7' and accepts '4:5'
--
-- This is a rehearsal, not the real thing: production still has to run
-- it, and the Beta2 incident (a CHECK that collided with existing rows
-- because the rehearsal had not seeded data that violated it) is why the
-- seeded-row step above is part of the test rather than an afterthought.
-- Here every existing row is NULL, which the constraint admits by
-- design, so there is no equivalent collision to hit.
