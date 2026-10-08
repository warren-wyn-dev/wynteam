# WYNOS Finance Reporting — QA Sandbox v1

**Scope:** GitHub `warren-wyn-dev/wynteam` branch `sandbox/stripe-testmode-20261008`, Supabase QA `pcatuxtenluqzjzzwsvl` ONLY. Never apply to Production, deploy Vercel, change Stripe/PromptPay checkout or webhook behavior, issue real refunds, collect GP, or trigger merchant payouts.

## Installed read-only RPCs

| RPC | Audience | Scope |
| --- | --- | --- |
| `admin_food_finance_report_qa(p_from,p_to,p_store_id default null)` | Authenticated QA GP allowlist | Aggregate projections and refund events, optionally per store |
| `admin_food_finance_events_qa(p_from,p_to,p_store_id default null,p_limit default 50,p_offset default 0)` | Authenticated QA GP allowlist | Paginated order projection / simulated adjustment timeline |
| `merchant_food_finance_report_qa(p_store_id,p_from,p_to)` | Active merchant **owner** of requested store | Store-scoped aggregate only |
| `merchant_food_finance_events_qa(p_store_id,p_from,p_to,p_limit default 50,p_offset default 0)` | Active merchant **owner** of requested store | Store-scoped paginated timeline |

Internal `food_finance_report_core_qa` and `food_finance_events_core_qa` are **not executable** by `anon` or `authenticated`. External read RPCs are `SECURITY DEFINER` with empty `search_path` solely because the finance tables are intentionally private (RLS on, no client SELECT grants). The wrapper does an independent `auth.uid()` + explicit QA admin allowlist or owner-membership check **before** entering the privileged core. General authenticated and merchant staff roles cannot read reports. The API is read-only.

## Financial meaning — simulation only

- All figures are **satang integers** and THB; `estimated_*`, `projected_*`, `simulated_*` are not actually collected income, financial statements, Stripe settlement nor a merchant payout.
- A selected range `[p_from,p_to)` (max 366 days) filters Finance projections by **projection creation time**, and refund adjustments by **adjustment creation time**, independently. A simulated refund can fall in a period different from its original sale. Fields ending `period_*_projection_less_reversals` are **period deltas**, not historical outstanding balances or settled revenue.
- `projected_customer_paid_satang` covers **captured Finance QA projections only**, not every paid Food order. An empty Finance projection dataset produces zeros even if checkout has confirmed payments.
- Discounts remain `unallocated_discount_satang` until an approved sponsor policy is defined. Delivery share and liability are not invented.
- All actual Stripe processing fees remain `null` / `unknown`; **merchant net payout remains `null` / `not_reconciled`**. No default GP percentage is applied.
- No shopper contact/address, Stripe secret, or payment-intent ID is returned in Merchant events. Access is always scoped to the owned store.
- Results are based on append-only Finance/Refund QA records and do not mutate orders or original snapshots.

## Testing and regression

SQL fixtures (each self-contained `BEGIN; ... ROLLBACK;`):

- `supabase/sandbox/gp/refunds_smoke.sql` — original partial/full, duplicate, balances, immutable, security regression.
- `supabase/sandbox/gp/refunds_edge_smoke.sql` — zero/negative/null, mismatched key payload, frozen GP after rate edit, already-refunded status, non-PromptPay denial, 1-satang cumulative rounding.
- `supabase/sandbox/gp/finance_reporting_smoke.sql` — owner vs other store, nonallowlisted admin, unrelated user, 1 projection + 2 refund events, pagination, date validation, unknown fees and payout, no PII, unchanged payment state.
- `supabase/sandbox/gp/finance_smoke.sql` — original Finance projection regression.

The smoke scripts temporarily insert a hypothetical QA GP rate and projections only inside a transaction. They do not call Stripe or actually refund WF000005. Test runs must be done ONLY on Supabase QA.

**Not yet load/concurrency-tested:** two truly simultaneous refund requests from separate DB sessions. The append-refund RPC takes a per-order `FOR UPDATE` projection lock and has unique `(order_id,simulation_key)` and `(order_id,sequence_number)` constraints; these are inspected safeguards, not a substitute for a verified two-session stress test. This test needs a plan that preserves all-Rollback guarantees.

**Security advisor:** authenticated wrapper `SECURITY DEFINER` warnings are expected and require continuous review. They are intentionally accessible only through function-level ownership/allowlist checks; direct table access and core execution remain denied. Supabase Auth leaked-password protection and unrelated shared-schema security/performance notices are out of scope and should be reviewed separately.

## Next, before any release

Review owner vs accounting-role permissions for future merchants; reconcile real Stripe fee/balance transaction accounting and discount/delivery allocation rules; define business/reporting calendars and revenue recognition; test multi-session concurrency; verify role access end-to-end using authenticated HTTP requests; add pagination/export controls and load tests. UI/Vercel deployment and actual-money workflows are NOT part of this QA milestone.
