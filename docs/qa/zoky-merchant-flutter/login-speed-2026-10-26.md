# Merchant login cold-start verification — 2026-10-26

## Scope and behavior

This is local candidate evidence on the `49e34d35657771949e26472fa14f1f4744955af0` release baseline plus the Merchant stability repairs. It is not a production deployment record. Another release advanced production during this work; the release owner must rebase the candidate onto the observed live source and rerun release verification before publishing.

The public Merchant login logo and empty form now render in the initial HTML. Inputs, password visibility control and submission remain disabled until the existing shared session check completes. A retained session still returns to the authorized Merchant home. No account, token or store data is server-rendered by this change.

The official PNG remains byte-for-byte unchanged (SHA-256 `d586308c23b45aa9533cbce1e2512597a22ce43611e2bcbeb62c05f09823b022`). Next Image serves an appropriately sized derivative and preloads the login logo. The authenticated Flutter wrapper, bridge and helpers load after the existing shared gate accepts a session. The copied bridge/view lifecycle, account key, disposal and token-free Dart boundary remain unchanged.

Independent review identified a new failure boundary when the deferred JavaScript chunk cannot load. The import now catches that failure and shows Merchant retry and `/merchant` recovery before starting the engine. A browser regression aborts the compiled authenticated chunk and checks both recovery actions, zero engine requests and absence of a bridge.

## Validation

- Next.js 16.4.3 production build, TypeScript, targeted ESLint and `git diff --check`: pass.
- Merchant Node tests: 60/60 pass after the final application change.
- Focused Chromium mobile and desktop: all 24 existing/public-SSR cases pass; the two new chunk-failure cases pass in a separate targeted run after correcting a test's ARIA-role selector. The initial full 26-case run had only those two selector failures; the recovery UI was already present. The release candidate on the refreshed production base still needs its complete final run.
- Coverage includes fresh root sign-in, warm direct-login return, public form without JavaScript, disabled session-dependent controls, one removable view, shared-session sign-out, token-free bridge, bootstrap failure recovery, actual compiled payment/photo flows, denied/offline access and saving an editor draft during a held refresh.
- Independent source review found no unresolved CRITICAL/HIGH issue. The additional MEDIUM chunk-load recovery finding was fixed and its forced-failure browser cases pass.

## Controlled root-entry measurement

Before and after use the same local production server, hostname-preserving loopback proxy at port 3015, Thai locale, fresh browser contexts and blocked service workers. The proxy sends `Host: merchant.wynos.online`; its upstream is port 3013. Vercel analytics endpoints are stubbed in both root measurements. No real account, customer data or backend mutation is used. The final after run executes after browser tests finish, without overlapping test load.

The slow mobile profile is 390 × 844, 150 ms network latency, 200,000 bytes/s download, 93,750 bytes/s upload and 4× CPU throttling. These are single controlled observations, not field percentiles or an uptime guarantee.

| Root-entry metric | Before | Final after |
| --- | ---: | ---: |
| Public form visible | 4,335 ms | 3,772 ms |
| Largest contentful paint | 5,056 ms | 3,792 ms |
| Login submit enabled | Not separately captured | 3,878 ms |
| Network idle / completed observation | 5,554 ms | 4,923 ms |
| Encoded resource bodies | 720,283 bytes | 594,903 bytes |
| Encoded logo | 117,204 bytes | 4,616 bytes |
| Cumulative layout shift | 0.0611 | 0 |

`Public form visible` measures rendering; it does not mean authentication is ready. `Login submit enabled` explicitly waits for the shared session check. `Network idle` includes Playwright's quiet period and is not an interaction metric. Root routing retains the existing client-side session gate, so root entry still has that cost. Direct `/merchant/login` also verifies the public form/brand in HTML with JavaScript disabled; it is not used as a substitute for the root timing comparison.

The final root guest measurements at mobile, slow mobile and desktop all return HTTP 200 with no JavaScript exceptions, failed requests or horizontal overflow. None downloads the authenticated wrapper chunk (`1_txp19-36zer.js` in this build) or a `/merchant-flutter/` engine resource.

Local audit artifacts: `/workspace/scratch/merchant-login-speed-root-baseline.json`, `merchant-login-speed-root-final.json`, `merchant-login-speed-final-build.log`, `merchant-login-speed-final-node.log`, `merchant-login-speed-final-browser.log` and `merchant-login-speed-chunk-recovery.log`. They contain only synthetic/local verification data. Production publication remains governed by the release workflow and its separate reviews.
