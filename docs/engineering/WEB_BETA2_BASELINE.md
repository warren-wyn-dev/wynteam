# WYNOS Web Beta 2 baseline

Status: Development/Staging only.

## Baseline

WYNOS Web Beta 2 starts from the exact Web application code currently deployed as WYNOS Web Beta 1 Production:

- Beta 1 Web baseline commit: `d92bd1622ff9795ea29901453d5b1ccf1d735db4`
- Beta 2 development branch: `web-beta2`
- Beta 2 Vercel project: `wynos-web-beta2-staging` (`prj_70GIbp0o056AOPsVUAie9CROED7r`)
- Beta 2 Supabase project: `yydgdapzlrjmlrjgijkj`
- Beta 1 Production Supabase project: `kqokpocajhfbidcxpvhh`

The initial Beta 2 application UI/UX, routes, navigation, components, features and runtime behavior must remain the Beta 1 baseline until a Beta 2 change is intentionally made.

## Isolation rules

1. Never point Beta 2 at the Beta 1 Production Supabase project.
2. Never use Production user data as Beta 2 test data.
3. Beta 2 deployment must target only the dedicated Beta 2 Staging Vercel project.
4. `web-beta2` must not be merged into `main` or released to `wynos.online` without explicit Founder approval.
5. New UX/UI, backend, API and database work is developed and tested on Beta 2 first.
6. Important Beta 1 fixes made after this baseline must be reconciled into Beta 2 deliberately so the branches do not silently drift.
7. Beta 2 release to Production is a separate, explicitly approved operation. There is no automatic Beta 2 -> Production release.

## Parity gate before feature development

Before treating the baseline as ready, verify:

- Home
- Search
- Post creation/detail/activity
- Notifications
- Profile
- Chat
- Clubs
- Login / Signup
- Settings and primary navigation
- Staging database tables/RPCs/RLS/storage used by the Web application
- Staging deployment contains the Staging Supabase origin and does not contain the Production Supabase origin

Test data is intentionally separate from Production; data contents are not expected to be identical.


## Baseline certification — 2026-09-28

- Full browser regression on the Beta 1 Web baseline: 995 passed, 9 skipped, with one WebKit/iPhone 432px timing case failing on the first run.
- The single failed case was re-run independently and passed.
- Baseline finalization run: GitHub Actions `36385850974` — success.
- Certified protected Staging deployment: `dpl_DH6DJSYrXigjuzguM9fHrkj3GhBN`.
- Certified Preview URL: `https://wynos-web-beta2-staging-a2l8925m1-warren14.vercel.app`.
- Hosted smoke verified the main Web routes, Next.js runtime, Staging Supabase origin, absence of the Production Supabase origin, and public Firebase Web configuration.
- The dedicated Vercel Staging project is configured to ignore Git-connected branches other than `web-beta2` (controlled exact-SHA CLI deploys are also allowed).
- Vercel isolation run: GitHub Actions `36386358134` — success.
- The permanent `web-beta2` Staging workflow now uses fail-closed project checks, one Playwright retry for browser timing flakes, protected Preview deployment only, same-origin redirect smoke checks, and automatic bypass revocation.
- Production Vercel remains on the WYNOS Web Beta 1 deployment and was not targeted by any Beta 2 deployment.

### Environment-only differences

The application baseline is copied from Beta 1, but Staging intentionally uses separate accounts and test data. External provider credentials are not assumed to be shared with Production. In particular, Google OAuth on the Staging Supabase project remains disabled until dedicated Staging OAuth credentials are configured; email/password authentication is the supported Staging test path for now. This does not change the Beta 1 UI baseline or connect Beta 2 to Production data.

## Installed iPhone visual baseline

Source-code equality is not sufficient for parity certification on iOS Home Screen apps because iOS caches PWA status-bar metadata at installation time.

The Founder-provided real-device Beta 1 reference currently uses a viewport where the app/backdrop extends behind the iPhone system status area. Beta 2 intentionally reproduces that installed-device geometry with `appleWebApp.statusBarStyle = "black-translucent"` while retaining the Beta 1 safe-area/layout CSS.

For visual acceptance, compare the rendered Beta 2 Home Screen app against the Founder-provided Beta 1 screenshots on the same iPhone dimensions. Existing Beta 2 Home Screen shortcuts must be removed and re-added after a status-bar metadata change because iOS caches that metadata.

Staging account/profile/post contents remain separate from Production data by design; visual parity means geometry, components, typography, controls and behavior, not copied Production user data.
