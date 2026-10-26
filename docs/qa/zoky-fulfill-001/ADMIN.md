# Scoped ZOKY Admin fulfillment candidate

Base: live Admin8fab9b4b, separate from the web71f7fb0f baseline. Only zoky-admin code and this evidence change.

Order lists use server-side mode/payment/status/refund-age filters before pagination. Detail shows pickup time/code, request state and private refund evidence. A refund older than24h is highlighted; finance aggregates paid delivered/picked-up orders on the server by fulfillment/payment. Existing Stripe history remains visible. Signing validates food-edit permission and the authorized order's store/order prefix; no arbitrary URL/path is accepted.

Validation:3/3 synthetic tests for overdue boundaries/Stripe+COD exclusions, permission+path-limited private signing, and RPC-filter forwarding. Production build and TypeScript pass; lint has0errors1existing warning. Backend actual role denial and aggregation bounds tested in the web/database SQL suite. No live database/customer data used.

Deployment depends on the reviewed ZOKY-FULFILL-001 migration and its hosted staging verification. Existing all-main deployment is unsuitable: release the exact candidate SHA with the separately reviewed scoped workflow, behind staging/production reviews. No migration/deployment has occurred from this worktree.
