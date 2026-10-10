# Product Task — WYN-215 — Notifications per app + 4-digit order numbers

Status: production rollout verified live 2026-10-05 — `push_tokens.app`, the 4-digit Food order-number function, and `send-push-notification` per-app routing are active in production
Owner: AI Product Manager / AI Coding
Date: 2026-10-05

## Founder direction

- "การแจ้งเตือน งง มาก" (screenshot): one order produced the same notifications in both the WYNOS and the Wynos Merchant Home Screen apps, all titled "WYN".
- Titles (Founder, 2026-10-05): **Wynos** (Social), **Wynos Food** (customer), **WYNOS Merchant** (store). "ถูกต้อง".
- "เลขออเดอร์ 4 ตัว พอ". The WF prefix stays (no answer on dropping it; smallest change).
- "อนุมัติ" (2026-10-05).

## Scope

- Each notification shows only in its own app:
  - **WYNOS Merchant:** store notifications (new order, slip sent, paid, store suspension, ads credit, campaign payout, Merchant application).
  - **Wynos Food:** customer order notifications (paid, slip needs checking, refunded, delivered).
  - **Wynos:** everything else (Social), as before.
- Food and Merchant fall back to the Wynos app when their own app has no registered device, so no order notification is lost.
- Titles as above. A Social notification from a person keeps that person's name as its title (chat sender etc.); only the old "WYN" title becomes "Wynos". The "WYNOS Merchant · " body prefix is dropped (the title says it).
- Tapping a Food or Merchant notification opens that app (`/food`, `/merchant`). Opening the specific order is not in this task.
- New Food orders are numbered `WF0015`, `WF0016`, ...; past orders keep `WF000001`-style numbers. Past 9999 the number grows to 5+ digits (never cut).

## Technical design

- `push_tokens.app` (`social` / `food` / `merchant`, NULL = registered before this change = Social).
- Web: a token is labelled by host (`food.` / `merchant.wynos.online`), or, for an installed Home Screen app on wynos.online, by the path the app was launched at (`/food`, `/merchant`). A browser tab on wynos.online is always Social (it shares one token with the main app). Existing tokens are relabelled the next time each app is opened.
- `send-push-notification`: classifies `system` notifications by the text their database triggers write (`pushAppForNotification`), sends only to that app's tokens (`tokensForApp`), and titles them (`pushMessageForApp`).
  - Known limit: a slip-problem notification whose text is a free-form store note is not recognised and shows in the Wynos app.
- Both web and the function work before the migration is applied (they fall back to the old behaviour), so release order cannot break Push.

## Release order

1. Merge the PR (web deploys).
2. `push-apply-wyn215.yml` with `APPLY-WYN-215`.
3. `deploy-edge-functions.yml` → `send-push-notification`.
4. Open WYNOS, Wynos Merchant (and Wynos Food if installed) once each so their tokens are relabelled.

## Verification

- `deno test supabase/functions/`: 89 passed (7 new).
- `node --test web/tests/*.test.mjs`: 227 passed (4 new), typecheck and eslint clean.
- `supabase/tests/wynos_push_app_routing_test.sh` on PostgreSQL 16: ALL CHECKS PASSED (re-run safe; WF0015; WF9999 → WF10000; unknown app rejected).

## Rollback

`alter table public.push_tokens drop column app;`, re-run `food_next_order_number` from `migrations_wynos_food_merchant_v1.sql`, redeploy the previous `send-push-notification` and revert the web commit.
