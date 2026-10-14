# WYNOS Food Android — Adaptive / Responsive UI Specification v1.0
**Platform:** Native Android, Kotlin + Jetpack Compose. **Status:** implementation contract for Android UI only; no API/payment/production authorization. **Date:** 2026-10-14.

## 1. Intent & immutable decisions
- Reference the *quality and consistency* of polished food delivery apps such as LINE MAN, **without copying its branding, layouts or assets**. WYNOS Food identity: clean white, magenta-red accents, soft-3D only on a few actions.
- Home: **WYNOS Food in one header line**, search **above** promotional banner, optional truthful coupon section, **no horizontal filter chips**, **no outer restaurant card border/background/shadow**, **no "+" quick-order overlay**; 1:1 dish photographs; tapping the image/name/price opens **native menu details** to choose mandatory options and order there.
- Search-side filter icon stays; its bottom sheet can filter actual backend-defined categories / open / fee; never fabricate rating, ETA, distance, coupon or free delivery.
- Preserve **Home / Orders / Messages / Account** bottom navigation, and **no Home delivery/pickup toggle**. Signed-out browse still works. Do not revive fake promotions or hidden production mutations.
- Source of truth: food.wynos.online API fields, not hardcoded sample businesses or discounts.

## 2. Layout model (measure actual available window in dp)
Use `BoxWithConstraints` or window metrics **after insets**, not physical phone model, pixel dimensions or screen diagonal. Respond to rotation, font scaling, split-screen, external displays and foldables.

| Available window width | Class | Horizontal padding | Preferred content width | Pattern |
| --- | --- | --- | --- | --- |
| 320–359dp | tight phone | 12dp | fluid | Single-column discovery, smallest menu tiles; no clipping |
| 360–599dp (360/390/412/430) | compact phone | 16dp | fluid | Single-column featured restaurants + horizontally scrollable 1:1 dishes |
| 600–839dp | medium tablet / split-screen | 24dp | max 720dp centered | Wide single-column Home; 2-column **store discovery grid** where appropriate |
| 840dp+ | expanded tablet / unfolded | 24–32dp | max 960dp centered | 2–3-column store grid; bounded editorial Home and dialogs. Consider dual-pane menu details only when tested |

These are breakpoint **policies**, not exact device categories. For widths smaller than 320dp avoid crashes/negative measures; keep the primary UI scrollable.

## 3. Responsive tokens
```text
outerPadding = if width<360 12dp else if width<600 16dp else 24dp
contentMaxWidth = if width<600 fluid else if width<840 720dp else 960dp
gap = 8dp / 12dp / 16dp / 24dp (no ad-hoc spacing)
searchVisualHeight = 44dp; filterVisualSquare = 44dp;
interactive touch area >=48x48dp through outer layout where possible
heroHeight = clamp((boundedContentWidth - 2*outerPadding)/2.30, 140dp, 172dp)
  phone; tablet cap 200dp with restrained art cropping
featuredCoverSquare = clamp(windowWidth*0.26 + 14, 96dp, 124dp)
menuImageSquare = clamp(windowWidth*0.20 + 16, 84dp, 120dp)
menuItemRowGap = 8-10dp; image aspectRatio = 1:1, centerCrop
couponEmptyRow ~= 60-76dp; show actual coupon cards ONLY from live eligible offers
bottomNavVisualHeight = 62-68dp + system nav inset, four evenly weighted items
```
When rendering inside a bounded column, derive thumbnails from the **measured bounded viewport**; do not let giant images inherit full tablet screen width. Images are lazily loaded. Do not enforce same line wraps for every locale; allow dynamic height for text.

## 4. Shared design system
- Colors use existing WebRed / WebInk / WebMuted semantics; light background white; subtle shadow/elevation only for search, banner, coupon ticket, primary CTA and selected nav indicator.
- Corner radii: 10–12dp for dish images, 12–16dp for store covers, 16–20dp hero/coupons, circular search/icon affordances.
- Text scales via `sp` respecting OS fontScale: section 18–22sp, store title 16–18sp, menu title 12–14sp, price 13–15sp, secondary 12–14sp. Allow 2 lines for Thai dish names; don't truncate prices. At 1.3–2.0 font scale test clipping/scroll rather than force fontScale 1.0.
- Minimum contrast WCAG AA for body labels where possible, accessible labels/semantics for filters, menu images, logo, order states and bottom tab selection. All tappable surfaces should expose an accessible 48dp target; give keyboard focus and meaningful Back behavior.
- Tap menus to details, never direct-submit an order from Home. Missing/out-of-stock menu items show accurate disabled/availability cues.
- Responsive layouts preserve app state on rotation and process recreation (search, filter, tab, cart and selected store).

