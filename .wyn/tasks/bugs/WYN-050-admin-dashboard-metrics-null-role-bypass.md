# Bug Report — WYN-050

Status: active (fast-follow fix applied in the same session, verifying now — not a separate Debug Engineer round, mirrors WYN-048's own "one-line fix, low risk" precedent)
Owner: AI QA & Security (found), fixed inline

Bug: `public.admin_dashboard_metrics()`'s role guard (`if internal.current_platform_role() not in ('admin', 'moderator') then raise exception ...`) silently does nothing for a caller with **no `profiles` row at all** — `internal.current_platform_role()` returns `NULL` for such a caller, and `NULL not in ('admin', 'moderator')` evaluates to `NULL`, which PL/pgSQL's `IF` treats the same as `FALSE` (skips the branch). The exception is never raised, and the function proceeds to compute and return real platform-wide aggregate metrics to a caller who was never verified as `admin`/`moderator` — or verified as anything at all.

Reproduction: seeded a caller with a row in `auth.users` but deliberately **no** matching row in `public.profiles` (a plausible real state — e.g. a signup that inserted the auth user but whose `profiles` insert failed or hasn't run yet), then called `admin_dashboard_metrics()` as that caller under the real `authenticated` role. `internal.current_platform_role()` confirmed to return `NULL`. The RPC returned a full row of aggregate data instead of raising — no exception, `SELECT * FROM public.admin_dashboard_metrics()` succeeded.

Root Cause: `x NOT IN (...)` in SQL/PL-pgSQL is three-valued logic — `NULL NOT IN (a, b)` is `NULL`, not `TRUE`, whenever the left-hand side is `NULL`. This project's own schema already documents this exact trap elsewhere (`set_club_member_role()`'s comment: "explicitly coalesces club_role()'s possible NULL before a `not in` check -- `null not in (...)` evaluates to NULL, not true, which would silently skip the exception and let a total stranger through") — the same class of bug was reintroduced here because the new RPC's guard clause was written without that `coalesce`.

Fix: wrap the role check in `coalesce(..., '')` so a `NULL` role becomes an empty string, which correctly fails the `not in (...)` check as `TRUE`:

```sql
if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
  raise exception 'Not permitted to view admin dashboard metrics';
end if;
```

Files Changed: `supabase/schema.sql` (`admin_dashboard_metrics()`'s guard clause, one line)

Tests: extended `supabase/tests/wyn_050_admin_dashboard_test.sh` with a new check (CHECK4) reproducing this exact scenario (auth user with no `profiles` row) — confirmed **red→green**: reverted the `coalesce` fix locally, re-ran the script, watched CHECK4 fail with the RPC succeeding instead of raising; restored the fix, re-ran, all checks pass. Full suite (21 scripts including this one) re-run afterward with no cross-task regression.

Regression Risk: none for existing callers — every real account already has a `profiles` row (the signup flow inserts one), so `coalesce(role, '')` only changes behavior for the specific edge case this bug describes; `admin`/`moderator`/`user` values are untouched by the `coalesce`.

Handoff to QA: re-verify — see the Independent QA section of `.wyn/tasks/approved/WYN-050-admin-dashboard.md` for the full re-verification record.
