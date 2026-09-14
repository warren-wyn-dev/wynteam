# WYN-159 — Search, Notifications, Chat

Tokens/primitives referenced here are defined in `wyn-159-web-v2-design-system.md`.
Existing code referenced: `web/components/search-route.tsx`, `notifications-route.tsx`,
`chat-inbox-parity.tsx`, `chat-routes.tsx`.

---

## Screen: Search

**Purpose:** Find people/posts/clubs/hashtags.

**User Flow:** Tap search from header/bottom-nav → type query → see live results grouped by type (or
existing tab set, whatever the current implementation groups by — preserve exactly) → tap a result →
navigate to Profile/Post Detail/Club.

**Components:** `WynosHeader` (compact — search field replaces title, per brief), `WynosSearchField`,
`WynosTabs` or `WynosPillButton` group if results are segmented (match existing segmentation, don't invent
a new one), `WynosListRow` per result (avatar/thumbnail + primary label + secondary meta).

**Interactions:** Existing debounced query behavior, existing empty/recent-search state, existing tap-to-
navigate behavior — all unchanged.

**States:** Empty query (recent searches / suggestions, existing content, restyled rows). No results
(`WynosEmptyState`). Loading (skeleton `WynosListRow`s).

**Responsive Behavior:** Search field full-width within the column at all breakpoints; results list
single column.

**Accessibility:** Search input has a visible label or `aria-label` ("ค้นหา"), clear button is a real
focusable control with `aria-label` ("ล้างคำค้นหา" or existing copy).

**Design Rules:** `WynosSearchField` uses `--surface` fill (not `--bg`) with no border by default, `--border`
on focus — this is the one exception where a filled (not outline) input reads correctly against the
reference's minimal aesthetic, matching common search-field convention in the X/Threads reference family.

**Handoff:** Depends on Search Field, List Row, Tabs/Pill Button primitives.

---

## Screen: Notifications

**Purpose:** Surface likes/comments/follows/mentions/club activity.

**User Flow:** Tap bell/nav slot → see list, newest first, existing "ทั้งหมด" / "การกล่าวถึง" (all/mentions)
segmentation (WYN-043) preserved → tap a row → navigate to the relevant post/profile/club.

**Components:** `WynosHeader`, `WynosTabs` (ทั้งหมด / การกล่าวถึง — existing set, unchanged), `WynosListRow`
per notification (avatar + rich text line + timestamp + optional thumbnail).

**Interactions:** Existing mark-as-read behavior (on view or on tap — preserve whichever the current
implementation does), existing tap-to-navigate per notification type (WYN-043 type table unchanged).

**States:** Unread indicator — a small dot or bold-weight row text (**not** a colored background band —
avoid the old heavier "unread card" treatment described as a hangover from the parity era; the reference's
whole aesthetic is "no heavy cards," and unread state should read the same way: a subtle dot in
`--text-primary` or `--accent-red` at most, never a filled colored row). Empty state (`WynosEmptyState`).

**Responsive Behavior:** Single column list at all widths, standard row height per `WynosListRow` token
(derive a consistent ~56–64px row height covering avatar + two lines of text, confirm against real content
during implementation rather than guessing further here).

**Accessibility:** Unread rows are announced as unread to screen readers (`aria-label` prefix or
`aria-current`, not color alone — satisfies the existing "don't communicate state with color only" rule).

**Design Rules:** Hairline `--border` row separators, no shadow, no unread background fill (see States).

**Handoff:** Depends on List Row, Tabs primitives.

---

## Screen: Chat — Inbox

**Purpose:** List of conversations.

**User Flow:** Tap chat nav destination → see conversation list (ทั้งหมด / ยังไม่อ่าน existing segmentation
per WYN-158 restoration notes) → message requests as a separate destination/banner (existing, preserve
exactly — this was explicitly called out as restored behavior in WYN-158 and must not regress) → tap a
row → open Conversation.

**Components:** `WynosHeader`, `WynosTabs` or `WynosPillButton` pair (ทั้งหมด / ยังไม่อ่าน), message-request
banner row (`WynosListRow` variant with a trailing chevron/count), `WynosListRow` per conversation (avatar
+ name + last-message preview + timestamp + unread marker).

**Interactions:** Existing tap-to-open, existing presence/typing indicators (WYN-139) unchanged — this pass
restyles the indicator's appearance (small dot, monochrome or the existing online-green convention — online
presence is a status color like Like, keep it as an intentional second color exception alongside Like and
link-blue, all three being pre-existing universal-convention colors, not new decoration).

**States:** Unread marker (dot, not full-row color fill — same rule as Notifications). Empty inbox
(`WynosEmptyState`). Message-request banner shown only when requests exist (existing conditional).

**Responsive Behavior:** Single column list; on desktop, an inbox+conversation split view is explicitly
**not** introduced by this brief (brief doesn't ask for it, and existing product is single-column
navigation) — keep the existing push-navigation model (inbox → conversation as a separate route), don't
invent a two-pane layout as part of this visual migration.

**Accessibility:** Unread state announced via label, not color alone.

**Design Rules:** Same list-row hairline-divider language as Notifications/Search.

**Handoff:** Depends on List Row, Tabs primitives.

---

## Screen: Chat — Conversation

**Purpose:** 1:1 (and existing group, if shipped) messaging thread.

**User Flow:** Open from Inbox → scroll message history → type in composer → send → existing realtime
delivery/typing-indicator behavior (WYN-139) unchanged.

**Components:** `WynosHeader` (back-chevron + peer name/avatar + presence dot), message bubble component
(new — not in the canonical primitive list since it's chat-specific; build as `WynosMessageBubble` following
the same token rules), lightweight composer (`WynosInput` variant, send `WynosIconButton`).

**Interactions:** Existing send/receive, existing message grouping rules (WYN-031 chat-message-grouping-
bubble-spec) — bubble grouping/timestamp-collapsing logic is unchanged, only restyled.

**States:** Sending/sent/failed message state (existing retry-on-fail behavior, restyle the failed indicator
to monochrome + a small `--accent-red` retry icon, consistent with red being reserved for
attention-worthy/negative or Like-adjacent signals — a failed send is a legitimate use of that same red).
Typing indicator (existing).

**Responsive Behavior:** Full-height single conversation column; composer sticks to viewport bottom with
`env(safe-area-inset-bottom)` and keyboard-visible-viewport handling (see Responsive/iPhone Safari notes in
the design-system doc's migration checklist — this screen is the highest-risk one for iOS keyboard/viewport
bugs, test explicitly on WebKit).

**Accessibility:** Message list is a live region for new incoming messages (if not already implemented,
add minimal `aria-live="polite"` on the list container without changing scroll/focus behavior).

**Design Rules:** Own messages: `--text-primary` fill, white text. Peer messages: `--surface` fill,
`--text-primary` text. No gradient bubbles, no color-per-user schemes — exactly two visual states (mine/
theirs), matching the monochrome system.

**Handoff:** Depends on Header, Input, Icon Button primitives. Highest implementation risk in this batch
(realtime + keyboard/viewport) — allocate extra QA time, do not rush this surface's regression testing.
