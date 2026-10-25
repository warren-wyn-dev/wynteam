# ZOKY Merchant frontend release, 2026-10-24

The Founder asked “เอาขึ้นเว็บจริง” and then “ต่อ” for the approved Merchant design. This authorizes the isolated Merchant frontend release and Merchant-origin root entry. The approval is recorded in the candidate's `.wyn/company/APPROVALS.md`. It does not authorize database changes, an all-main release, security-policy changes, or bypassing a required production reviewer.

The live `merchant.wynos.online` alias belongs to Vercel project **web** (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`, team `team_Kamt1PUT5XKn9MWrF404re1w`), not the separate `wynteam-gesb` preview project. Its deployment also serves Food, ZOKY, Social and Maps. The candidate therefore starts from the actual current production commit `e6f577dcccb86b51c68d91e754b19fe4cfa27222`, retaining later Food fixes, and carries only the reviewed Merchant changes. The immutable old production deployment is `dpl_HhzmnfVpb9qyHd7yeiAiiUmkbPV9` / `web-79yhwvs9b-warren14.vercel.app`.

The general release freeze (#1142–#1151) and the previous ZOKY exception remain unchanged. This new manual workflow only accepts the full SHA and exact file list in `zoky-merchant-ui-release.json`, at the tip of `release/zoky-merchant-ui-20261024`. The unfinalized zero pin fails closed. No workflow or database file is part of the product candidate. Shared support files are individually allowlisted; unrelated Food, Social, Maps, banner and featured-store changes are excluded.

The control PR also sets `git.deploymentEnabled: {"main": false}` in `web/vercel.json`, enforcing the existing all-main freeze at that configuration root while leaving unspecified preview branches enabled. This setting is supported by Vercel's published Git configuration schema and does not prevent the reviewed manual CLI release. It is not part of the product candidate. MCP's normalized project metadata does not expose `rootDirectory`; if a Git project instead uses repository root, this web-scoped setting is not a repository-root guard. The current `web` Git bot explicitly rejects deployment with “There is no GitHub account connected to this Vercel account”; no deployment was created for the control SHA and the live production SHA remains unchanged. The repository-root configuration is left untouched. No Git account is reconnected by this work. The protected CLI staging step independently reads the existing project root setting and uploads the correct directory.

After this reviewed control PR is merged, dispatch **ZOKY Merchant UI scoped release** on `main`, with the manifest's SHA and confirmation `ZOKY_MERCHANT_UI_20261024`. Its steps are:

1. Validate original repository, main, exact SHA, branch tip, current-production ancestry, path manifest and expiry, and run the unchanged freeze/secret checks plus the new negative tests.
2. Run the candidate's full web/Flutter checks and legacy/compiled Merchant browser tests against synthetic fixtures. This job has no production credentials and makes no database connection.
3. Wait for the existing **production** environment reviewer. Revalidate the candidate and expiry after the wait, inspect the still-current live deployment and aliases, then build a production artifact with `--skip-domain` in the correct project. No production domain is assigned at this step.
4. Verify the immutable host, login, Flutter bundle, CanvasKit and 3D assets using authenticated HTTP access. Production configuration is reused by the protected deployment step without printing values; no `.env` file is fetched. Preserve `ZOKY_LEGACY_FOOD_REDIRECT=0` (live Food currently serves HTTP 200), and enable only `ZOKY_MERCHANT_FLUTTER_ENABLED=1`.
5. Wait for the production environment reviewer before promotion. Recheck the candidate, expiry, original live deployment, unchanged Food phase and staged artifact's project, SHA, production target and READY state. Promote that same tested artifact, then verify the original aliases and public core routes.

Merchant's `/merchant` route remains the existing fallback, and `payments=return` / `payments=refresh` remain in the legacy payment setup. The root cutover affects `merchant.wynos.online` only. No database, Edge Function, auth provider, spend, environment protection, or other origin's routing is changed.

If any post-promotion check fails, stop and preserve the run evidence. Do not perform an automatic rollback. The Founder can direct Vercel Instant Rollback to the recorded old deployment. A separate root-flag-off release is also possible if the Founder chooses it. Never deploy a stale candidate after production drifts; update the production base, rebuild, revalidate and review a new pin.

The GitHub production environment remains restricted to `main` and requires reviewer `warren-wyn-dev`. Chat authorization does not self-approve that platform review. No personal tokens or customer data are required for verification. Protected staging review and promotion review are concrete, reviewable final actions.

## Account-exit follow-up, 2026-10-25

The first release run, `40097479381`, was cancelled before staging or promotion after review found that an account without an accessible store could not reach sign-out. No production deployment or domain assignment occurred in that run.

The reviewed replacement is `514fd13a1655d2c94fed82272d12273e98a17a1b`, on the same live base and release branch. It includes the `9a53e008` account-exit fix: empty, initial-load failure and revoked-store states can use the existing shared sign-out callback. The normal shop home is unchanged. Independent review found no blocker/HIGH.

Verification passed: Flutter analysis, all 30 Flutter tests, release compilation and system-font guard; all 16 compiled browser cases (10 existing core cases plus mobile/desktop empty, offline and revoked-store account exits); ESLint and diff checks. The exact 103 approved paths are unchanged. Food, Next configuration, auth callbacks, database, existing workflows and release controls remain byte-identical to the live base. The manifest changes only the reviewed SHA; targets, root flags, required production reviewer and rollback target remain unchanged.

PR #1239 is merged as code integration (`b9142015`). Production still uses the isolated live-based candidate rather than all of main. The replacement must pass the existing workflow guard and credential-free verification before the protected staging and promotion actions.
