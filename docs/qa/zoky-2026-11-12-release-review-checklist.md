# ZOKY release review checklist — 2026-11-12

For the human QA & Security review of what shipped on 2026-11-12 (PRs #1342–#1347).
Automated checks (CI, Codex) passed; nobody has done the human pass yet. Use synthetic
data and test accounts only; do not read real customer data.

## 1. Install card ("add to home screen")
- [ ] iPhone Safari, first visit to zoky.wynos.online: the card appears at once, centered, with ZOKY icon, 3 steps and "ไว้ทีหลัง"; no "เข้าใจแล้ว" button.
- [ ] "ไว้ทีหลัง" closes it; reload shows it again (no cooldown, by design).
- [ ] Android Chrome: install button works; manual steps shown when the install event is missing.
- [ ] Already-installed app (standalone): card never shows.
- [ ] Card does not block checkout or payment screens in a way that loses a basket.

## 2. Delivery location (GPS instead of the map pin)
- [ ] "ใช้ตำแหน่งปัจจุบัน" asks permission only on tap, not on page load.
- [ ] Accuracy > 100 m shows a warning but the address can still be saved.
- [ ] Permission denied / GPS off / timeout: Thai error text, place-search fallback works.
- [ ] Coordinates are validated server-side (no trust of client values); out-of-area address is refused with a clear message.
- [ ] No coordinates in logs, analytics or third-party requests other than the approved place search.
- [ ] Wyn Maps still has its map pin (unchanged).

## 3. LINE removal
- [ ] Settings page (customer and Merchant): no LINE rows or contact link.
- [ ] Store QR (share sheet, poster, Merchant "QR ร้าน"): plain `zoky.wynos.online/s/<code>` link.
- [ ] `/line` and `/line?mode=link&oa=food` redirect to `/food`.
- [ ] A new order produces a Web Push to the merchant device and no LINE message.
- [ ] Opening a ZOKY link from inside LINE's browser is bounced to the system browser.
- [ ] `send-push-notification` logs show no LINE errors after the 2026-11-12 deploy.

## 4. Domains and routing
- [ ] food.wynos.online/<path>?<query> redirects 307 to zoky.wynos.online/<path>?<query>.
- [ ] zoky.wynos.online and merchant.wynos.online are unaffected by each other's settings.
- [ ] Supabase Auth redirect allowlist has no preview-URL entries left.

## 5. Known gaps (not covered by automation)
- No real-device iPhone/Android pass on every screen.
- Android install timing and order-completion impact untested.
- Human security review of: GPS handling, the removed LINE endpoints (verify they are deleted in Supabase), and the 2026-11-12 Supabase token rotation.
