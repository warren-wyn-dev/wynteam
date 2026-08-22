# Bug Report — WYN-027

Status: bugs (NEW — found by AI QA & Security, independent round 1, 2026-08-22)
Owner: AI Debug Engineer

Bug: `public.is_blocked_either_way(a uuid, b uuid)` — the SECURITY DEFINER
helper function WYN-027 added so every content-visibility/interaction RLS
policy (`drops`, `pops`, `drop_comments`, `pop_comments`, `club_posts`,
`club_post_comments`, `drop_likes`, `drop_comment_likes`, `pop_likes`,
`pop_comment_likes`, `club_post_likes`, `follows`, `drop_mentions`,
`club_post_mentions`) can check "is there a block between these two
people, in either direction" without needing a broader `select` policy
on `blocks` itself — is **directly callable by any authenticated client
for any two arbitrary user IDs**, exactly the leak its own code comment
says it exists to avoid:

> "security definer so it can run from inside those policies without
> needing a broader select policy on blocks itself **that would
> otherwise leak who-blocked-whom to the blocked party**"

The function achieves that goal for the `blocks` *table* (its own
`select` policy correctly stays `auth.uid() = blocker_id`, blocker-only)
but does **not** achieve it for itself: like every other function in
this schema, it was created without any `revoke execute`, so PostgreSQL's
default ACL (`EXECUTE` granted to `PUBLIC` on function creation) applies.
Supabase/PostgREST auto-exposes every `public`-schema function with
`EXECUTE` as an RPC endpoint (`POST /rest/v1/rpc/is_blocked_either_way`)
gated purely by that ACL — there is no separate opt-in required. Four
other new WYN-027 RPCs (`block_user`, `unblock_user`,
`block_relationship`) got an explicit `grant execute ... to
authenticated` (correct, intended client entry points); this one and its
four sibling author-lookup helpers (`drop_author_id`, `pop_author_id`,
`drop_comment_author_id`, `pop_comment_author_id`) did not — the missing
grant statement was clearly meant to signal "internal only," but omitting
an explicit grant does not achieve that in Postgres, since the implicit
default grant to `PUBLIC` already covers it.

