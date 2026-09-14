# WYN-159 — Profile, Post Detail

Tokens/primitives referenced here are defined in `wyn-159-web-v2-design-system.md`.
Existing code referenced: `web/components/profile-route.tsx`, `profile-parity-route.tsx`,
`profile-recommendations.tsx`, `profile-follow-list-route.tsx`, `post-detail-route.tsx`,
`golden-drop-card.tsx`, `web/app/profile-golden-final.css`, `web/app/post-detail-parity.css`.

---

## Screen: Profile (own / other user)

**Purpose:** Show a user's identity, stats, and content across tabs.

**User Flow:** Arrive via bottom nav (own profile), avatar/name tap from any post (other user), or
`/[profileSlug]` public link. View cover/avatar/bio/stats → switch tabs (สื่อ / รีโพสต์ / ถูกใจ) →
scroll that tab's `WynosPostCard` grid/list → tap Follow/Message/Edit depending on ownership.

**Components:** `WynosHeader` (back-chevron + name, on other-user profile; menu icon on own profile),
`WynosAvatar` (72px — see open sizing note in design-system doc), `WynosSection` (bio/stats block),
`WynosPillButton` (Follow / Following / Message / Edit Profile depending on state), `WynosTabs` (สื่อ /
รีโพสต์ / ถูกใจ — **exact existing tab set, unchanged** per standing product requirement), list of
`WynosPostCard`.

**Interactions:** Tab switch (existing behavior). Follow/Unfollow toggle (existing). "ผู้ติดตาม"/"กำลัง
ติดตาม" counts tap → Followers/Following list routes (existing `profile-follow-list-route.tsx`, restyle
rows only, no behavior change). Edit Profile (own) → existing settings/edit flow, unchanged.

**States:**
- Own profile: Edit Profile pill instead of Follow; no more-menu (or a reduced own-profile menu — preserve
  exact existing conditional).
- Private/blocked interactions: existing gates (WYN-039 private-account follow-request, WYN-027 block)
  unchanged — this is a visual pass only, all authorization/visibility logic stays server-enforced exactly
  as today.
- Empty tab (e.g. no reposts yet): `WynosEmptyState`, monochrome, existing copy.
- Loading: skeleton header block + skeleton post rows.

**Responsive Behavior:** Single column at all widths, same max-width column as the rest of the app shell.
Cover image (if `profiles.cover_url` is populated, per the 2026-09-10 Founder reference note in WYN-141)
spans the column width, `16px` radius bottom corners only where it meets the avatar overlap, matching the
existing Founder-approved profile screenshot metrics from WYN-141 — that Founder-supplied visual reference
for Profile takes precedence over inventing new proportions here; this doc only re-skins colors/typography/
border language onto those already-approved metrics, it does not re-derive layout from scratch.

**Accessibility:** Stats (posts/followers/following counts) are readable by screen readers as labeled
values, not bare numbers (existing `aria-label` pattern if present, else add "N ผู้ติดตาม" style labels).

**Design Rules:** Thin `--border` separators between header/stats/tabs sections (no shadowed card blocks).
Tabs use the same underline-active style as Home's `WynosTabs`, not a segmented-pill style, for system
consistency.

**Handoff:** Depends on Avatar, Pill Button, Tabs, Post Card (already built in the Home/Nav batch).
Preserve `profiles.cover_url` data dependency exactly as WYN-141 established it.

---

## Screen: Post Detail (route `/drop/[id]`)

**Purpose:** Expanded single-post view with full comment thread.

**User Flow:** Arrive from a feed tap (Home/Profile/Search) → read full post + media → scroll comments/
replies → tap composer to reply → tap an action (Like/Comment focus/Repost/Share/Save).

**Components:** `WynosHeader` (back-chevron + "โพสต์" or similar title — confirm existing copy), expanded
`WynosPostCard` (same visual language as feed card, larger media treatment), comment `WynosListRow` per
comment/reply (avatar + name + timestamp + body + like), reply composer (`WynosInput` variant, existing
46px height per prior WYN-158 parity spec — keep this exact metric, it was Founder-approved), "ดูกิจกรรม"
row (existing 54px height per WYN-158 — keep), Activity sheet (`WynosSheet`).

**Interactions:** Existing threaded comment/reply behavior (expand/collapse replies, pagination) unchanged.
Tap "ดูกิจกรรม" → `WynosSheet` titled "กิจกรรมโพสต์" with exactly two tabs **ถูกใจ** / **รีโพสต์** (no
"ทั้งหมด" tab — this is an explicit existing requirement from the prior parity work, restated here so it
is not lost in the visual migration).

**States:** Same Like/Repost active-color rules as Post Card. Comment composer disabled state while
submitting (existing). Empty comments state (`WynosEmptyState`, "ยังไม่มีความคิดเห็น" or existing copy).

**Required action row (explicit in Founder brief for this screen):** Like, Comment, Repost, Share, Save —
five actions. This is one action more than the current shipped Home Post Card row (which has no Save/
bookmark button per `post-actions.tsx` above) — Save here maps to the existing bookmark feature
(`/bookmarks` route) already in the product; add a bookmark toggle icon to this expanded action row using
the existing bookmark mutation, styled monochrome with an active/filled state on save (no color change on
save — bookmarking isn't a "red" signal, only Like is).

**Responsive Behavior:** Root bottom navigation is hidden on this screen (existing behavior, preserve —
this is a focused/stacked view). Single column at all widths; comments never go multi-column.

**Accessibility:** Reply composer is keyboard-submittable (Enter to send existing behavior, if present).
Each comment row's Like control is independently focusable.

**Design Rules:** Compact caption/link/hashtag treatment with bright-blue interactive text — this is an
explicit carry-over from the Founder's 2026-09-10 final reference (recorded in WYN-141) and predates this
brief; it is a deliberate, Founder-approved exception to "color reserved for Like only" for hyperlinks/
hashtags specifically (link-blue is a near-universal affordance convention, same category as Like-red).
Everything else in Post Detail follows the monochrome system exactly as Post Card.

**Handoff:** Depends on Post Card, Icon Button, Sheet, Input primitives. Preserve the exact five-action
row, the two-tab (not three-tab) Activity sheet, and the 46px/54px metrics called out above — these are
pre-existing Founder-approved requirements, not open for reinterpretation during this visual migration.
