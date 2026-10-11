# WYNOS Admin — Discovery, Gap Analysis และแผนงานตาม Master Implementation Prompt

วันที่: 2026-10-11 · Branch: `claude/wynos-admin-merchant-finance` · สถานะ: รอ review / QA / Founder approval

เอกสารนี้ตอบ Phase 0 (Discovery & Safety) ของ Master Prompt และบันทึกงานที่ลงมือทำจริงในรอบนี้
ทุกอย่างอ้างอิงจาก source code ใน repo ณ วันที่เขียน — ไม่ได้สมมติว่าบริการใดมี API ถ้าไม่พบในโค้ด

---

## 1. Architecture เดิม (ตรวจจากโค้ดจริง)

| ส่วน | สิ่งที่พบ |
|---|---|
| Admin app | `admin/` — Next.js 16.3 (App Router) + React 19 + TypeScript + Tailwind 4 + shadcn/ui (เขียนเอง) · Vercel project แยก · โดเมน `admin.wynos.online` (ผูกเมื่อ 2026-10-11) |
| Backend | Supabase project เดียวร่วมกับ WYNOS Web / Food / Merchant / Maps — ไม่มี backend service แยก |
| Data access ของ Admin | **ทุกการอ่าน/เขียนผ่าน RPC `SECURITY DEFINER` ที่ตรวจสิทธิ์ใน DB** ด้วย session ของผู้ใช้เอง (`@supabase/ssr`) — **ไม่มี service-role key ใน Admin** |
| Authentication | Supabase Auth (บัญชีเดียวกับ WYNOS Account) · `proxy.ts` ตรวจ session · `requireAdminRole()` ตรวจ `platform_role` + สิทธิ์ใน layout ฝั่ง server |
| Authorization | WYN-219: `public.admin_permissions` (system × view/edit) + `internal.platform_super_admins` · `internal.has_admin_permission(system, level)` ถูกใช้ในทุก admin RPC (step 2 deploy แล้ว) · systems = account, social, food, merchant, maps |
| Payments | Stripe Connect (Standard, **direct charge เข้าบัญชีร้าน, ไม่มี application fee**) + PromptPay slip ของร้าน · Stripe automatic payout เข้าธนาคารร้าน · webhook → `food_stripe_payouts` |
| Merchant finance | `merchant_finance_summary` (WYN-210) ฝั่งร้าน: รายได้ = ยอดขายสุทธิ − ค่าโฆษณา + ส่วนแบ่งแคมเปญ WYNOS · **ไม่มี GP / commission ในระบบ** |
| WYNOS ส่วนแบ่งแคมเปญ | `food_order_campaigns.platform_funded` + `food_platform_settlements` (บันทึกการโอนโดย admin, ล็อกแถวกันโอนซ้ำ) |
| Notifications | Web Push / in-app / realtime (WYN-190, WYN-215) · ไม่มี Email · Promo notifications ของ Food มี cron |
| Audit | `public.audit_log` + view `admin_audit_log` (super admin only) · `internal.log_audit_event()` |
| Tests | DB: 114+ สคริปต์ `supabase/tests/*.sh` บน PostgreSQL จริงใน CI · Admin: lint + typecheck ใน CI (ไม่มี unit test framework) |
| Deploy | `deploy-admin.yml` (manual) · migration ใช้ workflow `*-apply-*.yml` แบบ manual dispatch หลัง Founder อนุมัติ |

## 2. ฟีเจอร์เดิมที่พบ (ใช้งานได้จริง มี backend)

| หมวด | หน้า | ความสามารถ |
|---|---|---|
| Dashboard รวม | `/` | metrics, trends, DAU chart, feed algorithm observability |
| Dashboard รายระบบ | `/dashboard/{account,social,food,merchant,maps}` | สรุปจาก RPC เดิม |
| Account | `/users`, `/users/[id]` | ค้นหา, directory, ดูบัญชี, แบน/ระงับ/ปลดแบน, ประวัติ moderation |
| Account | `/team` | ให้/ถอนสิทธิ์รายระบบ (super admin) + audit |
| Social | `/moderation`, `/reports`, `/announcements` | ค้น/ซ่อน/คืนโพสต์, คิวรายงาน, ประกาศ + inactive reminder (ส่งเอง) |
| Food | `/food/orders`, `/food/orders/[id]` | ออเดอร์ทุกร้าน, รายละเอียด, timeline, สลิป |
| Merchant | `/food`, `/food/stores/[id]` | ร้านค้า, ระงับร้าน, ทีมร้าน |
| Merchant | `/merchants` | ตรวจใบสมัคร Merchant (approve/reject) |
| Merchant | `/food/coupons`, `/food/campaigns`, `/food/ads`, `/food/notifications` | คูปอง, แคมเปญ WYNOS ที่ร้านเลือกเข้าร่วม + โปรลูกค้าใหม่ 100/40 + บันทึกการโอนส่วนแบ่ง, โฆษณา + top-up, แจ้งเตือนโปร |
| Maps | `/maps/places` | จัดการสถานที่, import, suggestion, ตรวจรูป |
| ส่วนกลาง | `/audit-log` | Audit Log (super admin) |

