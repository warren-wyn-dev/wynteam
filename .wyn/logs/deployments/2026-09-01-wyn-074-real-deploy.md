# Deployment Log — WYN-074 (post images flashing blank on scroll)

Date: 2026-09-01
Owner: AI Deploy & DevOps
Approved by: Founder ("Deploy เลย")

## Release
- Task: WYN-074 — Founder-reported bug (screen recording): on Profile, posts only showed "half" — root-caused to `HomeDropCard`'s bare `Image.network` with no placeholder/disk cache
- Source branch: `claude/home-page-ux-ui-design-2sxqbi`
- PR: #197 — merged to `main` via merge commit `e516f40d5cee8083d1ce413200db0fb358d08ac6`

## QA Status
PASS (2026-09-01) — see `.wyn/tasks/approved/WYN-074-profile-post-image-blank-flash.md` (871/871 tests, 0 analyze issues, independently re-verified; confirmed `CachedNetworkImage` in place and `cached_network_image` resolved as a real dependency, not just declared).

## Pre-deploy check
- `git log --oneline HEAD..origin/main -- supabase/schema.sql` → empty. No schema changes (Flutter widget change + new pub dependency only). No migration step required.

## Build & Deploy
- GitHub Actions workflow: `deploy-web.yml` (`workflow_dispatch`, ref `main`)
- Run: [`33529251136`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33529251136), run #30
- `head_sha`: `e516f40d5cee8083d1ce413200db0fb358d08ac6` (matches merge commit)
- `status`: completed, `conclusion`: success
- Started: 2026-09-01T16:00:45Z, finished: 2026-09-01T16:03:23Z (~2m38s)
- Deploy target: Vercel project "web" → https://web-neon-sigma-66.vercel.app (production)

## Deployment Result
SUCCESS

## Production Verification
Direct `curl` checks against `https://web-neon-sigma-66.vercel.app/` after the run completed:
- `/` (index.html): HTTP 200
- `/main.dart.js`: HTTP 200, 4,145,796 bytes — **different size than the last logged build (4,087,668 bytes, WYN-073 deploy)**, larger by roughly the size of the new `cached_network_image`/`octo_image` packages bundled in, confirming this is a real freshly-compiled build with the new dependency included, not a stale cache hit
- `/flutter_bootstrap.js`: HTTP 200
- `/manifest.json`: HTTP 200

## Rollback Plan
If Founder reports a visual/functional regression from this deploy:
1. Re-run `deploy-web.yml` (`workflow_dispatch`) with `ref` pinned to the previous good commit (`a2bfc151`, the WYN-073 merge — PR #195) to redeploy the prior build to the same Vercel production alias.
2. No database/schema rollback needed — this task made no `supabase/schema.sql` changes.
3. Alternatively `vercel rollback` to the immediately-prior production deployment on the "web" Vercel project, if faster.

## Notes
- Fix is scoped to `HomeDropCard` (shared by Home feed and Profile posts tab) — covers both screens from one change.
- ~28 other `Image.network` call sites elsewhere in the app (club covers, Zoky product images, saved-grid tiles, etc.) have the same underlying no-placeholder/no-cache pattern but were not reported as broken and were left untouched — flagged as a known follow-up if Founder wants it addressed later.
- PR #197 status checks: only the 4 known stray Vercel auto-preview projects, all success — no unexpected new checks this round (unlike WYN-073's stray Netlify check).
