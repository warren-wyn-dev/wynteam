# Design Spec — WYN-053 (WYN Admin Report Center)

Status: active (retroactive — UI ถูก implement และ QA PASS ไปแล้วตาม combined Product+Design task `.wyn/tasks/approved/WYN-053-admin-report-center.md`, "Owner: AI Product Manager + AI Design (combined)" ไม่เคยมีไฟล์ design doc แยกต่างหากมาก่อน — เอกสารนี้บันทึก UI ที่มีอยู่จริงให้อยู่ในรูปแบบมาตรฐานเดียวกับ WYN-049 ถึง 052 แล้ว re-skin ตามระบบใหม่ทันที)
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/approved/WYN-053-admin-report-center.md`
อ้างอิง Design system: **`.wyn/docs/design/wyn-admin-design-system.md`** (Black & White Premium — ใช้ตั้งแต่ต้น ไม่มี "เวอร์ชันเก่าแบบ cyan" สำหรับหน้านี้ เพราะไม่เคยมี design doc มาก่อนที่จะต้อง re-skin) — reuse component เดิมทั้งหมดจาก WYN-051/052 (`ActionDialog`/`Badge`/`Table` pattern) ไม่มี component ใหม่

## Screen 1 — Report Queue (`app/(admin)/reports/page.tsx`)

Purpose: ให้ Admin/Moderator เห็นคิว Report ทั้งหมดของทั้งแพลตฟอร์ม (8 ประเภท target ตาม `reports_target_type_check`: user/drop/drop_comment/club/club_post/club_post_comment/message/redrop) ในที่เดียว — เป็นจุดเข้าแบบ "เริ่มจาก Report" คู่กับ WYN-051/052 ที่เป็นจุดเข้าแบบ "เริ่มจาก User/Drop โดยตรง"

User Flow:
1. เปิดหน้า → เห็นตาราง Report เรียงเก่าสุดก่อน (FIFO — ไม่มี severity/risk score ในสคีมาให้เรียงแบบอื่น, "Risk Classification" ของ Master Spec คือคอลัมน์ `category` ที่มีอยู่แล้ว) กรองเริ่มต้นที่ "รอดำเนินการ" (`pending`/`reviewing` รวมกัน)
2. เปลี่ยน filter บนแถบสถานะ (รอดำเนินการ/ดำเนินการแล้ว/ยกเลิกแล้ว/ทั้งหมด) → ตารางอัปเดตทันที (client-side navigation ผ่าน query string `?status=`)
3. คลิกแถวไหนก็ได้ → **routing แยกตาม `target_type`**: `user` ไป `/users/{target_id}` (WYN-051), `drop` ไป `/moderation/{target_id}` (WYN-052), 6 ประเภทที่เหลือไป `/reports/{id}` (Screen 2 ใหม่ของหน้านี้)

Components:
- **Status Filter**: กลุ่มปุ่ม 4 ปุ่มแนวนอน ("รอดำเนินการ"/"ดำเนินการแล้ว"/"ยกเลิกแล้ว"/"ทั้งหมด") เหนือตาราง — ปุ่มที่เลือกอยู่ = พื้น `gray-100` + ตัวหนังสือ `ink` + font-medium (**เปลี่ยนจาก cyan-50/`#0090C4` เดิม** — ดู Visual Refresh ด้านล่าง) ปุ่มอื่น = `gray-500` ไม่มีพื้นหลัง
- **Table** (component มาตรฐานตามหัวข้อ 6.3 ของ design system): คอลัมน์ ประเภท (`Badge variant="outline"` — pill กลวง border `gray-300`, ข้อความ `gray-700`) / หมวดหมู่ (`category` แปลไทย) / รายละเอียด (`detail`, truncate) / สถานะ (แปลไทย) / วันที่ — ทั้งแถวคลิกได้ (`ClickableRow`, hover → `gray-50`)
- Empty state: "ไม่มีรายงานในหมวดนี้" กึ่งกลาง `gray-500`

