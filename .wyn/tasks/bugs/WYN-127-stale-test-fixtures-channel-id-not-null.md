# Bug Report — WYN-127 (follow-up, non-blocking)

Status: **fixed (2026-09-07, AI Debug Engineer)** — all 6 fixture-only scripts patched and independently re-verified green against a local scratch PostgreSQL 16.13. `channel_id` (sourced from `select id from public.club_channels where club_id = ... order by created_at limit 1`, i.e. each fixture Club's own auto-created "ทั่วไป" default channel) added to the raw `club_posts` inserts in `wyn_021`/`wyn_044`/`wyn_045`/`wyn_047`/`wyn_117`; `p_channel_id` (same lookup) added as the 2nd positional argument to every `create_poll_club_post(...)` call in `wyn_115`. All 6 scripts now print "ALL CHECKS PASSED" with the exact same check count as the pre-WYN-127 baseline (commit `5498928`, verified via a throwaway `git worktree` checkout run against the old schema+old script pair): wyn_021 5/5, wyn_044 21/21, wyn_045 22/22, wyn_047 42/42, wyn_115 24/24, wyn_117 15/15 — confirming the fix touched only fixture setup, not any assertion. No `schema.sql` or Dart file changed. `wyn_038_view_counting_test.sh` intentionally left untouched (out of scope, unrelated pre-existing failure per Root Cause below). Handed off to AI QA & Security for optional spot-check (non-blocking).
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (optional spot-check)

Bug: WYN-127 added `club_posts.channel_id` as `NOT NULL` and changed `create_poll_club_post()`'s signature (inserted a new `p_channel_id` parameter). 6 of this repo's pre-existing `supabase/tests/*.sh` regression scripts predate that change and were never updated to match, so they now error out during fixture setup (or, for `wyn_115`, calling the RPC with the old signature) instead of running their actual assertions:

- `wyn_021_club_post_mentions_rls_test.sh` — raw `insert into club_posts (...)` fixture has no `channel_id` column at all → `NOT NULL` violation
- `wyn_044_notification_settings_test.sh` — same
- `wyn_045_privacy_controls_test.sh` — same
- `wyn_047_data_rights_test.sh` — same
- `wyn_115_club_poll_test.sh` — calls `create_poll_club_post(club_id, content, options, duration, mentions)` (old 5-arg shape) → `function ... does not exist`
- `wyn_117_club_owner_insights_test.sh` — same raw-insert-missing-`channel_id` issue as 021/044/045/047

**This is confirmed to be test-fixture staleness only, not a production/runtime regression** — see Root Cause below for the independent verification performed. A separate 8th failing script, `wyn_038_view_counting_test.sh`, is unrelated to WYN-127 entirely (reproduced identically against the pre-branch baseline commit `5498928`, before any WYN-127/128/129 work existed — 8 checks fail there too, same failure signature) and needs its own, separate investigation outside the scope of this ticket.

Reproduction: `bash supabase/tests/wyn_021_club_post_mentions_rls_test.sh` (or 044/045/047/117) → `ERROR: null value in column "channel_id" of relation "club_posts" violates not-null constraint` during fixture insert, before any real assertion runs. `bash supabase/tests/wyn_115_club_poll_test.sh` → `ERROR: function public.create_poll_club_post(unknown, unknown, text[], integer, uuid[]) does not exist`.

Root Cause / why this does NOT block deploy: independently re-verified (AI QA & Security, live PostgreSQL 16.13) that the actual application code path is already correct and was never affected:
- `ClubPostRepository.createPost()` requires `channelId` (non-nullable Dart param) and always sends `'channel_id': channelId` in its insert.
- `ClubPostRepository.createPollClubPost()` requires `channelId` and always sends `'p_channel_id': channelId` (named param) to the RPC — matches `create_poll_club_post()`'s current 6-param signature exactly.
- `create_club_post_screen_test.dart` (part of the 1377/1377 green Flutter suite) already asserts `createPollClubPostArgs` includes `'channelId': 'channel-1'` — this call shape has been correct and tested since WYN-127's original Coding round, before this bug even existed in the shell-script suite.
- Directly invoked `public.create_poll_club_post(p_club_id => ..., p_channel_id => ..., ...)` against a live Postgres 16.13 the exact way the Dart repository calls it (named params) — succeeded, created the `club_posts` row with the correct `channel_id` and its matching `club_post_polls` row.
- The migration's own backfill (verified in the original QA FAIL report) already guarantees every pre-existing `club_posts` row has a valid `channel_id`, so this constraint cannot fire against real/legacy data either.

In short: WYN-127 correctly updated every real call site (Dart app + its own widget tests) when it added `channel_id`, but nobody went back and updated these 6 older, unrelated feature's SQL regression scripts' *fixture* inserts/RPC calls to match — a maintenance gap, not a functional bug.

Fix: Add `channel_id` (referencing each fixture Club's own default/"ทั่วไป" channel, e.g. `select id from public.club_channels where club_id = ... order by created_at limit 1`) to the raw `club_posts` fixture inserts in `wyn_021`/`wyn_044`/`wyn_045`/`wyn_047`/`wyn_117`, and add a `p_channel_id` argument (same lookup) to every `create_poll_club_post(...)` call in `wyn_115`.

Files Changed (expected): `supabase/tests/wyn_021_club_post_mentions_rls_test.sh`, `wyn_044_notification_settings_test.sh`, `wyn_045_privacy_controls_test.sh`, `wyn_047_data_rights_test.sh`, `wyn_115_club_poll_test.sh`, `wyn_117_club_owner_insights_test.sh`. No `schema.sql`/Dart changes needed.

Tests: Re-run all 6 scripts after the fixture fix and confirm each returns to "ALL CHECKS PASSED" with the same check count as before WYN-127 (i.e. the fix only touches fixture setup, not any assertion).

Regression Risk: None — these are test-only files; fixing their fixtures cannot affect any shipped behavior.

Handoff to QA: Optional spot-check once fixed (re-run the 6 scripts, confirm green) — does not need to happen before WYN-127/128/129 ships, since production correctness for this exact concern was independently verified above through the real Dart code path, its own passing widget tests, and a direct live-Postgres call matching the Dart call shape exactly.
