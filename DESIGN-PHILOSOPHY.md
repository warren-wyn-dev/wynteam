# WYNOS — UX/UI Design Philosophy

This document is for designing **any WYNOS screen not already covered** in
this design-reference set. `SPEC.md` gives you exact tokens for the Home
screen; this file gives you the *reasoning* behind every decision made
across the whole app, so a new screen feels like it belongs, even if
nobody explicitly designed it yet.

If you're about to build a screen and it's not in the numbered reference
files (01–22), read this whole document first, then apply it. If something
here still doesn't answer your question, stop and ask rather than guessing.

---

## 1. What WYNOS is, in one sentence

A premium, minimal social feed (Threads/X-inspired, not copied) that will
eventually add commerce — but **commerce is explicitly out of scope right
now**. Don't design shop/product/checkout screens unless directly asked;
that decision was made deliberately partway through this project.

---

## 2. The one rule that generates most of the others

**There is exactly one accent color: sapphire (`#1B3A6B`).** Everything
else is ink, paper, canvas, graphite, faint, or hairline (see `SPEC.md` for
exact hex values). This single constraint is why WYNOS looks calm instead
of like a typical mass-market app (Shopee/Lazada/TikTok-style apps use
saturated color for urgency; WYNOS deliberately does not).

Practical implications:
- Never introduce a second accent color (no red for errors, no green for
  success, no orange for warnings). Express state through weight, opacity,
  or the one accent — not new hues. If a situation genuinely seems to need
  a new color (e.g. a destructive delete-forever action), stop and ask
  first; don't decide unilaterally.
- Discount badges, price tags, urgency banners — if these ever get built —
  must not use red/orange the way Shopee-style apps do. Use sapphire or
  ink-on-tint instead.
- "Verified" badges, active nav indicators, primary buttons, links,
  hashtags, avatar rings — all sapphire. If a new UI element needs to
  signal "this is important" or "this is active," reach for sapphire
  before reaching for anything else.

---

## 3. Typography has exactly two jobs

- **Fraunces (serif)**: display moments only — the "WYNOS" wordmark,
  screen titles in headers, avatar initials, empty-state headlines, rank
  numerals (Top 100). It shows up sparingly, as a signature, not as body
  text.
- **Inter (sans)**: everything else. Every label, button, timestamp, post
  body, input field, helper text.

If you're unsure which to use for a new element: if it's something the
person *reads for meaning* (a sentence, a label, a number they're
scanning), it's Inter. If it's a *brand or identity moment* (a title, a
name-as-monogram, a big standalone numeral), it's Fraunces. When in doubt,
default to Inter — Fraunces overused stops feeling special.

---

## 4. Spacing rhythm

- Page horizontal padding is **24px (`px-6`)**, consistently, on every
  top-level section of every screen. Nothing floats at a different inset.
- Within one logical group of fields/content, spacing is tighter (12–16px)
  than the spacing *between* groups (24px or more). This is how a screen
  reads as "organized into sections" without needing boxes or dividers
  around every group — see Create Club's two-group layout as the
  reference example.
- Grouped lists (Settings, Create Club) use a small uppercase graphite
  label above each group, not a bordered card, unless the content
  specifically benefits from a contained card (see §8).

---

## 5. Components you should reuse, not reinvent

If a new screen needs any of these, copy the *pattern* from where it
already exists rather than designing a new version:

