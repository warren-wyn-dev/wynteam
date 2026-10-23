# ZOKY Merchant brand refresh — 2026-10-23

Founder requested a visual refresh matching the live consumer site, https://zoky.wynos.online.

The live consumer stylesheet uses ZOKY header colors `#f93384`, `#f72c7e`, `#ee226e`, action color `#d61256`, pale pink `#ffeff5`, ink `#16161a` and surface `#f6f6f8`. These live tokens take precedence over the older red Food tokens on main.

Merchant now uses the matching pink hero, berry actions, white cards, pale selected navigation, neutral dividers and darker secondary text. Success/payment completion retains semantic green. Buttons have a 48px minimum height; dialogs share the rounded white styling. Narrow or enlarged-text metric layouts switch to one column; delivery-method selection expands within narrow dialogs; menu switches identify the affected item to assistive technology.

Only the Flutter Merchant and its page/PWA theme are changed. Shared login, Food, backend contracts, permissions, storage, payment processing and root cutover are unchanged. No new fonts or dependencies are bundled.

Verification: Flutter analysis and 23 tests; release Flutter compilation and existing font guard; six routing tests; TypeScript check; focused browser lifecycle 10/10 passed with synthetic stores/payments/proofs on mobile and desktop. Screenshots: [mobile](brand-refresh/mobile.png), [desktop](brand-refresh/desktop.png). Screenshot fixtures are synthetic and never access real customer data. Production remains unchanged.