Critically, unlike `block_relationship(p_other_user_id uuid)` (which is
correctly safe to expose — it always resolves the *caller's own*
relationship via `auth.uid()` internally, never a client-supplied "who am
I"), `is_blocked_either_way` takes **both** parties as free parameters,
so any authenticated caller can ask about any pair, not just relationships
involving themselves.

**Practical impact**: `profiles` has always had `using (true)` on `select`
(any authenticated user can read any profile, needed for the
username-availability check since WYN-002) — so user IDs are trivially
enumerable. Combined with this gap, any authenticated WYN user can learn
whether *any two other users* have blocked each other, entirely bypassing
the `blocks` table's own privacy-preserving RLS. For a Trust & Safety
feature whose whole purpose is protecting users who blocked someone
(often after harassment) from that relationship being discoverable, this
is a meaningful privacy leak — e.g. it would let a harasser check whether
a specific victim has also blocked other people they know, without the
victim ever being told or asked.

Reproduction (verified against a fresh local PostgreSQL 16, `supabase/schema.sql`
loaded clean with `ON_ERROR_STOP=1`, queries run as role `authenticated`
with `request.jwt.claim.sub` set — not as the `postgres` superuser, which
would bypass RLS and hide this):

1. Seed users Alice, Dave (unrelated to each other except the block below), Eve (a total stranger to both — never interacts with either).
2. As Alice: `select public.block_user('<dave_id>')` — Alice blocks Dave.
3. As Eve (uninvolved third party):
   - `select count(*) from public.blocks` → **0 rows** (correct — Eve cannot browse the table directly, RLS is doing its job here).
   - `select public.is_blocked_either_way('<alice_id>', '<dave_id>')` → **`true`** — Eve, who has nothing to do with either user, learns Alice and Dave have blocked each other, entirely bypassing the RLS that just correctly denied her the direct table read one line above.

```sql
-- as Eve (request.jwt.claim.sub = eve, role authenticated):
select count(*) from public.blocks;                                    -- 0 (correctly denied)
select public.is_blocked_either_way(alice_id, dave_id);                -- true (LEAKED)
```

Root Cause: PostgreSQL grants `EXECUTE` on a newly created function to
`PUBLIC` by default. Every other SECURITY DEFINER function in this schema
that's meant to be an intentional client RPC has an explicit `grant
execute on function ... to authenticated;` right after its definition
(see `submit_report`, `block_user`, `unblock_user`, `block_relationship`
in this same file, and `club_role`'s callers in the WYN-014 section).
`is_blocked_either_way` (and its four sibling author-lookup helpers) were
written to be *internal-only*, callable from inside other policy/RPC
definitions — but nothing in Postgres treats "no explicit grant
statement" as "revoke from PUBLIC." The omission silently leaves the
default PUBLIC-execute ACL in place, so the function is just as
client-callable as the four that were deliberately exposed.

Fix: Simple `revoke execute ... from authenticated, anon, public;` does
**not** work here — verified empirically: revoking breaks the very RLS
policies this function exists to serve, because a policy's `using`/`with
check` clause is evaluated under the *querying role's* privileges (e.g.
`authenticated`), not the defining role's, so `authenticated` must retain
`EXECUTE` for `select * from public.drops` etc. to keep working at all.

The correct fix is to make the function unreachable via PostgREST's HTTP
RPC surface while keeping it callable from SQL contexts like RLS
policies — the standard Supabase pattern is to move genuinely
internal-only helpers out of the `public` schema (which PostgREST
auto-exposes) into a schema PostgREST is never configured to expose
(commonly `internal` or `private`; check `supabase/config.toml` /
project API settings for the actual exposed-schemas list — this repo's
current schema.sql has never needed one before, so it likely doesn't
exist yet and will need creating). Concretely:

1. `create schema if not exists internal;` (or whatever name matches project convention — check for one first).
2. Move `is_blocked_either_way` (and, out of caution, `drop_author_id`/`pop_author_id`/`drop_comment_author_id`/`pop_comment_author_id` — same exposure class, lower sensitivity since "who authored visible content" isn't really secret, but no reason to leave them reachable either) to `internal.*`.
3. Update every RLS policy/RPC that references `public.is_blocked_either_way(...)` / `public.drop_author_id(...)` / etc. (11+ call sites across `drops`/`pops`/`*_comments`/`*_likes`/`follows`/`*_mentions` policies) to the new schema-qualified name.
4. Keep (or add) `grant execute on function internal.is_blocked_either_way(uuid, uuid) to authenticated;` — this is safe specifically *because* PostgREST cannot route to a non-exposed schema regardless of the underlying GRANT, verified empirically that revoking EXECUTE breaks the policies, so the grant must stay; the fix is schema placement, not the ACL.
5. Re-verify (this QA session confirmed, don't re-derive from scratch, but do re-run): the RLS-embedded call still works for a normal `authenticated` query against `drops`/etc., AND a direct `select internal.is_blocked_either_way(...)` (or the PostgREST RPC equivalent, if a live Supabase project is available to test against by the time this is fixed) is rejected for a client that has no reason to be in that schema.

If `internal`/`private` schema conventions turn out to already be planned
elsewhere in the roadmap (e.g. WYN Admin's Phase 7 backend), coordinate
naming with that rather than inventing a second one.

Files Changed (expected): `supabase/schema.sql` only — this is a pure
RLS/RPC-surface fix, no Dart change anticipated (the Dart app never calls
`is_blocked_either_way`/the four author-lookup helpers directly; it only
ever calls `block_relationship`/`block_user`/`unblock_user`, all of which
stay in `public` with their existing grants, unchanged).

Tests: Verify against a real local Postgres 16 (stub `auth`/`storage`
schema + `authenticated`/`anon` roles + grants, load `schema.sql` with
`ON_ERROR_STOP=1`) that after the fix:
1. The exact reproduction above — Eve calling the moved function for Alice/Dave's pair — is now rejected (`permission denied for schema internal` or equivalent), while Eve calling `block_relationship()` for her own relationships still works normally (unchanged, still in `public`, still `auth.uid()`-scoped).
2. Every WYN-027 Acceptance Criterion this QA round already verified independently (see the "Independent QA — Round 1" section added to `.wyn/tasks/review/WYN-027-block-system.md`) still holds — content visibility both directions, interaction restrictions on all 8 like/comment tables, Follow/mention gating both directions, unblock regression, self-block, nonexistent target, raw insert/delete bypass on `blocks`, spoofed unblock, mutual block, idempotent re-block, `blocks` table privacy. All of these depend on the RLS policies that call the now-moved function, so a schema-qualification typo anywhere would show up immediately as a regression here.
3. `flutter analyze`/`flutter test` — no Dart change expected, but re-run per standing practice.
4. WYN-028 (Mute)'s own SQL suite (its `home_feed` view filter doesn't call `is_blocked_either_way` at all, so it should be unaffected, but confirm — this task's fix touches the same file).

Regression Risk: Low-to-moderate. The SQL is mechanical (schema-qualify
5 function names at their `create function` site and update ~11 call
sites), but there are enough call sites across enough tables that a
missed one would silently reintroduce either the leak (if a call site is
left in `public`) or a functional break (if a call site's
schema-qualification is wrong and the policy itself starts raising
"function does not exist"). Grep for every occurrence of
`is_blocked_either_way(`, `drop_author_id(`, `pop_author_id(`,
`drop_comment_author_id(`, `pop_comment_author_id(` in `schema.sql`
before considering this done — do not rely on memory of "the 11 places
listed above," verify by search.

Handoff to QA: Once fixed, send back to AI QA & Security for round 2 —
must re-verify directly against real Postgres (not just read the diff)
that (a) the leak reproduction above is now blocked, (b) every one of
the 87 independent checks from round 1 (see
`.wyn/tasks/review/WYN-027-block-system.md`, "Independent QA — Round 1")
still passes with the functions in their new schema, and (c) do the same
red→green proof style this project's WORKFLOW.md expects: confirm the
leak reproduces on the *pre-fix* code (this report already did that) and
is gone on the *post-fix* code, not just read the fix and assume.
