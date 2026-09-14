# WYN-159 — Create Post (Composer), Clubs, Settings

Tokens/primitives referenced here are defined in `wyn-159-web-v2-design-system.md`.
Existing code referenced: `web/components/beta4-composer.tsx`, `clubs-routes.tsx`,
`club-detail-route.tsx`, `club-detail-golden.tsx`, `club-invite-route.tsx`, `settings-route.tsx`.

---

## Screen: Create Post (Composer)

**Purpose:** Author a new post (text/images/poll) or edit a draft.

**User Flow:** Open via bottom-nav center CTA (`?compose=1`, existing) or "edit draft" entry point →
write text → optionally attach images/camera capture/poll → choose audience → post (or save draft).

**Components:** `WynosHeader` (close "×" + "โพสต์" submit `WynosButton`, or existing copy), `WynosAvatar`
(self), `WynosInput` (large multiline text area variant), audience selector (`WynosPillButton` or sheet —
match existing control type), image/camera/poll attachment icons (`WynosIconButton` row), upload-progress
indicator (existing WYN-094 behavior, restyle only: a slim monochrome progress bar/ring, no colored
gradient), mention/hashtag inline highlighting (existing rich-text behavior, restyle inline link color to
the same blue used in Post Detail captions for consistency).

**Interactions:** All existing composer behaviors unchanged: drafts autosave (WYN-036), audience selection,
text input with mention/hashtag detection, image picker, camera capture, poll builder (WYN-035), image
aspect-ratio handling (WYN-109), upload progress (WYN-094). This is a restyle of an already-complex,
already-correct interaction set — do not touch the underlying state machine.

**States:** Empty/disabled submit until content exists (existing rule). Uploading (progress state,
restyled). Error (existing retry affordance, restyled to monochrome + red for the error text/icon only,
consistent with error-color convention inherited from `design-principles.md`).

**Responsive Behavior:** Full-height sheet/page on mobile; centered modal (`WynosModal` or `WynosSheet`
desktop variant) on wide viewports, same max-width as the rest of the app shell's column.

**Accessibility:** Text area has adequate contrast and is screen-reader labeled; attachment buttons carry
`aria-label`s (existing "แนบรูปภาพ", "ถ่ายภาพ", "สร้างโพล" style labels, preserve exact copy).

**Design Rules:** White background throughout (`--bg`), no card-within-card treatment for attachments —
image previews sit directly in the compose flow with `16px` radius and no extra border, consistent with
the "no unnecessary colored UI, no giant controls" principle. Do not add Check-in or location — explicitly
out of scope per Founder brief.

**Handoff:** Depends on Input, Icon Button, Button, Sheet/Modal primitives. Second-highest interaction
complexity in this project after Chat Conversation — preserve all existing state/validation logic,
restyle only.

---

## Screen: Clubs (Discovery / List / Detail / Create / Invite / Club Post)

**Purpose:** Club discovery, membership, and club-scoped posting.

**User Flow:** Discover clubs (list/search) → view a club's detail (info, members, posts) → join/leave →
create a new club → invite via link/code → view a club post in its own detail view.

**Components:** `WynosHeader`, `WynosListRow` (club discovery rows: club avatar/cover thumbnail + name +
member count + join `WynosPillButton`), `WynosSection` (club detail header: cover, avatar, name, description,
member count, join/leave/manage controls), `WynosTabs` (club detail's own tab set if any — preserve existing),
`WynosPostCard` (club posts reuse the same card, per the brief's "same canonical tokens/components" rule),
`WynosButton` (create-club submit), `WynosInput` (club name/description fields), invite-link display
(existing WYN-136 mechanism, restyle only: monochrome copy-link row with a `WynosIconButton` copy action).

**Interactions:** Existing join/leave (with existing confirmation/undo if present), existing club creation
form validation, existing invite-link generation/redemption (WYN-123, WYN-136, WYN-124 notification tie-in)
— all unchanged. Club poll (WYN-115) and club events (WYN-118) reuse Post Card / List Row primitives rather
than introducing club-specific one-off styles.

**States:** Membership states (not-member/pending-request-for-private-club/member/admin) drive which
controls render — existing conditional logic, unchanged; only the control styling (pill button variants)
changes.

**Responsive Behavior:** Single column at all widths, cover image full column width with `16px` bottom
radius where it meets content (same treatment as Profile cover).

**Accessibility:** Join/leave state changes are announced (existing toast/inline-confirmation pattern,
restyled to a simple monochrome toast, not a colored banner).

**Design Rules:** Club posts visually indistinguishable in structure from Home feed posts (same
`WynosPostCard`) — the brief's "all must use the same canonical tokens/components" applies most literally
here, since Clubs previously had its own bespoke CSS (`club-detail-golden.css`, `club-audit.css`,
`club-post-card-web.css`) that this migration retires entirely.

**Handoff:** Depends on List Row, Section, Tabs, Post Card, Button, Input primitives — build after Post
Card/Profile since Clubs reuses both extensively. Retire all `club-*` legacy CSS files in this batch.

---

## Screen: Settings

**Purpose:** Account, privacy, notification, and data-rights controls.

**User Flow:** Open from Home menu or Profile → scroll grouped sections → tap a row → either toggle inline
(switch) or navigate to a sub-page (existing WYN-044/WYN-045/WYN-047 sub-flows) → sign out.

**Components:** `WynosSection` (grouped list with a small uppercase or muted-gray group label, per the
brief's "simple native-feeling list rows" instruction), `WynosListRow` (icon + label + optional trailing
control: chevron for navigation, switch for inline toggle, value text for current selection), version
footer text (existing "V1.0.0 Beta4" style footer, preserve exact copy/format).

**Interactions:** All existing settings behaviors (privacy controls WYN-045, notification settings
WYN-044, data rights/export WYN-047, platform documents acceptance WYN-046, sign-out) unchanged —
restyle rows only.

**States:** Toggle on/off (existing), destructive action confirm (sign-out, account deletion if present) —
`WynosModal` confirmation, red only on the destructive action label/button, not the whole modal.

**Responsive Behavior:** Single column list, same max-width column as rest of app. No oversized cards —
this is explicit in the brief ("Create simple native-feeling list rows... No oversized cards").

**Accessibility:** Switch controls are real `<button role="switch" aria-checked>` or native `<input
type="checkbox">` semantics (whichever the existing implementation already uses — verify and preserve,
only restyle visually). Consistent row height for predictable screen-reader/keyboard navigation.

**Design Rules:** White background, hairline dividers between rows within a section, slightly larger gap
between section groups (use the `24px`/`32px` spacing tokens) rather than a bordered box per section —
matches "no oversized cards" instruction directly.

**Handoff:** Depends on Section, List Row, Modal primitives. Lowest interaction-complexity screen in this
project — good candidate to parallelize with Clubs if two implementation passes are running, since neither
depends on the other beyond shared primitives already built earlier in the batch order.
