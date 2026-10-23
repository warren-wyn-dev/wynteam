# ZOKY Stripe-only + auto-refund — gated rollout plan (CTO final review 2026-10-23)

**Status:** CTO verdict APPROVE WITH CONDITIONS. QA Re-test 3 PASS (`feat/zoky-stripe-only-web:.wyn/tasks/qa/ZOKY-stripe-only-auto-refund-qa.md`).

**Branches:**
- Backend: `feat/zoky-stripe-jobs-db` @ `b3ccc010`. A PR to `main` fast-forwards onto `1166a59d`.
- Web and edge: `feat/zoky-stripe-only-web` @ `eeeb5f5e`. This fast-forwards from release `e6f577dc`, and the exception guard simulation PASSes.

Every step needs its own Founder approval, the GitHub `production` review, and a record in APPROVALS.

| # | Step | Must be true before | Rollback |
|---|---|---|---|
| 0 | Merge the payjobs PR to main (deploys nothing). Fast-forward `release/zoky-web-20261018` to eeeb5f5e. | CI green; reviews done | Revert PR on main; revert commit on the release branch (no force push) |
| 1 | Stripe test-mode E2E on a separate Free Supabase staging project (2026-09-27 approval, no spend), with Stripe test keys and a Vercel Preview pointed at staging | Step 0 done | n/a |
| 2 | `food-apply-zoky-stripe-jobs.yml` preflight (read-only) | E2E PASS | n/a |
| 3 | Deploy `stripe-webhook` from main | Preflight shows `refund.*` events, or the Dashboard Connect endpoint lists `refund.created`, `refund.updated`, `refund.failed` and `charge.refund.updated`. Live edge source equals main ≤ 1166a59d (F3). Webhook revert PR prepared. | Revert PR + redeploy (cron must be off) |
| 4 | Deploy `merchant-stripe-refund` from main (F1) | Step 3 healthy | Revert + redeploy |
| 5 | Deploy `food-stripe-refund-worker` | — | Inert until cron |
| 6 | Apply `jobs` | Steps 3–5 done; Vault project URL present; record the legacy-pending and backfill counts | Rollback file (unschedule cron, policy NULL, drop the 3 triggers; tables kept) |
| 7 | Apply `cron` | Step 6 verified | `cron-off` |
| 8 | ZOKY exception EDGE (checkout/cancel @ eeeb5f5e) | Cron ticks; no failed or needs_attention spike | Revert on the release branch, then EDGE again |
| 9 | ZOKY exception PHASE1 web | Step 8 healthy | Vercel Instant Rollback to the e6f577dc deployment |
| 10 | Watch for 24–48 h | — | `cron-off` / earlier steps |
| 11 | `activate` (Stripe-only, PromptPay only) | Founder reviews the PromptPay-ready store count (stores that aren't ready stop taking orders); merchants notified; LOW items ideally fixed | `deactivate` |
| 12 | `backfill` (optional) | Candidates reviewed with merchants (cash refunds already made) | Backfill rollback |

## Staging E2E scenarios
- PromptPay pay leaves the order paid.
- Store cancel creates a refund job, which goes pending/requires_action, then succeeded, then refunded, with exactly one notification each.
- `charge.refunded` is a noop.
- A failed refund ends as paid/failed and sends notices.
- Cancelling an unpaid order expires its Checkout session.
- With the policy on, card is refused; `deactivate` brings back legacy behaviour.
- On an order with no job, the legacy button plus `refund.updated` ends as refunded.
- Duplicate events are ignored.

## Open LOW follow-ups
- ZOKY-152 cancel text in `internal.food_order_status_notify`.
- ZOKY-148 customer copy when a job needs attention.
- Run `admin_food_refund_jobs` daily.
- F4: an adopted, already-succeeded refund can stay pending.
- Workflow and cron headers do not mention the deploy order (F2).
