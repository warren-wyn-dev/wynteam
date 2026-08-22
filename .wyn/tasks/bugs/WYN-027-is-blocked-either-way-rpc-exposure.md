# Bug Report — WYN-027

Status: **closed** (RESOLVED + VERIFIED — แก้แล้ว ผ่าน QA อิสระรอบ 2 — PASS, 2026-08-22)
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (รอบ 2 — PASS, ปิดแล้ว)

## QA Round 2 — Independent Verification (AI QA & Security, 2026-08-22)

ยืนยันอิสระว่า fix ของ AI Debug Engineer (commit `1d2fc70` — ย้าย `is_blocked_either_way`/`drop_author_id`/`pop_author_id`/`drop_comment_author_id`/`pop_comment_author_id` จาก `public` ไป schema ใหม่ `internal`) แก้ปัญหานี้ได้จริง:

1. อ่าน diff จริง + `grep` ยืนยัน 0 จุดเหลือใน `public.*`, ครบ 27 จุดใน `internal.*`
2. รัน `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` ที่ Debug สร้างไว้เอง — 9/9 PASS
3. **สร้าง database ใหม่ + รัน SQL harness 87 เคสของรอบ 1 ซ้ำทั้งหมด** (fixture ของ QA เอง ไม่ reuse ของ Debug) — 87/87 PASS ไม่มี regression
4. **Red→green อิสระคนละสคริปต์กับ Debug**: ยืนยัน `public.is_blocked_either_way(...)` ไม่ resolve อีกต่อไป, RLS-embedded call (`select * from drops` เป็นต้น) ยังทำงานถูกต้อง
5. **ตรวจเพิ่มเกินกว่าที่ Debug ทดสอบ**: พบว่า role `authenticated` ยังมี USAGE+EXECUTE บน `internal.is_blocked_either_way` ตรงๆ ได้ (จำเป็นสำหรับ RLS) — วิเคราะห์แล้วว่า **ไม่ใช่ leak ซ้ำ** เพราะการป้องกันจริงคือ PostgREST ไม่ route ไปยัง schema `internal` เลย (ไม่มีทางที่ end user จริงจะได้ raw Postgres connection เป็น role `authenticated`) ต่างจาก threat model เดิมที่รั่วผ่าน `POST /rest/v1/rpc/...` ที่ client ทุกคนยิงถึงได้ตรงๆ — เสนอ (ไม่ block) ให้เพิ่ม `supabase/config.toml` พร้อม `[api] schemas = ["public"]` ตอนตั้ง infra จริง เพื่อ codify ขอบเขตนี้เป็นโค้ดแทนที่จะพึ่ง dashboard setting เฉยๆ
6. ยืนยัน `anon` role ไม่มี USAGE บน `internal` เลย (permission denied)
7. รัน `wyn_021_club_post_mentions_rls_test.sh` (regression ข้าม task) ซ้ำ — 5/5 PASS
8. `flutter analyze`/`flutter test` อิสระ — clean / 395/395 ตรงกับที่ Debug รายงาน

**Final Status: PASS** — รายละเอียดเต็มอยู่ที่ `.wyn/tasks/approved/WYN-027-block-system.md`'s "Independent QA — Round 2" section

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

---

## Debug Output (AI Debug Engineer)

