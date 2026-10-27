# ZOKY-BILLING-001: Technical design (monthly store fee)

Status: DRAFT — for CTO/Architect review. Implements the approved PRD
`.wyn/docs/product/zoky-billing-001-monthly-fee.md` (Founder approved 2026-10-27).
Date: 2026-10-27

## 1. Approach

The design reuses the ad top-up pattern that is already in production
(`supabase/migrations_wynos_food_ads_v1.sql`). That pattern is:
- a singleton settings row;
- a transfer slip stored in `food-private/<area>/<store_id>/...`;
- security-definer RPCs that check the role on the server;
- Admin review with an audit entry and a `notifications` row for the store team.

The design adds no new service, Edge Function or dependency.

Nothing changes in production until an Admin sets a price, a ZOKY payment
account and switches billing on. `billing_enabled` defaults to `false`.

## 2. Data model (one additive migration, no change to existing tables' data)

| Table | Purpose |
|---|---|
| `food_billing_settings` (singleton) | Current fee (THB), trial days, and ZOKY payment account (PromptPay and/or bank). Also holds the receipt issuer name and address, `billing_enabled`, and `launched_on` (Bangkok date, set once on first enable and never changed). |
| `food_billing_price_history` | Insert-only history of `monthly_fee` and `trial_days`, with who set them and when (PRD 1). |
| `food_store_billing` | One row per store that has started selling. Fields: `opened_on` (Bangkok date), `trial_days` (snapshot), and `cycle_anchor` = `opened_on + trial_days`. |
| `food_billing_invoices` | One row per store per cycle, enforced by `unique (store_id, period_start)`. Each row snapshots `amount`, and has `due_on` = issue date + 7, a status, the slip, review fields, `receipt_no` and `paid_at`. |
| `food_billing_reminders` | Records which reminder offset (−3, 0, +3, +7) was sent for an invoice, with key `(invoice_id, offset_days)`, so no reminder is sent twice. |

All tables have RLS enabled and every grant revoked from `anon` and
`authenticated`. All access goes through RPCs.

### Opening date and cycles (Q1, Q2, Q4)
- **New store:** a trigger on `food_stores` creates its `food_store_billing` row
  the first time `is_published` becomes true while billing is launched.
  `opened_on` = the Bangkok date at that moment.
- **Store already selling at launch (Q4):** when billing is first enabled, every
  published store gets `opened_on = launched_on`.
- **Cycle start dates:** cycle *n* starts at `cycle_anchor + n months`. It is
  always computed from the anchor, never from the previous cycle, so there is
  no drift. PostgreSQL clamps to the month end, so an anchor on the 31st bills
  on 28/29 Feb and 30 Apr.
- **Invoice amount:** every invoice is a full month (Q2) at the fee current on
  its issue date. A price change therefore only affects later cycles (PRD 1).

### Invoice status
`unpaid → slip_submitted → paid`. Two other transitions exist:
- `slip_submitted → rejected → slip_submitted` (the store sends a new slip);
- `unpaid | rejected | slip_submitted → waived` (Admin only, reason required).

`receipt_no` is set when an invoice becomes `paid`, as `ZK-YYYYMM-NNNNNN` from a
sequence.

## 3. Daily job

`internal.food_billing_run()` runs from `pg_cron` at 01:05 UTC (08:05 Bangkok).
It does nothing while billing is off. When billing is on it:
1. Backfills missing `food_store_billing` rows for published stores (safety net
   for the trigger).
2. For each store whose current cycle has started, inserts that cycle's invoice
   (`on conflict do nothing`). It only does this when the fee is > 0. Missed
   past cycles are not back-billed.
3. Sends reminders for `unpaid` and `rejected` invoices at offsets −3, 0, +3 and
   +7 days from `due_on` (Q3).
   - Reminders go out as `notifications` rows to the active owner/admin members.
     Push goes out through the existing notifications pipeline when the store has
     it switched on.
   - If the job missed a day, it sends only the latest reminder that is due and
     records the earlier offsets as sent.
4. **Never suspends a store (PRD 11).** Admins suspend stores with the existing
   `food_stores.admin_suspended_at` action. That action already hides the store
   from customers (Q7).

The job is idempotent, so running it twice on the same day changes nothing.

## 4. RPCs

