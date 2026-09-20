# Bug Report — WYN-181 (Sub-task 1: Install Prompt Banner)

Status: fixed
Owner: AI Debug Engineer
Bug: Two real bugs found in `web/components/install-prompt-banner.tsx`.

## Bug 1 (HIGH) — banner never shows on iPad at all

`isIos()` only matched `/iphone|ipad|ipod/i` against `navigator.userAgent`. Since iPadOS 13, Safari's default user agent masquerades as desktop macOS Safari with no "iPad" substring at all (a deliberate Apple change so sites don't serve iPad users a mobile layout). Real device iPads therefore fall through to the `else` branch, which waits forever for `beforeinstallprompt` — an event Safari never fires on any Apple platform. Result: the entire install-banner feature is silently, permanently broken on the exact device class this sub-task's sibling work (iOS splash screens, still pending) explicitly targets.

Reproduction: set `navigator.userAgent` to a real iPad's default string (`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 ... Safari/605.1.15` — indistinguishable from a real Mac by UA alone), load the page, wait past the 20s delay, dispatch no `beforeinstallprompt` (since Safari never fires it) — banner never appears.

Fix Applied (AI Debug Engineer, 2026-09-20): `isIos()` now also checks `navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1` — the standard, widely-used sniff for "this is an iPad pretending to be a Mac" (a real Mac never reports touch points). A genuine Mac desktop (`maxTouchPoints === 0`) is correctly left alone.

## Bug 2 (MEDIUM) — accepting the install prompt doesn't persist the dismissal

The design spec says dismissing the banner — by closing it, clicking "not now", *or* a resolved install prompt (accepted or rejected) — should write the localStorage timestamp so it doesn't reappear for 7 days. The original code only called `dismiss()` (which writes the timestamp) on the `"dismissed"` outcome; on `"accepted"` it only called `setVisible(false)`, never writing the timestamp. Low real-world impact (Chrome won't refire `beforeinstallprompt` in the same tab right after an accepted install), but a real, reproducible logic bug that also silently violates the written spec — e.g. a fresh tab/reload before the app actually finishes installing could show the banner again.

Fix Applied (AI Debug Engineer, 2026-09-20): `install()` now always calls `dismiss()` after `userChoice` resolves, regardless of outcome.

## Tests after fix

Independent Playwright harness against a real dev server (chose a much faster technique than either AI Coding's original real-24s-waits or the diagnosis of Clock API not working: wrap `window.setTimeout` via `page.addInitScript` to shrink any delay ≥15000ms down to 300ms — this sidesteps whatever incompatibility Clock API has with Next dev mode without waiting real seconds per test):
- iPad masquerading as Mac (`platform: "MacIntel"`, `maxTouchPoints: 5`, no `beforeinstallprompt`): banner now appears with the iOS manual-steps UI — **pass**
- Sanity: a real Mac desktop (`maxTouchPoints: 0`) is still correctly NOT treated as iOS — **pass**
- Accepting install (mocked `event.prompt()` + `userChoice` resolving `"accepted"`): dismissal timestamp is now written, banner hides, and reappearing is correctly suppressed on reload within the cooldown — **pass**
- Re-ran the original 10-scenario suite (Android install flow, iOS manual steps, dismiss persistence, standalone-mode suppression) — **10/10 still pass**, confirming no regression

`typecheck`/`lint`/`build` clean (0 errors, same 3 pre-existing unrelated warnings).

Files Changed: `web/components/install-prompt-banner.tsx` only (both fixes, ~8 lines total).

Regression Risk: Low — both fixes are scoped to the two specific functions flagged, no other files touched, no change to CSS/markup/design.

Handoff: → **AI QA & Security** for re-verification before this sub-task can proceed to Deploy gate.
