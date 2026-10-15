# Zoky Android & Merchant — Full feature release acceptance
**Status: INCOMPLETE; NOT PRODUCTION READY.** Latest QA-green draft branches must never be interpreted as end-to-end live readiness.

This checklist covers the user-requested **Zoky app-wide Home**, its Food ordering destination, Merchant communication, messages, and supporting shared WYNOS Account/Backend. Keep Zoky Home distinct from Food catalog/search. No unapproved DNS, merge, payment/production data writes, or live deployment.

## Release matrix (2026-10-15)

| Feature | Current evidence | Release blocker / acceptance gate |
|---|---|---|
| Zoky branding, HD Home, responsive 320-1080p | PR #1215/1216, Android screenshot/CI QA | Device QA against founder-approved mockup; no raw food illustration emoji |
| Main Food entry and four bottom tabs | Android QA screens and navigation | Verify persisted sessions and back-stack on actual Android devices |
| Saved addresses + Home selector | PR #1216; reads buyer-scoped addresses | Signed-in buyer CRUD/selected address under RLS on isolated staging; only mutate with opt-in |
| Favorites | Native existing account-scoped UI | Validate add/remove persistence, sign-out and other-user isolation |
| Admin campaign carousel | Existing `food_active_home_banners`, PR #1216 | Publish/read/disable/reorder real banners on staging, checked store deep links |
| Deals/promotions | Buyer-targeted notifications, dedicated page | **Not a real coupon claim/apply flow.** Validate eligibility, expiry, stacking and first-order merchant-funded promotion on an end-to-end checkout |
| Order history and status notices | Buyer-scoped history and foreground refresh | Tested lifecycle, background handling and delivered/cancelled/refunded events; no synthetic notifications |
| Notifications in Messages | Promo inbox, read state, order snapshot | Reliable deduplication, unread reconciliation, push delivery receipts, quiet hours and deep links |
| Buyer ↔ Merchant chat | PR #1217 gated Android/Merchant UI and draft SQL | Real two-party staging E2E; RLS tenant isolation, block/report, rate limits, reconnect, idempotent retries |
| Native Android Push | Not feature-complete in Zoky | Dedicated FCM sender/project credentials, token registration/removal, explicit permission, foreground/background and offline tests |
| Shared WYNOS Account | Existing client authentication | Account switching/logout privacy and session revocation across both apps |
| Store/catalog/menu/cart | Existing native parity implementation | Verify all real menu options, availability, price quote and basket cases |
| Order creation, payments, coupons, refunds | Only staging-gated Android order/Stripe pieces | Dedicated payment sandbox with complete Food schema, idempotency, webhook-verified paid/refunded transitions; never enable release by assumption |
| Merchant fulfillment and chat | WYNOS Merchant web; staging chat component | End-to-end cross-platform status/chat, role membership changes, no cross-store data |
| Thai/English and accessibility | Existing two-language Android screenshot QA | Finish end-to-end localized flows, touch targets, TalkBack, screen sizes |
| Security, performance, operational rollout | Partial CI/static QA | Approved release checklist, monitoring, logging redaction, staged rollout and rollback |

## Explicit completion rules

1. **Provision isolated full Food staging**: do not re-use Production `kqokpocajhfbidcxpvhh` or incomplete Stripe Sandbox `pcatuxtenluqzjzzwsvl`. Staging may need paid cloud services and connected billing. Obtain owner approval before creating a project or incurring costs.
2. Replicate *schema only* and seed **synthetic** catalog/orders/merchants. Do not copy user PII, payment details, secrets or real order data into staging.
3. Review proposed chat SQL and migrate **only to approved staging**; independent security tests for three buyers, two merchants, removed store staff, anonymous, cross-order and cross-tenant attempts. Check RLS with real authenticated PostgREST sessions, not merely developer/service-role SQL.
4. Configure staging-only Firebase/FCM and server-side notification dispatch; include token lifecycle, authorization, anti-spam, opt-outs (marketing), Quiet Hours and no Email Notifications. Verify device push delivery while application is open, backgrounded and terminated.
5. Run real signed-in Android ↔ Merchant test conversations, including offline/retry, duplicate requests, order cancellation, logout/account switch and invalid permissions.
6. Run one safe **test payment** from basket → quote → order → webhook confirmation → merchant accept/deliver → receipt/refund reconciliation; coupon and delivery pricing checked at the backend. Never run this against Production accounts.
7. Obtain founder-approved screenshot parity and full QA evidence for 720p/1080p actual devices and Redfinger streaming, with differences identified rather than hidden.
8. Obtain explicit owner approval for the Production database migration, publishable/secret configuration, app signing, Google Play distribution, DNS, staging/production rollout and rollback. No automatic merge or deploy from draft PRs.

### Feature flags / nonnegotiable safety
- Release Android must keep `CHAT_STAGING_ALLOWED=false`, `STAGING_ORDER_CREATION_ALLOWED=false`, `STAGING_MOBILE_PAYMENT_ALLOWED=false`, and all account/address mutations staging-only unless a separately reviewed **real production** implementation is approved.
- Merchant chat Preview must validate the explicit dedicated Staging project ref *and* URL; domain or a feature flag alone is insufficient.
- Avoid claims of full completion based solely on compile success, static guard tests, admin schema presence, or guest screenshot QA.

### Owner action needed for next integration phase
Authorize creation/use of a **separate full Zoky Food Supabase Staging project** (including possible cloud cost) and the **Firebase Cloud Messaging project** to use for Zoky Android testing. Without these services we can finish UI/reviewable code, but cannot truthfully verify real chat or native Push delivery end-to-end.
