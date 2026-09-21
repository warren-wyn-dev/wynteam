# Deployment Log — WYN-185 Wynos Web Beta1 Fixes (12-item bug/UX bundle)

**Release**: Founder-issued 13-item bug/UX fix pass on WYNOS web — Post Detail keyboard
behavior, Public Club RLS, Trending Top 100 button, Draft system, Share reliability,
Search URL state, Follow wording, DM Request timing, Profile external link,
`MAX_POST_IMAGES` single source of truth, and a UX/UI + accessibility consistency
pass. Item 8 (Activity) was implemented then fully reverted mid-session at Founder's
explicit instruction ("Item8ลบออกไปเลย") — 12 of 13 items shipped.

**Task Log**: `.wyn/tasks/active/WYN-185-wynos-web-beta1-fixes.md` (full root cause,
files changed, and test results per batch).

**Build Status**: `npm run check` (lint/typecheck/build) clean, 0 errors, 2
pre-existing warnings. Full Playwright suite across all 3 CI browser projects
(`webkit-iphone`, `chromium-android`, `chromium-desktop`): 267/267 PASS.

**QA & Security**: Full pass by AI QA & Security — first pass returned FAIL (3 stale
regression-test assertions from this batch's own intentional product changes, plus a
HIGH security finding on item 11's deploy sequencing). Both resolved and independently
re-verified PASS. Full findings: `.wyn/tasks/bugs/WYN-185-stale-regression-assertions.md`.

**CI flakes found and fixed post-QA** (real CI's full 3-project matrix caught what
this session's single-project sandbox runs couldn't):
- `post-detail-keyboard.spec.ts` "single scroll container" — a genuine scroll-paint
  race on `chromium-desktop` (fixed: wait for `window.scrollY > 0` before asserting)
  and, separately, `page.mouse.wheel()` being entirely unsupported under mobile
  WebKit emulation on `webkit-iphone` (a hard API gap, not a flake — fixed: switched
  to `window.scrollBy()`, which works uniformly across engines).

**Security**: Item 11 (Profile external link) ships a render-time
`normalizeExternalUrl()` re-validation in `profile-route.tsx` as defense-in-depth.
The DB-side write-time validation trigger
(`supabase/migrations_wyn187_profile_external_link_validation.sql`) was applied by
the Founder directly via the Supabase Dashboard before this deploy, per Change
Control (no AI applies production SQL).

**Approval**: Founder gave explicit production deployment approval ("อนุญาตขึ้นเว็บ")
after QA & Security PASS.

**PR**: [#586](https://github.com/warren-wyn-dev/wynteam/pull/586)
(`claude/wynos-web-beta1-fixes-r3c06k` → `main`), merged by Claude with the Founder's
explicit deployment authorization (commit `8780fe9`).

**Rollback Plan**: Standard PR revert. No destructive migrations in this PR — the
`wyn187` migration is a separate, additive, Founder-applied file independent of this
PR's own build/deploy.

**Deployment Result**:
- `WYN-158 Production Deploy` run #172
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35597707980) — **success**.
- Post-merge `CI` run on `main`
  (https://github.com/warren-wyn-dev/wynteam/actions/runs/35597708010) — **success**.
- Deployed to `wynos.online`.
