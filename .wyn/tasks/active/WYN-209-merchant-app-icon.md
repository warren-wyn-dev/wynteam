# Product Task — WYN-209 — Wynos Merchant app icon

Status: in review — awaiting Founder "อนุมัติ" to merge
Owner: AI Design / AI Coding
Date: 2026-10-04

## Founder direction

- "ออกแบบไอคอนแอป Wynos Merchant ให้ด้วย".
- After seeing a new storefront design, the Founder asked for the original artwork instead: "ชอบแบบเดิม ไม่มีขอบขาว และอยากให้เพิ่มคำว่า Merchant บนไอคอน".

## Design

- The original glossy red icon with the white W and the shop under the middle peak, redrawn as a vector so every size is sharp.
  - The only intact copies of the old artwork were 180–192px; every larger file was corrupted.
- Full-bleed red with no white border around the icon.
- The word **Merchant** in white under the W.
- Source art: `web/public/icons/merchant/v15-source.svg`. Its text uses Liberation Sans Bold; the shipped PNGs are pre-rendered.

## Files

| File | Use | Shape |
|---|---|---|
| `v15-180.png` | iPhone (apple-touch-icon) | Full-bleed square; iOS rounds it |
| `v15-192.png`, `v15-512.png` | Manifest / browser "any" | Rounded |
| `v15-maskable-512.png` | Android | Full bleed; the W and the word sit inside the 80% safe zone |

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
