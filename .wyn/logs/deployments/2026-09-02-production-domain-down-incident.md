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

## Next step
Asked Founder whether:
1. `wynos.online` should become the documented canonical production URL going forward (replacing `web-neon-sigma-66.vercel.app` everywhere it's referenced in `.wyn/company/CONTEXT.md` and elsewhere), and
2. Whether they still want the old `web-neon-sigma-66.vercel.app` link restored (optional — cosmetic only, requires Vercel Dashboard → project "web" → Settings → Domains → re-add it, if Vercel allows).