| Need | Reuse from |
|---|---|
| A person's avatar | The ring-avatar pattern (colored circle + thin sapphire-tint ring), used identically everywhere — posts, comments, profile, chat, club members |
| A list of people (with a follow/join button) | Search's suggested-accounts row, or Club's member row — same shape |
| A horizontal image carousel | Home's "peek card" pattern (next card visibly bleeds off the right edge) |
| A segmented toggle (2–3 options) | The pill-with-sliding-white-background pattern from Drop's photo/poll toggle and Create Club's privacy toggle |
| Tabs under a header | The thin sapphire-underline style used on Home, Notifications, Profile, Club — never a filled-pill tab style |
| An empty state | Icon-in-a-soft-tint-circle + Fraunces headline + one supportive Inter sentence (see Home's new-user state, Bookmarks, Notifications, Chat) |
| A disabled primary action | Full-opacity sapphire when actionable, flat `hairline`-colored and `faint`-text when not — never a half-opacity fade |
| A "..." overflow menu | Small anchored dropdown/sheet with 1-2 plain rows (icon + label), not a huge menu |
| Report/Block/destructive confirmation | A bottom sheet sliding up over a dimmed background, not a full pushed screen — these are quick utility actions, not destinations |

---

## 6. Navigation: which pattern for which situation

WYNOS has three navigation patterns. Pick based on the *nature* of the
screen, not habit:

1. **Bottom nav tab** (Home, Search, Drop\*, Notifications, Profile) — for
   the handful of primary destinations someone returns to constantly.
   Adding a 6th tab is almost never the right call; it crowds a
   deliberately minimal bar. (\*Drop is visually a tab icon but behaves
   like a push — see below.)
2. **Pushed screen** (Post Detail, Settings, Chat, Chat Thread, Followers,
   Other Profile, Top 100, Bookmarks, Drop) — for anything you navigate
   *into* and want a clear "back" out of. Hides the bottom nav while
   active. Use a `ChevronLeft` back button, top-left, in a 3-column grid
   header (`40px / 1fr / 40px`) so the title stays perfectly centered and
   never overlaps the back button (this exact bug happened once — see
   Create Club's header fix — don't repeat it with a negative-margin
   hack).
3. **Overlay** (Side Menu drawer, Report/Block bottom sheet, Image
   Viewer) — for something that sits *on top of* whatever's underneath
   rather than replacing it. Side Menu slides from the left with a dimmed
   backdrop; bottom sheets slide from the bottom the same way; Image
   Viewer takes the full screen but is dismissed with a close button, not
   a back button (it's a lightbox, not a destination).

If you're not sure which of the three a new screen should be: ask "does
the person expect a persistent tab, a stack they can back out of, or a
transient thing they'll dismiss and return from where they were?" That
answers it.

---

## 7. Never duplicate the same function in two places

If two entry points would do the exact same thing, remove one. This
happened twice already:
- Home's header used to have both a search icon *and* a bottom-nav search
  tab — the header icon was replaced with Chat instead.
- The logout button existed on both Profile's header and the side menu at
  different points during design — it now lives in exactly one place
  (bottom of Settings).

Before adding an icon/button to a header or menu, check whether the same
action is already reachable elsewhere. If yes, either don't add it, or use
that slot for something that *isn't* already available.

---

## 8. When to use a bordered "card" container vs. loose sections

Default to loose sections (label + content, separated by spacing, no
visible border) — this is most of the app. Reach for an actual bordered
card container only when:
- The content is a self-contained *form* a person fills out in one sitting
  and benefits from feeling like one contained unit (Create Club's fields,
  Edit Profile's fields) — chosen deliberately after comparing card vs.
  loose-section layouts and picking card for compactness.
- It's genuinely a "unit" being previewed (a single Top 100 rank card, an
  image in a carousel).

Don't wrap ordinary content (a feed post, a settings list, a notification
row) in a bordered card — that's not the WYNOS visual language.

---

## 9. Copyright / asset safety

- **Never use real photography, stock images, or screenshots of real
  UI/marketing materials** as design elements (this came up with the Club
  banner, which originally referenced a composited marketing screenshot).
  If a screen seems to need a photo-like visual, build an **original
  abstract graphic** instead (radial gradients, geometric shapes, solid
  brand-color blocks) — see the Club detail banner and Search's rank
  cards for the established approach.
- Never reproduce third-party logos, wordmarks, or trademarked icons
  (e.g. Threads' spinning-@ logo). Inspiration from a competitor's *layout
  pattern* is fine; copying their *brand assets* is not.
- Icons come from Lucide (open-source) exclusively. Don't introduce a
  second icon library.

---

## 10. Content and empty/loading states are not optional

Every list-type screen needs a real empty state (see §5) — not a blank
screen, not a plain gray sentence floating alone. If you're building a
screen that can plausibly have zero items (a new user's feed, an inbox
with no messages, a club with no posts yet), design that state
intentionally as part of the same task, don't leave it for later.

---

## 11. Data model discipline (for engineering, not just visuals)

Everything in this design-reference set uses local component state and
hardcoded mock arrays because these files are visual/behavioral
prototypes, not production code. When implementing for real:
- Keep the app's actual data model, API calls, and backend integration.
  Only borrow the *layout, styling, and interaction logic* from these
  reference files.
- Don't hardcode the sample names/content (WARREN, ZEN, "WYNOS Feedback",
  etc.) into production — those exist purely so the reference files have
  something to render.

---

## 12. If you're designing something genuinely new

For any screen or component not covered by an existing pattern:
1. Check §5 first — is this actually a variation of something that
   already exists?
2. If it's truly new, default to the *simplest, quietest* version:
   ink/paper/graphite text, sapphire only where something is genuinely
   interactive or important, Inter for all text, 24px page padding,
   generous whitespace over dense packing.
3. Write a short comment explaining the design decision (why this layout,
   what it's reusing, what's different) — every reference file in this
   project does this, and it's what lets the next person (human or AI)
   understand intent instead of just copying shapes.
4. If a choice feels like it might need a new color, a new font, a new
   navigation pattern, or anything else not covered above — stop and ask
   rather than deciding alone. That's cheaper than building the wrong
   thing and unwinding it later.
