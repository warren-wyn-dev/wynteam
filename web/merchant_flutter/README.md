# Zoky Merchant — Flutter UI for the existing Food system

This package is embedded by the existing Next.js `/merchant/flutter` route. It is not a separate backend, account system or standalone deployment.

The Next.js `DeveloperRouteGate` and shared Supabase browser client own authentication, account switching, authorization context and push cleanup. `createMerchantFlutterBridge` wraps existing Food/Merchant services. Dart receives JSON application data only, never credentials or tokens. Every data operation rechecks the signed-in user and store access; SQL/RLS/RPCs and Storage remain authoritative.

## Development / checks

From this directory, using Flutter 3.47.7:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

From `web/`:

```sh
ZOKY_FLUTTER_SDK=/path/to/flutter-3.47.7 npm run build:merchant-flutter
npm run dev
```

Open `/merchant/flutter` and use the existing WYNOS login. Do not serve the Flutter index as a standalone app: its JavaScript bridge is installed by the authenticated Next.js host. Build output goes to the ignored `public/merchant-flutter/` directory. The bootstrap does not register or replace a service worker.

The pinned SDK builds with `--wasm`, producing the Wasm/Skwasm application and a
JavaScript/CanvasKit fallback. The loader retains Flutter's browser feature
detection and default browser allowlist, and uses single-threaded Skwasm so the
shared origin does not need COOP/COEP headers. Both engines remain same-origin.

After compilation, `scripts/version-merchant-flutter.mjs` moves the complete
payload to `public/merchant-flutter/builds/<content-hash>/`. Its JS, Wasm, images
and generated icon font use immutable browser caching. Stable bootstrap, HTML
and `build-version.json` are revalidated to discover the current build. Known
fixed legacy asset paths rewrite to that build with revalidation, preserving
older wrappers without caching mutable URLs indefinitely. Always rebuild through
`build:merchant-flutter` so the loader marker, cache key and legacy aliases agree.

`ZOKY_MERCHANT_FLUTTER_ENABLED=1` enables the Merchant-origin root entry only on a reviewed deployment. The default preserves the legacy Merchant route. Food, Social and other origins remain unchanged. Feedback, help and notification settings remain available through `/merchant?legacy=1` using the same account and backend.

## Startup and visual readiness

The authenticated host reveals a view after its critical store content (or an
actionable empty/error state) has painted. The `zoky-merchant-startup` event is
matched to that view's ID; a removed view cannot reveal a replacement account.
Secondary summaries and decorative images do not block readiness. An independent
20-second content timeout retains reload and legacy-route recovery.

A public `TextPainter` probe starts Flutter's existing Thai fallback in parallel
with authorized data reads. A changed Thai layout after `systemFonts` notification
confirms preparation; a 1,200 ms bound prevents a font outage from locking the app.
A timed-out result is unconfirmed and does not guarantee that glyphs are ready.
This keeps the system-text-font policy and adds no font bundle or engine-private
API. The engine shares preparation across view remounts.

The shared tool atlas starts downloading/decoding during critical store reads.
Stable pink placeholders cover pending artwork and menu pictures; menu slots
remain 64 by 64 pixels and pictures remain lazy. Decorative failure does not
disable actions. Local Web Inspector marks `merchant:flutter:start`, `entrypoint`,
`engine`, `view` and `content` expose startup stages without account/store data;
`start` is the authenticated host mount, after the existing session gate.

## Operations covered in Flutter

- Store selection, menu editing/availability, store information/open state.
- Payment channels (PromptPay, bank account, store QR upload/removal) and weekly opening hours with special closed days, for owner/admin/manager. The bridge rechecks the PromptPay format of `food_stores_promptpay_id_format_check`, 10–15 digit bank accounts, a complete 7-day schedule with HH:MM times and up to 60 closed dates, then reads the row back.
- Status-filtered order pagination, server sales reports and store promotions.
- Ads (`merchant_ad_account`): credit, clicks, start/pause, and credit top-up by transfer to ZOKY's PromptPay with a validated slip (`merchant_request_ad_topup`). ZOKY campaigns (`merchant_platform_campaigns`): the cost split is shown before joining; join/leave use the existing RPCs. Both are owner/admin/manager only, and only the helpers' own Thai messages are shown, never raw server text.
- Team: everyone sees the store's staff (`merchant_staff_members`); owner/admin add people by @username and change roles or access through the existing staff RPCs. The owner row and your own row are never editable from here.
- Store finance for owner/admin/manager: `merchant_finance_summary` for today, yesterday, this week or this month (Bangkok calendar), the same figures as the legacy finance page.
- Manual slip review with private signed image and image-render gate before marking paid. Pending manual payments without a slip require explicit receipt confirmation. Stripe payments remain server verified.
- Accepted → preparing (with selected ETA) → ready → dispatch, cancellation with reason and paid-order refund-pending warning.
- Delivery completion with mandatory private photo and dropoff note. Photo selection remains local until confirmation; replacement/close releases the local selection. A failed completion retains its uploaded path for retry.
- Existing realtime order channel and user-initiated Web Push subscription.