## 3. ตารางเมนูเดิม → เมนูใหม่

| เมนู | ก่อน | หลัง (รอบนี้) | หมายเหตุ |
|---|---|---|---|
| หมวดสุดท้ายของ Sidebar | อื่นๆ | **ส่วนกลางและระบบ** | ตาม Master Prompt §2.2 |
| การเงินร้านค้า | ไม่มี | **WYNOS Merchant → การเงินร้านค้า** (`/merchant/finance`) | ไม่สร้างหมวด Finance & GP แยก |
| Store Detail | หน้าเดียวยาว | **7 แท็บ** Overview / Store Info / Menus / Operations / Promotions / Finance / Activity Logs (`?tab=`) | Finance แสดงอ่านอย่างเดียว ลิงก์ไปการเงินร้านค้า |
| อื่นๆ ทั้งหมด | — | ไม่เปลี่ยน | URL และสิทธิ์เดิมคงเดิม |

Sidebar ยังมี Dashboard รวม + 6 หมวด ตามที่กำหนด ไม่มีหมวดหลักใหม่

## 4. ฟีเจอร์ที่นำกลับมาใช้ (Reuse)

- สูตรเงินของร้านจาก `merchant_finance_summary` (WYN-210) — คัดลอกนิยามเดียวกันทุกบรรทัด และ **test เทียบผลกับฟังก์ชันเดิมทีละ field**
- `internal.food_platform_owed_rows` (WYN-206) สำหรับยอด WYNOS ค้างโอน
- `internal.has_admin_permission` (WYN-219) สำหรับสิทธิ์
- RPC เดิมของ Store Detail (`admin_food_store_detail`, `admin_food_orders`, `admin_wynos_place_for_store`) และ view `admin_audit_log`
- Component/สไตล์เดิมของ Admin (Badge, NoAccess, RefreshButton, การ์ดสถิติ, tab pattern แบบลิงก์)

## 5. ฟีเจอร์ที่พัฒนาเพิ่มในรอบนี้

| ฟีเจอร์ | ไฟล์ |
|---|---|
| RPC `admin_merchant_finance_overview(from, to)` (read only, merchant:view) | `supabase/migrations/20261011120000_admin_merchant_finance_overview.sql` |
| Rollback | `supabase/rollbacks/20261011120000_admin_merchant_finance_overview_rollback.sql` |
| DB behaviour test (39 assertions + เทียบ 11 field กับ `merchant_finance_summary`) | `supabase/tests/admin_merchant_finance_overview_test.sh` |
| Production apply workflow (manual, ต้องพิมพ์ยืนยัน, main only) | `.github/workflows/admin-apply-merchant-finance.yml` |
| หน้า การเงินร้านค้า: ภาพรวม, รายได้ร้านค้า, ยอดค้างจ่าย, การจ่ายเงินให้ร้านค้า (Stripe payout), ประวัติการโอน, GP (รอการตัดสินใจ) + ตัวกรองวันนี้/7/30 วัน/กำหนดเอง | `admin/app/(admin)/merchant/finance/page.tsx`, `admin/lib/admin-merchant-finance.ts` |
| Store Detail แบบแท็บ + Activity Logs ของร้าน | `admin/app/(admin)/food/stores/[id]/page.tsx`, `admin/lib/admin-audit-log.ts` |
| Sidebar: ส่วนกลางและระบบ + การเงินร้านค้า | `admin/lib/admin-nav.ts` |

## 6. API Changes

- **เพิ่ม** `public.admin_merchant_finance_overview(p_from date, p_to date) returns jsonb` — additive, stable, `security definer`, `search_path = ''`, revoke จาก `public/anon`
- ไม่มีการแก้ RPC, table, policy หรือ view เดิม → **backward compatible** กับ Web/Food/Merchant/Maps ทั้งหมด
- ไม่คืนเลขบัญชีธนาคาร, PromptPay ID, Stripe account ID หรือข้อมูลลูกค้า (มี test ยืนยัน) — คืนเฉพาะเลขบัญชี 4 ตัวท้าย

## 7. Permission Matrix (สถานะจริงหลังรอบนี้)

