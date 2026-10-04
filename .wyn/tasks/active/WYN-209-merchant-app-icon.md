# Product Task — WYN-209 — Wynos Merchant app icon

Status: in review — awaiting Founder "อนุมัติ" to merge
Owner: AI Design / AI Coding
Date: 2026-10-04

## Founder direction

- "ออกแบบไอคอนแอป Wynos Merchant ให้ด้วย".
- "ชอบแบบเดิม ไม่มีขอบขาว และอยากให้เพิ่มคำว่า Merchant บนไอคอน".
- The Founder then supplied the exact artwork (1254px glossy W + shop): "ไอคอนที่อยากได้ แค่อยากเพิ่มคำว่า Merchant ในไอคอน และจัด ไอคอน ชื่อ ให้สวย ตรงกลาง".

## Design

- The Founder's artwork, unchanged. The W + shop is cropped from it with soft edges and placed on a full-bleed red background in the same reds, so there is no white border.
- **Merchant** in white Outfit Bold (OFL), with the same soft pink bevel and shadow as the mark. The Founder picked the largest text size (option C).
- The mark and the word are centred together as one group.
- Master: `web/public/icons/merchant/v15-1024.png`.

## Files

| File | Use | Shape |
|---|---|---|
| `v15-180.png` | iPhone (apple-touch-icon) | Full-bleed square; iOS rounds it |
| `v15-192.png`, `v15-512.png` | Manifest / browser "any" | Rounded |
| `v15-maskable-512.png` | Android | Full bleed; the mark and the word are smaller so they sit inside the 80% safe zone |

- Manifest URL bumped to `?v=15`, so installed phones fetch the new icon.

## Bug fixed along the way

The live `v14-512.png` was a truncated PNG: its IDAT chunk was cut off and it had no IEND. Android and Chrome were drawing a broken 512px and maskable icon.

The new spec checks that every published icon is a whole PNG of the stated size.

## Verification

- tsc and eslint pass.
- `wynos-merchant.spec.ts`: 66 passed, including the WYN-209 check.
- Home-screen preview rendered for iPhone and Android masks.

## Rollback

Revert the PR, which points everything back to v14.

Note: phones that already installed the app may keep the old icon until they re-add it to the home screen.
