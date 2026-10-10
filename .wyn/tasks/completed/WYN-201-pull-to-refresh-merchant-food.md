# Product Task — WYN-201 — Pull to refresh in Wynos Merchant and WYNOS Food

Status: approved — released via PR #829
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "ทุกหน้าควรมีรีเฟรช แบบดึงลงรึป่าว". AI recommended list pages only, using the social app's existing pull-to-refresh. Founder: **"อนุมัติ"** (2026-10-04).

## Scope (web only)

- Merchant: the หน้าหลัก, ออเดอร์, เมนู and รายงาน tabs refresh when pulled down from the top.
- Food: the หน้าร้าน/เมนู and ออเดอร์ tabs refresh the same way.
- Both use the shared `usePullToRefresh` hook and `PullToRefreshIndicator`, the same as the social app, so the gesture feels identical.
- Not on forms or sheets (store settings, menu editor, order detail, cart). The hook never starts a pull from dialogs or inputs, and those tabs are disabled.
- Installed PWAs (above all on iPhone) have no browser pull-to-refresh, so this fills that gap. Merchant still updates by itself through realtime.

## Release

Merge (web auto-deploys). Rollback: revert the merge commit.
