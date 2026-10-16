# Zoky iOS Home Header Phase 1 — QA checklist

Current status: Phase 1 Header source updated and static GitHub checks completed; latest PNG revision still awaits physical-device Expo Go screenshot review.

## Functional smoke checks (iPhone, Expo Go)

### Phase 1 — selected compact header (priority)

- [ ] Compare the Home header against the approved compact B mockup on a physical iPhone; adjust after screenshot review rather than claim pixel perfection.
- [ ] Recheck after the 2026-10-16 device screenshot: previously the gradient ended in a solid hot-pink band and the wordmark was too close to the white sheet.
- [ ] Preview Home shows only the branded Phase 1 header and blank white canvas; old hero, Ride and other unapproved home sections are hidden.
- [ ] Status bar is light over the pink-to-magenta header, including Dynamic Island/safe-area handling.
- [ ] Header renders `assets/zoky-wordmark-320.png` from the user's transparent logo PNG, not `zoky-wordmark-source.png` (150px) or any manually-traced SVG.
- [ ] Check the actual brand geometry: map-pin `o`, central hole, Z/k/y letterforms and smile. Confirm crisp edges on a Retina iPhone and no pink/black rectangular image background.
- [ ] The 320x177 PNG is an optimized screenshot-preview asset based on a user-provided 1256x1256 transparent source, not an original vector master; report visible banding or jaggies honestly and replace with a larger lossless asset if needed.
- [ ] White circular outlined pink heart sits at right, has a 48pt touch target, and opens a clearly labeled favorites placeholder.
- [ ] The Home header contains NO location, notification bell, cart, welcome copy or extra buttons.
- [ ] The white content beneath the header has softly rounded top corners; gradient has subtle layered waves.
- [ ] Header is compact (approximately 15–20% shorter than the previously approved tall concept).
- [ ] Returning from favorites restores Home; switch tabs and navigate to Food/store/cart without losing state.
- [ ] Verify on small and large iPhone sizes, large fonts and VoiceOver, with touch targets reachable.
- [ ] Favoriting actual stores is NOT implemented in Phase 1; do not claim that user favorites persist.

### Other preview smoke checks (deferred until later phases; not a Phase 1 approval gate)

- [ ] Launch Zoky with Expo SDK 57 and see the refreshed hot-pink home without a crash.
- [ ] The real Zoky wordmark silhouette appears on the Home header only, with no duplicate text or location row.
- [ ] Home CTA and search shortcut both open the Browse screen.
- [ ] Home category tap opens Browse with the selected category.
- [ ] Browse shows correct filtered result count and resettable empty state.
- [ ] Store cards communicate closed/demo state and never imply a real merchant.
- [ ] Ride is labeled Coming Soon and has no active booking action.
- [ ] Tap Food -> search store/menu -> filter menu category -> open store.
- [ ] Closed store cannot add items to cart.
- [ ] Open sample noodle item, verify vertical spicy level is mandatory.
- [ ] Toggle add-on choices respecting max select; adjust quantity.
- [ ] Add chosen menu item, view quantity and illustrative subtotal.
- [ ] Add a different store's item, verify replacing the cart requires confirmation.
- [ ] Reduce/remove line, clear cart, check empty state.
- [ ] Verify checkout is disabled and no network request or payment occurs.
- [ ] Switch tabs; confirm Orders/Messages/Account show non-operational placeholders.
- [ ] Try large fonts, VoiceOver labels, 320pt-wide iPhone and app background/restore.

## Later integration testing (not authorized yet)

- Isolated staging Food + Merchant Supabase with synthetic users and real RLS checks.
- Compare public food_public_catalog response shape against web.
- Cross-user/session isolation, quote validation, closed/stock-out guard, network failures.
- Native secure Auth redirects and storage; never place privileged server secrets in client.
- Server-authoritative order and payment only after a separately approved staging gate.

No production writes, notifications, deployment, release signing, PR merge or store submission.
