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
