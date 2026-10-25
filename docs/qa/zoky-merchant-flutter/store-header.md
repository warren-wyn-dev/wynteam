# Store-name-only authenticated header — 2026-10-24

Founder requested removing the ZOKY Merchant logo from the shop interface and showing just the shop name. The Flutter header now uses a single row: selected shop/store selector, notification control and refresh. Remove the logo/Merchant descriptor from the desktop sidebar too. Truncate long shop names visually while retaining the full text semantics. Login branding and application identity are outside this authenticated-header change.

Validation: Flutter analyze/26 tests, release compilation/font guard, and four compiled Flutter mobile/desktop payment-to-delivery flows passed. Screenshots use synthetic data: [mobile](store-header/mobile.png), [desktop](store-header/desktop.png). No backend or production routing changes.
