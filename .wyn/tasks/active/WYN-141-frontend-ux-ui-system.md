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

## Founder Direction Amendment — 2026-09-12

Founder: "ชอบ UX UI ของเธรด ปรับให้หน่อย ทุกหน้า ยกเว้นโปรไฟล์ จัดดีแล้ว" + "อยากให้ดูโปรไฟล์เป็น แล้วปรับทุกหน้าให้ไปในทิศทางเดียวกัน"

Clarified with Founder (AskUserQuestion, 2026-09-12):

1. "Other Profile" (design-reference `18-other-profile.tsx`) is **not** automatically covered by the Profile exemption — it must still be audited/adjusted.
2. Post Detail (`07-post-detail.tsx`), despite receiving its own Founder-final screenshot on 2026-09-10, must **also** be re-aligned to the new Profile-led direction — it is not exempt.
3. Scope for this round is the **WYNOS mobile app only** (design-reference `01`–`22` except `05-profile`). Admin/back office is explicitly **out of scope**.

### Requirements (amendment)

1. Treat the Founder-approved final **Profile** screenshot (2026-09-10) as the single visual north star for the whole WYNOS mobile app — not just a one-off fix for the Profile screen.
2. AI Design re-audits every in-scope mobile screen (`design-reference/01,02,03,04,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22`) against Profile's realized direction — surface/card/row treatment, spacing rhythm, typography weight, header/nav chrome, iconography, accent usage — and documents concrete deltas per screen.
3. Post Detail and Other Profile get their own explicit before/after rationale in the revised spec; neither may be carried over unchanged just because an earlier reference existed for them.
4. No new accent colors or token deviations — apply the existing Sapphire palette / `SPEC.md` tokens more consistently, matching Profile's application of them.
5. Preserve existing navigation, business logic, auth/authorization and data contracts (same constraint as the base WYN-141 task) — this is a visual/pattern-consistency pass, not a feature change.
6. Admin is unaffected by this amendment.

### Acceptance Criteria (amendment)

- Revised design spec explicitly cites the Profile final screenshot as the reference and covers all in-scope screens listed above.
- Post Detail and Other Profile each have a stated before/after rationale (not marked "no change needed" by default).
- No proposed change alters navigation destinations, business logic, or data flows.
- No tokens/colors introduced outside approved SPEC.md + Sapphire palette.
- Founder visual approval obtained on the revised spec before Coding resumes any further non-Admin batch.

### Known Blocker

No screenshot files for Profile/Post Detail exist in this repository (checked — not committed anywhere under the working tree). AI Design will need the Founder to re-share the reference image(s) in-session before producing the revised spec.

### Data Integrity Issue Found (unrelated to this amendment, flagged for Founder)

`.wyn/company/DECISIONS.md` — a mandatory read-before-work file for every AI role — is corrupted: it is binary data, not valid text (confirmed with `file`, and it has been binary since the single commit that introduced it, `c385739`, same on `origin/main`). Per `.wyn/company/RULES.md` ("Founder Feedback" section), this amendment should normally also be logged there, but it could not be appended safely. Recording it here instead as the interim durable record. Recommend Founder/DevOps restore or rebuild `DECISIONS.md` from an earlier good source if one exists.

Handoff: AI Design — produce the revised WYN-141 spec per this amendment; request Founder re-share the Profile/Post Detail reference image(s); then Founder visual approval before Coding resumes.
