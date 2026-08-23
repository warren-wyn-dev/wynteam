# Deployment Log — WYN-030 (Appeal System) — Independent QA Round 2 catch-up merge

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## Context — why this is a separate log entry from `2026-08-22-wyn-030-merge-to-main.md`

The first WYN-030 merge (PR #133 + PR #134, logged at `.wyn/logs/deployments/2026-08-22-wyn-030-merge-to-main.md`) landed commit `3fd2c8a` on `main` (as `17027ba`). At that time the "Independent QA — Round 1" section shipped with the feature had actually been written by the **same session/agent as Coding** (both in commit `5edb995`) — self-QA, not a genuinely independent QA pass, breaking the process every other Phase 1 task (WYN-026/027/028/029) had followed correctly.

A separate QA session caught this after the first merge had already happened, and ran a real independent Round 2 (own session, re-read the diff, re-ran `flutter analyze`/`flutter test` fresh, re-ran `wyn_027`/`wyn_029` regression, found and closed **4 real coverage gaps** in the persisted `wyn_030_appeal_system_test.sh` script — Suspend/Ban-approved `overturned_at` flip had only been "verified by hand," `anon` role was never tried against `submit_appeal()`/`decide_appeal()` (the same class of gap WYN-027 hit — Postgres grants EXECUTE to PUBLIC by default), re-deciding an already-decided appeal was never tested, and `get_my_moderation_action()`'s cross-user scoping was never tested) — committed as `b855676` on `claude/wyn-030-appeal-system`. Verdict unchanged (still PASS), now backed by real independent verification (24/24 → **31/31**).

**`b855676` was created after PR #133/#134 had already merged**, so it was never brought into `main`. This deployment log covers merging that remaining commit.

## QA Status

**PASS** (unchanged verdict, now genuinely independently verified — see `.wyn/tasks/approved/WYN-030-appeal-system.md`'s "Process Flag" and "Independent QA — Round 2" sections, and `.wyn/company/DECISIONS.md`'s 2026-08-23 entry for the full account).

This session re-verified independently before merging (not just trusting the branch's own report):
- Read the branch's git log/diff directly, confirmed `b855676` was not an ancestor of `origin/main` before merging (`git merge-base --is-ancestor b855676 origin/main` → false).
- `flutter analyze`: **0 issues** (fresh run, this session).
- `flutter test`: **451/451 pass** (fresh run, this session).
- `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`: **9/9 PASS** (fresh Postgres 16 database, this session).
- `supabase/tests/wyn_029_moderation_queue_test.sh`: **36/36 PASS** (fresh Postgres 16 database, this session).
- `supabase/tests/wyn_030_appeal_system_test.sh`: **31/31 PASS** (fresh Postgres 16 database, this session — confirms the 4 new adversarial checks from Round 2 pass for real, not just per the QA session's own report).

## Build Status

- `flutter pub get`: clean (same 21 packages with newer versions available, none blocking).
- `flutter analyze`: **0 issues**.
- `flutter test`: **451/451 pass**.
- Flutter 3.47.1 (stable) from `/home/user/flutter`.
- Merge method: **merge commit** (not fast-forward — `main` had advanced past `b855676`'s parent via the PR #133/#134 merges, so a real 2-parent merge was required):
  1. `git checkout main && git merge --ff-only origin/main` — local `main` fast-forwarded `fc952dd..839eb00` (10 commits, all already-known WYN-030 work from PR #133/#134).
  2. `git checkout claude/wyn-030-appeal-system && git merge main` — **1 conflict** in `.wyn/company/CONTEXT.md` (both `main` and the branch had appended a different bullet to the same WYN-030 section independently). Resolved by keeping both bullets, ordered chronologically (the PR #133/#134 merge note first since it happened at an earlier commit, the process-flag note second), plus a short note flagging that `b855676` itself still needed a separate merge. Committed as `5d1a621`.
  3. Ran `flutter analyze`/`flutter test` and all 3 SQL regression scripts fresh on the merged tree (results above) before pushing anything.
  4. Pushed `claude/wyn-030-appeal-system` (`b855676..5d1a621`), then `git checkout main && git merge --no-ff claude/wyn-030-appeal-system` (commit `19e6668`, clean — only the 4 files `b855676` had touched came through, no further conflicts since `5d1a621` already contained everything `main` had).
  5. Pushed `main` directly (`839eb00..19e6668`) — no branch protection blocked a direct push; no PR was opened for this step since the substantive review (Independent QA Round 2) already happened on the branch before this merge.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below.

## Changes

4 files changed (169 insertions, 3 deletions) merged into `main` (`839eb00..19e6668`, via merge commit `19e6668`, carrying `b855676`):

- `.wyn/company/CONTEXT.md` — added the "แก้ไข process flag" note (already present on the branch, carried through unchanged by this merge; the CONTEXT.md conflict itself was resolved in the earlier `5d1a621` commit, not part of `b855676`'s own diff).
- `.wyn/company/DECISIONS.md` — the 2026-08-23 process-flag decision entry.
- `.wyn/tasks/approved/WYN-030-appeal-system.md` — new "Process Flag" and "Independent QA — Round 2" sections.
- `supabase/tests/wyn_030_appeal_system_test.sh` — 4 new checks (`CHECK21`–`CHECK24b`), regression script now 31 checks total (up from 24).

No `schema.sql` or Dart source changes in this merge — Round 2 QA found and closed test-coverage gaps, it did not need to change any application code (the underlying behavior it verified was already correct).

Full history: `.wyn/tasks/approved/WYN-030-appeal-system.md`, `.wyn/company/DECISIONS.md` (2026-08-23), `.wyn/logs/deployments/2026-08-22-wyn-030-merge-to-main.md` (the original merge this one completes).

## Deployment Result

**Merged to `main`, pushed successfully.** `origin/main` now at commit `19e6668`, verified via `git fetch origin && git merge-base --is-ancestor b855676 origin/main` returning true. `main` previously sat at `839eb00` (PR #134's deployment-log merge); this merge brings the genuinely-independent WYN-030 QA Round 2 work onto `main` for the first time. **Phase 1 (Safety & Trust Foundation) is now code-complete on `main` with every task's QA verdict backed by a real independent QA pass** — WYN-026/027/028/029/030 all merged, and WYN-030 specifically no longer carries the self-QA process gap the earlier merge had unknowingly shipped with.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since every prior assessment, e.g. `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`, `.wyn/logs/deployments/2026-08-22-wyn-030-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **nineteenth+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." This has never been a WYN-030-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert -m 1 19e6668` on `main` restores the pre-merge state (a merge-commit revert, since this has two parents). Reverting would remove only the 4 files this merge touched (the Round 2 QA process-flag documentation and the 7 extra regression-script checks) — it would **not** remove the Appeal System feature itself, which landed in the earlier `17027ba`/`d520abb` merge and is untouched by this one.
- **Database**: no schema change in this merge — nothing to roll back at the database layer.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from the previous WYN-030 deployment log's Next Steps — real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment, plus the standing one-time `platform_role` promotion for the Founder's account once real infra exists (from WYN-029).

**Phase 1 (Safety & Trust Foundation — Report → Moderation → Appeal, per the Master Spec) is now fully code-complete on `main`, with every task's QA verdict backed by a genuinely independent QA pass.** Per the WYN-030 task file's own Recommendation, the suggested next step for AI Product Manager is to re-check Phase 2 (WYN Chat) readiness before starting it, since Phase 2 has a direct dependency on WYN-027/028 (Block/Mute), both already merged and QA-verified.
