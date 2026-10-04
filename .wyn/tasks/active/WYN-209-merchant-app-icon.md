# Product Task — WYN-209 — Wynos Merchant app icon

Status: in review — awaiting Founder "อนุมัติ" to merge
Owner: AI Design / AI Coding
Date: 2026-10-04

## Founder direction

- "ออกแบบไอคอนแอป Wynos Merchant ให้ด้วย".
- Standing direction: simple and easy to understand, Wynos red leads, no rainbow.

## Design

- Flat Wynos-red square (light-to-deep red gradient).
- A white storefront with a striped awning, and a red "W" on the shop front.
- Same storefront language as the WYN-208 bottom-bar home icon.
- Source art: `web/public/icons/merchant/v15-source.svg`.

## Files

| File | Use | Shape |
|---|---|---|
| `v15-180.png` | iPhone (apple-touch-icon) | Full-bleed square; iOS rounds it |
| `v15-192.png`, `v15-512.png` | Manifest / browser "any" | Rounded |
| `v15-maskable-512.png` | Android | Full bleed; the shop sits inside the 80% safe zone |

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
