# Zoky iOS Design Preview 2 — QA checklist

Current status: source added for review; no Expo Go physical-device execution has been claimed.

## Functional smoke checks (iPhone, Expo Go)

- [ ] Launch Zoky with Expo SDK 57 and see the refreshed hot-pink home without a crash.
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
