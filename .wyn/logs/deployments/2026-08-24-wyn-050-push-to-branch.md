# Deployment Log — WYN-050 (WYN Admin Dashboard)

Release: code-integration push to the designated session branch (not `main`)
Date: 2026-08-24

## QA Status

**PASS, after a real Major finding was caught and fixed in the same session.** See `.wyn/tasks/approved/WYN-050-admin-dashboard.md`'s "Independent QA" section for the full record, and `.wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md` for the bug report.

Round 1 (FAIL): `admin_dashboard_metrics()`'s role guard used `internal.current_platform_role() not in ('admin', 'moderator')` without wrapping the (possibly-`NULL`) role in `coalesce()`. A caller with an `auth.users` row but no matching `profiles` row gets `NULL` back from `current_platform_role()`, and `NULL not in (...)` evaluates to `NULL` -- which PL/pgSQL's `if` treats the same as `false`, silently skipping the exception. Reproduced live: such a caller got real aggregate platform metrics back with no rejection at all.

Fix: `coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator')`. Verified red before the fix (new CHECK4 failed exactly as predicted) and green after, then re-ran all 21 SQL regression scripts with no cross-task regression.

## Build Status

- `check_schema_ordering.py`: OK
- All 21 SQL regression scripts (`wyn_021` through `wyn_050`): **PASS**
- `next build`: clean, 0 errors/warnings
- `npm run lint`: **0 issues**

## Deployment Target

**`claude/phase-7-continuation-5s8by3` on GitHub only** — pushed via `git push`, not merged into `main`, no PR opened (same reasoning as WYN-044/WYN-049's deployment logs: this session doesn't open PRs without an explicit request, and none was made this round).

## Changes

13 files changed (937 insertions), committed as `2cde13d`:

- **SQL**: `admin_dashboard_metrics()` RPC (`supabase/schema.sql`) + `supabase/tests/wyn_050_admin_dashboard_test.sh` (17 checks, including the CHECK4 that catches the bug above).
- **Web**: `lib/admin-metrics.ts`, `components/admin/{stat-card,dashboard-metrics,dashboard-skeleton,refresh-button}.tsx`, `app/(admin)/error.tsx` (new), `app/(admin)/page.tsx` (rewritten from the WYN-049 placeholder).
- **Docs**: `.wyn/tasks/approved/WYN-050-admin-dashboard.md`, `.wyn/docs/design/wyn-050-admin-dashboard.md`, `.wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md`, `.wyn/company/CONTEXT.md` updated.

## Deployment Result

**Pushed successfully.** Code-complete and QA-approved (after the fast-follow fix); not yet merged into `main`, not yet deployed to any live URL (same gap as WYN-049 -- no Vercel project points at `admin/` yet).

## Production Verification

Not applicable — same Readiness Gate as every prior task, plus WYN-049's admin-specific gap (no hosting target for `admin/` yet). The live-data path (real `admin`/`moderator` account seeing real numbers) is untestable without a real Supabase project, same limitation WYN-049 documented.

## Rollback Plan

- **Code**: nothing on `main` yet; `git revert 2cde13d` on the session branch if needed.
- **Database**: one new function (`admin_dashboard_metrics()`), no table/schema changes. Not applying this `schema.sql` version is the entire rollback (no live database exists to migrate back).

## Next Steps

Same as WYN-049's: awaiting an explicit request to open a PR/merge to `main`, and Founder action on hosting (`admin/` needs its own Vercel project) and a real Supabase project to verify the live path. Phase 7's next task per the roadmap is WYN-051 (Admin User Management).
