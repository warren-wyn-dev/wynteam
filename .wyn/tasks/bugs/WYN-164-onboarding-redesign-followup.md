# Bug Report — WYN-164

Status: closed (AI QA & Security ยืนยัน PASS รอบ 2 แล้ว 2026-09-19 — ดูรายละเอียดที่
`.wyn/tasks/approved/WYN-163-onboarding-button-redesign.md`)
Owner: AI Debug Engineer → AI QA & Security (**verified PASS**)
Parent: WYN-163 (`.wyn/tasks/qa/WYN-163-onboarding-button-redesign.md`)

## Bug

QA testing of WYN-163 (Apple-style squircle redesign of the 6 WYNOS Web onboarding screens) found the
implementation functionally correct on all approved screens, but **2 findings** that mean the work isn't
fully consistent yet — QA round 1 is a **FAIL** pending these:

### 1. [MEDIUM] `/account/add` ("เพิ่มบัญชี") silently inherited the new button/input styling, but not the
   rest of the redesign — now visually inconsistent

`AccountAddRoute` (`web/components/account-add-route.tsx`, route `/account/add`, the "add another account"
flow used by the account switcher) reuses the exact same shared classes as the 6 WYN-163 screens
(`.auth-ref-viewport`, `.phone`, `.field`, `.btn-primary`, `.btn-outline` — all declared in
`web/app/auth-reference.css`). This screen was **not** in WYN-163's approved scope
(`.wyn/docs/design/wyn-163-onboarding-button-redesign.md` § Screen lists only the 6 `(auth-flow)` routes),
but because the CSS is shared infrastructure, it received the new squircle buttons (58px tall, 24px radius)
and inputs (56px tall, 18px radius) as an unreviewed side effect — while its headline stayed at the old
20px/700 size and its "เข้าสู่ระบบด้วย Google" button stayed plain text (no icon), because those two changes
were applied file-by-file inside `screens.tsx` only, which this screen doesn't use.

Net result: `/account/add` now looks like an unfinished hybrid — big, confident, tactile buttons next to a
small old-style header and a Google button with no logo, right after the rest of the auth flow shipped with
both. See screenshot evidence below.

### 2. [MEDIUM] Welcome screen headline wraps mid-word on a 320px-wide viewport

The Welcome tagline "ทุกเรื่องราว มีจุดเริ่มต้น" was bumped from 17px to 32px per the approved spec. At the
primary target widths (390px, 430px) it fits on one line exactly as in the Founder-approved mockup. At
**320px** (e.g. iPhone SE 1st-gen, some older/smaller Android phones — explicitly part of WYN's standard
320/360/390/430 test matrix per `.wyn/docs/design/ds-008-responsive-accessibility.md`) it wraps onto 2
lines, splitting "จุดเริ่มต้น" awkwardly. This was flagged as a risk to check in the WYN-163 spec's
Accessibility section and is confirmed real at this one width. Not an overflow/clipping bug — text stays
fully visible and legible, just an unpolished line break.

## Reproduction

Environment: local `npm run dev` (Next.js 16.3.5, Turbopack), Chromium via Playwright
(`/opt/pw-browsers/chromium`), commit `16d3ccaa` (WYN-163 implementation).

1. `cd web && npm run dev`
2. Finding 1: open `http://localhost:3000/account/add` at 390×844 — compare against `http://localhost:3000/welcome`
   at the same viewport. Buttons/inputs are visibly the new bigger squircle style; headline "เพิ่มบัญชี" and
   the Google button are still the old style.
3. Finding 2: open `http://localhost:3000/welcome` at **320×844** specifically (not 390+) — the headline
   wraps to 2 lines, splitting "จุดเริ่มต้น".

## Root Cause

1. `web/app/auth-reference.css` is shared between the 6 in-scope onboarding screens and `/account/add`,
   which nobody had noticed shares the same viewport/button/field classes — the WYN-163 spec's screen
   inventory (`web/components/auth-flow/screens.tsx`) didn't include `web/components/account-add-route.tsx`
   at all, so AI Coding never checked for other consumers of the same CSS file before editing it.
2. The 32px headline size was chosen and mocked up against 390px-wide artboards only; nobody rendered the
   approved mockup at 320px before implementing, so the wrap wasn't caught until real-browser QA.

## Fix

Two independent small fixes, both within WYN-163's own spirit ("smallest safe change", no new scope):

