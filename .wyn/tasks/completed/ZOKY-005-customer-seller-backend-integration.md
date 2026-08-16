# Product Task — ZOKY-005 (Phase 5)

Status: completed (R1 เท่านั้น — 2026-08-16, แก้แล้ว ผ่าน QA ด้วยการรัน SQL จริงกับ PostgreSQL 16 local; R2/R3 ยังคง backlog แยกต่างหาก)
Owner: AI Product Manager

> **หมายเหตุการตัดสินใจ [2026-08-16]**: Founder สั่งให้เดินหน้าทำงานค้างต่อเนื่องโดยไม่ต้องหยุดถามทุกจุด (บริบทก่อนหน้านี้ในเซสชัน) — จึงดำเนินการ **R1 ตามคำแนะนำเดิมของเอกสารนี้เอง** (in-app notification ผ่านกระดิ่งเดิม ไม่ใช่ push จริง) แทนที่จะหยุดรอคำตอบ 3 ข้อใน Handoff ด้านล่าง ถ้า Founder ต้องการ scope อื่น (เช่น push notification จริง หรือ R2/R3 ทันที) แจ้งได้ — ย้อนกลับได้ง่ายเพราะเป็น additive migration ล้วน (เพิ่ม column/constraint/trigger ใหม่ ไม่แตะของเดิม)

Feature: Phase 5 — เชื่อม Customer ↔ Seller ↔ Backend (ตามหัวข้อใน `.wyn/docs/product/zoky-platform-roadmap.md`)

> **หมายเหตุสำคัญก่อนอ่านต่อ**: หัวข้อ "Phase 5" ใน roadmap doc มีแค่ชื่อหัวข้อ ไม่มีรายละเอียดเหลืออยู่เลย (ต่างจาก Phase 4/SELLER ที่มี Section เต็มจาก master prompt) — เอกสารนี้จึงเป็น**ข้อเสนอที่ AI Product Manager สร้างขึ้นเองจากการ audit ช่องว่างจริงในโค้ดเบส** ไม่ใช่การถอดความจาก spec ต้นฉบับที่ Founder เคยส่งมา ถ้า Founder มีเนื้อหา Section ต้นฉบับที่ตรงกับ Phase 5 อยู่แล้ว ควรส่งมาแทนที่เอกสารนี้จะแม่นยำกว่า

Goal: ปิดช่องว่างการเชื่อมต่อระหว่างแอปฝั่งลูกค้า (`app/`) กับแอปฝั่งร้านค้า (`seller_app/`) ที่ปัจจุบัน**เชื่อมกันแค่ผ่านตาราง database ร่วม** (RLS-based passive sharing) แต่ไม่มีการ "แจ้ง" กันแบบ active เลยสักจุด

Target User: ทั้งลูกค้า (ผู้ซื้อบน ZOKY) และร้านค้า (ผู้ขายบน ZOKY Sellers by WYN)

Problem (จาก audit โค้ดเบสจริง 2026-08-16):

1. **ร้านค้าไม่ได้รับแจ้งเตือนเลยเมื่อมีคำสั่งซื้อใหม่** — ตรวจ `create_orders()` ใน `supabase/schema.sql` แล้วยืนยันว่าไม่มี trigger `notify_*` ใดๆ เกี่ยวกับ order เลย ต่างจากทุก interaction อื่นในระบบ (Like/Comment/Follow/Club events ทุกอย่างมี notification trigger ครบ) — ร้านค้าต้องเปิดแอปมาเช็ค "คำสั่งซื้อ" tab เองเรื่อยๆ ไม่มีทางรู้ทันทีว่ามีคนสั่งซื้อ
2. **ลูกค้าไม่ได้รับแจ้งเตือนเมื่อสถานะคำสั่งซื้อเปลี่ยน** (เช่น seller กด "จัดส่งแล้ว") — เช็ค `notifications` table's `type` CHECK constraint แล้วมีแค่ 9 ประเภท (`like_drop`/`like_pop`/`comment_drop`/`comment_pop`/`follow`/`club_join_request`/`club_join_approved`/`club_post_like`/`club_post_comment`) ไม่มีประเภทเกี่ยวกับ order เลยแม้แต่ประเภทเดียว
3. **Chat ระหว่างผู้ซื้อ-ผู้ขายไม่มีอยู่จริง** — ยืนยันจาก comment ในโค้ดเอง (`store_screen.dart`: "Chat Seller ถูก omit เพราะไม่มีระบบ messaging ในแอปเลยแม้แต่จุดเดียว") — ตรงกับที่ DS-001's audit เคยพบไว้ก่อนหน้านี้แล้วเช่นกัน
4. **ปุ่ม Follow Store มีแต่ใช้งานไม่ได้จริง** — `StoreScreen` มีปุ่ม Follow แต่ตาราง `store_follows` ไม่มีอยู่จริง (ต่างจาก `follows` ที่ใช้กับ user-to-user follow) เป็น known gap ที่ทิ้งไว้ตั้งแต่ ZOKY-001

