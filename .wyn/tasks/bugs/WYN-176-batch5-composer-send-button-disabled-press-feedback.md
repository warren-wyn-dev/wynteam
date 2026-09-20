# Bug Report — WYN-176 (batch 5)

Status: fixed
Owner: AI Debug Engineer
Bug: `.golden-club-composer button` (the Club chat send button, `web/app/club-detail-golden.css`) applied the `scale(0.96)` press-feedback transform even when the button was genuinely `disabled` in real usage (`disabled={sending || (!draft.trim() && !image)}`, `web/components/club-detail-golden.tsx:441`), because its `:active` rule was missing the `:not(:disabled)` guard that its sibling selectors in the same batch correctly received. Same root-cause pattern as the WYN-176 batch 4 disabled-button bug.

Affected selector: `.golden-club-composer button` — `web/app/club-detail-golden.css:166` (`.golden-club-composer button:active` had no guard, while `.golden-club-inline-join`, `.golden-club-primary-join`, `.golden-club-sheet-row`, `.golden-club-poll > button` in the same rule block correctly had `:active:not(:disabled)`).

Not a bug: `.golden-club-composer label` (the image-attach control) is a `<label>` wrapping a hidden file input — `<label>` elements don't support the `:disabled` pseudo-class in CSS, so `:not(:disabled)` cannot be applied there. This is a pre-existing structural limitation shared with `.audit-club-image-picker` elsewhere in the app, not a new issue.

Reproduction: AI QA & Security built an independent Playwright harness (real 38-file CSS cascade), rendered the send button with `disabled`, pressed and held, waited for the 160ms transition to settle, and read `getComputedStyle(el).transform` — got `scale(0.96)` instead of `none`. Confirmed not a harness artifact by checking the 5 sibling selectors in the same commit, all of which correctly returned `none` when disabled.

Root Cause: Same as batch 4 — inconsistent application of the `:not(:disabled)` guard across a batch of newly-added selectors; one selector with a real disabled state in production was missed.

Fix Applied (AI Debug Engineer, 2026-09-20): Added `:not(:disabled)` to `.golden-club-composer button:active` in `web/app/club-detail-golden.css` (single-selector, one-line change within the existing shared `:active` rule block).

Tests after fix: fresh Playwright harness using inline `<style>` (avoiding the `file://` CSP restriction QA's own harness hit) — disabled variant now correctly shows `transform: none` (no press feedback), enabled variant still correctly applies `scale(0.96)` on press and releases to `none` — **3/3 pass**. `typecheck`/`lint`/`build` clean (0 errors, same 3 pre-existing unrelated warnings).

Files Changed: `web/app/club-detail-golden.css` only (1 line).

Regression Risk: Low — single-selector additive guard, no other files affected, no radius/size/logic change.

Handoff: → **AI QA & Security** for re-verification before this batch can proceed to Deploy gate.
