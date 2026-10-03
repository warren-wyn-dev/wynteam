# Product Task — WYN-195 — WYNOS Food entry inside the social app

Status: review
Owner: AI Product Manager / AI Coding
Date: 2026-10-03

## Founder direction

- "WYNOS Food ควรมีอยู่ในหน้าโซเซียลนะ"
- In AskUserQuestion: placement **"แถบลัดใต้แท็บหน้าหลัก กับ ในเมนูด้านข้าง"**; audience **"เฉพาะ developer ก่อน"**

## Scope

- A "WYNOS Food · สั่งอาหาร ส่งถึงที่" row directly under the Home tabs (`components/home/home-food-shortcut.tsx`), linking to `/food`.
- A "WYNOS Food" row in the Home drawer menu.
- Both are shown only when `useIsDeveloperAccount()` is true (fails closed). `/food` keeps its own server-side developer gate.
- Neutral row in the Home style, with one warm accent on the icon (light and dark).

## Acceptance criteria

1. Developer accounts see the Food row under the Home tabs and in the drawer, and both open `/food`.
2. Non-developer accounts see neither.
3. Quick compose, tabs, feed and the drawer are otherwise unchanged.
4. Thai/English strings are covered; lint, typecheck and Food/Merchant specs pass.

## Out of scope

- Opening Food to every account (needs a separate Founder decision and the server rollout setting).
- Bottom navigation changes.