| การกระทำ | super admin | merchant:edit | merchant:view | food:edit | food:view | ไม่มีสิทธิ์ |
|---|---|---|---|---|---|---|
| ดูการเงินร้านค้า `/merchant/finance` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| ดูแท็บ Finance ของร้าน | ✅ | ✅* | ✅* | ❌ | ❌ | ❌ |
| เปิด Store Detail | ✅ | — | — | ✅ | ✅ | ❌ |
| ระงับร้าน / ปิดสิทธิ์ทีมร้าน | ✅ | — | — | ✅ | ❌ | ❌ |
| ดูออเดอร์ (ข้อมูลลูกค้า) | ✅ | — | — | ✅ | ❌ | ❌ |
| Activity Logs ของร้าน | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| บันทึกการโอนส่วนแบ่ง WYNOS | เดิม (platform admin, ไม่เปลี่ยน) | | | | | |
| แก้ GP / อนุมัติ payout | **ยังไม่มีฟีเจอร์** (รอ Business Decision) | | | | | |

\* Store Detail เปิดด้วยสิทธิ์ food (เมนู Stores ยังใช้สิทธิ์ `food` ตาม decision 2026-10-11) — แท็บ Finance ต้องมี merchant เพิ่ม
ทุกช่องบังคับใช้ใน DB (RPC) ไม่ใช่แค่ซ่อนเมนู

**ข้อจำกัดที่ต้องตัดสินใจ:** โมเดลสิทธิ์ปัจจุบันมีแค่ระดับระบบ × view/edit — สิทธิ์ละเอียดแบบ `merchant.finance.read`, `merchant.gp.update`, `merchant.payout.approve`, `food.refund.approve`, `marketing.banner.publish` ใน Master Prompt **ยังไม่มี** การเพิ่มคือ authorization architecture change → ต้องมี proposal + Founder approval (ดู §10 ข้อ D1)
รอบนี้จึงเลือก merchant:view สำหรับการเงินแบบอ่านอย่างเดียว ถ้า Founder ต้องการจำกัดให้แคบกว่านี้ (เช่น super admin เท่านั้น) แก้ได้ในฟังก์ชันเดียว

## 8. Automated Test Results (รอบนี้)

| Check | ผล |
|---|---|
| `supabase/tests/admin_merchant_finance_overview_test.sh` (PostgreSQL 16) | **PASS** — สิทธิ์ (food-only/user/owner/signed-out ถูกปฏิเสธ, anon ไม่มี execute), ตรงกับ `merchant_finance_summary` ทุก field, ขอบวันเวลาไทย, payout/settlement ตามช่วง, ไม่รั่วเลขบัญชี/Stripe ID, idempotent |
| `npm run lint` (admin) | PASS |
| `npx next typegen && npx tsc --noEmit` (admin) | PASS |
| `npm run build` (admin) | PASS |
| Playwright (Chromium) กับ `next start` + mock Supabase ที่เรียก **ฟังก์ชันจริงบน Postgres local** | **44/44 PASS** — desktop 1366 + mobile 390: ตัวเลขจริง, ตารางร้าน, payout, GP pending, fallback ช่วงวันผิด, 7 แท็บร้านโหลดได้, sidebar ใหม่, ไม่มี horizontal scroll, ไม่มี client error; บัญชี food-only ถูกปฏิเสธหน้า/แท็บการเงินและไม่เห็นเมนู |

ยังไม่ได้ทดสอบกับ staging/production database (ต้อง apply migration หลัง Founder อนุมัติ)

## 9. Security Review (รอบนี้)

- Read only ทั้งหมด: ไม่มีปุ่มจ่ายเงิน, คืนเงิน, หรือแก้ค่าการเงิน → ไม่มีความเสี่ยงจ่ายซ้ำ/replay จากงานนี้
- สิทธิ์ตรวจใน DB (`has_admin_permission('merchant','view')`) — เรียก API ตรงก็ถูกปฏิเสธ (BOLA/direct-API bypass ทดสอบแล้ว)
- Sensitive data masking: เลขบัญชี 4 ตัวท้ายเท่านั้น; ไม่มี Stripe account ID / PromptPay ID
- `search_path = ''`, revoke `public/anon`, ช่วงวันจำกัด 366 วันกัน query หนัก
- Audit log query ของร้าน: validate UUID ก่อนใส่ใน filter (กัน filter injection) และยังผ่าน view ที่จำกัด super admin
- ไม่มี secret ใหม่, ไม่มี service-role ใน Admin
- ข้อสังเกตเดิม (ไม่ได้แก้รอบนี้): `admin_platform_owed` คืนเลขบัญชีธนาคาร/PromptPay เต็มให้ platform admin เพื่อใช้โอนเงินจริง — ควรพิจารณาจำกัด/ปกปิดในรอบถัดไป (**MEDIUM**, ต้อง Founder ตัดสินเพราะกระทบขั้นตอนโอนเงินจริง)

