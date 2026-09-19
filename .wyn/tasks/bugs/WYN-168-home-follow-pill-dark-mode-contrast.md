# Bug Report — WYN-168

Status: closed (AI QA & Security ยืนยัน PASS แล้ว 2026-09-19 — ดูรายละเอียดที่ท้ายไฟล์)
Owner: AI Deploy & DevOps
Parent: none (pre-existing production bug, unrelated to any in-flight task) — discovered as a side effect of
adversarial dark-mode testing during WYN-167's QA round (2026-09-19)

## Bug

The "ติดตาม" (Follow) button on Home feed posts (`.wyn-post-follow-pill`,
`web/components/home/post-author-row.tsx` + `web/app/home.css`) is **effectively invisible in dark mode** —
white text on a near-white background. This is live on production right now (dark mode shipped 2026-09-16,
`.wyn/logs/deployments/2026-09-16-web-dark-mode-design-pass-deploy.md`), independent of WYN-167.

## Reproduction

Environment: local `npm run dev`, Chromium via `playwright-core` with `colorScheme: "dark"` emulation
(`/opt/pw-browsers/chromium` — this sandbox's `@playwright/test`-managed browsers still aren't installed,
same pre-existing gap as every prior QA round).

1. `cd web && npm run dev`
2. Open `http://localhost:3000/dev/home-fixture` with the browser/OS set to dark mode (or Playwright's
   `colorScheme: "dark"`)
3. Any post with a visible "ติดตาม" button renders it as a near-white pill with white text — screenshot
   confirms the label is unreadable

## Root Cause

`web/app/home.css`'s `.wyn-post-follow-pill` (default, not-yet-following state) hardcodes
`background: #f1f1f3` — a literal hex value, not a `var(--wyn-*)` theme token. `color: var(--wyn-text)` IS
theme-aware and correctly resolves to near-white in dark mode (confirmed via `getComputedStyle`:
`rgb(255, 255, 255)`) — but the background never follows it, staying light gray regardless of theme.

Computed contrast ratio (WCAG relative luminance formula): **white (255,255,255) text on `#f1f1f3`
(241,241,243) background = 1.13:1** — WCAG AA requires ≥4.5:1 for normal text. This is effectively zero
contrast, not just "below standard."

The `.is-requested` variant (private-account "ขอติดตามแล้ว" state — reachable when `followRequested` is
true) uses `background: var(--wyn-bg)` (correctly theme-aware) but `color: #6b6b6b` (also hardcoded) — in
dark mode this computes to **3.94:1**, still below the 4.5:1 AA threshold, though far less severe than the
default state's 1.13:1.

Note: the `.is-following` CSS branch (`border-color: #e1e1e4`) appears to be dead code under the current
render logic — `post-author-row.tsx` only renders the button at all when `showFollow && !following`, so
`following === true` never reaches this button; not verified further since it's out of scope for this bug,
noted here in case it's relevant to whoever picks this up.

