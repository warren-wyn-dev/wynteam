# Design Spec — WYN-141: Frontend UX/UI System Upgrade

Owner: AI Design → Founder review → AI Coding
Status: DESIGN_COMPLETE / APPROVAL_REQUIRED before Coding
Visual preview: `design-reference/23-ux-ui-system-preview.svg`

## Design Direction

Refine the approved WYNOS language; do not replace it. Use Sapphire as the primary accent, paper/ink surfaces, flat bordered containers, restrained radius, system typography, generous whitespace and subtle motion. No gradients, decorative glass, heavy shadows or new accent colors.

## Responsive Shell

| Width | Layout contract |
|---|---|
| 320–599 | Single column, 12–16px edge inset, bottom navigation, full-width sheets |
| 600–839 | Centered primary rail up to 600px; preserve mobile navigation unless a tested adaptive shell is introduced |
| 840–1199 | Centered primary rail up to 680px; optional contextual rail, never empty decorative space |
| ≥1200 | App shell max-width 1180px; primary content 680px; supporting rail up to 320px |

Content detail and forms use a readable max-width. Media may be wider only where the existing surface intentionally makes media the hero.

## Core Primitives

### Buttons

- Primary: Sapphire fill, white label, 48px recommended height.
- Secondary: paper fill, strong border, ink label.
- Tertiary/icon: no container until hover/focus/press; minimum 44×44 target.
- Destructive: danger color only for the destructive choice, never the whole modal.
- Loading keeps button width stable, disables duplicate submission and retains an accessible label.
- Disabled uses reduced emphasis but must remain legible.

### Inputs

- Persistent label; placeholder is an example, never the only label.
- Input and placeholder text remain at least 16px.
- Help text appears before interaction when useful; error replaces help without shifting unrelated layout excessively.
- Focus ring uses the existing Sapphire token and is visible on keyboard navigation.

### Cards and List Rows

- Prefer flat sections/list rows for social content.
- Use bordered cards only for grouped controls, dashboard metrics or distinct bounded objects.
- Whole-row navigation has one semantic tap target; nested actions must not compete with it.
- Skeleton geometry matches final content to minimize layout shift.

### Modal Surfaces

- Mobile: safe-area-aware bottom sheet for short contextual tasks; pushed screen for long/complex flows.
- Desktop: bounded dialog, max-width 520px, focus trapped, Escape/dismiss behavior explicit.
- Destructive dialogs name the object and consequence; primary focus starts on the safe action.

### Loading, Empty and Error

- Initial loading: skeleton for content surfaces; spinner only for compact indeterminate operations.
- Refresh: retain content and show non-blocking progress.
- Empty: icon/illustration placeholder, one clear explanation, one meaningful CTA at most.
- Error: human-readable cause category, retry action and preserved content when possible.
- Offline: state that connectivity is required and expose retry; never loop silently.

## Surface Contracts

### Auth and Onboarding

One primary action per step, visible progress, keyboard-safe CTA, clear recovery for OAuth/email failures and no dead-end guest entry. Preserve existing auth architecture.

### Navigation and Feed

Preserve five-item navigation and current Home post structure. Improve only adaptive width, state consistency, focus/semantics and verified gesture arbitration between tab swipe, carousel swipe, refresh and back navigation.

### Content Detail and Creation

Keep composer actions reachable above the keyboard, stabilize upload progress, make validation local to the offending control and preserve draft/retry paths.

### Search, Discovery and Notifications

Use stable result/filter hierarchy, retain queries across navigation when currently supported, and give empty/error states a specific recovery action. Notification rows maintain a single clear destination.

### Profile and Settings

Use readable centered rails on wide screens; preserve current profile/feed relationship. Group settings by consequence and visually separate destructive/account actions.

### Clubs and Chat

Preserve existing permissions, membership and message business logic. Standardize list density, unread/online indicators, composer states, moderation actions and responsive modal treatment.

### Admin

Use the same semantic principles with denser desktop spacing: persistent sidebar, clear page hierarchy, responsive tables/list fallback, visible filters, deterministic bulk/destructive actions and strong keyboard focus.

## Accessibility Acceptance

- 44px absolute minimum target; 48px recommended.
- No clipping/overflow at 320px or text scale 2.0.
- Meaning is not conveyed by color alone.
- Keyboard focus is visible and follows reading order.
- Icon-only actions have semantic/accessible names.
- Motion uses existing tokens and respects reduced-motion capability where supported.

## Implementation Batches and Gates

Each batch requires: targeted tests → full relevant lint/test → production build where credentials/toolchain permit → regression report. Stop before the next batch on any failure.

1. Tokens/primitives/tests.
2. Auth/navigation shell.
3. Feed/content.
4. Search/notifications/profile/settings.
5. Clubs/chat.
6. Admin.
7. Full responsive/accessibility QA.