States: Loaded (ตารางมีแถว) / Empty (ข้อความกึ่งกลาง) — ไม่มี Loading skeleton แยกในรอบนี้เดิม (Server Component fetch ตรง เหมือน WYN-051/052's ผลการค้นหา)

Responsive Behavior: Desktop-first เหมือนทุกหน้า — ตาราง `overflow-x-auto` บนจอแคบ

Accessibility: Status filter ปุ่มมี `aria-current`/state ที่ชัดเจนผ่านสีตัวหนังสือ+พื้นหลัง (ไม่ใช่สีอย่างเดียว — ตัวหนังสือหนาขึ้นด้วยเมื่อ active) — ตารางใช้ `<table>`/`<th>` ความหมายจริง

Design Rules:
- **ไม่มี rich content preview สำหรับ 6 ประเภทที่ไม่ใช่ user/drop** (Non-goal ชัดเจนตาม Product spec — การสร้าง admin-bypass RPC ต่อตารางเป็นงานคนละขนาด ไม่ใช่ส่วนขยายธรรมชาติของ "แสดงคิว")
- ไม่มี pagination (ใช้ query ธรรมดา ไม่ตั้ง limit ชัดเจนในรอบนี้ตามที่ Coding ระบุ — ถ้ารายการเยอะขึ้นมากให้เพิ่มทีหลัง)
- ไม่มี severity/risk-score ใหม่ — "Priority" ของ Master Spec = ลำดับเวลา (FIFO) เท่านั้นในรอบนี้

---

## Screen 2 — Generic Report Detail (`app/(admin)/reports/[id]/page.tsx`, ใหม่)

Purpose: แสดง raw fields ของ Report สำหรับ 6 ประเภทที่ไม่มีหน้ารายละเอียดเฉพาะของตัวเอง (`drop_comment`/`club`/`club_post`/`club_post_comment`/`message`/`redrop`) พร้อม action bar ทั่วไป

User Flow:
1. เข้าจาก Screen 1 (คลิกแถวที่ไม่ใช่ user/drop) → เห็น target type + status badge + category/detail/created_at ดิบ
2. **ถ้า status ยังเปิดอยู่ (`pending`/`reviewing`)**: เห็น action bar 6 action (No Action/Warn/Remove Content*/Restrict/Suspend/Ban — *เฉพาะ `drop_comment`/`club_post`/`club_post_comment`) เรียก `apply_moderation_action()` เดิมตรงๆ
3. **ถ้า status ปิดแล้ว (`actioned`/`dismissed`)**: ไม่มี action bar — ข้อความ "รายงานนี้ถูกดำเนินการไปแล้ว"

Components:
- Header: "รายงาน{ประเภท}" (`page-title` token) + `Badge variant="outline"` สถานะ + "Target ID: {mono}"
- ตารางฟิลด์ดิบ (2 คอลัมน์ label/value): หมวดหมู่, รายละเอียด, วันที่รายงาน
- **`ReportActionsBar`**: ปุ่มเรียงแนวนอน — No Action (`outline`)/Warn (`outline`)/Remove Content (`destructive`, เฉพาะ 3 ประเภทเนื้อหา)/Restrict (`outline`, requireDuration)/Suspend (`outline`, requireDuration)/Ban (`destructive`) — ทุกปุ่มเปิด `ActionDialog` เดิม (reuse จาก WYN-051 ตรงๆ ไม่มีการปรับแก้ component)

States: Loaded (มี action bar หรือไม่มีตามสถานะ), 404 (`notFound()` ถ้า id ไม่มีจริง)

Responsive Behavior: Desktop-first เหมือนทุกหน้า — action bar `flex-wrap` บนจอแคบ

Accessibility: เหมือน `ActionDialog` เดิมทุกจุด (focus-trap, `aria-busy`, `role="alert"`)

Design Rules:
- **Remove Content ปรากฏเฉพาะ 3 ประเภทเนื้อหา** ตรงตาม validation ที่มีอยู่แล้วใน `apply_moderation_action()` (ไม่ตัดสินใจใหม่ — reuse กติกาเดิม)
- ปุ่ม Ban ที่นี่ **ไม่ใช้ typed-confirmation** เหมือน WYN-051's `BanDialog` — เพราะ Ban แบบผ่าน Report ใช้ `ActionDialog` ธรรมดามาตั้งแต่ Flutter app's `ModerationActionSheet` เดิมอยู่แล้ว (typed-confirmation เป็น safeguard ใหม่ที่ WYN-051 เพิ่มเฉพาะ *direct* admin action เท่านั้น ไม่ใช่การตัดสโคปในงานนี้)

---

## Visual Refresh (2026-09-04) — Black & White Premium

**สถานะ**: หน้านี้ไม่เคยมี design doc มาก่อน — เนื้อหาทั้งหมดข้างบนคือ spec ฉบับสมบูรณ์ในภาษาระบบใหม่แล้ว ไม่ต้องอ่านคู่กับเอกสารอื่น

การเปลี่ยนแปลงจาก UI ที่ implement จริงตอนนี้ (ซึ่งยังใช้สี cyan อยู่):
- **Status filter ปุ่มที่ active**: จาก `bg-[#E6F9FF] text-[#0090C4]` (cyan) → `bg-gray-100 text-ink font-medium` ตามหัวข้อ 3.3/6.8 ของ design system (สื่อ active ด้วยน้ำหนัก ไม่ใช่สี)
- **Badge ประเภท (`variant="outline"`)**: คงรูปแบบเดิม (outline, ไม่มีสี) — แต่เปลี่ยนเป็น pill เต็ม (`rounded-full`) ตามหัวข้อ 6.2
- **Badge สถานะ**: คงรูปแบบเดิม (`variant="outline"`, ไม่ใช่สี) — เพราะสถานะ Report ทั้ง 4 (pending/reviewing/actioned/dismissed) ไม่มีสถานะไหน "อันตราย" ในตัวมันเอง เป็นแค่ metadata ของ workflow ไม่ใช่ critical alert ตรงตามกติกาข้อ 3.3 ของ design system (สิ่งเดียวที่ต้องรีบดูคือ "ยังไม่ actioned" ซึ่งสื่อผ่านการเป็น default filter อยู่แล้ว ไม่ต้องเพิ่มสีซ้ำ)
- **ปุ่ม Remove Content/Ban ใน `ReportActionsBar`**: ยัง `variant="destructive"` เหมือนเดิมทุกประการ (destructive action ที่แท้จริง)
- **Table**: hairline `gray-100` ระหว่างแถว, header `gray-50`, hover `gray-50` (คงเหมือนทุกหน้า)

Handoff: AI Coding — `components/admin/report-actions-bar.tsx` ไม่ต้องแก้ (reuse `ActionDialog` ที่แก้สีที่ต้นทางแล้วพอ) — ไฟล์ที่ต้องแก้จริง: `app/(admin)/reports/status-filter.tsx` (เปลี่ยน hardcode hex), `app/(admin)/reports/results.tsx`/`app/(admin)/reports/[id]/page.tsx` (badge pill shape ผ่าน `components/ui/badge.tsx` ที่แก้กลางจุดเดียวพอ ไม่ต้องแก้ไฟล์นี้เพิ่ม)
