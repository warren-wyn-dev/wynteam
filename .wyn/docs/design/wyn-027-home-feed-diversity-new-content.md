# Design — WYN-027: Home Feed Diversity + New Content Indicator

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-027-home-feed-diversity-new-content.md`
Depends on (read-only, do not modify): `.wyn/docs/design/wyn-018-home-feed-ranking.md`, `app/lib/features/home/data/home_ranking.dart`

Both requirements below are **additive** — R1 is a new post-processing step that runs *after* `HomeRepository.fetchRankedFeed`'s existing `items.sort(...)` call; R2 is a new repository method + new screen-level polling/banner. Neither touches `rankingScore()` or the 8 locked unit tests behind it (`home_ranking_test.dart`). Same discipline as WYN-018 itself: keep the risky, already-QA'd thing (`rankingScore`) untouched, and put all new behavior in new, independently-testable functions.

---

## R1 — Feed Diversity (sliding-window anti-repetition pass)

### Rule

No author may occupy **more than 2 consecutive positions** in a row in the final ordered list (`maxConsecutiveSameAuthor = 2`). Equivalently: look at any 3 consecutive positions — they must not all share the same author. This matches the AC wording exactly ("ไม่แสดง author เดียวกันติดกันเกิน 2 ตำแหน่งรวด") and the product spec's "ภายใน 3 ตำแหน่งล่าสุด" example (2 previous + the candidate being placed = 3).

- **Never drops or adds items.** Output is always a permutation of the input — same length, same set of ids. This is a hard invariant (AC: "Diversity pass ไม่ทำให้เนื้อหาหายไป").
- **Reorders, does not hide.** No score is changed, nothing is filtered out.
- If there isn't enough author variety left to satisfy the rule (e.g. the remaining unplaced items are all by the same author), the rule is allowed to break rather than get stuck — AC explicitly scopes the guarantee to "เมื่อมี content จาก author อื่นเพียงพอให้กระจาย".

### Where it runs

Applied **only** inside `HomeRepository.fetchRankedFeed` ("สำหรับคุณ"), on the full 200-item scored-and-sorted candidate list, **before** the existing pagination slice — i.e. inserted between the existing `items.sort((a, b) => ...)` call and the existing `return items.sublist(from, ...)` line in `home_repository.dart`. Running it over the whole 200-item window (not per-10-item page) is required so a run isn't invisibly split/rejoined across a page boundary (item 10 of page 0 and item 1 of page 1 must also respect the rule).

```dart
// home_repository.dart, fetchRankedFeed — unchanged lines shown for anchoring
items.sort((a, b) { ... });                 // existing WYN-018 line, untouched

final diversified = diversifyFeed(items);    // NEW (WYN-027) — post-processing pass

