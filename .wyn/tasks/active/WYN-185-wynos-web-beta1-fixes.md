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

## Batch 3 — Trending Top 100 button

Root cause: `<button className="top100-link" type="button">ดูอันดับทั้งหมด (Top 100)</button>`
in `search-route.tsx` had no `onClick` at all — a genuinely dead button, not a routing bug.

Reused the existing `fetchTrendingHashtags(client, limit)` (already RPC-backed via
`trending_hashtag_candidates`, already takes a `limit` param) instead of building new
backend ranking infra — the Founder's own wording ("ข้อมูลแนวโน้มที่มีอยู่", trend data that
already exists) scopes this to surfacing the existing computation at a bigger limit (100),
not inventing a new one.

Files Changed:
- `web/components/trending-route.tsx` (new) + `web/app/trending/page.tsx` (new) — real
  page (not a modal — the Founder's own URL-shareable/refreshable requirement pointed at a
  route), distinct loading/error/empty states (error keeps a retry button, doesn't fall
  back to the empty-state wording), `disabled={loading}` on retry to block a double-tap
  mid-fetch.
- `web/components/search-route.tsx` — the button is now `<Link href="/trending">` (Next
  client-side nav + prefetch, no full reload).
- `web/app/parity-completion.css` — added `text-decoration: none` to `.top100-link` (was
  button-only CSS; needed now that the element renders as an `<a>`).
- `web/components/dev/trending-fixture.tsx` + `web/app/dev/trending-fixture/page.tsx`
  (new, no-backend fixture, `?state=loading|error|empty|list`) + `web/tests/browser/trending-top100.spec.ts`
  (new, 6 checks: list content, loading/error/empty distinctness, retry gated to the error
  state only, single `<main>`).

Tests: `npm run check` PASS. Playwright spec 6/6 PASS (chromium-desktop, same local
executablePath workaround as Batch 1, reverted after).

Known Issues: `trending_hashtag_candidates` windows at 48h/100 candidate posts, so the
"Top 100" list is realistically a shorter "however many hashtags survive from the last
100 trending posts" list, not a guaranteed exactly-100 — flagging since the Founder's
literal wording is "100 รายการ": widening the backend to a true always-100 chart (e.g. a
dedicated `hashtag_scores` table refreshed like `top100_scores` already is for drops)
is a bigger backend change than this item's button-is-dead root cause called for; said
so here rather than silently deciding either way.

## Batch 4 — Draft system (explicit save + autosave)

Found the draft *system* itself already substantially built: `drop_drafts` table,
`lib/drafts.ts` (`fetchDrafts`/`fetchDraft`/`saveDraft`/`deleteDraft`, DB-backed so
already cross-device, not localStorage), a working `/drafts` list page with
updated-at + preview text + delete-with-confirm (`drafts-route.tsx`), reopen-to-edit via
`/?compose=1&draft=<id>`, and a close-confirmation dialog in the composer
(`beta4-composer.tsx`'s `requestClose`/`closePrompt`) that already asks "บันทึกเป็นร่างก่อน
ออกไหม?" with ทิ้ง/ยกเลิก/บันทึกร่าง when there's unsaved content — so "cancel silently
discards" wasn't actually reproducible in the current code path.

What was actually missing, matching the Founder's own wording: (1) no *explicit,
always-visible* "บันทึกร่าง" action while composing — the only save path was buried inside
the close-confirmation dialog, which is exactly "ไม่มีวิธีบันทึกร่างที่ชัดเจน" (no clear way);
(2) no autosave at all.

Files Changed:
- `web/components/beta4-composer.tsx`:
  - Factored the existing save-draft call into `persistDraft()`, shared by three
    callers instead of one.
  - Added an always-visible "บันทึกร่าง" quick-action button (disabled when there's
    nothing to save or a save/publish is already in flight).
  - Added autosave: an 800ms debounce on caption/poll-options/image/mode changes,
    skipped on the very first render and right after an existing draft finishes
    loading into the form (so opening a saved draft doesn't immediately re-save it
    unchanged), and skipped while `busy` or with no content.
  - Fixed a race the autosave introduces: publishing clears any pending autosave
    timer before deleting the draft row, so a debounce that was already scheduled
    can't fire after publish and silently re-create the just-deleted draft with
    stale content.
  - Added inline success/error/"saving" text feedback for both the manual button and
    autosave (`autosaveStatus`), per the Founder's system-wide "every action needs
    success/error feedback" requirement (item 13).
- `web/app/system-parity-final.css` — `.beta4-draft-status` (+ `.error` variant).

Tests: `npm run check` (lint+typecheck+build) PASS.

Known Issues: No Playwright coverage added for this one — `saveDraft()` uploads to
Supabase Storage and writes to `drop_drafts`, and the composer only mounts behind
`DeveloperRouteGate` (a real session), so exercising it end-to-end needs either a live
Supabase backend or a meaningfully larger network-mock harness than this session's other
`/dev/*-fixture` specs use. Verified by tracing every code path by hand instead
(debounce scheduling/cleanup, the publish-vs-autosave race, the skip-on-load flag) and
`npm run check`. Flagging this gap explicitly rather than claiming test coverage that
isn't there.
