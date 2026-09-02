# Deployment Log — WYN-077 (Basic Product Analytics) — DEPLOYED

```
Release: WYN-077 (self-hosted product analytics: signup funnel, activation, D1/D7 retention, top signup sources — Admin Dashboard "Growth" section)
Version: main.dart.js built via GitHub Actions run 33686337670 (run #37) from `main` @ `8dc18d4`, workflow_dispatch. Supersedes run #36 (`b87872c`) — see "Two deploy runs" below for why a second one was needed.
QA Status: PASS — 2 rounds on the original feature (see `.wyn/tasks/approved/WYN-077-basic-product-analytics.md`). A 3rd, narrower issue (see below) was found and fixed post-merge by this same session acting as Deploy & DevOps, not re-routed through full QA (single-file, single-line addition, already-reviewed content that simply hadn't been committed the first time).
Build Status: Admin (Next.js) — `npm install && next build && npm run lint` run for real in this session at each stage (original PR, and again after merging PR #210/#212's onboarding rework), all clean. Flutter app — built for real inside GitHub Actions (no local SDK in this sandbox at any point) — both run #36 and #37 completed with conclusion `success`.
Deployment Target: (1) Supabase project `kqokpocajhfbidcxpvhh` (production database) — migration prepared and verified, Founder said they'd run it via Supabase Dashboard SQL Editor before this deploy (unconfirmed from this session's side — see below). (2) Vercel project "web" (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), production URL https://wynos.online, via `deploy-web.yml`. (3) Admin dashboard (`admin/`) — **still has no live deployment at all** (pre-existing gap since WYN-049, unrelated to this task) — the Growth section's UI has nowhere to go live until Founder sets up that Vercel project for the first time.
Changes: `analytics_events` table (new, insert-only RLS) + `admin_dashboard_metrics()` extended with 8 Growth columns (SQL); `AnalyticsRepository` (new) wired into `EmailAuthScreen`, `CreateDropScreen`, `RootShell`, and `OnboardingFlow` (Admin dashboard code-ready, not yet deployable per above).
```

## Merge conflict with a concurrent PR (#210/#212)