Requirements (ข้อเสนอ แบ่งเป็นระดับความสำคัญ ให้ Founder เลือก/ตัดขอบเขต):

**R1 (แนะนำ, เร่งด่วนสุด) — แจ้งเตือน Order สองทาง**
- เพิ่ม notification type ใหม่ 3 แบบ: `new_order` (ร้านได้รับ เมื่อลูกค้าสั่งซื้อ), `order_shipped` (ลูกค้าได้รับ เมื่อร้านกดจัดส่ง), `order_delivered_confirmed`/`order_cancelled` (ตามความเหมาะสม)
- Trigger ใหม่ผูกกับ `create_orders()`/`update_order_status()` (มิเรอร์ pattern trigger เดิม 9 ตัวที่มีอยู่แล้ว — security-definer, self-notification guard)
- ขยาย `notifications` table เพิ่ม `order_id` column (มิเรอร์ pattern `club_id`/`club_post_id` ที่เพิ่งแก้ใน SCHEMA-DROP-001)
- ฝั่ง UI: กระดิ่งแจ้งเตือนที่มีอยู่แล้วทั้ง 2 แอป (`NotificationListScreen` ของ `app/`, ยังไม่มีของ `seller_app/`) ต้องแสดง type ใหม่ได้

**R2 (เสนอเป็นเฟสถัดไป ไม่รวมรอบนี้) — Chat ผู้ซื้อ-ผู้ขาย**
- งานใหญ่ระดับ feature ใหม่เต็มรูปแบบ (DB schema/realtime subscription/RLS/UI ทั้ง 2 แอป) ไม่ใช่งานเล็กแบบ R1 — ประเมินว่าควรเป็น task แยกต่างหาก (ZOKY-006?) ไม่รวมในรอบนี้เพื่อไม่ให้ Phase 5 ใหญ่เกินจัดการ

**R3 (เสนอเป็นเฟสถัดไป ไม่รวมรอบนี้) — Follow Store**
- ต้องสร้างตาราง `store_follows` ใหม่ + RLS + UI wiring — ขนาดงานเทียบเท่า R1 แต่คนละ domain แนะนำแยก task (ZOKY-007?)

Acceptance Criteria (สำหรับ R1 เท่านั้น หากอนุมัติแค่ R1):
- [ ] ร้านค้าได้รับ notification ทันทีที่มีคำสั่งซื้อใหม่เข้ามา (real-time ผ่าน DB trigger ไม่ใช่ polling)
- [ ] ลูกค้าได้รับ notification เมื่อสถานะคำสั่งซื้อเปลี่ยนเป็นจัดส่งแล้ว/ถึงแล้ว/ยกเลิก
- [ ] Self-notification guard ถูกต้อง (ไม่มี — order เป็น 2 ฝ่ายต่างกันเสมอ ผู้ซื้อกับเจ้าของร้านเป็นคนละคนโดย RLS ของ orders บังคับอยู่แล้ว)
- [ ] `seller_app/` มีหน้าจอแจ้งเตือนของตัวเอง (ปัจจุบันไม่มีเลย — ต้องสร้างใหม่ มิเรอร์ `NotificationListScreen` ของ `app/`)
- [ ] ไม่กระทบ notification trigger เดิม 9 ตัวที่ผ่าน QA แล้ว
- [ ] `flutter test` ทั้ง 2 แอปผ่านครบ

Dependencies: Phase 4 (SELLER-001 ถึง SELLER-005) เสร็จสมบูรณ์แล้ว — พร้อมเริ่มได้ทันที

