# ZOKY store QR: LINE add-friend prompt

User report: scanning the store poster does not show the LINE add-friend screen.
Candidate base: `release/zoky-line-web-20261101`, `81b6a3a33a6fb716aa3a670beae9cf327fca220c`.
Local branch: `fix/zoky-qr-line-entry-20261105`.

## Cause and change

The QR generator already builds a LIFF URL with the store destination. The visible
web URL on the poster is a separate share link. The `/line` navigation flow
previously opened the store without checking friendship. Automatic ZOKY account
linking does not itself add the OA as a friend.

For store destinations in the customer LIFF browser, check friendship before
checking the ZOKY session. If the user is not a friend, await LINE's native
`requestFriendship()` add/unblock prompt before continuing to the same store.
Confirmed friends skip the prompt; native cancellation is respected. One shared
promise prevents duplicate prompts when the effect is replayed. Limit the lookup
to four seconds, leaving the user's time in the native prompt unrestricted.

The Founder confirmed the customer OA as `@732igmun`. When native friendship is
unavailable, open its official HTTPS profile once with `liff.openWindow` and keep
the original store on an add-friend screen. Its manual add-friend link still works
when automatic opening fails; the separate store action uses the exact safe
destination. Notification linking remains bounded best effort before this screen.
No friendship is forced and no successful friendship is inferred from dismissal.

No QR reissue, database change, new dependency, or authentication change is needed.
This displays a request; the customer still chooses whether to add/unblock the OA.

## LINE public configuration and fallback

Anonymous bootstrap for customer LIFF `2012311758-OEhTuU5V` confirms endpoint
`https://food.wynos.online/line`, `openid` and `profile`, and `hasLinkedBot:false`.
This is why a native-only change would still fail. The approved fixed-OA fallback
works independently of that missing binding. The official profile URL
`https://line.me/R/ti/p/%40732igmun` responds HTTP 200.

For the native subwindow, the LINE Login channel still needs the customer OA
linked and LIFF size `Full`. Full size cannot be verified from anonymous context.
No LINE management connection exists here, and these settings were not changed.

Official API: https://developers.line.biz/en/reference/liff/#request-friendship

## Verification

- `npm run test:line`: 15/15 pass. Covers waiting for dismissal, guests, existing
  friends, safe destinations, unsupported API, missing OA, native cancellation,
  fixed-OA fallback and stalled lookup with no late prompt.
- `npm run typecheck`: pass.
- Focused ESLint on the three changed source/test files: pass.
- `npx next build`: pass, including TypeScript and static page generation.
  This checks the Next.js application; the unrelated Flutter build was not run.
- `npm run test:share-links`: 19/19 pass. The pre-existing source-regex test
  expected the old direct share handler removed by the QR share sheet. The
  identical failure was reproduced at the unchanged base and in the first PR CI
  run. Updated it to check the current sheet's store data and share handler;
  retained sign-in return checks and the Merchant publication guard.
- Independent review found no blocker; its network-stall finding was addressed
  with a bounded friendship lookup and a regression test.
- Actual React component browser QA: 17/17 pass in Chromium with development
  StrictMode effect replay. Actual `LineEntry`, helper and CSS run against a fake
  SDK and fake guest client: missing OA/native error/unsupported SDK; once-only
  opening; manual action after opening throws; share-code and UUID store return;
  existing friend/native dismissal; unchanged Merchant/order/external-browser
  flows; rejected external destination; exact native cancellation; bounded
  friendship/session lookup and session rejection. No uncaught browser errors. Screenshot
  checked at 390 x 844. Evidence: `/workspace/scratch/line-browser-qa/artifacts/`.

No real customer data, database connection, production secrets or login tokens
were used. Physical iOS/Android LINE UI was not exercised; browser mocks do not
prove native display. The explicit profile-link and same-store screen provide the
supported fallback for the verified missing OA binding.

## Staging handoff

Founder authorized commit/push and staging on 2026-11-05, then explicitly directed
"จัดการให้สำเร็จ พร้อมใช้งานเลย", authorizing the controlled production release.
The scoped release workflow must stage, verify, and promote the exact artifact
through its existing production environment reviews and live-base guards.

Target the PR at `release/zoky-line-web-20261101`, because `main` has older
application source and is not the running ZOKY baseline. Automatic PR previews
are paused in the existing workflow; use a preview of the exact pushed candidate
in the existing Vercel `web` project without changing production aliases or
Deployment Protection. Record preview status and smoke evidence separately.

The printed QR and the production LIFF ID still open the production LIFF endpoint.
A preview alone cannot prove native LINE behavior: end-to-end scanning needs a
separate staging LIFF with its endpoint set to the preview `/line`. Browser mocks
can verify the candidate's SDK calls without connecting to customer data.

PR: https://github.com/warren-wyn-dev/wynteam/pull/1335

The first preview (`dpl_5azEJYbWif4VN6GsTCSn3UiupzRp`, candidate `9295499`)
remained queued with no build events. The authenticated fetch connector returned
`deployment_authentication_required`: its temporary share link was not accepted
by Vercel SSO. CLI fallback (`vercel@65.11.0 whoami --non-interactive`) reports
`Logged out`. No login, protection change or production deployment was performed.
Preview readiness, hosted smoke tests, native LINE verification and subsequent
CI status are not implied by passing local checks.