| RPC | Gate (server side) | Notes |
|---|---|---|
| `merchant_billing(store)` | `merchant_has_store_role(store, owner/admin)` | Returns status, fee, trial end, next cycle, the ZOKY account, and the last 12 invoices. |
| `merchant_submit_billing_slip(invoice, path)` | Owner/admin of the invoice's store | Status must be `unpaid` or `rejected`. Path must be `billing/<store_id>/<invoice_id>/<file>` with no `..`. |
| `merchant_billing_receipt(invoice)` | Owner/admin of the invoice's store | Works only for `paid` invoices. Returns the receipt fields. |
| `admin_billing_overview()` | `has_admin_permission('merchant','view')` | Returns settings, price history, slips waiting for review, and overdue stores with days overdue. |
| `admin_update_billing_settings(...)` | `has_admin_permission('merchant','edit')` | To enable billing it requires a fee > 0, a ZOKY account and an issuer name. Sets `launched_on` once and backfills stores. Writes an audit entry. |
| `admin_review_billing_invoice(invoice, approve, note)` | merchant:edit | Status must be `slip_submitted`. Rejecting needs a reason. Writes an audit entry and notifies the store. |
| `admin_waive_billing_invoice(invoice, reason)` | merchant:edit | Reason required. Writes an audit entry and notifies the store. |

All RPCs above are security definer with `search_path = ''`. Execute is granted
to `authenticated` only.

**Storage policies on `food-private`:**
- Insert under `billing/<store_id>/<invoice_id>/`: only owner/admin of that store,
  and only when that invoice belongs to that store and is `unpaid` or `rejected`.
- Select: owner/admin of the store. Platform admins can already read all of
  `food-private`.
- No update or delete policy.

## 5. Clients

- **Merchant Flutter app:** a new page "ค่าบริการ ZOKY", shown to owner/admin only.
  - It shows the current invoice and how to pay, attaches a slip, and opens a
    printable receipt for paid invoices.
  - It shows an overdue banner on the home page.
  - All calls go through `merchant-flutter-bridge.ts` with the same checks as
    the existing pickers: picker opened during the tap, image validated, role
    rechecked.
- **Receipt:** a Next page `/merchant/billing/receipt?invoice=<id>`. It uses the
  signed-in session and the `merchant_billing_receipt` RPC, and the browser's
  print dialog saves it as PDF (Q5: a plain receipt, not a tax invoice).
- **Zoky Admin:** a new page `merchant/billing` with:
  - the settings form and price history;
  - the slip review queue (signed URL, approve / reject with reason);
  - the overdue list with a link to the store page, where the existing suspend
    button lives;
  - waive with reason.
- **GP:** unchanged (Q6). Every store stays at 0% and the GP admin page stays.

## 6. Founder decisions on open points (AskUserQuestion, 2026-10-27)

1. **No invoice while the store cannot sell:** a cycle that starts while the
   store is unpublished or suspended is not billed.
2. **Notify on issue:** the store team gets a notification on the day an invoice
   is issued, in addition to the −3/0/+3/+7 reminders.
3. **Owner/admin only:** only the owner and store admins see and pay billing.
   Managers do not.

## 7. Security and QA plan

- **Cross-store access:** reading or paying another store's invoice, slip paths
  for another store or invoice, and direct RPC calls with forged ids must all be
  refused.
- **Uploads:** wrong file type, oversize files, and non-image content.
- **State machine:** a duplicate submit, review of a non-submitted invoice, and
  waive without a reason must all fail.
- **Job:** idempotency, cycle anchors at the month end, the trial boundary, a fee
  change between cycles, and reminder de-duplication.
- **Admin:** view-only Admin cannot change settings or review; a
  non-platform user is refused.
- **Tests:**
  - SQL tests in `supabase/tests/` using synthetic data only;
  - bridge unit tests;
  - Flutter widget tests;
  - Zoky Admin typecheck/build.
  - No production data is used.

## 8. Rollout and rollback

1. DB migration via the reviewed apply workflow, with Founder approval.
   Billing stays off.
2. Zoky Admin deploy and web (Merchant app) release through the existing gates.
3. The Founder sets the price, trial and account in Admin, then switches
   billing on.

**Rollback:**
- Switching billing off stops new invoices and reminders immediately.
- A rollback script drops the new functions, policies, cron job and tables,
  only after export, because invoices are financial records.
