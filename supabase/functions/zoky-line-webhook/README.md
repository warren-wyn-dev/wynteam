# Zoky Merchant LINE OA integration — staging-only

**Status:** protocol scaffolding and tests only, **NOT a live integration**.

- LINE OA Bot basic ID: `@620wwvcd`.
- Vercel Merchant: `https://merchant.wynos.online/` (shared `web` project).
- Its production Supabase ref was observed as `kqokpocajhfbidcxpvhh`. This database is shared with other brands: never mix stores or cross-send customer/order data.

## Current files

- `handler.mjs` + `index.ts`: HMAC-SHA256 verification over raw webhook bytes. Signed LINE URL verification with `events: []` returns HTTP 200; **all signed non-empty events return 503** until durable processing exists.
- `account-link.mjs`: cryptographically generated 256-bit nonce; fixed-origin LINE accountLink redirect builder; accountLink webhook event shape validation.
- `line-api.mjs`: server-only issuing of LINE link tokens with supplied backend secret. This helper is not invoked yet. `makeLinkPrompt` references a **planned route** `/merchant/line-connect` which does not exist yet; do not send that card until route and sessions are implemented.
- `order-card.mjs`: example Flex card and strict postback parser; **not connected to any order handler**.

## Required work before enabling any real event

1. Review current Zoky Merchant auth/session system for Flutter and legacy Next.js. Confirm account/store mapping and that all roles can be revoked immediately.
2. Implement one-time link nonce storage, bounded 10-minute expiry, server-side issuance, atomic consumption, and unique constraints; provide secure self-service unlink. Build migrations offline and test RLS against multi-store access.
3. Serve authenticated route `/merchant/line-connect`. Authenticate the Merchant user, pick/confirm the store, validate token, create nonce, record it and redirect only to LINE's accountLink endpoint. Authenticate against fresh membership from the server, not from user metadata or URL parameters.
4. Handle verified `accountLink` events in idempotent durable storage. A failed or unmatched accountLink event must not attach a LINE ID. No LINE identifier may grant staff access by itself.
5. Implement order alert outbox only after payment/business eligibility, with retries, deduplication and rate limits. Never send customer address, phone or payment slips in LINE.
6. Treat postback as an *untrusted* action proposal: verify sender, active store membership, correct store/order, payment/refund state and existing order status. Existing `public.food_transition_order` checks `auth.uid()` and cannot be called with service role as if it were an authenticated merchant. Use a reviewed atomic transition that preserves all existing order/refund side effects.
7. Stage full end-to-end multi-store and race tests, obtain owner approval separately for each production migration, secret injection, Edge Function deploy and LINE Webhook change.

## Manual LINE and secret steps — only after staging succeeds

- The owner adds OA as friend; this has been done for their LINE account.
- Store `ZOKY_LINE_CHANNEL_SECRET` and `ZOKY_LINE_CHANNEL_ACCESS_TOKEN` only in Supabase Edge Functions Secrets (never in chat, GitHub, browser code, screenshots or public logs).
- After a deployed, tested real HTTPS endpoint exists, configure it as the LINE Developers Webhook URL; click Verify and enable Use webhook. **No guessed URL should be entered now.**

## Tests

- `deno check supabase/functions/*/index.ts`
- `deno test --allow-read supabase/functions/`
- `node --test web/tests/zoky-line-webhook.test.mjs`

The PR is Draft, not production-approved. No database, LINE account or Vercel setting was modified by this branch.

## Update: account-link authorization contract (not wired to production)

- `link-flow.mjs`: orchestrates the merchant-side link request with a 10-minute cryptographically random nonce, stores only its SHA-256 digest, and consumes a verified LINE `accountLink` event via an injected, **atomic** repository. Its inputs **must** come from a trusted Supabase Auth user session, not user-provided user ID.
- `web/tests/zoky-line-link-flow.test.mjs`: Node tests for first successful link, replay rejection, revoked role, and expired nonce with a test-only fake store. Tests of an in-memory fake do **not** prove PostgreSQL atomicity.
- `docs/engineering/zoky-line-link-schema-draft.sql`: review-only private-by-default tables plus transactional RPC design; it is **NOT a migration and has NOT been executed**. Production order data is unchanged.
- Next: review the SQL and write the actual repository adapter and Merchant callback page on this isolated branch, then run disposable-database/RLS tests before considering any staging deployment.
