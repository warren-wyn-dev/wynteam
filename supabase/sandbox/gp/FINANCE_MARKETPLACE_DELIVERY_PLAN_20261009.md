# WYNOS Food — Marketplace-grade Finance Delivery Plan (Sandbox Only)

Status: IMPLEMENTATION PLAN, NOT LIVE. Branch sandbox/stripe-testmode-20261008. QA project pcatuxtenluqzjzzwsvl. No production writes, live money, deployment, or default GP activation authorized by this document.

## Core architecture
- Payment orchestration: server-only PaymentIntent/Checkout creation, webhook signature verification, immutable raw Stripe event receipt, deduplication by event id and payment id, retries with dead-letter review. Never trust browser payment success.
- Marketplace: Stripe Connect merchant onboarding with verified charges_enabled, payouts_enabled and required capabilities. Confirm account/country and PromptPay charge type support in Stripe Test Mode before selecting separate charges/transfers vs destination charges. One merchant per order by default; multi-merchant cart requires explicit split allocations.
- GP: versioned per-store rate contracts, effective dates, approval history, satang integer arithmetic, explicit rounding, excluded/discounted bases, delivery allocation. No silently applied rate.
- Ledger: append-only double-entry journal; payment clearing, platform GP payable/revenue, merchant payable, processor fee expense, refunds, transfer reversals and reserve/holds. Enforce balanced postings and idempotency in a single database transaction. Distinguish projected, earned, available, transferred and paid-out.
- Settlement: eligible only after verified successful payment, store onboarding and order fulfillment/risk hold; transfer exactly once using Stripe idempotency keys; reconcile Stripe transfer/payout/balance transaction IDs. Transfer to connected account is not equivalent to bank payout.
- Refund: authorize maker/checker; support partial refunds, refund pending customer bank details (PromptPay), failed refunds, post-transfer reversals and outstanding merchant negative balances; never equate a requested refund with settled refund.
- Reconciliation: daily THB transaction-level comparisons against Stripe charges, refunds, balance transactions, transfers, payout statuses; exception queue with audit trail and replay controls.
- Security: RLS/role matrix, least-privilege server credentials, immutable admin audit, webhook replay protections, signed JWT real-Auth E2E, merchant cross-store denial, automated concurrency and rollback tests, production kill switches and operational alerts.

## Release gates
1. GitHub protected QA Environment with owner/unrelated QA credentials, QA-only legacy service role and store ids; run ephemeral admin Auth gate; verify deletion and zero allowlist afterward.
2. Signed-JWT HTTP tests plus real Auth browser E2E; address security findings by impact, not blindly.
3. Verify Connect eligibility and actual PromptPay/card settlement behavior for the designated WYNOS Food test account. No assumptions about supported charge types.
4. Founder policy signoff: rate by store, discount base, delivery/courier fee split, fee burden, cancellation and refund rules, minimum/hold periods, dispute reserves, payout schedule, tax and invoices.
5. Implement ledger, onboarding, settlement worker, Stripe webhooks and reconciliation on sandbox; run end-to-end test mode with synthetic connected merchants and safe refunds.
6. Independent accounting/legal review of Thailand marketplace payments and tax obligations; security review; staged production launch with rollback, monitoring and explicit final go-live approval.

## Definition of done
100% requires passing each release gate with verifiable CI/test-mode evidence, authorized environment configuration and reviewed business policy. No successful mock test is a substitute for live capability validation.

Reference: https://docs.stripe.com/connect/marketplace ; https://docs.stripe.com/payments/promptpay ; https://docs.stripe.com/connect/separate-charges-and-transfers
