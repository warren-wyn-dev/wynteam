# Deployment Log — WYN-044 (Notification Settings)

Release: code-integration push to the designated session branch (not `main`, and not a production/end-user deploy — see "Deployment Target" and Readiness Gate below)
Date: 2026-08-24

## QA Status

**PASS** — WYN-044 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session, continuing directly from WYN-043 (Phase 5's first task). Full report: `.wyn/tasks/approved/WYN-044-notification-settings.md`'s "Independent QA" section.

- **Product/Design**: 6 opt-out notification categories (Likes & ReDrop, Comments & Mentions, Follows, Messages, Club, System) mapped from the 24 `NotificationType` values that exist in the codebase today. Moderation/Appeal (4 types, account-safety info) and ZOKY order notifications (4 types, a feature unreachable since WYN-024 removed the ZOKY tab) are deliberately never gated. Data model: a new `notification_settings` table (lazy upsert — no row until the user's first toggle, no backfill for existing accounts), with "missing row = every category enabled" as the single most important semantic (called out explicitly in the Product spec's Risks as more dangerous than WYN-043's redrop crash, since a wrong default here fails silently).
- **Coding caught a real gap before writing any SQL**: the first draft of the Product spec's category mapping only covered 23 of the 24 notification types — `redrop` had no category at all. Fixed by revising both the Product and Design specs (folding `redrop` into the Likes category) before implementation, documented inline in both files.
- **Coding**: new `internal.notification_category_enabled()` helper (mirrors `internal.is_blocked_either_way()`/`internal.is_drop_deleted()`) and `public.set_notification_category_enabled()` RPC (upserts exactly one category). 15 `notify_*` trigger functions plus `accept_follow_request()`, `get_or_create_conversation()`, and `send_system_notification()` (18 functions total) redefined via `create or replace function` — appended at the end of `schema.sql`, mirroring this project's established "later definition wins" convention already used for `drops`' RLS policy history across WYN-027/037/039. New `NotificationSettingsScreen` (6 `SwitchListTile`, fail-open on a failed fetch) wired into `SettingsScreen`'s new "การแจ้งเตือน" section.
- **Independent QA — PASS (no defects found)**: re-ran every test independently rather than trusting Coding's self-report, read the full diff adversarially, and ran 3 additional adversarial probes beyond the regression suite (`NULL` value rejected without corrupting the affected column, an uppercase category name rejected rather than silently matching, a direct cross-user insert attempt rejected by RLS). Also verified — as a bonus finding, not a defect — that the existing `send-push-notification` Edge Function (WYN-016) fires from a Database Webhook on `notifications` INSERT, so gating the insert itself automatically gates the FCM push too, with no separate bypass path.

Full history: `.wyn/tasks/approved/WYN-044-notification-settings.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-044-notification-settings.md`, `.wyn/company/CONTEXT.md` (2026-08-24 entries).

## Build Status

Verified in this session, using this container's Flutter 3.47.1 (stable, installed fresh this session — the sandbox had no Flutter SDK pre-installed) and a local Postgres 16 server:

- `flutter pub get`: clean (same set of "newer versions available, none blocking" as every prior deployment log)
- `flutter analyze`: **0 issues**
- `flutter test`: **676/676 pass** (665 baseline + 11 new: `notification_settings_test.dart` 6 cases, `notification_settings_screen_test.dart` 5 cases, `settings_screen_test.dart` +1 case)
- SQL regression scripts, each against a fresh throwaway Postgres 16 database under the real `authenticated` role (not superuser):
  - All 16 prior scripts (`wyn_021` through `wyn_043`) — **all PASS**, no cross-task regression
  - `supabase/tests/wyn_044_notification_settings_test.sh` — new this round, **20/20 PASS**
- `supabase/check_schema_ordering.py` — **OK, no forward references**
- Merge method: **N/A this round** — see Deployment Target below for why this stops at a branch push rather than a `main` merge.

## Deployment Target

**`claude/phase-7-continuation-5s8by3` on GitHub only** (`warren-wyn-dev/wynteam`) — pushed via `git push -u origin`, not merged into `main`.

This is a deliberate deviation from this project's own established convention (every prior task, WYN-034 through WYN-043, merged its session branch into `main` via a GitHub PR as its "deploy" step). The reason is specific to *this* session's operating environment, not a change to WYN's own process: this session runs under an explicit instruction not to open a pull request unless a human explicitly asks for one, and no such request was made this round (the Founder's instruction this session was simply "Phase 7 ต่อ" / "continue"). Opening and merging a PR autonomously here would go beyond what was actually asked. The code itself is exactly as ready to merge as every prior approved task — QA passed with no findings, and the branch is a normal fast-forward off `main`'s current tip (`ff55b89`, WYN-043's own merge commit) — nothing here is a technical blocker, only a scope-of-authorization one.

