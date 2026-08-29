# WYNOS Home Feed — Design & Implementation Spec

**Reference implementation:** `wynos-home-full.jsx` (attach both files together — this
document explains *why* and *exact values*, the `.jsx` is the executable source of truth)

**Purpose of this document:** every value below is copied directly from the working
reference file, not estimated. If a number here ever disagrees with the `.jsx`, the
`.jsx` wins — but they should never disagree if implemented correctly.

---

## 0. Non-negotiables

- Do not introduce any color not listed in Section 1.
- Do not swap fonts. Only two font families exist in this design, ever.
- Do not add drop shadows, gradients, or borders that aren't specified below.
- Every spacing value is in Tailwind units or exact px — use the exact number given,
  not "close enough."
- If something in the app's real data model doesn't match the mock data in Section 8,
  keep the app's real data and real logic — only styling and interaction patterns
  described here should change.

---

## 1. Design Tokens (color)

| Token name  | Hex value  | Used for |
|---|---|---|
| `ink`       | `#12120F` | Primary text, icons at full strength, banner background, active nav |
| `paper`     | `#FAF9F6` | Page background, card background, text-on-dark |
| `canvas`    | `#EDEBE5` | Outer device bezel background only (not part of the app UI itself) |
| `graphite`  | `#8A8880` | Secondary text, inactive icons, metadata |
| `faint`     | `#C7C4BC` | Tertiary text (view counts, disabled states, footer text) |
| `hairline`  | `#E8E6E0` | All dividers, all 1px borders |
| `sapphire`  | `#1B3A6B` | The **one** accent color. Used for: avatar ring, active tab underline,
    hashtags, verified badge fill, primary buttons (follow, new-posts pill), liked-heart fill |

Sapphire is used with alpha in two places only:
- Avatar ring: `#1B3A6B33` (20% opacity) as a 1px border
- Nothing else gets an alpha value. Do not invent new tints.

**Rule:** if you feel like you need a new color for something (a warning, a discount
badge, an error state), come back and ask — don't default to red/green/orange. Prefer
expressing state through weight, opacity of ink/graphite, or the single sapphire
accent before reaching for a new hue.

---

## 2. Typography

Two font families only:

| Role | Family | Where |
|---|---|---|
| Display | `Fraunces` (serif), weight 500 | The "WYNOS" wordmark in the header, and large headline text in empty states. Nowhere else. |
| Body/UI | `Inter` (sans-serif), weights 400/500/600/700 | Every other piece of text in the app: names, timestamps, post body, buttons, labels |

Font import (if not already handled by your build):
```
@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
```

### Type scale actually used (do not invent sizes outside this list)

| Size (px) | Weight | Used for |
|---|---|---|
| 20 | 500 (Fraunces) | Empty-state headline |
| 19 | 500 (Fraunces), letter-spacing 0.06em | "WYNOS" wordmark in header |
| 14.5 | 600 (Inter) | Post author name |
| 14.5 | 400 (Inter), leading-relaxed | Post body text |
| 14 | 600 (Inter) | Suggested-follow name |
| 13.5 | 400/600 (Inter) | Filter tab labels |
| 13.5 | 500 (Inter) | Hashtags |
| 13 | 600 (Inter) | Banner headline |
| 13 | 400 (Inter) | Menu item labels ("แชร์", "บันทึก"), empty-state subtext |
| 12.5 | 600/400 (Inter) | New-posts pill, reply preview name+text, follow button |
| 12 | 400 (Inter) | Timestamp, "liked by" text, handle text |
| 11.5 | 400 (Inter) | ReDrop attribution line |

---

## 3. Spacing & layout constants

- Screen frame: `max-width: 390px`, `height: 844px` (iPhone-standard mock frame),
  `border-radius: 44px`
- Horizontal page padding throughout: `px-6` (24px) on every section — header, banner,
  tabs, posts, empty state. This is the single most important consistency rule: **every
  top-level section shares the same 24px left/right padding.** Nothing is flush to the
  edge except images inside the carousel (which intentionally bleed to the right edge).
- Post vertical padding: `pt-4 pb-4` (16px top, 16px bottom) per post
- Divider between posts: `1px solid hairline`, no divider after the last post
- Gap between avatar and post content: `gap-3.5` (14px)
- Gap between action-bar icons: `gap-5` (20px) between icon groups, `gap-1.5` (6px)
  between an icon and its own count label
