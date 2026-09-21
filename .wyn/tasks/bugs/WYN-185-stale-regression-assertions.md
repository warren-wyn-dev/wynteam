# Bug Report — WYN-185

Status: fixed — see `.wyn/tasks/active/WYN-185-wynos-web-beta1-fixes.md`'s
"QA follow-up" section for the applied fix and test results. All 3 flagged
assertions updated, plus a 4th stale assertion (`navigator.share` →
`shareOrCopyLink`, from item 5) found while re-running the full suite. The
external-link (item 11) defense-in-depth was also applied. Full
`npx playwright test --project=chromium-desktop`: 89/89 PASS. Ready for
QA re-check.
Owner: AI Debug Engineer
Bug: WYN-185 (Wynos Web Beta1 fixes) batches 7 and 13 changed real, intended
product behavior (search state/tabs restructure; action-row icon size
normalization 24px→22px) but did not update 3 pre-existing regression tests
that hardcode the old values. Running the full `web/tests/browser/` suite
(not just the new batch-specific specs + `npm run check`) reproduces 3
deterministic failures out of 90 tests on `chromium-desktop`:

1. `web/tests/browser/parity.spec.ts:115-116` ("source contracts cannot
   regress to staged migration UI") — asserts the literal source strings
   `<WynosShareIcon size={24} />` and `<WynosIcon name="repost" size={24}
   strokeWidth={2} />` still exist in `web/components/home/post-actions.tsx`.
   Batch 13 changed both to `size={22}` (item 13, "inconsistent action-row
   icon sizes" fix) — correct product change, stale test.
2. `web/tests/browser/home-visual-parity.spec.ts:66,68-69` ("first post
   matches compact avatar author caption and action geometry") — asserts
   live computed CSS `width`/`height: 24px` on the rendered repost icon
   `<svg>` and the share icon in the Home feed. Confirms the 22px change is
   actually live end-to-end (not just source-level) — this is the real
   Home feed rendering the new, intentionally-correct 22px icon, but the
   test still expects 24px.
3. `web/tests/browser/system-visual-parity.spec.ts:18-21` ("Search keeps
   the current Flutter Discovery then three-tab contract") — asserts the
   literal source string `useState<"user" | "drop" | "club">` still exists
   in `web/components/search-route.tsx`. Batch 7 (item 7) intentionally
   restructured search state from local `useState` to URL-derived
   (`?q=`/`?type=`) with a new default "ทั้งหมด" (All) tab — correct
   product change (this was the actual point of item 7), stale test.

Reproduction:
```
cd web
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers npx playwright test --project=chromium-desktop
# (or: npx playwright install chromium   first, if the sandbox's pre-installed
#  chromium revision doesn't match package.json's playwright version)
```
86 passed, 3 failed — the 3 listed above. Reproduced independently 1-for-1
on 2026-09-21 by AI QA & Security against commit `a24797b` (branch
`claude/wynos-web-beta1-fixes-r3c06k`, HEAD of this task).

Root Cause: Batches 7 and 13's own "Tests:" log entries only mention
`npm run check` (lint+typecheck+build) plus the batch's own new
`/dev/*-fixture` Playwright spec — neither batch ran the full pre-existing
`web/tests/browser/` suite before considering the batch done. This is the
exact same class of mistake flagged one day earlier in
`.wyn/company/DECISIONS.md`'s 2026-09-20 WYN-184 entry ("literal-string CSS
assertion ต้องอัปเดตคู่กับการแก้ CSS เสมอ + AI Coding ต้องรัน
`web/tests/browser/` suite จริงก่อนส่ง QA ไม่ใช่แค่ ad hoc harness") and
recorded in `.wyn/learning/LESSONS_LEARNED.md`/`MISTAKES.md` — it recurred
here regardless.

Fix (recommended, not yet applied — QA does not fix product/test code):
Update the 3 stale assertions to match the new, intentionally-correct
values. Do NOT revert the icon-size or search-state product changes — both
are the actual, Founder-requested fixes for items 7 and 13.
- `parity.spec.ts:115-116`: `size={24}` → `size={22}` for both the
  `WynosShareIcon` and the repost `WynosIcon` lines (mirror
  `post-actions.tsx`'s actual current source).
- `home-visual-parity.spec.ts:66,68-69`: `"24px"` → `"22px"` for both the
  repost icon and the share icon width/height assertions.
- `system-visual-parity.spec.ts:18-21`: replace the
  `useState<"user" | "drop" | "club">` / `not.toContain('setTab("all")')`
  assertions with ones that match the new URL-driven 4-tab (`all`/`users`/
  `posts`/`clubs`) contract in the current `search-route.tsx` — e.g. assert
  the `SEARCH_TABS`/`AllResults`/`role="tab"` shape instead of the removed
  local-state literal. Re-check whether this test's Flutter-parity intent
  (matching `search_screen.dart`'s 3-tab bar) still needs a *separate*
  assertion for the non-"all" tabs, since the Flutter side wasn't part of
  this task's scope.

After the 3 assertions are updated, re-run the full
`npx playwright test --project=chromium-desktop` suite (should return to
90/90, or whatever the current total is) before handing back to QA.

Files Changed: none yet (bug report only — QA does not edit test/product
code per its role).

Tests: See Reproduction above. `bash supabase/tests/wyn_185_public_club_read_access_test.sh`
(10/10), `wyn_187_profile_external_link_validation_test.sh` (7/7),
`wyn_130`/`wyn_115`/`wyn_117` club regression scripts, and `npm run check`
were all independently re-verified and are clean — this bug is isolated to
the 3 Playwright assertions above, not a DB/security regression.

Regression Risk: Low for the recommended fix itself (test-only, 3 literal
value updates) — the risk is in accidentally "fixing" this by reverting the
actual UI change instead of updating the assertion, which would undo a
Founder-requested fix (items 7/13) and reintroduce the icon-size
inconsistency / User-tab-first-look bugs this task was meant to resolve.
Also worth a process note (not a code fix): AI Coding should run
`npx playwright test --project=chromium-desktop` (full suite) — not just
`npm run check` plus the batch's own new spec — before marking any batch
"Tests: PASS" going forward, per the standing WYN-184 lesson.

Handoff to QA: After the 3 assertions are corrected and the full suite is
green again, re-run this task's full QA pass (functional + the item
9/10/11 security checks + accessibility + `npm run check` + full
Playwright suite + the two DB migration test scripts) — do not assume a
narrow re-check of just the 3 tests is sufficient, since this file's
existence means the batch's own self-reported "Tests: PASS" was incomplete
once already.

---

## Secondary finding (HIGH, security — flagging alongside, not blocking on
its own, but must be resolved/explicitly accepted by Founder before
production deploy)

Item 11 (Profile external link) ships web client code
(`web/components/profile-route.tsx`) that renders
`profile.social_links.website` directly as a clickable
`<a href={...} target="_blank" rel="noopener noreferrer nofollow ugc">` on
any user's public profile page — but the server-side validation trigger
that's supposed to be the actual security boundary
(`supabase/migrations_wyn187_profile_external_link_validation.sql`,
`profiles_validate_social_links()`) is **not applied to any database yet**
(by design, per AGENTS.md Change Control — the Founder applies it via the
Supabase Dashboard). Until it's applied, `profiles.social_links`' RLS
policy is `using (auth.uid() = id)` with **no `WITH CHECK` content
restriction at all**, so any authenticated user can bypass the web client's
own `normalizeExternalUrl()` guard with a raw REST `PATCH` and store a
`javascript:`/`data:` URI in their own profile's `social_links.website`.
Any other authenticated visitor who opens that profile and clicks the
"เว็บไซต์ภายนอก" link would execute the attacker's JS in their own
logged-in browser session on the app's own origin (classic stored
self-XSS-turned-into-an-attack-on-others pattern via a profile link — well
established as a real risk class, not theoretical).

Verified independently (throwaway local Postgres, schema.sql +
`migrations_wyn187_...sql` applied): with the trigger in place, `data:` URIs,
mixed-case `JaVaScRiPt:` URIs, and cross-user writes are all correctly
rejected/blocked (7/7 scripted checks + 5 additional QA-authored checks, all
PASS) — the validation design itself is sound. The gap is purely
**deployment sequencing**: the web code that *renders* the link must not go
live before the DB trigger that *validates what can be stored in it* does.

Recommendation:
1. Require the Founder (or AI Deploy & DevOps) to apply
   `migrations_wyn187_profile_external_link_validation.sql` to
   production **before or atomically with** deploying this batch's web
   code — do not deploy the web app first and the migration "later."
2. As cheap defense-in-depth independent of the migration, consider having
   `profile-route.tsx` re-run `normalizeExternalUrl()` on
   `profile.social_links.website` at render time before using it as `href`
   (currently only validated at write time) — this closes the window even
   if the migration is ever skipped or a future write path forgets to
   validate.
