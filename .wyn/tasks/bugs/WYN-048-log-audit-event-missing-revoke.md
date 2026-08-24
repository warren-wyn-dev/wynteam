# Bug Report — WYN-048

Status: fixed
Owner: AI Debug Engineer (orchestrator, fast-follow)

Bug: Independent QA (2026-08-24) found `internal.log_audit_event()` (`security definer`, added in the WYN-048 section of `supabase/schema.sql`) is directly callable by any `authenticated` client via raw SQL — the Coding Output claimed it was not granted to `authenticated`, but no explicit `revoke execute ... from public` statement was ever added, so PostgreSQL's default PUBLIC-execute grant (assigned automatically at `CREATE FUNCTION` time) plus this schema's existing `grant usage on schema internal to authenticated` (needed by other RLS-embedded helpers) combine to make it directly callable. Since `p_actor_id`/`p_target_id` are fully caller-supplied parameters (not derived from `auth.uid()`), an authenticated user can forge arbitrary `audit_log` rows attributing any of the 5 event types to any other user.

This is the exact same vulnerability class already found and fixed once in this codebase: `internal.notification_enabled()` (WYN-044, round 1 QA finding) needed the identical fix. The precedent (`revoke execute on function internal.notification_enabled(uuid, text) from public;`) exists in the same file but was not applied to this new function.

Reproduction:
```sql
select has_function_privilege('authenticated', 'internal.log_audit_event(uuid,text,uuid,jsonb)', 'EXECUTE');
-- returns t (should be f)

set role authenticated;
set request.jwt.claim.sub = '<attacker-uuid>';
set request.jwt.claim.role = 'authenticated';
select internal.log_audit_event('<victim-uuid>', 'account_deleted', '<victim-uuid>', '{"forged":"true"}'::jsonb);
-- succeeds -- should raise insufficient_privilege
```
QA sanity-checked the test method against `internal.notification_enabled()` (which does have the fix) to confirm the method is sound and the gap is specific to `log_audit_event()`.

Root Cause: `create or replace function internal.log_audit_event(...) ... $$;` in the WYN-048 section of `schema.sql` was not followed by a `revoke execute ... from public` statement, unlike the WYN-044 precedent it should have mirrored. `wyn_048_audit_log_test.sh`'s 28 checks never reference `log_audit_event` by name and never test its direct-call privilege — no equivalent of `wyn_044`'s CHECK20 was written for it, so the gap shipped despite an otherwise thorough test suite.

Fix: Add `revoke execute on function internal.log_audit_event(uuid, text, uuid, jsonb) from public;` immediately after the function definition (mirrors the exact fix already present for `internal.notification_enabled()`). Add a permanent regression check to `wyn_048_audit_log_test.sh` mirroring `wyn_044`'s CHECK20: an `authenticated` direct call to `internal.log_audit_event(...)` must fail with a permission error.

Files Changed: `supabase/schema.sql`, `supabase/tests/wyn_048_audit_log_test.sh`

Tests: New check confirms direct-call rejection; full `supabase/tests/` suite (all 21 scripts) re-run to confirm zero regression from the fix; `check_schema_ordering.py`.

Regression Risk: Minimal — the revoke only affects direct client-SQL access to a helper function no legitimate Flutter code path ever calls directly (only the 5 already-wired `security definer` functions call it, and they run as the function owner, unaffected by a PUBLIC-level revoke).

Handoff to QA: Re-verify `has_function_privilege('authenticated', 'internal.log_audit_event(uuid,text,uuid,jsonb)', 'EXECUTE')` now returns `f`, and that the forgery reproduction above now raises instead of succeeding.
