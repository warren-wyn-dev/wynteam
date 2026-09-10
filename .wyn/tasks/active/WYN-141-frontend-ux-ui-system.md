# Product Task — WYN-141

Status: active — Founder approved; Admin implementation complete and verified, Flutter batches pending a Flutter-capable runner
Owner: AI Product Manager → AI Design → Founder review → AI Coding → AI QA & Security
Feature: WYNOS frontend UX/UI system upgrade
Goal: Make the existing WYNOS experience feel coherent, polished, responsive and accessible without changing product behavior or unrelated backend logic.
Target User: WYNOS consumer users on mobile/web and WYN Admin operators.
Problem: The repository has approved colors, typography, spacing and interaction tokens, but presentation patterns remain distributed across many screens. Loading/width behavior, loading/empty/error states, forms, dialogs and navigation require a systematic audit and staged consolidation.

## Requirements

1. Audit existing patterns before changing UI.
2. Preserve the approved WYNOS visual direction and Sapphire brand palette.
3. Establish reusable primitives for spacing, typography, buttons, inputs, cards, modals, list rows, loading, empty and error states.
4. Apply mobile-first responsive rules to auth/onboarding, navigation, feed, content detail, search/discovery, notifications, profile/settings, Clubs, Chat and Admin.
5. Improve hierarchy, scanability, contrast, touch targets, keyboard/focus behavior and semantic labels.
6. Preserve existing features, routes, authorization, data flows and business logic.
7. Do not add Check-in or other new product functionality.
8. Gate any new user-facing behavior behind the existing developer-account staged rollout unless it is a pure bug/accessibility fix.
9. Implement one surface batch at a time; lint, test and build after every major batch and stop on regression.
10. Show a visual artifact to Founder and receive approval before production UI implementation, per the standing Founder decision.

## Acceptance Criteria

- Audit documents current inconsistencies with reproducible counts/examples.
- Founder-approved responsive visual spec exists before Coding.
- Shared primitives have explicit default, pressed, focused, disabled, loading, empty and error behavior.
- Mobile checks cover 320/390/430px; responsive checks cover 768/1024/1440px; text scaling covers at least 1.0/1.3/2.0 where Flutter supports it.
- Existing navigation and business actions remain behaviorally unchanged.
- Each implementation batch passes relevant lint, tests and build before the next starts.
- QA reports regressions before rollout continues.

Dependencies: Existing DS-001, DS-008, DS-010, WYN-106, WYN-107, WYN-140 and developer-account rollout WYN-125.
Priority: High — quality/platform consistency; lower than unresolved P0 security or availability incidents.
Risks: Broad visual blast radius, responsive overflow, gesture conflicts, accessibility regressions and accidental product-flow changes.
Recommendation: Approve the attached system preview, then execute the staged batches in `.wyn/docs/design/wyn-141-frontend-ux-ui-system.md`.
Handoff: Founder visual review → AI Coding after approval.

## Founder Approval — 2026-09-08

Founder reviewed the Product/Design milestone and instructed “ทำให้เสร็จเลยนะ”. Visual approval gate passed;
Coding may proceed under the existing scope and staged-rollout safeguards.

## Coding Batch 1 — Admin responsive/accessibility shell

Implementation:

- Added a keyboard-visible skip link and focusable main landmark.
- Converted the fixed desktop-only sidebar into an adaptive desktop sidebar/mobile bottom navigation without changing destinations.
- Added a bounded 1180px content rail, mobile bottom-nav clearance and resilient `min-width: 0` layout behavior.
- Made the header sticky/compact, hides secondary email at constrained widths and preserves role/sign-out actions.
- Raised shared Admin buttons/inputs to accessible mobile touch/input sizes.
- Added a global reduced-motion override that honors OS preference.

Files Changed:

- `admin/app/(admin)/layout.tsx`
- `admin/app/globals.css`
- `admin/components/admin/header.tsx`
- `admin/components/admin/sidebar.tsx`
- `admin/components/ui/button.tsx`
- `admin/components/ui/input.tsx`
- `admin/components/ui/textarea.tsx`

Reason: This batch changes the shared presentation shell/primitives, so every Admin surface benefits without duplicating per-page styling or touching data/auth logic.

Tests:

- `npm run lint` — PASS
- `npx next typegen` — PASS
- `npx tsc --noEmit` — PASS

Build:

- `NEXT_PUBLIC_SUPABASE_URL=https://example.supabase.co NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=test-key npm run build` — PASS; all 10 routes generated/compiled.

Known Issues:

- Current environment has no Flutter SDK. Downloading Flutter 3.47.1 from Google Storage is blocked by the network proxy (`403 Forbidden`), so broad Flutter shared-widget changes cannot meet the mandatory lint/test/build gate here.
- No browser binary/screenshot renderer is installed, so responsive Admin visuals still require CI/browser/device QA despite compile-time checks passing.

Handoff: AI QA & Security for the Admin batch; continue Flutter batches only on a runner with Flutter 3.47.1.


## Founder final visual reference — 2026-09-10

The final Profile and Post Detail screenshots supplied directly by the Founder supersede conflicting older TSX composition for those two surfaces. Implementation target is screenshot-level visual parity while preserving Beta4 behavior and backend contracts; the only required data addition is `profiles.cover_url` for the visible profile cover.
