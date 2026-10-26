# ZOKY Merchant stability QA — 2026-10-25–26

Status: three confirmed defects repaired and verified in source; the repair is not yet published to production. Do not interpret the earlier successful deployment smoke as authenticated production acceptance.

## Scope and baseline

The Founder reported that the published Merchant website was not stable and requested QA. Baseline is the released source `49e34d35657771949e26472fa14f1f4744955af0`, artifact `dpl_AzSiNf7cK7GfS7qboogk3YtR1q73`, at https://merchant.wynos.online/.

The story under test is entry from the Merchant origin, shared-account login, mounting the compiled Flutter UI, editing and saving during automatic refresh, receiving realtime order updates, switching destinations and recovering from network/read failures. Public checks run against the live guest pages; authenticated checks use isolated local synthetic sessions/bridges only. No production account, customer data, database connection, credential files or live mutation is used.

## Confirmed findings

| Priority | Trigger and observed behavior | Repair and regression boundary |
| --- | --- | --- |
| P1, routing | A guest enters the new Merchant `/` root and signs in. Shared return-path validation rejects `/`, and login's default destination is hardcoded `/merchant`, which renders the legacy interface. Warm-session entry at `/merchant/login` also defaults to the legacy interface. | Use the Merchant-origin root as the default after login, following its existing server-side feature flag. Preserve explicit safe return paths, payment callback routing and the legacy default on other origins. Verify a synthetic browser sign-in round trip. |
| P2, editing | A periodic refresh starts while an edit dialog is open. Save is still offered, but the controller returns false because a read makes `writable` false. The dialog records a terminal failed state, disabling fields and Save even after the refresh completes; the user must close and refill it. | Wait for the active read before deciding whether a write is allowed. Recheck store/access state and keep single-write protection. Verify that the existing draft saves exactly once when the read completes and does not write after access is revoked. |
| P2, realtime | A new order arrives after the current order-page read but before the rest of a refresh finishes. A refresh request during `loading` is dropped, so the order remains absent until the next 20-second poll. | Coalesce a trailing refresh without overlapping reads, indefinitely extending the active read or starving a queued write. Verify the late order becomes visible and repeated notifications do not block Save. |

The two Flutter failures were reproduced against the original source with synthetic delayed repository responses before applying fixes. The routing failure was verified against the original return-path module and an isolated browser fixture. These are functional stability findings; the checks did not establish a server outage or a customer-account authorization failure.

## Public production browser evidence

Four fresh Chromium profiles exercised root-to-login navigation, official logo loading, email/password controls, show/hide password, forgotten-password navigation, browser Back and reload. Input values were synthetic and were never submitted. All four profiles completed without a page exception, failed request, HTTP 4xx/5xx response or horizontal layout overflow. Signed-out entry downloaded no Flutter runtime assets.

| Profile | Root to ready login | Login reload | Login LCP | CLS |
| --- | ---: | ---: | ---: | ---: |
| Mobile, 390×844 | 5.02 s | 1.27 s | 4.16 s | 0.062 |
| Mobile, 390×844, simulated slow 4G and 4× CPU slowdown | 6.98 s | 1.50 s | 6.48 s | 0.061 |
| Desktop, 1440×1000 | 2.88 s | 1.23 s | 2.03 s | 0 |
| Small mobile, 320×568 | 5.10 s | 1.21 s | 4.07 s | 0 |

These are bounded lab observations from this execution environment, not field percentiles or a load test. The simulated network used 150 ms latency, 200,000 bytes/s download and 93,750 bytes/s upload. Ready time includes waiting for the logo and network idle. Cold guest pages transferred approximately 835–842 kB of resource bodies; the official PNG accounted for about 117 kB. Cold mobile loading remains a performance improvement opportunity, while reload and the tested controls completed successfully.

A read-only Vercel runtime query grouped by level returned no error/fatal groups for this exact deployment in the latest 30-minute window. The initial one-hour query was rejected by plan retention; no broader history, request payloads, runtime message bodies or credentials were retrieved. Server log absence does not establish client-side stability.

## Final regression and limitations

The controller fixes passed all 39 Flutter tests (30 existing plus nine new) and analysis. The new cases exercise a real editor during its 20-second poll, a 100-event burst, pagination notifications, duplicate writes, access revocation, server denial, continuous notifications without write starvation and view disposal. Merchant Node coverage passed 60 tests, including the three new behavioral auth-return cases.

The actual original compiled renderer reproduced the editor failure (zero writes, disabled form, dialog left open). The fixed compiled renderer preserved the entered name/price, waited for the read, wrote exactly once and closed its dialog in Chromium and WebKit. The durable browser regression is `merchant-flutter-stability.spec.ts`; it passed on Pixel 5 Chromium and iPhone 13 WebKit emulation. The baseline and fixed JavaScript were distinguished by their actual network-loaded SHA-256 hashes (`c2c9bde4…` versus `79a8aff9…`).

Bounded stress against the fixed compiled app passed four profiles: Chromium and WebKit, each at 390×844 and 1440×1000. Each profile completed ten four-destination navigation cycles, five edit-dialog open/type/close cycles, five engine-view remove/add cycles, orientation resize and simulated offline/recovery. Each ended with one Flutter view, no JavaScript page errors and no failed requests. The stress fixture made no writes; the focused save regression separately made exactly one synthetic write. This is WebKit engine/emulation coverage, not testing on physical Apple hardware.

The focused Merchant browser configuration now runs the already-built production server. Its isolated virtual Merchant hostname is deliberately intercepted and served from loopback; other network/WebSocket requests are blocked and auth/backend responses are synthetic. Next development-mode origin/HMR restrictions prevented that virtual-host fixture from hydrating, so these checks use the deployed production-mode behavior rather than relaxing the application's development/security configuration. Run `npm run check` or `npm run build` with synthetic public configuration before `npm run qa:merchant-flutter`.

Final integrated verification passed: lint, TypeScript, **393 Node test executions**, Flutter analysis/**39 tests**, release compilation/system-font guard and Next production build. A local dependency symlink initially prevented Turbopack from resolving Next; replacing it with the same installed dependency files inside the worktree fixed the build without changing application configuration or dependency versions. The new browser fixture's Window fields were made optional to describe their absence outside that isolated page; runtime assertions remain strict.

The focused production-mode browser suite passed **22/22 cases in 1.8 minutes** across mobile and desktop, including fresh Merchant-root sign-in, warm-session direct login, removable token-free embedding, load-error recovery, payment/ETA/delivery-photo flows, empty/offline/revoked-store account exits and the new editor race. Against the original production build, the same sign-in regression failed at the expected boundary: successful sign-in navigated to `/merchant` instead of `/`. Against the repair, both fresh and warm-session cases returned to the root and mounted one Flutter view. Independent source/security review found no blocker/HIGH.

Production was re-inspected during QA and still serves the baseline source `49e34d35657771949e26472fa14f1f4744955af0`. No release, rollback, database migration, authentication-provider change or live mutation was performed for this QA. Authenticated production acceptance with an actual store account and physical-device checks remain outside the synthetic evidence above. A repair is not published merely because a local test passes.
