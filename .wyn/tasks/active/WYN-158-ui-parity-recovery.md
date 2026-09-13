# WYN-158 — UI Parity Recovery

Status: ACTIVE
Date: 2026-09-13
Owner: Founder

## Why this recovery exists

The Next.js production cutover succeeded technically, but the live consumer web exposed a visual/UX parity gap: the signed-out route still showed an internal migration/test shell instead of the Founder-approved Flutter WYNOS experience. Automated Phase 4 checks proved browser stability, routing, DOM rendering, fonts and overflow behavior; they did not prove screenshot-level visual parity.

WYN-158 must therefore remain active until the Next.js consumer web is visually and behaviorally reconciled against the Flutter implementation as the golden master.

## Golden-master rule

- Flutter `app/` is the visual/interaction reference.
- Preserve Next.js/React DOM rendering, browser/OS system fonts and existing Supabase contracts.
- Do not redesign screens while migrating them.
- Do not change Supabase Auth/RLS/RPC/storage contracts for visual parity work.
- Do not automatically roll production back to an older WYNOS version.

## Recovery sequence

1. Welcome/Auth + root navigation shell.
2. Home + post cards/detail/composer.
3. Search + Profile.
4. Notifications + Chat + Settings.
5. Deep-link states, loading/empty/error states and final visual regression gate.

## First recovery tranche

Branch: `feat/wyn-158-ui-parity-recovery`

- Replace the signed-out Next.js test shell with Flutter-parity Welcome.
- Restore WYNOS/BETA wordmark, original Thai tagline and bottom-anchored `เริ่มต้นใช้งาน` CTA.
- Restore Auth Method flow for Google and email.
- Restore email sign-up/sign-in surface.
- Reconcile bottom navigation height, labels, icon sizing and 56px circular create action with the Flutter Founder metrics.
- Add browser QA that fails if the old `Next.js Web รุ่นทดสอบภายใน` shell returns.

## Completion rule

Do not mark this recovery complete from route/browser smoke tests alone. Each screen group must be compared against the Flutter golden master for structure, copy, spacing, typography, colors, radius, safe-area behavior, interactions and state transitions. Final completion requires a real-iPhone Safari check of the recovered production UI.
