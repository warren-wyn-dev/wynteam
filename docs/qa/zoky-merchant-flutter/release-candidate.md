# Merchant-only release candidate

Candidate branch: `release/zoky-merchant-ui-20261024`.

Production base: `e6f577dcccb86b51c68d91e754b19fe4cfa27222`, verified through Vercel metadata for `merchant.wynos.online` on 2026-10-24. The live deployment is `dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9` (`web-79yhwvs9b-warren14.vercel.app`) in project `web` (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`), team `team_Kamt1PUT5XKn9MWrF404re1w`. The same deployment serves the Food, ZOKY, Social and Maps origins.

The previous candidate based on `0533fb36` is superseded. This branch replays its scoped Merchant commit, then the subsequent Merchant branding/auth/home commits onto the actual live base. It does not merge main or copy the web directory from main. The later Food storefront and navigation fixes remain present.

The release changes only Merchant frontend/build/test source and its documentation. The Food pages/components, `food-origin.ts`, `food-merchant.ts`, shared auth callback, Push prompt, Next configuration, workflows, tools, Supabase source and schema stay byte-identical to the live base. Shared changes needed by Merchant are the package build commands, generated-output ignores, English UI translations, the synchronous Push permission helper, and the narrowly controlled Merchant-origin root rewrite. Homepage banner/featured-store modules remain absent.

`ZOKY_MERCHANT_FLUTTER_ENABLED` remains off by default in source. The approved production artifact enables it only for the exact Merchant host; Stripe Connect `payments=return` and `payments=refresh` still reach the legacy payment setup handler. Existing `/merchant` routes remain available for fallback. The current Food redirect phase must be preserved on deployment.

Validation on this actual production base: full `npm run check` passed (390 Node regressions, Flutter analysis, 27 Flutter tests, Flutter release build, font guard and Next.js production build). The focused compiled/shared-auth browser suite passed 10/10 on mobile and desktop. An additional 27 routing, Food-origin and Maps regression cases passed. Only synthetic fixtures and dummy public configuration were used; no real account or database was accessed. The release-specific shortcut test harness loads this production base's existing Food-origin module.

Latest visual evidence is in `final-home.md` and its captures. The home has eight 3D tool shortcuts, actual shop/status/sales/readiness data, same-baseline smaller decimals, and no duplicate weekly-quality card. Quality remains an actionable shortcut to aggregate reviews. These are results for the committed candidate source; immutable staging and production verification will be recorded by the reviewed release workflow, and have not happened yet.

The Founder instructed “เอาขึ้นเว็บจริง” and “ต่อ” on 2026-10-24. Production still follows the reviewed, narrow Merchant release workflow and the existing protected GitHub `production` environment. The general all-system release freeze, its acceptance issues, and required reviewer policy are unchanged. A staged production build must pass checks before promotion. Preserve the deployment above for Founder-directed recovery; do not roll back automatically.

The integration reuses the existing account, Food backend, permissions and payment/order/delivery flow. It includes explicit manual receipt confirmation, preparation ETA, membership-filtered stores and deferred photo upload. The documented residual concerning an immutable storage object after an abandoned failed completion remains; no storage policy is weakened. No database or live customer-data tests are part of this release.

## Account-exit fix verified on 2026-10-25

The earlier `0fc4650b` pin is superseded by this branch's sign-out follow-up. Source fix `9a53e008`, cherry-picked as `57f63d91`, preserves an account exit when stores are empty, unavailable or finally revoked. No normal-home design or authentication contract changes. The previous release run `40097479381` was cancelled before a staging artifact or production action.

After the fix, Flutter analysis, all 30 Flutter tests, release compilation and font guard passed. Compiled mobile/desktop browser QA passed 16/16, including the ten existing core cases and six new empty/offline/revoked-store sign-out cases. ESLint and diff checks passed for the expanded browser fixture. Independent review found no CRITICAL/HIGH issue. The unchanged Node/backend source retains the baseline 390-test evidence above; the release workflow must run the full candidate checks again before staging.

The exact reviewed 103-path set is unchanged. Food source, shared auth callbacks, Next configuration, workflows, Supabase and tools remain byte-identical to `e6f577dc`. Read-only Vercel metadata on 2026-10-25 confirmed that `merchant.wynos.online` still serves `dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9` / `e6f577dc` in the pinned `web` project. Immutable staging and promotion remain pending and are not claimed by this local verification record.
