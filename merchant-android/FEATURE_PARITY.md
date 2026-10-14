# Merchant Web → Native Android feature parity checklist

Canonical source: \`web/components/merchant/wynos-merchant-app.tsx\` and imported panels/libs (checked 2026-10-14). This checklist is a release gate, not a claim of completion.

Legend: **Partial** = some working code on this branch; **Missing** = not native yet.

| Web capability | Android status | Remaining work |
| --- | --- | --- |
| Merchant login and active account gate | Partial | Sign-up, password reset, deep-link email confirmation, full auth test |
| Store switcher, session persistence | Partial | Android resilience, credentials QA |
| Home readiness, sales, shortcuts | Partial | Publish checklist, maps/warnings and all shortcuts |
| New / preparing / delivery / finished (24h) | Partial | Full list paging, ETA, delivery evidence, alerts |
| Payment slip and verification | Missing | Signed private media, manual review, secure approval flow |
| Delivered confirmation with dropoff photo | Missing | Photo selection/upload, RPC, failure/retry UX |
| Order history, filters/search/paging | Partial | Status/date search and full pagination |
| Menu create/edit/availability | Partial | Full options, photos, stock, sold out today, delete |
| Menu drag reorder, category tools | Missing | Touch drag, category order/save/cancel |
| Sales reports | Partial | Best sellers and full reporting UI |
| Merchant finance | Partial | Date ranges, graphs, Stripe status, exports, refund handling |
| Store brand media | Missing | Image picker, preview, compression, upload |
| Store information/hours/closures | Partial | Weekday hours, temporary closures, lead times and readiness |
| Delivery zones/maps/favorite addresses | Missing | Store/pickup pin, map picker, delivery range, saved places |
| Store payment/publishing/tax/scheduled orders | Missing | Stripe/payment QR, readiness, invoices, scheduled orders |
| Merchant audit history | Missing | Read-only logs and filters |
| Promotions created by stores | Missing | CRUD, validation, toggles |
| WYNOS platform campaigns | Missing | View, opt-in/out, campaign states |
| Merchant advertisements | Missing | Account, budget, top-up slip, pause and reporting |
| Customer feedback | Missing | Data, moderation/view and actions |
| Notifications / Push / sound / quiet hours | Missing | FCM registration, backend token mapping, settings and deep links |
| Help and customer support | Missing | Native help UI/contact actions |
| Receipt and shipping-label printing | Missing | Android Print Framework and device-printer QA |
| Merchant staff/permissions | Missing | Match any web-accessible permission tools |
| Multilingual experience | Missing | Mirror currently supported web locales |

**Security gates:** always use merchant's own JWT + public publishable key, never ship service credentials. Require RLS/manager permissions on server; do not implement privileged bypasses. A submitted slip is NOT the same as confirmed payment: before accepting an order in the native app it must be marked paid by the verified backend workflow. Any payment verification/delivery completion additions need a separate security review.

**Stop-release conditions:** any missing web feature; no real-device build; no E2E regression; no reliable FCM; any account/tenant bleed; inability to recover from network loss. Only mark 100% after feature-by-feature acceptance on Android.
