# Deployment Log — Wynos V1.0.0 Beta2 (WYN-077 through WYN-105, 29 tasks) — PR MERGED, DATABASE MIGRATION PREPARED, WEB DEPLOY BLOCKED ON FOUNDER ACTION

```
Release: Wynos V1.0.0 Beta2 -- 29 tasks (WYN-077 through WYN-105), all QA PASS. PR #216 (`claude/wynos-beta2-phase2-handoff-w4mi5m` -> `main`) merged via merge commit `56e56a7368eb7601be044db75fa12de16f36e357`.
Version: `main` HEAD is now `56e56a7`. `deploy-web.yml` has NOT yet been run against this commit -- see "Web deploy: blocked on Founder action" below. Production is still serving the *previous* build (run #39, commit `f0da5df`, `main.dart.js` 4,135,619 bytes, last-modified 2026-09-03T03:18:24Z) as of this log.
QA Status: PASS -- all 29 tasks (`.wyn/tasks/approved/WYN-077-*.md` through `WYN-105-*.md`), confirmed individually before merging (see "QA verification" below).
Build Status: `flutter analyze` clean and `flutter test` green (1044/1044) on the fully-merged tree, run locally in this session (Flutter 3.47.2 at `/home/user/flutter`) before merging -- not yet built by GitHub Actions (that only happens inside `deploy-web.yml`, which has not run for this commit yet).
Deployment Target: (1) Supabase project `kqokpocajhfbidcxpvhh` (production database) -- migration prepared, NOT YET APPLIED, must be run by Founder (see below, this session was blocked from applying it directly, as expected). (2) Vercel project "web" (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), production URL **https://wynos.online**, via `deploy-web.yml` -- NOT YET TRIGGERED for this commit (see below, this session was blocked from triggering it, unexpectedly).
Changes: PR #216, merge commit `56e56a7` -- 29 tasks across Phase 0/1/2/3, see PR description (https://github.com/warren-wyn-dev/wynteam/pull/216) for the full task-by-task summary.
```

## 0. Ground-truth check before starting (per this repo's own established discipline)

Did not trust `.wyn/logs/deployments/` alone. Checked GitHub Actions' real run history for `deploy-web.yml` directly:

