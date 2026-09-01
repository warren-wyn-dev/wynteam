# Deployment Log — WYN-075 (P0 revert: cached_network_image broke every post image)

Date: 2026-09-01
Owner: AI Deploy & DevOps
Approved by: Founder ("Deploy")

## Release
- Task: WYN-075 — P0 revert of the WYN-074 fix. `CachedNetworkImage` failed to load every post image on production (Home feed + Profile both), confirmed by Founder. Reverted `HomeDropCard` to `Image.network`, keeping the original blank-flash fix via Flutter's own `loadingBuilder`/`errorBuilder` instead of an external package.
- Source branch: `claude/home-page-ux-ui-design-2sxqbi`
- PR: #200 — merged to `main` via merge commit `50c034787c72187da153bbe529c1751d2424225c`

## QA Status
PASS (2026-09-01) — see `.wyn/tasks/approved/WYN-075-revert-cached-network-image-web-broken.md` (871/871 tests, 0 analyze issues; confirmed no `cached_network_image` usage remains in code and `pubspec.lock` no longer lists it or its 8 transitive deps).

## Pre-deploy check
- `git log --oneline HEAD..origin/main -- supabase/schema.sql` → empty. No schema changes (Flutter widget revert + dependency removal only).

## Build & Deploy
- GitHub Actions workflow: `deploy-web.yml` (`workflow_dispatch`, ref `main`)
- Run: [`33531506545`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33531506545), run #31
- `head_sha`: `50c034787c72187da153bbe529c1751d2424225c` (matches merge commit)
- `status`: completed, `conclusion`: success
- Started: 2026-09-01T16:23:40Z, finished: 2026-09-01T16:26:16Z (~2m36s)
- Deploy target: Vercel project "web" → https://web-neon-sigma-66.vercel.app (production)

## Deployment Result
SUCCESS

## Production Verification
Direct `curl` checks against `https://web-neon-sigma-66.vercel.app/` after the run completed:
- `/` (index.html): HTTP 200
- `/main.dart.js`: HTTP 200, 4,088,406 bytes — **shrank from the WYN-074 build (4,145,796 bytes)**, consistent with `cached_network_image` and its 8 transitive deps being removed, confirming this is the reverted build and not a stale cache hit
- `/flutter_bootstrap.js`: HTTP 200
- `/manifest.json`: HTTP 200

Byte-level checks confirm a fresh, smaller build shipped. **Visual confirmation that images actually render again still needs Founder to check on a real device/browser** — this sandbox cannot open a browser against production (Chromium-through-proxy is not reachable from this session, unrelated to the app itself).

## Rollback Plan
If this revert itself somehow causes a new issue (unlikely — restores the exact `Image.network` code path that was working before WYN-074):
1. Re-run `deploy-web.yml` (`workflow_dispatch`) with `ref` pinned to `a2bfc151` (the WYN-073 merge, PR #195 — the last known-fully-good build before either WYN-074 or WYN-075 touched image loading).
2. No database/schema rollback needed.

## Notes
- Root cause of *why* `cached_network_image` failed on this Flutter Web build was not fully diagnosed (CORS ruled out; a headless-browser repro was attempted but blocked by this sandbox's own proxy, not the app) — flagged in the task file as a follow-up if real image caching on web is wanted again later, to be investigated with real browser dev-tools access rather than guessed at again.
- This whole WYN-074 → WYN-075 sequence happened within about 30 minutes end-to-end, all on the same day.
