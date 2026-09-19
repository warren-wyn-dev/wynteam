# Bug Report — WYN-175

Status: bugs
Owner: AI Debug Engineer
Bug: Two of the new WYN-175 skeleton rows use the wrong height — `NotificationSkeleton` and the hashtag rows inside `SearchDiscoverySkeleton` are taller/shorter than the real rows they stand in for, so the page visibly jumps once real data replaces the skeleton (the exact regression this task's own Risks section warned about: "Skeleton loading ถ้าออกแบบไม่ตรงกับ layout จริงของ content จะเกิด layout shift").

Root cause (same pattern, both instances): `.notification-row` and `.hashtag-row` each have more than one CSS rule for the same class across different files imported in `web/app/layout.tsx`. The skeleton components were built by reading only the *first* rule found for each class, not the one that actually wins the cascade in production. This repo stacks several override files after the "base" definition (`parity-*.css`, `pixel-parity-*.css`, `system-parity-*.css`), and the last-imported same-specificity rule wins.

## Reproduction

Verified with a static harness that loads all 38 CSS files from `web/app/` in the exact order `layout.tsx` imports them (not just the file where each class is first defined), rendering both the new skeleton markup and the real row markup side by side, then measuring `getBoundingClientRect().height` for both.

1. `.wyn-skeleton-notification-row` (added in `web/app/skeleton.css`) renders at **76px** — copied from the min-height in `app/phase3.css:297`'s `.notification-row` rule.
2. The real `.notification-row` in production actually resolves to **62px** — `app/pixel-parity-audit-closure.css:184-190` (imported at `layout.tsx:30`, after `phase3.css` at `layout.tsx:10` and `system-parity-lock.css` at `layout.tsx:26`) is the last same-specificity rule and wins: `min-height: 62px; padding: 8px 16px; grid-template-columns: 46px minmax(0, 1fr) auto; gap: 12px;`
3. `.wyn-skeleton-hashtag-row` (added in `web/app/skeleton.css`) renders at **44px** — copied from `app/phase3.css:267`'s `.hashtag-row` rule.
4. The real hashtag row markup in `search-route.tsx` carries **both** `hashtag-row` and `flutter-rank-row` classes (`<div className="hashtag-row flutter-rank-row" ...>` at `search-route.tsx:239`). `.flutter-rank-row` in `app/parity-completion.css:22` (imported at `layout.tsx:13`, after `phase3.css`) wins and resolves to **63px** (`min-height: 62px` + 1px border), not 44px.

Net effect: Notifications' skeleton is 14px taller than the real row (content jumps up when data loads); Discovery's hashtag skeleton rows are 19px shorter than the real rows (content jumps down, and the 3 hashtag + 3 profile row skeleton block sits ~57px shorter than the real Discovery page it's standing in for).

## Expected

Skeleton row heights match the real row's actual rendered height (within ~1px) so no visible jump occurs when real data replaces the skeleton — this is the stated Acceptance Criteria intent, not a new requirement.

## Actual

Notification skeleton: 76px vs. real 62px (FAIL, -14px mismatch)
Search/Discovery hashtag skeleton: 44px vs. real 63px (FAIL, +19px mismatch)
(For contrast, the two rows that did match: search-user-row skeleton 64px = real 64px; search-club-row skeleton 68px = real 68px — both PASS, confirming the harness methodology itself is sound and this is a real, localized mismatch, not a measurement artifact.)

## Suggested Fix

In `web/app/skeleton.css`:
- `.wyn-skeleton-notification-row`: change `min-height: 76px` → `62px`, `padding: 11px 16px` → `8px 16px`, `grid-template-columns: 44px minmax(0, 1fr)` → `46px minmax(0, 1fr) auto` (to match the real 3-column grid — the real row reserves a trailing column for the unread dot), `gap: 11px` → `12px`.
- `.wyn-skeleton-hashtag-row`: change `min-height: 44px` → `62px`, and align padding/gap with `.flutter-rank-row` (`padding: 12px 16px`, `gap: 10px`) rather than the superseded `.hashtag-row` base rule.

In `web/components/ui/skeleton.tsx`, `NotificationRowSkeleton`'s avatar should stay 44px (that part was already correct — `.notification-avatar-wrap` is 44-46px across the cascade, not the part that mismatched).

Re-verify against the *full* CSS cascade (all files `layout.tsx` imports, in that order), not just the first file where a class appears — this codebase's `parity-*`/`pixel-parity-*`/`system-parity-*` override files make "first definition found" an unreliable way to determine a class's real computed style. The QA harness used to catch this is at the path noted below and can be reused/adapted for the fix verification.

## Files Changed (expected)

- `web/app/skeleton.css`

## Tests

No existing automated test covers skeleton row dimensions (already flagged as a Known Issue by AI Coding). Recommend converting the ad-hoc QA harness into a checked-in regression test once the fix lands, so this class of cascade-mismatch bug is caught by CI instead of manual QA next time. Harness + check script (not committed, in scratchpad): loads all `app/layout.tsx`-listed CSS files in `layout.tsx` order, renders skeleton markup next to real row markup, and asserts `getBoundingClientRect().height` matches within 1px.

## Regression Risk

Low — the fix is a pure CSS value correction in one file (`skeleton.css`), touching only the two skeleton components identified. No logic, data-fetching, or auth code involved. Re-run the same harness comparison after the fix to confirm both rows match, and spot-check the other two (already-passing) skeleton rows are untouched.

## Handoff to QA

After the fix, QA re-verifies row-height parity for all 4 skeleton row types (search user, search club, notification, discovery hashtag) against the full CSS cascade, re-confirms press-feedback and reduced-motion checks still pass (they were not affected by this bug and already passed), then re-runs `lint`/`typecheck`/`build`.