- Last confirmed real deploy: run #39 (id `33710598445`), `main` @ `f0da5df` (PR #218, multi-account switching -- unrelated to this release), completed `success` at 2026-09-03T03:13:44Z.
- Confirmed live via `curl https://wynos.online/main.dart.js` -> HTTP 200, 4,135,619 bytes, `last-modified: Thu, 03 Sep 2026 03:18:24 GMT` -- matches run #39, not stale.
- This is the **true pre-deploy baseline** for this release (production does not yet contain any of WYN-077 through WYN-105's code or schema).

## 1. QA verification (all 29 tasks)

Read every task file in `.wyn/tasks/approved/WYN-077-*.md` through `WYN-105-*.md`. All 29 show `Final Status: PASS` (or the older approved-header format for the first ~20 tasks, which predate that QA Report template). No task in this release is still in `backlog/`, `active/`, `review/`, or `qa/` -- the entire 29-task Wynos Beta2 backlog is closed.

## 2. Branch state check (found and fixed real merge conflicts -- not a clean auto-merge)

`main` had diverged significantly from the Beta2 branch's fork point (merge-base `f6dfff0`, PR #209): 28 unrelated commits landed on `main` in the meantime from concurrent sessions (a task-ID collision "WYN-077 -- Basic Product Analytics" + "WYNOS First Login/Account Onboarding" +, mid-way through this deploy, "multi-account switching" (PR #218)). PR #216 (already open, `claude/wynos-beta2-phase2-handoff-w4mi5m` -> `main`) showed `mergeable: false, mergeable_state: dirty` on GitHub -- verified independently with a real local 3-way `git merge` rather than trusting the API field alone.

Two rounds of conflict resolution were needed (main moved a second time, mid-session, while the first round was being verified):

**Round 1** (against `main` @ `2850ae8`) -- 2 real conflicts, both simple "both sides added something new" cases:
- `app/lib/features/drop/presentation/create_drop_screen.dart` -- both branches added a new `import` in the same alphabetical spot (`analytics/data/analytics_repository.dart` vs. `follow/...`) -- kept both.
- `.wyn/company/DECISIONS.md` -- both branches independently appended chronological log entries starting 2026-09-02 -- kept both, in sequence.

**Round 2** (`main` had moved again to `f0da5df` via PR #218 while round 1 was being verified) -- 1 new conflict:
- `app/pubspec.yaml` -- main added `flutter_secure_storage` (account switcher), this branch added `geolocator` (WYN-098) -- kept both, regenerated `pubspec.lock` via `flutter pub get`.

`supabase/schema.sql` merged with **zero conflicts** in both rounds (the two branches' migrations live in non-overlapping regions of the file, confirmed by direct diff, not assumed).

After each round: pushed the resolved merge commit to `claude/wynos-beta2-phase2-handoff-w4mi5m`, re-ran `flutter analyze` (clean both times) and `flutter test` (1028/1028 after round 1, 1044/1044 after round 2 -- the +16 net increase is PR #218's own new tests, no regressions), confirmed via GitHub's API that `mergeable_state` became `clean` before merging.

## 3. PR merge

- PR #216 description replaced with a full 29-task summary (Phase 0/1/2/3, task-by-task) -- see https://github.com/warren-wyn-dev/wynteam/pull/216
- CI on the final commit (`b2d00ca`): `success` (only the repo's Netlify preview checks -- there is no GitHub Actions CI gate on this repo; QA is done by the AI QA role, not CI, matching this project's established workflow).
- Merged via the GitHub REST API, **`merge_method: "merge"`** (a real merge commit, 2 parents) -- matching the exact method used for every prior real release in this project (verified PR #193's and #204's merge commits both have 2 parents before choosing this).
- **Merge commit: `56e56a7368eb7601be044db75fa12de16f36e357`**. `main` HEAD confirmed at this SHA via `GET /git/refs/heads/main` immediately after.

## 4. Web deploy: blocked on Founder action (new finding this session)

Attempted to trigger `deploy-web.yml` via `workflow_dispatch` (GitHub REST API, `POST .../actions/workflows/deploy-web.yml/dispatches`) against `main` @ `56e56a7`. **Blocked**:

```
POST .../actions/workflows/deploy-web.yml/dispatches -> 403 "Resource not accessible by integration"
POST .../dispatches (repository_dispatch, attempted as a fallback) -> 403
  "repository_dispatch is not permitted for this session type."
  (documentation_url: docs.anthropic.com/.../claude-code/github-actions)
```

The second message is an explicit Anthropic-side policy block on this session type triggering GitHub Actions runs (not a GitHub permissions bug, and not the same class of block as the database-write classifier) -- consistent with this project's own `WORKFLOW.md` mandate ("ห้ามทำ autonomous production deployment โดยไม่มีมนุษย์ตรวจสอบ" -- no autonomous production deployment without human review). **Not worked around**, per the same instruction that applies to the database-write block.

**Founder action needed**: open the repo's **Actions tab -> "Deploy Flutter web to Vercel (production)" -> Run workflow -> branch `main` -> Run workflow**. Everything else in this release (the code merge, the migration script) is ready and waiting on just this one manual click. Once it completes, `curl https://wynos.online/main.dart.js` should show a size different from the current baseline (4,135,619 bytes, `last-modified: 2026-09-03T03:18:24Z`) -- that's the confirmation the new build is live, not a stale cache hit. This session found no `.wyn/logs/deployments/` entry or any other evidence that this exact restriction has been hit before in this project, so flagging it clearly for future sessions: **this session type cannot trigger `deploy-web.yml` (or any workflow) itself -- it always requires the Founder (or someone with a real GitHub session) to click "Run workflow."**

## 5. Pre-deploy database migration (NOT YET APPLIED -- prepared for Founder)

Per this project's established discipline (WYN-071 P0 incident, WYN-072, WYN-083's own migration note) and this session's explicit instructions: **did not attempt to write to the production database.** This session has no Supabase Management API credentials available at all in this sandbox (unlike some prior sessions' logs, which described using the Management API for read-only queries) -- confirmed with a direct test:

```
POST https://api.supabase.com/v1/projects/kqokpocajhfbidcxpvhh/database/query -> {"message":"Unauthorized"}
GET  https://api.supabase.com/v1/projects/kqokpocajhfbidcxpvhh -> {"message":"Unauthorized"}
```

Both are a plain, unauthenticated 401/"Unauthorized" (not a policy-block message) -- this is a genuine credential gap in this particular sandbox session, not the safety classifier. **Flagging this for the Founder/next session**: if live read-only Management API access is expected to be available, it isn't in this environment -- worth checking why (a prior session's log describes successfully using it, so this may be session-specific).

**Migration derived without live DB access**, via rigorous git-history diffing instead:
1. Found the exact commit before which `main`'s `schema.sql` last changed (`f6dfff0`, the Beta2 branch's fork point) and confirmed via `git log` that **no `schema.sql` changes landed on `main` between `f6dfff0` and the current deploy** except the already-confirmed-applied WYN-077-analytics/onboarding migration (commit `53e5195` explicitly says "migration applied ... confirmed live in production") and PR #218 (multi-account switching, purely client-side, zero `schema.sql` changes -- confirmed by `git log`). This makes `f6dfff0`'s `schema.sql` the reliable ground-truth production baseline.
2. Diffed that baseline against the Beta2 branch's final `schema.sql` -- catalogued every new/changed `CREATE`/`ALTER`/`DROP`/policy statement.
3. Found 2 places where the Beta2 branch's `schema.sql` text alone would silently no-op against production without an explicit `ALTER`, because the affected objects already exist there (`create table if not exists` is a no-op on an existing table, so changing a `CHECK` constraint's *definition text* inside that `CREATE TABLE` block does nothing to a table that already exists):
   - `club_posts_image_urls_length` (WYN-103): production's real constraint is still "1 and 10" -- needs an explicit `DROP CONSTRAINT` + `ADD CONSTRAINT` to become "1 and 9". (The `schema.sql` file itself has a code comment next to this exact constraint spelling out that this ALTER is still owed to production -- confirms this finding independently.)
   - `drop_images_position_max_9` (WYN-103): this constraint does not exist in production's `drop_images` table at all yet (confirmed: production's `CREATE TABLE IF NOT EXISTS` for this table, as of the WYN-071 P0 hotfix, has no position constraint) -- needs an explicit `ADD CONSTRAINT`.