if (from >= diversified.length) return [];
return diversified.sublist(
  from,
  to + 1 > diversified.length ? diversified.length : to + 1,
);
```

### Which modes use it

| Mode | Uses diversify pass? | Why |
|---|---|---|
| "สำหรับคุณ" (`fetchRankedFeed`) | **Yes** | This is the mode the product spec targets — it's the only feed where an algorithm already reorders content away from strict recency, so smoothing out repetition belongs at the same layer. |
| "ล่าสุด" (`fetchFeed`, chronological) | **No** | "ล่าสุด" exists specifically as the un-touched, literal-timeline escape hatch from any algorithm (see WYN-018 design doc, R3: "ranking doesn't silently replace it"). Reordering it — even just to diversify — breaks that promise and would make "ล่าสุด" no longer mean "exactly what was posted, in order." |
| "กำลังนิยม" (Trending row, `fetchTrending`) | **No** | Trending is a small (10-item), already-curated "top by engagement" list with its own distinct promise ("กำลังนิยม" = ranked by engagement, full stop). It's also too short for a sliding-window rule to matter much, and forcing a lower-engagement item in just for diversity would misrepresent what "trending" means. |
| "จาก Club ของคุณ" (`FromYourClubsFeed`) | **N/A** | Separate widget/query (WYN-015), not `home_feed`-based, and not in this task's scope. |

### Algorithm (pseudocode — implement as-is)

```dart
/// home_diversity.dart (new file, mirrors home_ranking.dart's structure:
/// one pure function, no DB/network dependency, directly unit-testable).
///
/// Post-processing pass for WYN-027 — reorders an already-ranked list so
/// no author occupies more than [maxConsecutiveSameAuthor] consecutive
/// positions. Never adds or removes items: the result is always a
/// permutation of [rankedItems]. Deterministic and pure. See
/// .wyn/docs/design/wyn-027-home-feed-diversity-new-content.md.
List<HomeFeedItem> diversifyFeed(
  List<HomeFeedItem> rankedItems, {
  int maxConsecutiveSameAuthor = 2,
}) {
  if (rankedItems.length <= maxConsecutiveSameAuthor) return rankedItems;

  // `remaining` keeps its original score order at all times -- we only
  // ever remove from it (either from the front, or by pulling a later
  // item forward). We never re-sort it.
  final remaining = List<HomeFeedItem>.from(rankedItems);
  final result = <HomeFeedItem>[];

  while (remaining.isNotEmpty) {
    final candidate = remaining.first;

    final wouldExtendRun = result.length >= maxConsecutiveSameAuthor &&
        result
            .sublist(result.length - maxConsecutiveSameAuthor)
            .every((placed) => placed.authorId == candidate.authorId);

    if (!wouldExtendRun) {
      // Placing the top-of-remaining item is safe -- take it as-is,
      // preserving its score-order position among items placed so far.
      result.add(candidate);
      remaining.removeAt(0);
      continue;
    }

    // candidate would create a 3rd-in-a-row for the same author. Find
    // the nearest later item (closest to the front == next-highest
    // remaining score) by a *different* author, and pull it forward --
    // this is the "interleave" the product spec asks for, not a drop.
    final swapIndex =
        remaining.indexWhere((item) => item.authorId != candidate.authorId);

    if (swapIndex == -1) {
      // Every remaining item is by the same author as candidate -- no
      // diversity left to interleave with. Per AC, the rule is allowed
      // to break here rather than get stuck; place everything as-is.
      result.addAll(remaining);
      remaining.clear();
    } else {
      // Pull the diverse item forward; candidate stays at remaining[0]
      // and will be retried next loop, once the new tail of `result`
      // isn't 2x candidate's author anymore.
      final pulled = remaining.removeAt(swapIndex);
      result.add(pulled);
    }
  }

  return result;
}
```

**Why this terminates (no infinite loop):** every iteration either (a) removes `remaining.first` (the "safe placement" branch), or (b) removes some `remaining[swapIndex]` (the "swap forward" branch), or (c) clears all of `remaining` (the "give up" branch). `remaining.length` strictly decreases every iteration in all three cases, so the loop runs at most `rankedItems.length` times. Worst case is O(n²) (a linear scan for each of n items) — fine at the 200-item candidate-window scale this runs at (same scale `rankingScore`'s own sort already operates on).

**Worked trace** (authors shown as letters, already in score order): input `A A A B C` with `maxConsecutiveSameAuthor = 2`:
1. `result=[]`, candidate `A` → safe (result too short to violate) → `result=[A]`, `remaining=[A A B C]`
2. candidate `A` → safe → `result=[A A]`, `remaining=[A B C]`
3. candidate `A` → **would extend run** (last 2 in result are both `A`) → find first non-`A` in `remaining` → index 1 (`B`) → pull `B` forward → `result=[A A B]`, `remaining=[A C]`
4. candidate `A` → safe now (last 2 in result are `A, B`) → `result=[A A B A]`, `remaining=[C]`
5. candidate `C` → safe → `result=[A A B A C]`, `remaining=[]`

Final: `A A B A C` — same 5 items, no run longer than 2, and items were only *moved*, never dropped. This is the exact shape of case the AC describes ("follow user ที่มีหลายโพสต์ล่าสุด → feed ไม่แสดง author เดียวกันติดกันเกิน 2 ตำแหน่งรวด").

### Required unit tests (new file `home_diversity_test.dart`, mirrors `home_ranking_test.dart`)

1. **Invariant — no data loss**: for any input, `diversifyFeed(input).length == input.length` and the set of ids is identical (a permutation, not a filter). This is the single most important test given AC's explicit "ไม่ทำให้เนื้อหาหายไป".
2. A run of 4+ same-author items with enough other-author items available → output has no run longer than 2.
3. All items by a single author (no diversity possible) → output is unchanged (same order), proving the "give up gracefully" branch doesn't crash or drop items.
4. Already-alternating input (e.g. `A B A B A`) → output identical to input (no unnecessary reordering — the pass should be a no-op when the rule is already satisfied).
5. Fewer than `maxConsecutiveSameAuthor + 1` total items → returns input unchanged (the early-return guard).

### Explicit non-goal

`DropRepository.fetchRankedFeed`'s own "For You" tab (added as a WYN-018 follow-up, see that design doc's "Non-goals" section) also calls `rankingScore` but is **not** in scope here — this task only touches `HomeRepository.fetchRankedFeed`. Applying the same diversify pass to Drop's For You tab is a reasonable future follow-up for consistency, but wasn't asked for and shouldn't be bundled in without a decision to do so.

---

## R2 — New Content Indicator (polling + banner)

### Polling mechanism

- **Interval: 45 seconds** (`Timer.periodic(const Duration(seconds: 45), ...)`) — the midpoint of the product spec's suggested 30-60s range. This is the **first periodic-polling `Timer` in the codebase** (the existing notification badge, `_loadUnreadNotificationCount`, only fetches once on screen load/return, it doesn't poll) — flagged so Coding treats lifecycle cleanup (below) as a first-class requirement, not an afterthought.
- **Query — lightweight count only**, same `count(CountOption.exact)` pattern `NotificationRepository.countUnread()` already uses (a HEAD request; PostgREST returns the count via a response header, never fetches row bodies):

```dart
// home_repository.dart — new method
/// Lightweight poll for WYN-027's "new content" banner -- counts rows
/// only (never fetches them) via count(CountOption.exact), same pattern
/// as NotificationRepository.countUnread. `since` is the timestamp of
/// the last successful feed load (see HomeFeedScreen._lastSeenAt), not
/// tied to any particular item's created_at, so it works the same way
/// whether the feed is in ranked or chronological order.
Future<int> countNewSince(DateTime since) async {
  final response = await _client
      .from('home_feed')
      .count(CountOption.exact)
      .gt('created_at', since.toIso8601String());
  return response;
}
```

- **`since` boundary**: `HomeFeedScreen` tracks `DateTime? _lastSeenAt`, set to `DateTime.now().toUtc()` at the moment `_loadInitial()` successfully repopulates `_items` (inside the same `setState` call that clears/refills `_items`). Using wall-clock "moment I last (re)loaded" rather than e.g. `_items.first.createdAt` is deliberate: in "สำหรับคุณ" mode, `_items` is ranked by score, not strict recency, so the newest item isn't reliably at index 0 — a time-of-load boundary is correct regardless of feed mode.
- **Overlap guard**: skip a poll tick if the previous one hasn't returned yet (`bool _isPolling` flag), so a slow response near a tick boundary can't fire two overlapping count queries.
- **Fail-open on error**: a failed poll (network blip) is silent — same pattern as `_loadUnreadNotificationCount` — it just tries again on the next tick, no error UI for a background check.

### Start/stop lifecycle — must account for `IndexedStack`

`RootShell` (`app/lib/features/root/presentation/root_shell.dart`) renders all 5 tabs inside a single `IndexedStack` to preserve each tab's scroll position/state — confirmed by that file's own comment ("IndexedStack keeps every tab's State alive"). This means **`HomeFeedScreen.dispose()` does not fire when the user switches to Drop/Pop/Profile/ZOKY** — the widget stays mounted, just not visible. A `Timer.periodic` started in `initState` and only cancelled in `dispose` would keep polling forever in the background, failing the AC ("หยุด polling เมื่อออกจากหน้า Home") and the battery/network risk the product spec calls out (R2).

Required fix: thread current-tab visibility into `HomeFeedScreen` explicitly, the same way `RootShell` already threads `_profileVisitKey` into `ViewProfileScreen` for an analogous IndexedStack problem.

1. `HomeFeedScreen` gains a new required constructor parameter: `required this.isVisible` (`final bool isVisible`).
2. `RootShell.build` passes `isVisible: _index == 0` at the `HomeFeedScreen(...)` call site (`root_shell.dart`, where the `tabs` list is built).
3. `_HomeFeedScreenState.didUpdateWidget` reacts to `isVisible` flipping:

```dart
@override
void didUpdateWidget(covariant HomeFeedScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.isVisible == oldWidget.isVisible) return;
  if (widget.isVisible) {
    _startPolling();
    _pollForNewContent(); // catch-up check immediately, don't wait a full 45s
  } else {
    _stopPolling();
  }
}
```

4. `initState` starts polling only after the first load completes (`_loadInitial()` sets `_lastSeenAt`, then start the timer) — no point polling "new since X" before X exists.
5. `dispose()` still calls `_stopPolling()` too, as the final safety net for when `RootShell` itself is torn down (e.g. sign-out).

```dart
void _startPolling() {
  _pollTimer?.cancel();
  _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) => _pollForNewContent());
}