**Next Steps for the Founder**: say the word (e.g. "เปิด PR", "merge WYN-044 เข้า main") and this gets opened as a PR and merged the same way every prior task was, or merge `claude/phase-7-continuation-5s8by3` into `main` directly.

## Changes

13 files changed (1869 insertions, 1 deletion), committed as `852a166` on `claude/phase-7-continuation-5s8by3`:

- **SQL** (`supabase/schema.sql`): new `notification_settings` table + RLS (owner-only SELECT/INSERT/UPDATE) + `internal.notification_category_enabled()` + `public.set_notification_category_enabled()`. 18 existing functions redefined to add a gate check before their `insert into notifications`.
- **New SQL regression test**: `supabase/tests/wyn_044_notification_settings_test.sh` (20 checks).
- **Flutter**: `notification_settings.dart` (model), `notification_settings_repository.dart`, `notification_settings_screen.dart` (all new), `settings_screen.dart` (new "การแจ้งเตือน" section).
- **Tests**: `app/test/notification_settings_test.dart` (new, 6 cases), `app/test/notification_settings_screen_test.dart` (new, 5 cases), `app/test/support/recording_notification_settings_repository.dart` (new fake), `app/test/settings_screen_test.dart` (+1 case).
- **Docs**: `.wyn/tasks/approved/WYN-044-notification-settings.md`, `.wyn/docs/design/wyn-044-notification-settings.md`, `.wyn/company/CONTEXT.md` updated.

Full history: `.wyn/tasks/approved/WYN-044-notification-settings.md`.

## Deployment Result

**Pushed successfully to `claude/phase-7-continuation-5s8by3`.** Code-complete and QA-approved; not yet merged into `main` (see Deployment Target above for why, and what unblocks it).

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since every prior assessment, e.g. `.wyn/logs/deployments/2026-08-23-wyn-043-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo (this also means `send-push-notification`'s Edge Function, referenced in this task's QA notes, cannot actually deliver a push yet either).
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-eighth+ approved batch** in this project's history to reach this exact same gate. None of this is WYN-044-specific; it is a whole-project blocker that needs Founder action.

## Rollback Plan

- **Code**: nothing has touched `main` yet, so there is nothing to revert there. Reverting on the session branch itself is a plain `git revert 852a166` (a normal commit, not a merge commit).
- **Database**: `supabase/schema.sql` grew by 1 new table (`notification_settings`), 2 new functions, and 18 redefined functions (each adding one gate condition, no other logic changed). Since there is no live database yet, "rollback" means "don't apply this `schema.sql` version" — no live migration to reverse, no rows to reconcile.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated.

**New this round**: whether to merge `claude/phase-7-continuation-5s8by3` into `main` (see Deployment Target above) — this one is a quick yes/no, not an infrastructure project. With WYN-044 code-complete, Phase 5's remaining task is WYN-045 (Settings screen เต็มรูปแบบ) — not started yet.
