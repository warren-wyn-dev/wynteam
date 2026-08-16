# Bug Report — SCHEMA-001

Status: closed (แก้แล้ว ผ่าน QA — PASS, ยืนยันด้วยการรัน `schema.sql` จริงบน Postgres สด ไม่ใช่แค่อ่าน SQL)
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (PASS)

Bug: `supabase/schema.sql` fails to run end-to-end against a genuinely fresh (empty) Postgres database — the `public.notifications` table's `create table` statement (WYN-012, near the top of the file) declares `club_id uuid references public.clubs (id)` and `club_post_id uuid references public.club_posts (id)` inline in its column list, but `public.clubs`/`public.club_posts` are not created until far later in the file (WYN-014). Running the file top-to-bottom — the only way Supabase's SQL Editor executes a pasted script — aborts at the `notifications` table with:

```
ERROR: 42P01: relation "public.clubs" does not exist
```

Reproduction:
1. Create a brand-new, empty Supabase project (no prior schema).
2. Paste the entire contents of `supabase/schema.sql` into the SQL Editor and run it.
3. Execution aborts partway through with the error above; every statement after the failure point (which is nearly the entire file — hundreds of tables/RLS policies/RPCs from WYN-002 through SELLER-004) never runs, leaving the database in a half-migrated state.

Root Cause: When WYN-015 added Club-related notification types, the `club_id`/`club_post_id` columns were added by editing the *original* `notifications` `create table` statement in place (chronologically positioned at WYN-012, before Club exists at all) instead of appending a separate `alter table public.notifications add column ...` statement positioned after `public.clubs`/`public.club_posts` are created (WYN-014). Confirmed via direct read of `supabase/schema.sql`:
- Line ~604: `club_id uuid references public.clubs (id) on delete cascade,` — inside the `notifications` `create table` block.
- Line ~605: `club_post_id uuid references public.club_posts (id) on delete cascade,` — same block.
- Line 774: `create table if not exists public.clubs (...)` — the referenced table, defined ~170 lines *after* the column that references it.
- Line 822: `club_posts` table (`club_id uuid not null references public.clubs (id) ...`) is defined even later.

This bug existed from the moment WYN-015 merged, but was never caught because every RLS/RPC/schema review this entire session — for every single task, per `.wyn/tasks/approved/*.md`'s QA reports — was done by **reading SQL semantics only**, since no live Supabase project existed to run the file against. This is the first time `schema.sql` has ever been executed against a real, fresh database from the very first statement.

Fix: Remove `club_id`/`club_post_id` from the `notifications` `create table` column list, and add them via `alter table public.notifications add column if not exists club_id uuid references public.clubs (id) on delete cascade;` (and the same for `club_post_id` → `club_posts`), positioned immediately after `public.club_posts` is created (after line ~822, before the `notifications` RLS/trigger code that follows later in the file references these columns). Verify no other statement between the original `notifications` table position and the new `alter table` position depends on `club_id`/`club_post_id` already existing on the table (e.g. an index or check constraint) — if any exists, it must move with the columns.

After fixing, do a full top-to-bottom static read of `schema.sql` (not just this one spot) to check for any *other* forward-reference the same way (a table/column referencing another table that is defined later in the file) — this bug class could exist elsewhere and was never checked for systematically before.

Confirmed by: Founder running the actual SQL Editor against a real, brand-new Supabase project (`akawuzukstmbztyajxsr`, region `ap-southeast-1`) and reporting the exact error text back verbatim, plus independent code read confirming the line-order issue.

---

## Debug Output (AI Debug Engineer)

