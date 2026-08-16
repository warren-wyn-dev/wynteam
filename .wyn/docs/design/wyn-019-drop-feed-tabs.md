# Design — WYN-019: Drop Feed Redesign + Tabs

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-019-drop-feed-tabs.md`

## R7 decision: replace the grid as Drop tab's default view, but don't delete it

The spec's own AppBar/TabBar mockup describes a scrollable feed, not a grid, so the grid can't stay the *default* view and still satisfy "Drop ไม่ใช่แค่หน้าสำหรับสร้างโพสต์ ... ต้องมีหน้า Drop Feed". But "ห้ามทำลายฟีเจอร์เดิม" doesn't require keeping this exact screen's exact layout — it requires the underlying capability (browse all Drops, tap into detail) to keep working, which it does either way. `DropGridTile` itself isn't deleted — `ProfileDropGridTab` (WYN-013) already reuses it independently for a user's own-profile grid, so the grid rendering capability stays fully alive in the codebase, just no longer mounted as the Drop tab's own view. Net effect: nothing a user could do before stops working; the Drop tab's browsing layout changes from grid to feed, which is exactly what was asked for.

## Screen 1 — Drop tab

```
AppBar: "Drop" + สร้าง Drop button (unchanged)
TabBar: For You | Following | Latest   <- NEW, default For You
Feed (per-tab, scrollable, HomeDropCard reused verbatim)
```

- Reuses `HomeDropCard` (WYN-007) exactly — no new card widget. `HomeDropCard` takes a `HomeFeedItem`, and `Drop` (WYN-005) already carries every field a Drop-typed `HomeFeedItem` needs, so a `HomeFeedItem.fromDrop(Drop)` factory bridges the two (mirrors the existing reverse conversion, `HomeFeedItem.toDrop()`, that WYN-007 already has for the opposite direction).
- Tapping a card still opens `DropDetailScreen` exactly as the grid did — no navigation change.
- **For You** (default): chronological for now, identical query to today's `DropRepository.fetchFeed` — WYN-019 doesn't implement ranking (that's WYN-018's job). Once WYN-018 ships, For You switches to the shared ranking query so the term means the same thing on Home and Drop.
- **Latest**: chronological, same query as For You right now (`fetchFeed`) — they'll diverge once WYN-018 lands. Two tabs showing identical content on day one is expected and acceptable; the tabs exist for the UI to be ready for that divergence, not to force a difference before there's a real ranking signal.
- **Following**: new `DropRepository.fetchFollowingFeed(page)` — Drops from users the current user follows, chronological. Empty state distinct from the other tabs: "ยังไม่ได้ follow ใครเลย ลองดู For You เพื่อค้นหาคนน่าสนใจ" (a join-prompt in the same spirit as WYN-015's "จาก Club ของคุณ" empty state, not the generic "ยังไม่มีใครโพสต์" text).
- Switching tabs re-fetches from scratch (no shared pagination state across tabs, same independent-per-tab approach `SearchScreen`'s User/Drop/Pop/Club tabs already use).
- Location: `drops` gets a nullable `location` text column (schema-only, R6) — no UI reads or writes it this round.

## Non-goals this round

- No ranking algorithm for "For You" (WYN-018).
- No UI to set/display location on a Drop.
- No change to `CreateDropScreen`, `DropDetailScreen`, or `ProfileDropGridTab`.
