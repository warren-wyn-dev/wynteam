# Bug Report — SCHEMA-DROP-001 (ambiguous `profiles` embed breaks Home/Drop/Pop/Club feeds)

Status: closed (found + fixed + verified against real Supabase project 2026-08-16, PASS)
Owner: found and fixed by Claude while helping Founder verify the guest sign-in path against the real Supabase project (`akawuzukstmbztyajxsr`) for the first time
Found by: running the actual compiled app (`flutter build web`) against the real, live Supabase project — the first time any query in this codebase has executed against real data with real foreign keys. Every prior review of these queries (Coding, QA, every widget test) only ever exercised `Recording*Repository` fakes, which override the query methods entirely and never send a real PostgREST request — this bug class is invisible to that. Same root pattern as SCHEMA-001 (2026-08-15): "semantically correct when read" and "actually executes against a real database" are different dimensions of correctness, and this project only just gained the ability to check the second one.

Bug: Every query that embeds `author:profiles(...)` **alongside a sibling embed that also has its own foreign key to `profiles`** (a `*_likes(count)` or `*_comments(count)` aggregate in the same `select()`) fails with PostgREST error `PGRST201`, HTTP status 300:

```json
{
  "code": "PGRST201",
  "message": "Could not embed because more than one relationship was found for 'drops' and 'profiles'",
  "hint": "Try changing 'profiles' to one of the following: 'profiles!drops_author_id_fkey', 'profiles!drop_likes'."
}
```