## 5. Screen-by-screen behavior
| Screen / flow | Compact | Medium / expanded | Data / functional constraints |
| --- | --- | --- | --- |
| Home header/address/search | 1-line WYNOS Food, responsive sign-in/cart and delivery address, compact 44dp visual search + filter | bounded and centered header/search; don't stretch icon control | respect safe insets/keyboard; signed-out view need not show address |
| Promotional hero | approx 2.3:1 with clamped height, text/CTA in safe left region | cap hero width and height, image crop; no vertically stretched banner | published banner first; otherwise branded illustration/real menu photo; CTA scrolls to actual stores |
| Coupons | compact single row for no verified offers | bounded horizontal ticket list for real offers | no invented code, eligibility or claim button |
| Restaurant recommendation | frameless restaurant cover + 2-line details + horizontal dish row | capped column; browsing more restaurants uses responsive grid | show actual fee/open/cuisine, no fabricated rating/ETA/location |
| Menu photographs | every thumbnail 1:1 and clickable; name 2 lines, price follows | number visible increases naturally; square stays square | opens menu detail, no "+" on Home |
| Store details/menus/add-ons | vertical scrolling sections and sticky action without overlap | bounded wide panel; tablets may split catalog/options after tested | option radio rows remain vertical; respect sold-out/selected add-ons |
| Cart/checkout/payment | vertical forms; totals and CTA remain readable above IME | bounded 600–720dp form; avoid excessively wide fields | only staging transactions; never enable live writes by UI work |
| Orders/history/detail | readable status chips and rows; list scrolls | bounded list / details; avoid full-width unreadable lines | buyer-scoped real data; correct localization |
| Messages | 4-tab nav preserved even while real chat unavailable | centered empty state | do not claim chat works until backend does |
| Account/login/password reset/addresses | centered scrollable form; safe keyboard and error state | form width max ~600dp | preserve shared WYNOS identity/session/RLS |
| Modals/bottom sheets | IME-aware, scroll within viewport, dismiss/back supported | limit dialog width; large screens can use centered modal | do not hide mandatory option controls behind keyboard |

## 6. Bottom navigation & insets
Use `Scaffold.bottomBar`, not absolute overlays on restaurant content. Consume system bars exactly once (avoid double padding). Keep 4 equally weighted tabs; labels present in Thai and English; visual height ~62–68dp **excluding** the OS gesture/nav inset. Respect gesture/3-button nav, landscape and display cutouts. Hide keyboard appropriately when navigating, and never let order CTA cover field focus.

## 7. Visual acceptance & regression gates
Test **320, 360, 390, 412, 430, 600, 720, 840, 960dp** logical available widths where infrastructure permits. Minimum CI screenshot gate: TH/EN 360/390/430dp; also manual tablet/landscape/split-screen and fontScale 1.0, 1.3, 1.5, 2.0.
- No content clipped or obscured by status bar, notch, keyboard or bottom navigation.
- Search/filter visual sizes compact and balanced; touch target >=48dp.
- Hero CTA fits within banner; no text/image intersection at narrow widths.
- Restaurant area **no outer card**; menu thumbnails **1:1**; no Home "+"; photo/name open correct detail.
- Banners and real data loading/empty/error states behave, no false coupon/promises.
- Account, cart, address, orders and menu options can scroll and submit their existing permitted operations.
- Build gate: latest commit `assembleDebug testDebugUnitTest lintDebug bundleRelease`, 360/390/430 Thai+English Emulator capture, manual device UAT. Any screenshot automation based on old copy must be updated honestly, never disabled to mask failures.

## 8. Delivery phases
**Phase A (this change / implement after spec):** core responsive token utilities with regression tests; adapt Home, header, banner, recommendation and menu row; bounded wide-layout shells and four-tab bottom nav; 360/390/430/600+ visual guardrails; no API/behavior change.
**Phase B (follow-on after physical QA):** systematic tablet two-pane menu and account/order forms, fontScale/IME large text passes across every dialog, full manual landscape/foldable checks.
**No production deployment, Play release, database changes or live order/payment toggle without separate permission.**
