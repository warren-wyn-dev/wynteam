# WYNOS Web — Staging

Founder decision, 2026-09-26 (recorded in `.wyn/company/APPROVALS.md`).

## What staging is

Every pull request that changes `web/` gets its own **staging deployment**, a protected Vercel preview built from the PR's latest commit. Workflow: `.github/workflows/web-next-phase5-preview.yml`.

For each push to such a PR the workflow:
1. runs `npm run check` (lint, typecheck, node test suites, production build);
2. deploys a Vercel **preview**. The production alias `wynos.online` is never touched;
3. smoke-checks the main routes on the deployed URL;
4. posts or updates a "WYNOS Web staging" comment on the PR with the URL;
5. runs the full Playwright browser QA (Chromium + WebKit) against the deployed URL, using a temporary Vercel protection bypass that is revoked at the end of the job.

## How to use it (release gate 5)

- Open the staging URL from the PR comment on a phone or desktop. It is protected by Vercel Deployment Protection, so sign in to Vercel first.
- Staging verification means the workflow above is green and, for user-facing changes, the change was tried on the staging URL.
- Merging the PR to `main` still deploys production automatically (`wyn-158-production-deploy.yml`, Founder choice). Staging therefore happens **before merge**. Do not merge a user-facing web PR whose staging job is red or has not run.

## Limits (accepted by the Founder)

- **Shared database.** Staging uses the production Supabase project. Test with developer accounts only. Never rehearse database migrations or destructive actions on staging; those still go through the Founder-approved migration process.
- **No Push on staging.** Firebase config is not injected into preview builds, so Push cannot be enabled there. This avoids registering extra device tokens against real accounts. Test Push after release.
- **Fork and Dependabot PRs** get no secrets, so they get no staging deployment.

## Rollback

Production rollback is unchanged: use Vercel Instant Rollback to the previous production deployment, or revert the merge commit on `main`.

## Isolated Beta2 staging (manual pilot; independent of the legacy per-PR previews)

Founder approved a separate **Supabase Free** project, no incremental spending. The separate
Singapore database is `yydgdapzlrjmlrjgijkj`, with the reviewed WYN-135/137/159 schema
already installed; production remains `kqokpocajhfbidcxpvhh`. The existing
`web-next-phase5-preview.yml` **still uses production Supabase**. Never run staging
migrations, destructive tests or production-data fixtures against those legacy PR URLs.

The new `web-beta2-isolated-staging.yml` is **manual-only** until Vercel access and
environment isolation are independently verified. It refuses to deploy if required
secrets are absent, either Supabase URL points at the wrong project, the staging key
is not a publishable key, either key is shared with production, the Vercel project
is shared, or the separate Vercel project does not require Vercel Authentication on
previews. The workflow always attempts to revoke its temporary QA bypass. It never
uses `--prod`, touches the production alias, or applies SQL.

An authorized infra owner must first provision/reuse an explicitly approved **separate**
Vercel project under the existing authorized scope, enable Vercel Authentication for
all previews, and configure GitHub Actions secrets:

- `STAGING_SUPABASE_URL` = `https://yydgdapzlrjmlrjgijkj.supabase.co`
- `STAGING_SUPABASE_PUBLISHABLE_KEY` = that staging project's publishable key
- `STAGING_VERCEL_PROJECT_ID` = the separate staging project's `prj_...` ID

Existing production secrets `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and
`VERCEL_PROJECT_ID`, plus the existing `VERCEL_ORG_ID` and `VERCEL_TOKEN`,
are only used by the guard / authorized Vercel API. **Never supply a service-role
key to NEXT_PUBLIC_* or use production accounts, credentials, messages, photos
or auth exports as staging fixtures.** Check Vercel plan and any provisioning cost
before creating a project; stop for new Founder approval if spending is required.

When an authorized operator has the **staging-only server secret** in a secure local
environment, the reviewed manual `web/scripts/bootstrap-beta2-staging.mjs --apply`
command can create seven strictly synthetic identities and two private test Clubs.
It refuses production URLs, publishable keys, missing explicit confirmation and
CI execution. Set `STAGING_SUPABASE_URL`, `STAGING_SUPABASE_SERVICE_ROLE_KEY`
and `CONFIRM_WYNOS_STAGING_BOOTSTRAP=YES` through the operator's secure local
environment (not in shell history, PR comments, CI or client variables). The
script writes passwords and IDs to a permission-restricted **local temporary
file**. Never commit or upload that file; securely distribute test credentials
only to the authorized QA team, retain it for cleanup and remove the seeded
users/data after testing. Do not run the script twice unintentionally. The
staging project is currently unseeded; adding this script does not provision
accounts until an authorized operator actually executes it.
Cover developer Owner/Admin/Moderator/Member, non-developer Member and outsider;
do not mark authenticated staging E2E as passed until these actual staging logins
and cross-role denials have been tested. Keep Push disabled and review Free quotas.
When isolated staging is green, propose a **separate** reviewed PR to migrate the
existing per-PR preview workflow from production to staging; do not silently change
the production deployment or existing PR workflow in this pilot.

Production developer-account UAT still follows Issue #748 on `wynos.online`, not
this protected pilot. Issue #749 stays open until project protection, runtime
variables and real synthetic-account tests are verified.

### Isolated Beta2 staging security audit (2026-09-28)

**Staging-only** migration `web_beta2_staging_anon_grants_parity` has been
applied to Supabase ref `yydgdapzlrjmlrjgijkj`, with the reviewed SQL source
at `docs/engineering/staging-only/WEB_BETA2_ANON_GRANTS.sql`. Read-only
post-migration verification: 143 public SQL functions on staging; 15 callable
by `anon`, of which three use SECURITY DEFINER; 138 callable by
`authenticated` (unchanged); zero staging Auth users and developer identities.
It removed the 103 excess anonymous function grants identified by comparing
the staging baseline with the existing production function signatures and
privileges. The eight Beta2 developer, Club Chat and Club Announcement RPCs
are **not** anonymously executable, including `is_developer_account()`.
No production schema, production data or production ACL was changed. The
production schema currently has additional functions absent from staging:
matching anonymous EXECUTE grants for the overlapping functions does **not**
mean full schema parity.

The security advisor still flags four inherited SECURITY DEFINER views in
both databases; they require independent multi-role UAT tracked in [#688](https://github.com/warren-wyn-dev/wynteam/issues/688).
Staging also reports other advisor warnings, which must be individually
triaged; do not claim zero security warnings based on this one migration.

**Outstanding release gates:** Founder reports the three staging GitHub
repository secrets were added, but the GitHub connector cannot verify their
names or values. The first authorized manual staging workflow run must pass
its exact-project, distinct-key and Vercel SSO fail-closed checks. The workflow
cannot be dispatched before it exists on GitHub's default branch, and merging
`web/**` auto-deploys public Beta1 even while Beta2 feature flags stay off:
obtain explicit Founder merge authorization separately. Human synthetic
staging-account bootstrapping and role-denial browser UAT have not run.
