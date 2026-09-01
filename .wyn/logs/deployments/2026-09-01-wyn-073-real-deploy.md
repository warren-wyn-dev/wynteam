# Deployment Log — WYN-073 (Home layout reorder + feed-mode tabs restyle)

Date: 2026-09-01
Owner: AI Deploy & DevOps
Approved by: Founder ("Deploy เลย")

## Release
- Task: WYN-073 — Home layout reorder, remove Club/Trending sections from Home, restyle feed-mode tabs (SegmentedButton → text + underline)
- Source branch: `claude/home-page-ux-ui-design-2sxqbi`
- PR: #195 — merged to `main` via merge commit `a2bfc151f77391d6f273519224b9821872b18f13`

## QA Status
PASS (2026-09-01) — see `.wyn/tasks/approved/WYN-073-home-layout-tabs-restyle.md` for full independent QA verification notes (871/871 tests, 0 analyze issues, component order/tab restyle/overflow all re-checked against actual code).

## Pre-deploy check
- `git log --oneline HEAD..origin/main -- supabase/schema.sql` → empty. No schema changes in this task (confirmed at QA time too). No migration step required — unlike WYN-072, no schema-drift risk this round.

## Build & Deploy
- GitHub Actions workflow: `deploy-web.yml` (`workflow_dispatch`, ref `main`)
- Run: [`33512075044`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33512075044), run #29
- `head_sha`: `a2bfc151f77391d6f273519224b9821872b18f13` (matches merge commit)
- `status`: completed, `conclusion`: success
- Started: 2026-09-01T13:13:13Z, finished: 2026-09-01T13:15:53Z (~2m40s)
- Deploy target: Vercel project "web" → https://web-neon-sigma-66.vercel.app (production)

## Deployment Result
SUCCESS

## Production Verification
Direct `curl` checks against `https://web-neon-sigma-66.vercel.app/` after the run completed:
- `/` (index.html): HTTP 200
- `/main.dart.js`: HTTP 200, 4,087,668 bytes — **different size than the last logged build (4,095,595 bytes, WYN-072 deploy)**, confirming this is a real freshly-compiled build, not a stale cache hit
- `/flutter_bootstrap.js`: HTTP 200
- `/manifest.json`: HTTP 200

## Rollback Plan
If Founder reports a visual/functional regression on Home after this deploy:
1. Re-run `deploy-web.yml` (`workflow_dispatch`) with `ref` pinned to the previous good commit (`33150ae`, the WYN-072 merge — PR #193) to redeploy the prior build to the same Vercel production alias.
2. No database/schema rollback needed — this task made no `supabase/schema.sql` changes.
3. Alternatively `vercel rollback` to the immediately-prior production deployment on the "web" Vercel project, if faster.

## Notes
- No schema migration in this deploy (unlike WYN-072) — verified both at QA and again pre-deploy.
- PR #195 status checks included the known stray auto-preview projects (Vercel ×4, all success) plus one new stray Netlify preview check (`netlify/exquisite-taiyaki-660324/deploy-preview`, pending at merge time) — none of these are part of the real deploy pipeline (`deploy-web.yml` → Vercel project "web"), so they were correctly ignored per the pattern established during the WYN-072 deploy.
