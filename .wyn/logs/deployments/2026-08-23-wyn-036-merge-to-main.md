# Deployment Log — WYN-036 (Draft System)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-036 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session, continuing the same session-pattern WYN-034/WYN-035 established for Phase 3:

- **Product/Design**: Master Spec section 3 lists Draft as a base capability ("ผู้ใช้ทำได้: Save Draft, Edit Draft, Delete Draft, Continue Editing — Draft ต้องเป็น Private"). Product filled in the mechanics: the only entry point to saving a Draft is closing the composer (X button or system back) with unsaved content, which shows a 3-button dialog ("บันทึกร่าง"/"ทิ้ง"/"ยกเลิก") — no separate "Save Draft" button, to keep the AppBar uncluttered, mirroring Twitter/Instagram's own close-intercept pattern. A Draft never needs to pass full publish validation (e.g. a poll draft can have just 1 filled option). The key architectural call, mirroring WYN-034/WYN-035's own precedent: **a Draft is a fully separate table (`drop_drafts`), never a `drops` row**, so it structurally cannot leak into `home_feed`/Search/Notifications/Reports/anywhere else — visible only to its owner.
- **Coding**: New `drop_drafts` table with a looser `valid_draft_poll_options()` CHECK than WYN-035's `valid_poll_options()` (2-4 options, ≤80 chars each, but incomplete/duplicate options allowed — a Draft is explicitly allowed to be unfinished). RLS is 4 policies, every one scoped to `auth.uid() = author_id` with no exception — unlike ReDrop/Poll, a Draft has no other party to ever share visibility with. `DropRepository` gained `fetchDrafts()`/`saveDraft()` (insert-or-update by id, so re-saving never duplicates)/`deleteDraft()`/`createDropFromExistingImage()` (publishes from a Draft's already-uploaded image without re-uploading it). `CreateDropScreen` gained a `draft` param, a `_prefillFromDraft()` that copies a Draft's content into the screen's own state on `initState()`, and a `PopScope<bool>` wrap so both the AppBar X button and the system back gesture route through the same `_handleClose()` — confirmed via reading Flutter framework source that a direct `Navigator.pop()` call always bypasses `PopScope.canPop` (only `maybePop()`/system back consult it), so there's no infinite-loop risk between the two paths. New `DraftGridTile` (reuses WYN-035's `PollPlaceholderTile` for poll-mode drafts) and `ProfileDraftsTab` (a new "ร่าง" tab on the owner's own Profile, mirroring `ProfileSavedTab`).
- **Independent QA — PASS (1 real bug found and fixed before approval)**: read the full diff directly, ran `flutter analyze` (clean) and `flutter test` independently, re-ran all 10 SQL regression scripts independently (196/196). Traced the compose-mode switch path specifically (image ↔ poll state coexists in one widget) and found that `SegmentedButton.onSelectionChanged` never clears `_imageBytes`/`_existingImageUrl` when switching to โพล mode — `_share()`/`_canShare` already gated correctly on `_mode`, but `_saveDraftAndClose()` did not: saving a draft after switching from image mode to poll mode would silently upload the stale leftover image and attach its `image_url` to what should have been a pure poll draft. Wrote a regression test reproducing the exact scenario, confirmed it **fails against the original code** and **passes after the fix** (gating `imageBytes`/`existingImageUrl` in `_saveDraftAndClose` by `_mode == _ComposeMode.image`) before accepting the fix. Also re-encountered the known "Timer is still pending" gotcha in `profile_drafts_tab_test.dart` (repositories constructed inline inside `testWidgets` bodies instead of `setUpAll`) — fixed by moving construction to `setUpAll`, matching the project's established discipline.

Full history: `.wyn/tasks/approved/WYN-036-draft-system.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-036-draft-system.md`, `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified in this session, using this container's Flutter 3.x (stable) and a local Postgres 16 server:

- `flutter pub get`: clean (packages have newer versions available, none blocking — same as every prior deployment log)
- `flutter analyze`: **0 issues**
- `flutter test`: **576/576 pass** (553 baseline + 23 new for this task: `drop_draft_test.dart` +3, `draft_grid_tile_test.dart` +4, `profile_drafts_tab_test.dart` +5, `create_drop_screen_test.dart` +10 [`Draft (WYN-036)` group, including the QA-added mode-switch regression test], `view_profile_screen_test.dart` updated 1 existing case for the new 5th tab)
- SQL regression scripts, each against a fresh throwaway Postgres 16 database under the real `authenticated` role (not superuser):
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS**
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_033_share_to_chat_test.sh` — **12/12 PASS**
  - `supabase/tests/wyn_034_redrop_test.sh` — **21/21 PASS**
  - `supabase/tests/wyn_035_poll_in_drop_test.sh` — **23/23 PASS**
  - `supabase/tests/wyn_036_draft_system_test.sh` — **15/15 PASS** (new this round)
  - **181/181 checks total across the 9 prior scripts, 196/196 including WYN-036's own** — no failures.
- Merge method: **merge commit** via GitHub (`claude/phase-3-wyn-035-5y4yfj` → `main`, PR #145). `origin/main` was confirmed a fast-forward ancestor of the feature branch before opening the PR (the branch was reset onto latest `main` after WYN-035's own PR #144 already merged, per this project's "designated branch already merged → restart from main" convention).
- GitHub PR status checks: not blocked on any failing check before merging, same non-blocking-preview precedent already established on prior Phase 3 PRs.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

16 files changed (2005 insertions, 153 deletions) merged into `main` via PR #145:

- **SQL** (`supabase/schema.sql`): new `valid_draft_poll_options()` IMMUTABLE function (structural-only: 2-4 options, ≤80 chars each, incomplete/duplicate options explicitly allowed). New `drop_drafts` table (`author_id`, nullable `image_url`/`caption`/`poll_options`/`poll_duration_days`, `created_at`/`updated_at`) with a `(author_id, updated_at desc)` index and 4 RLS policies (select/insert/update/delete), every one scoped strictly to `auth.uid() = author_id` with no other-party visibility at all. No changes to `drops`/`home_feed`/`notifications`/`reports`/any other existing table or view.
- **Flutter**: new `DropDraft` model (`fromMap`, `isPoll`). `DropRepository` gained `fetchDrafts()`, `saveDraft()` (upsert-by-id), `deleteDraft()`, and `createDropFromExistingImage()` (extracted a shared `_insertDropWithImageUrl()` helper from `createDrop()`). New `DraftGridTile` and `ProfileDraftsTab` widgets; `ViewProfileScreen` gained a 5th "ร่าง" tab (owner-only). `CreateDropScreen` gained a `draft` constructor param, `_prefillFromDraft()`, `_hasUnsavedContent`, a `PopScope`-driven close-intercept dialog (`_handleClose`/`_saveDraftAndClose`), and mode-aware draft-save gating (the QA fix).
- **New persisted regression test**: `supabase/tests/wyn_036_draft_system_test.sh` (15 checks, added to the same `supabase/tests/` suite as `wyn_021` through `wyn_035`).
- **Tests**: `app/test/drop_draft_test.dart` (new, 3 cases), `app/test/draft_grid_tile_test.dart` (new, 4 cases), `app/test/profile_drafts_tab_test.dart` (new, 5 cases), additions to `app/test/create_drop_screen_test.dart` (10 cases: the new "Draft (WYN-036)" group, including the QA-added mode-switch regression test), a fix to 1 existing case in `app/test/view_profile_screen_test.dart` (tab count 4→5), and `app/test/support/recording_drop_repository.dart` (fake `fetchDrafts`/`saveDraft`/`deleteDraft`/`createDropFromExistingImage` overrides).

Full history: `.wyn/tasks/approved/WYN-036-draft-system.md`.

## Deployment Result

**Merged to `main` via PR #145, pushed successfully.** This is the third task of **Phase 3 (Drop Enhancement)** to land on `main`, following WYN-034 (ReDrop) and WYN-035 (Poll in Drop). Users can now save an in-progress Drop or Poll as a private Draft instead of losing it on close, continue editing it later from a new "ร่าง" tab on their own Profile, publish it (which deletes the Draft automatically) or delete it directly — with no other user ever able to see it, enforced at the database layer via RLS rather than only hidden by the UI.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-035-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-fourth+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-036-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove the Draft system entirely — the close-intercept dialog, the "ร่าง" Profile tab, and every Draft-prefill path in `CreateDropScreen` would disappear — leaves WYN-021 through WYN-035 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by the `drop_drafts` table, its RLS policies/index, and the `valid_draft_poll_options()` function. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse, no data to migrate off of.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-036-specific manual step is needed beyond those.

With WYN-036 merged, **Phase 3 (Drop Enhancement)'s third task is code-complete**. Per the Roadmap, the remaining Phase 3 tasks are WYN-037 (Edit/Delete Drop), WYN-038 (View counting system), and WYN-039 (Private Account + Follow Request) — none started yet; the Founder has not yet been asked to confirm continuing further into Phase 3.
