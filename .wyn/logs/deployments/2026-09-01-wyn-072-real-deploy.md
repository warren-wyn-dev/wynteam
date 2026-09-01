# Deployment Log — WYN-072 (WYNOS wordmark, pause Apple sign-in, guest browsing) — REAL PRODUCTION DEPLOY, SUCCESS

```
Release: WYN-072 (Welcome/Auth Method wordmark fix "WYN"→"WYNOS", pause Sign in with Apple, guest browsing via Anonymous Sign-In with a 4-point requireRealAccount() gate)
Version: main.dart.js (4,095,595 bytes), built via GitHub Actions run 33503100073 from `main` @ `33150ae` (merge of PR #193), workflow_dispatch
QA Status: PASS — 2 rounds. Round 1 found a test-infrastructure-only bug (Realtime pending-disconnect Timer leak in a new AuthGate widget test), fixed by AI Debug Engineer (rootShellBuilder injection seam), round 2 independently re-verified flutter analyze (0 issues) + flutter test (878/878) clean. See `.wyn/tasks/approved/WYN-072-onboarding-polish-guest-browsing.md`.
Build Status: `flutter build web --release --dart-define-from-file=dart_define.json` succeeded inside the GitHub Actions run (this session has no local Flutter/Vercel toolchain of its own for the real deploy step -- verification builds earlier in this session used a separately-downloaded SDK for testing only, not for this deploy).
Deployment Target: Vercel project "web" (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), production URL **https://web-neon-sigma-66.vercel.app** (the confirmed real user-facing production domain -- not the stray `wynteam`/`wynteam-cesp`/`wynteam-ipe1`/`wynteam-z3rr` GitHub-integration auto-preview projects, which stay green on every push but never run a real Flutter build).
Changes: PR #193 (`claude/home-page-ux-ui-design-2sxqbi` -> `main`, merge commit `33150ae`) -- see PR body for full file list. Also includes everything already merged to `main` since the last logged real deploy (2026-08-25) that had not been formally logged here -- see "Deploy history gap closed" below.
```

## Pre-deploy database migration (P0-class risk caught and fixed before shipping)

Before merging/deploying, checked `git log` for `supabase/schema.sql` changes since the last logged real deploy and found 3 commits (`dff6c10`, `6f643f1`, `2ef7af4`, dated 2026-08-29/30) that each explicitly required "re-running the updated home_feed/profiles definitions against production Supabase before this is live" -- the exact same class of gap that caused the WYN-071 P0 incident (2026-08-25).

**Verified against the live production database directly** (Supabase Management API, read-only queries first, not assumed):
- `profiles.is_verified`: missing
- `home_feed` view's `liked_by`/`top_reply`/`author_is_verified`/`redropper_is_verified`: missing
- `drop_count()` function: already present (applied by an earlier, undocumented session)

**Fix applied**: Founder ran the corrected migration SQL directly via the Supabase Dashboard SQL Editor (this session's own attempt to apply it programmatically via the Management API was blocked by the sandbox's own safety classifier for production-database writes -- expected and correct behavior for this class of action, not worked around). First attempt hit Postgres error `42P16` (`CREATE OR REPLACE VIEW` cannot reorder/rename existing columns, only append new ones) because production's actual `home_feed` column order didn't match `schema.sql`'s latest version -- re-queried production's real column order and rebuilt the migration with the 4 new columns appended at the end instead of interleaved (confirmed safe: `HomeFeedItem.fromMap` reads every field by JSON key name, never by position). Second attempt: **Success**.

**Verified again after the fix** (read-only queries): all 4 new `home_feed` columns present at positions 26-29, `profiles.is_verified` present (boolean, default false), `select count(*) from home_feed` returns cleanly (43 rows, no error). A REST API smoke query for `author_is_verified,liked_by,top_reply` against `home_feed` also returned HTTP 200 with no Postgrest error.

**Likely pre-existing production impact this fixed**: per the "Deploy history gap closed" section below, the Home-feed-restyle code that depends on these columns was already live in production since 2026-08-30 (run 20) without this migration ever having been applied -- meaning Home feed was likely already throwing Postgrest errors for real users for roughly 2 days before this fix, independent of WYN-072 itself.

## Deploy history gap closed (found while investigating the above)

