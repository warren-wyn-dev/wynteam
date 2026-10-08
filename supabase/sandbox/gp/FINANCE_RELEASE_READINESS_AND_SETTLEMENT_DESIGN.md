# WYNOS Food Finance & Revenue Sharing — QA Release Readiness / Settlement Design

**Date:** 2026-10-08. **Status:** design and QA only, **NOT APPROVED FOR LIVE MONEY**.

## Existing implementation (truthful status)
- GitHub sandbox: `sandbox/stripe-testmode-20261008`. No main branch merge or production deployment.
- Supabase QA: `pcatuxtenluqzjzzwsvl` (never connect this API to the production WYNOS frontend).
- GP rates are **draft-only**, explicitly configured per store; no default rate, no actual fee collection.
- Finance projections and refund adjustments are immutable simulation-only records. Stripe charges, refunds, transfers, application fees, webhook code and payouts are unchanged by Finance QA.
- Finance v1 summaries and event timeline, Finance v2 Bangkok daily/monthly buckets and per-order details have Owner/QA Admin RPC access checks.
- The existing Merchant Finance page for **real merchant account balances** remains intact. A separate merchant QA preview is opt-in using `NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW=true` AND exact `https://pcatuxtenluqzjzzwsvl.supabase.co` client URL. It must never be enabled on Production.

## API contracts for QA preview

Period is half-open `[p_from,p_to)`, max 366 days; `p_granularity` is `day` or `month` using `Asia/Bangkok`.
- `merchant_food_finance_buckets_v2_qa(p_store_id uuid,p_from timestamptz,p_to timestamptz,p_granularity text default 'day')`: active store **owner only**.
- `admin_food_finance_buckets_v2_qa(p_from timestamptz,p_to timestamptz,p_granularity text default 'day',p_store_id uuid default null)`: independently QA-admin allowlisted only.
- `merchant_food_finance_order_details_v2_qa(p_store_id uuid,p_order_id uuid)`: active owner of requested store only; missing/other-store projection returns generic `not_projected`.
- `admin_food_finance_order_details_v2_qa(p_order_id uuid)`: independent QA admin allowlist only.

These RPCs are read-only, output **simulated financial figures only**, do not expose customer names, phone numbers, addresses, Stripe secrets or payment-intent IDs. They return `stripe_processing_fee_satang=null` and `merchant_net_payout_satang=null` explicitly; do not render them as ฿0 or actual earnings. No ability to refund or transfer funds is exposed to clients.

## Business / legal decisions REQUIRED before any real finance implementation

1. Founder must approve **whether GP should actually be collected**, which stores, which products, effective date, review/appeal policy, rounding policy and whether draft rates should become active; no default rate may be silently introduced.
2. Decide how delivery fees and any courier earnings are split; Finance simulations currently treat delivery separately from food GP.
3. Decide sponsorship of discounts, fee handling on discounted items, cancellations, partial refunds, chargebacks, and promotions paid by WYNOS or merchants. Do not assume payer or falsely calculate a net refund.
4. Confirm Stripe Connect account capabilities and the settlement/charge model actually supported for **PromptPay in Thailand** in Stripe's current API docs; no guarantee `application_fee_amount` is usable for any specific payment until verified. Avoid mixing direct charge/connected-account ledger with separate transfer assumptions.
5. Specify source of truth for actual Stripe processing fees (balance transaction), net receipts, taxes/invoicing and reconciliation schedules; clarify disputes and cash timing.
6. Approve payout authorization, maker/checker roles, precise refund-approval roles and whether staff may view finance. Current QA merchant reports are owner-only; Admin QA uses a separate allowlist.
7. Design finance audit event immutability and idempotency and reconciliation against immutable Stripe webhooks **before** real ledger posting. Define recovery, retries, pagination and period corrections.
8. Seek appropriate accounting/tax and financial/legal review for Thailand before live revenue sharing or handling third-party funds.

## Security and test gates (not optional)

- **PASSED in QA:** SQL regression including GP, Finance, Refund, cross-store malformed source guard, simulated claims spoof denial, Finance v1 and v2; all tests end in `ROLLBACK`.
- **NEEDS REAL EVIDENCE:** Signed JWT Auth HTTP calls from an authorized QA account (no real JWTs present in current session), including non-owner denial and positive admin.
- **NEEDS REAL EVIDENCE:** Completed GitHub Actions isolated two-/ten-session refund concurrency checks. Script, ephemeral database workflow and smoke SQL compilation are prepared; a green CI run log has not been verified.
- **NEEDS REAL EVIDENCE:** Frontend TypeScript/Next.js build and browser tests for newly added QA preview; code committed but not claimed compiled/deployed.
- **OPEN REVIEW:** Supabase security advisor warns about intentional public SECURITY DEFINER RPC wrappers, authenticated logins, and separate Auth leaked-password setting. Manually inspect auth/role checks and use a separate approval for unrelated project-wide Auth settings.
- **BEFORE PUBLIC LAUNCH:** No QA preview on Production, safe rollout behind feature flags, human approval for business policy, staged test/refund reconciliation, release monitoring and rollback plan.

## QA hygiene

Never insert persistent QA GP draft rates, Finance projections, financial adjustments or Admin allowlist users except via explicitly approved temporary **isolated** fixtures. Transaction-only QA tests use `BEGIN/ROLLBACK`. Synthetic concurrent commits are permitted ONLY inside the disposable Postgres GitHub Actions service, never the existing shared Supabase QA project.

**Definition of 100%:** requires proof for all blocked gates + stakeholder decisions above, and explicitly authorized rollout. A successful SQL migration or local simulation is NOT 100% of live finance functionality.
