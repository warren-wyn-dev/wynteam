# Product Task — WYN-202 — Wynos Merchant: alert rings until the order is opened or accepted

Status: review — PR open, waiting for Founder approval to merge (web only)
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "ส่วนการแจ้งเตือน ดังจนกว่า จะกดรับออเดอร์ หรือ กดดูออเดอร์" (2026-10-04).

## Scope (web only)

- The new-order alert rings every 2.5 s with no time limit. The 3-minute cap is removed.
- It stops only when the store taps "ดูออเดอร์" / "ดูสลิปและรับออเดอร์", or when the order is accepted (on this device or another one).
- The close (X) button is removed, and Escape no longer dismisses the alert, so it cannot be silenced without opening the order.
- Unchanged:
  - The alert waits while the menu or store editor sheet is open, and it appears and rings as soon as that sheet closes.
  - A new slip for the same order rings again.

## Release

Merge (web auto-deploys). Rollback: revert the merge commit.
