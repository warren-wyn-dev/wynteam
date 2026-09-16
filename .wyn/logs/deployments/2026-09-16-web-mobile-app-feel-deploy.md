# WYNOS Web Beta1 — Mobile App Feel Deploy

Date: 2026-09-16

## Release

- Scope: PWA install support (manifest, icons, service worker), bottom nav icon
  set (Home/Search/Post/Notification/Profile, Chat moved into the Home header),
  Framer Motion page/modal/like animation, 44x44 touch-target fixes
- Version: within **WYNOS Web Beta1** — no version bump requested, `.wyn/company/VERSION_CONTROL.md` not touched
- PR: [#468](https://github.com/warren-wyn-dev/wynteam/pull/468) — merged by warren-wyn-dev (this session) at 2026-09-16T01:00:36Z
- Commit deployed: `5192a39cd8348186df65f9789eb6ce1706b67c88` (merge commit on `main`: `617c8e508cce44d6206185bb9b6206fae454c1f7`)

## QA Status

PASS (AI QA & Security, this session). Two testing mistakes were caught and corrected during QA rather than accepted at face value: the `/dev/home-fixture` page wires every interaction handler as a no-op, so the drawer and the like-button bounce both looked "broken" against it at first — both were re-verified against a temporary standalone harness with real state, confirming the drawer's open/close animation and the heart's keyframe bounce (1 → 1.35 → 0.95 → 1.08 → 1) both run correctly with no console errors.

## Build Status

- Local sandbox: `npm run check` (lint + `tsc --noEmit` + `next build`) green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed / 26 failed, but every failure traced to a pre-existing test/CI-environment cause (visual-snapshot font drift already isolated in PR #467's QA, a stale source-text assertion on an untouched file, a `next dev`-only overlay/JIT-compile artifact since this check runs against the dev server rather than a production build, and unauthenticated-session redirects on gated routes) — documented in a PR comment before merging; zero overlap with this PR's changed files. Full root-cause writeup: https://github.com/warren-wyn-dev/wynteam/pull/468#issuecomment-5690426146

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

29 files in `web/` — see PR #468 for the full breakdown (it also carries the PR #467 deployment-log docs from earlier in this branch's life). No backend/RPC/schema changes; no new environment variables. Notable dependency changes: added `framer-motion`, removed a briefly-installed `next-pwa` (unmaintained since 2022, unpatched high-severity RCE in its dependency chain — see PR description), bumped `next` 16.3.2 → 16.3.5 to close two unrelated critical RCE CVEs `npm audit` flagged.

## Deployment Result

Automatic: merging PR #468 into `main` triggered `wyn-158-production-deploy.yml` ([run 35042350573](https://github.com/warren-wyn-dev/wynteam/actions/runs/35042350573), push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T01:01:01–01:01:37Z)
2. `Deploy to Vercel production` — success (2026-09-16T01:01:37–01:02:49Z)
3. `Verify production routes` — success (2026-09-16T01:02:49–01:02:52Z): polled `wynos.online` until it served the new build, confirmed no legacy Flutter bootstrap, checked `/ /search /notifications /chat /settings /profile/me /clubs /bookmarks` all returned success

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from the GitHub Actions runner) — success, all 8 routes checked
- **Not AI-confirmed**: this sandbox's outbound network policy blocks arbitrary external hosts (`wynos.online` is not on the egress allowlist), so I could not independently curl it myself — same limitation as the previous deploy, relying on the CI job's own verification
- **Still needed from Founder**: opening wynos.online on a real phone to confirm the PWA install prompt appears, the bottom nav reads right, and the animations feel good — this log covers infrastructure-level success, not a human's read on whether it now actually *feels* more like a native app

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a straightforward code-only Vercel deployment, same as the prior release.
- If a regression is found: **do not roll back automatically** (per `.wyn/company/VERSION_CONTROL.md` — Owner must direct any rollback). In order of preference:
  1. Fix-forward: push a corrective commit to `main` (or a hotfix branch → PR → merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
  2. If a hard rollback is directed by Founder: `git revert` the merge commit (`617c8e5`) and push to `main`, or use `vercel rollback` to the previous production deployment from PR #467 — both require explicit Founder instruction first.
- If the service worker specifically is ever suspected of serving stale content: it only caches `/_next/static/*` (content-hashed, safe to cache indefinitely) and `/icons/*` plus the logo — never HTML or Supabase requests — so a bad deploy cannot get "stuck" behind it. Bumping `CACHE_NAME` in `public/sw.js` (already versioned `wynos-static-v1`) forces every client to drop old cached assets on next visit.
