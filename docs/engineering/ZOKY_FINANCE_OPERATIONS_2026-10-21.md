# ZOKY finance operations — approved requirements

Scope: per-order money, GP, refunds, daily payouts, reconciliation, documents,
and finance administration. All implementation and provider verification are
isolated in Sandbox before production approval.

- GP default 10%, scheduled store overrides; rates snapshotted per order.
- Merchant pays actual processor fees, separately from GP. Unknown fees are
  pending, never silently zero or described as a bank payout.
- Merchant cancellation refunds all remaining food and delivery. Customer
  cancellation must already satisfy the existing pre-acceptance policy.
- Missing/incorrect items require owner/manager confirmation; refund the
  discounted item value and corresponding GP. Delivered-order claims require
  review. Cumulative reservations prevent overlapping refunds or rounding drift.
- Bangkok business days close at 00:00; payout initiation at 08:00 only for
  provider-available money. Carry unavailable money. Bank arrival is not promised.
  Existing automatic provider schedules must be explicitly migrated to managed
  payouts before creating any additional payout; never run both.
- Manual adjustments require another authorized admin, not the proposer.
  Approval is an accounting decision, not proof that a transfer succeeded.
- Read-only statements/CSV use the Founder-supplied operator identity,
  configured privately in the database. Not VAT registered. No invented house
  number, taxpayer number or VAT tax invoice. Missing statutory fields block
  issuance of document types requiring those fields, not ordinary statements.
- Provider facts and audit history are private, replay-safe, and reconcilable.
  Amounts use integer satang. No user-controlled authorization metadata.

Acceptance evidence must distinguish local tests, authenticated hosted smoke,
browser verification, actual provider money movement and production enablement.
No category is inferred from another. The earlier automatic full-refund code
remains a prerequisite and is not evidence of partial-refund completion.

## Sandbox verification — 2026-10-21

- Main migration and promotion-refund follow-up applied only to isolated QA.
  Old automatic-refund Cron was drained and disabled before prospective queue
  cutover. Historical order/payment amounts and statuses were preserved.
- Seven handlers/workers deployed in QA. New worker endpoints reject anonymous
  requests with HTTP 401. Dedicated private Cron authentication is required.
- Stripe confirmed the QA merchant bears its actual processing fees. Its old
  provider payout schedule was switched to manual before enabling managed
  daily payouts. No new payout, charge or refund was fabricated for acceptance.
- Real sync returned HTTP 200: four payment facts matched, seven provider
  balance transactions reconciled against the actual available+pending balance.
- Web and admin production builds passed against the public QA client binding.
  Stripe regression suite: 86 passing. SQL integration tests passed allocation,
  cumulative rounding, promotion subsidy reduction, duplicate requests,
  authorization, dual approval, pending fees, partial then remaining full refund,
  fixed payout retry amounts and paid customer cancellation.
- Hosted transaction-local identity checks passed owner reads and unrelated-user
  denial. These are database authorization checks, not browser/Auth E2E evidence.
- All eleven private finance tables use RLS and have no browser grants. Financial
  RPCs deny anonymous execution. Advisor notices for intentional authorized
  SECURITY DEFINER RPCs/private RLS tables remain; compromised-password checking
  is still disabled and remains a broader production blocker.

## Remaining acceptance and operation limits

Fresh authenticated end-to-end payment → partial refund → remaining cancellation
and actual provider payout still require Sandbox execution. Two distinct admin
accounts must be explicitly selected before granting QA financial authority;
no merchant was elevated. Existing refunded orders must never be reused as a
new refund test. Ordinary statements remain non-VAT documents.

Provider ledger backfill is bounded to 100 transactions per sync. Payouts wait
until full history and the observed balance reconcile; large histories can take
multiple runs. Unknown responses older than the provider idempotency recovery
window freeze for review. Never create a replacement transaction to clear a
warning. Previously settled campaign subsidies need a reviewed adjustment if
returned items require recovery; unsettled subsidy entitlements are reduced
proportionally, only after provider-confirmed item refunds.

Vercel rejected branch-scoped Preview environment configuration with
`no_github_account_connected`. Use a deployment-only public QA build binding
for a reviewed source commit instead; do not change global/production env.
Any new Preview origin must be explicitly added to the Sandbox test return
allowlist before checkout testing. Production has not been enabled.

Recovery: preserve queues and audit history. Pause the private financial Cron
before correcting worker code; reconcile any accepted provider IDs before
retrying. Never re-enable the old provider automatic payout schedule alongside
managed payouts. Provider schedule changes require checking in-flight payouts.
