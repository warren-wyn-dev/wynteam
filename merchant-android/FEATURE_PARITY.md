# Merchant Web → Native Android feature parity checklist

Canonical source: `web/components/merchant/wynos-merchant-app.tsx` and imported panels/libs (checked 2026-10-14). This checklist is a release gate, not a claim of completion.

Legend: **Partial** = a code path exists but production QA and/or feature subflows are outstanding; **Missing** = not native yet.

| Web capability | Android status | Remaining work |
| --- | --- | --- |
| Merchant login and active account gate | Partial | Sign-up, password reset, deep-link email confirmation, full auth test |
| Store switcher, session persistence | Partial | Android resilience, credentials QA |
| Home readiness, sales, shortcuts | Partial | Publish checklist, maps/warnings and all shortcuts |
| New / preparing / delivery / finished (24h) | Partial | ETA and delivery photo flow coded; paging, Realtime, alerts and device QA still missing |
| Payment slip and verification | Partial | Signed private image preview + human confirmation and issue/paid RPC coded; needs authenticated device/RLS security QA |
| Delivered confirmation with dropoff photo | Partial | Image picker, preview, EXIF-stripping JPEG upload and completion RPC coded; needs on-device/storage RLS testing and retries |
| Order history, filters/search/paging | Partial | Search, date/status filters and 30-row paging coded; needs E2E validation |
| Menu create/edit/availability | Partial | Options editor, stock, sold-out, delete coded; image uploads, category tools and edge-case QA remain |
| Menu drag reorder, category tools | Partial | Button-based item reorder/save/cancel coded; direct touch drag and category management UI missing |
| Sales reports | Partial | Best sellers and full reporting UI |
| Merchant finance | Partial | Date ranges, graphs, Stripe status, exports, refund handling |
| Store brand media | Missing | Image picker, preview, compression, upload |
| Store information/hours/closures | Partial | Profile, delivery fees, basic preparation hours and server readiness coded; weekday schedule, dates, maps missing |
| Delivery zones/maps/favorite addresses | Missing | Store/pickup pin, map picker, delivery range, saved places |
| Store payment/publishing/tax/scheduled orders | Partial | PromptPay/bank/tax/scheduled settings coded; Stripe onboarding, QR upload, publish gating, printing missing |
| Merchant audit history | Partial | Last 12 event types/time readable via RPC; advanced activity tools missing |
| Promotions created by stores | Missing | CRUD, validation, toggles |
| WYNOS platform campaigns | Missing | View, opt-in/out, campaign states |
| Merchant advertisements | Missing | Account, budget, top-up slip, pause and reporting |
| Customer feedback | Missing | Data, moderation/view and actions |
| Notifications / Push / sound / quiet hours | Missing | FCM registration, backend token mapping, settings and deep links |
| Help and customer support | Missing | Native help UI/contact actions |
| Receipt and shipping-label printing | Partial | Native Android Print Framework generates receipt/address PDF; multi-page output, map QR and device-printer QA outstanding |
| Merchant staff/permissions | Missing | Match any web-accessible permission tools |
| Multilingual experience | Missing | Mirror currently supported web locales |

**Security gates:** always use merchant's own JWT + public publishable key, never ship service credentials. Require RLS/manager permissions on server; do not implement privileged bypasses. A submitted slip is NOT the same as confirmed payment: before accepting an order in the native app it must be marked paid by the verified backend workflow. Any payment verification/delivery completion additions need a separate security review.

**Stop-release conditions:** any missing web feature; no real-device build; no E2E regression; no reliable FCM; any account/tenant bleed; inability to recover from network loss. Only mark 100% after feature-by-feature acceptance on Android.
