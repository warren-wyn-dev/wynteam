# Bug Report — WYN-176 (batch 6)

Status: fixed
Owner: AI Debug Engineer
Bug: When `web/tests/browser/parity.spec.ts` was edited in batch 6 to stop reading the now-deleted `club-detail-route.tsx` (dead code) and rely instead on the existing `clubGolden` assertions against `club-detail-golden.tsx` (the live component), the commit message claimed the same contracts were "already checked (more thoroughly)" by `clubGolden`. This was only half true: the removed assertion checked 4 Supabase contract strings (`from("club_channels")`, `from("club_channel_messages")`, `from("club_events")`, `rpc("club_insights"`), but the `clubGolden` assertion only covered 2 of them (`club_channel_messages`, `club_insights`) — `club_channels` and `club_events` were dropped entirely with no replacement, even though both are real, live queries in `club-detail-golden.tsx` (lines 138 and 217).

Effect: not a live/security bug — the app's actual behavior was never protected by the old assertion either, since it checked a dead file that's never rendered. The real effect is a test-coverage regression: two genuine live Supabase queries in `club-detail-golden.tsx` lost the regression-test coverage they should have gained when the test was redirected to check the live file, silently narrowing the safety net.

Root Cause: When consolidating two overlapping assertion lists into one, only the properties actually being tested for at the time were preserved carefully; the full set difference between the old (4-item) and new (partial) contract list wasn't cross-checked before commit.

Fix Applied (AI Coding, 2026-09-20): Added the two missing contract strings, `'from("club_channels")'` and `'from("club_events")'`, to the existing `clubGolden` contract-check array in `web/tests/browser/parity.spec.ts` (single-line, additive change). Verified both strings are genuinely present in `web/components/club-detail-golden.tsx` (lines 138, 217) before adding.

Tests after fix: `npx playwright test tests/browser/parity.spec.ts -g "source contracts cannot regress"` — 3/3 pass (all projects) with the new assertions included. Full regression suite (`parity.spec.ts`, `system-visual-parity.spec.ts`, `pixel-parity-pass-2.spec.ts`, `final-source-parity-gate.spec.ts`, `founder-visual-parity.spec.ts`) — 54 passed, 6 failed (the same pre-existing `page.goto`/`chromium_headless_shell` sandbox limitation noted throughout this session, unrelated to this diff). `typecheck`/`lint`/`build` clean (0 errors, same 3 pre-existing unrelated warnings).

Files Changed: `web/tests/browser/parity.spec.ts` only (1 line).

Regression Risk: None — test-only, purely additive assertion.

Handoff: → **AI QA & Security** for re-verification before this batch can proceed to Deploy gate.