No production UI code may start until Founder approves the visual preview. Any approved implementation remains behind developer-account staged rollout when it changes user-visible behavior rather than fixing an existing accessibility/layout defect.

---

## Amendment — Profile as Canonical Reference (2026-09-12)

Founder: "ชอบ UX UI ของเธรด ปรับให้หน่อย ทุกหน้า ยกเว้นโปรไฟล์ จัดดีแล้ว" + "อยากให้ดูโปรไฟล์เป็น แล้วปรับทุกหน้าให้ไปในทิศทางเดียวกัน" (ดู product amendment ที่ `.wyn/tasks/active/WYN-141-frontend-ux-ui-system.md`)

### DS-001 vs this spec — resolved

Confirmed with Founder directly (AskUserQuestion, since `.wyn/company/DECISIONS.md` is corrupted and could not record this): **Sapphire `#1B3A6B` + Threads/X-inspired (this document, `design-reference/`)** is now the governing direction for WYNOS (`app/`), superseding DS-001's Cyan/Orange for this scope. DS-001 is amended with a scope note accordingly; it remains fully in force for `seller_app/` (ZOKY), which this amendment does not touch.

---

### Screen: Post Detail (`07-post-detail.tsx`)

**Purpose:** Bring Post Detail fully in line with Profile's realized final direction — not exempt despite already having its own 2026-09-10 Founder screenshot.

**User Flow:** Unchanged — pushed screen from a post's `⋯`/tap, back via `ChevronLeft`.

**Components:** Already Sapphire/paper-ink token system per its own header comment (`07-post-detail.tsx` lines 17–21) — avatar ring, action bar, comment thread. Re-check specifically against whatever header/avatar/cover treatment Profile's final screenshot establishes (e.g. `profiles.cover_url` cover if the post author's own avatar/identity chrome echoes it anywhere), plus spacing rhythm and type weights.

**Interactions:** Unchanged — double-tap-to-like, comment composer pinned above keyboard, `⋯` overflow menu (Share/Save only, per DESIGN-PHILOSOPHY §5/§4.6).

**States:** Unchanged — loading/empty/error per existing spec.

**Responsive Behavior:** Unchanged — readable max-width on ≥600px per the Responsive Shell table above.

**Accessibility:** Unchanged — 44px targets, focus order, semantic labels.

**Design Rules:** No new tokens. Sapphire-only accent. Compare pixel-for-pixel against Profile's final reference once re-shared — do not treat the existing `.tsx` as sufficient on its own for this pass.

**Handoff:** AI Coding — hold this screen's batch until Founder re-shares the Profile (and, if it affects shared chrome, Post Detail) reference image(s); this is a re-validation pass, not a rewrite.

---

### Screen: Other Profile (`18-other-profile.tsx`)

**Purpose:** Same as above — explicitly not covered by the Profile exemption even though it shares Profile's layout by design (per its own header comment: "Same layout as your own Profile... except the action row swaps...").

**User Flow:** Unchanged — pushed screen from tapping another user's name/avatar; `⋯` adds report/block (own profile doesn't need this).

**Components:** Avatar, identity block, stats, tabs — mirrors Profile's structure already. Re-check against Profile's final screenshot for the same chrome/spacing/cover treatment Profile itself just got; the Follow/Message action row and report/block `⋯` are the only intentional deltas from Profile and should stay.

**Interactions:** Unchanged — Follow/Unfollow toggle, message icon, report/block bottom sheet (DESIGN-PHILOSOPHY §5 "Report/Block" pattern).

**States:** Unchanged.

**Responsive Behavior:** Unchanged.

**Accessibility:** Unchanged.

**Design Rules:** No new tokens. Same Sapphire/paper-ink system as Profile.

**Handoff:** AI Coding — same hold as Post Detail, pending the re-shared reference image(s).

---

### Design Rule: All other in-scope screens (01–04, 06, 08–17, 19–22)

**Purpose:** Apply Profile's direction system-wide without re-litigating each screen individually — these already use the same Sapphire/paper-ink tokens, typography, and component patterns documented in `design-reference/SPEC.md` and `DESIGN-PHILOSOPHY.md`; no screenshot exists for them beyond the `.tsx` references themselves, so those references stand as-is.

**Design Rules:** Coding proceeds batch-by-batch per the existing rollout order in this document and in `wyn-141-frontend-ux-ui-audit.md`, using each numbered `design-reference` file as the spec, with DS-001's Cyan/Orange no longer a valid fallback anywhere in `app/` per the resolution above.

**Handoff:** AI Coding may continue non-Admin batches for these screens without waiting on the screenshot re-share — only Post Detail and Other Profile are gated on it.

### Known Blocker (repeated from product amendment) — RESOLVED 2026-09-12

Founder shared the real Profile screenshot in-session. Saved to `design-reference/founder-screenshots/profile-final-2026-09-12.png` (canonical reference, supersedes conflicting detail in `05-profile.tsx` below). Founder confirmed directly: "ชอบแบบนี้ แบบล่าสุด ตอนนี้เลย" (like this one, the latest, right now).

