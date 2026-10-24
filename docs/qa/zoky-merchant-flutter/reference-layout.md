# Merchant reference layout — 2026-10-23

Founder supplied the existing Merchant login URL and four authenticated-screen screenshots as a design reference. Keep the live consumer ZOKY pink brand from the previous iteration, while restoring the familiar Merchant information hierarchy.

- Four primary destinations: home, orders, menu and more. Reports, store settings and promotions remain reachable from home/more; subpages retain a back action.
- Compact Merchant/store header; home prioritizes store identity, today's sales and the existing permission-controlled open/closed switch.
- Menu items are grouped in expandable category cards. Search covers item/category; category filtering and display sorting do not rewrite persisted menu order. Public product photos use the existing public storage URL helper; missing/broken photos show an icon.
- More groups reports, order history, promotions, settings and notifications. Advanced finance/campaign/ads/team tools explicitly open the existing Merchant application. No new advertising, finance, share/QR analytics, map editing or wake-lock implementation is implied by this visual refresh.
- Empty orders show a clear empty state. Compact menu rows move controls below the item on narrow/large-text layouts. Store/menu/promotion control semantics are isolated from surrounding card text. Long sales totals scale within the hero while retaining their complete semantic value.

Verification uses synthetic stores, orders, menu items, payments and delivery proof. No production database/customer data is accessed. Shared auth, role checks and payment/delivery validation remain in force. This is a preview change; production root cutover stays disabled.

## Validation

- Flutter analyze and 24 tests passed. A 320px/200% text test includes sales of 9,999,999.99 and navigation through menu/more without render exceptions.
- Release Flutter compilation and font policy passed; no bundled text fonts/dependencies added.
- Bridge tests 22/22, TypeScript and focused lint passed; six routing tests passed.
- Chromium mobile/desktop 10/10 passed, including manual/slip payment → preparation → delivery proof, followed by home/menu/more navigation. Browser assertions follow Flutter control semantics.
- Synthetic screenshots: [mobile home](reference-layout/mobile-dashboard.png), [menu](reference-layout/mobile-menu.png), [more](reference-layout/mobile-more.png), [desktop home](reference-layout/desktop-dashboard.png).
