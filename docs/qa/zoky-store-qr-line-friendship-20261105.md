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
Existing friends skip the prompt. One shared promise prevents duplicate prompts
when the effect is replayed. Limit the network lookup to four seconds, while
leaving the user's time in the native prompt unrestricted. Unsupported clients,
lookup failures and prompt errors continue to the original store.

No QR reissue, database change, new dependency, or authentication change is needed.
This displays a request; the customer still chooses whether to add/unblock the OA.

## LINE configuration required

In LINE Developers, the customer LINE Login channel must link the customer OA.
Its LIFF app needs `profile` scope and screen size `Full`. Check the add-friend
option for first-time authorization as well. This configuration was not inspected
or modified; the repository contains no LINE Developers management connection.

Official API: https://developers.line.biz/en/reference/liff/#request-friendship

## Verification

- `npm run test:line`: 13/13 pass. Covers waiting for dismissal, guests (no ZOKY
  session access in the friendship helper), existing friends, destination
  restrictions, unsupported API, OA errors, rejected prompts, and stalled lookup
  with no late prompt.
- `npm run typecheck`: pass.
- Focused ESLint on the three changed source/test files: pass.
- `npx next build`: pass, including TypeScript and static page generation.
  This checks the Next.js application; the unrelated Flutter build was not run.
- `npm run test:share-links`: 18/19 pass. The pre-existing source-regex test
  `Food and Merchant are wired to the share link` expects the old direct share
  handler removed by the QR share sheet. The identical failure was reproduced in
  a separate unchanged worktree at the candidate base; left outside this fix.
- Independent review found no blocker; its network-stall finding was addressed
  with a bounded friendship lookup and a regression test.

No real customer data, database connection, production secrets or login tokens
were used. Native iOS/Android LINE prompt and real OA configuration remain to be
verified before release: non-friend, blocked OA, existing friend, guest, cancel,
and return to the same store.

## Staging handoff

Founder authorized committing/pushing the candidate and testing staging on
2026-11-05. Production deployment is outside that authorization and still requires
the repository's release gates.

Target the PR at `release/zoky-line-web-20261101`, because `main` has older
application source and is not the running ZOKY baseline. Automatic PR previews
are paused in the existing workflow; use a preview of the exact pushed candidate
in the existing Vercel `web` project without changing production aliases or
Deployment Protection. Record preview status and smoke evidence separately.

The printed QR and the production LIFF ID still open the production LIFF endpoint.
A preview alone cannot prove native LINE behavior: end-to-end scanning needs a
separate staging LIFF with its endpoint set to the preview `/line`. Browser mocks
can verify the candidate's SDK calls without connecting to customer data.
