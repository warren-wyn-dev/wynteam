# WYNOS Web Beta 1 — Phase 1 mobile release verification

Scope: installed PWA, native-like navigation, Home feed responsiveness, and Web Push.
Existing Phase 1 implementation landed in #660. This checklist verifies the current
Next.js `web/` app instead of adding competing PWA or notification code.

## Automated checks

From `web/`:

```bash
npm ci
npm run lint
npm run typecheck
npx playwright test tests/browser/pwa-cache-refresh.spec.ts \
  tests/browser/pwa-install.spec.ts \
  tests/browser/native-navigation.spec.ts \
  tests/browser/native-performance.spec.ts \
  tests/browser/native-push.spec.ts
npm run build
```

The PWA cache tests cover live icon refresh, last-successful-icon offline
fallback, fingerprinted asset reuse, scoped cleanup of superseded WYNOS caches,
and the rule that authenticated pages/API calls never enter the static cache.

## Preview checks before any production change

- Verify `/manifest.webmanifest`, all referenced icons, and `/sw.js` return
  successful responses. Confirm the manifest remains `display: standalone`.
- Verify `/api/push-config` returns `configured: true` in the intended preview
  environment before treating Push as available. Do not paste configuration
  values, tokens or notification payloads into screenshots/issues.
- Use the preview's real auth flow and test accounts; source-only fixture tests
  do not establish that production Supabase delivery, permissions or account
  switching work.

## Real-device gate (not reproducible in desktop browser emulation)

| Device | Check | Result |
| --- | --- | --- |
| iPhone Safari | Add to Home Screen, launch from icon, check native white status bar, safe areas, splash and keyboard | Pending |
| iPhone installed PWA | Navigate across all five tabs; open a post and return to exactly the same Home feed position | Pending |
| iPhone installed PWA | Opt in from Settings with a user gesture; receive background/foreground pushes and tap through to the correct chat/post | Pending |
| iPhone installed PWA | Sign in as A, enable Push, switch to B and verify A's private notifications never appear for B | Pending |
| Android Chrome | Install PWA, launch standalone, verify tabs, gestures, feed scroll restoration and keyboard | Pending |
| Android installed PWA | Opt in to Push, verify notification click destination and sign-out token cleanup | Pending |
| Both | Simulate weak/offline network; app icon loads from last successful cache, auth/content errors stay explicit rather than showing stale private data | Pending |

Capture the device model, OS/browser version, preview commit and pass/fail for
each row, without sharing personal messages or FCM tokens.

## Feed performance review

- Compare Home, Chat and Profile experience on a midrange Android and iPhone
  with the previous production release; measure LCP, INP and CLS via available
  Speed Insights/Analytics where data is present.
- Verify opening a post and returning preserves feed position; background
  prefetch must not run when `Save-Data` is enabled or the page is hidden.
- Test a long feed with images and the existing scroll-to-hide chrome; ensure
  no delayed jump, oversized media download or gesture conflict.

## Release discipline

`main` pushes touching `web/**` can trigger the WYN-158 production deployment.
Keep fixes on a separate branch and in a draft PR until CI, preview QA,
real-device checks and explicit Founder approval are complete.
Do not merge or manually deploy the Push Edge function based on emulated
browser tests alone.
