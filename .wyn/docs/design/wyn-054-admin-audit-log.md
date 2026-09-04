# Design Spec — WYN-054 (Audit Log)

Status: active (retroactive — UI ถูก implement และ QA PASS ไปแล้วตาม combined Product+Design task `.wyn/tasks/approved/WYN-054-audit-log.md` — ไม่เคยมีไฟล์ design doc แยกต่างหากมาก่อน)
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/approved/WYN-054-audit-log.md`
อ้างอิง Design system: **`.wyn/docs/design/wyn-admin-design-system.md`** (Black & White Premium)

## Screen — Audit Log (`app/(admin)/audit-log/page.tsx`)

Purpose: ให้ Admin/Moderator อ่าน `audit_log` (บันทึกทุก action สำคัญของ Admin ตั้งแต่ WYN-048) ผ่านหน้าเว็บเป็นครั้งแรก — ก่อนหน้านี้อ่านได้เฉพาะผ่าน SQL editor ตรงๆ เท่านั้น (`audit_log` เองไม่มี SELECT policy ใดๆ โดยตั้งใจ — VIEW `admin_audit_log` คือทางเข้าเดียว)

User Flow:
1. เปิดหน้า → เห็นตารางทุกแถวจากทุก event type เรียงใหม่สุดก่อน (newest-first, ต่างจาก Report Queue ที่เรียง FIFO — audit log คือ "สิ่งที่เพิ่งเกิดขึ้น" ต้องการดูล่าสุดก่อนโดยธรรมชาติ)
2. เปลี่ยน filter ประเภทเหตุการณ์ (dropdown, 10 event type + "ทุกประเภท") → ตารางกรองทันที
3. ไม่มี action ใดๆ ในหน้านี้ — เป็นหน้าอ่านอย่างเดียว (read-only ตาม Master Spec: "ห้าม Admin ปกติลบ Audit Log")

Components:
- **Event Type Filter**: `Select` (shadcn) มุมขวาบนของ filter bar — ตัวเลือก 11 รายการ (10 event type จริง + "ทุกประเภท") แปลไทยครบทุกตัว
- **Table** (มาตรฐานตามหัวข้อ 6.3): คอลัมน์ ผู้ดำเนินการ (`actor_username_snapshot`, เปิดเผยตรงๆ — คนละกติกากับ "reporter identity" ที่ปิดสนิทใน Report/Moderation, เพราะ accountability ของทีมงานต่อกันเองเป็นเรื่องปกติ ต่างจากการปกป้อง reporter จาก target) / เหตุการณ์ (แปลไทยผ่าน `EVENT_TYPE_LABEL`) / Target ID (`font-mono`, เทา) / รายละเอียด (`detail` jsonb, render เป็น formatted `<pre>` ดิบ — generic viewer ไม่ใช่ bespoke renderer ต่อ event type เพราะ event type จะเพิ่มขึ้นเรื่อยๆ ในอนาคต) / เวลา
- Empty state: "ไม่มีรายการในหมวดนี้"

States: Loaded / Empty (ตาม filter ที่เลือก) — ไม่มี pagination ในรอบนี้ (`limit(200)`-ish ceiling เดียวกับ WYN-051/052's `limit 30` แต่ปรับขึ้นเพราะเป็น log ที่ดูผ่านๆ ไม่ใช่ค้นหาด้วยคำเฉพาะเจาะจง)

Responsive Behavior: Desktop-first เหมือนทุกหน้า — คอลัมน์ "รายละเอียด" (`<pre>`) จำกัดความกว้าง `max-w-md` + `overflow-x-auto` ภายในตัวเองไม่ดันตารางกว้างเกิน

Accessibility: `<pre>` ยังอยู่ใน `<td>` ปกติ อ่านได้ผ่าน screen reader ตามลำดับเนื้อหาจริง — `Select` ใช้ Radix มาตรฐานเดิม (`aria-label="กรองตามประเภทเหตุการณ์"`)

Design Rules:
- **ไม่มี renderer เฉพาะต่อ event type** — `detail` แสดงเป็น JSON ดิบเสมอ (ป้องกันไม่ให้ต้องแก้หน้านี้ทุกครั้งที่มี event type ใหม่เพิ่มเข้ามาจาก task อื่น)
- **ไม่มีปุ่มลบ/แก้ไขใดๆ ในหน้านี้เลย** — ตรงตาม Master Spec "ห้าม Admin ปกติลบ Audit Log" (view เป็น SELECT-only โดยโครงสร้าง ไม่ใช่แค่ UI ไม่มีปุ่ม)
- ไม่มี date-range filter ในรอบนี้ (Non-goal ชัดเจนตาม Product spec — `created_at` sort เพียงพอสำหรับ V1)

---

## Visual Refresh (2026-09-04) — Black & White Premium

**สถานะ**: หน้านี้ไม่เคยมี design doc มาก่อน — เนื้อหาทั้งหมดข้างบนคือ spec ฉบับสมบูรณ์ในภาษาระบบใหม่แล้ว

การเปลี่ยนแปลงจาก UI ที่ implement จริงตอนนี้: **แทบไม่มี** — หน้านี้ไม่เคยใช้สี cyan เลยแม้แต่จุดเดียว (ไม่มีปุ่ม primary action ในหน้านี้ตั้งแต่ต้น เพราะเป็นหน้าอ่านอย่างเดียว) การเปลี่ยนแปลงเดียวที่มีคือความสม่ำเสมอของ component กลาง:
- **Table**: header/hover/hairline สี ตามหัวข้อ 6.3 ของ design system (`gray-50`/`gray-50`/`gray-100`) — ปัจจุบันใช้ `bg-muted/40` ซึ่งใกล้เคียงอยู่แล้ว ปรับให้ตรง token เป๊ะ
- **`<pre>` รายละเอียด**: ตัวหนังสือ `gray-500`(light)/`gray-400`(dark) ตาม `caption` token — ไม่เปลี่ยนพฤติกรรม

Handoff: AI Coding — ไม่มีไฟล์เฉพาะของหน้านี้ที่ต้องแก้สี (การแก้ `components/ui/badge.tsx`/global table style ที่จุดเดียวก็ครอบคลุมแล้ว เพราะหน้านี้ reuse pattern กลางทั้งหมด ไม่มี hardcode สีของตัวเอง)