Between this session forking its branch and opening its PR, a *different* concurrent session merged PR #210 — "WYNOS First Login / Account Onboarding" — which:
- **Also used task ID "WYN-077"** for a completely different feature (a naming collision from two sessions picking the same next-available number independently; not resolved here, flagged for a future cleanup pass — see `.wyn/company/CONTEXT.md`).
- Deleted `app/lib/features/auth/presentation/username_setup_screen.dart` (this task's original `signup_completed` hook point) in favor of a new multi-step `OnboardingFlow` (Birthday → Username → Display Name → Password → Profile Optional → Finish).
- Added `supabase/schema.sql` content in a non-overlapping region of the file (auto-merged cleanly — verified with `git merge-base --is-ancestor` and a direct diff, not assumed).
- Added a `profiles_username_not_reserved` CHECK constraint that broke the *pre-existing* `wyn_050_admin_dashboard_test.sh`'s own fixture data (`username: 'admin'`/`'moderator'`, both now-reserved words) — fixed by renaming the fixture's usernames to `test_admin1`/`test_mod1`, not by touching the constraint.

Resolved by moving `logSignupCompleted()` into `OnboardingFlow._enterWynos()` (the new equivalent "onboarding just finished" moment), re-verified `wyn_050`/`wyn_077`'s SQL tests (17/17, 11/11) and the admin build/lint against the fully merged tree before opening PR #211.

## Two deploy runs — a staging mistake, caught and fixed same-session

Run #36 (`b87872c`, PR #211) deployed successfully, but **the `logSignupCompleted()` call written during the merge above was never actually committed** — it was made via an edit that sat unstaged while a separate `git add` only staged one other file before the merge commit. Caught by this session's own stop-hook flagging an uncommitted change immediately after the deploy, not by an external report. Impact was narrow: `EmailAuthScreen`/`CreateDropScreen`/`RootShell`'s analytics calls were all committed and deployed correctly in run #36 — only the `OnboardingFlow` completion event was missing, meaning the Growth dashboard's `signup_completed`/conversion/activation/retention columns simply wouldn't have populated yet (no crash, no broken UI, just quietly incomplete data).

Fixed as a small follow-up (PR #213, 1 file, 10 lines) re-applied against `main`'s state at that point (which had moved again in the meantime — a *third* concurrent session, PR #212, had pushed real `flutter analyze`/`flutter test` fixes to this exact file). Verified the re-applied diff still made sense against that newer version (an added `hide UsernameTakenException` clause on an adjacent import line — no logic conflict) before merging and triggering run #37.

**Lesson for next time**: after resolving a `git merge` conflict that required *additional* manual edits beyond what `git merge` itself staged, always run `git status` immediately before the merge commit — don't trust that everything you touched during conflict resolution is staged just because the conflict markers are gone.

## Pre-deploy database migration

Extracted the exact WYN-077 block from `supabase/schema.sql` into `.wyn/logs/deployments/2026-09-02-wyn-077-production-migration.sql` — mechanically extracted with `awk`, not hand-typed (a hand-typed first attempt was caught missing a comment block during self-review and discarded). Re-verified byte-identical to a fresh extraction after the PR #210/#212 merge too (that merge didn't touch this region of the file).

**Verified against a local throwaway Postgres**, not assumed: built a database with the exact schema state `schema.sql` had immediately before the WYN-077 block (simulating production), applied the migration on top — succeeded cleanly, `admin_dashboard_metrics()` returns sane empty-state data (`0`s, `top_sources: []`) with zero `analytics_events` rows present.

**Founder said they'd run this via the Supabase Dashboard SQL Editor right away**, before this session proceeded to open/merge the PR and trigger the deploy — this session has no way to independently confirm the migration actually landed in production (no Supabase credentials here). If the Admin Dashboard's Growth section (once `admin/` has a live deployment) or a direct `analytics_events` insert ever errors with "relation does not exist," that's the thing to check first.

Purely additive — one new table, one function dropped and recreated with more columns than before. Nothing existing changes shape for any caller reading only the original 14 columns.

## Deployment Result

**SUCCESS.** Run #37 (id `33686337670`, workflow `deploy-web.yml`) completed with conclusion `success`, `main` @ `8dc18d4`.

## Production Verification

Not yet done from inside this sandbox — this environment's egress proxy blocks `wynos.online` directly (same restriction noted in every prior deploy log in this project). **Recommend Founder open https://wynos.online**, try a real email sign-up through to Finish, and confirm nothing user-visible broke (the analytics calls are best-effort/fire-and-forget by design, so even a schema mismatch would fail silently rather than show an error — worth a real look regardless).

## Rollback Plan

- **Database**: purely additive — rolling back app code doesn't require rolling back the schema. If ever needed: `drop table if exists public.analytics_events cascade;` then restore the previous 14-column `admin_dashboard_metrics()` definition (`schema.sql` history at commit `7d09825^`).
- **App code**: re-run `deploy-web.yml` against the previous production commit (`7083f67`, pre-WYN-077), or `git revert` the relevant merge commits on `main` and redeploy.
- **Admin**: N/A — no live deployment exists yet to roll back.

## Next Steps (Founder)

1. Open https://wynos.online and confirm the app works end to end (real sign-up, Home feed, posting) — same as every prior deploy's ask.
2. **Admin dashboard remains undeployed** (pre-existing gap since WYN-049) — the Growth section only becomes visible once a Vercel project exists for `admin/` (Root Directory = `admin/` + env vars).
3. The WYN-077 task-ID collision with PR #210's "First Login/Account Onboarding" is cosmetic (documentation/comments only, no functional impact) but should get a cleanup pass sometime — not urgent.
