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

## Merchant order tabs — prepared 2026-11-01

Founder request: order tabs "ใหม่ · กำลังเตรียม · จัดส่ง · เสร็จ · ยกเลิก". Candidate `release/zoky-line-web-20261101` @ `98ec4b2b` = live `7543acce` + tab UI (`orderTabs`), bridge `delivering` tab reading `ready_for_delivery` + `out_for_delivery` (own-key allowlist; `constructor`/`__proto__`/unknown rejected), updated browser fixtures. Local verification: Flutter analyze clean, 96 Flutter tests, release web build, Next build, bridge 49/49, Merchant Node 101/101, Merchant browser QA 48/48 (Chromium mobile + desktop, incl. delivery and pickup flows through the "จัดส่ง" tab). LINE v2 push fixes (#1308) dispatched as run 41272674550.

## Production — 2026-11-01 (Asia/Bangkok 11:20–11:36)

- LINE push fixes (#1308: slip card, one orange reminder, fulfilment/payment line, one-line headlines): run [41272674550](https://github.com/warren-wyn-dev/wynteam/actions/runs/41272674550), success 04:20 UTC, source `release/zoky-line-push-20261101` @ `8725ac45`.
- Merchant order tabs (#1309): run [41273249812](https://github.com/warren-wyn-dev/wynteam/actions/runs/41273249812) guard, stage and promote all succeeded (promoted 04:36 UTC) after both Founder approvals. Customer hosts now serve `dpl_q64ggYo5yRQFMtwBCd5bG4HfEQDK` (source `98ec4b2b`). Independent check: Merchant root/flutter/`/line`, Food root/`/line`, ZOKY and WYNOS roots → 200; live Flutter build `406687c9aff379f75da3` contains the `delivering` tab; Vercel runtime errors (1h): none. Rollback: Instant Rollback to `dpl_Gd5Ydswjt3YS3umxkxpGP4SmQhKT`.

## 2026-11-01 — Merchant UX redesign round 1 (ZOKY-MERCHANT-UX-002)

- Candidate: `release/zoky-line-web-20261101` @ `301785b8` (base `98ec4b2b`), released via PR #1310 and run 41299720769 (guard, stage and promote all green; Founder approved both Production reviews).
- Scope: redesigned order cards (one-step "ตรวจสลิป/ตรวจเงินเข้า · รับออเดอร์" with server payment check unchanged, ETA chips, items/note/address on card) and 3D tools atlas 652,796 → 72,968 bytes.
- Pre-release QA: Flutter analyze + 96 tests, `next build`, `qa:merchant-flutter` 48/48. One regression (pickup code label shortened) caught and fixed before release.
- Live: `dpl_3NeC39MgBUY5frNZ2UtgQ635u4cT` on merchant.wynos.online and customer hosts; `/merchant/flutter` 200, atlas 72,968 bytes, new strings in `main.dart.js`, no runtime errors.
- Rollback: Vercel Instant Rollback to `dpl_q64ggYo5yRQFMtwBCd5bG4HfEQDK`.
- Next: rounds 2+ (หน้าหลัก, เมนูอาหาร, เพิ่มเติม) per the approved prototype.

## 2026-11-01 — Merchant UX redesign round 2 (ZOKY-MERCHANT-UX-002)

- Candidate: `release/zoky-line-web-20261101` @ `a3f38406` (base `301785b8`), released via PR #1311 and run 41303233421 (guard, stage and promote green; Founder approved both Production reviews).
- Scope: Home one-tap open/close switch and "ต้องทำตอนนี้" counts (new store-scoped `orderCounts` bridge read behind `storeAccess` + RLS, counts only), Menu category/sold-out chips with "N เมนู · หมด X", grouped More rows with 3D icons.
- Pre-release QA: Flutter analyze + 97 tests, bridge node tests 103, `next build`, `qa:merchant-flutter` 48/48.
- Live: `dpl_38dkGyWCexrTsByZdoo6LXjeEQ9d` on merchant.wynos.online and customer hosts; `/merchant/flutter` 200, round-2 strings present in `main.dart.js`, no runtime errors.
- Rollback: Vercel Instant Rollback to `dpl_3NeC39MgBUY5frNZ2UtgQ635u4cT`.

## 2026-11-01 — Incident: Merchant failed to open on Founder's iPhone (rolled back)

- ~14:47Z Founder saw "เปิด Zoky Merchant ไม่สำเร็จ" (20s content timeout) on round 2 (`dpl_38dkGyWCexrTsByZdoo6LXjeEQ9d`).
- Live assets were all served (200); the live round-2 bundle with a synthetic bridge reached content-ready in ~6s in headless Chromium.
- ~14:57Z Vercel Instant Rollback to round 1 `dpl_3NeC39MgBUY5frNZ2UtgQ635u4cT` (approved rollback plan).
- ~14:59Z The legacy Merchant on the same phone showed "กำลังยืนยันการเข้าสู่ระบบ…", i.e. PostgREST 401 "JWT issued at future" outliving the 45s clock-skew retries: Supabase Auth issued a token ahead of the database clock. Not caused by round 2; affects old and new Merchant alike.
- Fix prepared (`b50c0ccd`): the Flutter 20s timeout becomes a non-fatal "slow" state that still reveals the app; hidden-page time is not counted; hard failure at 90s. Re-release of round 2 + fix pending Founder approval.
- ~15:14Z Founder confirmed customers were also affected (system-wide). Founder restarted the Supabase project; sign-in recovered for Merchant and customers. Root cause: Supabase Auth/database clock skew (PGRST303), resolved by the restart.
- 15:29Z Re-release via PR #1312, run 41320562488 (Founder approved both reviews): round 2 + non-fatal slow startup + fresh-token resend for "JWT issued at future" (`ca492fe9`). Live `dpl_DBAanMCH8h91AEoodQcdCZkN7rKn`; `/merchant/flutter` 200, round-2 bundle live, no runtime errors. Rollback: `dpl_3NeC39MgBUY5frNZ2UtgQ635u4cT`.
- Follow-up: if PGRST303 recurs for more than a few minutes, restart the Supabase project and open a Supabase support ticket.

## 2026-11-01 — Merchant speed release (Founder: "Merchant แอบช้า")

- Candidate `0f450a9d` (base `ca492fe9`), PR #1313, run 41324810629; guard, stage and promote green, Founder approved both reviews.
- Scope: instant order tabs (per-scope tab cache), CanvasKit content-addressed separately (`builds/2ae0779baf21c297069c/canvaskit/`, immutable) so app-only releases keep the engine cached, bundled NotoSansThai (SIL OFL, SHA-256 pinned in the font policy; Founder-approved policy change).
- Live `dpl_J4VVC9TZbQ5EXENZNXMCaW5zfJRi`: `/merchant/flutter` 200, FontManifest lists MaterialIcons + NotoSansThai, engine served immutable, no runtime errors.
- Simulated 4G (live bundle, synthetic data): no Google font request; app content 0.6s after view (was 1.4s) and font warmup 0ms (was ~1.5s, timed out). Cold first load is still bound by the one-time ~4 MB download.
- Rollback: `dpl_DBAanMCH8h91AEoodQcdCZkN7rKn`.

## 2026-11-01 — Merchant in-app feedback and help

- Candidate `d8ec38dc` (base `0f450a9d`), PR #1314, run 41327955996; Founder approved both reviews.
- Scope: ฟีดแบ็ก and ช่วยเหลือ open inside the Flutter Merchant (no legacy jump). New bridge read `reviews` (whitelisted fields) and write `replyReview` (manage role + review in store; RPC re-checks).
- Live `dpl_9YrwL9aoUMhMkreXBJoCnzyyCr4r`; `/merchant/flutter` 200, new screens present in `main.dart.js`, engine base unchanged (`2ae0779baf21c297069c`, stays cached).
- Rollback: `dpl_J4VVC9TZbQ5EXENZNXMCaW5zfJRi`.
- Remaining legacy jumps: readiness checklist tools and "เครื่องมือเพิ่มเติม" (intentional escape hatch).

## 2026-11-01 — Merchant store editor in the new app (no legacy jumps)

- Candidate `783e99d2` (base `d8ec38dc`), PR #1315, run 41330703727; Founder approved both reviews.
- Scope: readiness checklist, store status sheet and header bell stay in Flutter; full store editor (images, profile, delivery, GPS pins with service-area check, temporary closure, scheduled orders, tax invoice, publish with readiness gate). Bridge validates every field (manage role) and reads it back.
- Live `dpl_2iVwx34njwqKa4biniz612RmynvQ`; `/merchant/flutter` 200, editor strings present, engine cached (`2ae0779baf21c297069c`), no runtime errors.
- Rollback: `dpl_9YrwL9aoUMhMkreXBJoCnzyyCr4r`. Follow-up option: drag-to-place map pin.

## 2026-11-01 — Merchant map pin picker

- Candidate `04234e53` (base `783e99d2`), PR #1316, run 41334363392; Founder approved both reviews.
- Scope: "เลือกบนแผนที่" for store and pickup pins; host opens the shared ZOKY map picker (search, drag pin, GPS) over the Flutter view via bridge `pickMapLocation` (manage role, coordinates validated, no write until บันทึกข้อมูลร้าน).
- Live `dpl_AZHBwtFSUY5AJZnneGRYRc7YFRaJ`; `/merchant/flutter` 200, new button in `main.dart.js`, engine cached, no runtime errors.
- Rollback: `dpl_2iVwx34njwqKa4biniz612RmynvQ`.

## 2026-11-01 — Merchant speed round 2

- Candidate `1dbe68ae` (base `04234e53`), PR #1317, run 41337082376; Founder approved both reviews.
- Scope: early engine load for returning merchants; store reads overlapped with the stores access revalidation (publish only if still listed); instant reopen from a per-account store snapshot (no orders/customers; cleared on sign-out; read-only until live).
- Live `dpl_57fwHSLJhRAKEpVVfdTFXr1BvP7e`; `/merchant/flutter` 200, engine base unchanged (cached), no runtime errors.
- Rollback: `dpl_AZHBwtFSUY5AJZnneGRYRc7YFRaJ`.

## 2026-11-01 — Zoky Merchant logo as the app icon

- Candidate `d31bd9df`, PR #1318, run 41338842923; Founder approved both reviews.
- Scope: Merchant icons v16 (180/192/512/1024/maskable) from the Founder's Zoky Merchant logo; manifest, layout and Flutter `appleWebApp` title "Zoky Merchant".
- Live `dpl_5Pk8xu5aNnMgqwHnPjF274hZJLDt`; Flutter manifest and HTML serve v16. Main `/merchant/manifest.webmanifest` still served v15 from edge cache at check time.
- Rollback: `dpl_57fwHSLJhRAKEpVVfdTFXr1BvP7e`.
