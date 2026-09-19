# Bug Report — WYN-168

Status: open — found by AI QA & Security during WYN-167 testing, not caused by WYN-167
Owner: AI Debug Engineer
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

## Fix (recommended, not yet implemented)

Replace the hardcoded hex values with theme-aware tokens:
- Default state: `background: #f1f1f3` → a token that keeps the light-mode value at/near `#f1f1f3` and adds
  a dark-mode value with real contrast against white text (e.g. a new `--wyn-surface-strong`-style token, or
  reuse an existing dark-appropriate surface token if one already fits — needs a look at what dark-mode
  surface tokens `design-system.css`/`globals.css` already define from the 2026-09-16 dark mode pass). This
  is a color decision, not just a rename, so it should go through AI Design rather than AI Coding picking a
  value unilaterally.
- `.is-requested` state: `color: #6b6b6b` → `var(--wyn-text-secondary)` likely (already used elsewhere for
  secondary text, needs confirming its dark-mode value clears 4.5:1 against `var(--wyn-bg)`)

Since this changes an actual color decision (not just a token rename), this should go through AI Design
first to pick the exact dark-mode background value, then AI Coding to implement — not decided unilaterally
by QA.

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
