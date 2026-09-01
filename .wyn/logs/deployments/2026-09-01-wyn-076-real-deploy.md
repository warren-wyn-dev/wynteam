# Deployment Log — WYN-076 (liked heart still sapphire in 2 spots)

Date: 2026-09-01
Owner: AI Deploy & DevOps
Approved by: Founder ("Deploy เลย")

## Release
- Task: WYN-076 — Founder circled the like/comment/redrop/view action bar on a Home post, wanted the heart red. Fixed 2 remaining spots (`home_drop_card.dart`, `home_pop_card.dart`) still using `WynColors.sapphire` instead of the app-wide `Colors.red` convention for the liked-heart icon.
- Source branch: `claude/home-page-ux-ui-design-2sxqbi`
- PR: #204 — merged to `main` via merge commit `7a7234a9aafd22a96c4af801760de01d8aa099a9`

## QA Status
PASS (2026-09-01) — 871/871 tests, 0 analyze issues.

## Pre-deploy check
- No schema changes (color-value change only).

## Build & Deploy
- GitHub Actions workflow: `deploy-web.yml` (`workflow_dispatch`, ref `main`)
- Run: [`33533323875`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33533323875), run #32
- `head_sha`: `7a7234a9aafd22a96c4af801760de01d8aa099a9` (matches merge commit)
- `status`: completed, `conclusion`: success
- Started: 2026-09-01T16:41:41Z, finished: 2026-09-01T16:44:16Z (~2m35s)
- Deploy target: Vercel project "web" → https://web-neon-sigma-66.vercel.app (production)
- Note: PR #204's 4 stray auto-preview Vercel checks (wynteam/-ipe1/-cesp/-z3rr) failed with "Deployment rate limited — retry in 24 hours" (the account-wide free Hobby plan's 100/day cap), but the real deploy pipeline (this workflow, the "web" project) was unaffected and completed normally.

## Deployment Result
SUCCESS

## Production Verification
Direct `curl` checks against `https://web-neon-sigma-66.vercel.app/` after the run completed:
- `/` (index.html): HTTP 200
- `/main.dart.js`: HTTP 200, 4,088,406 bytes — **identical to the WYN-075 build**, expected since this change only swaps a color constant (no new/removed dependencies)
- `/flutter_bootstrap.js`: HTTP 200
- `/manifest.json`: HTTP 200

## Rollback Plan
If needed: re-run `deploy-web.yml` pinned to `50c03478` (WYN-075 merge, PR #200) to redeploy the prior build. No schema rollback needed.

## Notes
- The stray Vercel auto-preview projects hitting their daily quota is worth keeping an eye on: if it recurs and starts blocking the *real* deploy workflow too (it did not this time), Founder may want to either wait out the 24h reset or consider disabling/unlinking those auto-preview projects from the GitHub integration, since they aren't part of the actual deploy pipeline.