## 10. Business Decisions ที่ต้องได้รับการยืนยัน (ห้ามสร้างค่าเอง)

| # | เรื่อง | ทำไมต้องตัดสิน |
|---|---|---|
| B1 | WYNOS จะเก็บ GP หรือไม่ / เริ่มเมื่อไร / อัตราเริ่มต้น | ปัจจุบัน 0% — ร้านรับเงินเต็มผ่าน Stripe direct charge |
| B2 | ฐานคำนวณ GP (ก่อน/หลังส่วนลดร้าน, ส่วนลดแพลตฟอร์ม, ค่าส่ง) | กระทบรายได้ร้านทุกออเดอร์ |
| B3 | วิธีเก็บ GP: Stripe application fee ต่อออเดอร์ หรือหักตอน settlement (และกรณีจ่ายด้วยสลิป PromptPay เข้าบัญชีร้านตรง) | กระทบ payment architecture และสัญญากับร้าน |
| B4 | VAT / ภาษีหัก ณ ที่จ่าย / ใบกำกับภาษีค่า GP | ข้อกฎหมาย |
| B5 | การปัดเศษ และการคืน GP เมื่อ refund เต็ม/บางส่วน/ยกเลิก | ความถูกต้องทางบัญชี |
| B6 | รอบ settlement / payout หากไม่ใช้ Stripe automatic payout | ตอนนี้ Stripe โอนอัตโนมัติ — Admin ไม่ควรมีปุ่มจ่ายเงิน |
| B7 | ผู้อนุมัติ GP override / payout / refund (กี่คน, maker-checker หรือไม่) | Approval workflow |
| B8 | โปรลูกค้าใหม่ 100/40 อยู่ที่ Campaigns (Merchant) หรือย้ายไป Platform Marketing | Master Prompt จัดเป็น Platform Marketing แต่ decision 2026-10-11 วาง Campaigns ใต้ Merchant |
| D1 | เพิ่ม permission ระดับ feature (finance, gp, payout, refund, banner) | authorization architecture change |
| D2 | Refund จาก Admin (ตอนนี้ร้านเป็นผู้คืนผ่าน `merchant-stripe-refund`) | กระทบ payment flow + ต้อง idempotency |

## 11. สถานะรายฟีเจอร์ตาม Master Prompt

สัญลักษณ์: ✅ Implemented & Tested · 🟡 Implemented, Pending Integration · 🔵 Existing (ก่อนรอบนี้) · ⛔ Requires Business Decision · ⬜ Not Implemented

| หมวด | ฟีเจอร์ | สถานะ |
|---|---|---|
| Navigation | Dashboard รวม + 6 หมวด, ยุบ/ขยาย, drawer มือถือ, deep link | 🔵 + ✅ (เปลี่ยนชื่อหมวดส่วนกลางและระบบ) |
| Navigation | Search menu, สลับภาษาไทย/อังกฤษใน Admin | ⬜ |
| Dashboard รวม | สมาชิก/active/ร้าน/ออเดอร์ | 🔵 · ตัวกรองช่วงเวลา, รายได้ GP ⬜/⛔ |
| Account | User Management, ระงับ/ปลดระงับ, ประวัติ | 🔵 · หมายเหตุภายใน, Verification, Security/Sessions, Service Access, Analytics ⬜ |
| Social | Moderation, Report Center, Announcements | 🔵 · Clubs, Official Accounts, WYNOS Plus, Analytics ⬜ |
| Food | Orders + detail | 🔵 · Customers, Payments & Refunds, Support, Discovery/Delivery Settings, Analytics ⬜ |
| Merchant | Stores, Verification, Coupons, Campaigns, Ads, Promo Notifications | 🔵 |
| Merchant | Store Detail แบบ 7 แท็บ | ✅ (Menus/Promotions แสดงสถานะ "ยังไม่มี API" ตามจริง) |
| Merchant | การเงินร้านค้า: ภาพรวม, รายได้ร้าน, ยอดค้างจ่าย, payout status, ประวัติการโอน | 🟡 tested locally — รอ apply migration บน production |
| Merchant | GP Management / Calculation Engine / ค่าคอมมิชชัน / รายการปรับปรุงยอด | ⛔ B1–B7 |
| Merchant | Payout approval / กดจ่ายเงิน | ⛔ B6 (Stripe โอนอัตโนมัติอยู่แล้ว) |
| Merchant | Menu Management จาก Admin | ⬜ (ต้องมี RPC ร่วมกับ Merchant backend) |
| Merchant | รายงานการเงิน + export CSV | ⬜ |
| Maps | Place Management | 🔵 · Categories, Map Reports, Analytics, Settings ⬜ |
| ส่วนกลาง | Audit Logs, Roles & Permissions | 🔵 |
| ส่วนกลาง | AI Secretary, Platform Marketing (Banner/Placement Registry), Notification Management, System Settings | ⬜ |

