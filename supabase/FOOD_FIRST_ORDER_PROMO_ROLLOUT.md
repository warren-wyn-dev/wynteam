# WYNOS Food — First-order merchant-funded promotion rollout

**Change:** Food/ Merchant/ Admin. Customer's first Food order qualifies if food subtotal >= ฿120. Fixed ฿20 discount, merchant 100% funded. WYNOS 0%. No coupon code. No stacking beyond the existing best-campaign rule.

**Current state:** Source branch only, no production schema change, no production enablement.

## Dependencies and release gates

1. Review `supabase/migrations/20261008161000_food_admin_coupons.sql` and its associated production preflight; this previous coupon migration must be applied BEFORE `20261009120000_food_first_order_merchant_funded.sql` because this campaign candidates definition preserves its coupon support. Do not bypass existing PR #1039 release gates.
2. Resolve Admin Vercel project's access/deployment failure. Verify exact production team/project target for both `web/` and `admin/`. Do not create a duplicate Admin project as a workaround.
3. Complete independent code and security review, run `cd web && npm run test:stripe && npm run typecheck && npm run build`, Admin build, SQL harness and integrated checkout tests. Verify migration against staging DB before any production change.
4. Verify signed-in new user eligible at a joined store only; old user denied even when past order was at a different store. Check cancelled unpaid order restoration versus paid/refunded cancellation still consumed.
5. Test both regular and scheduled Food order RPCs, coupon pathways (if available), Stripe payment amounts, merchant financial summary, refund cases, duplicate webhooks, and concurrent orders from two sessions (must never get two redemptions).
6. Confirm merchant enrollment requires manager/owner via existing `merchant_join_platform_campaign` RPC and no enrollment happens when Admin enables the offer. Validate row-level permissions and parameter validation.
7. Production deploy needs explicit Founder authorization after passing release gates. Leave offer inactive until Admin deliberately activates it and merchant explicitly joins.

## Integration matrix

| Case | Expected |
|---|---|
| New buyer, participating store, ฿119 | No promo |
| New buyer, participating store, ฿120 | Discount ฿20 (food only) |
| New buyer, nonparticipating store | No promo |
| WYNOS user with no prior Food orders | Eligible at participating store |
| Old Food buyer at any store | No first-order promo |
| Cancelled and never paid prior order | Eligible again |
| Previously paid then cancelled/refunded | Consumed; manual support review if exceptional |
| Two simultaneous first orders | Max one may redeem; second must not get promo |
| Admin toggles off | No new discount; historical order snapshots unchanged |
| Merchant opts out | No further first-order discounts at that merchant |
| Store has another better campaign | Existing best-discount selection; no stacking |
| Duplicate Stripe event | No duplicate order discount |
| Delivery fee or addons | Threshold based on server-priced food subtotal (includes priced menu options); delivery excluded |

## Metrics, ledger, rollback

- Original order fields: `subtotal`, `campaign_discount`, `delivery_discount`, `total`.
- Campaign snapshot: `food_order_campaigns.platform_funded=0` for this promotion; merchant cost = campaign + delivery discount minus platform-funded amount. No platform reimbursement is due.
- If launch problems occur, use Admin toggle to deactivate; do not rewrite historical paid orders, refund records, or settlements. Disable the feature before DB rollbacks.
- Migration creates database trigger locks to protect concurrent first-order redemptions. Review lock throughput and logs before rollout; reject production release if timeouts or inconsistent financial totals appear.

## Known limitations

- This branch's test suite consists of source-contract tests; full database, payment, browser, and TypeScript builds must be separately run and recorded.
- The Admin project release issue and dependent 2026-10-08 coupon deployment must be resolved first.
- Failed concurrent promotional checkout may return `first_order_already_used`, so client error messaging should be tested during browser QA.
