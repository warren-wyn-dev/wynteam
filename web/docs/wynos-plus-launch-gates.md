# WYNOS Plus — Phase 3 launch gates

Status: Staging preview only, stacked on Phase 2 and Phase 1 Web Beta 1.
The user requested paid membership, but billing provider, price, interval, currency,
entitlement catalog and refund/cancellation terms have not yet been finalized.
None of these are safe to invent or activate silently.

## Implemented for isolated QA

- Mobile-friendly `/plus` route entered from the user's own profile menu;
  no change to the five-tab bottom dock or the seven-row Settings layout.
- Membership status is readable only by its own authenticated account under
  PostgreSQL RLS. Anonymous users cannot SELECT; browsers have no rights to
  INSERT, UPDATE or DELETE membership rows. Unknown/expired memberships deny
  entitlement even when the displayed status was previously active.
- Private provider identifiers live in non-exposed `internal` schema with
  no public, anonymous or authenticated table permissions.
- Payment CTA is disabled. There are no charges, automatic Verified badges,
  real checkout, or premium content gates in this preview.

## Mandatory paid-launch gates

The Founder selects the billing provider and approves price, currency,
billing interval, Plus features and cancellation/refund/consumer terms.
Only then implement server-side checkout and a verified-signature,
idempotent webhook with duplicate-event handling, payment failure,
refund, chargeback, cancellation, delayed webhook and provider outage tests.
All gated features must recheck membership on the trusted backend.

Run `npm run test:plus-entitlements` and
`bash supabase/tests/wyn_191_plus_memberships_test.sh` in isolated QA.
Verify anonymous, user A/B, active, past-due, expired, unauthorized writes
and raw provider-reference isolation. Production migration/security
architecture and actual paid enrollment need separate Founder approval.

No production DB migration, billing charge, or product-version bump is
implied by landing code on this staging branch.
