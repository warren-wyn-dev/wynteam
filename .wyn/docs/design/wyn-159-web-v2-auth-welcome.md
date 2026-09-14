# WYN-159 — Welcome/Auth and Remaining Screens (Migration Batch 14)

Tokens/primitives referenced here are defined in `wyn-159-web-v2-design-system.md`.
Existing code referenced: `web/components/parity-auth-entry.tsx`, `parity-email-auth.tsx`,
`parity-invite-code.tsx`, `web/app/parity-auth-email.css`.

---

## Screen: Welcome / Auth

**Purpose:** First-run entry point — sign in or create an account.

**User Flow:** Land on `/` while signed out → see WYNOS wordmark/mark + tagline → choose Google or email
auth → (email path) enter email → password or OTP per existing flow → (new account) existing invitation/
sign-up flow (WYN-002) → land on Home.

**Components:** `WynosAppShell` (auth variant — no header/bottom-nav chrome), brand mark (same SVG wordmark
mark as the Header's Home variant, larger), `WynosButton` (primary — "เข้าสู่ระบบด้วย Google" style, existing
copy), text/pill divider ("หรือ"), `WynosInput` (email), `WynosButton` (secondary/outline — email continue),
existing invite-code entry component (`parity-invite-code.tsx` logic, restyle only).

**Interactions:** Existing Google account-chooser behavior (WYN-158 restoration notes: "Google account
chooser behavior" must keep working exactly), existing email sign-up/sign-in and invitation flow — this
batch is styling-only, no auth-flow logic changes (auth architecture changes require separate Founder
approval per AGENTS.md Change Control — out of scope here regardless).

**States:** Loading (during OAuth redirect/session check), validation error (existing inline error text,
red per error convention), invite-required gate if applicable (existing).

**Responsive Behavior:** Centered content column on all viewports (this screen has no persistent nav, so
the max-width column can be narrower than the app shell's normal content width if that reads better —
e.g. 400–440px centered — confirm visually during implementation rather than forcing the same width as
Home).

**Accessibility:** Form inputs properly labeled, error messages associated via `aria-describedby` if not
already, Google button uses Google's official asset/copy requirements (existing constraint from
`design-principles.md`, still binding — brand-partner buttons are not part of "our" visual system to
restyle).

**Design Rules:** White background, monochrome wordmark, no color except the same link-blue (for "เงื่อนไข
การใช้งาน"/terms links, WYN-046) and error-red conventions used everywhere else in the system. This is the
one screen where the reference provides zero direct visual guidance (it has no auth mockup) — extrapolate
from the token system rather than inventing new colors/decoration.

**Handoff:** Lowest priority in the batch order (explicitly last, "remaining screens"). Preserve the exact
existing auth logic; this is pure restyle.

---

## Remaining Screens (grouped, lower individual complexity)

For each of the following, the same pattern applies: reuse the primitives already built in earlier
batches (`WynosHeader`, `WynosListRow`, `WynosAvatar`, `WynosPostCard`, `WynosPillButton`), preserve all
existing behavior/data flow exactly, remove the surface's legacy CSS file(s) once migrated.

- **Followers / Following lists** (`/profile/[id]/followers`, `/following`): `WynosListRow` per user
  (avatar + name + Follow pill), same list treatment as Search results.
- **Public profile via slug** (`/[profileSlug]`): identical to Profile screen spec above — same component,
  different resolution path (existing `profile-slug-resolver.tsx` logic unchanged).
- **Bookmarks** (`/bookmarks`): `WynosPostCard` list, identical to Home feed list treatment, no separate
  visual spec needed beyond "it's a filtered feed."
- **Club Invite** (`/club-invite/[code]`): centered single-action screen (club preview card + join
  `WynosButton`), same pattern as Welcome/Auth's centered-column treatment.

**Handoff:** These can be migrated in any order relative to each other once their shared primitives exist;
none introduces a new primitive beyond what's already specified.
