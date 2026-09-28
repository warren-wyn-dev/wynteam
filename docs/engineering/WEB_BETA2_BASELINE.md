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
