# WYNOS Food Android — staging-only order creation contract (2026-10-14)

**Scope:** Native Kotlin/Compose debug preview, not a production checkout. This
branch must never be merged/released with staging order creation enabled.
Existing site, WYNOS Merchant, Supabase Production and Stripe are unchanged.

## Read-only production contract review

Verified live SQL RPC signature using a read-only catalog query:

`food_create_order(p_store_id uuid, p_recipient_name text, p_recipient_phone text,
p_shipping_address text, p_customer_note text, p_items jsonb,
p_latitude double precision default null, p_longitude double precision default null)`

- Server calculates authoritative prices, option surcharges, delivery fees and
  promotions. Android sends **no** final prices.
- The **legacy** RPC creates an order immediately with
  `status=pending_acceptance` and `payment_status=pending`.
- **No server-side idempotency key** is accepted by this RPC. A network timeout
  may mean the order was created despite a failed client response.
- Server rate limiting is useful but **not** a duplicate-payment solution.
- Therefore production/release APKs must always set
  `STAGING_ORDER_CREATION_ALLOWED=false`.

## NEW — buyer-scoped idempotent RPC proposed in next Draft PR

A dedicated local migration (NOT deployed) now adds
`public.food_create_order_idempotent(p_attempt_id, ...)` and private
`internal.food_mobile_order_attempts`. Within one Postgres transaction it
serializes each authenticated buyer/attempt ID, invokes the existing
server-authoritative `food_create_order`, and stores the returned order ID.
An identical replay returns the same order ID; a changed cart/address with
the same attempt ID fails closed. Anonymous callers and direct reads of
the attempt ledger are denied. The test suite verifies those properties on
a throwaway PostgreSQL database.

The Native staging-only gateway now calls this RPC, NOT the legacy
non-idempotent RPC. A unique attempt UUID is generated before network I/O,
retained in the ViewModel, and shown if the result is uncertain. No automatic
resubmission or payment is enabled; a full mobile payment order-intent
contract must still be designed, tested and deployed separately. Process
death / reinstall persistence of attempt references and cross-device
reconciliation remain release blockers. Do not turn this on in any
production or release APK.

**Important:** The existing Stripe Sandbox lacks the full Food staging
schema and does not yet have this migration. The test flag cannot
successfully submit orders until an isolated disposable full-parity Food
staging database is prepared and this migration is applied there.

## Staging-only debug opt in

Only use an isolated *disposable* Food staging project with matching
food_public_catalog, food_quote_order, food_create_order and address policies,
plus seeded fake stores, fake test users and merchant test fixtures:

```properties
WYNOS_FOOD_SUPABASE_URL=https://<20-char-nonprod-ref>.supabase.co
WYNOS_FOOD_SUPABASE_PUBLISHABLE_KEY=<public-staging-key>
WYNOS_FOOD_STAGING_PROJECT_REF=<20-char-nonprod-ref>
WYNOS_FOOD_ORDER_CREATION_STAGING=true
```

The debug Gradle flag requires an exact staging project/ref match and
explicitly rejects the current Production ref. Release ALWAYS turns the
feature off. Do not add service role/Stripe secret keys to mobile builds.

Existing WYNOS Stripe Sandbox project does **not** have the Food catalog,
quote, address and merchant fixtures needed for order E2E. The UI can compile
and show its guarded path, but **end-to-end staging checkout is blocked**
until those services and fixtures are actually available.

## Functional and safety QA before production work

- [ ] Confirm never available in any production-configured/release build.
- [ ] On disposable staging, sign in, create address with valid pin, select
  menu with add-ons and a note, get server quote, review totals.
- [ ] Verify explicit second confirmation, and only one order request even
  with rapid taps/recomposition; no retry after any uncertain response.
- [ ] Verify returned order ID exists and is buyer-owned, notes/options
  match, Merchant sees order, and read-only order history reconciles.
- [ ] Kill network after request reaches server: app must show uncertain
  result and **must not retry automatically**; reconcile manually.
- [ ] Confirm no Stripe payment, live charge, webhook, delivery dispatch,
  email or production mutation can occur through this staging workflow.
- [ ] Unit tests and Android CI build/lint pass.

## Release blockers (must be addressed separately)

1. Add server-side **idempotent** mobile order-intent API with authenticated
   buyer, unique attempt ID, durable price snapshot and atomic order creation.
2. Design/test server-verified Stripe mobile PaymentIntent/PaymentSheet
   contract and webhook reconciliation. Do not spoof a browser Origin header.
3. Cover payment authorization failure, disconnect, duplicate request, refund,
   cancellation and restaurant acceptance/self-delivery transitions.
4. Provide complete isolated Food staging parity plus actual authenticated
   end-to-end device/merchant/payment tests.
5. Finish push/realtime, data safety/legal/account rights, release signing,
   Play Console and full accessibility/device-class QA.

**Status: development progress, NOT ready for real customers.**
