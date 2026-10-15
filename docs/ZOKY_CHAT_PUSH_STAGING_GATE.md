# Zoky Buyer ↔ Merchant Order Chat — Staging Gate (not shipped)

Status: **blocked pending isolated Zoky Food staging and merchant client implementation**. Do not apply this SQL on Production, and do not enable chat in the Android Debug APK until the complete cross-client QA gate passes.

## Database contract
Draft only: `supabase/qa/zoky_food_order_chat_staging_v1.sql`.

- Message belongs to an existing Food order, with globally unique message id and idempotency client id scoped to sender.
- `sender_id = auth.uid()` on insertion. Access to the message stream restricted to the order buyer or active merchant store team with roles owner/admin/manager/orders/support.
- Anon denied. Cross-tenant and cross-order requests denied. No UPDATE or DELETE from clients.
- 1,200-character message limit, rate-limited at most 20 messages/minute per authenticated sender; never place a service-role key in Android.
- No attachment, file, location, customer contact sharing, or arbitrary direct messaging in v1.
- Buyer account = existing shared WYNOS Account. Merchant membership resolved by server-side store roles, never Android state.

## Work that remains BEFORE a chat release
1. Allocate/approve a **disposable isolated Food staging project** with full catalog/orders/RPC schema. Do not test on the WYNOS production project `kqokpocajhfbidcxpvhh` or reuse the incomplete Stripe sandbox as though it were full Food staging.
2. Promote draft SQL to a reviewed, versioned migration. Confirm RLS/security advisors, role grants, and verified indexes. Run a transactionally isolated matrix with three buyer accounts, two merchant accounts, foreign-store staff, removed staff member and anonymous user.
3. Implement Buyer Android chat threads scoped to placed orders. Show sending, received, retry states and unreads; do not display as complete when the staging flag is off.
4. Implement Merchant web chat list and detail with a two-sided message exchange, order reference, and role-checked route. Prove cross-tenant and stale-session isolation.
5. Add backend-only notification dispatch and deep links; request Android notification permission appropriately. Respect quiet hours, block/report, opt-out for marketing and no Email notifications.
6. QA device screenshots, background/foreground lifecycle, RLS, spam/rate limits, order cancellation, multiple accounts, offline/retry, and real Web Push/Android Push delivery (no mock success).
7. Owner approves staging evidence and any eventual Production migration, keys, DNS/deployment separately.

## Blocking release conditions
- Failing RLS/tenant isolation or missing merchant chat → blocked.
- Missing push credential/token registration and callback verification → keep push disabled.
- Never merge chat migration or enable production feature flags based solely on APK build success.
