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

## Batch 5 — Share (navigator.share + clipboard fallback + toast)

Found `profile-route.tsx`'s `share()` already had the correct, complete implementation
(navigator.share, clipboard fallback, `showToast("คัดลอกลิงก์แล้ว")` on success, an
AbortError-vs-real-failure distinction since AbortError fires both for a deliberate
cancel and for "no compatible share target" and the API can't tell them apart). The
other 5 share call sites (post detail, club post, club, feed card, home feed) all
duplicated the same navigator.share/clipboard logic *without* the toast — every outcome
was swallowed by an empty `catch {}`, so a clipboard-only device got no confirmation at
all and a real failure (e.g. clipboard permission denied) looked identical to the button
doing nothing.

Files Changed:
- `web/lib/share.ts` (new) — `shareOrCopyLink()`, extracted from profile-route.tsx's
  existing correct implementation, now the one shared helper every call site uses.
- `web/components/profile-route.tsx` — switched to the shared helper (no behavior
  change, just dedup).
- `web/components/post-detail-route.tsx`, `web/components/golden-drop-card.tsx`,
  `web/components/home/home-screen.tsx`, `web/components/club-detail-golden.tsx` (both
  the club-post share and the main club share) — wired to the shared helper +
  `useToast()`/`<Toast>` (added where missing; `home-screen.tsx` already had the
  Toast plumbing for other actions, just wasn't using it for share).
- `web/components/dev/share-fixture.tsx` + `web/app/dev/share-fixture/page.tsx` (new,
  no-backend fixture — sharing a link never touches Supabase, so this one only needed
  `navigator.share`/`navigator.clipboard` stubbed, not a Supabase session) +
  `web/tests/browser/share.spec.ts` (new, 5 checks: clipboard-only success, clipboard
  failure surfaces an error, `navigator.share` success shows no redundant toast,
  AbortError falls back to clipboard, a real `navigator.share` failure surfaces an
  error).

Tests: `npm run check` PASS. Playwright spec 5/5 PASS (chromium-desktop, same local
executablePath workaround as prior batches, reverted after).

## Batch 6 — Performance/Navigation: audit, no code change

Audited item 6's checklist against what's already in the codebase before writing
anything new, per AGENTS.md's "reuse before duplication, don't rewrite what's already
working" principle — found this one substantially already built, not a gap needing a
fix:

- **Client-side nav + prefetch**: no plain `<a href="/...">` internal links found
  (grepped); every internal link is `next/link`. No `prefetch={false}` anywhere. No
  `window.location.reload()`/`window.location.href =` full-reload calls anywhere. The
  two `window.location.assign()` calls that exist are both intentional exceptions with
  their own comments (switching Supabase auth session — needs a real reload to
  reinitialize the client; a same-URL "back" link, where a Next `<Link>` would be a
  no-op).
- **Caching Feed/Profile/Search/Club**: `lib/mount-cache.ts` (module-level `Map`,
  survives `PageTransition`'s unmount/remount on every route change) is already wired
  into `search-route.tsx`, `club-detail-golden.tsx`, `profile-route.tsx` (also on
  React Query with a persist-client), `post-detail-route.tsx`, `bookmarks-route.tsx`,
  `notifications-route.tsx`, `settings-route.tsx`, `clubs-routes.tsx`,
  `chat-routes.tsx`, `deep-link-routes.tsx`. The Feed (`home/home-screen.tsx`) uses its
  own purpose-built equivalent (`getHomeScreenStore()`, a per-user module-level store
  keyed by feed tab, which also prefetches the *other* tabs' data in the background) —
  more sophisticated than `mount-cache`, not a gap.
- **Skeleton on load**: every audited page seeds `loading` from whether a cache hit
  exists and renders a dedicated skeleton component (`FeedSkeleton`,
  `SearchUserSkeleton`, etc., in `components/ui/skeleton.tsx`) while `loading` is true.
- **Route prefetch + scroll memory**: `app-navigation-runtime.tsx` (mounted once in
  the root layout, survives every navigation) already `router.prefetch()`s the 5
  primary tab routes and remembers/restores scroll position per root tab so returning
  to one doesn't reset to the top.
- **Double-submit prevention**: every primary submit/mutate action reviewed this
  session (composer publish, draft save, club join/leave, follow) already guards with
  a `busy`/`disabled` state. The one pattern that doesn't — optimistic like/save/redrop
  toggles reading `viewer` state at the start of an async handler — has a theoretical
  double-tap race, but `drop_likes`/`saves` (composite primary key) and
  `redrops_standard_unique` (partial unique index) make a duplicate insert impossible
  at the database layer regardless; worst case on a genuine simultaneous double-tap is
  a harmless extra round-trip, not data corruption or a duplicate row. Rewriting every
  toggle handler in the app for this low-severity edge case is a large, cross-cutting
  change this batch didn't find a concrete bug to justify, and overlaps with the
  already-tracked (not-yet-started) `WYN-160-web-design-system-consolidation` backlog
  item — flagging it here rather than taking it on unprompted.

No files changed in this batch. Reporting this as audited/verified rather than silently
skipping it, per the Founder's own instruction to report rather than decide scope
unilaterally when something doesn't need the assumed fix.

## Batch 7 — Search: URL state, "ทั้งหมด" default tab, debounce, error states

Root causes found:
- `submit()` only ever set local React state (`query`), never touched the URL — so
  typing a search and refreshing, going back, or sharing the link always landed back on
  empty Discovery. There was no `type=` URL param at all.
- Every submitted search defaulted to the "User" tab (`useState<...>("user")`, with a
  `#`-prefixed query the only exception). A query that only matches post captions (no
  matching username) opened on an empty "ไม่พบผู้ใช้" User tab first — exactly the bug
  described.
- No debounce — search only ran on explicit submit (Enter / the search icon).
- `UserResults`/`DropResults`/`ClubResults` had no error handling at all: an unhandled
  rejection just left `loading=false` with `rows=[]`, which renders identically to a
  genuine "no results" empty state — a real search failure was indistinguishable from
  "nothing matched."

Files Changed:
- `web/components/search-route.tsx`:
  - `SearchInner` now reads `q`/`type` from the URL as the source of truth and writes
    back via `router.replace()` (shallow, no history spam) — covers refresh/back/share.
  - Added a debounced (400ms) as-you-type effect; Enter/the search icon still submits
    immediately, bypassing the debounce.
  - Added a new `AllResults` component (the "ทั้งหมด" tab, now the default) showing a
    capped preview from each of Users/Posts/Clubs in one screen with "ดูทั้งหมด" links
    into the full tab — the User-tab-first-look bug is gone by construction, since the
    default no longer commits to one category before any data has loaded.
  - Added a distinct error state (with a "ลองใหม่" retry) to `UserResults`,
    `DropResults`, `ClubResults`, and the new `AllResults`, each with its own wording,
    separate from their existing loading/empty states.
  - Tab buttons got `role="tab"`/`aria-selected` (previously unlabeled toggle buttons).
- `web/app/parity-completion.css` — `.search-all-results`/`.search-all-see-more` (reuses
  the existing `.route-section`/`flutter-search-discovery` rhythm, no new visual
  language introduced).
- `web/components/dev/search-url-fixture.tsx` + `web/app/dev/search-url-fixture/page.tsx`
  (new, no-backend fixture — reimplements just the URL/debounce plumbing against a stub
  content area, since the real tab content needs a live Supabase session) +
  `web/tests/browser/search-url-state.spec.ts` (new, 5 checks: debounced URL write,
  "ทั้งหมด" default, tab-click persists across reload, a shared `?q=&type=` URL
  reproduces the same search, a 1-character query doesn't fire).

Tests: `npm run check` PASS. Playwright spec 5/5 PASS (chromium-desktop, same local
executablePath workaround as prior batches, reverted after). Hit and worked around an
apparent React Compiler ESLint bailout inconsistency (the identical
sync-input-from-URL effect lints clean in the real, larger `search-route.tsx` but the
same pattern in the small isolated fixture triggers `react-hooks/set-state-in-effect` —
documented inline with a scoped disable rather than silently suppressed).

Known Issues: Hashtag/mention links (`rich-post-text.tsx`, `/search?q=<tag>`) no longer
jump straight to the Posts tab for a `#`-prefixed query the way the old code did —
they now land on "ทั้งหมด" like every other search, per the Founder's explicit "All tab
is the default" instruction. Flagging this behavior change explicitly since it wasn't
called out by name in the bug report, in case the old hashtag-specific shortcut was
intentional and should come back as a `type=posts` param on those specific links.

## Batch 8 — Activity (Views/Likes/Comments/Reposts/Saves, unique views, ghost fix)

**Conflict found and escalated before writing any code**: item 8 asks for Views to
count by unique user/session, but the DB currently does the opposite on purpose —
WYN-083 (2026-09-02, Founder-approved, from the Beta2 spec directly, item 21/28)
deliberately removed `drop_views`' original unique-viewer dedup so views count
unlimited/every repeat, including the post's own author, exactly to fix a different
Founder complaint at the time ("นับไม่จำกัด... รวมถึงเจ้าของโพสต์ด้วย"). Asked the
Founder directly rather than picking a side; **decision: keep WYN-083's uncapped total
(still what ranking/trending/the on-post view badge use) and add a *separate*
unique-viewer count just for the Activity sheet's display.**

Also found "Activity" isn't a page anywhere in this codebase (web or Flutter) — it's
`post-detail-route.tsx`'s existing "ดูกิจกรรม" sheet (2 tabs: Likes/Reposts today),
which matches "แก้ Activity" ("fix" implying something existing) and "รายชื่อใน Activity
ต้องตรงกับข้อมูลจริง" (a list of *names*, which only this per-post sheet has — Views/
Saves have no name list by design, see below).

Root cause of the ghost "W @" rows: same class of bug WYN-130 already fixed for Club
Members — a `profiles` row can exist with no username/display_name at all
(`AuthRepository.setDateOfBirth` upserts a bare row before the Username onboarding
step ever runs), and the sheet's previous raw `.from("profiles").select(...).in("id",
ids)` join had no filter for it. `profiles.username` also had no length/non-empty
CHECK at all (`display_name` already did) — only a reserved-word check.

Files Changed:
- `supabase/migrations_wyn186_activity_unique_views_ghost_fix.sql` (new) —
  `drop_unique_viewer_count(uuid)` (new, separate from WYN-083's `drop_view_count()`,
  untouched); `drop_activity_profiles(uuid, kind, limit)` (new, ghost-filtered via the
  same `profile_private.onboarding_completed` check WYN-130 used, mirrors each source
  table's own SELECT policy exactly — `drop_likes` unrestricted, `redrops`/
  `drop_comments` exclude blocked-either-way authors — rather than loosening or
  tightening what a caller could already see); `profiles_username_not_empty` CHECK
  constraint (`not valid`, grandfathers existing rows, same safe pattern as the
  existing `profiles_username_not_reserved`) — blocks empty-string only, NULL (the
  legitimate not-yet-onboarded state) is untouched. **Not applied to any database** —
  Founder runs it via Supabase Dashboard SQL editor, per AGENTS.md Change Control.
  `content_save_count()` (WYN-014-era) and `drop_view_count()` (WYN-038/083) were
  already exactly what was needed for Saves/Views-total — reused, not rebuilt.
- `supabase/tests/wyn_186_activity_unique_views_ghost_fix_test.sh` (new) — 9 checks
  against a throwaway local Postgres DB, same harness as `wyn_130`/`wyn_185`.
- `web/components/post-detail-route.tsx` — `ActivitySheet` grew from 2 tabs to 5
  (Views/Likes/Comments/Reposts/Saves), each tab showing its own count in the label.
  Views and Saves are count-only (`drop_views`/`saves` are both RLS-scoped to
  "only the viewer/saver themselves," a deliberate WYN-038 privacy decision — there is
  no name list to show for these two, not even to the post's own author). Likes/
  Comments/Reposts keep the person-list format, now backed by the ghost-filtered RPC,
  plus a UI-level `Boolean(profile.username)` filter as a defense-in-depth backstop.
  Added a distinct error+retry state (was: silently empty on failure). Reads
  `?activity=1` to auto-open the sheet (the new Notifications entry point below).
- `web/components/notifications-route.tsx` — a `like_drop`/`comment_drop`/`redrop`
  notification now opens `/drop/<id>?activity=1` instead of the bare post, so tapping
  one lands straight in Activity — the entry point item 8 asked for.
- `web/app/post-detail-parity.css` — `.detail-activity-tabs` changed from a rigid
  2-column grid to a horizontal scroller (5 Thai label+count tabs don't fit a fixed
  grid at 390px without truncating), plus `.detail-activity-count` for the new
  count-only tab layout.
- `web/components/dev/activity-sheet-fixture.tsx` + `web/app/dev/activity-sheet-fixture/page.tsx`
  (new, no-backend fixture) + `web/tests/browser/activity-sheet.spec.ts` (new, 5
  checks: all 5 tab counts render, Views/Saves are count-only with no person list,
  Likes shows its list, a 0-count list tab shows its own empty state rather than
  looking like a count-only tab).

Tests: `npm run check` PASS. `bash supabase/tests/wyn_186_activity_unique_views_ghost_fix_test.sh`
9/9 PASS. Playwright spec 5/5 PASS (chromium-desktop, same local executablePath
workaround as prior batches, reverted after).

Known Issues: No live Supabase project, so the client-side RPC wiring is
typecheck/build-verified and the RPC logic itself is DB-test-verified, but the two
were never exercised together end-to-end. The Founder should apply the migration to
staging first and confirm the Activity sheet's 5 tabs against a real post with real
likes/comments/reposts/saves/views before production.

## Batch 9 — Follow (wording, busy state, full rollback)

Found the exact "กำลังติดตาม" complaint reproducible: every follow/unfollow toggle
button in the app (6 production call sites: Profile, Post Detail, Chat, Search x2,
Follower/Following lists, Suggested-to-follow) used
`following ? "กำลังติดตาม" : requested ? "ขอติดตามแล้ว" : "ติดตาม"` — "กำลังติดตาม"
("currently following") on a *button* reads as an in-progress verb, the same shape as
"กำลังโหลด"/"กำลังส่ง", not a completed state. None of the 6 showed any visible
difference between "request in flight" and "idle, waiting for a tap" beyond the
button merely going `disabled` — no spinner, no text change at all during the request.

`profile-route.tsx`'s `follow()` already had real optimistic follower-count updates
(the only one of the 6 that did) — but its failure-path rollback only restored
`following`/`requested`, not `followerCount`, so a failed request left the displayed
follower count permanently off by one even though the button itself reverted
correctly. Fixed as part of this batch.

Files Changed:
- `web/components/ui/follow-button-label.tsx` (new) — `followButtonLabel({ busy,
  following, requested })`, the one shared label function every call site now uses:
  `busy` → "กำลังดำเนินการ…", `following` → "ติดตามแล้ว" (was the ambiguous
  "กำลังติดตาม"), `requested` → "ขอติดตามแล้ว" (unchanged — already an unambiguous
  completed-state phrase), else "ติดตาม".
- `web/components/profile-route.tsx` — wired to the shared label; fixed `follow()`'s
  rollback to also restore `followerCount` on failure (previously left mutated).
- `web/components/post-detail-route.tsx` — the author-follow button had *no* busy
  guard or optimistic feedback at all (a genuine double-submit gap, not just a wording
  one); added a `followBusy` state, `disabled` guard, and the shared label.
- `web/components/chat-routes.tsx`, `web/components/profile-recommendations.tsx`,
  `web/components/profile-follow-list-route.tsx`, `web/components/search-route.tsx`
  (both the User-tab and Discovery-suggestions follow buttons) — wired to the shared
  label using each file's own already-existing busy/pending tracking.
- Left every *noun*/tab-label use of "กำลังติดตาม" untouched (Profile's "42
  กำลังติดตาม" follower-count stat, the Following tab in Profile/Home/the follow-list
  switcher) — those are standard, correct Thai for "(the list of accounts) being
  followed," not the reported bug, which was specifically the button-state wording.
- `web/components/dev/follow-button-fixture.tsx` + `web/app/dev/follow-button-fixture/page.tsx`
  (new, no-backend fixture — `followButtonLabel()` is a pure function, no Supabase
  needed) + `web/tests/browser/follow-button-label.spec.ts` (new, 5 checks: idle/busy/
  following/requested wording, busy taking priority over following).

Tests: `npm run check` PASS. Playwright spec 5/5 PASS (chromium-desktop, same local
executablePath workaround as prior batches, reverted after).

Known Issues: Optimistic follower-*count* updates (as opposed to the button's own
state) only exist on the Profile page, the one place item 9's literal wording
("อัปเดตจำนวนผู้ติดตามทันทีแบบ optimistic") applies to (it's the only follow button
with a visible count next to it). The other 5 call sites now get correct busy-state
feedback and completed-state wording, per the rest of item 9, but weren't converted to
optimistic toggling — none of them have a follower count on screen to update, and
doing so would mean the same conflict-of-scope tradeoff `toggleAuthorFollow`'s
wait-for-server design represents everywhere else in the app (a bigger, more invasive
change than this item's concrete complaints called for). Flagging rather than silently
picking one.
