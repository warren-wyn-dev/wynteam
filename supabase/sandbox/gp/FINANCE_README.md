# WYNOS Finance & Revenue Sharing — Supabase QA, simulation-only v1

## Scope and release guardrails
- GitHub branch: `sandbox/stripe-testmode-20261008`.
- Target DB: **Supabase QA `pcatuxtenluqzjzzwsvl` exclusively**.
- Never apply these finance SQL files to Production Supabase, nor update Stripe Live, food.wynos.online, merchant.wynos.online or Vercel.
- Existing Stripe Checkout remains **PromptPay only**; its code, payment methods, session creation, webhook and payouts are untouched.
- **No default GP rate. No real GP collection. No transfers/refunds.** The database CHECK requires `actually_collected_gp_satang = 0` and `actual_platform_transfer_satang = 0`.

## SQL migrations
1. `supabase/migrations_wynos_food_gp_sandbox_draft_v1.sql` — existing, empty merchant rate drafts and explicit GP Admin allowlist.
2. `supabase/migrations_wynos_food_gp_engine_sandbox_v1.sql` — existing GP engine and immutable order snapshots.
3. `supabase/migrations_wynos_food_finance_sandbox_v1.sql` — **new**, immutable finance projections and signed reconciliation lines.
4. `supabase/migrations_wynos_food_finance_sandbox_preview_v2.sql` — **new**, pure hypothetical-preview calculator for nonzero delivery and discounts.

## Accounting semantics and customer reconciliation

A finance projection uses the **frozen GP snapshot for an order**. It records:

- `food_gross_satang` — **before discount** food subtotal.
- `delivery_fee_satang` — separately recorded.
- `unallocated_discount_satang` — difference between food plus delivery and actually paid.
- `customer_paid_satang` — amount in the test-mode paid Stripe ledger.
- `gp_rate_bps` — frozen percentage from the existing GP snapshot; never a default.
- `estimated_platform_gp_satang` and `estimated_store_food_satang` — **simulations on pre-discount food**, not actual settlement, payout, or net merchant income.
- `stripe_processing_fee_satang = NULL`, `stripe_fee_status = 'unknown'` — **unknown, not free**.
- `merchant_payout_status = 'not_reconciled'` — actual net merchant payout is **unknown**.
- `discount_allocation_status='unallocated'` — the party paying for promotions has not been decided.

**Book 1, `customer_reconciliation`:**

`+food_gross +delivery_fee -unallocated_discount -customer_paid = 0`.

**Book 2, `food_share_projection`:**

`+estimated_platform_gp +estimated_store_food -food_gross = 0`.

The books contain **seven signed reconciliation lines**. These are **not** legally recognized double-entry general ledger accounts or external settlement entries; they merely reconcile verified test payment inputs and a separate hypothetical commission allocation. Full net merchant income is **not computable** until the discount payer, processing fee, taxation, refunds and payout evidence are resolved.

All amount math uses integer satang. GP calculation rounds half-up, sourced from the existing immutable GP snapshot. Rows and lines reject all `UPDATE` and `DELETE` to protect their historical meaning.

## Stripe Connect / PromptPay integration plan — NOT implemented

Existing QA code creates Checkout Sessions using the `Stripe-Account` header of a Thai **Standard connected merchant account** (direct charge) and explicitly sets `payment_method_types[0] = promptpay`. It does **not** set `application_fee_amount` or `transfer_data`.

Future revenue collection design must validate, in a separate **Stripe Named Sandbox**, that the connected account, platform and PromptPay payment method support application fees under the current commercial configuration, country, region, Connect account and API version; generic Stripe Connect documentation is **not proof** of eligibility for this particular account.

A proposed *future*, separately approved integration could use a supported Connect application-fee mechanism during creation of a new test-mode Checkout PaymentIntent, then verify Stripe fee objects, ledger balance transactions, collection, refunds, account capabilities, taxes and payout reconciliation end-to-end. This step requires a separate user approval and a documented rate and discount policy. This migration deliberately includes **no fee collection parameters or payment API calls**.

For this QA v1:
- `food_finance_capture_order_qa(order_id)` is manually invoked by trusted **service_role** only, not any live Checkout/Webhook path.
- A finance projection requires a GP snapshot plus currently **paid, non-refunded, non-cancelled, test-mode, THB, explicitly `promptpay`** Stripe payment, account/PaymentIntent and paid amount matching the snapshot.
- If the GP snapshot is missing: `gp_snapshot_not_available`; nothing written.
- If payment not eligible: `ineligible_payment`; nothing written.
- On success: create one frozen projection and seven balanced lines atomically, returning `projected`.
- On retry: `already_projected` without duplicates.
- Later merchant GP rate changes do not rewrite the frozen projection.
- The Admin read RPC `admin_food_finance_order_qa` requires authenticated identity plus explicit `food_gp_admin_allowlist` membership. Anonymous/merchant users cannot access tables or call the capture/preview functions.
- Future refund and partial-refund accounting must be **new append-only adjustments**, never rewrite frozen historical projections.

## Manual QA checks completed
- Missing GP rate and missing GP snapshot — no projection.
- Payment `WF000005` — only in rollback transaction, GP snapshot and finance projection, idempotent retries, seven lines and both books balanced.
- Change from example 10% to 20% — previously captured 10% remains unchanged.
- Refuse row UPDATE/DELETE and line UPDATE/DELETE.
- Refuse the separate older paid fixture with no explicit PromptPay method, even though it is a Stripe test payment.
- Validate correct access-control decisions for unauthorized and allowlisted test identity.
- Simulate hypothetical **฿100 food, ฿20 delivery, ฿10 unallocated discount, ฿110 customer paid, 10% GP preview** — both books sum to zero, real GP remains ฿0, Stripe processing fee and merchant net payout remain unknown.
- Reject overpayment inconsistent with food+delivery, and rates over 100%.
- Test transactions always end in `ROLLBACK`; permanent GP rate, finance projection and commission collection remain zero.

## Reproduce
Execute `supabase/sandbox/gp/finance_smoke.sql` **only** on Supabase QA. It uses existing Sandbox fixtures and explicitly `ROLLBACK`s the sample rows. Never execute against Production.

## Pending decisions before any real-money implementation
1. The actual **GP percentage**, who may set it, and effective-date/change-notice semantics.
2. GP basis when merchant-funded coupons, platform-funded discounts, delivery promotions, VAT and tips exist.
3. Who bears Stripe processing fees and how to fetch **actual balance transaction fees** rather than guess them.
4. Connect platform/Thai connected-account PromptPay fee-collection eligibility and Sandbox evidence.
5. Full/partial refunds, disputes, chargebacks, transfer reversals, payout arrival, tax invoices and audit retention.
6. QA Admin identity verification and separate allowlist permission; neither an email address supplied in chat nor a GitHub identity grants access.
7. A controlled, explicitly authorized rollout to Production is a **separate task**.
