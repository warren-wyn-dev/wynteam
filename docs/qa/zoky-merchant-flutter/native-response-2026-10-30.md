# Merchant navigation responsiveness and mobile app behavior

## Scope and authority

The Founder requested "แก้ไขให้เร็วที่สุด และ เหมือนแอปจริงที่สุด" after
reviewing the deployed Merchant performance measurements. Existing session
authorization for performance work, commit/push and a verified Merchant-only
release remains in force (company APPROVALS entry 2026-10-27). This iteration
retains Flutter and the current authentication/backend contracts.

Baseline source is `ddc1fc2bab58c39800db5766fe1970d1c46e3ebf`, currently served by
`dpl_HRTFBBHb6s6wpQZ69J1fgEERW5yP`. The baseline compiled main JavaScript was
preserved outside the repository and matches the public main JS SHA-256
`d957cb542975f07854e52759b55ec8de27be9c3480a10835a004d06ed93ff331`.

## Acceptance criteria

- Revisiting the main tabs retains menu search/filter and scroll state for the
  same account/store/role scope; changing scope discards retained private state.
- Hidden tabs exclude focus, pointer input and accessibility semantics; their
  animations and panel-specific polling remain inactive.
- Background order reads continue to leave existing menu actions available.
- Authorized Flutter engine preparation overlaps the authenticated React chunk;
  no view, bridge request or private data is created before the proper mount.
- Guests continue to download no Flutter runtime.
- A left-edge gesture inside Merchant Flutter never invokes the global Social
  back action. Document scroll policy applies only while Flutter is mounted;
  signed-out and legacy Merchant pages keep ordinary scrolling.
- Existing order/payment/refund, session/account-change and error recovery
  behavior passes the relevant regression suites before release.
- Compare compiled behavior against this deployed baseline under the same
  renderer, data, network and CPU conditions. Record actual observations;
  distinguish simulated observations from physical iPhone/Safari performance.

## Design boundaries

Retain visited tab widgets with standard Flutter lifecycle/layout primitives,
freeze inactive widget snapshots and rebuild the active page with the latest
controller state. Shorten navigation indicator animation without changing data
or mutation authorization. Do not introduce custom render-object layout rules.
Standard hidden widgets may still perform layout after constraint or independent
descendant changes; this design does not claim all hidden layout is eliminated.

Start the existing document-wide engine loader only within the authenticated
route boundary. Actual bridge setup, view creation, content/font readiness,
account generation guards and disposal remain with their existing owner.

Use the existing swipe-back opt-out and Merchant-host-scoped CSS for document
overscroll. Keep the existing PWA icons/manifest and avoid new install prompts.
An embedded-engine keyboard inset change requires separate validated work and is
not simulated with an unverified viewport flag in this iteration.

## Investigation: login readiness

The prior five slow/cold public samples showed login form appearance at
1.03–1.11 seconds and enabled readiness at 3.53–3.64 seconds, with no observed
Supabase/Auth ResourceTiming request in those guest samples. Hydration and the
shared application payload are material contributors. Do not remove the session
check or enable premature sign-in merely to improve this metric. No login/auth
architecture change is included without a verified safe implementation.

## Validation and release status

Implementation and initial independent review are complete. Flutter analyze and
96 tests, dual Wasm/JavaScript compilation, the font guard and Next production
build passed. Merchant Node 101 tests and the independent loader/routing/startup
18-case subset passed. TypeScript passed; ESLint reported zero errors and the
17 existing unrelated warnings. The final Chromium mobile/desktop browser suite
passed 48/48 in one full run, including the authorized concurrent-loading and
gesture/scroll restoration regressions, both compiled renderers and existing
order/payment flows. Test data is synthetic.

The reviewer identified a same-store replacement-repository state-isolation edge;
it was resolved with a repository-generation scope key and a regression included
in the full 96-test run. No unresolved CRITICAL/HIGH finding was reported.

WebKit was considered for additional verification, but its required system
libraries are unavailable and dependency installation needs OS privileges this
executor does not have. No WebKit or physical iPhone pass is claimed.

Controlled measurements are pending. This document does not claim a new
production release yet. Before staging, record exact source SHA and completed
measurement observations. Use the normal protected reviewed-source workflow
with automatic domain assignment disabled. Verify the staged artifact before
assigning only `merchant.wynos.online`.

Recovery mapping is the baseline Merchant deployment above; preserve all other
project aliases and record their mappings before and after a release. Do not
promote the whole project. No database/schema/payment contract, provider,
dependency, auth policy or private-data persistence changes are in scope.
