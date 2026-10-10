# WYNOS Admin — free-only development and release QA

Decision: **2026-10-10 — Founder requires no paid services, plan upgrades, or spending.**
This is a hard constraint for WYNOS Admin development, testing and release.
Do not purchase capacity, change billing, upgrade Supabase/Vercel, or assume a free trial will remain free.

## Resources allowed without purchasing capacity

- **GitHub:** existing repository and its included/no-cost CI usage only; no paid runners or billed services.
- **Local development:** Supabase CLI and Docker on an existing computer to run an isolated Postgres/Auth/API stack. This does **not** need a third hosted Supabase project.
- **Automated regression:** the existing throwaway PostgreSQL CI service containers check RLS/RPC/financial transitions. They are not a substitute for testing browser login against Auth.
- **Admin application:** Next.js built locally with a synthetic test backend. Never use a Production or Stripe Sandbox URL or credential in QA.
- **Vercel:** existing Admin project inside Hobby free limits. Do not create new projects to bypass quotas or repeatedly call previews after 402.

Current limitations: Production and Stripe Sandbox occupy both available active Supabase Free slots. Designated Admin staging is inactive/inaccessible. `admin.wynos.online` is not attached to the Admin Vercel project and current domain access returns 403. Do **not** pause live projects or claim/move DNS automatically.

## Safe local QA setup

Prerequisites on a developer's existing computer: Docker, Supabase CLI and Node.js 22; use an isolated checkout.

1. From the repository root run `supabase start` to start a **local-only** Supabase stack. If schema/migrations fail, fix local fixtures; never run a destructive database command against a hosted backend.
2. Run `supabase status` to obtain the **local** API URL and local anon/publishable key. Never copy Production, Stripe Sandbox, real Auth accounts or customer data.
3. In `admin/.env.local`, set `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321` (or actual local port), plus `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` from the local status.
4. In `admin/` run `npm ci`, `npm run check:free-local-qa`, `npm run test:workspaces`, `npm run lint`, and `npm run dev`. Passing the preflight proves the URL is loopback-only, **not** that Supabase is healthy or seeded.
5. Prepare synthetic local test accounts for Admin, Moderator and regular User. Verify local `profiles.platform_role` and test only local RLS/RPC migrations. Do not reuse real credentials.
6. Test login, sign-out, role revocation, stale sessions, unauthorized direct RPC calls, Admin-only Food order pages, mobile views (320/390/768/1440px) and accessibility. Record errors and audit evidence.
7. Record exact PR SHA, runnable commands, test account roles, migration version, test logs and rollback. Test financial features with disposable data and provider test fakes, never live money.

`npm run check:free-local-qa` explicitly refuses **all remote URLs**, including Production, Stripe Sandbox and staging. This is an extra local guard; it does not modify hosted Vercel build/deploy preflight.

## Honest release gates

- GitHub CI success shows source checks, build, guest redirects and local PostgreSQL/RLS tests; **it does not demonstrate real signed-in browser QA**.
- Local Supabase Auth plus synthetic role E2E is a useful zero-cost integration path, but cannot prove a Vercel-hosted Preview, real operator sessions or DNS.
- A release requires independent authorization, reviewed access matrix, verified production secrets/URL, reliable rollback and live smoke checks with authorized staff.
- Until domain ownership/access is resolved, `admin.wynos.online` remains unavailable; a verified existing Vercel-assigned hostname can be **evaluated** but is not an automatic fallback deployment.
- If any gate remains impossible within free limits, keep the affected capability OFF/Draft. Do not bypass the test, spend money, pause existing projects, or claim "100% complete".
- The 33 planned capabilities in Control Map remain planned until separately implemented and tested. No automatic Production SQL, role grants, Stripe transactions, promotions or merges.

## Minimum 0-baht acceptance checklist

- [ ] Candidate commit has a green full CI and role/RLS regressions
- [ ] Local synthetic Admin, Moderator and User browser/RPC workflows pass
- [ ] Auth errors, revoked permissions, impersonation attempts and unauthorized data access are blocked
- [ ] Real operation endpoints include server-side validation, scoped permissions, reason, audit and rollback
- [ ] Admin URL, correct project, authorized Production operator smoke and rollback are verified
- [ ] No additional paid plan, billing, domain purchase or suspension of active projects

Related: [Central Control specification](./central-control-master-spec.md), [staging/release QA](./staging-release-qa.md), PR #1053, issue #1067.
