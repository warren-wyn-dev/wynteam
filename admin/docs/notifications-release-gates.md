# WYNOS Admin Notifications — Phase 3 source preview and future inbox contract

**Status:** Draft first slice only. The implemented page shows actual **pending-work signals**; it is not an event delivery service or persistent unread inbox.

## Implemented now
- `/admin-notifications`: read-only pending Social report rows and Admin-only Merchant application status.
- All source data read with signed-in staff's own RLS-scoped Supabase client. Admin and Moderator roles are verified server-side; **Moderator does not call the Merchant applicant RPC**.
- Database data is reduced to generic label, stable source ID, time and existing authorized route; no customer/merchant contact data, raw reports, tokens or payment fields.
- Bounded latest 10 records per source. Stable source+record keys deduplicate repeated rows. Independent source failure -> "cannot verify", not false empty.
- `NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED` gates the Central menu and protected page; OFF by default.
- No Email Notifications, Web Push, notifications table, Cron, DB writes, alerts sent, read-state changes or new roles.

## Separate design + approvals required for full Admin Notifications
A real persisted staff inbox needs a reviewed recipient-scoped schema and event ingestion contract **before** coding or migrating anything:

| Field / control | Proposed contract (requires review) |
| --- | --- |
| Event identity | `source` + immutable `event_id` + `recipient_id` uniqueness to make retries idempotent |
| Origin | Server-side authoritative report/merchant/incident events, never arbitrary frontend input |
| Delivery | Server-owned recipient resolution; check recipient is still staff and has event/resource permission |
| Read state | Per-recipient read timestamp with server-side ownership/RLS checks, not a LocalStorage-only badge |
| Retention | Proposed 30 days for standard staff signals; confirm by Data/Privacy owners |
| Revocation | Prevent unauthorized older items from being read if role is downgraded or resource permission revoked |
| Retry | Dedupe, bounded retries, backoff, acknowledgement and no spam floods |
| Channels | In-App first; optional Web Push only after opt-in and separate approval; **no Email** |
| Content | Generic metadata; no order/payment/PII or raw incident stack in message body |
| Reliability | Event source integrity, logging/redaction, retention/cleanup, concurrency and load tests |

**Important:** Pending work signals are not necessarily "new notifications" and may predate first visit. The current page never labels them unread or delivered and has no mark-as-read control. System incident notices remain unimplemented until trustworthy alert sources exist.

## Staging verification
- [ ] Guest and ordinary user cannot access, including direct URL.
- [ ] Moderator sees only authorized Social signals; staff with revoked role cannot access stale payload.
- [ ] Admin sees Merchant source without any applicant phone, address, contact name or note.
- [ ] Duplicate source rows display once; missing/partial/failed source is not counted as zero.
- [ ] Staging event fixtures cannot create real notifications, marketing effects or payments.
- [ ] Responsive at 320px, 390px, iPad and desktop; correct focus and labels.
- [ ] Real backend/push/read-state functionality is **not** considered tested by this slice.

## Release safety
This is stacked on unmerged Workspace PR #1053. It does not alter PR #1053, PR #1051, Food/Merchant apps, user roles, orders, payments or any shared database. Feature flag stays OFF until the approved isolated staging E2E gate is met.
