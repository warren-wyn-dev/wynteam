# Deployment Log — WYN-029 (Moderation Queue + Action)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-22

## QA Status

**PASS** — WYN-029 went through a full two-round independent QA cycle (separate session from Coding, not self-QA):

- `.wyn/tasks/approved/WYN-029-moderation-queue.md` — **Independent QA — Round 1 (FAIL, Major)**: reviewed schema.sql diff independently, ran the persisted 32-case SQL regression script, re-ran `wyn_021`/`wyn_027` for cross-task regression, ran `flutter analyze`/`flutter test` independently (426/426), plus extra input-validation probing not in the ACs — all passed. Then found a **Major finding beyond the ACs**: `apply_moderation_action()` inserted the reviewing moderator's real `auth.uid()` as `notifications.actor_id` for Warning/Remove Content notifications. `notifications`' SELECT policy is row-level (`recipient_id = auth.uid()`), so the target user could fetch the moderator's identity (username, display name) via the exact same join query `notification_repository.dart` already uses, or via a raw REST call — `NotificationListScreen`'s `_hidesActorIdentity()` only hid it in the UI, not at the data-access layer. Same mistake class as the WYN-027 `is_blocked_either_way` RPC-exposure bug (mitigating at the UI layer instead of closing the actual data boundary). Full report: `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` (now closed).
  - AI Debug Engineer fixed it (commit `1595d6f`): relaxed `notifications.actor_id` to nullable, `apply_moderation_action()` now inserts `NULL` instead of the reviewer's `auth.uid()` for Warning/Remove Content, made `WynNotification`/`notification_list_screen.dart` null-safe.
  - **Independent QA — Round 2 PASS**: re-verified the fix independently — reviewed the real diff of `1595d6f`, ran `flutter analyze` (clean), ran the expanded 36-case SQL regression script (36/36), **built a fresh separate Postgres 16 database** (not reused from Debug) with its own newly-written probes (not reused from Debug), reproduced the exact Round 1 leak scenario (moderator "Secret Moderator" warns Alice), confirmed both an INNER JOIN (0 rows) and a **LEFT JOIN** (to rule out the join simply filtering out non-matching rows rather than the data genuinely being absent) — `actor_id`/`actor_username` came back **NULL, not just unmatched** — confirming the leak is genuinely closed at the data layer, not merely hidden from one query shape. Also re-verified `moderation_actions` (the real audit trail) stays protected (target sees 0 rows), re-ran `wyn_021`/`wyn_027` (no cross-task regression), and ran `flutter test` independently (433/433, matching Debug's reported count).

Full history: `.wyn/tasks/approved/WYN-029-moderation-queue.md` (Design/Coding/Independent QA Round 1/Round 2 sections), `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` (closed).

## Build Status

Re-verified independently at the new `main` HEAD (post-merge, not just the feature branch's own numbers), using Flutter 3.47.1 (stable) from `/home/user/flutter`:

- `flutter pub get`: clean (21 packages have newer versions available but none are blocking; no resolution errors)
- `flutter analyze`: **0 issues**
- `flutter test`: **433/433 pass** (0 failures; the `NetworkImage` warm-up lines seen mid-run are expected test-environment noise from stubbed image URLs, not failures)
- Merge method: **fast-forward** (`claude/wyn-029-moderation-queue` → `main`, commit `83ce961..b04d455`, no conflicts). Verified before merging that `main` (`83ce961`, matching `origin/main`) is the exact `git merge-base` of `main` and the feature branch, and that `git merge-base --is-ancestor main claude/wyn-029-moderation-queue` confirmed a fast-forward was possible before running `git merge --ff-only`.
- SQL regression scripts re-run against a fresh local Postgres 16 (already running as cluster `16/main`, port 5432) at the new `main` HEAD, each script builds and drops its own throwaway database:
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - No failures post-merge — the merge itself did not disturb anything the independent QA rounds had already verified.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

44 files changed (5578 insertions, 162 deletions) merged into `main` (`83ce961..b04d455`):

- **Platform Role foundation**: new `platform_role` column on `profiles` (`user`/`moderator`/`admin`, default `user`) protected by a **two-layer self-escalation guard** — INSERT policy pins `platform_role = 'user'` regardless of what a client sends, and an UPDATE trigger (`profiles_prevent_platform_role_change`, mirrors `clubs_prevent_owner_id_change`) blocks any client-side change entirely. No client-facing UI or RPC can change it in this round — promotion is a manual superuser SQL operation only (see "Next Steps" below).
- **Moderation Queue**: `moderation_queue` view (deliberately **not** `security_invoker` — re-implements caller-based visibility itself via `internal.current_platform_role() <> 'user'`, so `reporter_id` is structurally unreachable to a moderator even via a raw REST call, not merely omitted from a hand-picked column list — `reports`' own reporter-only SELECT policy is untouched), `moderation_actions` table (`report_id`/`target_user_id`/`action_type`/`reason`/`duration_days`+`expires_at`/`reviewer_id`), `apply_moderation_action()` RPC (single atomic entry point: validates caller is moderator/admin, validates reason/duration, locks the report row via `select ... for update` as the double-action guard, resolves the target account the same way `submit_report()` already does, writes the audit row, closes the report, performs the action's real effect).
- **6 actions**: No Action (dismiss), Warning (notification, no restriction), Remove Content (hard-delete on Drop/Comment/Club Post), Restrict (1/3/7-day posting block, still can browse/like/follow), Suspend (1/3/7-day full login block with forced logout of existing sessions), Ban (permanent login block, no auto-expire, manual unban only via SQL).
- **Enforcement at the RLS layer, not just UI**: `internal.is_posting_blocked()`/`internal.current_platform_role()` helpers (both in `internal` schema per the WYN-027 lesson — not exposed to PostgREST), wired into `drops`/`drop_comments`/`clubs`/`club_posts`/`club_post_comments` INSERT policies. `get_my_moderation_status()` RPC is the single source of truth for both `AuthGate`'s login gate and the `RestrictionBanner` UI. Auto-expiry is inherent to the `expires_at > now()` comparison at every enforcement point — no cron/batch job. **Pop untouched** (no `pops`/`pop_comments` policy change, no `pop_*.dart` file touched, per the standing Pop-suspended decision).
- **Dart**: new `app/lib/features/moderation/**` (`ModerationRepository`, `ModerationReport`/`ModerationActionType`/`ModerationStatus`/`ModerationTargetSummary` models, `ModerationQueueScreen`, `ModerationReportDetailScreen`, `ModerationActionSheet`), `AccountRestrictedScreen` + `AuthGate` changes for the Suspend/Ban login block (force sign-out, then show the restricted-state screen from local `State`, not derived live from the auth stream — avoids a race where the reason/expiry text would vanish the instant `signOut()` completes), `RestrictionBanner` (new shared widget) wired into `CreateDropScreen`, `DropDetailScreen`'s comment composer, `ClubPostDetailScreen`'s comment composer, `CreateClubScreen`, `SettingsScreen` gets a hidden "เครื่องมือผู้ดูแล" entry point gated on `platformRole` passed from the already-fetched profile (no extra query, no client-supplied override path).
- **Notification integration**: 2 new `NotificationType` values (`moderation_warning`/`moderation_content_removed`) reuse the existing Notification system (WYN-012) instead of new UI — reviewer identity is hidden at the data layer, not just the UI, following the Round 1→Round 2 fix (`notifications.actor_id` is `NULL` for these two types, never the real moderator).
- Bug-fix commit `1595d6f` (actor-identity-leak fix) and both QA-round documentation commits (`fdcf7be` Round 1 FAIL, `b04d455` Round 2 PASS) are included in this merge.

Full history: `.wyn/tasks/approved/WYN-029-moderation-queue.md`, `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` (closed).

## Deployment Result

**Merged to `main`, pushed successfully.** `origin/main` now at commit `b04d455`, verified matching local `main` after push (`git fetch origin main` + `git rev-parse origin/main main` both returned `b04d455`). `main` previously sat at `83ce961` (the WYN-026/027/028 merge log entry); this fast-forward brings WYN-029 (Moderation Queue + Action), including the actor-identity-leak fix and both rounds of independent QA documentation, onto `main` for the first time.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`, `.wyn/logs/deployments/2026-08-22-wyn-026-027-028-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)` (compile-time `--dart-define`), currently unset anywhere in the repo (correctly — never hardcode real credentials). No `supabase/config.toml` exists either.
- **No native OAuth/Firebase config** — searched the whole repo for `google-services.json`/`GoogleService-Info.plist`: none found.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist in the repo.
- **No Android SDK/Xcode in this sandbox** — this session's environment has a working Flutter SDK (found at `/home/user/flutter`, version 3.47.1 stable, confirmed by running `flutter analyze`/`flutter test` successfully) but `flutter build apk`/`flutter build ipa` cannot be attempted (`which xcodebuild` empty, `ANDROID_HOME`/`ANDROID_SDK_ROOT` unset, no `adb`/`sdkmanager` on PATH).

This is now the **seventeenth+ approved batch** in this project's history to reach this exact same gate (WYN-005/006/007/008/009/012/013/014/015/019-022/ZOKY-001-004/SELLER-001+/WYN-024/DS-009/WYN-026/027/028/**WYN-029**) — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-029-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment — verified directly rather than assumed.

## Rollback Plan

- **Code**: `git revert` the merge range on `main` (`83ce961..b04d455`, i.e. revert commits `f994c4f`, `3ef84b4`, `24afe2d`, `fdcf7be`, `1595d6f`, `b04d455` as a group) restores the pre-merge state exactly — no destructive history rewrite needed since this was a fast-forward, not a squash/rebase. Note: reverting would re-introduce the moderation-actor-identity leak that Round 2 QA closed, so a full revert is discouraged; if a partial rollback is ever needed, revert only from `main`'s tip backward to no further than `83ce961` and never ship `83ce961`'s state to any real backend if the goal is to keep the Moderation Queue feature disabled while retaining the WYN-026/027/028 security fixes.
- **Database**: `supabase/schema.sql` grew by the `platform_role` column + guards, `moderation_actions` table, `moderation_queue` view, the `apply_moderation_action()`/`get_my_moderation_status()` RPCs, the `internal.is_posting_blocked()`/`internal.current_platform_role()` helpers, RLS enforcement additions on `drops`/`drop_comments`/`clubs`/`club_posts`/`club_post_comments`, and the `notifications.actor_id` nullable relaxation + 2 new `NotificationType` values. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse. Once a real Supabase project exists, standard practice will be to version schema changes as separate migration files rather than one monolithic `schema.sql` apply, so a real rollback path exists in production.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

To make an actual production deploy possible for WYN-029 (and everything already queued behind this same gate):

1. **Create a real Supabase project** (requires Founder: real account, billing) and run `supabase/schema.sql` against it. While setting it up, also create `supabase/config.toml` with `[api] schemas = ["public"]` explicit (still an outstanding Minor recommendation from WYN-027's Round 2 QA).
2. **Set up native OAuth Client ID (Google) + Apple Developer account** (Apple Sign-In capability) — required since WYN-002, still outstanding.
3. **Add real `google-services.json`/`GoogleService-Info.plist`** (unblocks WYN-016 Push Notifications too).
4. **Choose and configure a distribution channel** (TestFlight / Play Internal Testing / Firebase App Distribution) — Founder previously approved "Internal Testing" as the target (see `.wyn/company/DECISIONS.md`, 2026-08-13).
5. **Provide an environment with Android SDK/Xcode** for real `flutter build` release artifacts, or a CI pipeline that has them.
6. **WYN-029-specific manual step, beyond the generic infra above**: promote the Founder's own account to `platform_role = 'admin'` — this cannot be done through any app UI or client-facing RPC by design (the whole point of the two-layer self-escalation guard). Once a real Supabase project exists and the Founder has a real `profiles` row, run this exact 3-statement sequence directly in the Supabase SQL editor (documented inline in `supabase/schema.sql` next to `profiles_prevent_platform_role_change`), as a superuser/table owner — the `authenticated` role PostgREST clients run as has no `ALTER TABLE` privilege, so no client can ever do this itself:
   ```sql
   alter table public.profiles disable trigger profiles_prevent_platform_role_change;
   update public.profiles set platform_role = 'admin' where id = '<founder-auth-uid>';
   alter table public.profiles enable trigger profiles_prevent_platform_role_change;
   ```
   Without this step, the Moderation Queue entry point in Settings will never appear for anyone (it's gated on `platformRole != 'user'`), and no report will ever get reviewed even after the app itself is deployed and working.

AI Deploy & DevOps can execute steps 2-5's technical configuration once step 1's account/project exists; step 1 itself requires Founder action (real account, billing) and cannot be done by the AI team per `.wyn/company/RULES.md`. Step 6 is a one-time manual SQL operation that only the Founder (or someone acting with direct database superuser access, which the AI team does not have in production) can run, since by design no automated/client path exists to perform it.
