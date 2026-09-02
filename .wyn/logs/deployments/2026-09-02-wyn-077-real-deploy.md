# Deployment Log — WYN-077 (Basic Product Analytics) — PENDING Founder action, not yet deployed

```
Release: WYN-077 (self-hosted product analytics: signup funnel, activation, D1/D7 retention, top signup sources — Admin Dashboard "Growth" section)
Version: not yet built — commit bb92aff on branch `claude/wynos-online-verification-vvvheg` (not merged to `main`)
QA Status: PASS — 2 rounds. Round 1 found a real bug (AnalyticsRepository crashed when Supabase wasn't initialized, broke 2 existing tests), AI Debug Engineer fixed it, round 2 independently re-verified. See `.wyn/tasks/approved/WYN-077-basic-product-analytics.md`.
Build Status: Admin (Next.js) — `npm install && next build && npm run lint` run for real in this session, both clean. Flutter app (`app/`) — **not built in this session** (no Flutter SDK in this sandbox, same limitation every prior task has hit); `deploy-web.yml` builds it inside GitHub Actions using a real Flutter SDK, so this isn't a blocker for the actual deploy step, just for local verification.
Deployment Target: (1) Supabase project `kqokpocajhfbidcxpvhh` (production database) — needs a schema migration first. (2) Vercel project "web" (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), production URL https://wynos.online, via `deploy-web.yml` (GitHub Actions, workflow_dispatch). (3) Admin dashboard (`admin/`) — **has no live deployment at all yet** (confirmed still true as of this session — see RELEASE_NOTES.md's "สิ่งที่ยังไม่รวมใน Beta 1"), so the Growth section's UI has nowhere to go live until Founder sets up that Vercel project for the first time (pre-existing gap since WYN-049, not something this task can or should fix).
Changes: `analytics_events` table (new) + `admin_dashboard_metrics()` extended with 8 Growth columns (SQL); `AnalyticsRepository` (new) wired into 4 screens (Flutter); Admin Dashboard "Growth" section (Next.js, code-ready but not deployable yet per above).
```

## Why this hasn't been deployed yet

Two things this session cannot do itself, both by design (not a workaround-able technical block):

1. **No Supabase production credentials in this session.** RELEASE_NOTES.md is explicit that these stay with the Founder, not in code or any session. Every prior task in this project's history that needed a schema change hit the same wall and resolved it the same way (see `.wyn/logs/deployments/2026-09-01-wyn-072-real-deploy.md`, `2026-08-25-wyn-071-p0-production-schema-hotfix.md`): the Founder runs the prepared SQL directly via the Supabase Dashboard's SQL Editor.
2. **No PR opened / not merged to `main`.** `deploy-web.yml` (the only path to a real Flutter build+deploy, since there's no local SDK) is `workflow_dispatch`-only and every prior real deploy in this project's history ran it against `main` after a PR merge — this session hasn't been asked to open a PR or merge, and per the same precedent other sessions have followed (`.wyn/company/CONTEXT.md`, WYN-044/WYN-049), doesn't do so without an explicit ask.

## Pre-deploy database migration — prepared and verified, not yet applied

Extracted the exact WYN-077 block from `supabase/schema.sql` into `.wyn/logs/deployments/2026-09-02-wyn-077-production-migration.sql` — **mechanically extracted with `awk`, not hand-typed** (a hand-typed first attempt was caught missing a comment block during self-review and discarded; the committed file's SQL body is byte-identical to a fresh `awk` re-extraction, verified with `diff` after stripping comments/blank lines from both).

**Verified against a local throwaway Postgres**, not assumed: built a database with the exact schema state `schema.sql` had immediately before the WYN-077 block (simulating current production, since production has every prior task's schema already applied), then applied `2026-09-02-wyn-077-production-migration.sql` on top — succeeded cleanly. Queried `admin_dashboard_metrics()` afterward with zero `analytics_events` rows present (production's actual starting state): `signup_started_24h` = 0, `top_sources` = `[]` (not null) — confirms the Admin Dashboard's Growth section renders sanely from day one before any real signups happen, not just with the synthetic test data QA's own regression test seeds.

Purely additive — one new table, one function dropped and recreated with more columns than before. Nothing existing changes shape for any caller reading only the original 14 columns.

## Deployment Result

**Not deployed.** Nothing pushed to production in this session.

## Production Verification

N/A — nothing deployed yet.

## Rollback Plan (once deployed)

- **Database**: purely additive (see above) — rolling back the *app code* does not require rolling back the schema; unused new columns/table are harmless. If ever needed: `drop table if exists public.analytics_events cascade;` then re-run the *previous* `admin_dashboard_metrics()` definition (the 14-column version, still in `schema.sql`'s git history at commit `7d09825^`).
- **App code**: re-run `deploy-web.yml` against the previous production commit, or `git revert` the merge commit on `main` and redeploy.
- **Admin**: N/A until it has a first deployment to roll back from.

## Next Steps (Founder)

1. **Run `.wyn/logs/deployments/2026-09-02-wyn-077-production-migration.sql`** in Supabase Dashboard → SQL Editor for project `kqokpocajhfbidcxpvhh`, *before* the app deploy below. Verified safe (see above) but this session cannot run it itself.
2. **Decide how the code ships**: this branch (`claude/wynos-online-verification-vvvheg`) has 7 commits' worth of WYN-077 work sitting on top of `main` @ `f6dfff0`, unmerged. Say the word and this session will open a PR / merge it, then trigger `deploy-web.yml` (via GitHub Actions) once step 1 is confirmed done.
3. **Admin dashboard remains undeployed** (pre-existing gap, not new) — the Growth section will only be visible once a Vercel project exists for `admin/` (Root Directory = `admin/` + env vars, same setup WYN-049's log already described needing).
4. Once deployed: open https://wynos.online in a real browser and try a real email sign-up end to end, to confirm analytics writes don't silently break anything user-visible (they're best-effort/fire-and-forget by design, but worth a real look).
