# Coding Task — WYN-185

Status: active
Owner: AI Coding
Feature: WYNOS Web Beta1 — 13-item bug/UX fix bundle (Founder-issued directly, full requirements below stand in for PRD/acceptance criteria)
Branch: claude/wynos-web-beta1-fixes-r3c06k

## Scope (Founder request, 2026-09-21)

Founder gave a full ordered list of 13 items to fix in `web/` (Next.js consumer web),
in this order, each gated on lint+typecheck+build (and tests where added) before the
next starts:

1. Post Detail + Comment composer keyboard behavior (iOS Safari/PWA, visualViewport, safe-area, 44x44 hit areas)
2. Public Club data + Supabase RLS (0 members/no posts before joining is a real bug, not a display bug)
3. Trending Top 100 button (currently does nothing)
4. Draft system (no explicit save, cancel doesn't draft)
5. Share (navigator.share with clipboard fallback + toast)
6. Perceived speed/navigation (client-side nav, prefetch, skeletons, dedupe)
7. Search (URL-stateful, tabs, debounce, distinct states)
8. Activity (Views/Likes/Comments/Reposts/Saves, unique-view counting, ghost-user display bug)
9. Follow (loading/success wording, optimistic count + rollback)
10. Direct Message Request (compose-first, not request-on-tap)
11. Profile external link (add, validate, normalize, RLS)
12. MAX_POST_IMAGES=9 single source of truth (client currently shows "1 of 10")
13. UX/UI + accessibility consistency pass (terminology, single `<main>`, 44x44 icon hit areas, aria attributes, transitions)

Hard constraints from Founder: build on current state (no reverting), no feature removal,
no test-skipping/CI-gaming, keep the white/black mobile-web design (~390x844), fix root
causes with regression coverage, `git status` checked before starting, report any
requirement that conflicts with the current architecture instead of silently dropping it.

No live Supabase project/credentials in this sandbox (same wall every prior session in
this repo has hit — see WYN-141 log) and no real iOS Safari/device. Verification here is
`npm run check` (lint+typecheck+build) plus Playwright specs against no-backend
`/dev/*-fixture` routes (established pattern: `home-fixture`, `wyn-175-skeleton-fixture`).
Anything that needs a live backend or a real device is flagged explicitly per batch rather
than claimed as tested.

Supabase schema note: `supabase/schema.sql` is a baseline snapshot, not kept in sync with
every shipped migration (confirmed: WYN-161's `conversation_wynii` table isn't in it) — new
SQL for this task goes into its own `supabase/migrations_wyn1NN_*.sql` file per the
established pattern, annotated "Founder runs it via Supabase Dashboard SQL editor; no AI
applies production SQL" (per AGENTS.md Change Control — no AI-initiated production DB
changes).

## Batches

Logged below as each item completes.

## Batch 1 — Post Detail comment composer keyboard behavior

Root cause: `interactiveWidget:"resizes-content"` (already set in `app/layout.tsx` by an
earlier session) covers iOS 16.4+ Safari, but not every runtime (older iOS, some in-app
webviews/standalone-PWA cases) — there the layout viewport doesn't shrink for the keyboard
and the fixed-position composer stays pinned to the bottom of a viewport the keyboard is
now covering.

Also found while tracing which CSS rule actually wins: `.detail-composer-shell` /
`.flutter-detail-composer*` are declared in both `app/post-detail-parity.css` (older) and
`app/system-parity-final.css` (imported later in `app/layout.tsx`, so it wins the cascade
entirely for these selectors — same "later import shadows earlier one" class of bug as
WYN-175). Fixing the shadowed copy would have been a no-op in the real app; edited the
copy in `system-parity-final.css` instead. The 44x44 hit-area requirement was already met
there (48x48 send button, 46px input) — no separate touch-target fix needed.

Files Changed:
- `web/lib/use-keyboard-inset.ts` (new) — reads `window.visualViewport`, publishes
  `--wyn-kb-inset` + `[data-keyboard-open]` on `<html>`.
- `web/components/post-detail-route.tsx` — calls the new hook.
- `web/app/system-parity-final.css` — `.detail-composer-shell` transform tracks
  `--wyn-kb-inset`; drops the safe-area padding while `[data-keyboard-open]` (keyboard
  replaces the home-indicator safe area, so keeping both double-pads the gap).
- `web/components/dev/post-detail-keyboard-fixture.tsx` + `web/app/dev/post-detail-keyboard-fixture/page.tsx`
  (new, no-backend fixture, same pattern as `home-fixture`).
- `web/tests/browser/post-detail-keyboard.spec.ts` (new).

Tests: `npm run check` (lint+typecheck+build) PASS. Playwright spec (4 tests: 44x44 hit
areas, flush-bottom resting position, keyboard-inset tracking, single-scroll-container)
PASS against `chromium-desktop` locally (had to point `launchOptions.executablePath` at
the sandbox's pre-installed Chromium temporarily to work around a Playwright browser-version
mismatch — reverted before committing, not a real config change).

