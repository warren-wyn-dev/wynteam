# Design — WYN-017: Home Trending + Recommended Clubs

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-017-home-trending-recommended-clubs.md`

## Screen 1 — Home (additions only)

Layout order (top to bottom), existing rows unchanged:

```
Top row (search + notification bell)      <- unchanged (WYN-012)
ClubSection                                <- unchanged row + NEW recommended row
Trending row                               <- NEW
Feed mode toggle (สำหรับคุณ / จาก Club)     <- unchanged (WYN-015)
Main feed (chronological)                  <- unchanged (WYN-007)
```

### Trending row

- New horizontal row, ~110px tall, placed between `ClubSection` and the feed-mode toggle.
- Header: `Text('กำลังนิยม')` in the same `titleSmall` bold style `ClubSection` uses for "CLUB", left-aligned, no "ดูทั้งหมด" action this round (no dedicated Trending screen yet — out of scope, see WYN-017 Recommendation).
- Content: horizontal `ListView` of up to 10 square tiles (~90x90), each a **new** `TrendingTile` widget (`app/lib/features/home/presentation/widgets/trending_tile.dart`) — square thumbnail (image for Drop, thumbnailUrl for Pop with a small play-icon overlay, mirroring `HomePopCard`'s treatment) + like-count scrim at the bottom, visually modeled on `DropGridTile` but accepting a `HomeFeedItem` so one tile handles both content types (no existing tile does this — `DropGridTile`/`PopGridTile` are each single-type).
- Tap → same navigation as tapping a card in the main feed: `_openDrop`/`_openPop` (already on `_HomeFeedScreenState`, reused directly — no new navigation logic).
- Data: "trending" = highest `like_count + comment_count` among items posted in the last 48 hours. 48h keeps the row from being permanently dominated by old high-engagement posts, and is short enough that a new post has a real chance to surface if it's getting traction fast.
- Query approach: reuse the `home_feed` view exactly as `HomeRepository.fetchFeed` already does (`.from('home_feed').select().gte('created_at', <48h ago>).order('created_at', desc).limit(100)`), then sort the 100 candidates by `likeCount + commentCount` in Dart and take the top 10 — PostgREST can't `order()` by a computed expression that isn't a real column, and adding one means altering the view. Mirrors the exact precedent already in this codebase: `ClubRepository.fetchPopularClubs` fetches a bounded candidate set and sorts client-side rather than adding scalable server-side ranking, justified there as fine for "still a small catalog" — same justification applies here.
- Loading/Empty/Error: same fail-safe pattern as `ClubSection`'s club row (`FutureBuilder`, blank `SizedBox.shrink()` while loading/on error, small "ยังไม่มี content กำลังนิยม" text when the result list is empty) — a failed Trending fetch must never block the main feed underneath it from rendering (WYN-017 R3).

### ClubSection — Recommended Clubs row

- Add a second horizontal row, **shown only when the current user's joined-Club count is under 3** — deliberately not always-on, to keep the section from growing past a reasonable height for active Club members who already see their own clubs; the under-3 threshold is exactly where "help discover new communities" matters most.
- Reuses `ClubRepository.fetchPopularClubs()` (already built for WYN-015's Explore screen) and the existing `ClubMiniCard` widget verbatim — no new club-fetching logic, no new club card.
- Row header: `Text('Club แนะนำ')`, same style as the existing "CLUB" header, placed directly below the existing "Club ของฉัน" row.
- Tap → `ClubPage` (same as tapping a club in the existing row).

### ClubSection layout change (needed to fit the new row safely)

The current `ClubSection` wraps everything in `ConstrainedBox(maxHeight: 180)` with the club-row as an `Expanded` child — that only works because the 180px ceiling gives `Expanded` something to size against. Adding a second conditional row inside the same fixed 180px would either get clipped or force a fragile height recalculation, and this exact family of bug (fixed-height container fighting a variable-content child) already bit `ViewProfileScreen` once during WYN-015 (see `.wyn/company/DECISIONS.md`, 2026-08-14, the 1:1-ratio overflow fix).

Avoid repeating that: drop the outer `ConstrainedBox` + `Expanded` pattern entirely. Give the "Club ของฉัน" row a fixed `SizedBox(height: 108)` (108 ≈ what the old 180px ceiling left it after the ~72px header+button rows above it — so its rendered size doesn't change) instead of `Expanded`, and give the new "Club แนะนำ" row (header + list) the same fixed-height treatment, shown or not via a plain `if`. A `Column(mainAxisSize: MainAxisSize.min)` of fixed-height children needs no ambient height constraint at all, which is what makes this safe against the same class of bug.

## Non-goals this round

- No dedicated "ดูทั้งหมด Trending" screen (would need its own pagination/tabs — out of scope per WYN-017's Recommendation to keep this additive and low-risk).
- No change to the main feed's chronological ordering, `home_feed` view, or the "จาก Club ของคุณ" toggle (WYN-018's job, not this one).
