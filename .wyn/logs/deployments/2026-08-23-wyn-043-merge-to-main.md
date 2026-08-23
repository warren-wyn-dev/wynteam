# Deployment Log — WYN-043 (Notification Types) merged to `main`

```
Release: WYN-043 -- Notification Types (redrop crash fix, P0 + system notification type)
Version: N/A (no versioned build yet -- code-integration merge only, see Readiness Gate below)
QA Status: PASS (Independent QA, 2026-08-23 -- full report in .wyn/tasks/approved/WYN-043-notification-types.md, "Independent QA" section -- no findings at all)
Build Status:
  - supabase/tests/wyn_043_notification_types_test.sh: 10/10 PASS (run independently against a local PostgreSQL 16)
  - All 16 SQL regression scripts (wyn_021 through wyn_043): PASS, no cross-task regression
  - check_schema_ordering.py: clean, no forward references
  - Red->green proof independently reproduced for the redrop fix (reverted the _typeFromString case, confirmed the exact ArgumentError, restored it)
  - Adversarial probes beyond the committed test script: a SQL-injection-shaped message (stored as literal text, table intact), a nonexistent recipient (rejected by FK), a 10,000-character message (stored in full), and confirmation the function signature has no way to override actor_id
  - flutter analyze: 0 issues (Flutter stable SDK)
  - flutter test: 665/665 pass (659 baseline + 6 new)
  - GitHub PR #159 status checks: Vercel previews failed with "Deployment rate limited -- retry in 24 hours" (the same free-tier build-minute quota condition already documented in the WYN-030/040/041/042 deployment logs) -- an infra/quota condition unrelated to this diff, not a code or test failure. Netlify preview was still processing at merge time.
Deployment Target: `main` branch on GitHub only (warren-wyn-dev/wynteam) -- a code-integration step, not a deploy to any live/production/user-facing environment. See Readiness Gate below for why a real production deploy is still not possible.
Changes: PR #159 (`claude/wyn-40-continuation-ul5ngq` -> `main`, merge commit `02cbae7`, fast-forward-clean merge, no conflicts):
  - `notification.dart`: adds `NotificationType.redrop` (fixing the P0 crash -- `redrop` has been a valid `notifications.type` value since WYN-034, but the Flutter enum/parser never recognized it) and `NotificationType.system` (new). Doc comments on `actorId`/`reason` updated to note `system`'s null-actor, `reason`-carries-the-message shape.
  - `notification_list_screen.dart`: `_messageFor`/`_openNotification` gain cases for both new types (`redrop` opens the original Drop, mirroring `likeDrop`/`mentionDrop`; `system` is a no-op tap since its message is shown in full already). `_hidesActorIdentity` now also covers `system` (null actor, same as the 4 moderation/appeal types), and a new `_noActorIconFor()` helper gives `system` its own icon (`Icons.campaign_outlined`) instead of reusing `Icons.shield_outlined`.
  - `supabase/schema.sql`: `notifications_type_check` gains `'system'`. New `public.send_system_notification(p_recipient_id uuid, p_message text)` (`SECURITY DEFINER`, `plpgsql`) -- rejects any caller whose `platform_role <> 'admin'`, rejects a blank/null message, and inserts with `actor_id = NULL`, `type = 'system'`, the message in `reason`. Single-recipient only; no broadcast-to-all mechanism in this round.
  - New `supabase/tests/wyn_043_notification_types_test.sh` (10 checks) added to the persisted regression suite.
Deployment Result: Merged to `main` via PR #159, pushed successfully. `origin/main` now at commit `02cbae7`, verified matching local `main` after fetch. `main` previously sat at `6aef583` (the WYN-042 deployment-log entry). This merge starts Phase 5 (Notification & Settings Expansion) on `main`.
Production Verification: Not applicable -- no production environment exists. Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`, `.wyn/logs/deployments/2026-08-23-wyn-042-merge-to-main.md`) -- re-verified directly in this session, not assumed:
  - No real Supabase project -- `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
  - No native OAuth/Firebase config -- no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
  - No distribution channel (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
  - No CI pipeline -- `.github/workflows/` does not exist.
  - No Android SDK/Xcode in this sandbox -- `flutter build apk`/`flutter build ipa` cannot be attempted here.
  This is now the twenty-second+ approved batch in this project's history to reach this exact same gate -- all "approved, merged to `main`, waiting for real infra." Not a WYN-043-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.
Rollback Plan:
  - Code: `git revert` the merge commit `02cbae7` on `main` restores the pre-merge state. Reverting reintroduces the redrop crash bug (a regression to a worse state than before this PR, since the bug already existed on `main` before this merge -- if reverted, `redrop` and `system` notifications would both go back to crashing `WynNotification.fromMap`) and removes `send_system_notification()` entirely. Leaves WYN-005 through WYN-042 untouched, since those are separate, earlier merges.
  - Database: `supabase/schema.sql` grew by one new function (`send_system_notification`), its `grant execute`, and one new allowed value (`'system'`) in `notifications_type_check` -- no new tables, no column additions to any existing table, no altered RLS policy. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" -- no live migration to reverse.
  - Distribution: not applicable -- nothing has been distributed to any real device/store.
```

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from the WYN-042 deployment log's Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-043-specific manual step is needed beyond those.

**Phase 5 (Notification & Settings Expansion)** has begun with this task. Two follow-up ideas were flagged during WYN-043 and are worth Founder consideration for a future task:
1. **"Trending/Top 100 Notification Engine"** — needs new cron/scheduled-job infrastructure (there is none anywhere in this project yet) plus a snapshot/diff mechanism to detect "newly trending" state changes, since Trending/Top 100 rankings (WYN-041/042) are computed transiently on every fetch with nothing persisted server-side.
2. **A `send_system_notification()` broadcast-to-all mode** — the current RPC is single-recipient only by design; a true announcement blast to every user would need its own task to design a safe bulk-insert approach.

The remaining Phase 5 tasks per the roadmap are **WYN-044** (Notification Settings — per-type opt-in/opt-out) and **WYN-045** (a full Settings screen consolidating Account/Privacy/Security/Safety/Data/Legal).
