# Design Spec — WYN-055 (WYN Official Announcements)

Status: active (retroactive — UI ถูก implement และ QA PASS ไปแล้วตาม combined Product+Design task `.wyn/tasks/approved/WYN-055-official-announcements.md` — ไม่เคยมีไฟล์ design doc แยกต่างหากมาก่อน)
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/approved/WYN-055-official-announcements.md`
อ้างอิง Design system: **`.wyn/docs/design/wyn-admin-design-system.md`** (Black & White Premium)

## Screen — Announcements (`app/(admin)/announcements/page.tsx`)

Purpose: ให้ **Admin เท่านั้น** (ไม่ใช่ Moderator — เข้มกว่าทุก RPC อื่นของ Phase 7 นี้โดยตั้งใจ ตรงตาม Master Spec "Admin สร้างประกาศ") ส่งประกาศระบบถึงกลุ่มผู้ใช้ (ทุกคน/ผู้ใช้ทั่วไป/ทีมงาน) ครั้งเดียวแบบ bulk พร้อมดูประวัติการส่งย้อนหลัง

User Flow:
1. เปิดหน้า → เห็นฟอร์ม Compose (ประเภท/กลุ่มผู้รับ/ข้อความ) ด้านบน + History table ด้านล่าง
2. เลือกประเภท (4 แบบ: อัปเดตระบบ/อัปเดตนโยบาย/แจ้งปิดปรับปรุงระบบ/ประกาศสำคัญ) + กลุ่มผู้รับ (ทุกคน/ผู้ใช้ทั่วไป/ทีมงาน) + พิมพ์ข้อความ → ปุ่ม "ส่งประกาศ" เปิดใช้งานได้เมื่อกรอกครบ
3. กด "ส่งประกาศ" → เปิด Dialog ยืนยัน (แสดงชื่อกลุ่มผู้รับเป็นภาษาไทยที่ชัดเจน เช่น "ส่งถึงผู้ใช้ทั่วไปทุกคน — การส่งนี้ย้อนกลับไม่ได้" + ข้อความที่จะส่งแบบเต็ม) → กดยืนยันอีกครั้ง
4. สำเร็จ → Dialog ปิด, ฟอร์มเคลียร์, ข้อความ "ส่งประกาศสำเร็จ ถึงผู้รับ {N} คน" ปรากฏเหนือปุ่ม, History table รีเฟรช (`router.refresh()`)

Components:
- **Compose Form** (การ์ดเดียว, `max-w-lg`): `Select` ประเภท → `Select` กลุ่มผู้รับ → `Textarea` ข้อความ → ปุ่ม "ส่งประกาศ" (**นี่คือปุ่ม primary action เดียวของหน้านี้** — `variant="primary"`, ink เต็ม)
- **Confirmation Dialog**: ไม่ reuse `ActionDialog` ตรงๆ (โครงสร้างฟิลด์ต่างกัน: ประเภท+กลุ่มผู้รับ+ข้อความ ไม่ใช่แค่ "เหตุผล" เดียว) — แสดงชื่อกลุ่มผู้รับ+คำเตือน "ย้อนกลับไม่ได้" + preview ข้อความเต็มในกล่อง `gray-50` พื้นหลัง (ไม่ใช่ `bg-muted/40` เดิม — ปรับเป็น token ใหม่) + ปุ่มยืนยัน (`primary`, ink เต็ม — **ไม่ใช่ destructive** เพราะการส่งประกาศไม่ใช่การทำลาย/ลงโทษ แค่ "ย้อนกลับไม่ได้" ซึ่งสื่อผ่านข้อความเตือนใน description พอแล้ว ไม่ต้องยืมสีแดงมาใช้)
- **History Table** (มาตรฐานตามหัวข้อ 6.3): คอลัมน์ ประเภท/กลุ่มผู้รับ/ข้อความ (truncate)/จำนวนผู้รับ/ผู้ส่ง/วันที่ — อ่านจาก `admin_audit_log` (WYN-054's VIEW) กรองเฉพาะ `admin_announcement_sent` โดยตรง ไม่มี table คู่ขนาน
- Empty history: "ยังไม่เคยส่งประกาศ"

Interactions: ปุ่มยืนยันใน Dialog ระหว่างส่ง = disabled + `aria-busy` + ข้อความ "กำลังส่ง..." (มิเรอร์ pattern เดิมของ `ActionDialog`/`BanDialog`)

States: Idle (ฟอร์มว่าง) → กรอกครบ (ปุ่มเปิดใช้งาน) → Confirming (Dialog เปิด) → Sending (ปุ่มยืนยัน disabled+busy) → Success (ข้อความจำนวนผู้รับ) หรือ Error (`role="alert"`, ข้อความ "ส่งประกาศไม่สำเร็จ ลองใหม่อีกครั้ง" — Dialog ไม่ปิดให้แก้ไขแล้วลองใหม่)

Responsive Behavior: Desktop-first เหมือนทุกหน้า — Compose Form ความกว้างคงที่ `max-w-lg` ไม่ขยายเต็มจอกว้าง (ป้องกัน Textarea กว้างเกินจนอ่านยาก) — History table `overflow-x-auto`

Accessibility: ทุก `Select`/`Textarea` มี `<label>` ผูกจริง, error message `role="alert"`, ปุ่มยืนยัน `aria-busy` ระหว่าง pending

Design Rules:
- **Admin-only ไม่ใช่ admin/moderator** — ต้องสื่อสารชัดใน UI ถ้า Moderator เผลอเข้าหน้านี้ได้ (เช่นผ่าน URL ตรง) แล้วกด "ส่งประกาศ" ต้องเห็น error ที่ชัดเจนว่าไม่มีสิทธิ์ ไม่ใช่ error ทั่วไปที่ทำให้เข้าใจผิดว่าเป็น bug — **นี่คือจุดเดียวใน Phase 7 ที่ RPC guard เข้มกว่าเดิม (`<> 'admin'` ไม่ใช่ `not in ('admin','moderator')`)** ต้องระวังไม่ให้ UI สื่อสารผิดเป็น "moderator ก็ทำได้" (sidebar เองก็แสดงเมนูนี้ให้ moderator เห็นเหมือนกันทุกเมนู เพราะไม่มีการซ่อนเมนูตาม sub-role ในรอบนี้ — error message ตอนกดจึงต้องทำหน้าที่สื่อสารแทน)
- ไม่มีการแสดง preview ว่า category ไหนมี icon/สไตล์ต่างกันที่ฝั่งผู้รับ (Product's Scope decision ข้อ 3: หมวดหมู่เป็น metadata สำหรับผู้ส่ง/History เท่านั้น ไม่ใช่ rendering ที่ต่างกันฝั่งผู้ใช้)
- ไม่แสดงจำนวนผู้รับ "คาดการณ์" ก่อนส่ง (Product's Scope decision ข้อ 3 ระบุตรงๆ ว่า preview ราคาถูกทำไม่ได้โดยไม่ query ซ้ำ — Dialog ยืนยันด้วยชื่อกลุ่มแทน)

Handoff: AI Coding — ไม่มี component ใหม่ต้องสร้าง (compose-form/history เป็น implementation เฉพาะหน้านี้อยู่แล้ว ไม่ reuse ActionDialog ตามที่ระบุไว้ข้างบน) — เปลี่ยนแค่สี: `Button` "ส่งประกาศ"/ปุ่มยืนยันใน Dialog จาก `--primary` (cyan เดิม) → `ink`, กล่อง preview ข้อความจาก `bg-muted/40` → `bg-gray-50`

---

## Visual Refresh (2026-09-04) — Black & White Premium

**สถานะ**: หน้านี้ไม่เคยมี design doc มาก่อน — เนื้อหาทั้งหมดข้างบนคือ spec ฉบับสมบูรณ์ในภาษาระบบใหม่แล้ว

สรุปการเปลี่ยนแปลงจาก UI ที่ implement จริงตอนนี้:
- ปุ่ม "ส่งประกาศ" และปุ่มยืนยันใน Dialog: cyan (`--primary` เดิม) → `ink` เต็ม+ตัวหนังสือขาว (กรณีข้อ 3 ของกติกาสี — ปุ่ม primary action เดียวของหน้า)
- กล่อง preview ข้อความใน Dialog: `bg-muted/40` → `bg-gray-50` (ตัวเลข token ที่ชัดเจนแทนค่า opacity ลอยๆ)
- History table: header/hover/hairline ตาม token มาตรฐานหัวข้อ 6.3 (เหมือนทุกตารางในระบบ)
- **ไม่มีจุดไหนใช้สีแดง (destructive) ในหน้านี้เลย** — ยืนยันว่าถูกต้องตามกติกาใหม่: การส่งประกาศไม่ใช่ destructive action (ไม่ได้ลบ/แบน/ทำลายอะไร) แค่ "ย้อนกลับไม่ได้" ซึ่งเป็นคนละเรื่องกับ "อันตราย" — คำเตือนสื่อผ่านข้อความ ไม่ใช่สี
