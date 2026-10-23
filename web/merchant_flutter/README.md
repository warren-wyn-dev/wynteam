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

`ZOKY_MERCHANT_FLUTTER_ENABLED=1` enables the Merchant-origin root entry only on a reviewed deployment. The default preserves the legacy Merchant route. Food, Social and other origins remain unchanged. Advanced finance, payment-provider setup, staff and operating-hours tools remain available through `/merchant` using the same account and backend.

## Operations covered in Flutter

- Store selection, menu editing/availability, store information/open state.
- Status-filtered order pagination, server sales reports and store promotions.
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
