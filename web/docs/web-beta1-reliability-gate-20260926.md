# WYNOS Web Beta 1 — reliability gate (2026-09-26)

Owner request: finish four reliability areas: social-state consistency; degraded-network publication; installed-phone/PWA UX; measured runtime performance and error recovery.

**Do not mark the entire gate passed merely because a local browser suite or production route smoke passes.** This release extends existing Web Beta 1; it must not revert to an old baseline.

## 1. Social data correctness

- Acquire a synchronous lock per scope/account/post/action **before** any optimistic update. Home, Profile, Detail, Club, and Quote use the same guard. An in-flight save doesn't block an independent like.
- Publish changes across mounted tabs and routes using the existing session-local event bus. On failure, publish a rollback and re-fetch authoritative server state. A confirmed offline signal blocks attempts before optimistic changes.
- Explicit Undo uses the same lock as Save. Tap Like/Save/Repost repeatedly while a request is pending; verify only one mutation runs, the selected state and counters agree across Feed/Profile/Detail when the request settles. Simulate network failures, verify rollback.
- The lock is local to one browser session; cross-device authoritative synchronization is still the backend's responsibility. A tap made while its first mutation is pending is ignored rather than queued. This prevents duplicate requests without promising that every rapid second tap is applied.

## 2. Offline, slow upload and publication recovery

- Composer must retain caption and selected files when offline and refuse to publish until connectivity is available.
- A synchronous in-component publish lock blocks double submission before React can paint its disabled button.
- Text/image Drop retries reuse the same publication operation ID **only if the input is identical** after an ambiguous transport failure, so an already-committed post is reconciled instead of duplicated.
- The existing serial draft autosave retries when an online event fires, and drafts are never deleted until a confirmed publication.
- Poll publication does not yet have a server-side idempotency key. On ambiguous poll failure, require the user to check Feed before resubmitting. Do not claim a guaranteed exactly-once poll write.
- Test on throttled Fast 3G, intermittent offline, upload interruption after 1/N images, returning online and navigating away/back. Confirm recovery of author text and uploaded media. A web application cannot guarantee retention of user-selected files if its entire tab is force-killed before remote autosave; this limitation must be part of the release QA.

## 3. Installed PWA / physical device gate

Automated Playwright WebKit iPhone and Chromium Android tests are **emulation**, not physical-device approval. The existing checklist `web/docs/web-beta1-phase1-mobile-qa.md` must be completed on:
- iPhone Safari + installed Home Screen PWA, including iOS white status area, bottom safe area, Feed scroll down/up, composer keyboard and tab refresh.
- Android Chrome + installed PWA, including scroll restoration after viewing a post, offline launch, image selection and resuming after backgrounding.
- Push opt-in/out, opening notification URLs, and signing out user A and into user B without showing A's private push content.
- At least one simulated slow/mobile connection during caption/image publication. Record hardware model, OS/browser version, commit and pass/fail; never log user content, tokens or private push payloads.

**Release blocker:** physical device results are pending until a person actually performs and records these checks. Browser green alone is not evidence of hardware success.

## 4. Observability, performance and recovery

- Root layout already includes Vercel Web Analytics and Speed Insights for field LCP, INP and CLS.
- Client monitor adds only a bounded `beta1_client_failure` custom event with `kind` and coarse `area`. Never send a user id, post id, error message, error stack, full URL/query, or private content. Unexpected route errors present a retryable recovery screen rather than a blank app.
- Record production field **p75** LCP <= 2.5 s, INP <= 200 ms, CLS <= 0.1, split by mobile and route where sufficient traffic exists. Record failure-event trend, repeat-session crashes and failed write rates for at least seven days after release.
- Correlate error-rate changes and performance regressions with the deployed commit. If custom events are unavailable under the current analytics plan, explicitly record that monitoring blind spot and use available Vercel runtime logs.
- Do not invent field measurements: this session's Vercel connector did not list a team/project, so actual analytics and grouped runtime errors could not be retrieved.

## Release sequence

1. Branch-only implementation + unit/source tests + Web Next.js CI + full browser QA.
2. Production preview/manual functional verification with test accounts; physical iPhone and Android gates where available.
3. Explicit founder approval for production deploy after QA evidence; release with the current main as baseline.
4. Verify production route smoke, user-gesture flows, Speed Insights and error telemetry. Preserve the merge commit for a narrowly scoped revert if needed. Never automatically roll back the founder's baseline.
