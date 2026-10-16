# Zoky iOS Preview 1 — Native React Native + Expo

**State:** development-only source in a dedicated branch. No production use, deployment, order creation, authentication, payment, or live customer data.

This folder is a new iPhone frontend companion to the *existing* food.wynos.online customer web experience. It is **not** a WebView or a wrapped website; it implements its screens with React Native components. Existing WYNOS/Zoky web, Supabase, and Android code remain untouched.

## Why this preview is offline-only

The current website's public catalog and signed-in order API are documented in:
- web/components/food/food-guest-browse.tsx
- web/lib/food-customer.ts
- food-android/API_INTEGRATION.md (draft Android work on a separate PR)

**No production URL, anonymous key or API credential is bundled.** Synthetic fixture storefronts and prices are clearly labeled. No network calls or data mutations are implemented.

## Screens available now

- Zoky Home: brand theme, Food entry and non-operational Ride preview.
- Food browse: restaurant search, menu-category filter, restaurant cards.
- Store details: menu list, radio/checkbox-like configurable options including vertical spicy-level choices.
- Single-store cart: add, quantity changes, remove, clear; preview-only subtotal and illustrative delivery fee.
- Orders / Messages / Account: informational placeholders, not fake functional integrations.

## Develop using a cloud terminal (iPhone only)

Use a GitHub Codespace (or equivalent cloud Linux dev environment), opening **only this branch**. In its terminal:

~~~sh
cd zoky-ios
npm install
npm run check
npm run start:tunnel
~~~

Expo CLI may request an Expo/Ngrok tunnel dependency; approve only after checking pricing and permissions. Sign into the Expo account used on the iPhone, then open the generated Expo URL or QR code in Expo Go.

This is a **development server** for device testing, *not* a deployment to the internet or App Store. If using local networking rather than a tunnel, the cloud dev container may not be reachable from the iPhone.

Version policy: SDK 57 (React Native 0.86, React 19.2.3) was selected because the SDK 58 release of Oct 15, 2026 is not yet available in App Store Expo Go. Revisit versions before the first actual device QA.

## Static checks

~~~sh
npm run check
~~~

This code has not yet been confirmed running on a physical iPhone. Manual acceptance tests are in QA.md.

## Integration gates

1. Review and match the website guest catalog JSON contract and published/suspended/closed rules before adding *read-only* access through the existing food_public_catalog RPC.
2. Implement account auth only after mobile PKCE/redirect, secure session storage, logout isolation, RLS and account recovery QA are approved.
3. Server-calculated quote, order creation, address mutations, receipts, payment, chat, FCM/APNs and Ride are all **out of scope**. Never enable them against Production as part of this preview.
4. Do not merge or deploy without new founder approval.

## Safety boundaries

- No WebView.
- No service_role, sb_secret, Stripe secret, OAuth secret, FCM server keys, or customer data in mobile source.
- No public claim that preview item prices, coupons, or fees are real.
- Keep Zoky Android Kotlin/Compose and web site intact; all new code stays under zoky-ios/.