`.wyn/logs/deployments/` had no real-deploy entries after 2026-08-25, but `deploy-web.yml`'s actual run history (checked via GitHub Actions API, not assumed) shows **7 successful production deploys between 2026-08-25 and 2026-08-31** that were never logged here: runs 8, 12, 16, 20, 23, 26, 27 (commits `58e4757` through `8aae125` -- WYN-071 docs, the 3 deferred restyle gaps, push notification type coverage, the WYNOSHomeSpec.md consolidated Home restyle, the explainer banner, the Home header, and the liked-by-avatars restore fix, respectively). Production was already much closer to current `main` than the deployment-log folder suggested -- this was a documentation gap, not an actual deployment gap. Flagging so no future session re-derives the wrong "production is stuck at 2026-08-25" assumption from an incomplete log folder again; ground truth is the GitHub Actions run history, not this folder, when the two disagree.

## Deployment Result

**SUCCESS.** GitHub Actions run 33503100073 (workflow `deploy-web.yml`, run #28) completed with conclusion `success` in ~2m40s.

## Production Verification

Done for real against the live URL, not assumed:
- `curl https://web-neon-sigma-66.vercel.app/` -> HTTP 200, 1,523 bytes (valid `index.html`)
- `curl https://web-neon-sigma-66.vercel.app/main.dart.js` -> HTTP 200, 4,095,595 bytes (a real, freshly-compiled build -- different size than the last logged build, 3,985,507 bytes from 2026-08-25, confirming this isn't a stale cache hit)
- `curl https://web-neon-sigma-66.vercel.app/manifest.json` -> HTTP 200
- `curl https://web-neon-sigma-66.vercel.app/flutter_bootstrap.js` -> HTTP 200
- `home_feed` REST query for the new columns -> HTTP 200, no Postgrest error
- **Not done**: a real-browser smoke test (open the app, tap "เข้าชม WYNOS ได้เลย", confirm the guest gate dialog, confirm Home feed renders without errors) -- this sandbox's Chromium/Playwright path has the same egress restrictions noted in every prior deploy log. **Recommend Founder open https://web-neon-sigma-66.vercel.app in a real browser** to visually confirm the WYNOS wordmark, the Apple button is gone, the guest button works, and Home feed loads without the "โหลด Drop ไม่สำเร็จ" error that WYN-071's schema gap caused last time.

## Rollback Plan

- **Immediate**: re-run `deploy-web.yml` against the previous commit (`8aae125`, run 27's SHA) to restore the prior build within ~3 minutes, or `vercel rollback` with `VERCEL_TOKEN` if CLI access is available.
- **Code**: `git revert` merge commit `33150ae` on `main`, then redeploy.
- **Database**: the migration applied (`profiles.is_verified`, `home_feed` view redefinition, `drop_count()`) is purely additive (new column with a default, `CREATE OR REPLACE VIEW`/`FUNCTION`) -- rolling back the *app code* does not require rolling back the schema; the new columns are simply unused by older code. No destructive schema change was made, so there is nothing to reverse on the database side even in a rollback scenario.

## Security note carried forward from QA

The guest-browsing gate added in WYN-072 is UI-level only. `supabase/schema.sql`'s RLS does not distinguish an anonymous session from a real one (`is_anonymous` isn't referenced anywhere in the policies) -- a guest calling the API directly, bypassing the app UI, could still Like/Comment/Post. This is a pre-existing characteristic of the already-approved Anonymous Sign-In (2026-08-16), not a new hole from this deploy, but WYN-072 makes creating an anonymous account far more discoverable (a visible button on the sign-in screen) than before. Founder should be aware; enforcing this at the RLS layer instead would be a Security Architecture change requiring separate approval.

## Next Steps (Founder)

1. Open **https://web-neon-sigma-66.vercel.app** in a real browser/phone to visually confirm WYN-072 (WYNOS wordmark, no Apple button, "เข้าชม WYNOS ได้เลย" guest entry) and that Home feed loads cleanly (the schema fix above should have resolved any lingering load errors from the undocumented 2026-08-30 deploys).
2. Consider whether the `.wyn/logs/deployments/` gap (7 undocumented real deploys) means other sessions should get in the habit of checking GitHub Actions' own run history directly rather than trusting this log folder as complete.
3. Native mobile (iOS/Android) build/distribution remains blocked on `google-services.json`/`GoogleService-Info.plist` + a distribution channel -- unchanged from every prior log.
