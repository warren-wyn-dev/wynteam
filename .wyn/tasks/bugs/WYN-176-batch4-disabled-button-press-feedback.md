# Bug Report — WYN-176 (batch 4)

Status: verified — QA PASS, ready for Deploy gate
Owner: AI Debug Engineer
Bug: 5 of the 9 press-feedback selectors added in WYN-176 batch 4 (`web/app/profile-golden-final.css`) apply the `scale(0.96)` press-feedback transform even when the underlying `<button>` is genuinely `disabled` in real usage, because their `:active` rules are missing the `:not(:disabled)` guard that two sibling selectors in the very same commit correctly received. This makes disabled/non-functional buttons visually "press" as if they were interactive, which is the opposite of the intent of the WYN-163/175/176 press-feedback system (giving honest, intentional interaction feedback).

Affected selectors (confirmed real `disabled={...}` usage in `web/components/profile-route.tsx`, CSS has no `:not(:disabled)` guard):
- `.wyn-profile-action-primary` / `.wyn-profile-action-secondary` — `profile-golden-final.css:190-198`; real disabled states: `disabled={action}` (unblock button, line 282), `disabled={action || summary.blockedBy}` (follow button line 285, message button line 286)
- `.profile-account-select` — `profile-golden-final.css:439-446, 340`; real disabled state: `disabled={action || managingAccounts}` (account-switcher row, `profile-route.tsx:295`)
- `.profile-account-use-other` — `profile-golden-final.css:441, 448, 401`; real disabled state: `disabled={action}` (`profile-route.tsx:295`)
- `.profile-more-sheet > button` — `profile-golden-final.css:530-536`; real disabled states: `disabled={action}` on the mute/unblock/block buttons inside the more-options sheet (`profile-route.tsx:296`)

