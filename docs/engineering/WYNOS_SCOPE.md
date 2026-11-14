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
- **เตรียม branch ลบโค้ดโซเชียลแล้ว แต่ยังไม่ merge:** `claude/remove-social-from-web` (ลบ 187 ไฟล์จาก `web/`; ผ่าน tsc, eslint, `next build`, Playwright 99 specs) **ห้าม merge จนกว่า cutover จะได้รับอนุมัติและ `wynos.online` ถูกเสิร์ฟจาก repo ใหม่แล้ว** เพราะ `web/` ปัจจุบันยัง deploy `wynos.online`
- **ยังไม่ย้าย** Supabase migrations/Edge Functions และ Vercel deploy/โดเมน — มีแผนฉบับร่างรอ Founder อนุมัติที่ `docs/SUPABASE_SEPARATION_PLAN.md` และ `docs/CUTOVER_PLAN.md` ใน Norswor-WYNOS
- ช่วง production freeze (ดู `WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`) ยังมีผล: ไม่มีการ deploy หรือเปลี่ยน production จากงานนี้
