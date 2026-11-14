# WYNOS — Scope

**WYNOS = แอปโซเชียลที่ `https://wynos.online` เท่านั้น** ไม่เกี่ยวกับบริการอื่น

## บริการอื่น (ไม่ใช่ WYNOS)

| บริการ | โดเมน / ตำแหน่ง |
|---|---|
| WYNOS Food | `food.wynos.online`, `web/app/food`, `web/components/food` |
| Merchant / ZOKY | `merchant.wynos.online`, `zoky.wynos.online`, `web/app/merchant`, `web/merchant_flutter`, `zoky-admin/` |
| WYNOS Maps | `maps.wynos.online`, `geo.`, `routing.`, `web/app/maps`, `web/app/api/maps` |
| LINE entry | `web/app/line` |
| Admin | `admin.wynos.online`, `admin/` |
| Android / Flutter app | `android/`, `app/` (พักการพัฒนา) |

## โค้ดของ WYNOS โซเชียล

ย้ายไปที่ repository แยกแล้ว: <https://github.com/warren-wyn-dev/Norswor-WYNOS>
(branch `claude/sharp-planck-ysorua`, รอ Founder review/merge) รายละเอียดขอบเขตอยู่ที่ `docs/SCOPE.md` ใน repo นั้น

## สถานะการย้าย

- **คัดลอกแล้ว** — `web/` ส่วนโซเชียล (ตัด Food, Merchant, Maps, LINE ออก) ผ่าน lint, typecheck, unit tests และ build
- **ยังไม่ลบ** โค้ดโซเชียลใน `web/` ของ repo นี้ — `web/` ยังเป็นโปรเจกต์ที่ deploy `wynos.online` และบริการอื่นอยู่ จึงรอ Founder อนุมัติ cutover
- **ยังไม่ย้าย** Supabase migrations/Edge Functions (ฐานข้อมูลใช้ร่วมกับบริการอื่น และเป็น production) และ Vercel deploy/โดเมน
- ช่วง production freeze (ดู `WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`) ยังมีผล: ไม่มีการ deploy หรือเปลี่ยน production จากงานนี้
