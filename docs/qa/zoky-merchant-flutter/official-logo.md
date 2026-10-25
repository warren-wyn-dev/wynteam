# Official ZOKY logo — 2026-10-24

Founder provided `.wyn/brand/zoky-logo-kit` on `docs/zoky-foundation` as the official logo source. Use `zoky-logo-pink-transparent.png` unchanged: 1140×664 RGBA, Git blob `d233c3597c2aa152ace3622c164cbb60c37b48e1`.

The exact bytes are copied to `web/public/brand/zoky/` for Merchant auth pages and `web/merchant_flutter/assets/brand/` for the Flutter header/sidebar. Preserve aspect ratio, transparency and original color. Merchant remains a text descriptor beside/below the official artwork. No artwork is regenerated or recolored; no font dependency, auth or backend change is involved.

Validation: Flutter analyze/24 tests and release compilation/font guard passed; TypeScript, focused auth lint and 11 merchant account tests passed. Chromium mobile/desktop lifecycle 10/10 passed, including a real PNG load check on the login page. Two focused login captures also passed after waiting for entrance opacity to settle. Screenshots: [mobile login](official-logo/mobile-login.png), [desktop login](official-logo/desktop-login.png), [mobile header](official-logo/mobile-header.png). Synthetic data only; no production release.