Known Issues: Real iOS Safari/PWA keyboard behavior still needs an actual-device check —
this sandbox has no iOS device and no WebKit browser binary (only Chromium is
pre-installed). The Playwright spec verifies the CSS contract the hook drives, not real
`visualViewport` keyboard events (Chromium desktop/headless can't simulate an OS keyboard).

Commit: `4937647`.

## Batch 2 — Public Club data + Supabase RLS

Root cause (confirmed at the DB layer, not just in the client): `club_posts` and the
`club-media` storage bucket were built members-only-visible by design (see the comment
above the `club-media` bucket insert in `schema.sql`), and the web client computed
`member_count` with a raw `count` query against `club_members` — whose SELECT policies
only let an approved member (or the club's own owner/admin, for pending rows) see any
rows at all, for *any* club regardless of `privacy`. For a Public club a non-member's
count query returns 0 rows (not an error — RLS just filters everything out), and the
posts query returns empty the same way. Both self-correct the moment the viewer becomes
an approved member, which is exactly the "0 สมาชิก + no posts before joining, 4 members
+ posts right after" symptom.

Fix widens READ access only, and only for `privacy = 'public'` clubs — posting and Club
Chat stay members-only, private clubs are unaffected (every new policy/function checks
`privacy = 'public'` explicitly or reuses `club_role()`, which still returns null for a
non-member regardless of privacy). Member *count* is exposed through a new
security-definer RPC rather than loosening the `club_members` table's own RLS, so a
non-member gets the number, never the roster (`club_member_profiles()` — the roster
RPC — is untouched, still member-only). Verified this doesn't affect `club_post_likes`/
`club_post_comments`/`club_post_polls` — each has its own independent `club_role()`
check inside its SELECT policy (not derived from `club_posts` visibility), so those stay
members-only exactly as before; only the post's own text/images/pinned-state became
visible pre-join.

Files Changed:
- `supabase/migrations_wyn185_public_club_read_access.sql` (new) — additive
  `club_posts`/storage SELECT policies for `privacy = 'public'` clubs, plus
  `club_member_count(uuid)` and the batched `club_member_counts(uuid[])` RPCs.
  **Not applied to any database from here — per AGENTS.md Change Control, the Founder
  runs this via the Supabase Dashboard SQL editor.** Not folded into `schema.sql`
  (confirmed that file is a baseline snapshot, not kept in sync with every shipped
  migration — WYN-161's `conversation_wynii` table isn't in it either).
- `supabase/tests/wyn_185_public_club_read_access_test.sh` (new) — 10 checks against a
  throwaway local Postgres DB (schema.sql + the migration above), same harness as
  `wyn_130_club_members_ghost_accounts_test.sh`.
- `web/lib/phase3-data.ts` — `mapClub()`/`mapClubs()` call the new RPCs instead of a raw
  `club_members` count query.
- `web/components/club-detail-golden.tsx` — `join()` now updates `membership` and
  `club.member_count` optimistically before the network call, and rolls both back to the
  pre-click snapshot if the API call fails (was: no visible change until a full
  `refresh()` completed, with no rollback path on failure at all).

Reviewed but left unchanged (in scope per the Founder's own item 2 wording, which is
posts/count/details, not full engagement data): `club_post_likes`/`club_post_comments`
counts embedded in the posts query still resolve to 0 for a non-member of a Public club,
since those two tables keep their own members-only SELECT policy. The post itself,
its image(s), and pin state are visible; its like/comment counts aren't until joining.
Flagging this explicitly rather than silently leaving it, per the Founder's instruction
to report anything the requirements didn't cover rather than deciding it myself.

Tests:
- `npm run check` (lint+typecheck+build) PASS.
- `bash supabase/tests/wyn_185_public_club_read_access_test.sh` — 10/10 checks PASS
  (had to `service postgresql start` first; this sandbox's local Postgres 16 cluster
  exists but starts stopped).
- Re-ran 3 pre-existing Club regression tests (`wyn_130`, `wyn_115`, `wyn_117`) against
  their own unmodified harness (schema.sql only, no new migration layered in) to confirm
  no collateral change: all still PASS. Traced `wyn_115`'s non-member poll-denial check
  specifically (its fixture club *is* `privacy = 'public'`) against the new migration's
  policies by hand — `club_post_polls`' SELECT policy re-checks `club_role()` itself, so
  it isn't affected by `club_posts` becoming readable.

Known Issues: No live Supabase project in this sandbox, so this is DB-layer-verified
(throwaway local Postgres) and client-code-verified (typecheck/build), not
end-to-end-verified against the real production schema. The Founder (or AI Deploy &
DevOps) should apply the migration to a staging project first and confirm the "WYNOS
Feedback" club shows its real member count and posts pre-join before applying to
production.

Handoff: AI QA & Security for a second look at the RLS scoping (privacy boundary is the
security-sensitive part here) before the Founder applies the migration.
