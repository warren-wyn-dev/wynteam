# WYNOS Food Android — Native design parity with food.wynos.online

Last reviewed: 2026-10-14. **Draft PR only; not deployed to Production.**

The website remains the visual and business-flow reference, while Android is
Kotlin + Jetpack Compose throughout — no PWA, TWA or WebView wrapper. This PR
keeps the same WYNOS Food Supabase API, user accounts and saved addresses.

## Parity changes in this PR

| Flow | Food web reference | Native Android implementation |
| --- | --- | --- |
| Home delivery location | Shows the selected delivery location and opens a picker | Shows current selected saved address (fallback to default) and opens a Material 3 bottom sheet; selection invalidates the old server quote |
| Home catalog | Red/white brand palette, storefront photo cards and search | Same palette and fields, readable adaptive columns; lone store takes entire row, multiple stores use two columns when the screen allows |
| Food account | Default recipient and phone are primary, not the login email | Recipient and phone headline with email secondary and ellipsized |
| Saved addresses | Default label and GPS location indicator | Matching default badge, map pin and pin-readiness status |
| Order history | Localized dates and payment-aware status | Thai Buddhist-year / English dates and correct pending/issue/submitted status labels |
| Chat empty state | Distinguishes Food chat from Social chat | Added matching clear explanation without pretending messaging is available |
| Cart bottom action | Large, legible sticky checkout CTA | Native safe-area-aware bottom action and concise disabled text; cannot create/charge live orders |

## Deliberate platform differences / unfinished work

- Native location selection is limited to **already saved addresses**.
  Full web maps/Places picking, recipient updates and address deletion are
  still gated from Production. No GPS or coordinate guesses are made.
- Web promotional placement, discounts, ratings, distance and delivery ETA
  need structured backend data parity before they can be reproduced
  truthfully in Native. Do **not** invent ratings, ETA, or discounts.
- Live ordering/payment, Merchant fulfillment, push and native messaging
  require end-to-end staging integration and separate approvals.
- Android navigation gestures, Back handling, native bottom sheet, native
  safe area and accessibility may differ from web's markup by design.
- No change in web/Supabase Production code, pricing, payment contract,
  account deletion, or release settings.

## Verification

- Android :app:assembleDebug, :app:testDebugUnitTest, :app:lintDebug,
  unsigned :app:bundleRelease.
- Native Thai+English 360/390/430 screenshot QA.
- Unit tests for selected/default delivery address and localized order dates.
- Manual signed-in regression: account with 2 stored addresses, switch in
  Home sheet, verify header and quote invalidation, rotate/recreate, review
  Account/Orders/Cart/Store on a real Android device.
- Release gates remain as documented in PLAY_RELEASE_READINESS_2026.md.