This bug predates WYN-167 entirely — confirmed via `git show 443317cb^:web/app/home.css`, the exact same
hardcoded `background: #f1f1f3` line existed unchanged since commit `dfadc434` ("expand Home icon-button tap
targets"), well before WYN-167 touched this file. WYN-167 only added a `transition`/`:active` rule after
this existing declaration — it did not touch color/background at all.

This is exactly the class of issue `.wyn/docs/design/wyn-160-web-design-system-consolidation.md`'s audit
already flagged generally ("ห้ามมีไฟล์ CSS ไหน hardcode สีเทา/ขาว/ดำเป็น hex ตรงๆ — ต้องอ้าง `var(--wyn-*)`
เท่านั้น") — this is one concrete instance of that broader known gap.

## Fix (decided by AI Design, 2026-09-19 — ready for AI Debug Engineer)

Checked `web/app/design-system.css` first per the standing rule ("ห้ามคิดทิศทางสีใหม่หากมี design system ที่
อนุมัติแล้ว") — the 2026-09-16 dark mode pass already declared exactly the tokens this needs; **no new color
invented**, this is a pure hardcoded-hex → existing-token swap:

1. **Default state** — `.wyn-post-follow-pill { background: #f1f1f3 }` → `background: var(--wyn-surface)`
   - Light mode: `--wyn-surface` = `#fafafa` (vs. the current `#f1f1f3`) — both are near-white neutral grays,
     visually indistinguishable at this size/weight; no meaningful light-mode change
   - Dark mode: `--wyn-surface` = `#111111` → white text on `#111111` computes to **18.88:1** (WCAG AA needs
     4.5:1, AAA needs 7:1 — clears both with large margin)

2. **`.is-requested` state** — `.wyn-post-follow-pill.is-following, .wyn-post-follow-pill.is-requested { color: #6b6b6b }`
   → `color: var(--wyn-text-secondary)`
   - Light mode: `--wyn-text-secondary` = `#6b6b6b` — **byte-for-byte identical** to the current hardcoded
     value, zero visual change
   - Dark mode: `--wyn-text-secondary` = `#8a8880` on `var(--wyn-bg)` (`#000000`) computes to **5.91:1**,
     clears the 4.5:1 AA threshold

3. **`.is-following`/`.is-requested`'s `border-color: #e1e1e4`** — left as-is, out of scope. This isn't part
   of the text-contrast bug (borders follow WCAG's separate 3:1 non-text threshold, and `#e1e1e4` only
   applies in light mode already since `border-color` isn't re-declared for dark mode on this rule — a
   pre-existing, separate, lower-priority gap; not touched here to keep this fix minimal and scoped to the
   actual unreadable-text bug).

**Design Rules**: both replacements are drop-in — same property, same selector, only the value moves from a
literal hex to the token that already carries the correct value for both themes. No spacing/size/layout
change. No new CSS custom property needs declaring.

**Handoff**: AI Debug Engineer — 2-line change in `web/app/home.css`, no `.tsx` changes needed.

## Tests

After fixing: re-run the same dark-mode contrast check (compute WCAG ratio via `getComputedStyle`, same
method used to find this) at both states (default + `is-requested`), confirm ≥4.5:1 for both. Add as a
permanent regression test in `web/tests/browser/` if a suitable dark-mode test file exists, or note as a
candidate for one.

## Regression Risk

N/A yet (not fixed) — but note for whoever fixes it: this button appears on every Home feed post from a
non-followed author, so it's high-visibility; re-check light mode still looks correct after any token swap
(light mode currently has adequate contrast — `#f1f1f3` bg + dark `--wyn-text` — don't regress that side).

## Severity

**HIGH** — not a crash/data-loss issue, but a core, frequently-visible interactive control
(the primary "follow someone" affordance in the whole app) is functionally unusable (unreadable, though
still clickable/tappable by position) for any user with dark mode enabled. Per AGENTS.md, HIGH findings need
resolution or explicit documented Founder risk acceptance before further dark-mode-affecting release — does
**not** block WYN-167 (unrelated diff, zero regression risk, already Founder-approved) but should be
prioritized as its own fast-follow.

## Handoff

Filed by AI QA & Security during WYN-167's QA round. Recommend: AI Design picks the corrected dark-mode
token value → AI Debug Engineer or AI Coding implements → AI QA & Security re-verifies contrast ≥4.5:1 in
both states → Deploy. Founder should be told this exists and is live on production now, independent of any
in-flight work.

---

## Resolution (2026-09-19, AI Debug Engineer)

Implemented exactly as AI Design specified — 2-line change in `web/app/home.css`:
1. `.wyn-post-follow-pill { background: #f1f1f3 }` → `background: var(--wyn-surface)`
2. `.wyn-post-follow-pill.is-following, .wyn-post-follow-pill.is-requested { color: #6b6b6b }` →
   `color: var(--wyn-text-secondary)`

**Verification**: `npm run typecheck`/`lint`/`build` all clean (0 errors, same 3 pre-existing unrelated
warnings). Re-measured actual rendered contrast via `playwright-core` + `/opt/pw-browsers/chromium` against
a live dev server (this sandbox's `@playwright/test`-managed browsers still aren't installed):
- Light mode, default state: `rgb(250,250,250)` bg / `rgb(10,10,10)` text → **18.97:1**
- Dark mode, default state: `rgb(17,17,17)` bg / `rgb(255,255,255)` text → **18.88:1** (was 1.13:1)
- Light mode, `.is-requested`: `rgb(255,255,255)` bg / `rgb(107,107,107)` text → **5.33:1**
- Dark mode, `.is-requested`: `rgb(0,0,0)` bg / `rgb(138,136,128)` text → **5.91:1** (was 3.94:1)

All 4 combinations now clear WCAG AA's 4.5:1 threshold with margin. Screenshots confirm: dark mode now shows
readable white-on-dark-gray "ติดตาม" text; light mode is visually unchanged (as predicted — both token
swaps resolve to values imperceptibly close to, or byte-for-byte identical to, the previous hardcoded ones
in light mode).

Added a permanent regression test: `web/tests/browser/home-visual-parity.spec.ts`, new
`test.describe("dark mode")` block, `"follow pill text clears WCAG AA contrast in both states"` — computes
the actual WCAG relative-luminance contrast ratio from `getComputedStyle()` at runtime (same formula used to
find this bug) and asserts ≥4.5:1 for both the default and `.is-requested` pill states. Verified the test's
own logic independently against the live app before committing (both ratios reproduce exactly: 18.88 and
5.91) — the project's own Playwright test runner still can't execute in this sandbox (missing
`chromium_headless_shell` binary, same pre-existing gap as every prior round), so this needs a real CI/dev-
machine run to execute the `.spec.ts` file itself; the `browser-qa` CI check on the next PR will do this.

**Lessons recorded**: `.wyn/learning/LESSONS_LEARNED.md`, `.wyn/learning/MISTAKES.md` (2026-09-19 entries).

Handing back to **AI QA & Security** for verification.

---

## QA Verification (2026-09-19, AI QA & Security)

**Independent re-test** on commit `b27c4ccd` — re-ran `typecheck`/`lint`/`build` fresh (all clean), then 13
checks against a live dev server (`playwright-core` + `/opt/pw-browsers/chromium`):

- Re-measured contrast in both themes × both pill states (4 combinations) — all clear 4.5:1: light default
  18.97:1, light `.is-requested` 5.33:1, dark default 18.88:1, dark `.is-requested` 5.91:1
- Confirmed light mode's background literally matches the new token value (`rgb(250, 250, 250)` =
  `#fafafa`), consistent with the "no meaningful light-mode change" claim
- Checked the `border-color: #e1e1e4` point the fix left out of scope, for due diligence rather than taking
  the claim at face value: dark mode border-vs-bg is actually 16.09:1 (fine, ironically — light gray border
  reads clearly against a black background), light mode is 1.31:1 (unchanged from before this fix — a
  pre-existing subtle-border choice, not something this fix regressed)
- Confirmed the follow-pill's click handler still works, 0 console errors
- Confirmed WYN-167's press-scale motion (`transform: scale(0.96)` on `:active`) still functions correctly
  on the now-recolored pill — the two fixes compose without conflict
- Swept `/welcome`, `/signup/step-1`, `/login`, `/dev/home-fixture` for console errors — 0 on all 4

**13/13 passed. Result: PASS.**

**Security**: CSS-only change, no secrets, no new trust boundary.

Both WYN-167 and WYN-168 are now verified and ready for deploy together. Handing off to
**AI Deploy & DevOps**.

---

## Deployment (2026-09-19, AI Deploy & DevOps)

Deployed together with WYN-167 via PR #547, merged by the Founder at 2026-09-19T09:42:24Z. A follow-up CI
fix (PR #548) was needed post-merge — 3 pre-existing source-lock tests pinned the old hardcoded color value
this fix intentionally changed, and a Codex review then caught that the first fix attempt was itself
vacuous (didn't actually scope the check to the follow-pill rule). Both resolved; production deploy
succeeded end-to-end on the final state. Full log:
`.wyn/logs/deployments/2026-09-19-wyn-167-168-home-feed-motion-contrast-fix-deploy.md`. Still needs the
Founder's real-device confirmation that the follow button now reads clearly in dark mode on
`wynos.online`.
