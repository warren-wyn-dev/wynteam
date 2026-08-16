# Design — WYN-020: Hashtag System

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-020-hashtag-system.md`

## Shared building blocks

- `core/text_utils.dart`: `hashtagPattern` (the one regex definition, Unicode-aware so Thai hashtags tokenize correctly) + `extractHashtags(text)` (exact tag set, lowercased). Both the rendering widget and the search-side exact-match filter import this — no second regex anywhere.
- `core/widgets/hashtag_text.dart`: new `HashtagText` widget, drop-in replacement for `Text(caption)` wherever a caption/content string is rendered. Splits the string into spans on `hashtagPattern`, styles `#tag` spans in `colorScheme.primary` + semibold, and on tap **builds its own repositories from `Supabase.instance.client` and pushes `HashtagFeedScreen` directly** — the same self-contained-navigation shortcut `PushNotificationService._openFromPushData` already uses, rather than threading a new callback parameter through every intermediate widget between the 6 render sites and their nearest repository-holding ancestor. `HashtagText` needs no new constructor params at any of its 6 call sites beyond the text itself.
- Applied at all 6 places a caption/content string is currently rendered as plain `Text`: `HomeDropCard`, `HomePopCard`, `DropDetailScreen`, `PopClipView`, `ClubPostCard`, `ClubPostDetailScreen`.

## Screen — Hashtag Feed

- Route: `HashtagFeedScreen(tag: 'WYN', ...)`, pushed from any hashtag tap.
- AppBar title: `#WYN`. TabBar: Latest (default) | Trending.
- Mixed Drop + Club post results, each rendered with its own existing card (`HomeDropCard` via `HomeFeedItem.fromDrop`, `ClubPostCard` with per-club role resolved the same way `FromYourClubsFeed`, WYN-015, already does it — `ClubRepository.fetchMyMembership` per distinct `clubId` seen in the results, cached in a map). Club post visibility needs no extra gating code: `club_posts`' own RLS already limits results to posts the searching user can actually see (approved member of a non-public club, or any Public club), the same guarantee `fetchFromJoinedClubs` already relies on.
- **Matching approach**: query `DropRepository.searchByCaption(query: '#$tag')` / a new `ClubPostRepository.searchByContent(query: '#$tag')` (ILIKE, ILIKE, same shape as WYN-009's existing search) to get a bounded SQL-side candidate set, then keep only results where `extractHashtags(caption/content).contains(tag.toLowerCase())` — the exact-match re-check that fixes the `#WYNfamily`-matches-`#WYN` problem flagged in WYN-020's own R4.
- **Latest** = merged results sorted by `createdAt` desc.
- **Trending** = merged results sorted by `likeCount + commentCount` desc.
- **Scope decision**: single bounded fetch (page 0 only from each source, no infinite scroll) rather than a fully paginated cross-content-type feed — pagination across two different tables with independent ILIKE queries and a client-side merge/sort has no clean "page N" definition without a lot more machinery, and this is a discovery feature, not a primary feed. If a hashtag turns out to need real pagination once usage data exists, that's a natural fast-follow scoped narrowly to this one screen.
- Empty state: "ยังไม่มีโพสต์ที่ใช้ #{tag}".

## Non-goals this round

- No `hashtags` entity table (stays ILIKE-based, per the task's own Recommendation — consistent with WYN-009's existing precedent).
- No infinite scroll on Hashtag Feed (see Scope decision above).
- No change to how Drop/Club post creation stores captions -- hashtags are still just substrings of the existing `caption`/`content` text, not a separate structured field.
