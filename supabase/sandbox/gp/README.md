# WYNOS GP — Sandbox draft / simulation only

Implemented only in QA Supabase project `pcatuxtenluqzjzzwsvl`
and the GitHub branch `sandbox/stripe-testmode-20261008`.
**Never run this migration, enable this Admin route, or change fee policies on Production without a separate release approval.**

## Scope
- No default GP percentage. An absent `food_gp_store_rates` row means **not configured**, not 0%.
- Per-store rate saved as integer basis points (1 bps = 0.01%).
- `food_gp_store_rates.mode` is constrained to `simulation_only`; it cannot be activated for real collection.
- GP base for illustrative quotes is food subtotal in satang **excluding delivery**, computed as `floor(food_satang * rate_bps / 10000 + 0.5)`.
- `admin_food_gp_preview` reports `actually_collected_gp_satang = 0` in every case.
- Stripe Connect direct charges, PromptPay payment method, Webhook, refunds, payouts, merchant finance, and all existing order tables remain **unchanged**.
- Customer refunds, merchant-funded discounts, tax treatment, delivery-fee ownership, fee caps, Stripe application fees and payout reconciliation must be designed and approved before any real deduction.

## Authorization and audit
- The QA database currently does **not** contain Production's `profiles.platform_role` / WYNOS Admin role architecture. Do not copy Production auth data or grant ordinary developer or merchant accounts admin privileges.
- `food_gp_admin_allowlist` starts EMPTY, intentionally. Only an explicitly verified WYNOS Admin test user may be provisioned by a trusted **service_role** action within QA. There is no public self-service grant.
- `admin_food_gp_list`, `admin_food_gp_set_draft` and `admin_food_gp_preview` check the allowlist via `auth.uid()` server-side. Anonymous users cannot call them; authenticated users not in the allowlist are denied.
- The tables have RLS enabled and no authenticated/anon table grants, so browser clients can neither bypass RPCs nor edit rate history.
- `admin_food_gp_set_draft` serializes per-store changes, checks the expected previous rate and requires a reason (3–500 characters); writes to `food_gp_rate_audit` on changes.
- The WYNOS Admin interface is at `admin/app/(admin)/food/gp`, accessible only in an Admin *preview* configured with the isolated QA Supabase URL. The existing Admin layout additionally requires the platform Admin role. **The sandbox Admin test account and isolated Admin deployment still require separate provisioning.** It is not an accessible Production feature.
- No Admin users or GP rates have been assigned as part of this initial scaffold.

## Testing completed
In a transaction (rolled back afterward):
1. A non-allowlisted authenticated QA test user cannot list GP.
2. Temporarily allowlisted identity sets a draft rate of 775 bps.
3. THB 500 food subtotal previews THB 38.75 GP and THB 461.25 before other fees; collected GP = THB 0.
4. Outdated expected rates are rejected, a second change creates an audit trail.
5. No paid order status or Stripe payment is modified.
After rollback: 0 admins, 0 configured stores, 0 audit records, and `WF000005` remains `paid`.

## Prerequisites before a real GP release
- Agree on a per-store/default contractual GP policy, refund/dispute adjustment and revenue recognition.
- Confirm Stripe Connect fee-collection support for the exact Connect account integration, PromptPay, and merchant countries, including tax and settlement obligations.
- Implement immutable **order-time** rate snapshots, fee ledger, Stripe fee collection and reconciliation; idempotent webhook processing for all relevant payment states.
- Connect verified platform Admin identities to a dedicated QA Admin app and test admin/moderator/merchant permissions and the Admin UI.
- Run full PromptPay and refund acceptance tests in Sandbox, then plan a separately approved Production rollout.

