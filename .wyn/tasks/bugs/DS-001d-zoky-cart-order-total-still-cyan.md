# Bug Report — DS-001d (BUG-2)

Status: bugs
Owner: AI Debug Engineer
Found by: AI QA & Security (DS-001 QA round 2 — verifying DS-001c/BUG-1 fix, 2026-08-16)

Bug: Two ZOKY commerce **totals** (both explicitly monetary/"price" values, both on screens DS-001 Section 4 Rule #1 names by name — "cart" and "order") still render in **Cyan `#00C8FF`**, not Orange, in both light and dark mode, inside `app/` (the customer-facing WYN Social app's ZOKY marketplace tab). This is the exact same root-cause family as DS-001c/BUG-1 (WYN Social Cyan leaking into a ZOKY commerce value that should be Orange per the Founder's 2026-08-15 decision), just at two call sites BUG-1's fix did not cover, because the original bug report (`DS-001c-zoky-price-color-not-orange-in-app.md`) only enumerated the 6 call sites that read `colorScheme.tertiary`. These two sites never read `colorScheme.tertiary` — they explicitly read `colorScheme.primary`, which is Cyan in `app/`'s `WynTheme` both before and after DS-001c's fix, so BUG-1's `ZokyThemeScope` fix (which only remaps `tertiary`/`onTertiary`/`tertiaryContainer`/`onTertiaryContainer`) does not, and structurally cannot, touch them.

Affected call sites (both pre-date DS-001 entirely — introduced in `f7f6259`, ZOKY-003's original implementation, before the Cyan/Orange color direction existed; never touched by DS-001a/b/c):

1. `app/lib/features/zoky/presentation/zoky_cart_screen.dart:239` — `_buildBottomBar`'s "ยอดรวมทั้งหมด" (grand total), the large bold total shown in the bottom action bar of the **Cart screen** right next to the "ยืนยันคำสั่งซื้อ" button:
   ```dart
   Text(
     thaiBahtLabel(total),
     style: Theme.of(context).textTheme.titleLarge?.copyWith(
           fontWeight: FontWeight.bold,
           color: Theme.of(context).colorScheme.primary,
         ),
   ),
   ```
2. `app/lib/features/zoky/presentation/widgets/order_summary_card.dart:87-91` — the per-order total shown on every card in the **Order List screen** (`ZokyOrderListScreen`):
   ```dart
   Text(
     thaiBahtLabel(order.total),
     style: Theme.of(context).textTheme.titleSmall?.copyWith(
           color: Theme.of(context).colorScheme.primary,
           fontWeight: FontWeight.bold,
         ),
   ),
   ```

Both resolve `colorScheme.primary` → `WynColors.cyan500` (`#00C8FF`) in both `WynTheme.light` and `WynTheme.dark`, since `app/lib/core/design/wyn_colors.dart`'s `socialLightScheme`/`socialDarkScheme` both set `primary: cyan500`.

This directly contradicts:
- `.wyn/docs/design/ds-001-color-system.md`, Section 4, Rule #1: "ราคา — ตัวเลขราคาสินค้าทุกที่ (grid tile, product detail, cart, checkout summary, order detail) — ดิบ `#FF6B35` ทั้ง light และ dark" — the file column literally lists `cart`, `order`, and the "ทุกที่" ("everywhere") in the description is not qualified to "only per-line-item prices, not totals."
- `.wyn/company/DECISIONS.md` (2026-08-15): "ZOKY Primary (commerce layer แยก identity): Orange `#FF6B35` ใช้เฉพาะ price/CTA/seller badge/commerce state" — an order/cart grand total is unambiguously a "price"/commerce-state value.
- The practical effect DS-001c's fix was supposed to achieve: on the **same Cart screen**, after BUG-1's fix, every per-item price (`ZokyCartItemTile`, via `ZokyThemeScope`) is now correctly Orange — but the grand total directly below it, in the same screen, in the same visual hierarchy (arguably the most important number on the screen, right next to the checkout button), is still Cyan. This is a visible, jarring inconsistency a user will notice immediately, and defeats the stated purpose of BUG-1's fix ("ZOKY commerce identity separation").

Reproduction (proved independently at runtime with a throwaway widget test, run then deleted — not just read from source):

1. Pump `ZokyCartScreen` with a `RecordingZokyRepository` seeded with one cart item (price 125, quantity 2 → line total 250) under `WynTheme.light` (then repeat under `WynTheme.dark`).
2. `pumpAndSettle()`, find the `Text` showing `'฿250'` (the bottom bar's grand total), read its resolved `style.color`.
3. Result (both light and dark — value is identical because `primary` doesn't change): `Color(alpha: 1.0, red: 0.0, green: 0.7843, blue: 1.0)` — exactly `WynColors.cyan500`, not `WynColors.orange500` (`Color(alpha: 1.0, red: 1.0, green: 0.4196, blue: 0.2078)`).
4. Repeat for `ZokyOrderListScreen` with a `RecordingZokyRepository` seeded with one order (`total: 220`) + matching `OrderItem`: find `Text('฿220')` (the `OrderSummaryCard`'s total), same result — exactly `cyan500` in both light and dark.
5. Independently confirmed the per-item prices on the very same `ZokyCartScreen` pump (`ZokyCartItemTile`'s `'฿125'`) DO correctly resolve to `orange500` (BUG-1's fix works) — so the grand total's Cyan is not a `ZokyThemeScope`-wrapping gap, it is a different, unrelated color choice (`colorScheme.primary` instead of `colorScheme.tertiary`) at these 2 call sites specifically.

Expected: `thaiBahtLabel(total)` in `ZokyCartScreen`'s bottom bar and `OrderSummaryCard`'s per-order total both render Orange (`WynColors.orange500`, matching the raw-shade convention `ZokyThemeScope`/`ZokyTheme` already use for every other ZOKY price in `app/`), in both light and dark mode.

Actual: Both render Cyan `#00C8FF` in both light and dark mode — visually indistinguishable from WYN Social's own brand accent color, and inconsistent with every other price on the same screens (which are correctly Orange after BUG-1's fix).

Root Cause: These 2 call sites pre-date DS-001 entirely (written in `f7f6259`, ZOKY-003's original implementation, when the whole app used a single Blue `#2D6CDF` seed color and "which slot is Cyan vs Orange" wasn't a concept yet). When DS-001a/b globally repointed `colorScheme.primary` from Blue to Cyan, these 2 `Text` widgets silently inherited Cyan without anyone auditing whether a `colorScheme.primary`-styled monetary value inside a ZOKY screen should actually be using the new ZOKY-Orange convention instead. DS-001c's own audit/fix pass (and the original BUG-1 bug report it produced) scoped its search to call sites of `colorScheme.tertiary` (the new "should be Orange" slot) — it never went back and grepped for pre-existing `colorScheme.primary` usages *inside* `app/lib/features/zoky/` that render a `thaiBahtLabel(...)` value, so these 2 were never in scope for anyone's audit, including QA round 1's own review of DS-001c.

Fix (recommend mirroring BUG-1's exact pattern for consistency): swap `Theme.of(context).colorScheme.primary` → `Theme.of(context).colorScheme.tertiary` at both call sites, so they pick up `ZokyThemeScope`'s Orange remap automatically:
- `zoky_cart_screen.dart:239` — `_buildBottomBar` is already called from inside `ZokyCartScreen.build()`'s `Builder`-provided `context` (the same descendant context `ZokyCartItemTile`'s price already resolves Orange through), so this is a same-file, same-context, one-line color-slot swap — **no new `ZokyThemeScope`/`Builder` wrapping needed**, it's already inside one.
- `order_summary_card.dart:87-91` — `OrderSummaryCard` is used by `ZokyOrderListScreen`, which is **not currently wrapped in `ZokyThemeScope` at all** (it wasn't one of BUG-1's 5 wrapped screens because BUG-1's scope was strictly "screens with a `colorScheme.tertiary` call site," and `ZokyOrderListScreen` had none until this fix introduces one). This fix must **also** wrap `ZokyOrderListScreen`'s `build()` in `ZokyThemeScope` + `Builder` (same pattern as the other 5 screens — see `zoky_order_detail_screen.dart`'s `build()` for the closest analog, since it also calls a child-widget-building helper that needs `Theme.of(context).colorScheme.tertiary` to resolve correctly), otherwise `colorScheme.tertiary` under `ZokyOrderListScreen`'s current (unwrapped) context resolves to Cyan too (same failure mode as the original BUG-1, not a fixed one).
- Before committing to this exact fix, re-run a grep sweep in `app/lib/features/zoky/` for every remaining `colorScheme.primary` call site combined with a `thaiBahtLabel(...)`-derived value nearby (or any other monetary value), to make sure there are exactly these 2 and not a 3rd/4th missed by this bug report too — do not assume this report's list is exhaustive without re-verifying independently, the same way this report itself was only found by re-deriving the check DS-001c's own audit should have done.

Files Changed (expected): `app/lib/features/zoky/presentation/zoky_cart_screen.dart`, `app/lib/features/zoky/presentation/widgets/order_summary_card.dart`, `app/lib/features/zoky/presentation/zoky_order_list_screen.dart` (new `ZokyThemeScope`/`Builder` wrap). Do **not** touch `seller_app/` — not applicable there (its `ZokyTheme` already makes `primary` stay Cyan and `tertiary` Orange app-wide by design; need to independently verify `seller_app/`'s equivalent cart/order-list screens don't have the analogous issue as part of this fix's QA handoff, since this bug report only audited `app/`).

Tests to add (regression memory): extend `app/test/zoky_price_orange_theme_regression_test.dart` (or a new test group in the same file) with 2 more cases — pump `ZokyCartScreen` (already partially covered, just needs a second assertion on the grand-total `Text` in addition to the existing per-item-price assertion) and `ZokyOrderListScreen` under real `WynTheme.light`/`WynTheme.dark`, assert the resolved total `Color` equals `WynColors.orange500`, not `WynColors.cyan500`, in both modes — same assertion style already used in that file (checks the *resolved* value, not just "some color is applied").

Regression Risk: Low — same shape as BUG-1's fix (a color-slot swap + one additional `ZokyThemeScope` wrap around a screen that has no other `Theme`-sensitive content that would need to be preserved as Cyan). Should not affect any non-color behavior. Full `app/` (294 baseline + new tests) and `seller_app/` (91, unaffected) suites must still pass.

Handoff to QA: After the fix, QA round 3 must (1) re-run the runtime probe for both call sites (and any additional ones found by the re-audit this report recommends) confirming Orange, not Cyan, in both light and dark; (2) confirm `ZokyOrderListScreen`'s new `ZokyThemeScope` wrap doesn't change any other color on that screen (e.g. `OrderStatusBadge`'s `primaryContainer`-based "in progress" status colors, which are an intentional, documented, pre-existing design decision unrelated to this bug — see `order_status_badge.dart`'s own doc comment — and must stay exactly as they are); (3) re-run `flutter analyze`/`flutter test` independently on both `app/` and `seller_app/`; (4) re-verify BUG-1's own fix (the 6 original call sites + `ZokyThemeScope`) is still intact and untouched by this fix; (5) re-check the mirrored token files (`wyn_colors.dart`/`wyn_typography.dart`/`wyn_spacing.dart`/`wyn_theme.dart`) are still untouched in both apps.

---

## Secondary observation (non-blocking, NOT part of this bug, logged for a future fast-follow — not included in "Files Changed" above)

`app/lib/features/zoky/presentation/widgets/order_status_badge.dart` maps the 4 "in progress" order statuses (`paid`/`sellerProcessing`/`readyToShip`/`shipped`) to `colorScheme.primaryContainer`/`onPrimaryContainer` (a Cyan-tinted container), while `.wyn/docs/design/ds-001-color-system.md` Section 4 Rule #4 ("Commerce state ที่เป็นบวก") says these should be Orange, and names this exact file. This widget's own doc comment gives an explicit, considered rationale for keeping them blue-tinted ("all 'someone still needs to act on this, not a final state' ... told apart by icon+text only"), and the file has never been touched by any DS-001 commit (last touched by SELLER-003, `9a72d9d`, which already passed its own QA round with this behavior in place). Unlike the two totals in this bug report (which are a straightforward oversight with no design rationale), this is an existing, reasoned, already-QA'd design decision that predates DS-001's Section 4 table — flagging the inconsistency between the doc and the code for AI Design to resolve (either update the doc to reflect the intentional carve-out, or file a deliberate follow-up to change the widget) rather than folding it into this bug report as a code defect.
