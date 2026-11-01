# ZOKY-LINE-001 backend production rollout — 2026-10-31

## Authorization

Founder approved D1–D6 ("อนุญาต"), then instructed "จัดการให้เสร็จ พร้อมใช้งานจริงเลย" and approved all three GitHub Production environment reviews. Record: `.wyn/company/APPROVALS.md` (ZOKY-LINE-001).

## What changed in production

| Step | Run | Result |
|---|---|---|
| PR #1304 merged to `main` (`5b29e05`) | all GitHub Actions CI green (Vercel Git statuses red on every PR: no GitHub account connected to Vercel) | merged |
| `zoky-line-apply.yml` — additive `public.line_links` | [41214649344](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214649344) | success; verified table_ready, rls_on, policies=2, anon_read=false, members_insert=false, members_update=false, members_read_line_id=false, members_delete=true |
| Deploy `line-link` | [41214748754](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214748754) | deployed to `kqokpocajhfbidcxpvhh` |
| Deploy `line-webhook` | [41214751671](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214751671) | deployed to `kqokpocajhfbidcxpvhh` |

Post-deploy public smoke (no credentials, no data written): unsigned webhook → 401; unknown `?oa` → 404; `line-link` without JWT → 401; CORS preflight from `https://food.wynos.online` → 204 with that origin only.

## Deliberately not deployed

- `send-push-notification`: `main` also carries two reviewed but never-deployed push changes since the live 2026-10-05 deploy (`741c6717`): Merchant order details as push title, and no Social push to legacy `app = NULL` tokens. Deploying from `main` would ship them with LINE. Held for a Founder decision (deploy from `main`, or a LINE-only build on the live source). Not needed until LINE secrets exist.
- Web (`/line`, Food menu entry, Merchant card): needs `NEXT_PUBLIC_LIFF_ID_*` at build time and a scoped release on the live bases (Food/ZOKY `93e6954`, Merchant `ddc1fc2`; pending Merchant release `94c8d62`).

## Current state

LINE delivery is off: `LINE_NOTIFICATIONS_ENABLED` and LINE secrets are not set; `line-link` answers 503 `line_disabled` to signed-in callers. No customer-visible change.

## Rollback

Functions are inert without secrets. Table rollback (destructive, Founder approval): `supabase/rollbacks/20261031120000_zoky_line_links_rollback.sql`.

## Follow-up 2026-11-01 — Founder decisions and release plan

- Founder configured both LINE Providers ("Zoky • สั่งอาหาร" for customers, "Zoky Merchant OA" for stores), the Supabase LINE secrets (per-provider Login channel IDs, #1305 / `line-link` redeployed), both webhooks (Verify passed) and the Vercel `NEXT_PUBLIC_LIFF_ID_*` values. `LINE_NOTIFICATIONS_ENABLED` is still unset.
- Founder chose **ข**: deploy `send-push-notification` as live `741c6717` + LINE only. Source `release/zoky-line-push-20261101` @ `47a58c8a` (deno check + 73 tests pass); deployed by `zoky-line-push-deploy.yml` (main-only, typed confirmation, production review, path allowlist against `741c6717`).
- Founder chose to **cancel** the pending Merchant staging run 41154897642 (`94c8d62`) and fold it into the LINE web release. Candidate `release/zoky-line-web-20261101` @ `7543acce` = `94c8d62` + web part of #1304 only. History is linear (`93e6954` ⊂ `ddc1fc2` ⊂ `94c8d62`) and everything after `93e6954` is Merchant-scoped, so one artifact serves all customer hosts. Local verification: lint, typecheck, `next build`, line 8/8, i18n 48/48, merchant-flutter 101/101, notifications 60/60, push-toggle 35/35, share-links 19/19.
- `zoky-web-thai-mobile-release.yml` retargeted to that candidate (confirmation `ZOKY_LINE_WEB_20261101`, expires 2026-11-14), with per-host drift check (Merchant `dpl_HRTFBBHb…`, others `dpl_2muRGSzQ…`) and `/line` added to staged and public smoke checks.

## Production release — 2026-10-31 18:43–18:49 UTC

- `send-push-notification` LINE-only build deployed: run [41229070763](https://github.com/warren-wyn-dev/wynteam/actions/runs/41229070763) (source `47a58c8a` on live `741c6717`), success after Founder approval.
- Web release: run [41229073133](https://github.com/warren-wyn-dev/wynteam/actions/runs/41229073133) — guard, stage (authenticated checks incl. `/line`) and promote (per-host drift check, public smoke incl. `/line`, Merchant entry 307) all succeeded after both Founder approvals.
- All customer hosts now serve `dpl_Gd5Ydswjt3YS3umxkxpGP4SmQhKT` (verified `food.wynos.online`, `merchant.wynos.online` aliases). Independent HTTP check: `/line` on Food and Merchant, Food/ZOKY/WYNOS roots, Merchant root and login → 200; `/merchant?order=…` → 307 `/merchant/flutter?order=…`. Vercel runtime errors (1h): none.
- Rollback: Vercel Instant Rollback to `dpl_2muRGSzQwa7qxcHjYAApkbxBbJuJ` (Food/ZOKY/WYNOS) / `dpl_HRTFBBHb6s6wpQZ69J1fgEERW5yP` (Merchant); LINE delivery: unset `LINE_NOTIFICATIONS_ENABLED`.
- Remaining: Founder sets `LINE_NOTIFICATIONS_ENABLED=1` and performs the real-account link + test notification.

## Founder real-account acceptance — 2026-11-01 02:04 (Asia/Bangkok)

Founder set `LINE_NOTIFICATIONS_ENABLED=1`, linked the Merchant store account at `/line?mode=link&oa=merchant`, and sent the Merchant notification test. The message "ทดสอบการแจ้งเตือน" with the "เปิดดู" button arrived in the Zoky Merchant OA chat (Founder screenshot). Merchant LINE delivery: **PASS** end to end on production. Customer (food) link/test not yet performed.

Customer (food) link: first attempt returned `invalid_line_token` because `LINE_FOOD_LOGIN_CHANNEL_ID` did not match the channel holding the food LIFF (Provider "Zoky • สั่งอาหาร" has both a LINE Login and a LINE MINI App channel named "Zoky"). Founder corrected the secret to that channel's ID; link then succeeded (no redeploy). Customer LINE message delivery on a real order not yet observed.

## v2 LINE cards — 2026-11-01 03:00 UTC

Founder-approved redesign (#1307): Flex cards with status colour, order details (items, store-only note, total), fewer store messages (slip-submitted and unpaid new-order skipped; COD/paid/unreadable always sent), friendlier wording, no customer name/phone/address. Deployed by run [41266443505](https://github.com/warren-wyn-dev/wynteam/actions/runs/41266443505) from `release/zoky-line-push-20261101` @ `8f4e0557` (live `741c6717` + LINE only): scope guard, deno check and 88 tests passed. Awaiting Founder real-order check.