Priority: R1 สูง (ช่องว่างจริงที่กระทบการใช้งานจริงทันทีที่มีคำสั่งซื้อจริงเกิดขึ้น) R2/R3 ปานกลาง (เสนอแยก task)

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เอกสารนี้เป็นการตีความช่องว่างเอง ไม่ใช่ spec ต้นฉบับจาก Founder — อาจไม่ตรงกับที่ Founder ตั้งใจจริงสำหรับ "Phase 5" | กลาง | ระบุสถานะ PROPOSED ชัดเจน รอ Founder ยืนยัน/แก้ไข scope ก่อนส่งต่อ Design/Coding |
| R2 | `seller_app/` ไม่มี notification screen เดิมเลย เป็นงานสร้างใหม่ทั้งหมด ไม่ใช่แค่ต่อยอด | ต่ำ | มิเรอร์ `app/`'s `NotificationListScreen`/`NotificationRepository` ตรงๆ ตาม pattern ที่ SELLER-XXX ทุก task ทำมาตลอด |

Recommendation: อนุมัติแค่ **R1** ในรอบนี้ (ขอบเขตเล็ก ชัดเจน กระทบการใช้งานจริงสูงสุด) แล้วแยก R2 (Chat) และ R3 (Follow Store) เป็น task ในอนาคตตามลำดับความสำคัญที่ Founder กำหนด — ไม่แนะนำทำทั้ง 3 อย่างพร้อมกันเพราะ R2 เป็นงานขนาดใหญ่ที่ควรมี Design spec ของตัวเอง

Handoff เดิม (ตอบแล้วโดยดำเนินการ R1 ตามคำแนะนำ ไม่ใช่ Founder ตอบเอง — ดูหมายเหตุด้านบน): คำถามข้อ 2/3 ยังเปิดอยู่จริง (in-app only ในรอบนี้, R2/R3 ยัง backlog) ถ้า Founder ต้องการคำตอบอื่นแจ้งได้ทุกเมื่อ

## Coding Output (R1, 2026-08-16)

**Database** (`supabase/schema.sql`, ส่วนใหม่ "ZOKY-005 R1: Order Notifications" ต่อท้าย SELLER-003 section):
- เพิ่ม `notifications.order_id` (FK → `orders.id` on delete cascade) ผ่าน `alter table` มิเรอร์ pattern `club_id`/`club_post_id` (WYN-015)
- ขยาย `notifications_type_check` เพิ่ม 4 ประเภทใหม่: `new_order`, `order_shipped`, `order_cancelled`, `order_refunded` — ใช้วิธี lookup ชื่อ constraint เดิมแบบ dynamic (ไม่เดาชื่อ) เหมือนที่ SELLER-003 ทำกับ `orders.status`
- `order_delivered_confirmed` **ไม่ได้เพิ่ม** ตามที่ร่างไว้ในเอกสารนี้ตอนแรก — เพราะ transition นั้นเป็นการกระทำของผู้ซื้อเอง (`confirm_order_received`) ไม่มีอีกฝ่ายให้แจ้ง
- Trigger ใหม่ 4 ตัว บน `orders` (security-definer, มิเรอร์ pattern trigger เดิมทั้งหมด):
  - `orders_notify_new_order` (after insert) — แจ้งเจ้าของร้าน เมื่อ `create_orders()` สร้าง order
  - `orders_notify_shipped` (after update, `ready_to_ship`→`shipped`) — แจ้งผู้ซื้อ
  - `orders_notify_cancelled` (after update, →`cancelled`) — **ทิศทางไม่คงที่**: ใช้ `auth.uid()` เทียบกับ `buyer_id`/store owner เพื่อรู้ว่าใครเป็นคนยกเลิก แล้วแจ้งอีกฝ่าย (`cancel_order` ผู้ซื้อกดเอง vs `seller_cancel_order` ร้านกดเอง ใช้ trigger เดียวกันคุมทั้งคู่)
  - `orders_notify_refunded` (after update, →`refunded`) — แจ้งผู้ซื้อ
  - ทุก trigger มี self-notification guard (กันกรณีเจ้าของร้านซื้อสินค้าร้านตัวเอง)

