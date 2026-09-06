# Bug Report — WYN-122 (QA Round 1 finding)

Status: bugs
Owner: AI Debug Engineer

Bug: `internal.chat_pair_allowed(uuid, uuid)` (the new WYN-122 helper that every chat-lockdown RLS policy calls) is missing its `grant execute ... to authenticated` statement — the one thing every other `internal.*` RLS helper function in this codebase has, with zero exceptions (`internal.is_blocked_either_way`, `internal.drop_author_id`, `internal.pop_author_id`, `internal.drop_comment_author_id`, `internal.pop_comment_author_id`, `internal.current_platform_role`, `internal.is_posting_blocked`, `internal.is_drop_deleted`, `internal.mention_allowed`, `internal.comment_allowed` — all 10 have it). Missing in both `supabase/schema.sql` and the hand-mirrored `.github/workflows/wyn122-apply-chat-lockdown-schema.yml` (same statements, copy-pasted, so both are missing it identically).

Reproduction: (verified against a real local PostgreSQL 16 running `schema.sql` as-is, not guessed)

```sql
-- Baseline: works fine under Postgres's own default (EXECUTE granted to
-- PUBLIC on function creation, never revoked project-wide in this file).
set role authenticated;
set request.jwt.claim.sub = '<alice>';
set request.jwt.claim.role = 'authenticated';
select public.get_or_create_conversation('<bob>');  -- succeeds
select * from public.conversations;                  -- succeeds
reset role;

-- Now simulate the exact defensive posture this codebase's own comment
-- at schema.sql:2080-2096 says to assume ("Postgres grants EXECUTE to
-- PUBLIC by default... so omitting a grant/revoke statement does NOT
-- make [it] internal-only" -- the whole reason every sibling helper
-- has an explicit grant is to not depend on that default staying true):
revoke execute on function internal.chat_pair_allowed(uuid, uuid) from public;

set role authenticated;
set request.jwt.claim.sub = '<bob>';
set request.jwt.claim.role = 'authenticated';
select * from public.conversations;
reset role;
-- ERROR:  permission denied for function chat_pair_allowed
```

Root Cause: `conversations` SELECT, `messages` SELECT/INSERT, and `storage.objects` (chat-media) INSERT policies all call `internal.chat_pair_allowed(...)` directly inside their `using`/`with check` clause. RLS policy evaluation runs as the querying role itself (`authenticated`) — unlike a call made from inside a `SECURITY DEFINER` function (`get_or_create_conversation()`/`count_unread_conversations()`/`chat_lockdown_status()`, which all run as the function's *owner* and are therefore unaffected, confirmed separately by testing each one after the same revoke — all 3 kept working). Without an explicit grant, `authenticated`'s ability to call this function inside those 4 RLS policies depends entirely on Postgres's default PUBLIC-execute grant never having been revoked anywhere for this database — an assumption this exact codebase has already been burned by once (see the schema.sql:2080-2096 comment and `.wyn/tasks/bugs/WYN-027-is-blocked-either-way-rpc-exposure.md`, a related but distinct incident: that one was about *client-facing over-exposure* via PostgREST; this one is the mirror-image failure mode -- *under*-exposure to the `authenticated` role RLS itself needs, if the default this relies on is ever tightened).

Practical impact if this ships as-is: if the real Supabase production project has ever had (or later gets) a project-wide `REVOKE EXECUTE ... FROM PUBLIC` default-privilege hardening applied, or if any other future migration does this defensively, chat breaks **completely for every single user, including @warren and @wynos_online** — not a graceful lockdown, a hard `permission denied` on every conversation load/send. This is precisely why 100% of this function's siblings never rely on that default.

Fix: add one statement in both places (`supabase/schema.sql`'s WYN-122 section and `.github/workflows/wyn122-apply-chat-lockdown-schema.yml`'s step 2), immediately after the function definition, matching the codebase's own 100%-consistent convention exactly:

```sql
grant execute on function internal.chat_pair_allowed(uuid, uuid) to authenticated;
```

Files Changed (expected):
- `supabase/schema.sql`
- `.github/workflows/wyn122-apply-chat-lockdown-schema.yml`

Tests: after the fix, re-run the exact repro above (revoke, then confirm it now fails without the grant reinstated, then confirm granting fixes it) as a permanent regression check -- ideally folded into `supabase/tests/wyn_122_chat_lockdown_test.sh` as a new CHECK so this can never silently regress again (e.g. someone rewriting the function later and forgetting the grant a second time). Also re-run the full existing `wyn_122_chat_lockdown_test.sh` suite (15 checks) plus `wyn_031/032/033` to confirm zero regressions from adding the grant.

Regression Risk: none from the fix itself -- adding an EXECUTE grant is strictly additive/permissive in the correct direction, mirrors an established pattern used 10 other times in this exact file already, and cannot make anything *more* restrictive than it already behaves under the current (unrevoked-default) production state.

Handoff to QA: after Debug applies the fix, re-run this exact repro (revoke → confirm still-broken without grant is now a stale statement; confirm the grant is present in both files; confirm the full `wyn_122_chat_lockdown_test.sh` suite still passes 15/15) before re-approving.