void _stopPolling() {
  _pollTimer?.cancel();
  _pollTimer = null;
}
```

### Banner UI

**Position**: floating pill, horizontally centered, near the top of the feed content area — inside the `Stack` that wraps `_buildBody()`'s `Expanded` region (below the feed-mode `SegmentedButton`, overlaid on top of the scrolling list itself, not pushing content down). Only rendered when `_feedMode != _HomeFeedMode.fromYourClubs` (that mode has its own separate widget/query, untouched by this task).

**Copy**: "↑ {n} โพสต์ใหม่" (e.g. "↑ 12 โพสต์ใหม่"). Deliberately "โพสต์" (post) rather than the AC's illustrative "Drop ใหม่" wording, since `home_feed` mixes Drop and Pop — the count can include either or both, and the banner shouldn't imply it's Drop-only.

**Visual**: Material pill/chip — `WynSpacing.radiusFull`-style fully-rounded corners, background `colorScheme.primary` (WYN Blue per the approved DS-001 direction — Blue + White + Soft Gray, no new color introduced), white/`onPrimary` text and a small up-arrow icon, subtle `elevation` (2-4dp) so it visually floats over the list beneath it. Compact height (~40dp) with horizontal padding (`WynSpacing.space4`) — wraps its content, does not span full width, so it reads as a floating affordance rather than a blocking banner. This is a small, WYN-native pill component — not a copy of any specific competitor's "new posts" banner treatment (matches DS-001's "ห้ามลอก Layout ของ Instagram/TikTok" instruction; a floating count pill is a common, non-proprietary pattern, not a distinctive layout being copied).

**Component**: extract as its own widget, `widgets/new_content_banner.dart` (`NewContentBanner`), mirroring how `TrendingTile`/`HomeDropCard`/`HomePopCard` are already extracted from `home_feed_screen.dart` rather than inlined — keeps it independently testable via widget test.

```dart
// widgets/new_content_banner.dart — shape only, not final code
class NewContentBanner extends StatelessWidget {
  const NewContentBanner({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  // Material(color: colorScheme.primary, borderRadius: fully rounded) +
  // InkWell(onTap) + Row(Icon(Icons.arrow_upward, size: 16), Text('$count โพสต์ใหม่'))
  // wrapped in Semantics(button: true, label: '$count โพสต์ใหม่ แตะเพื่อโหลด')
}
```

**Appear/disappear animation**: wrap in `AnimatedSlide` (from `Offset(0, -1)` to `Offset.zero`) + `AnimatedOpacity` (0 → 1), ~200ms, `Curves.easeOut`, keyed on `_newContentCount > 0`. Reverse the same animation (slide up + fade out) when the count returns to 0 — both on successful banner-tap reload and, if it ever happens, if `_lastSeenAt` gets bumped by another path.

### Tap behavior — reuse the existing full-reload path, no new merge logic

On tap: hide the banner immediately (optimistic — `setState(() => _newContentCount = 0)`), then call the **exact same `_loadInitial()`** the pull-to-refresh `RefreshIndicator` already calls (`home_feed_screen.dart`, `_buildBody`'s `RefreshIndicator(onRefresh: _loadInitial, ...)`). No new dedup/merge code is needed: `_loadInitial()` already does a full clear-and-repopulate-from-page-0 (`_items..clear()..addAll(items)`), which is why the "ไม่ duplicate กับที่มีอยู่แล้ว" AC is satisfied by construction — there's nothing old left in `_items` to duplicate against. This is deliberately the same brief "list clears → center spinner → repopulates" experience users already get from pulling to refresh today, not a new/different loading pattern — lower implementation risk than building an incremental prepend-only fetch, and consistent with reusing already-proven code per company convention.

After the reload resolves, scroll to top so the user actually sees the fresh content (this is the "...เลื่อนขึ้นไปดู" half of the product spec's "แตะแล้วค่อยโหลด/เลื่อนขึ้นไปดู"):

```dart
Future<void> _onNewContentBannerTap() async {
  setState(() => _newContentCount = 0);
  await _loadInitial(); // same method RefreshIndicator already calls; also resets _lastSeenAt
  if (!mounted) return;
  await _scrollController.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}
```

No auto-scroll and no auto-reload ever happens from the *polling* side — only `_newContentCount` changes when a poll finds new rows. The feed itself never jumps or reorders on its own while the user is reading, satisfying "ห้ามบังคับ feed กระโดดเองระหว่างผู้ใช้กำลังอ่าน" — jumping only ever happens as the direct result of the user's own tap.

### States

| State | Trigger | Visual |
|---|---|---|
| Hidden (default) | `_newContentCount == 0` | No banner rendered |
| Appearing | A poll tick finds `count > 0` | Slide-down + fade-in, ~200ms |
| Visible | `_newContentCount > 0`, feed idle | Pill showing exact count, tappable |
| Reloading | User tapped the banner | Banner already hidden (optimistic); feed shows its existing `_isLoadingInitial` center-spinner state briefly (same as pull-to-refresh today) |
| Post-reload | `_loadInitial()` resolves | Feed shows new content at top; scroll animates to position 0 |

### Accessibility

- `NewContentBanner` wrapped in `Semantics(button: true, label: '$count โพสต์ใหม่ แตะเพื่อโหลด', excludeSemantics: true)` — same `Semantics` + `excludeSemantics` pattern already used for the search bar and notification bell in this same screen (`_buildSearchBar`, `_buildNotificationButton`).
- Minimum touch target ~40-44dp tall pill, generous horizontal padding — no target smaller than the platform minimum.
- Color contrast: white/`onPrimary` text on `colorScheme.primary` background meets WCAG AA at the app's existing primary blue (same combination already used elsewhere in the app, e.g. the notification badge and primary buttons — no new color pairing introduced).

### Responsive behavior

- Pill width is intrinsic (wraps its text/icon content, not full-width), centered horizontally via `Center` inside a `Positioned(left: 0, right: 0, ...)` — so it stays centered and appropriately sized on any phone width without special-casing screen size.
- Positioned with top padding (`WynSpacing.space2`) inside the already-`SafeArea`-wrapped screen body, so it never sits under a notch/status bar on any device.

---

## Design Rules (recap)

1. `rankingScore()` and its 8 locked tests are never touched by this task — R1 is a strictly-additive post-processing function.
2. R1's diversify pass runs on the full ranked candidate window, before pagination slicing — never per-page in isolation.
3. R1 only applies to "สำหรับคุณ" — "ล่าสุด" and "กำลังนิยม" keep their existing, un-diversified ordering on purpose (see the mode table above for why).
4. R1 must never change the total item count or drop an item — verified by a dedicated permutation-invariant unit test, not just a visual check.
5. R2's polling `since` boundary is a load-timestamp (`_lastSeenAt`), not an item's `createdAt` — correct in both ranked and chronological modes.
6. R2's polling must stop when the Home tab is not the visible tab (`IndexedStack` caveat, not just on `dispose()`) — implemented via a new `isVisible` parameter threaded from `RootShell`.
7. R2's banner tap reuses `_loadInitial()` verbatim (the same method `RefreshIndicator` already calls) rather than introducing new merge/dedup logic — minimizes new, untested code paths for a task the product spec itself rates as low risk/additive.
8. No new color, typography, or layout primitive is introduced — the banner is a pill using the existing `colorScheme.primary` (WYN Blue) and `WynSpacing` tokens already used throughout Home.

## Handoff

To AI Coding:
- New file `app/lib/features/home/data/home_diversity.dart` (`diversifyFeed`), wired into `HomeRepository.fetchRankedFeed` exactly at the point shown above.
- New test file `home_diversity_test.dart` with (at minimum) the 5 cases listed under R1.
- New `HomeRepository.countNewSince(DateTime since)` method (count-only query).
- `HomeFeedScreen` gains: `required this.isVisible` constructor param, `_lastSeenAt`/`_newContentCount`/`_pollTimer` state, `_startPolling`/`_stopPolling`/`_pollForNewContent`/`_onNewContentBannerTap` methods, `didUpdateWidget` override, and the `NewContentBanner` widget wired into the existing `Stack` around `_buildBody()`.
- `RootShell` call site for `HomeFeedScreen(...)` gains `isVisible: _index == 0`.
- New widget file `app/lib/features/home/presentation/widgets/new_content_banner.dart` (`NewContentBanner`).
- No `schema.sql` changes required for either R1 or R2 (R2's count query reads the existing `home_feed` view's existing `created_at` column; no new index is being requested here — the existing chronological/trending/ranked queries already filter/order by `created_at` without a dedicated index today, so this doesn't change that pre-existing, out-of-scope characteristic).
- No RLS changes — `home_feed` is `security_invoker = true` already (WYN-007); the new count query is subject to the exact same visibility as every other `home_feed` read.
