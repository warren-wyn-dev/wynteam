# Product Task — WYN-212 — Home Food banner only for people in Maha Sarakham

Status: approved — Founder "อนุมัติ" 2026-10-04; releasing PR #867
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- Screenshot of the Home "WYNOS Food" banner: "กลัวไปรบกวน คนอื่น".
- Approved points 1–3: "โอเค เอาแบบนี้ ตามข้อ1-2-3เลย".
  1. WYNOS Food stays in the ☰ drawer for every signed-in user.
  2. The banner under the Home tabs shows only to people known to be in Maha Sarakham.
  3. The banner has an ✕ to hide it.

## How "known in Maha Sarakham" works

- Home never asks for GPS.
- When Food's area check (WYN-211) runs, its result is remembered on the device (`wynos-food-area-v1:<user>`).
- Without a remembered answer, Home looks at the user's own saved delivery pin (`food_customer_addresses`, own rows by RLS) and asks the existing `food_service_area_check` RPC.
- Answers are refreshed after 7 days when outside, and after 1 day when there was no pin. An inside answer is kept.
- ✕ stores `wynos-food-shortcut-hidden-v1:<user>` on the device.

Frontend only. No database, API or auth change.

## Verification

- `tsc`, `eslint` and `test:i18n` pass.
- New spec WYN-212 passes, plus the updated WYN-195 spec.
- Remaining failures already fail on `main` (food SEO, map tiles) or need a running server (compact-drawer:43).

## Rollback

Revert the PR.