**`app/` (ลูกค้า)**:
- `WynNotification`/`NotificationType` เพิ่ม 4 type ใหม่ + `orderId`/`orderStoreName` field (ดึงผ่าน `order:orders(store:stores(name))` embed)
- `NotificationListScreen` เพิ่มข้อความไทยเฉพาะ type และเปิด `ZokyOrderDetailScreen` เมื่อแตะ — ต้อง thread `zokyRepository` ใหม่ผ่าน `HomeFeedScreen`/`root_shell.dart` เพราะเดิม Home ไม่เคยต้องใช้ ZokyRepository

**`seller_app/` (ร้านค้า) — สร้างใหม่ทั้งฟีเจอร์ ไม่เคยมีมาก่อน**:
- `features/notification/data/seller_notification.dart` — model แคบกว่า `app/` เพราะร้านค้ารับได้แค่ 2 type (`new_order`, `order_cancelled` ทิศทางที่ผู้ซื้อยกเลิก) — `order_shipped`/`order_refunded` เป็นทิศทางถึงผู้ซื้อเสมอ ไม่มีทางถึงร้าน
- `SellerNotificationRepository` filter query ด้วย `.inFilter('type', [...])` ไม่ใช่แค่พึ่ง model กันเอง — ป้องกัน crash ถ้า profile เดียวกันมี notification ฝั่ง social จาก `app/` ปนมา (ใช้ recipient_id ร่วมกันข้ามแอป)
- `SellerNotificationListScreen` มิเรอร์ `NotificationListScreen` โครงสร้างเต็ม เปิด `SellerOrderDetailScreen` เมื่อแตะ
- ปุ่มกระดิ่ง + badge จำนวนไม่อ่าน เพิ่มใน `SellerDashboardScreen`'s AppBar (ไม่มี tab ที่ 6 เหลือใน bottom nav 5 ช่องเดิม)
- `SellerHomeShell`/`SellerAuthGate` เพิ่ม optional constructor injection `notificationRepository` มิเรอร์ pattern เดิมของ `SellerAuthGate` (เพื่อให้ test แทนที่ real Supabase client ได้)

## QA Verification (2026-08-16)

- `flutter analyze` ทั้ง 2 แอป: No issues found
- `flutter test`: `app/` 283/283 ผ่าน, `seller_app/` 96/96 ผ่าน (รวม test ใหม่ที่เพิ่มสำหรับ 4 order type + SellerNotificationListScreen ทั้งไฟล์)
- **รัน SQL จริงกับ PostgreSQL 16 local** (ไม่ใช่แค่อ่าน static) — โหลด `supabase/schema.sql` ทั้งไฟล์ผ่าน stub `auth`/`storage` schema สำเร็จไม่มี error แล้วจำลอง flow จริงในทรานแซกชันเดียว (rollback หลังทดสอบ):
  - ผู้ซื้อสั่งซื้อจริงผ่าน `create_orders()` → ร้านได้ `new_order` notification ✅
  - ร้านเดิน order ผ่าน `seller_start_processing`→`seller_mark_ready_to_ship`→`seller_ship_order` → ผู้ซื้อได้ `order_shipped` **แค่ครั้งเดียว** (ไม่ใช่ทุก status hop) ✅
  - ผู้ซื้อกด `cancel_order()` เอง → ร้านได้ `order_cancelled` โดย actor เป็นผู้ซื้อ ✅
  - ร้านกด `seller_cancel_order()` เอง (order อื่น) → ผู้ซื้อได้ `order_cancelled` โดย actor เป็นร้าน ✅ (ยืนยันทิศทางสองทางถูกต้องจาก trigger เดียว)
  - ร้านกด `seller_mark_refunded()` → ผู้ซื้อได้ `order_refunded` ✅
  - เจ้าของร้านสั่งซื้อสินค้าร้านตัวเอง → ไม่มี self-notification เกิดขึ้น ✅
  - Regression: trigger เดิม (`follow`) ยังทำงานปกติไม่ถูกกระทบ ✅

Handoff ถัดไป: R2 (Chat)/R3 (Follow Store) ยัง backlog รอ Founder จัดคิว — ไม่ได้แตะในรอบนี้ตามคำแนะนำเดิมของเอกสาร