## Security and testing

- Safe failures never become optimistic write success; failed writes require refresh.
- Updating menu fields preserves existing options, images and stock. Mutations are store-scoped and role checked.
- Account/route changes dispose the bridge, remove the Flutter view and close cached controllers/listeners. Each Dart transport captures its original bridge instance so stale callbacks cannot use a new account.
- Photos use browser selection and existing type/size/metadata-scrubbing upload helpers at final confirmation. Slips/proofs use expiring private URLs.
- No SQL migrations, new database, copied customer data or hard-coded API keys.
- Flutter widget/unit tests and synthetic-host browser tests exercise order/payment/photo/error flows without live customer data. Next bridge tests cover direct-API ownership, roles, no-op writes, Stripe verification and storage boundaries.

Production release must use the repository's existing reviewed scoped release process and preserve the existing `/merchant` entry as the recovery path. Do not deploy main while its enforced cross-system acceptance freeze is active.

If an upload succeeds but the final delivery RPC fails and the merchant abandons the dialog/session, an unreferenced private object can remain because current evidence Storage policy is immutable. Retry reuses the object; no delete policy or evidence immutability is weakened.

## ZOKY-FULFILL-001 Merchant integration (contract v1)

The Merchant bridge and both UIs implement the approved store-delivery / same-day
pickup contract in `.wyn/docs/engineering/zoky-fulfill-001-contract.md`:

- Owner/admin fulfillment settings use `food_store_set_fulfillment`. Schedule and
  at-least-one-mode errors stay visible; local form edits are drafts until save.
- Pickup orders show the Bangkok pickup time and code, then transition through
  `ready_for_pickup` and `picked_up` with no delivery-photo step.
- COD skips transfer-slip review. Delivery completion requires the merchant's
  explicit cash-received check and still uses the existing delivery-proof RPC.
- Customer cancellation requests call `food_resolve_cancel_request` with an
  explicit approve/reject and refund/no-refund decision.
- Transfer refunds require confirmation and a private slip before
  `food_store_mark_refunded`. The uploader uses the existing `food-private`
  bucket with prefix `food-refund-slips/<store_id>/<order_id>/`. Confirm this
  interpretation and the Storage policies with the Food/DB session before
  integration. Upload retries retain the same object path until the dialog is
  closed; an abandoned upload can leave an unreferenced private object.
- Realtime invalidations queue behind in-flight Flutter reads. Existing service
  worker push messages invalidate the active account's data and never supply
  order content. Listener cleanup follows host/session disposal.
- Stripe setup prompts are paused behind `STRIPE_SETUP_PAUSED`; existing Stripe
  code and legacy Stripe refund controls remain available. Transfer refunds use
  the new evidence flow, not the old manual refund-status controls.

The shared `food-merchant.ts` changes add fields only. Pickup transitions live in
our wrapper until the Food/DB session updates the shared status union/labels,
completed-order history and report aggregation to cover `picked_up`. Do not
change shared helper implementations from the Merchant branch.

Database integration is pending: tests use synthetic stores/orders and mocked
RPCs only. No live database, actual bank transfer, OS push delivery, production
migration or deployment is part of this verification. Before release, verify
RPC authorization across roles/stores, Storage policies/private signed URLs,
refund idempotency and notification triggers against the completed migration.

Contract follow-up: a merchant-initiated cancellation/no-show with a deliberate
no-refund choice is not expressible in the current transition RPC signature.
The Food/DB session must document whether `food_resolve_cancel_request` supports
orders without an active request, or provide an approved RPC extension. This
branch does not invent a SQL function or silently bypass the existing refund
behavior for direct store cancellations.
