# Deployment Log — WYN-181 (Install Prompt Banner + iOS Splash Screens)

**Release**: WYN-181 — Track 3 of epic WYN-174 (Install & Launch Experience)
**QA Status**: PASS on both sub-tasks (sub-task 1, the install banner, needed one fix/re-verify round for a disabled-button-style bug — iPad UA detection missing, accept-path not persisting dismissal — both fixed and re-verified; sub-task 2, iOS splash screens, passed QA on the first round)
**Build Status**: `typecheck`/`lint`/`build` clean (0 errors, 3 pre-existing unrelated warnings)

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `web/components/install-prompt-banner.tsx` + `web/app/install-prompt.css` (new) — custom PWA install prompt, Android/Chrome + iOS Safari variants
- `web/app/layout.tsx` — mounts the banner; adds 32-entry `appleWebApp.startupImage` metadata
- `web/public/splash/*.png` (32 new files, ~3.5MB) — static iOS launch images, light/dark × 16 device sizes
- `web/tools/wyn181_generate_ios_splash_screens.mjs` (new) — reusable generator script

**PR**: [#562](https://github.com/warren-wyn-dev/wynteam/pull/562) (`claude/wynos-online-version-1pqqws` → `main`) — no conflicts (branch was already up to date with `main`'s latest merge from the previous WYN-176 batch 4-6 PR); Founder merged within a minute of opening

**Deployment Result**:
- `WYN-158 Production Deploy` run #149 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35498844446) — **success**, all steps green (preflight, Vercel deploy, verify production routes), ~2 min total
- Post-merge `CI` run #1421 on `main` — **success**

**Production Verification**: GitHub Actions "Verify production routes" step passed (sandbox itself cannot reach `wynos.online` directly) — awaiting Founder physical-device confirmation: (1) install banner appears and works on Android and iOS, (2) launching from the iOS home screen shows the branded splash screen instead of a white flash

**Rollback Plan**: Revert the merge commit or the individual sub-task commits via a follow-up PR; the diff is additive (new component/files + new metadata field), no data/schema impact — safe to revert instantly if needed