This broke, against the real database:
- `DropRepository.fetchFeed`/`searchByCaption`/`fetchByAuthor`/`fetchById` (Drop grid, Home feed's Drop half, Drop search, opening a Drop from a notification)
- `DropRepository.fetchComments` (Drop comments sheet)
- `PopRepository`'s equivalent 4+1 methods (Pop feed, Home feed's Pop half, Pop search, Pop comments)
- `ClubPostRepository.fetchPosts`/`fetchFromJoinedClubs` (Club post feed, Home's "จาก Club ของคุณ" toggle)

In effect: **the Home feed and Drop grid — the two most central screens in the app — could never have loaded a single real row once real data existed**, despite 280/280 local tests passing and every prior QA round (WYN-005 through WYN-015, DS-001, DS-002) reporting PASS. `ZokyRepository`'s equivalent `author:profiles(...)` usage for reviews was checked and is **not** affected (no sibling embed shares a path to `profiles` in those queries) — confirmed by testing live rather than assuming symmetry with Drop/Pop/Club.

Reproduction:
1. Have a real Supabase project with the actual `supabase/schema.sql` applied (any project — the specific bug needs no seed data, since PostgREST rejects the query at the relationship-planning stage before it would even run against rows).
2. `curl` (or the app) any of: `GET /rest/v1/drops?select=*,author:profiles(username),drop_likes(count)`, or the `pops`/`club_posts` equivalents.
3. Observe HTTP 300 with the `PGRST201` body above, instead of the expected 200 + row data.

Root Cause: `DropRepository`/`PopRepository`/`ClubPostRepository` each declared a shared `_authorSelect` constant as a **bare, unqualified** `'author:profiles(username, display_name, avatar_url)'`, reused both for the main entity (`drops`/`pops`/`club_posts`, whose `author_id` column is the *intended* path to `profiles`) and for comments (`drop_comments`/`pop_comments`/`club_post_comments`, same pattern). Whenever that bare embed appeared in the same `select()` string as a `*_likes(count)`/`*_comments(count)` embed, PostgREST's relationship-resolution planner found **two** valid graph paths to `profiles` from the query's root table:
1. The intended one: `drops.author_id -> profiles.id` (a real, direct many-to-one FK)
2. An unintended one: `drops -> drop_likes -> profiles` (PostgREST treats `drop_likes`, which has FKs to both `drops` and `profiles`, as a viable many-to-many join table between them, purely because it's *also* present as a sibling embed in the same request — even though the request never asked to join `drop_likes` to `profiles` at all, just to count `drop_likes` rows)

With two candidate paths and no explicit disambiguation, PostgREST refuses to guess and returns `PGRST201` rather than silently picking one. This is a well-documented PostgREST behavior (resource embedding disambiguation), not a Supabase bug — the fix is entirely on the query-string side.

Fix: Qualify every `author:profiles(...)` embed with the exact foreign key constraint name (`profiles!<table>_author_id_fkey(...)`), exactly as PostgREST's own error `hint` field suggests. Verified the real constraint names directly against the live database (not assumed from Postgres's default naming convention, even though they turned out to match it exactly) for all 6 affected tables:

| Table | FK constraint |
|---|---|
| `drops` | `drops_author_id_fkey` |
| `drop_comments` | `drop_comments_author_id_fkey` |
| `pops` | `pops_author_id_fkey` |
| `pop_comments` | `pop_comments_author_id_fkey` |
| `club_posts` | `club_posts_author_id_fkey` |
| `club_post_comments` | `club_post_comments_author_id_fkey` |

Since the main-entity and comment-entity queries need *different* FK names, each repository's single `_authorSelect` constant was split into two: `_dropAuthorSelect`/`_commentAuthorSelect` (`drop_repository.dart`), `_popAuthorSelect`/`_commentAuthorSelect` (`pop_repository.dart`), `_postAuthorSelect`/`_commentAuthorSelect` (`club_post_repository.dart`). `club_post_comments`' bare-embed call sites (no sibling `*_likes` embed exists for it, so they weren't actually ambiguous yet) were qualified anyway for consistency and to stay safe if a `club_post_comment_likes` table is ever added later. `ZokyRepository`'s review-author embed was left untouched after confirming live it isn't ambiguous.

Files Changed:
- `app/lib/features/drop/data/drop_repository.dart` — 6 call sites repointed to `_dropAuthorSelect`/`_commentAuthorSelect`
- `app/lib/features/pop/data/pop_repository.dart` — 6 call sites repointed to `_popAuthorSelect`/`_commentAuthorSelect`
- `app/lib/features/club/data/club_post_repository.dart` — 5 call sites repointed to `_postAuthorSelect`/`_commentAuthorSelect`

No `supabase/schema.sql` change was needed or made — this is a pure client-side query-string fix; the schema's foreign keys were already correct.

Tests:
- `flutter analyze`: clean, 0 issues.
- `flutter test`: 281/281 pass, identical count to before this fix — expected, since every existing test uses `Recording*Repository` fakes that override these methods entirely and never construct or send the real query string, so this bug class (and this fix) is invisible to the existing suite by construction. This is itself a gap worth flagging (see Regression Risk).
- **Live verification against the real Supabase project** (`akawuzukstmbztyajxsr`), the authoritative test for this bug class:
  - Before fix: `curl` reproduction of all 3 previously-broken query shapes (`drops`+`drop_likes`, `pop_comments`+`pop_comment_likes`, `club_posts`+`club_post_likes`) returned `PGRST201`/300, matching the bug exactly.
  - After fix: the same 6 query shapes (main entity + comments, for Drop/Pop/Club) all return clean HTTP 200 against the live database.
  - End-to-end: ran the actual compiled `app/` (via `flutter build web` against the real project) through a full real user journey — guest (anonymous) sign-in -> username setup -> real `profiles` row created (HTTP 201) -> **Home screen renders successfully** or the real empty-state message ("ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!") instead of the app breaking on load, which is what would have happened pre-fix the instant any real Drop/Pop/Club post existed in the database.

Regression Risk: Low for the fix itself (query-string-only change, same columns/joins/counts requested, just disambiguated — not a behavior change once resolved). **However, flagging a real gap this bug exposed**: this entire bug class was invisible to 280+ passing local tests because `Recording*Repository` fakes bypass real PostgREST query construction entirely. Recommend (see `.wyn/learning/IMPROVEMENTS.md`) that once a persistent Supabase project is reachable in future sessions, embedded-select query strings get at least a one-time live smoke test the same way `SCHEMA-001`'s `check_schema_ordering.py` became a standing regression check for a different "only real execution catches this" bug class.

Handoff to QA: Recommend independent re-verification once Google/Apple OAuth or Phone OTP is wired up for a non-anonymous account, confirming Home feed/Drop grid/Pop feed/Club post feed all render real content (not just empty states) once seed data exists — this session's verification used a freshly-created, empty database, so the empty-state path is proven but a populated-feed render (with the corrected `author:profiles!...` embeds actually returning joined profile data) should be spot-checked once there's real content to render.
