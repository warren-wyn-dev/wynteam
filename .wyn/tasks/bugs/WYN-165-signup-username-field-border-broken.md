# Bug Report — WYN-165

Status: closed (AI QA & Security ยืนยัน PASS แล้ว 2026-09-19 — ดูรายละเอียดที่ท้ายไฟล์)
Owner: AI Deploy & DevOps
Parent: WYN-163 (`.wyn/tasks/approved/WYN-163-onboarding-button-redesign.md`), live production regression
reported directly by Founder after the WYN-163/164 deploy.

## Bug

Founder reported on real production (`wynos.online`, real iPhone, Signup Step 1 screen — "ชื่อผู้ใช้ ทำไม
ช่องหาย"): the "ชื่อผู้ใช้" (username) input field's border renders broken/incomplete — top and bottom border
lines mostly missing — while the other two fields on the same screen ("ชื่อที่แสดง", "วันเกิด") render as
complete, clean rounded rectangles.

## Reproduction

Environment: local `npm run dev` (Next.js 16.3.5, Turbopack), Chromium via `playwright-core`
(`/opt/pw-browsers/chromium`, executablePath override — this sandbox's `@playwright/test`-managed browser
binaries are still not installed, same pre-existing gap as WYN-163/164).

1. `cd web && npm run dev`
2. Open `http://localhost:3000/signup/step-1` at 390×844 (also reproduces at 320/360/430).
3. Screenshot confirms: the username field's box is missing its top and bottom border lines across most of
   its width — only small corner stubs remain near the left edge (under the "@" symbol). The other two
   fields render as complete rounded rectangles. Matches the Founder's screenshot exactly.

## Root Cause

Confirmed via `getComputedStyle`/`getBoundingClientRect` inspection (not guessed):

`SignupStep1Screen`'s username field wraps `<Input bare>` in a manually-styled `<div>`
(`web/components/auth-flow/screens.tsx`, was lines 393-396) that independently sets its own
`border: 1px solid var(--border-strong)`, `borderRadius: 18`, `padding: "0 18px"`, `height: 56`.

`Input` (`web/components/ui/input.tsx`) always applies `className="wyn-input"` to the underlying `<input>`
**regardless of the `bare` prop**. The shared descendant selector
`.auth-ref-viewport .field .wyn-input` (`web/app/auth-reference.css`) still matches this nested input (a
descendant selector doesn't care about the extra wrapper `<div>` in between), applying `height: 56px` and an
opaque `background: var(--bg)` (white) to the input itself — on top of the wrapper div's own identical
`height: 56` styling.

The wrapper div is `box-sizing: border-box` (via the global `.auth-ref-viewport *` rule) with a 1px border,
so its actual **content box** is only 54px tall (56 − 2×1px border), not 56px. The input, as a
`display:flex; align-items:center` child, is forced to its CSS-specified 56px height — 2px taller than the
54px content box it's centered in — so it overflows the wrapper's content box by 1px top and 1px bottom.
Because the input's own background (`var(--bg)`, opaque white) fills that overflow, it paints directly over
the wrapper's top and bottom 1px border lines across the input's full width, visually erasing them. Only the
short stretch near the "@" span (which the input doesn't cover) still shows the wrapper's border.

The other two fields on the same screen don't hit this because they use the plain `Field` helper — label +
`<Input bare>` directly inside `.field`, with no extra wrapper div — so `.wyn-input`'s styling applies once,
cleanly, with nothing else colliding.

This is a genuine nesting collision introduced by WYN-163's height bump (56px inputs, up from the pre-163
value) — at the old, smaller sizing the 2px discrepancy either didn't exist or wasn't visually encoded the
same way; it was not caught during WYN-163/164 QA because neither QA round screenshotted this specific field
at this pixel-level detail (round 1/2 checked geometry values and cross-screen consistency, not sub-pixel
border rendering within a single field).

## Fix

Smallest safe change: neutralize the colliding `.wyn-input` properties **locally**, on this one input's
inline `style`, instead of touching the shared CSS file (used cleanly by the other two fields on this screen
plus 5 other screens) or the `Input` component (used everywhere in the app).

`web/components/auth-flow/screens.tsx`, username field `<Input bare>`:
- `height: 56` → `height: "100%"` (resolves against the wrapper's flex content box, so it always matches
  exactly regardless of border width — more robust than hardcoding 54px)
- added `background: "transparent"` (removes the opaque white fill that was painting over the border)
- added `padding: 0` (removes doubled 18px horizontal padding — the wrapper already provides it)
- added `borderRadius: 0` (defensive; no border shows on the input itself, but removes any residual radius
  artifact if the background changes back in the future)

Verified via `getComputedStyle`: input now renders at `height: 54px` (matches wrapper's 54px content box
exactly) with `background: rgba(0,0,0,0)`, no overflow. Re-checked 320/360/390/430px — no overflow at any
width. Screenshot confirms the box now renders as a complete, clean rounded rectangle identical to the other
two fields.

Grepped every other `Input bare` usage in the codebase (`web/components/content-reference/*.tsx`,
`web/components/account-add-route.tsx`, `web/components/auth-flow/screens.tsx`) — this wrapper-div-with-its-
own-border/height/padding pattern is unique to this one field; no other instance needs the same fix.

## Files Changed

- `web/components/auth-flow/screens.tsx` — username field `<Input bare>` inline style (1 line)
- `web/tests/browser/auth-reference-flow.spec.ts` — added 1 regression test

## Tests

- `npm run typecheck` / `npm run lint` / `npm run build` — all clean (0 errors, same 3 pre-existing
  unrelated warnings as before)
- Manual Playwright verification (`playwright-core` + `/opt/pw-browsers/chromium`, dev server): screenshot
  at 390×844 before/after confirms the fix visually; `getComputedStyle`/`getBoundingClientRect` before/after
  confirms the input no longer exceeds the wrapper's 54px content-box height at 320/360/390/430px.
- Added regression test `signup step 1 username field input never exceeds its wrapper's content box` to
  `web/tests/browser/auth-reference-flow.spec.ts`. Verified this test's assertion logic directly (via
  `git stash` on just the component fix + a standalone script replicating the same assertion) actually
  fails against the pre-fix code (`inputRectHeight: 56 > wrapperClientHeight: 54`) and passes against the
  fix (`54 <= 54`) — confirming it's not a vacuous test. Note: a naive `boundingBox()`-vs-`boundingBox()`
  comparison does **not** catch this bug (the input's outer rect coincides with the wrapper's outer rect,
  since the overflow paints over the border rather than extending past it) — the test instead compares the
  input's rendered height against the wrapper's `clientHeight` (content box, border excluded).
- The project's own Playwright test runner still can't execute in this sandbox (missing
  `chromium_headless_shell` binary — same pre-existing gap noted in WYN-163/164) — needs a real CI/dev-
  machine run to execute the `.spec.ts` file itself; the `browser-qa` CI check on the next PR will do this.

## Regression Risk

Very low — single-line inline-style change on one specific input, scoped via inline style (not shared CSS),
verified not to affect the wrapper's layout, the other two fields on the same screen, or any other consumer
of `.wyn-input`/`Input bare`.

## Handoff to QA

Ready for AI QA & Security re-verification: confirm the username field box renders as a complete rounded
rectangle at 320/360/390/430px on `/signup/step-1`, confirm the other two fields and the rest of WYN-163's
scope are unaffected, and confirm the new regression test's intent (re-run manually if the CI Playwright
runner isn't available in the QA session either).

---

## QA Verification (2026-09-19, AI QA & Security)

**Independent re-test** (not trusting the Debug Engineer's own report — re-ran everything fresh): checked
out `claude/ux-ui-button-design-ult3lz` at commit `4c885033`, ran `npm run typecheck`/`lint`/`build` fresh
(all clean, 0 errors, same 3 pre-existing unrelated warnings), started a live dev server, and independently
verified with a fresh Playwright script (`playwright-core` + `/opt/pw-browsers/chromium` — the project's own
`@playwright/test` runner still can't launch in this sandbox, same pre-existing gap noted in every prior QA
round on this branch):

- Username input height vs. wrapper's `clientHeight` (the actual regression check, not just outer
  `boundingBox()` which the original bug report already noted is insufficient) — confirmed `input=54px <=
  wrapper=54px` at **320/360/390/430/768px** (added 768px beyond the original 4 widths as an extra check)
- Filled a 40-character username to check for box overflow from long text — wrapper's `scrollWidth` stayed
  within its own width, no horizontal overflow
- **Dark mode** (`colorScheme: "dark"` emulation, not covered by the original Debug Engineer's fix
  verification): wrapper border renders as a visible non-transparent gray, screenshot confirms the box
  still renders as a complete rounded rectangle in dark mode too — same CSS custom properties
  (`--border-strong`/`--bg`) as light mode, so this was expected to hold, but confirmed directly rather than
  assumed
- Swept all 7 auth-flow screens (`/welcome`, `/signup/step-1`, `/signup/step-2`, `/onboarding/profile`,
  `/login`, `/forgot-password`, `/account/add`) for browser console errors — 0 errors on any screen
- Scanned the full diff (WYN-165 + WYN-166 commits) for hardcoded secrets/keys/tokens/credentials — none
  found (only unrelated `key=` React props and pre-existing `password` field names/labels)

**Result: PASS.** No regressions found beyond what the Debug Engineer already reported fixed. Full QA report
covering this together with WYN-166: see `.wyn/tasks/approved/WYN-166-signup-birthdate-thai-selects.md`.
Handing off to **AI Deploy & DevOps**.

---

## Deployment (2026-09-19, AI Deploy & DevOps)

Deployed together with WYN-166 via PR #546, merged by the Founder at 2026-09-19T08:52:07Z. Production
deploy workflow succeeded end-to-end. Full deployment log:
`.wyn/logs/deployments/2026-09-19-wyn-165-166-username-border-birthdate-thai-selects-deploy.md`. Still
needs the Founder's real-device confirmation that the username field border now renders correctly on
`wynos.online/signup/step-1`.
