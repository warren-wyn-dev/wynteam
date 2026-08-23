# Deployment Log — WYN-038 (View Counting System — Drop)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-038 went through Product spec, Design spec, Coding, and a full independent QA cycle in this same session, continuing the Phase 3 session-pattern WYN-034/035/036/037 established:

- **Product/Design**: Master Spec section 6 ("VIEW SYSTEM": "นับ Views อย่างมีระบบ ไม่ใช่ทุก Refresh = 1 View ต้องมี: Unique Viewer logic, Rate limiting, Bot detection, Suspicious traffic detection") scoped to **Drop only** — Pop was removed from the Bottom Nav back in WYN-024 and has no real user reach, so its existing naive `view_count` counter (already flagged by WYN-006's QA as missing rate-limiting) was left untouched. Full bot detection isn't feasible with this stack (Flutter + Supabase only, no CAPTCHA/device fingerprinting/IP tracking) — accepted as a scope reduction, substituting three SQL-only behavioral defenses: self-view exclusion, a 20-inserts/60-seconds per-account rate limit, and a 50-inserts/10-seconds per-Drop velocity cap, all failing silently (no client-visible error).
- **Coding**: new `drop_views` table (`primary key (drop_id, viewer_id)` — this alone is the lifetime unique-viewer dedup mechanism). No raw client INSERT policy at all — the only write path is `record_drop_view()` (SECURITY DEFINER), which no-ops silently through checks a→d (deleted/self-view/rate-limit/velocity-cap) before an `on conflict do nothing` insert. `home_feed`/`saved_feed`'s Drop branch now calls a new `drop_view_count()` (SECURITY DEFINER) instead of the `null::bigint` placeholder WYN-007 reserved; Pop's branch in both views is untouched. Flutter: `Drop.viewCount`/`withExtraView()`, `DropDetailScreen`'s `_viewRecorded` flag (skipped entirely for the owner's own Drop), and a new view-count display on `DropDetailScreen`/`HomeDropCard` mirroring Pop's existing icon — with an added `Semantics` label Pop's own version was missing.
- **The key security/privacy decision this round**: `drop_views`' SELECT policy is restricted to `auth.uid() = viewer_id` — deliberately **not** opened select-all-authenticated the way `drop_likes` is, since "who viewed what" isn't something a user opts into revealing the way a Like is (mirrors the lesson from `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md`). `drop_view_count()` bypasses that restriction via SECURITY DEFINER to return an accurate count to every viewer without ever exposing the underlying viewer-identity rows.
- **Independent QA — PASS (3 real bugs found and fixed, all in test code)**: installed the Flutter SDK itself (Coding's sandbox had none, so its 607/607 figure was an estimate, not a verified run) and ran `flutter analyze`/`flutter test` for real. Found and fixed: a fixture in `drop_comment_delete_test.dart` whose default `viewCount` collided with a comment-count assertion once the new view-count UI was added; a new Semantics test in `drop_detail_screen_test.dart` that needed a substring match because the interaction row has no semantics boundary between buttons (a pre-existing gap from WYN-005/008/013, not introduced by this task); and an inline `RecordingDropRepository()` in the same test file leaking a GoTrue timer, fixed by moving it into `setUpAll` per the project's existing convention. Also independently re-ran all SQL scripts and read `record_drop_view()`/`drop_view_count()`/the `drop_views` RLS policy directly to confirm the privacy design holds.

Full history: `.wyn/tasks/approved/WYN-038-view-counting-system.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-038-view-counting-system.md`, `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified in this session, using this container's Flutter SDK (installed by AI QA & Security specifically to verify this task, since the Coding sandbox had none) and a local Postgres 16 server:

- `flutter analyze`: **0 issues**
- `flutter test`: **607/607 pass** (597 baseline from WYN-037 + 10 new for this task)
- SQL regression scripts, each against a fresh Postgres 16 database under the real `authenticated` role (not superuser):
  - `supabase/tests/wyn_038_view_counting_test.sh` — **29/29 PASS** (new this round)
  - All 11 prior scripts (`wyn_021` through `wyn_037`) — re-run independently, **all still passing, no cross-task regression**

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below.

## Changes

4 files changed in this round on top of the WIP commit (`.wyn/tasks/approved/WYN-038-view-counting-system.md` moved from `backlog/`, plus the 3 test-file fixes above) — combined with the prior WIP commit, the full task total is 17 files:

- **SQL** (`supabase/schema.sql`): new `drop_views` table + index, SELECT policy restricted to `auth.uid() = viewer_id`, `record_drop_view()` and `drop_view_count()` (both SECURITY DEFINER), `home_feed`/`saved_feed` redefined to call `drop_view_count()` for the Drop branch only.
- **Flutter**: `Drop`/`HomeFeedItem`/`DropRepository`/`DropDetailScreen`/`HomeDropCard` changes described above.
- **New persisted regression test**: `supabase/tests/wyn_038_view_counting_test.sh` (29 checks).
- **Tests**: additions across `drop_test.dart`, `drop_detail_screen_test.dart`, `home_feed_item_test.dart`, `home_feed_screen_test.dart`, `view_profile_screen_test.dart`, `support/recording_drop_repository.dart`, plus the 3 QA fixes to `drop_comment_delete_test.dart`/`drop_detail_screen_test.dart`/`home_feed_screen_test.dart`.

Full history: `.wyn/tasks/approved/WYN-038-view-counting-system.md`.

## Deployment Result

**Committed and pushed to `claude/phase3-wyn-038-7xzxbx` (2 commits: WIP implementation, then the QA fix-up).** Branch not yet merged into `main` — **opening a pull request requires the Founder's explicit go-ahead** (platform policy for this session), so this deployment log records the branch as build-verified and QA-approved, ready to merge on request, rather than already merged. This is the fifth task of **Phase 3 (Drop Enhancement)** ready to land on `main`, following WYN-034 (ReDrop), WYN-035 (Poll in Drop), WYN-036 (Draft System), and WYN-037 (Edit/Delete Drop) — and a direct dependency of WYN-041 (Trending Engine v2, Phase 4), which needs real Drop view data.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-037-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-sixth+ approved batch** in this project's history to reach this exact same gate — all "approved, ready for `main`, waiting for real infra." None of this has ever been a WYN-038-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: once merged, `git revert` the merge commit on `main` restores the pre-merge state. Reverting would remove the view-count display from `DropDetailScreen`/`HomeDropCard` and `Drop.viewCount` would go back to always-0 via `HomeFeedItem.toDrop()`. Leaves WYN-021 through WYN-037 untouched.
- **Database**: `supabase/schema.sql` grew by the `drop_views` table, 2 new SECURITY DEFINER functions, and 2 redefined views (`home_feed`/`saved_feed`). Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse, no accumulated `drop_views` rows to reconcile.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps

1. **Founder decision needed now**: whether to open the pull request from `claude/phase3-wyn-038-7xzxbx` into `main` to complete this merge (this session will not open a PR without that go-ahead).
2. Unchanged from prior deployment logs (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated per RULES.md's "โครงสร้างพื้นฐาน production".

With WYN-038 code-complete and QA-approved, **Phase 3 (Drop Enhancement)'s fifth task is ready**. Per the Roadmap, the remaining Phase 3 task is WYN-039 (Private Account + Follow Request) — not started yet.