1. Finish `/account/add` to match: bump its headline to the same `32px / 800 / letter-spacing -0.02em`
   treatment, and add the same `GoogleGlyph` icon (already defined in `screens.tsx` — either export it and
   reuse, or duplicate the small inline SVG into `account-add-route.tsx`) to its "เข้าสู่ระบบด้วย Google"
   button, using the same `leadingIcon` pattern. This is the recommended fix — it's a 3rd-party account
   switching entry point that deserves the same "look like WYNOS, not a generic form" treatment the Founder
   asked for, not a special case to carve out.
2. Prevent the mid-word wrap at 320px on the Welcome tagline specifically (not the other 5 short one-word
   headlines, which don't hit this). Simplest safe option: reduce the Welcome tagline's `letterSpacing`
   slightly or shrink its font-size a notch (e.g. 28px) only for that one `<p>` — it's the one headline in
   the set that's a full sentence rather than a 1-2 word title, so it doesn't have to share the exact same
   32px value as the others if that's what it takes to fit 320px cleanly. Re-check against the approved
   mockup/Founder before finalizing the exact number, since it's a visible size choice, not just a bugfix
   value.

## Files Changed

Expected: `web/components/account-add-route.tsx`, possibly `web/components/auth-flow/screens.tsx` (to
export `GoogleGlyph` for reuse instead of duplicating it), `web/app/auth-reference.css` (only if the
tagline fix needs a dedicated class instead of an inline style).

## Tests

After fixing: re-run `npm run typecheck && npm run lint && npm run build`, re-screenshot `/account/add` and
`/welcome` at 320/360/390/430px, and re-run `web/tests/browser/auth-reference-flow.spec.ts`. Consider adding
a regression assertion for the 320px Welcome headline (e.g. assert it renders within N px of height / stays
readable) so this doesn't silently regress again.

## Regression Risk

Low — both fixes are additive/cosmetic (an icon + a font-size tweak on one paragraph), touching only the
2 files already in play. No business logic, auth flow, or navigation changes.

## Handoff to QA

Once fixed, re-request AI QA & Security on WYN-163/WYN-164 together — re-verify both findings resolved,
re-run the full functional/regression pass done in QA round 1 (documented in
`.wyn/tasks/qa/WYN-163-onboarding-button-redesign.md`) to confirm nothing else regressed.

---

## Resolution (2026-09-19, AI Debug Engineer)

Both fixes implemented exactly as recommended above (option 1 for each), commit `a657e7bc`:

1. Exported `GoogleGlyph` from `screens.tsx`, imported it into `account-add-route.tsx`, wired it as
   `leadingIcon` on the Google button (same pattern as `WelcomeScreen`), and bumped the "เพิ่มบัญชี" headline
   to `32px / 800 / letter-spacing -0.02em` to match the other 6 screens.
2. Reduced the Welcome tagline specifically from `32px` to `28px` (only that one `<p>` — every other
   headline in the set is a short 1-2 word title and doesn't wrap, so they stay at 32px).

**Verification**: `npm run typecheck` / `npm run lint` / `npm run build` all clean (0 errors, same 3
pre-existing unrelated warnings as before). Manual Playwright verification against a live dev server
(`/opt/pw-browsers/chromium`, since this sandbox's `@playwright/test`-managed browser binaries aren't
installed — same pre-existing gap noted in WYN-163's Coding/QA rounds):
- `/welcome` at 320px: tagline renders as a single line (44px tall vs the ~102px/2-line wrap before)
- `/account/add` at 390px: primary button now `58px`/`24px` radius (already was — untouched), Google button
  now has the icon (`svg` count 1), headline now `32px`
- Re-swept all 7 screens (6 onboarding + `/account/add`) at 390px: correct text, 0 console errors, Welcome
  button order and geometry from WYN-163 unchanged (`58px`/`24px` primary, order
  สร้างบัญชีใหม่→เข้าสู่ระบบ→Google)

Added 2 regression tests to `web/tests/browser/auth-reference-flow.spec.ts` (`welcome headline stays on one
line at 320px`, `account/add matches the shared squircle button treatment and has a Google icon`) — their
assertions were verified by hand against the same real running app; the project's own Playwright test
runner still can't execute in this sandbox (missing `chromium_headless_shell` binary for the
`chromium-desktop`/`chromium-android`/`webkit-iphone` projects, a pre-existing environment gap unrelated to
this change) — needs a real CI/dev-machine run to execute the `.spec.ts` file itself.

**Lessons recorded**: `.wyn/learning/LESSONS_LEARNED.md`, `.wyn/learning/MISTAKES.md` (2026-09-19 entries).

Handing back to **AI QA & Security** for round 2.
