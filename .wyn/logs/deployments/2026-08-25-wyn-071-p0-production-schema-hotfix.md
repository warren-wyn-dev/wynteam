# Incident Log — P0: WYN-071 schema (`drop_images`) never applied to production, broke Drop loading app-wide

## Summary

WYN-071's QA process validated the new schema (`drop_images`, `profile_recommendation_dismissals`, updated `suggested_users()`) only against throwaway local Postgres databases (`supabase/tests/wyn_071_*.sh`) -- the same pattern used successfully for every prior task's SQL regression tests. What was missed: **nobody actually applied the migration to the real production Supabase database.** The app code was deployed (see `2026-08-25-wyn-071-064-065-real-deploy.md`) referencing a table (`drop_images`) that did not exist in production.

`_dropSelect` in `app/lib/features/drop/data/drop_repository.dart` embeds `drop_images(count)` and is used by **every** Drop-fetching method in the repository (Home feed, ranked feed, following feed, `fetchByAuthor` (Profile Posts/Media tabs), `searchByCaption` (hashtag search, used by `HashtagFeedScreen`), `fetchById` (Drop detail), saved feed, deleted-drops). Once this build went live, **every one of these broke** with a PostgREST error, surfaced to users as generic "โหลด...ไม่สำเร็จ" messages app-wide -- not a UI bug, not a "few pages," the entire Drop-loading surface of the app.

## How it was caught

Founder opened the live production app on their phone shortly after the deploy-correction was confirmed, and hit "โหลดผลการค้นหาไม่สำเร็จ" on hashtag search and "โหลด Drop ไม่สำเร็จ" on their own Profile's Posts tab (screenshots). Investigated by querying production directly via the Supabase Management API rather than guessing:

```sql
select table_name from information_schema.tables
where table_schema = 'public' and table_name in ('drop_images', 'profile_recommendation_dismissals');
```

Returned `[]` -- confirmed neither table existed in production, while both are `create table if not exists` in `supabase/schema.sql` (lines ~10058, ~10138) and were required by app code already live.

## Fix

Extracted the exact WYN-071 migration block from `supabase/schema.sql` (lines 10050-10180: `profile_recommendation_dismissals` table + RLS, `suggested_users()` update, `drop_images` table + RLS + idempotent backfill) and applied it directly to production via the Supabase Management API (`POST /v1/projects/{ref}/database/query`), the same mechanism used for the original WYN-063 production hotfix earlier in this project's history.

**Required explicit Founder authorization to execute**: this sandbox's safety classifier blocks direct production-database-write commands by default. Asked Founder via `AskUserQuestion` ("retry with authorization" vs. "hand you the SQL to run yourself in the Supabase SQL Editor") -- Founder chose to authorize the retry.

## Verification

- `select table_name from information_schema.tables ...` -- both tables now present.
- `select count(*) from public.drop_images` -- **13 rows**, confirming the backfill ran (13 pre-existing Drops with images each got their `position: 0` row).
- Reproduced the exact failing query pattern via the live REST API with the public anon/publishable key: `GET /rest/v1/drops?select=id,caption,drop_images(count)&limit=3` -- **HTTP 200** (previously would have errored; empty result body is RLS correctly hiding rows from an unauthenticated key, not a bug).

## Root cause (for future prevention)

The project's QA convention (`supabase/tests/*.sh` against throwaway local databases) proves the *SQL is correct* -- it does not prove the SQL was *ever run against production*. This is the second time this exact class of gap has caused a real production incident (see the WYN-063 `get_wynos_ranked_feed()` fix at the very start of this session's history). **AI Deploy & DevOps's checklist should explicitly include applying any new schema.sql delta to the real production database as its own verified step, separate from and in addition to app code deployment** -- QA passing local-database regression tests is necessary but not sufficient signal that production is ready.

## Rollback plan

Not applicable in the harmful-change sense (this only *added* tables/columns/a backfill, matching a live app that already expected them) -- but if ever needed: `drop table public.drop_images cascade; drop table public.profile_recommendation_dismissals cascade;` would revert to the WYN-071 code being broken again (not recommended -- the correct direction is forward, this incident's fix *is* the recovery).