Root cause verified independently before touching any code (read `supabase/schema.sql` directly, did not trust the bug report's line numbers or conclusion blindly):
- `create table if not exists public.notifications` starts at line 589. `club_id uuid references public.clubs (id) on delete cascade` was at line 604 and `club_post_id uuid references public.club_posts (id) on delete cascade` at line 605, both inside that same `create table` statement's column list.
- `create table if not exists public.clubs` is at line 774 (185 lines *after* the reference). `create table if not exists public.club_posts` is at line 1177 (573 lines after) — not line ~822 as the bug report's approximate reference guessed; line 822 is actually inside `club_members`, a different table. The bug report's core claim (forward reference exists, `notifications` fails first) was correct; only one line-number estimate for `club_posts` was off, which didn't change the diagnosis.
- Confirmed no index or check constraint anywhere in the file was ever attached to `club_id`/`club_post_id` (the two indexes on `notifications`, `notifications_recipient_created_idx`/`notifications_recipient_unread_idx`, are on `recipient_id` only; the only check constraint on the table is on `type`) — nothing else needed to move alongside the columns.

Fix: Removed `club_id`/`club_post_id` from the `notifications` `create table` column list (replaced with an explanatory comment pointing to where they're now declared). Added two `alter table public.notifications add column if not exists ...` statements immediately after `public.clubs`/`public.club_posts`/`public.club_post_likes`/`public.club_post_comments` and their RLS policies/storage bucket policies are fully set up — right before the block of WYN-015 notification trigger functions (`notify_club_join_request`, `notify_club_join_approved`, `notify_club_post_like`, `notify_club_post_comment`) that are the only code in the file which actually reads/writes these two columns. Verified those trigger functions don't need the columns to exist any earlier than that: PL/pgSQL only validates the SQL statements inside a function body lazily, at first *execution* (when a trigger actually fires), not at `create function` time — so the functions could technically have been declared even earlier without breaking `schema.sql`'s own top-to-bottom run, but placing the `alter table` calls right before them keeps the file's declared-before-used ordering intuitive for a future reader, matching the existing convention documented in the comment already above that block ("Must be declared after clubs/club_members/club_posts/... exist").

Systematic check for other forward references (as the bug report's "After fixing" section requested — not just the one spot Founder found): wrote a throwaway Python script (kept permanently at `supabase/check_schema_ordering.py` as a regression test, see below) that parses every `create table if not exists public.X` in the file to build a table-name → definition-line map, then walks every `create table` body and every standalone `alter table public.X ... references public.Y` statement checking that every `references public.Y` it contains points at a `Y` whose own `create table` line number is strictly less than the referencing statement's line. Ran it before the fix: found exactly the 2 issues already known (`notifications` → `clubs` at line 604, `notifications` → `club_posts` at line 605) and nothing else, across all 26 `create table` statements in the file (`profiles`, `drops`, `drop_likes`, `drop_comments`, `drop_comment_likes`, `saves`, `pops`, `pop_likes`, `pop_comments`, `pop_comment_likes`, `follows`, `notifications`, `clubs`, `club_members`, `club_posts`, `club_post_likes`, `club_post_comments`, `categories`, `stores`, `products`, `product_variants`, `platform_config`, `cart_items`, `orders`, `order_items`, `reviews`). Ran it again after the fix: 0 issues. **Result: the `notifications`/`clubs`/`club_posts` case was the only forward reference in the entire file — no other spot needed fixing.**

Files Changed:
- `supabase/schema.sql` — moved `club_id`/`club_post_id` from `notifications`'s `create table` to two `alter table ... add column if not exists` statements positioned after `public.club_posts` (and its RLS/storage setup) is fully created. No table/column/constraint/RLS-policy/RPC logic changed — this is a pure statement-reordering fix; the final schema shape (columns, types, foreign keys, `on delete cascade` behavior, indexes, RLS policies) is byte-for-byte identical to before, just declared in a different order so the file executes top-to-bottom against an empty database.
- `supabase/check_schema_ordering.py` (new) — a standalone, dependency-free Python 3 script (stdlib only, no live DB required) that statically re-runs this same forward-reference check any time `schema.sql` is edited in the future. Exit code 0 + "OK" when clean, exit code 1 + a listing of every offending reference otherwise. This is the regression test for this bug class (see Tests below).

Tests:
- `python3 supabase/check_schema_ordering.py` — FAIL (2 issues) before the fix, PASS (0 issues) after. This is a genuine dynamic regression test: it doesn't just read the fixed spot, it re-derives every table's definition line from the current file contents and re-checks all 26 tables' references from scratch every time it runs, so it will catch this same bug class again automatically if it's ever reintroduced (e.g. a future feature adding a column to an old table that references a table created later in the file).
- `flutter analyze` — clean in both `app/` and `seller_app/` (no issues found in either).
- `flutter test` — `app/`: all tests pass (265 tests). `seller_app/`: all tests pass (67 tests). Both counts are unchanged from before this fix, as expected: this change is pure SQL DDL statement reordering with zero impact on the final table/column structure, so no Dart code (models, repositories, widgets, or their tests) needed to change or could have regressed.

Regression Risk: Very low. The change reorders two `alter table` statements relative to their original inline position but produces an identical final schema (same columns, same types, same foreign keys, same `on delete cascade` semantics, same nullability, same lack of any index/constraint on these two columns). No RLS policy, RPC function, or Dart code references `notifications.club_id`/`club_post_id` any earlier in execution order than before (verified the only 4 places that read/write these columns — the WYN-015 trigger functions — already textually follow the new `alter table` position and, per PL/pgSQL's lazy validation, only need the columns to exist by first-trigger-fire time, long after `schema.sql` finishes running).

Handoff to QA: Send to AI QA & Security for verification that: (1) the reordered `schema.sql` still expresses the exact same final schema as before (diff review — no column/type/constraint/policy semantics changed, only position), (2) the new `supabase/check_schema_ordering.py` regression test correctly catches the original bug when run against a temporarily-reverted copy of the fix, and (3) no other forward-reference exists that this systematic check might have missed due to a limitation in its own logic (e.g. it does not currently parse multi-statement `alter table ... add constraint ... foreign key` syntax if that pattern is ever introduced later — only `references public.X` inline in a column definition, which is the only pattern used anywhere in this file today).

Lessons learned: recorded in `.wyn/learning/LESSONS_LEARNED.md` and `.wyn/learning/MISTAKES.md` — "reading SQL semantics" (RLS/RPC logic correctness) and "linear executability from an empty database" (statement ordering / forward references) are two entirely separate dimensions of schema review; a file where every individual statement is semantically perfect can still fail to run at all if even one earlier table references a later one, because Supabase's SQL Editor (and `psql -f`) executes strictly top-to-bottom with no automatic dependency resolution. Also proposed in `.wyn/learning/IMPROVEMENTS.md` that `supabase/check_schema_ordering.py` become a mandatory step (and eventually a CI check) any time a PR touches `supabase/schema.sql`.

---

## QA Verification (AI QA & Security)

```
Feature: SCHEMA-001 fix — supabase/schema.sql must execute top-to-bottom against a genuinely fresh (empty) Postgres database with zero errors
Environment: Local PostgreSQL 16 (apt package, already installed in this session's sandbox) — first time this session had a live Postgres available, so this is the first SCHEMA-001-related check ever run dynamically instead of by reading SQL only
Test Cases:
  1. Diff review of the fix commit (91c1a44) — confirm the column move is pure reordering, zero semantic change
  2. Run `python3 supabase/check_schema_ordering.py` against the current (fixed) schema.sql
  3. Run the same script against the pre-fix schema.sql (git show 91c1a44~1), to prove the regression test actually catches this bug class and isn't vacuously passing
  4. Static check for the one documented limitation of check_schema_ordering.py (it only parses inline `references public.X` — not multi-statement `alter table ... add constraint ... foreign key`) — grep schema.sql for that pattern to see if it's actually present and unchecked
  5. Build a minimal from-scratch stub of the Supabase-managed pieces schema.sql assumes exist (schema `auth` with `auth.users`/`auth.uid()`/`auth.role()`, schema `storage` with `storage.buckets`/`storage.objects`/`storage.foldername()`, role `authenticated`) on a brand-new empty database, then run the actual current `supabase/schema.sql` through `psql -f` end-to-end — this is the same reproduction Founder used originally (paste-and-run against a fresh project), just self-hosted instead of on supabase.com
  6. Negative control: run the same stub bootstrap + the pre-fix schema.sql through `psql -f` on a second fresh database, to confirm the harness genuinely reproduces the Founder's original error (not just passing by construction)
  7. Inspect the resulting `public.notifications` table on the successful (post-fix) run: columns, FK targets/`on delete cascade`, indexes, check constraints — confirm identical shape to what the bug report and Debug Output claimed (no index/constraint needed to move, nothing else changed)
  8. Sanity totals on the successful run: table/view count, RLS policy count, function count all created with zero errors
Passed: 8/8
Failed: 0
Severity: N/A (verification of an already-applied fix, not a new finding)
Reproduction Steps (test 5/6, the dynamic run):
  1. `service postgresql start` (Postgres 16, apt-installed)
  2. `createdb schema001_test` (genuinely empty database — no prior schema)
  3. Load a minimal stub bootstrap (`auth.users`, `auth.uid()`, `auth.role()`, `storage.buckets`, `storage.objects`, `storage.foldername()`, role `authenticated`) — the platform pieces Supabase itself pre-provisions but plain Postgres doesn't
  4. `psql -d schema001_test -f supabase/schema.sql` (the exact current, committed file — no edits)
  5. Repeat steps 2-4 on a second fresh database using `git show 91c1a44~1:supabase/schema.sql` (the pre-fix version) instead, as a negative control
Expected: Fixed schema.sql runs top-to-bottom with zero `ERROR` lines; pre-fix version reproduces `relation "public.clubs" does not exist` and the cascade of "notifications does not exist" errors that follow (since the table whose creation aborted is referenced by everything after it)
Actual:
  - Fixed schema.sql: `psql -f` completed with **0 ERROR lines**, every `CREATE TABLE`/`CREATE FUNCTION`/`ALTER TABLE`/`CREATE POLICY`/`INSERT` statement in the file succeeded. `public.notifications` in the resulting live database has `club_id uuid`/`club_post_id uuid` with `FOREIGN KEY ... REFERENCES clubs(id)/club_posts(id) ON DELETE CASCADE`, no index or check constraint on either column — byte-for-byte matches the pre-fix column definition, just declared later in the file. 28 tables/views, 77 RLS policies, 64 functions created successfully.
  - Pre-fix schema.sql (negative control, same stub, fresh DB): failed exactly as Founder originally reported — `ERROR: relation "public.clubs" does not exist` at the `notifications` table's `create table` statement, followed by a cascade of `relation "public.notifications" does not exist` errors for every later statement that depends on it (RLS policies, triggers, indexes) — confirms the reproduction harness is valid and the original bug is real, not just plausible-by-reading.
  - `check_schema_ordering.py`: `OK: no forward references found` (exit 0) against current schema.sql; `FAIL: 2 forward reference(s) found` (exit 1), listing exactly the `notifications`→`clubs` and `notifications`→`club_posts` lines, against the pre-fix copy — the regression test genuinely discriminates broken from fixed, not just reporting green unconditionally.
  - `grep -n "foreign key\|add constraint" supabase/schema.sql`: only hits are value-range `check` constraints (`profiles_display_name_length`, `orders_status_check`, `stores_address_length`, etc.) and one comment — no `alter table ... add constraint ... foreign key` statement exists anywhere in the file today, so the script's one documented blind spot is not currently masking anything.
  - Diff of commit 91c1a44 (`git diff 91c1a44~1 91c1a44 -- supabase/schema.sql`): confirms the change is a pure statement move — the removed inline columns and the added `alter table ... add column if not exists` are textually identical in type/`references`/`on delete cascade`, only their position in the file changed, plus explanatory comments. No RLS policy, RPC, index, or check constraint touched.
Security Findings: None. This bug and fix are pure DDL-statement-ordering — no RLS policy logic, authorization boundary, or data-exposure surface changed. Verified the `notifications` table's existing RLS policies (`select`/`update` gated on `auth.uid() = recipient_id`) are untouched by the diff and still present correctly on the live post-fix database.
Recommendation: Approve and close. This is now the most rigorously verified schema change in the project to date — the first time a `schema.sql` review in this repo has been backed by an actual `psql -f` run against a fresh database rather than static SQL reading alone, closing exactly the verification gap the bug's own "Lessons learned" section flagged. Suggest formalizing this as a standing QA step (not just Debug's own static script) any time `supabase/schema.sql` changes, now that a local Postgres is available in this environment — recorded below and in `.wyn/learning/IMPROVEMENTS.md`.
Final Status: PASS
```

Verification environment cleanup: both temporary test databases (`schema001_test`, `schema001_test_prefix`) and stub/scratch SQL files were dropped/deleted after verification — nothing left running or persisted beyond this report.

Lessons learned (added by QA): a live Postgres was available in this sandbox the whole time (`postgresql-16` was already installed) but every prior `schema.sql` review — including this bug's own Debug Output — assumed none was available and fell back to static reading. Worth checking for a runnable local Postgres before defaulting to static-only schema review going forward; recorded in `.wyn/learning/IMPROVEMENTS.md`.
