# Bug Report — WYN-043

Status: fixed (found during WYN-051's Independent QA, fixed as an isolated fast-follow immediately after WYN-051 deployed)
Owner: AI QA & Security (found), fixed inline

Bug: `public.send_system_notification()`'s admin-only guard (`if internal.current_platform_role() <> 'admin' then raise exception ...`) silently does nothing for a caller with **no `profiles` row at all** — the exact same NULL-role-bypass class documented in `.wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md`. `internal.current_platform_role()` returns `NULL` for such a caller; `NULL <> 'admin'` evaluates to `NULL`, and PL/pgSQL's `IF` treats a `NULL` condition the same as `FALSE` — the branch is skipped, the exception never raised, and the function proceeds to send an arbitrary "system" notification (which the recipient sees with no actor attached, i.e. presented as an official WYN announcement) to any target the caller names.

Reproduction: same shape as the WYN-050 finding — seed a caller with an `auth.users` row but no matching `profiles` row, call `send_system_notification()` as that caller under the real `authenticated` role. Confirmed the guard is skipped and the notification is sent.

Root Cause: identical to WYN-050's — `x <> y` (like `x not in (...)`) is three-valued logic; a `NULL` left-hand side makes the whole comparison `NULL`, not `TRUE`. This function predates the WYN-050 fix (it shipped in WYN-043) and was written without the `coalesce()` that pattern needs.

Fix: `coalesce(internal.current_platform_role(), '') <> 'admin'`.

Files Changed: `supabase/schema.sql` (`send_system_notification()`'s guard clause, one line)

Tests: extended `supabase/tests/wyn_043_notification_types_test.sh` with a new check reproducing this exact scenario (auth user with no `profiles` row calling `send_system_notification()`) — confirmed red before the fix (the call succeeded and inserted a notification instead of raising) and green after. Full 22-script suite re-run afterward with no cross-task regression.

Regression Risk: none for existing callers — real accounts already have a `profiles` row; `coalesce(role, '')` only changes behavior for this specific edge case.

Handoff to QA: re-verify — see `.wyn/tasks/approved/WYN-051-admin-user-management.md`'s Independent QA section, which is where this was first found (out of WYN-051's own scope, fixed as a separate follow-up).
