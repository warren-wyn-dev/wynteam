# Product Task — WYN-141

Status: active — Founder approved; Admin implementation complete and verified. Flutter SDK infra blocker resolved 2026-09-20 (see note below); Flutter batches 2-6 not yet implemented
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

## Infra blocker resolved (2026-09-20, web-beta1-readiness audit)

Re-tested the "no Flutter SDK / network 403" claim above in a fresh session — this sandbox instance could reach `storage.googleapis.com` fine. Downloaded Flutter 3.47.1 (matching the exact version CI pins in `.github/workflows/ci.yml`/`deploy-web.yml`), verified the SHA-256 against Google's own release manifest, ran `flutter pub get` (clean), `flutter analyze` (**no issues found**), and the full `flutter test` suite (**1521 passed, 0 failed** — baseline has grown since the 725/725 figure recorded in the WYN-P0 Google sign-in bug report months ago). The SDK-availability blocker that stopped Batches 2-6 from starting is gone.

**What is still genuinely missing, and is a different constraint than the SDK**: this sandbox has no Android SDK, no Chrome, no Linux GTK libs (`flutter doctor` confirms all three) — so there is no way to actually *render* the Flutter app here, on a device, emulator, or even `flutter run -d chrome`. Batches 2-6 are a full-app UI rollout (Auth/nav shell, Feed/content, Search/notifications/profile/settings, Clubs/chat, plus the closing responsive/accessibility QA pass) across a **live production app with real users** — writing that much UI code without any way to see it render, on a codebase this rigorous about independent visual verification (every other task in this repo gets a real-device Founder check before closing), is a real risk of shipping something broken that nobody — including this session — actually looked at. `flutter analyze`/`flutter test` passing proves the code compiles and existing behavior isn't broken; it proves nothing about whether a redesigned screen looks right.

Recommendation: do **not** blind-implement Batches 2-6 in one pass. Next safe step is Batch 1 (tokens/primitives — `lib/core/design/wyn_colors.dart`, `wyn_spacing.dart`, `wyn_theme.dart`, `wyn_typography.dart`, `lib/core/widgets/`) since primitive-level changes are unit/widget-testable without visual rendering; screen-level batches (2-6) should wait until there's a way to visually verify (a Flutter-capable runner with a simulator/device, or the Founder available to spot-check each batch on their own phone before the next one starts) — consistent with this task's own Requirement #10 and #9.

### Correction — Flutter web + CanvasKit rendering does work here (2026-09-20, same audit)

The "no way to visually verify" claim above was too pessimistic. `app/web/` is a real (if unused-for-production) Flutter target: `flutter build web --release` compiles successfully, and `flutter devices` detects a usable Chrome target once `CHROME_EXECUTABLE` points at the Playwright Chromium already present in this sandbox (`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`). CanvasKit defaults to fetching from `gstatic.com`, which the sandbox proxy blocks, but patching the loader config to use the already-bundled local `canvaskit/` folder fixes that. Result: a real, pixel-accurate (same Skia/CanvasKit renderer Flutter uses on-device) screenshot of the Welcome screen, taken via Playwright — confirms WYNOS/BETA wordmark, Thai tagline and the `เริ่มต้นใช้งาน` CTA render correctly.

**What this does and doesn't unlock**: this makes **unauthenticated screens** (Welcome, Auth method picker, sign-up/sign-in) genuinely visually verifiable in this sandbox — good enough to safely start Batch 2 (Auth/navigation shell) for the Auth portion. It does **not** unlock the screens that need a live Supabase session (Home, Feed, Profile, Search, Notifications, Settings, Clubs, Chat) — every other role in this codebase has hit that exact wall (no Supabase backend in sandbox), and screenshotting Flutter-web doesn't change that; those screens in Batches 2 (nav shell)-5 still need either a live backend connection or Founder device spot-checks per batch before shipping.


## Founder final visual reference — 2026-09-10

The final Profile and Post Detail screenshots supplied directly by the Founder supersede conflicting older TSX composition for those two surfaces. Implementation target is screenshot-level visual parity while preserving Beta4 behavior and backend contracts; the only required data addition is `profiles.cover_url` for the visible profile cover.