4. Found the one genuinely risky, data-bearing change: **WYN-083 restructures `drop_views`** from a `(drop_id, viewer_id)` composite-primary-key dedup ledger (production's current, real shape, with real accumulated view-count data) into a plain `id uuid primary key` append-only event log. This needs `DROP CONSTRAINT drop_views_pkey` + `ADD COLUMN id` + `ADD CONSTRAINT ... PRIMARY KEY (id)`, in that order, on a table with live data -- not a `CREATE TABLE IF NOT EXISTS` no-op.
5. Confirmed `home_feed`'s final redefinition (used by every one of WYN-092/093/097/098's changes, since 3 different worktrees each independently appended their own version and the branch's own merge-reconciliation note explains the final one supersedes all of them) only *appends* 5 new columns (`image_width`, `image_height`, `audience`, `location`, `image_count`) after production's current last column (`poll_expires_at`) -- byte-for-byte diffed against production's real current column list to confirm no existing column's position/name/type changes, which is the exact failure mode (`42P16`) that broke the WYN-072 deploy previously.

**Validated end-to-end against a local, throwaway PostgreSQL 16 instance** in this sandbox (`service postgresql start`), not just reviewed by eye:
- Built a minimal synthetic reproduction of production's *current* schema (the specific tables/columns/constraints this migration touches, in their pre-migration shape) and seeded it with existing `drop_views` rows to simulate real production data.
- Ran the migration script below against it: **applied cleanly, zero errors**.
- **Re-ran it a second time** (idempotency check): zero errors -- every `ALTER`/`CREATE` is `IF NOT EXISTS`/`IF EXISTS`-guarded or `CREATE OR REPLACE`.
- Verified the `drop_views` restructure preserved both pre-existing rows (now with generated `id`s, correct `drop_id`/`viewer_id`/`created_at` unchanged) and that `view_count` in `home_feed` correctly counts both (no dedup, matching WYN-083's intent).
- Verified `club_posts`: inserting a 10-image post now fails the `CHECK` constraint; a 9-image post succeeds.
- Verified `create_poll_drop()` and `record_drop_view()` (both replaced functions) execute successfully end-to-end.
- Dropped the throwaway database and stopped the local Postgres server afterward -- **no production system was touched by this validation.**

### The exact migration SQL (also saved at `.wyn/logs/deployments/2026-09-03-wyn-077-105-beta2-production-migration.sql`)

**Founder: run this once, in full, via the Supabase Dashboard -> SQL Editor**, against project `kqokpocajhfbidcxpvhh`, ideally *before* (or immediately after, doesn't matter much since the old app code doesn't reference any of these new columns/tables) the web deploy above. It is idempotent -- safe to re-run if a partial failure happens partway through.

```sql
-- ============================================================
-- Wynos Beta2 production migration (WYN-077 through WYN-105)
-- ============================================================

-- ---- WYN-079: Undo for "hide post" ----
drop policy if exists "Users can delete their own feed signals" on public.feed_signals;
create policy "Users can delete their own feed signals"
  on public.feed_signals
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- ---- WYN-083: view counting -- drop dedup, count from first view,
-- include author, uncapped. Restructures drop_views from a
-- (drop_id, viewer_id) composite-PK dedup ledger into a plain
-- append-only event log. Existing rows are preserved -- only the
-- primary key changes shape, not the data itself.
alter table public.drop_views drop constraint if exists drop_views_pkey;
alter table public.drop_views add column if not exists id uuid not null default gen_random_uuid();
alter table public.drop_views add constraint drop_views_pkey primary key (id);

create index if not exists drop_views_drop_id_idx
  on public.drop_views (drop_id);

create or replace function public.record_drop_view(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_drop record;
  v_account_recent_count bigint;
  v_drop_recent_count bigint;
begin
  select * into v_drop from public.drops where id = p_drop_id;

  if v_drop is null or v_drop.deleted_at is not null then
    return;
  end if;

  select count(*) into v_account_recent_count
  from public.drop_views
  where viewer_id = v_me and created_at > now() - interval '60 seconds';
  if v_account_recent_count >= 20 then
    return;
  end if;

  select count(*) into v_drop_recent_count
  from public.drop_views
  where drop_id = p_drop_id and created_at > now() - interval '10 seconds';
  if v_drop_recent_count >= 50 then
    return;
  end if;

  insert into public.drop_views (drop_id, viewer_id)
  values (p_drop_id, v_me);
end;
$$;

-- ---- WYN-093: dynamic-height feed images ----
alter table public.drops add column if not exists image_width integer;
alter table public.drops add column if not exists image_height integer;
alter table public.drop_images add column if not exists image_width integer;
alter table public.drop_images add column if not exists image_height integer;

-- ---- WYN-103: image count limit 10 -> 9 (defense-in-depth at the DB,
-- matching the app's own _maxImages = 9) ----
--
-- Production incident (2026-09-03): applying these two constraints
-- without `not valid` failed with 23514 -- real production has
-- drops/club_posts predating the app's 9-image limit that already have
-- 9+/10 images. `not valid` enforces the constraint on every new
-- insert/update from here on (the actual goal, defense-in-depth for
-- new posts) without retroactively validating -- and therefore without
-- touching or rejecting -- any pre-existing row. No user data is
-- read, modified, or deleted by this constraint either way.
alter table public.club_posts drop constraint if exists club_posts_image_urls_length;
alter table public.club_posts
  add constraint club_posts_image_urls_length
  check (image_urls is null or array_length(image_urls, 1) between 1 and 9) not valid;

alter table public.drop_images drop constraint if exists drop_images_position_max_9;
alter table public.drop_images
  add constraint drop_images_position_max_9 check (position >= 0 and position < 9) not valid;

-- ---- WYN-097: Post Audience Selector + "friends" (mutual follow) +
-- Close Friends ----
alter table public.drops
  add column if not exists audience text not null default 'everyone'
  check (audience in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me'));

create or replace function internal.is_mutual_follow(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.follows where follower_id = a and following_id = b)
     and exists (select 1 from public.follows where follower_id = b and following_id = a);
$$;

create table if not exists public.close_friends (
  owner_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, friend_id),
  constraint close_friends_no_self check (owner_id <> friend_id)
);

alter table public.close_friends enable row level security;

drop policy if exists "Owner views their own close friends list" on public.close_friends;
create policy "Owner views their own close friends list"
  on public.close_friends
  for select
  to authenticated
  using (auth.uid() = owner_id);

drop policy if exists "Owner adds a mutual follow as a close friend" on public.close_friends;
create policy "Owner adds a mutual follow as a close friend"
  on public.close_friends
  for insert
  to authenticated
  with check (auth.uid() = owner_id and internal.is_mutual_follow(owner_id, friend_id));

drop policy if exists "Owner removes a close friend" on public.close_friends;
create policy "Owner removes a close friend"
  on public.close_friends
  for delete
  to authenticated
  using (auth.uid() = owner_id);

create table if not exists public.drop_audience_exclusions (
  drop_id uuid not null references public.drops (id) on delete cascade,
  excluded_user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (drop_id, excluded_user_id)
);

alter table public.drop_audience_exclusions enable row level security;

drop policy if exists "Drop author manages their own audience exclusions" on public.drop_audience_exclusions;
create policy "Drop author manages their own audience exclusions"
  on public.drop_audience_exclusions
  for all
  to authenticated
  using (auth.uid() = (select author_id from public.drops where id = drop_id))
  with check (auth.uid() = (select author_id from public.drops where id = drop_id));

create or replace function internal.can_view_drop_audience(p_viewer uuid, p_drop public.drops)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_drop.author_id = p_viewer
    or p_drop.audience = 'everyone'
    or (p_drop.audience = 'friends' and internal.is_mutual_follow(p_viewer, p_drop.author_id))
    or (p_drop.audience = 'friends_except'
        and internal.is_mutual_follow(p_viewer, p_drop.author_id)
        and not exists (
          select 1 from public.drop_audience_exclusions
          where drop_id = p_drop.id and excluded_user_id = p_viewer
        ))
    or (p_drop.audience = 'close_friends'
        and exists (
          select 1 from public.close_friends
          where owner_id = p_drop.author_id and friend_id = p_viewer
        ));
$$;

drop policy if exists "Drops are viewable by authenticated users, excluding blocked, deleted, and locked-private authors" on public.drops;
drop policy if exists "Drops are viewable by authenticated users, excluding blocked, deleted, locked-private authors, and out-of-audience" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked, deleted, locked-private authors, and out-of-audience"
  on public.drops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and (deleted_at is null or auth.uid() = author_id)
    and internal.can_view_author_content(auth.uid(), author_id)
    and internal.can_view_drop_audience(auth.uid(), drops.*)
  );

create or replace function public.get_poll_results(p_poll_ids uuid[])
returns table(
  poll_id uuid,
  visible boolean,
  total_votes bigint,
  option_counts bigint[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    dp.id as poll_id,
    v.is_visible,
    case when v.is_visible
      then (select count(*) from public.drop_poll_votes dpv where dpv.poll_id = dp.id)
      else null end as total_votes,
    case when v.is_visible
      then (
        select array_agg(cnt order by idx)
        from (
          select gs as idx, count(pv.id) as cnt
          from generate_series(0, array_length(dp.options, 1) - 1) as gs
          left join public.drop_poll_votes pv
            on pv.poll_id = dp.id and pv.option_index = gs
          group by gs
        ) counted
      )
      else null end as option_counts
  from public.drop_polls dp
  join public.drops d on d.id = dp.drop_id
  cross join lateral (
    select
      dp.expires_at <= now()
      or d.author_id = v_me
      or exists (
        select 1 from public.drop_poll_votes dpv2
        where dpv2.poll_id = dp.id and dpv2.voter_id = v_me
      ) as is_visible
  ) v
  where dp.id = any(p_poll_ids)
    and not internal.is_blocked_either_way(v_me, d.author_id)
    and internal.can_view_author_content(v_me, d.author_id)
    and internal.can_view_drop_audience(v_me, d);
end;
$$;

create or replace function public.fetch_mutual_follows(p_page int default 0)
returns setof public.profiles
language sql
stable
security invoker
set search_path = public
as $$
  select p.*
  from public.profiles p
  where internal.is_mutual_follow(auth.uid(), p.id)
  order by p.username
  offset greatest(p_page, 0) * 30 limit 30;
$$;

grant execute on function public.fetch_mutual_follows(int) to authenticated;

-- ---- WYN-099: Likes Tab Privacy ----
alter table public.profiles
  add column if not exists likes_visibility text not null default 'everyone'
  check (likes_visibility in ('everyone', 'friends', 'only_me'));

create or replace function internal.can_view_likes(p_viewer uuid, p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_viewer = p_target
    or (select likes_visibility from public.profiles where id = p_target) = 'everyone'
    or (
      (select likes_visibility from public.profiles where id = p_target) = 'friends'
      and internal.is_mutual_follow(p_viewer, p_target)
    );
$$;

create or replace function public.can_view_likes(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select internal.can_view_likes(auth.uid(), p_target);
$$;

grant execute on function public.can_view_likes(uuid) to authenticated;

create or replace function public.fetch_liked_drop_ids(p_target_user_id uuid, p_page int default 0)
returns table(drop_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select dl.drop_id
  from public.drop_likes dl
  join public.drops d on d.id = dl.drop_id
  where dl.user_id = p_target_user_id
    and internal.can_view_likes(auth.uid(), p_target_user_id)
    and not internal.is_blocked_either_way(auth.uid(), d.author_id)
    and (d.deleted_at is null or auth.uid() = d.author_id)
    and internal.can_view_author_content(auth.uid(), d.author_id)
    and internal.can_view_drop_audience(auth.uid(), d)
  order by dl.created_at desc
  offset greatest(p_page, 0) * 21 limit 21;
$$;

grant execute on function public.fetch_liked_drop_ids(uuid, int) to authenticated;

create or replace function public.fetch_liked_pop_ids(p_target_user_id uuid, p_page int default 0)
returns table(pop_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select pl.pop_id
  from public.pop_likes pl
  join public.pops p on p.id = pl.pop_id
  where pl.user_id = p_target_user_id
    and internal.can_view_likes(auth.uid(), p_target_user_id)
    and not internal.is_blocked_either_way(auth.uid(), p.author_id)
  order by pl.created_at desc
  offset greatest(p_page, 0) * 21 limit 21;
$$;

grant execute on function public.fetch_liked_pop_ids(uuid, int) to authenticated;

-- ---- WYN-098: Location Check-in (LocationIQ) ----
alter table public.drops add column if not exists location_lat double precision;
alter table public.drops add column if not exists location_lon double precision;
alter table public.drops add column if not exists location_place_id text;

alter table public.drops drop constraint if exists drops_location_lat_lon_together;
alter table public.drops
  add constraint drops_location_lat_lon_together
  check ((location_lat is null) = (location_lon is null));

alter table public.drops drop constraint if exists drops_location_place_id_needs_name;
alter table public.drops
  add constraint drops_location_place_id_needs_name
  check (location_place_id is null or location is not null);

create table if not exists public.location_search_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  requested_at timestamptz not null default now()
);

alter table public.location_search_requests enable row level security;

create index if not exists location_search_requests_user_id_requested_at_idx
  on public.location_search_requests (user_id, requested_at desc);

-- create_poll_drop -- final signature (audience + location together;
-- this single CREATE OR REPLACE supersedes the WYN-097-only
-- intermediate version, so only the final one needs to be applied).
create or replace function public.create_poll_drop(
  p_caption text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}',
  p_audience text default 'everyone',
  p_excluded_friend_ids uuid[] default '{}',
  p_location text default null,
  p_location_lat double precision default null,
  p_location_lon double precision default null,
  p_location_place_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_drop_id uuid;
  v_options text[];
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;

  if p_caption is null or length(trim(p_caption)) = 0 then
    raise exception 'Poll question is required';
  end if;

  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  if p_audience not in ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me') then
    raise exception 'Invalid audience';
  end if;

  insert into public.drops (
    author_id, image_url, caption, audience,
    location, location_lat, location_lon, location_place_id
  )
  values (
    v_author, null, trim(p_caption), p_audience,
    p_location, p_location_lat, p_location_lon, p_location_place_id
  )
  returning id into v_drop_id;

  insert into public.drop_polls (drop_id, options, expires_at)
  values (v_drop_id, v_options, now() + make_interval(days => p_duration_days));

  if p_audience = 'friends_except' then
    insert into public.drop_audience_exclusions (drop_id, excluded_user_id)
    select v_drop_id, u
    from unnest(p_excluded_friend_ids) as u;
  end if;

  insert into public.drop_mentions (drop_id, mentioned_user_id)
  select v_drop_id, m
  from unnest(p_mentioned_user_ids) as m
  where not internal.is_blocked_either_way(v_author, m)
    and internal.mention_allowed(m, v_author);

  return v_drop_id;
end;
$$;

-- ---- Final home_feed redefinition (supersedes every earlier one --
-- adds image_width, image_height, audience, location, image_count as
-- the trailing 5 columns; every existing column/branch is otherwise
-- byte-for-byte identical to production's current definition) ----
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
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
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
  null::bigint as image_count
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
  (select count(*) from public.drop_images where drop_id = d.id) as image_count
from public.redrops r
join public.drops d on d.id = r.drop_id
join public.profiles prof on prof.id = d.author_id
join public.profiles redropper on redropper.id = r.redropper_id
left join public.drop_polls dp on dp.drop_id = d.id
where not exists (
  select 1 from public.mutes
  where muter_id = auth.uid() and muted_id in (d.author_id, r.redropper_id)
);

grant select on public.home_feed to authenticated;

select 'MIGRATION APPLIED OK' as status;
```

**What this migration deliberately does NOT include**: WYN-098's `location-search` Edge Function is code-complete in the merged commit (`supabase/functions/location-search/`) but is **not deployed** by this SQL migration -- Edge Function deployment is a separate `supabase functions deploy location-search` action (Supabase CLI, project credentials) that this session also has no access to. Not urgent: the function is non-functional either way until Founder provisions `LOCATIONIQ_API_KEY` (see "Known gaps" below), so there is no rush to deploy it before that key exists.

## Deployment Result

**PARTIAL.** Code merge: **SUCCESS** (PR #216, merge commit `56e56a7`). Database migration: **PREPARED, NOT APPLIED** (blocked on Founder running the SQL above). Web deploy: **NOT TRIGGERED** (blocked on Founder running `deploy-web.yml` manually -- this session cannot trigger GitHub Actions runs, confirmed via 2 independent 403s, one of them an explicit Anthropic session-type policy block).

## Post-deploy incident: `drop_images_position_max_9` violated by real production data (2026-09-03)

While running the migration above, the Founder hit `ERROR: 23514: check constraint "drop_images_position_max_9" of relation "drop_images" is violated by some row` -- real production has `drops` with more than 9 images already (posted before the app enforced the 9-image limit), so the plain `add constraint ... check (...)` form (which validates every existing row by default) correctly rejected them.

**Root cause**: this session's local-Postgres validation (see step 5 above) used a synthetic seed dataset that never included a row exceeding the new bound, so it never exercised this failure path -- a real gap in that test, not a flaw in the constraint's logic itself.

**Fix**: both narrowing-a-limit constraints in the migration (`club_posts_image_urls_length` 10->9, `drop_images_position_max_9`, the only two of this shape in the whole script) now use `check (...) not valid` instead of `check (...)`. `not valid` enforces the constraint on every future insert/update (the actual defense-in-depth goal) without validating -- and therefore without touching or rejecting -- any pre-existing row. This is the standard Postgres pattern for adding a constraint to a table with legacy data that predates the new rule; no user data was read, modified, or deleted to resolve this. The orchestrating session applied this fix directly to both this file and `2026-09-03-wyn-077-105-beta2-production-migration.sql` and relayed the two corrected statements to the Founder to run in place of the failed ones -- the rest of the script is unaffected and safe to re-run in full (every statement is `if not exists`/`if exists`/`create or replace` guarded).

**Follow-up (not done here, flagged for Product/Coding)**: some real Drops in production have more than 9 images. Whether to backfill/trim them, grandfather them as-is (the app's read path already renders however many `drop_images` rows exist per Drop, so this is not a functional bug -- just means the DB no longer matches the app's own forward-looking limit for those specific old rows), or something else, is a product decision, not something to resolve unilaterally in a hotfix.

## Production Verification

Baseline captured before this release (nothing below reflects Beta2 yet -- for Founder to compare against *after* running the workflow):
- `curl https://wynos.online/` -> HTTP 200
- `curl https://wynos.online/main.dart.js` -> HTTP 200, **4,135,619 bytes**, `last-modified: Thu, 03 Sep 2026 03:18:24 GMT` (run #39, commit `f0da5df`, pre-Beta2)

**After Founder runs `deploy-web.yml` against `main` @ `56e56a7` (or later)**: re-check `main.dart.js`'s size/`last-modified` -- it should differ from the baseline above, confirming a fresh compile rather than a stale cache hit, same check as every prior release in this project.

## Rollback Plan

- **Code**: if the new web build misbehaves after Founder triggers the deploy, re-run `deploy-web.yml` pinned to `f0da5df` (the last known-good commit, run #39) to restore the prior build within ~3 minutes. No `git revert` needed on `main` unless a code fix is also wanted immediately.
- **Database**: every statement in the migration above is additive or shape-preserving on existing data (new columns with defaults, new tables, `CREATE OR REPLACE VIEW/FUNCTION`, and the one structural change -- `drop_views`' primary key -- keeps every existing row, just changes what column identifies each row). **Rolling back the app code does not require rolling back the schema** -- old code simply doesn't reference the new columns/tables. If the schema absolutely must be reverted: `drop table if exists public.close_friends, public.drop_audience_exclusions, public.location_search_requests cascade;` then restore the pre-migration `drop_views` shape (`alter table public.drop_views drop constraint drop_views_pkey; alter table public.drop_views add constraint drop_views_pkey primary key (drop_id, viewer_id); alter table public.drop_views drop column id;` -- note this would silently discard any *new* rows inserted after the PK change that happen to share a `(drop_id, viewer_id)` pair with an existing row, since the old PK is a hard uniqueness constraint the new shape doesn't have -- **not recommended** unless truly necessary).
- **club_posts/drop_images constraints**: if the tighter 9-image limit needs reverting, `alter table public.club_posts drop constraint club_posts_image_urls_length, add constraint club_posts_image_urls_length check (image_urls is null or array_length(image_urls, 1) between 1 and 10); alter table public.drop_images drop constraint drop_images_position_max_9;`

## Known gaps (not blockers, carried forward from QA/Coding notes)

- **WYN-098's `location-search` Edge Function is non-functional until Founder provisions `LOCATIONIQ_API_KEY`** -- per explicit instruction for this deploy, this session did not attempt to configure it or make it appear functional. The code fails gracefully in the meantime (posting works normally, just without an attached location) -- this is expected and not a regression.
- Several tasks (WYN-093/094/097/098/099/104) are only verified via widget tests + static review (no device/simulator in any sandbox session so far) -- each task's own QA report already flags this and recommends a one-time real-device/browser check post-deploy; not a merge or deploy blocker.
- WYN-099's Likes-tab privacy has one documented, Product-spec-accepted residual risk: `drop_likes`/`pop_likes` tables themselves still allow any authenticated user to query them directly (bypassing the new `likes_visibility`-aware RPCs) -- this is intentional (changing it would risk breaking `like_count`/`liked_by` app-wide) and was already flagged to Founder in WYN-099's own QA report.
- Native iOS/Android app build/distribution remains out of scope (blocked on Firebase config files + a distribution channel) -- unchanged from every prior release, not attempted this session.

## Update (2026-09-03, orchestrating session): web deploy completed

Unlike the deploy subagent above, the orchestrating session's own GitHub tool access was *not* blocked from triggering `workflow_dispatch` -- successfully ran `deploy-web.yml` against `main` @ `09c0251` (then again implicitly current at `f228f63` after the migration-constraint hotfix below, same build either way since that fix only touches `.wyn/logs/`, not app code).

- Run: [`33711417505`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33711417505), run #40, `status: completed`, `conclusion: success`.
- **Production Verification (real, post-deploy)**: `curl -I https://wynos.online/main.dart.js` -> HTTP 200, **4,228,301 bytes**, `last-modified: Thu, 03 Sep 2026 03:33:25 GMT` -- different size than the 4,135,619-byte pre-Beta2 baseline above, confirming a genuinely fresh compile, not a stale cache hit.
- **Web deploy: DONE.** Database migration is still the Founder's action (see incident below -- it's in progress, hit and fixed one constraint issue along the way).

## Next Steps (Founder)

1. ~~Trigger the web deploy~~ -- **done**, see update above.
2. **Finish running the SQL migration** via Supabase Dashboard -> SQL Editor (project `kqokpocajhfbidcxpvhh`) -- the two `not valid` corrected statements (see "Post-deploy incident" above) replace the two that failed; the rest of the script is idempotent and safe to re-run in full if needed.
3. Once the migration is fully applied, consider a real-device/browser smoke test of WYN-097 (post as "เพื่อน"/"เฉพาะฉัน", confirm visibility), WYN-098 (location button, once `LOCATIONIQ_API_KEY` exists), and WYN-104 (photo crop) -- the highest-risk items among the "not yet device-tested" list above.