**Reproduction (own, independent from QA's)**: this sandbox has local
PostgreSQL 16 available (`postgresql-16`, `service postgresql status`
showed it already online). Built the same stub harness described in the
bug report (`auth.users`/`auth.uid()`/`auth.role()`,
`storage.buckets`/`storage.objects`/`storage.foldername()`, roles
`authenticated`/`anon`) matching `wyn_021_club_post_mentions_rls_test.sh`'s
pattern, loaded `supabase/schema.sql` clean (`ON_ERROR_STOP=1`, 0
errors) into a fresh throwaway DB, then reproduced the exact scenario:
seeded Alice/Dave/Eve, had Alice `block_user(dave)`, then as Eve
(`request.jwt.claim.sub` = Eve's id, role `authenticated`):
- `select count(*) from public.blocks` → **0** (correctly denied — RLS
  engaged in this harness).
- `select public.is_blocked_either_way(alice_id, dave_id)` → **`true`
  (1)** — confirmed the leak exactly as the bug report describes,
  independently, before touching any code.

**Root cause confirmed by reading the code, not guessed**: grepped the
whole `schema.sql` for `is_blocked_either_way(`, `drop_author_id(`,
`pop_author_id(`, `drop_comment_author_id(`, `pop_comment_author_id(`
(18 + 3 + 3 + 2 + 2 = 28 occurrences total, matching the bug report's
instruction not to trust memory) and confirmed: all 5 functions were
`create or replace function public.<name>(...) ... security definer`
with **no** `grant`/`revoke` statement anywhere near them, unlike every
sibling intentional-RPC function in the same section
(`block_relationship`, `block_user`, `unblock_user`, each followed
immediately by an explicit `grant execute ... to authenticated;`).
Postgres's default ACL (`EXECUTE` granted to `PUBLIC` on function
creation) was therefore still in effect, and since PostgREST's default
exposed-schema list is `public` only (confirmed no `config.toml` or any
other exposed-schema configuration exists anywhere in this repo — this
project has never needed one before), every one of these 5 functions
was a live, unauthenticated-by-design RPC route.

**Fix approach chosen, and why the "obvious" alternative doesn't
work**: independently re-verified the bug report's claim that a plain
`revoke execute on function public.is_blocked_either_way(uuid, uuid)
from authenticated;` breaks the RLS policies — tried it against the
reproduction DB: `select count(*) from public.drops` as an ordinary
(non-blocked-pair) `authenticated` user then fails with `permission
denied for function is_blocked_either_way`, because the `drops` SELECT
policy's `using` clause calls that function under the *querying role's*
privileges (`authenticated`), not the defining role's — confirming the
report's root-cause reasoning about SQL ACL evaluation, not just
trusting the write-up. Did not retry this dead end further.

Implemented the recommended schema-relocation fix instead. No
`internal`/`private` schema convention existed anywhere else in the
repo (grepped for `create schema`, `internal.`, `private.` across
`supabase/`, `.md`, `.toml` — only hit was the bug report itself and an
unrelated `-- only if the club is private` prose comment), so created a
new `internal` schema, matching the bug report's suggested name with no
naming conflict to coordinate.

**Fix applied** (`supabase/schema.sql`, WYN-027 section):
1. `create schema if not exists internal;` + `grant usage on schema
   internal to authenticated;`, added right before
   `is_blocked_either_way`'s definition, with a comment explaining why
   schema placement (not the GRANT) is the actual protection layer.
2. Moved all 5 functions from `public.*` to `internal.*` at their
   `create or replace function` definitions:
   `is_blocked_either_way(a uuid, b uuid)`, `drop_author_id(p_drop_id
   uuid)`, `pop_author_id(p_pop_id uuid)`,
   `drop_comment_author_id(p_comment_id uuid)`,
   `pop_comment_author_id(p_comment_id uuid)`. Kept `grant execute on
   function internal.<name>(...) to authenticated;` immediately after
   each — required for the RLS policies (which run as `authenticated`)
   to keep calling them; safe here because PostgREST never routes to
   `internal`, regardless of this SQL-level GRANT.
3. Updated **all 17 call sites** of `public.is_blocked_either_way(` and
   all 6 call sites of the 4 author-lookup helpers (2 +
   2 + 1 + 1) to the `internal.`-qualified name — did this with a
   single `sed` pass per function name across the whole file (each name
   is specific enough to have zero risk of an unintended match), then
   verified with `grep -c` that every occurrence count matched exactly
   (original count + 1 for the new `grant` line each), and grepped for
   `internal\.internal\.` to rule out a double-substitution typo — 0
   hits, and 0 remaining `public.is_blocked_either_way(`/etc.
   occurrences anywhere in the file.

**Verified against real Postgres, red→green, both directions, live —
not read from the diff**:
- Reloaded the fixed `schema.sql` into a fresh DB, re-ran the exact
  reproduction: `select public.is_blocked_either_way(...)` as Eve now
  **errors** (`function public.is_blocked_either_way(unknown, unknown)
  does not exist`) — the identifier PostgREST's default `public`-only
  exposed-schema config would have tried to route
  `POST /rest/v1/rpc/is_blocked_either_way` to no longer exists there.
  Confirmed the same for all 4 sibling functions via `pg_proc`/
  `pg_namespace` existence checks (0 in `public`, 1 in `internal`,
  each).
- Confirmed the schema boundary is a real access-control boundary, not
  just relocation: `set role anon; select
  internal.is_blocked_either_way(...)` → **`permission denied for
  schema internal`** (Postgres schema creation does not grant `PUBLIC`
  `USAGE` by default, unlike function `EXECUTE`, so nothing was granted
  to `anon`/`PUBLIC` on `internal` — only `authenticated` has `usage`).
- Confirmed legitimate RLS-embedded calls still work correctly post-fix
  across **every** call site the bug report listed (not just
  `is_blocked_either_way` on `drops`): seeded Dave's content across
  `drops`, `pops`, `drop_comments`, `pop_comments`, `club_posts`,
  `club_post_comments`, with Alice having blocked Dave — Alice got 0
  rows on all 6 SELECT-side tables, Eve (uninvolved) got the expected
  rows. Then exercised every INSERT-side defense-in-depth policy
  (`drop_likes`, `pop_likes`, `drop_comment_likes`,
  `pop_comment_likes`, `club_post_likes`, `follows`, `drop_mentions`,
  `club_post_mentions`): Alice's direct insert attempts against Dave's
  content were all rejected by RLS (`new row violates row-level
  security policy`), Eve's equivalent inserts against the same content
  all succeeded, and Dave mentioning Frank (no block) succeeded while
  Dave mentioning Alice (blocked) was silently rejected — 17/17 checks
  matched expected values (`a == e` for every row), confirming the
  mechanical rename didn't break a single one of the ~23 call sites.
- Did the `git stash`/`git stash pop` red→green proof this project's
  WORKFLOW.md convention expects, using the exact persisted regression
  script (not a throwaway variant): `git stash push -- supabase/schema.sql`
  (reverting to pre-fix) → ran
  `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` →
  **5 of 9 checks FAILED** (`CHECK2`–`CHECK6`, all "expected 0, got 1" —
  the 5 functions still present in `public`), exit code 1. `git stash
  pop` (fix restored) → ran the identical script again → **ALL 9 CHECKS
  PASSED**, exit code 0.
- Re-ran `supabase/tests/wyn_021_club_post_mentions_rls_test.sh`
  (unrelated sibling regression test, touches `club_post_mentions`
  whose `insert` policy also calls the now-relocated
  `is_blocked_either_way`) against the fixed schema — **5/5 PASSED**,
  confirming no cross-task regression.

**Regression test — persisted, re-runnable, following this project's
established pattern**: added
`supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`,
structured identically to `wyn_021_club_post_mentions_rls_test.sh`
(self-contained, stubs `auth`/`storage`, loads `schema.sql` into a
fresh throwaway DB, seeds fixtures, asserts `CHECK*`-prefixed rows
parsed from psql output). Its 9 checks cover: (1) sanity control that
`blocks` table RLS is engaged, (2)–(6) all 5 functions absent from
`public`'s `pg_proc`, (7)–(8) the block-aware `drops` SELECT policy
still filters correctly in both directions, (9) `block_relationship()`
(the intentionally-public, `auth.uid()`-scoped RPC, unaffected by this
fix) still works. Confirmed this exact script fails pre-fix and passes
post-fix (see red→green proof above).

**Files Changed**: `supabase/schema.sql` (5 function definitions moved
`public.*` → `internal.*` with a new `create schema if not exists
internal;` + `grant usage`, plus explicit `grant execute` on each
relocated function, plus all 23 call sites schema-qualified to
`internal.*`) and `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`
(new regression test). No Dart changes — confirmed by the bug report's
own claim (Dart never calls these 5 functions directly, only
`block_relationship`/`block_user`/`unblock_user`, all unchanged) and by
`flutter analyze`/`flutter test` below showing zero diff-relevant
impact.

**`flutter analyze`/`flutter test`**: ran both after the fix (Flutter
3.47.1, already present at `/home/user/flutter`). `flutter analyze`:
clean, no issues. `flutter test`: **395/395 passed**, 0 failures — as
expected for a pure-SQL schema-qualification change with zero Dart-code
impact.

**Regression Risk**: Low, as the bug report anticipated. The 23 call
sites were all mechanically verified via grep count-matching (not
memory) both before and after the fix, and the broader ad hoc
verification above exercised every one of them directly against real
Postgres, not just the `drops`/`is_blocked_either_way` pairing the
original leak reproduction used.

**Lessons learned**: recorded in `.wyn/learning/LESSONS_LEARNED.md` and
`.wyn/learning/MISTAKES.md` — a missing `grant`/`revoke` statement on a
`public`-schema `security definer` function is not "internal by
omission" in Postgres/PostgREST; the default PUBLIC-execute ACL plus
PostgREST's blanket schema auto-exposure means every `public`-schema
function is a live RPC unless it's provably unreachable (either by
schema placement outside the exposed-schema list, or, for genuinely
public-facing helpers, an intentional `grant execute ... to
authenticated` documenting that exposure was deliberate). Any future
`security definer` helper meant to be internal-only must go straight
into `internal` (now that it exists) rather than `public` with no
grant.

**Handoff to QA**: send back to AI QA & Security for round 2 — must
re-verify directly against real Postgres independently (not just trust
this report) that (a) the leak reproduction is now blocked, (b) every
one of the 87 independent checks from round 1 still passes with the
functions in their new schema, and (c) do the same red→green proof
style independently. `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`
is available to re-run directly
(`bash supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh`)
if this sandbox's local Postgres is still available in QA's session.
Task status in `.wyn/tasks/review/WYN-027-block-system.md` is left as
"review" / FAIL for QA to update after their own independent round-2
verification — not updated by this Debug session.