- Avatar ring: outer circle = inner circle size + 6px, ring is `1px solid #1B3A6B33`,
  positioned absolutely around the avatar, not affecting layout size

---

## 4. Component-by-component spec

### 4.1 Header
- Row: hamburger menu icon (left) — "WYNOS" wordmark (center) — search icon (right)
- Icons: 20px (menu), 19px (search), stroke-width 1.4, color `ink`
- Wordmark: Fraunces 500, 19px, letter-spacing 0.06em, color `ink`
- No border under the header itself — the visual separation comes from the banner/tabs
  below it, not a line here

### 4.2 First-time explainer banner
- **Trigger:** shown by default; permanently dismissed after the user taps the X once
  (persist this as a boolean per-user in real storage — not per-session)
- **Container:** rounded-2xl (16px radius), background `ink` (#12120F), padding
  `px-4 py-3.5` (16px horizontal, 14px vertical)
- **Content:** two lines of text, left-aligned, stacked
  - Line 1 (bold, 13px, white/paper): the value-prop hook, e.g. "ดู → แชร์ → ค้นพบ → ซื้อ"
  - Line 2 (regular, 12px, graphite): one-sentence explanation
- **Dismiss control:** an `X` icon, 15px, stroke-width 1.8, color graphite, top-right of
  the banner, vertically aligned with the first line of text (`mt-0.5` offset)
- **Page padding:** wrapped in `px-6 pt-3 pb-1` same as everything else

### 4.3 Filter tabs (sticky)
- **Behavior:** `position: sticky; top: 0; z-index: 20` relative to the scrolling feed
  container — this row (and the new-posts pill directly below it, if visible) must
  remain pinned to the top of the viewport while the feed scrolls underneath it
- **Background:** must be opaque `paper` (#FAF9F6) — never transparent, or post content
  will show through underneath it while scrolling
- Four tabs: "สำหรับคุณ", "ติดตาม", "ล่าสุด", "จาก Club"
- Tab spacing: `mr-6` (24px) between tabs, vertical padding `py-3` (12px)
- **Active tab:** text weight 600, color `ink`; a 2px-tall sapphire underline spans the
  full width of that tab's label, positioned 1px below the text baseline
- **Inactive tab:** text weight 400, color `faint` (#C7C4BC)
- Bottom border of the whole tab row: `1px solid hairline`

### 4.4 New-posts indicator pill
- **Trigger:** appears when the client detects new posts are available at the top of
  the feed (via websocket/poll — implement per your existing real-time infra). Do **not**
  silently prepend new posts on refresh; always surface this pill first and let the
  user choose to load them.
- **Behavior:** tapping it scrolls to top and reveals the new posts (in this mock, it
  simply dismisses — wire up the real scroll-to-top + prepend in production)
- Sits directly under the sticky tab row, and is *itself* part of the sticky block (see
  4.3) — it should not scroll away independently from the tabs
- **Style:** centered pill button, background `sapphire`, `box-shadow: 0 4px 14px
  rgba(27,58,107,0.3)`, padding `px-4 py-2`, rounded-full
- **Content:** an upward arrow icon (13px, stroke-width 2.2, white) + text "มีโพสต์ใหม่ {N} โพสต์"
  in white, 12.5px, weight 600
- Container row background: `paper`, padding `py-2.5`

### 4.5 Empty state (new user / nothing followed)
- **Trigger condition:** the "สำหรับคุณ" or "ติดตาม" tab has zero posts to show because
  the account follows no one yet. This is a real, expected state for every new signup
  — it must never be an unstyled blank screen.
- **Layout:** centered headline block, then a vertical list of suggested accounts
- **Headline:** Fraunces 500, 20px, color `ink`: "ยังไม่มีอะไรให้ดูตรงนี้"
- **Subtext:** Inter 400, 13px, color `graphite`, `mt-1.5`: one supportive sentence
  telling the user exactly what to do next (not just "no content")
- **Suggested account row:** avatar (38px) + name (14px, weight 600) + verified badge
  if applicable + handle (12px, graphite) on the left; a `ติดตาม` (Follow) button on the
  right
- **Follow button:** outline style, `1px solid sapphire`, text color sapphire, 12.5px
  weight 600, rounded-full, `px-4 py-1.5`
- **List spacing:** `space-y-4` (16px) between suggested rows

### 4.6 Post — structure top to bottom
1. **ReDrop attribution** (optional, only if this post is a repost): small repost icon
   (12px) + "ReDrop โดย {handle}" in 11.5px graphite, `mb-2.5`, indented `ml-1`
2. **Avatar** (left column, 40px + ring) next to the content column
3. **Header row:** name (14.5px weight 600 ink) + verified badge if applicable (14px
   sapphire-filled check, no border) + timestamp (12px graphite) on the left; a
   `⋯` more-options icon (16px, faint) on the right that opens a dropdown menu
4. **More-options dropdown:** appears anchored top-right of the post, `absolute right-0
   top-6`, white/paper background, `1px solid hairline`, `box-shadow: 0 8px 24px
   rgba(18,18,15,0.12)`, rounded-xl, min-width 148px. Contains exactly two rows:
   - "แชร์" (Share) with a share icon
   - "บันทึก" (Save/Bookmark) with a bookmark icon
   Each row is a full-width tappable button, `px-4 py-3`, a hairline divider between
   the two rows only (not after the last one)

   **This is where Share and Bookmark live now — they are intentionally NOT in the
   main action bar (see 4.9). This was a deliberate simplification: the action bar
   only holds the four most-used, most-glanced-at metrics (like, comment, repost,
   view); share/save are lower-frequency actions that belong one tap deeper.**
5. **Post body:** one `<p>` per line in the original content, 14.5px, ink, leading-relaxed,
   `space-y-2` between lines (8px gap) — do not collapse multi-paragraph posts into a
   single flowed paragraph; preserve the line breaks as separate paragraph elements
6. **Hashtags** (optional): rendered as plain inline text (not pill/chip shaped),
   13.5px, weight 500, color sapphire — this is intentional, hashtags read as branded
   text, not as buttons
7. **Image carousel** (optional, see 4.7)
8. **Liked-by row** (see 4.8)
9. **Action bar** (see 4.9)
10. **Top reply preview** (optional, see 4.10)

### 4.7 Image carousel (peek-card style)
- **Trigger:** rendered only when a post has an `images` array
- **Scroll container:** horizontal, `overflow-x-auto`, `scroll-snap-type: x mandatory`,
  scrollbar hidden. Critically: the container has a **negative right margin equal to
  the page's own right padding** (`-mr-6 pr-6`) so that the *last visible* card can
  bleed past the normal 24px content edge — this is what produces the "next card
  peeking" effect from the reference screenshot.
- **Each card:** width `82%` of the container, `aspect-ratio: 4 / 5`, `border-radius:
  16px` (rounded-2xl), `scroll-snap-align: start`
- **Gap between cards:** `gap-2` (8px)
- **Double-tap-to-like:**
  - Track the timestamp of the last tap in a ref (not state, to avoid re-render on
    every single tap)
  - If a second tap lands within **300ms** of the previous tap, treat it as a
    double-tap: fire the like action AND trigger the heart-burst animation
  - Do not fire on the first tap of a pair — a single tap on the carousel should not
    like the post (that would break normal browsing taps/scrolls)
- **Heart-burst animation:**
  - A single large heart icon (72px, filled paper/white, no stroke), centered
    absolutely over the carousel, `pointer-events: none` so it never blocks input
  - `filter: drop-shadow(0 4px 16px rgba(0,0,0,0.3))` so it's visible against any image
  - Animation keyframes (700ms total, ease-out):
    ```
    0%   { transform: scale(0.4); opacity: 0; }
    25%  { transform: scale(1.15); opacity: 1; }
    40%  { transform: scale(1); opacity: 1; }
    100% { transform: scale(1); opacity: 0; }
    ```
  - Remove the heart element from the DOM (or set display:none) after 700ms — don't
    leave an invisible-but-present node sitting on top of the carousel

### 4.8 Liked-by row
- **Trigger:** hidden entirely if total like count is 0 — do not render an empty "Liked
  by" row
- Shows up to the **first 3** likers as small overlapping circular avatars, then text
- **Mini-avatar:** 18px diameter, `1.5px solid paper` border (so they visually separate
  from each other when overlapping), each offset horizontally by `12px` from the
  previous one (so they overlap by 6px), letter centered, 9px Inter weight 700 white text
- **Text:** "ถูกใจโดย **{first name}**" (first name in bold ink) then, only if there are
  more than the 3 shown, " และอีก {N} คน" appended in regular graphite weight
- This exists specifically so likes read as *people you might know*, not an anonymous
  counter — do not replace this with a plain number anywhere in the product.

### 4.9 Action bar
Exactly four elements, in this order, evenly using `gap-5` (20px) between them:

| Icon | Size | Behavior |
|---|---|---|
| Heart | 17px, stroke 1.4 | Tappable. Toggles liked state. When liked: icon fills solid sapphire, count increments by 1 locally (optimistic update), icon+count color becomes sapphire. When not liked: outline only, color graphite. |
| Comment bubble | 17px, stroke 1.4 | Tappable, navigates to the comment thread. Color always graphite (no "active" state needed here). |
| Repost/repeat | 17px, stroke 1.4 | Tappable, opens repost/ReDrop options. Color always graphite. |
| Eye (view count) | 16px, stroke 1.4 | **Not tappable** — display-only. Color `faint`, one shade lighter than the other three, since it's informational rather than an action. |

Share and Bookmark are **not** in this row (moved to the `⋯` menu, see 4.6). Do not
add them back here even if it looks sparse — that sparseness is intentional restraint.

### 4.10 Top reply preview
- **Trigger:** only if the post has at least one reply worth surfacing (in production:
  typically the highest-engagement reply). If there are zero replies, render nothing —
  do not show an empty comment prompt here.
- **Layout:** a short vertical connector line (`1px`, hairline color, in a 24px-wide
  gutter) visually linking down from the avatar column above, then the reply content
  indented to align with the post body's left edge (not the avatar's left edge)
- **Content:** replier's name (12.5px weight 600 ink) followed inline by their comment
  text (12.5px, regular, a slightly muted ink-adjacent tone `#5A5850` — deliberately not
  full `graphite` and not full `ink`, since this is quieter than the post author's name
  but still needs to be legible body text)
- This is a preview only — tapping it should navigate to the full comment thread, it
  is not an inline reply composer

---

## 5. Interaction & state summary (for engineering)

| State | Trigger | Persistence |
|---|---|---|
| Banner dismissed | User taps X on explainer banner | Persist per-account, permanently (not per-session) |
| Post liked | Tap heart icon OR double-tap image carousel | Sync to backend; optimistic UI update immediately, roll back on failure |
| More-options menu open | Tap `⋯` | Local UI state only, closes on outside tap or on selecting an option |
| New-posts pill visible | Backend signals new posts exist at top of feed | Cleared when user taps the pill (which should scroll-to-top and merge the new posts in) |
| Empty state shown | User's relevant tab (สำหรับคุณ/ติดตาม) has zero followable content | Real condition — not a mock toggle. (The "ดูตัวอย่าง: ผู้ใช้ใหม่" button in the reference file is a **demo-only affordance** to preview this state; it must not ship in the real app.) |

---

## 6. Explicitly out of scope for this spec

- Anything related to a shop/store/product/checkout experience — this spec covers the
  **social feed only**, per direction to hold off on commerce screens for now.
- Bottom navigation bar styling — not shown in the reference file; use existing nav
  styling until a matching spec is provided.
- Any color, spacing, or component not explicitly named above. If you're improvising,
  stop and ask rather than guessing from "vibe."

---

## 7. How to implement without drifting from this spec

1. Extract Section 1 and 2 into your actual theme/tokens file (Tailwind config, CSS
   variables, or design-token JSON — whatever the codebase already uses). These should
   become named tokens (`color-ink`, `color-sapphire`, etc.), not repeated hex strings
   scattered through components.
2. Build components in the order listed in Section 4 (4.1 → 4.10), checking each one
   against this doc and the `.jsx` reference before moving to the next.
3. For anything stateful (Section 5), wire it to real data/backend calls — the
   reference file uses local `useState` purely because it's a static mock.
4. After implementation, do a side-by-side pass: open the reference `.jsx` in a browser
   preview next to the real app screen, and check every token in Section 1 and every
   size in Section 2 pixel-for-pixel.

---

## 8. Mock data used in the reference (for QA / visual comparison only)

This is the placeholder content used to build and preview the design. **Do not treat
this as real content requirements** — your actual feed data model stays as-is; this
section exists only so a reviewer comparing the live app to the reference screenshots
knows which text/values were arbitrary mock content vs. structural requirements.

- 3 sample posts (WARREN with a ReDrop + hashtags, ZEN with a single short line, WYNOS
  verified account with a 3-image carousel)
- 4 sample "suggested to follow" accounts for the empty state
- Like counts, view counts, and reply text are all placeholder numbers/strings