## 12. Production Deployment Plan

1. PR → review (CTO) → QA & Security ใช้รายงานนี้ + CI (lint/typecheck/DB tests)
2. Founder อนุมัติ apply migration → รัน `Admin -- apply Merchant Finance overview` (พิมพ์ `APPLY-ADMIN-MERCHANT-FINANCE`) บน main
3. ลำดับปลอดภัย: **apply migration ก่อน deploy Admin** ก็ได้หรือหลังก็ได้ — ถ้า Admin ขึ้นก่อน หน้า/แท็บการเงินแสดงสถานะ "ยังไม่ได้ติดตั้ง" แทน error
4. Founder อนุมัติ production deploy → `deploy-admin.yml`
5. Smoke test: เปิด `/merchant/finance` (super admin) ทุกแท็บ, Store Detail แท็บ Finance, บัญชีที่ไม่มีสิทธิ์ merchant ถูกปฏิเสธ; ตรวจยอดของร้านหนึ่งให้ตรงกับหน้าการเงินของร้านใน merchant.wynos.online ช่วงเดียวกัน
6. Monitor: Vercel logs (`admin-vercel-logs-check.yml`) และ Supabase logs 24 ชม.

## 13. Rollback Plan

- Admin: redeploy deployment ก่อนหน้าใน Vercel (instant rollback) — ไม่มี state ฝั่ง Admin
- DB: `supabase/rollbacks/20261011120000_admin_merchant_finance_overview_rollback.sql` (drop function เดียว, ไม่มีข้อมูลหาย, ไม่มีระบบอื่นเรียกใช้)
- Sidebar rename/แท็บร้าน: revert commit

## 14. คู่มือการใช้งาน (สั้น)

- **WYNOS Merchant → การเงินร้านค้า**: เลือกช่วงเวลา (วันนี้ / 7 วัน / 30 วัน / กำหนดเอง ไม่เกิน 366 วัน, เวลาไทย)
  - *ภาพรวมการเงิน*: ยอดขายสุทธิ, รายได้ร้านรวม, คืนเงิน, ค่าโฆษณา, ส่วนแบ่ง WYNOS, ยอด WYNOS ค้างโอน, ความพร้อมรับเงินของร้าน + วิธีคำนวณ
  - *รายได้ร้านค้า*: ตารางทุกร้าน เรียงตามยอดขาย (เลื่อนแนวนอนบนมือถือ) — กดชื่อร้านไปแท็บ Finance ของร้าน
  - *ยอดค้างจ่าย*: ร้านที่ WYNOS ยังค้างโอนส่วนแบ่ง — บันทึกการโอนที่หน้า Campaigns (มีการตรวจยอดและกันโอนซ้ำ)
  - *การจ่ายเงินให้ร้านค้า*: สถานะ Stripe payout (อ่านอย่างเดียว)
  - *ประวัติการโอน*: การโอนส่วนแบ่งที่บันทึกไว้ ใครบันทึก เลขอ้างอิง
  - *GP / ค่าคอมมิชชัน*: รายการเรื่องที่ต้องตัดสินใจก่อนเปิดใช้
- **Stores → ร้าน → แท็บ**: ลิงก์แต่ละแท็บแชร์ได้ (`?tab=finance` ฯลฯ)

## 15. ลำดับงานถัดไปที่แนะนำ (ไม่ต้องรอ business decision)

1. Food → Payments & Refunds แบบอ่านอย่างเดียว (Stripe payments, slip review queue, refund status) — ไม่สร้าง refund logic ใหม่
2. Merchant → รายงานการเงิน export CSV (ต้องเลือกสิทธิ์ export)
3. Account → หมายเหตุภายใน + Sessions & Devices (อ่าน `auth.sessions` ผ่าน RPC)
4. Platform Marketing → Placement Registry + Banner (เริ่มจาก Food Home banner ที่มีจุดแสดงผลจริง WYN-212)
5. Menu Management อ่านอย่างเดียวจาก Merchant backend

แต่ละข้อเป็น PR แยก มี migration + test + rollback + workflow apply ของตัวเอง