Correctly guarded in the same commit (control group, confirms the fix pattern already exists and just wasn't applied consistently):
- `.profile-account-manage:active:not(:disabled)` — `profile-golden-final.css:449`
- `.wyn-profile-edit-avatar-remove:active:not(:disabled)` — `profile-golden-final.css:506`

Reproduction:
1. Built an independent, from-scratch Playwright harness (`web/qa-wyn176-batch4-harness.mjs`, run against the real 38-file CSS cascade from `app/layout.tsx` in import order, using `chromium.launch({ executablePath: "/opt/pw-browsers/chromium" })`).
2. For each of the 5 affected selectors, rendered a `<button ... disabled>` variant matching the real markup shape from `profile-route.tsx`, moved the mouse over it, did a real `page.mouse.down()`, waited 300ms for the 160ms transition to settle, then read `getComputedStyle(el).transform`.
3. Result: `transform` computed to `matrix(0.96, 0, 0, 0.96, 0, 0)` (i.e. `scale(0.96)` applied) on all 5 disabled variants, identical to the enabled/pressed state — confirming the disabled buttons visually depress on press even though their `onClick` will never fire.
4. Isolated this to a genuine browser behavior (not a Playwright/test artifact) with a 10-line minimal repro (`<button disabled>` + `:active { background: red }` with no guard vs. `:active:not(:disabled)` with a guard) confirming this Chromium build (and, per standard CSS UI behavior, most browsers) does apply `:active` styling to `disabled` buttons unless explicitly excluded with `:not(:disabled)`.

Root Cause: Inconsistent application of the `:not(:disabled)` guard across the 9 new selectors in the batch — 2 of 4 selectors that have real `disabled` states in production got the guard, but `wyn-profile-action-primary`/`secondary`, `profile-account-select`, `profile-account-use-other`, and `profile-more-sheet > button` did not, despite all having real `disabled={...}` usage in `profile-route.tsx`.

Fix (suggested, for AI Debug Engineer / AI Coding to apply): add `:not(:disabled)` to the `:active` rules for the 5 affected selectors in `web/app/profile-golden-final.css`, matching the existing pattern used for `.profile-account-manage` and `.wyn-profile-edit-avatar-remove`:
- `profile-golden-final.css:195-197` → `.wyn-profile-action-primary:active:not(:disabled), .wyn-profile-action-secondary:active:not(:disabled) { transform: scale(0.96); }`
- `profile-golden-final.css:446` → `.profile-account-select:active:not(:disabled)`
- `profile-golden-final.css:448` → `.profile-account-use-other:active:not(:disabled)`
- `profile-golden-final.css:534` → `.profile-more-sheet > button:active:not(:disabled)`

Files Changed: (pending fix) `web/app/profile-golden-final.css`

Tests: after the fix, re-run `web/qa-wyn176-batch4-harness.mjs`'s disabled-variant edge-case block (Part B) — all 5 (currently 5 FAIL out of 9 disabled-capable checks — see below) should read `transform: none` while the disabled button is held down.

Regression Risk: Low — this is a scoped, additive CSS change (adding `:not(:disabled)` to already-added `:active` rules), no other selectors/files affected, no radius/size/logic changes.

Handoff to QA: after fix, re-run the independent Playwright harness (`web/qa-wyn176-batch4-harness.mjs` pattern — QA's own harness was deleted after this report per house rules, recreate fresh) confirming: (1) the 5 previously-broken selectors no longer show press feedback on their disabled variant, (2) the rest of the 30 original cascade/press-feedback/reduced-motion checks still pass, (3) `typecheck`/`lint`/`build` stay clean, (4) `tests/browser/parity.spec.ts` + `tests/browser/system-visual-parity.spec.ts` still pass.

## Fix Applied (AI Debug Engineer, 2026-09-20)

Applied exactly the suggested fix — added `:not(:disabled)` to the 5 flagged `:active` rules in `web/app/profile-golden-final.css`:
- `.wyn-profile-action-primary:active:not(:disabled)`, `.wyn-profile-action-secondary:active:not(:disabled)` (line 195-196)
- `.profile-account-select:active:not(:disabled)` (line 446)
- `.profile-account-use-other:active:not(:disabled)` (line 448)
- `.profile-more-sheet > button:active:not(:disabled)` (line 534)

(`.profile-account-remove` was NOT touched — confirmed it has no `disabled` attribute anywhere in `profile-route.tsx`, so QA correctly did not flag it.)

**Tests after fix**:
- New disabled-state harness (7 checks: the 5 fixed selectors + 2 control selectors that were already correct) — **7/7 pass**, `transform: none` on all disabled variants while held down
- Re-ran the original batch 4 harness (30 checks: press-applies/release/reduced-motion on all 9 selectors in their normal enabled state) — **30/30 still pass**, confirming the fix didn't regress normal press feedback
- `typecheck`/`lint`/`build` — clean (0 errors, same 3 pre-existing unrelated warnings)
- Diff is a 6-line change (adding `:not(:disabled)` to 5 selector names across 3 rule blocks), no other files touched

**Files Changed**: `web/app/profile-golden-final.css` only

Handoff: → **AI QA & Security** for re-verification before this batch can proceed to Deploy gate.

## QA Re-Verification (AI QA & Security, 2026-09-20)

Independently re-verified from scratch in an isolated worktree (did not trust Debug Engineer's self-report) — confirmed `git show --stat 86afa16` is exactly the claimed 6-line change to `web/app/profile-golden-final.css`; independently grepped `web/components/profile-route.tsx` and confirmed `.profile-account-remove` genuinely has no `disabled` attribute anywhere, so leaving it unguarded was correct.

Built a fresh independent Playwright harness (`chromium.launch({ executablePath: "/opt/pw-browsers/chromium" })`, real 38-file CSS cascade): the 5 previously-broken selectors now show `transform: none` while disabled (5/5), the 2 already-correct control selectors still show no regression (2/2), all 9 selectors' normal enabled press-feedback still applies/releases correctly (20/20), and `prefers-reduced-motion: reduce` still disables the transition on all 9 (10/10) — **37/37 pass**. Dev server console/HTTP sweep on `/profile/me` and `/settings` clean. `typecheck`/`lint`/`build` clean. Ran `tests/browser/parity.spec.ts` + `tests/browser/system-visual-parity.spec.ts` for real via `npx playwright test` — all Profile/Settings-relevant checks pass; the only failures are `page.goto`-based tests hitting the sandbox's pre-existing `chromium_headless_shell` binary mismatch, unrelated to this diff.

Security: confirmed CSS-only diff, no `.ts`/`.tsx`/API route touched, no new data flow or auth/authorization surface.

**Final Status: PASS** — approved for Deploy gate.
