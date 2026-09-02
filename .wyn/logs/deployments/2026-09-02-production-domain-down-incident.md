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

## Next step
Reported to Founder with a request for: (a) what domain was added, and (b) a check of Vercel Dashboard → project "web" → Settings → Domains to see whether `web-neon-sigma-66.vercel.app` is still listed under that project.