### Literal breakdown of the real screenshot (ground truth — read this before touching Profile/Post Detail/Other Profile)

This is a screenshot of the **actual running app**, not a mockup — treat every detail below as confirmed unless marked as an open question.

| Area | What the screenshot actually shows | vs. `05-profile.tsx` / `SPEC.md` |
|---|---|---|
| Cover photo | Full-width photo banner above the identity block (user's own uploaded photo) | **New** — confirms the `profiles.cover_url` addition already noted in this task's 2026-09-10 entry. Not a copyright/asset-safety violation (DESIGN-PHILOSOPHY §9 bans *decorative* stock photography as a design element, not user-uploaded content) |
| Header (over cover) | "โปรไฟล์" title top-left, share icon + settings gear top-right, white icons directly on the photo | **New position** — `.tsx` had the gear icon on a plain paper header with no cover to sit over |
| Avatar | Circular, thick white ring, overlaps the bottom edge of the cover (bottom-left aligned, not centered), small green online-status dot bottom-right | **Differs**: ring reads white/bright here vs. the `.tsx`'s thin sapphire-tint ring (could be the same ring reading differently against a photo — flagging as unconfirmed, not asserting a token change). Online-status dot is **new**, undocumented anywhere before this |
| Name row | Name + a small chevron-down next to it | **New, unexplained** — likely an existing account-switcher affordance already in the shipped app. Design position: preserve as existing behavior, don't redesign or remove it; not treating this as a new visual element to replicate elsewhere |
| Stats row | Exactly **2** stats: "กำลังติดตาม" (following) then "ผู้ติดตาม" (followers) — in that order, big number over small gray label | **Differs**: `.tsx` shows 3 stats (ผู้ติดตาม, กำลังติดตาม, โพสต์) in the opposite follower/following order, plus a post count that isn't shown here |
| Primary action | Solid **black** filled pill, pencil icon + "แก้ไขโปรไฟล์" label combined inside the button, spanning most of the row width | **Differs materially** — `05-profile.tsx`'s own comments explicitly call this button "de-emphasized... no longer a full-width bordered button," styled as a small plain-bordered pill. The real screen does the opposite: it's the visually heaviest element in the action row |
| Secondary actions | Two circular **outline** icon buttons (visible border) — person-add/follow-request icon, bookmark icon | **Differs**: `.tsx` used plain borderless icons here |
| Tabs | 3 tabs, each **icon + label**: "สื่อ" (grid icon), "รีโพสต์" (repeat icon), "ถูกใจ" (heart icon) | **Differs from `.tsx`** (text-only "โพสต์/ReDrop/ถูกใจ") but **confirms** the older WYN-071/WYN-013 rule ("tab ทุกอันต้องมี icon+label เสมอ") is still alive in the real app — the `.tsx`'s text-only tabs were apparently never shipped this way. Tab set/labels also don't match WYN-071 Screen 6's proposed 4-tab plan (Posts/Replies/Media/Likes) — the real app's 3 tabs (Media/Repost/Liked) are their own current shape |
| Bottom nav | 5 items, home/search/[+ elevated black circle]/notifications/profile, active tab filled black, inactive outline/gray | Consistent with the existing 5-item nav rule in DESIGN-PHILOSOPHY §6 — the elevated black "+" for Drop is the one new visual detail worth carrying into every other screen's nav |

### Correction to this document's earlier guidance

The "Design Direction" section above (Sapphire as primary accent, restrained radius, flat bordered containers) still holds for **surfaces, typography, and spacing**. It does **not** hold uncorrected for **primary button color**: the real Profile screen uses solid **ink/black** for its primary action, not sapphire. Until Coding/QA confirm otherwise, treat **ink-filled** as the primary button style and reserve sapphire for the same restrained roles DESIGN-PHILOSOPHY §2 already lists (verified badge, active tab underline, hashtags, avatar ring, links) — not as a button fill.

### Open question carried forward (not decided here)

Someone else's profile (`18-other-profile.tsx`) shows a **"ติดตาม" (Follow) button** in the same slot as Edit Profile — the screenshot only covers **own** profile, so it doesn't say whether Follow should also become ink/black-filled (matching this correction) or stay sapphire-filled (as a "positive/affirmative" action distinct from Edit). Not assuming either way — ask Founder or confirm against another real screenshot before Coding implements Other Profile's action row.

### Handoff (updated)

AI Coding may now proceed on Profile using `design-reference/founder-screenshots/profile-final-2026-09-12.png` + the breakdown table above as the spec, superseding the conflicting parts of `05-profile.tsx` listed above. Post Detail and Other Profile still need the Follow-button-color question resolved before their action rows are finalized; their non-action-row content (avatar, post rows, tabs where applicable) can proceed under the same ink/paper/hairline system already confirmed.
