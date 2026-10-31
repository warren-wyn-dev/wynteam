# Merchant navigation responsiveness and mobile app behavior

## Scope and authority

The Founder requested "แก้ไขให้เร็วที่สุด และ เหมือนแอปจริงที่สุด" after
reviewing the deployed Merchant performance measurements. Existing session
authorization for performance work, commit/push and a verified Merchant-only
release remains in force (company APPROVALS entry 2026-10-27). This iteration
retains Flutter and the current authentication/backend contracts.

Baseline source is `ddc1fc2bab58c39800db5766fe1970d1c46e3ebf`, served at the start of this iteration by
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

## Completed controlled measurements

Measured application commit: `ff481b65cf08bae590b42430ca60a3f390869e94`.
The comparison retained all 20 samples: five alternating paired trials per
source, each with cold browser-context navigation and same-context HTTP reload.
Both sources used CanvasKit, identical engine bytes, hashed immutable asset
caching, a content-ready cover, an invented five-item menu and 150-ms bridge read
delays. Chromium 153 used a 390×844 viewport, DPR 2, CPU slowdown 4×, 150-ms
network latency and 1.6-Mbps download. No concurrent browser/build workload ran
during the measurement window.

| Laboratory endpoint (median) | Deployed baseline | Candidate |
| --- | ---: | ---: |
| Cold dashboard Finance-actionable | 20.024 s | 20.200 s |
| Cold first menu touch to observed action-ready frame | 988.4 ms | 981.7 ms |
| Warm HTTP-reload dashboard Finance-actionable | 3.574 s | 3.614 s |
| Warm first menu touch to observed action-ready frame | 765.1 ms | 763.7 ms |
| Cold-run menu revisits, two predetermined sequence positions pooled | 599.2 ms | 505.2 ms |
| Warm-run menu revisits, same two sequence positions pooled | 576.4 ms | 490.4 ms |

Startup and first-menu readiness remain similar in these observations. Repeated
menu visits have lower pooled medians, about 15–16%, under this laboratory
profile. Each pooled cell contains two related observations from each of five
runs, not ten independent trials; per-position n=5 medians/ranges and every raw
sample are retained in the session evidence. This is not a universal speed
percentage, field INP, physical display presentation or an iPhone/Safari result.
The endpoint observes selected semantics and expected content followed by two
animation-frame callbacks. It includes browser frame-queue time and is not a
direct first-paint measurement. The bare Flutter fixture also omits Next
authentication, the production API bridge and the separate engine/chunk overlap.

There were zero page/host errors and zero failed requests across all 20 samples.
Menu controls remained actionable throughout sampled background order refresh in
both versions; that behavior was already fixed in the baseline.

A separate 40-item functional check confirms the candidate preserves the typed
menu search text after switching away and back; the baseline field becomes
blank while its parent filter remains applied. Paired canvas screenshots and
refocused editor values agree. An unfocused Flutter semantic input can expose an
empty DOM value even while the canvas correctly shows text, so it is not used
alone as the assertion. Scroll geometry restores and hidden-menu semantics are
absent in both versions; these are regression checks rather than new baseline
gains.

Candidate local main JavaScript SHA-256 is
`c84f98a734ac0d7eb2b8721381a0422b0f4d43893a2fe14111bebe9287249912`, under
`/merchant-flutter/builds/5d6b09d13158a63e9402/`. Session evidence is retained in
`/workspace/merchant-native-response/benchmark/` (method, raw results, summary,
artifact provenance, functional state JSON and paired screenshots).

## Release procedure

Use the normal protected reviewed-source workflow with automatic domain
assignment disabled. The exact release revision may add documentation only to
the measured application commit; verify the runtime files remain identical.
Verify the staged artifact before assigning only `merchant.wynos.online`.
Record the final workflow, deployment, source SHA, smoke result and alias mapping
separately after those gates pass. The measurements above do not themselves
claim that a new production release has occurred.

Recovery mapping is the baseline Merchant deployment above; preserve all other
project aliases and record their mappings before and after a release. Do not
promote the whole project. No database/schema/payment contract, provider,
dependency, auth policy or private-data persistence changes are in scope.
