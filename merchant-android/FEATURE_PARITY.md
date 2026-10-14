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
| Menu create/edit/availability | Partial | Native options, stock, sold-out, delete, picker/preview and image uploads coded; full storage-device QA remains |
| Menu drag reorder, category tools | Partial | Native touch drag, button fallback, category add/rename/reorder/save/cancel coded; multi-edit rollback and device drag QA remain |
| Sales reports | Partial | Best sellers and full reporting UI |
| Merchant finance | Partial | Today/yesterday/week/month/custom ranges, Stripe summary and CSV export coded; graphs, onboarding/refunds and E2E QA remain |
| Store brand media | Partial | Native image picker, preview and EXIF-free compressed logo/cover uploads, clear; needs authorized storage/device QA |
| Store information/hours/closures | Partial | Native 7-day schedule, special holidays, temporary closures, prep times and readiness coded; thorough device/timezone QA missing |
| Delivery zones/maps/favorite addresses | Missing | Store/pickup pin, map picker, delivery range, saved places |
| Store payment/publishing/tax/scheduled orders | Partial | Bank/tax/scheduled settings, readiness-gated publish/unpublish and printing coded; Stripe Connect onboarding, QR upload and full QA remain |
| Merchant audit history | Partial | Last 12 event types/time readable via RPC; advanced activity tools missing |
| Promotions created by stores | Partial | Native add/edit/delete/enable, item scope, discount type, limits and dates coded; backend/permission E2E QA pending |
| WYNOS platform campaigns | Partial | Native campaign list, settlement amounts, WYNOS-vs-merchant share and join/leave with confirmation coded; device/backend QA pending |
| Merchant advertisements | Partial | Ad account/metrics, pause/resume, private slip upload/top-up and history coded; live payment/permission QA pending |
| Customer feedback | Partial | Ratings/feedback read and native merchant reply coded; moderation/details and E2E QA pending |
| Notifications / Push / sound / quiet hours | Partial | Native in-app notification list, read/unread and server test RPC coded; FCM, Realtime, sound, quiet hours and deep links remain |
| Help and customer support | Partial | Native WYNOS official link, troubleshooting and copy diagnostics coded; contextual support flows QA pending |
| Receipt and shipping-label printing | Partial | Native Android Print Framework generates receipt/address PDF; multi-page output, map QR and device-printer QA outstanding |
| Merchant staff/permissions | Partial | Staff list/add/change role/activate via existing server RPCs coded; role/tenant E2E QA pending |
| Multilingual experience | Missing | Mirror currently supported web locales |

**Security gates:** always use merchant's own JWT + public publishable key, never ship service credentials. Require RLS/manager permissions on server; do not implement privileged bypasses. A submitted slip is NOT the same as confirmed payment: before accepting an order in the native app it must be marked paid by the verified backend workflow. Any payment verification/delivery completion additions need a separate security review.

**Stop-release conditions:** any missing web feature; no real-device build; no E2E regression; no reliable FCM; any account/tenant bleed; inability to recover from network loss. Only mark 100% after feature-by-feature acceptance on Android.
