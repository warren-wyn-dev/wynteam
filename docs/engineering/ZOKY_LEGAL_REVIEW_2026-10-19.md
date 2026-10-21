# ZOKY terms and privacy publication review

Status: drafted in response to the Founder's instruction “ไม่มี คิดให้หน่อย”. Not published or legally reviewed. The document pages deliberately show a draft notice and `noindex` until the operator confirms publication details and approves the final content.

## Scope and implementation

- Public Thai pages: `/food/terms` and `/food/privacy`, under the existing Food layout. They require no account or database read.
- Signup now links the existing notice to both documents. Privacy is described as a notice to read, not blanket consent for all processing.
- Copy is in `web/lib/food-legal.ts`; the shared server-rendered view and styles are in `web/components/food/food-legal-page.*`.
- `foodLegalPublication` contains intentionally empty operator/contact/effective-date fields and `approved: false`. Do not mark approved or remove the draft notice based only on code completion.
- No migration, legal seed replacement, consent gate, authentication change, new analytics, or external message was added.

## Facts checked against the application

| Document topic | Source checked |
| --- | --- |
| ZOKY branding, canonical host and Food routing | `web/lib/food-origin.ts`, `web/proxy.ts`, `web/app/food/layout.tsx` |
| Shared WYNOS Account, email and Google sign-in; no Social profile required | `web/components/food/food-auth.tsx` |
| Recipient/contact/address/location, order states, receipts and delivery proofs | Types and mutations in `web/lib/food-customer.ts` |
| Direct payment/slips and optional Stripe checkout | `uploadFoodPaymentSlip`, `startFoodStripeCheckout`, `cancelFoodStripeCheckout` in `web/lib/food-customer.ts` |
| Cancellation depends on current order state | `cancelFoodCustomerOrder` and its error mapping in `web/lib/food-customer.ts` |
| Refunds have a distinct status and provider handling | `web/lib/food-merchant.ts`, `web/lib/merchant-core.ts` |
| Public reviews and merchant responses | `FoodStoreReview` and review operations in `web/lib/food-customer.ts` |
| Local cart/favorites/history/preferences | `web/components/food/food-guest-browse.tsx`, `web/components/food/wynos-food-developer-app.tsx` |
| Supabase storage/auth, Firebase push, Vercel analytics/performance and maps | `web/lib/supabase/browser.ts`, `web/lib/push-notifications.ts`, `web/app/layout.tsx`, maps functions in `web/lib/food-customer.ts` |

The copy does not invent a company, contact, fixed refund deadline, universal refund eligibility, fixed data-retention period, domestic hosting region, or legal certification. It preserves rights required by Thai law rather than purporting to waive them.

## Required operator review before publication

1. Confirm the actual service operator and personal-data controller name, a working contact email and contact address. No guessed identity or support channel is displayed.
2. Confirm the effective date and review the complete Thai text, especially merchant/platform responsibilities, cancellation/refund handling, and statutory consumer rights. Legal review remains recommended; no lawyer approval is asserted.
3. Confirm operational retention rules for accounts, order records, tax information, payment slips, delivery photos, logs and backups, and who can fulfil access/deletion requests. The draft states purpose-based retention and legal exceptions, without an unverified deletion deadline.
4. Confirm processor contracts, hosting regions, overseas transfer safeguards and the actual enabled analytics/notification/map providers. The draft lists observed integrations but is not evidence that their operational agreements or safeguards have been reviewed.
5. Confirm the lawful basis and minimisation procedure for health/allergy details entered in optional notes, delivery-proof photos, and any processing that requires consent. The draft does not treat account creation as sensitive-data or marketing consent.
6. Review cookies/analytics consent requirements for the deployment and actual configuration. This change does not add a consent mechanism or alter the existing analytics implementation.
7. Confirm the controller can receive and handle rights requests, verify identity safely, and respond under applicable law. The privacy document itself does not implement a rights-request workflow.

These are publication review items, not claims that the corresponding operational processes are missing or noncompliant. The code audit cannot establish them.

## Verification

Focused ESLint and TypeScript checks, plus local anonymous browser verification, are recorded in the task handoff. Browser evidence is stored outside the repository at `/workspace/zoky-audit/legal-local-2026-10-19/`. The check uses local development with fake Supabase configuration, blocks external browser requests, and does not create accounts, orders, payments, or rights requests.

For release QA: open each route directly without a session, verify draft/publication status and canonical metadata, follow both signup links and return paths, check mobile width and keyboard focus, and confirm there are no page errors after the Food splash ends. After final content approval and actual publication fields are set, repeat the metadata and displayed contact checks in staging before production approval.
