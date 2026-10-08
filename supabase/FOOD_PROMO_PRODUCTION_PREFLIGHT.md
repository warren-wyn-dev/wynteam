# WYNOS Food — Coupons & Promotional Notifications Production Preflight

**Scope:** PR #1039, `food.wynos.online` and WYNOS Admin. Do not merge this with Stripe fixes (#1040) or the order QA work (#1041/#1042) without a separate cross-PR regression.

**Live state checked 9 October 2026 (Thailand):** Supabase has none of the six new Food promo/coupon tables, no new public Food v2/promo RPCs, no `wynos-food-promotions-5min` cron job, and no `send-food-promotion` Edge Function. The relevant `pgcrypto`, `pg_net`, `pg_cron` extensions are present. Web Vercel project latest Production deployment is READY **on main, not this PR**. Admin Vercel project most recently reported ERROR and `live:false`; detailed Admin deployment listing returned 403 with the available Vercel connector. Vercel previously returned HTTP 402 daily deployment quota when a staging deployment was attempted; its current remaining quota has **not** been independently confirmed. These are release blockers, not evidence of a successful launch.

## Preconditions

- [ ] All PR #1039 CI, Consumer Web, Security, Browser QA remain green at **latest head SHA after these readiness changes**.
- [ ] The branch is reviewed against current `main` and merged only in an approved deployment window.
- [ ] Vercel Admin project access and deployment failure are resolved; both Admin and Consumer Web can deploy to their **existing** expected projects/domains.
- [ ] Review Supabase migration contents and take a restorable backup before applying changes; verify current schemas and privileges.
- [ ] Confirm Food platform campaigns and outstanding orders remain unaffected by additive coupon migrations.
- [ ] Ensure `FCM_SERVICE_ACCOUNT` is set as a server-only secret and that a Supabase service-role/secret key is available to the new internal function. Never expose these to Web/Admin browser code.

## Ordered release

1. Apply **in order**, on the approved production project only, `20261008161000_food_admin_coupons.sql`, `20261008161100_food_promo_notifications.sql`, then `20261008161200_food_promo_cron.sql`. Verify schemas, RLS, and execution privileges. Cron is intentionally **inactive**.
2. Deploy `send-food-promotion` from `.github/workflows/deploy-edge-functions.yml` (manual `workflow_dispatch`); `supabase/config.toml` must set `[functions.send-food-promotion] verify_jwt = false` because requests are authenticated **inside the handler** with a 32+-character Vault key that is verified through a service-role-only RPC. Do not enable public unauthenticated sending.
3. Deploy WYNOS Admin from its existing Vercel project with the correct `admin/` root and proper Supabase connection, then deploy the Consumer Web to its existing project. Verify the Admin coupon and broadcast routes load under an authorized user, and Food Checkout loads normally without a coupon.
4. Using *controlled test accounts only*, create a limited Food platform campaign/coupon, quote normal and coupon checkout, check actual order amount, payment/merchant settlement, invalid/expired/over-quota coupon behavior, cancellation/retry, and bilingual mobile Checkout.
5. Verify Food marketing opt-in/out separately for In-App and Push. Test Food web token **only**; never deliver marketing to Social or Merchant tokens or `app IS NULL`. Test opt-out after enqueue, deep links, notification display, and quiet hours **22:00–08:00 Asia/Bangkok**.
6. Keep marketing `cron.job.active=false` while checks are incomplete. Enable the `wynos-food-promotions-5min` scheduler **only after** manual QA passes and there is explicit launch approval. Never use broad-audience broadcasts as a smoke test.
7. Record verifiable production readiness evidence: Vercel deployments READY, Supabase migration/Edge version, one controlled coupon order, merchant amount, and controlled Push delivery. Declare full Production readiness only after these checks.

## Safe stop and rollback

- First disable the dedicated promotional Cron job; the normal Food order and Merchant/Social notifications must continue unchanged.
- Hide or disable new coupon UI/campaign issuance when necessary without editing previously paid orders, refund records, or settlements.
- If a SQL rollback is genuinely needed, use a reviewed forward migration rather than dropping coupon redemptions or modifying historical transaction amounts.
- Reject rollout if Admin Vercel errors, JWT/key verification mismatch, a checkout total mismatch, or cross-app token routing is observed.

No production changes were made by the preflight itself.
