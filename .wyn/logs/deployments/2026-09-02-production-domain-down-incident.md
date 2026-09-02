# Deployment Log — Production incident: `web-neon-sigma-66.vercel.app` returning 404 DEPLOYMENT_NOT_FOUND

Date: 2026-09-02
Owner: AI Deploy & DevOps
Trigger: Founder report ("เพิ่มโดเมนใน Vercel แล้ว พัง" + screenshot of 404 DEPLOYMENT_NOT_FOUND on `web-neon-sigma-66.vercel.app`)

## Release
No code change. Incident response only.

## QA Status
N/A — no code changed. Redeploy used the exact commit already QA-passed and production-verified for WYN-076 (see `2026-09-01-wyn-076-real-deploy.md`).

## Build Status
SUCCESS — re-ran `deploy-web.yml` (workflow_dispatch) on `main` @ `6a8a9005cc33602980938f172bf84bc1dc98b0a2` to rule out a build/deploy problem.
- Run: [`33607733226`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33607733226), run #33
- `status`: completed, `conclusion`: success (08:15:16Z – 08:17:56Z)

## Deployment Target
Vercel project "web" (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`) → intended production domain `https://web-neon-sigma-66.vercel.app`

## Changes
None. This run deployed identical content to the last successful production deploy (WYN-076, run #32).

## Deployment Result
Pipeline: SUCCESS (Vercel accepted and built a new production deployment under the same project/org IDs used by every prior successful deploy).
**Domain: STILL BROKEN.** `https://web-neon-sigma-66.vercel.app/` continues to return `404` with header `x-vercel-error: DEPLOYMENT_NOT_FOUND` even after the fresh successful deploy.

## Production Verification
```
curl -sS -D - https://web-neon-sigma-66.vercel.app/
HTTP/2 404
x-vercel-error: DEPLOYMENT_NOT_FOUND
```
Checked `/`, `/main.dart.js`, `/flutter_bootstrap.js` — all 404 with the same error, before and after the redeploy.

## Root Cause (diagnosis, not yet confirmed by Founder)
Because a brand-new, successful `vercel deploy --prod` to the same `VERCEL_PROJECT_ID`/`VERCEL_ORG_ID` did **not** fix the domain, this is not a build/CI/code problem — it is a Vercel **domain/project configuration** problem, consistent with Founder having just added a domain in the Vercel dashboard. Most likely one of:
1. `web-neon-sigma-66.vercel.app` (the project's default alias) got detached from the "web" project — e.g. it was accidentally reassigned while adding the new custom domain.
2. The new domain was added under a **different** Vercel project than "web", and that action altered which project/deployment `web-neon-sigma-66.vercel.app` points to.
3. The "web" project itself was changed (renamed, or a different project now owns that default subdomain).

This cannot be diagnosed or fixed from this session: no Vercel dashboard/API credentials are available here (`VERCEL_TOKEN`/org/project IDs exist only as GitHub Actions secrets, not in this environment), and Vercel domain management is a dashboard-only action for whoever holds the Vercel account login.

## Rollback Plan
No code rollback needed/possible — no code changed, and the last deploy (run #32, WYN-076) already succeeded on this exact same alias before the domain change. Recovery is entirely on the Vercel side (Project Settings → Domains), owned by Founder's Vercel account access.

## Update — root cause confirmed, app is NOT actually down
Founder confirmed the domain added was **`wynos.online`**. Checked it directly:

```
curl -sS -D - https://wynos.online/          -> HTTP/2 200 (Vercel, serves the WYNOS Beta Flutter web build)
curl https://wynos.online/main.dart.js       -> 200
curl https://wynos.online/flutter_bootstrap.js -> 200
curl https://wynos.online/manifest.json      -> 200
curl https://www.wynos.online/               -> 200
```

**The production app is live and fully functional at `https://wynos.online`** (and `www.wynos.online`). Root cause of the screenshot: adding `wynos.online` as a custom domain on the "web" project detached the project's old auto-generated default domain `web-neon-sigma-66.vercel.app` from the project (a known Vercel behavior — the default `.vercel.app` alias isn't guaranteed to keep working once a custom domain takes over production; here it shows `DEPLOYMENT_NOT_FOUND` instead of redirecting). This is a **stale/cosmetic broken link, not a real production outage** — nothing served to real users on `wynos.online` is affected.

## Next step (superseded — see below, real recurring root cause found)
Asked Founder whether:
1. `wynos.online` should become the documented canonical production URL going forward (replacing `web-neon-sigma-66.vercel.app` everywhere it's referenced in `.wyn/company/CONTEXT.md` and elsewhere), and
2. Whether they still want the old `web-neon-sigma-66.vercel.app` link restored (optional — cosmetic only, requires Vercel Dashboard → project "web" → Settings → Domains → re-add it, if Vercel allows).
Founder confirmed both: wynos.online is canonical, old alias not restored. Docs updated (`CONTEXT.md`, `RELEASE_NOTES.md`) and merged via PR #206.

## Update 2 — real recurring root cause found: Vercel GitHub integration is now connected to project "web"
Minutes after merging PR #206 (a **docs-only** PR, no app code), Founder reported `wynos.online` broken again — this time with a *different* Vercel error (`NOT_FOUND` instead of `DEPLOYMENT_NOT_FOUND`). A screenshot of the Vercel dashboard (project "web") showed the culprit directly:

- A new **Production Deployment** `web-3m1a8rewr-warren14.vercel.app`, status **Ready**, created ~5 min prior
- **Source: `main` @ `c630514` — "Merge pull request #206"**
- Domains `wynos.online` / `www.wynos.online` attached to *this* deployment
- Visiting it shows `404 NOT_FOUND`

This proves project **"web" now has Vercel's GitHub integration connected** (previously believed to be CI-only per the 2026-08-25 correction in `DECISIONS.md`, which was about a *different* project, "wynteam"). Merging PR #206 into `main` made Vercel auto-build straight from the repo root — a bare Flutter source tree with no `vercel.json`/build config Vercel can zero-config-detect — producing a broken deployment that auto-promoted to Production and immediately stole the domains away from the correct build `deploy-web.yml` (run #33) had just deployed minutes earlier.

**This will recur on every future merge to `main`** (even docs-only ones) until the GitHub integration is disconnected from project "web". Re-ran `deploy-web.yml` (run #34) to restore the correct build again — this is a stopgap, not a fix, since the next merge to `main` will break it again the same way.

## Recommendation (needs Founder action in Vercel Dashboard — cannot be done from this session)
Go to **Vercel Dashboard → project "web" → Settings → Git** and **disconnect the GitHub repository connection** for this project. Production should continue to be deployed exclusively through `.github/workflows/deploy-web.yml` (which actually knows how to build Flutter web), same as it has been since 2026-08-25's correction — the difference is this time the setting needs fixing on project "web" itself, not just "wynteam".

## Update 3 — disconnect did not hold: broke a 3rd time after merging PR #207
Founder reported disconnecting the Git integration in Vercel Dashboard. To verify, merged PR #207 (another docs-only change, the log entry above) into `main` as a real test. **Production broke again within ~7 minutes**, same signature as Update 2 (`x-vercel-error: NOT_FOUND`). This means either:
1. The disconnect didn't actually save/apply on project "web", or
2. Something disconnected a *different* project (there may be more than one Vercel project in this account that looks similarly named), or
3. Vercel's GitHub App is still installed with access to this repo at the GitHub side (Settings → Integrations → Installed GitHub Apps → Vercel) even though the per-project "connected repo" toggle was changed, and that's enough to keep triggering auto-deploys.

Re-ran `deploy-web.yml` again to restore production. **Asked Founder to re-verify the disconnect** (confirm they were on project "web" specifically, that the Git section actually shows "no repository connected" after refreshing the page) and, if it still doesn't hold, to check from the GitHub side whether the Vercel GitHub App's repository access can be scoped/removed for this repo entirely as a more forceful fix.

## Update 4 — separate bug found: Google Sign-In redirects to the dead old domain
Founder reported a *different* failure while testing: tapping "เข้าสู่ระบบด้วย Google" on `wynos.online` immediately showed the old `web-neon-sigma-66.vercel.app` domain's `404 DEPLOYMENT_NOT_FOUND` page (screenshot: URL bar showing `...sigma-66.vercel.app`).

Root cause: per `app/lib/features/auth/data/auth_repository.dart` (comments + `WYN-P0-google-signin-broken-on-web.md`), `signInWithGoogle`/`signInWithApple` pass `redirectTo: null` on web by design, so `supabase_flutter` falls back to the current page's own origin as the OAuth callback — but that origin has to already be in the Supabase project's Auth `uri_allow_list` (confirmed via Management API in the WYN-P0 fix: previously only `https://web-neon-sigma-66.vercel.app` and `https://web-neon-sigma-66.vercel.app/**`). Since `wynos.online` was never added to that allow-list, Supabase falls back to the stale configured Site URL (the dead old domain) instead.

This is a **Supabase Dashboard** config issue (Authentication → URL Configuration → Site URL + Redirect URLs), not a code bug — no Supabase Management API credentials are available in this session to fix it directly, so instructions were given to Founder to update it manually: Site URL → `https://wynos.online`, add `https://wynos.online/**` to Redirect URLs. Founder confirmed making the change; verification of the actual OAuth round-trip (Google consent screen → redirect back) is pending Founder's own retest, since this session cannot drive a real Google OAuth flow through a browser.

**Retest confirmed by Founder: Google Sign-In now works correctly on `https://wynos.online`.** This item is resolved.

## Current status summary (end of incident)
- ✅ `https://wynos.online` serving production correctly (verified repeatedly via curl)
- ✅ Google Sign-In redirect fixed (Supabase Auth URL Configuration updated, Founder-confirmed working)
- ⚠️ **Unresolved / needs Founder follow-up**: it's still not confirmed that Vercel's GitHub integration on project "web" is fully disconnected. The dashboard-level "Disconnect" in Settings → Git did not hold on the first attempt (production broke a 3rd time after merging PR #207). A GitHub-side fix (removing/scoping the Vercel GitHub App's access to this repo under github.com/settings/installations, or the repo's Settings → Integrations) was suggested but not yet confirmed done. **Every future merge into `main` is a live test** — if it breaks `wynos.online` again, re-run `deploy-web.yml` to restore, and revisit the GitHub App access removal.
