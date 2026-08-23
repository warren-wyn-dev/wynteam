# Deployment Log — WYN-037 (Edit / Delete Drop)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-037 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session, continuing the same session-pattern WYN-034/035/036 established for Phase 3:

- **Product/Design**: Master Spec section 4 ("ผู้ใช้แก้ไข Drop ของตัวเองได้ ตั้งกฎได้ เช่น 'แก้ไขภายใน 30 นาที' และ: Delete, Soft Delete, Restore ในช่วงเวลาที่กำหนด — Admin ตรวจสอบประวัติได้") gave the exact edit window (30 minutes); Product picked 30 days for the restore window (not specified in the spec) mirroring familiar trash-retention UX (Gmail/Google Photos). Only the caption (or a Poll's question — same field) is editable, never the image or a Poll's options/duration. Delete is no longer a hard DELETE at all — replaced end-to-end by soft delete + restore. Full edit-history and an Admin review UI are explicitly out of scope this round (no WYN Admin web app exists yet to consume it) — only `edited_at` is tracked, driving a "แก้ไขแล้ว" badge.
- **Coding**: `drops` gained `edited_at`/`deleted_at` (both nullable). Every mutation to an existing Drop goes through one of 3 new SECURITY DEFINER RPCs — `edit_drop()` (owner + not deleted + within the 30-minute window), `soft_delete_drop()` (owner + not already deleted), `restore_drop()` (owner + deleted + within the 30-day window) — there is no client-facing raw UPDATE/DELETE on `drops` at all; the old self-delete RLS policy was removed outright. `drops`' SELECT policy was extended with `deleted_at is null or auth.uid() = author_id`, which alone hides a deleted Drop from Home Feed/Search/Profile/ReDrop everywhere, since `home_feed`/`saved_feed` are `security_invoker = true` views joining straight onto `drops` — no view redefinition needed. `drop_comments`' SELECT policy was extended the same way, closing an indirect leak soft-delete introduces (comments used to cascade-delete with a hard DELETE; they no longer do). Flutter: `EditDropCaptionScreen` (plain `TextField`, deliberately not `MentionInput`), `RecentlyDeletedDropsScreen` (reached from a new Settings entry), `DropDetailScreen`'s single delete `IconButton` replaced with a `more_vert` menu ("แก้ไข"/"ลบ"), a "แก้ไขแล้ว" badge, and a rewritten `confirm_delete_drop_dialog.dart` (no longer claims deletion is unrecoverable, for Drop specifically).
- **Independent QA — PASS (2 real bugs found and fixed before approval)**: read the full diff directly, ran `flutter analyze`/`flutter test` and all 11 SQL scripts independently. Found (1) `EditDropCaptionScreen` allowed saving a Poll's question as empty text, leaving live options/votes with nothing explaining them — fixed with an `isPollQuestion` flag requiring non-empty text in that case. Found (2), more serious: the `drop_comments` INSERT policy's own deleted-Drop check (`not exists (select ... from drops where deleted_at is not null)`) was self-defeating — that subquery is itself subject to `drops`' own SELECT RLS, which already hides a deleted row from anyone but its author, so for exactly the stranger the check exists to catch, the subquery always came back empty regardless of true deletion state, making the check a permanent no-op. Reproduced manually in `psql` (a stranger's comment insert on a deleted Drop succeeded, confirming the exploit) before fixing with a new SECURITY DEFINER helper, `internal.is_drop_deleted()` (mirroring the existing `internal.drop_author_id()`), that bypasses RLS to read the true state. Both fixes are covered by regression tests verified to fail against the original code and pass with the fix. Also caught and fixed 2 stale checks in `wyn_034_redrop_test.sh`/`wyn_035_poll_in_drop_test.sh` that relied on the now-removed hard DELETE policy (a raw `delete from drops` had silently become a 0-row RLS no-op) — updated both to call `soft_delete_drop()` instead and adjusted their expected values to match (ReDrop/`drop_polls`/`drop_poll_votes` rows no longer cascade away, since no real DELETE happens anymore).

Full history: `.wyn/tasks/approved/WYN-037-edit-delete-drop.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-037-edit-delete-drop.md`, `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified in this session, using this container's Flutter 3.x (stable) and a local Postgres 16 server:

- `flutter pub get`: clean (packages have newer versions available, none blocking — same as every prior deployment log)
- `flutter analyze`: **0 issues**
- `flutter test`: **597/597 pass** (576 baseline + 21 new for this task: `edit_drop_caption_screen_test.dart` +6 [4 original, 2 QA-added for the empty-poll-question fix], `recently_deleted_drops_screen_test.dart` +6, `drop_test.dart` +4, `drop_detail_screen_test.dart` +4 [`Edit/Delete (WYN-037)` group], `settings_screen_test.dart` +1)
- SQL regression scripts, each against a fresh throwaway Postgres 16 database under the real `authenticated` role (not superuser):
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_033_share_to_chat_test.sh` — **12/12 PASS**
  - `supabase/tests/wyn_034_redrop_test.sh` — **21/21 PASS** (CHECK21 updated for the soft-delete architecture change)
  - `supabase/tests/wyn_035_poll_in_drop_test.sh` — **23/23 PASS** (CHECK21 updated for the same reason)
  - `supabase/tests/wyn_036_draft_system_test.sh` — **15/15 PASS**
  - `supabase/tests/wyn_037_edit_delete_drop_test.sh` — **23/23 PASS** (new this round, includes the QA-added CHECK10c)
  - **212/212 checks total across the 10 prior scripts, 235/235 including WYN-037's own** — no failures.
