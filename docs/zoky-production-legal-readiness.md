# ZOKY legal publication status

Updated 2026-10-20 for the production-readiness patch.

## Initial finding and implemented response

The deployed signup notice originally asserted acceptance of WYNOS terms/privacy without document links. Existing `platform_documents` seeds were heading-only drafts, readable only after sign-in; they were unsuitable as a signup policy destination.

The Founder then requested new drafts: “ไม่มี คิดให้หน่อย”. The patch implements Thai public `/food/terms` and `/food/privacy` pages and links them from signup, with English translations through the existing language system. The documents describe the observed ordering, payment, delivery and shared-account flow. They do not invent an operator, contact address, refund deadline or fixed retention period, and the existing SQL legal seeds/acceptance records remain unchanged.

The pages deliberately state that they are drafts without effect and remain `noindex`. `foodLegalPublication.approved` is false, and operator/contact/effective-date fields remain empty. Code completion is not content approval or production publication.

## Required operator input

- Actual service operator and personal-data controller identity.
- Working contact details and correspondence address for order problems and privacy requests.
- Approval of the drafted text and effective date after reviewing actual responsibilities and operational practices. No legal review or certification is claimed by this task.

The Founder was asked for the operator/contact information during implementation. No answer supplying those facts has been received. Do not substitute guessed information or treat elapsed time as approval.

Before approving publication, confirm the draft's description of providers, retention/deletion, overseas processing, sensitive optional notes/photos and privacy-request handling matches the actual operation. These are verification limits, not findings that those practices are missing or unlawful.

## Acceptance criteria

Signed-out visitors must be able to read both documents before signup, with correct links, titles, contact information and effective dates. The final publication state must be approved, accurately represented and retested on staging. The draft pages and navigation passed the local production-build Chromium suite; final publication/contact checks remain pending.

Detailed source assumptions: `docs/engineering/ZOKY_LEGAL_REVIEW_2026-10-19.md`.
