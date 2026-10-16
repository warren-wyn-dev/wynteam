# Zoky iOS Design Preview 2 — Native React Native + Expo

**State:** development-only source in a dedicated branch. No production use, deployment, order creation, authentication, payment, or live customer data.

This folder is a new iPhone frontend companion to the *existing* food.wynos.online customer web experience. It is **not** a WebView or a wrapped website; it implements its screens with React Native components. Existing WYNOS/Zoky web, Supabase, and Android code remain untouched.

## Why this preview is offline-only

The current website's public catalog and signed-in order API are documented in:
- web/components/food/food-guest-browse.tsx
- web/lib/food-customer.ts
- food-android/API_INTEGRATION.md (draft Android work on a separate PR)

**No production URL, anonymous key or API credential is bundled.** Synthetic fixture storefronts and prices are clearly labeled. No network calls or data mutations are implemented.

## Premium native discovery UI — Preview 2

This iteration adds a native design component in `src/DiscoveryScreens.tsx` for Zoky Food Home and Browse screens. The hot-pink accent is `#F70365`. Home includes a clearly preview-only delivery area, a prominent food call-to-action, a functional search shortcut, Food and disabled Ride service cards, tappable food categories, an informational brand message, and sample storefront recommendations. Browse supports Thai search, category filtering, a result count, and a clear reset empty state. All promo content is informational, not a live coupon or entitlement.

## Design-review revision after first real iPhone screenshot

The first Expo Go screenshot did NOT match the agreed mockup: gradient was cut off, the logo sat too close to the white content edge, and the old prototype Home UI (including Ride) was still visible. The new fix uses measured numeric SVG dimensions instead of percentage sizing, a softer continuous gradient, a smaller wordmark and adjusted white overlap.

**For Phase 1 design review only**, `HOME_PHASE_ONE_REVIEW = true` in `App.tsx` temporarily renders only this Header and a blank white canvas on Home. The old HomeDiscovery implementation is still in the repository but not displayed on Home while its later UX/UI phases are undecided. Other tabs and preview screens remain in source.

This revision still requires Expo Go screenshot QA and TypeScript check in the user Codespace before being called visually approved.

## Phase 1 background and logo — original imagery only

Header uses **two extracted raster assets** rather than an SVG gradient recreation:
- `assets/zoky-wordmark-original-1066.png` — high-resolution original source lettering and smile with transparency (no recreated font, glyph paths, new tint, or AI imagery).
- `assets/zoky-header-from-original-jpg.jpg` — photographic crop (420/320px test asset) from a clean pink glossy upper strip in the founder-supplied square logo image; no new painted curves or drawn gradient.

The pink bitmap is scaled to the responsive wide Header, so this preserves the photograph's colours and highlights **but cannot be pixel-identical to the original square icon**. The 1066px logo is preserved. Phase 1 remains a static design preview. Device QA is required before approval.

## Phase 1 lossless logo asset (October 16, 2026)

The Home header now imports `assets/zoky-wordmark-original-1066.png`. This is a **pixel-preserving crop** of the user-supplied 1256×1256 transparent PNG: 1066×590, preserving full RGBA edge detail and the original white-to-pink lettering without recoloring, scaling, posterization, or re-drawing the wordmark. `Image` uses `resizeMode="contain"` and no tint. The older 150px, 320px and 420px assets remain as historical previews but **are not used on Home**.

This update applies only to the isolated Zoky iOS branch and is not deployed. Visual approval is still contingent on Expo Go on-device screenshot review. Run `cd /workspaces/wynteam/zoky-ios && git pull --ff-only && npm run check` then reload the running Expo session; do not merge or deploy.

## Home UX Phase 1 — Approved compact header

Approved visual direction: compact B header, 15–20% shorter than the prior tall mockup.

- **Background:** hot-pink to pastel-magenta gradient with subtle flowing wave overlays, not a generic gray toolbar.
- **Left:** white vector wordmark traced from the founder-provided pink Zoky app-icon photo (no pink tile).
- **Right:** 48pt white circular favorite button with outlined pink heart.
- **Removed from Home header:** location picker, notification bell, cart icon, extra welcome text.
- **Layout:** safe-area-aware full-bleed backdrop; white content rounds over the gradient.
- **Favorite action:** navigates to a placeholder-only Favorites screen. There is no persisted favorites data or customer read/write integration.
- **Scope:** affects the Home hub and Favorites header only. Food browse, store, cart and non-Home bottom tabs retain their existing preview functionality.
- **Native dependencies:** SVG and safe-area packages included in Expo SDK 57 Expo Go, with compatible versions pinned in \`package.json\`.

This matches the chosen **design direction**, not a verified pixel-identical implementation: the gradient and white wordmark are recreated from the supplied visual. Confirm on the user's device in Expo Go and compare screenshots before promising exact fidelity. Do not merge or deploy without further founder approval.

## Screens available now

- Zoky Home: premium pink hero, tappable search, categories, recommended synthetic stores, Food entry and non-operational Ride preview.
- Food browse: restaurant/menu search, category filter, result count, improved store cards, resettable empty state.
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

This code has not yet been confirmed running on a physical iPhone. UI checks are limited to a source review until `npm install`, `npm run check`, and Expo Go smoke testing are executed. Manual acceptance tests are in QA.md.

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