- Merge method: **merge commit** via GitHub (`claude/phase-3-wyn-035-5y4yfj` → `main`, PR #147). The branch was restarted from latest `origin/main` before this task began (per this project's "designated branch already merged → restart from main" convention, since WYN-036's own PR #145/#146 had already merged it).
- GitHub PR status checks: not blocked on any failing check before merging, same non-blocking-preview precedent already established on prior Phase 3 PRs.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

19 files changed (2076 insertions, 26 deletions) merged into `main` via PR #147:

- **SQL** (`supabase/schema.sql`): `drops` gained nullable `edited_at`/`deleted_at`. New RPCs `edit_drop(p_drop_id, p_caption)`, `soft_delete_drop(p_drop_id)`, `restore_drop(p_drop_id)` (all SECURITY DEFINER, each row-locked via `for update` to prevent races) — the only way to mutate an existing Drop. The old "Users can delete their own drops" DELETE policy is dropped entirely. `drops`' SELECT policy extended with `deleted_at is null or auth.uid() = author_id`; `drop_comments`' SELECT policy extended to require its parent Drop still be visible. `drop_comments`' INSERT policy extended to reject comments on a deleted Drop, via the new `internal.is_drop_deleted()` SECURITY DEFINER helper (needed specifically because a plain RLS-filtered subquery would have been self-defeating — see the QA finding above). No changes to `home_feed`/`saved_feed`/`redrops`/`drop_polls`.
- **Flutter**: `Drop` model gained `editedAt`/`deletedAt` (nullable), `wasEdited`, and `withEditedCaption()`. `DropRepository.deleteDrop()` now calls the `soft_delete_drop` RPC instead of a raw DELETE (method name kept, call sites unchanged); new `editDrop()`, `restoreDrop()`, `fetchDeletedDrops()`. New `EditDropCaptionScreen` and `RecentlyDeletedDropsScreen`. `DropDetailScreen`'s own-Drop delete `IconButton` replaced with a `more_vert` menu; added the "แก้ไขแล้ว" badge. `confirm_delete_drop_dialog.dart` rewritten (no longer shared with `confirmDeletePost`, since its "cannot be recovered" copy is no longer true for a Drop specifically — comments/Pop are untouched and still use the original shared dialog). `SettingsScreen` gained a "รายการที่ลบ" entry.
- **New persisted regression test**: `supabase/tests/wyn_037_edit_delete_drop_test.sh` (23 checks, added to the same `supabase/tests/` suite as `wyn_021` through `wyn_036`). 2 existing scripts (`wyn_034`/`wyn_035`) updated for the architecture change.
- **Tests**: `app/test/edit_drop_caption_screen_test.dart` (new, 6 cases), `app/test/recently_deleted_drops_screen_test.dart` (new, 6 cases), plus additions to `app/test/drop_test.dart` (4 cases), `app/test/drop_detail_screen_test.dart` (4 cases: the new "Edit/Delete (WYN-037)" group), `app/test/settings_screen_test.dart` (1 case), and `app/test/support/recording_drop_repository.dart` (fake `editDrop`/`restoreDrop`/`fetchDeletedDrops` overrides, plus call-tracking added to the existing `deleteDrop` override).

Full history: `.wyn/tasks/approved/WYN-037-edit-delete-drop.md`.

## Deployment Result

**Merged to `main` via PR #147, pushed successfully.** This is the fourth task of **Phase 3 (Drop Enhancement)** to land on `main`, following WYN-034 (ReDrop), WYN-035 (Poll in Drop), and WYN-036 (Draft System). Users can now fix a typo in a Drop's caption (or a Poll's question) within 30 minutes of posting, and deleting a Drop no longer means losing it forever — it disappears from everyone else's view immediately but stays recoverable by its own author for 30 days from a new "รายการที่ลบ" screen in Settings.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-036-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-fifth+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-037-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove Edit/Delete entirely — the composer's "แก้ไข"/"ลบ" menu, the "แก้ไขแล้ว" badge, and the "รายการที่ลบ" Settings screen would disappear — and would need `drops`' old DELETE policy restored for self-delete to work again (this task removed it outright). Leaves WYN-021 through WYN-036 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by `drops.edited_at`/`deleted_at`, 3 new RPCs, `internal.is_drop_deleted()`, and 3 extended RLS policies (`drops` SELECT, `drop_comments` SELECT and INSERT). Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse, no soft-deleted rows to reconcile.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-037-specific manual step is needed beyond those.

With WYN-037 merged, **Phase 3 (Drop Enhancement)'s fourth task is code-complete**. Per the Roadmap, the remaining Phase 3 task is WYN-038 (View counting system) and WYN-039 (Private Account + Follow Request) — neither started yet; the Founder has not yet been asked to confirm continuing further into Phase 3.
