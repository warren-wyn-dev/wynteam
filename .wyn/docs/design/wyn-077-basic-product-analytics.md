# Design Spec — WYN-077 (Basic Product Analytics)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/active/WYN-077-basic-product-analytics.md`
อ้างอิง GTM context: `.wyn/docs/product/wynos-gtm-roadmap.md`
อ้างอิง Design system: `.wyn/docs/design/wyn-049-admin-foundation.md` (shadcn neutral base + WYN Cyan accent) และ `.wyn/docs/design/wyn-050-admin-dashboard.md` (stat card pattern เดิม) — **ไม่คิดทิศทาง visual ใหม่ ต่อยอด pattern เดิมของ WYN-050 ทั้งหมด** ไม่มี component ใหม่นอกจาก 1 ตัว (ดูด้านล่าง)

## บริบท

ฟีเจอร์นี้**ไม่มีหน้าจอฝั่งผู้ใช้ Gen Z เลย** — เป็น instrumentation ล้วนๆ (event ที่เก็บแบบเงียบๆ ตอน user ใช้แอปปกติ ไม่มี UI ให้เห็น ไม่มี consent prompt เพิ่มเพราะเป็น first-party analytics เก็บเอง ไม่ส่งออกนอกระบบ) หน้าจอเดียวที่มีการเปลี่ยนแปลงจริงคือ **WYN Admin Dashboard** (`admin/`, WYN-050) ที่ต้องเพิ่ม section ใหม่ให้ Founder เห็นผล GTM ได้

## Screen — Dashboard (`app/(admin)/page.tsx`) — เพิ่ม Section ใหม่ "การเติบโต"

Purpose: ให้ Founder เห็นสัญญาณว่า Go-To-Market ได้ผลไหม (สมัครกี่คน, สมัครสำเร็จกี่ %, ใช้งานต่อกี่วัน, มาจากช่องทางไหน) โดยไม่ต้องเปิด SQL editor — ต่อยอด dashboard เดิมของ WYN-050 ไม่สร้างหน้าใหม่

User Flow:
1. Admin/Moderator เปิด `/` (Dashboard) ตามเดิม (ไม่เปลี่ยนจาก WYN-050)
2. เห็น 4 section เดิม (ผู้ใช้งาน/เนื้อหา/การมีส่วนร่วม/รายงาน) **บวก section ใหม่ "การเติบโต" ต่อท้ายลำดับสุดท้าย** (ไม่แทรกกลาง กันสับสน mental model เดิมของ Admin ที่คุ้นเคยแล้ว)
3. ปุ่ม "รีเฟรช" เดิมที่มีอยู่แล้วดึงข้อมูล section ใหม่พร้อมกันในคำเรียก RPC เดียวกัน (ไม่เพิ่มปุ่มรีเฟรชที่สอง)

Components:

**Section "การเติบโต"** — 5 stat card ใหม่ (reuse `StatCard` component เดิมจาก WYN-050 ทั้งหมด ไม่สร้าง component ใหม่สำหรับส่วนนี้) + 1 การ์ดพิเศษสำหรับ Top Sources (component ใหม่ 1 ตัว):

| Card | ตัวเลขหลัก | ตัวเลขรอง | Icon |
|---|---|---|---|
| สมัครใหม่ | Signup started (24h) | — | `UserPlus` |
| สมัครสำเร็จ | Signup completed (24h) | Conversion % (completed/started) | `CheckCircle2` |
| Activation | % ที่ทำ core action แรกภายใน 24 ชม.หลังสมัคร | จำนวนคน (ตัวเลขดิบ) | `Zap` |
| D1 Retention | % กลับมาใช้วันที่ 1 | — | `RotateCcw` |
| D7 Retention | % กลับมาใช้วันที่ 7 | — | `RotateCcw` |

รูปแบบการ์ด "สมัครสำเร็จ"/"Activation" ใช้ layout ตัวเลขหลัก+รอง เดียวกับการ์ด Clubs/Reports ของ WYN-050 เป๊ะ (ไม่คิด layout ใหม่)

**Top Sources card** (component ใหม่ `components/admin/top-sources-card.tsx`, reuse `Card`/`CardHeader`/`CardContent` เดิม ไม่ใช่ stat card ตัวเลขเดี่ยว):
- Header: "ช่องทางยอดนิยม (7 วันล่าสุด)"
- Content: list สูงสุด 5 แถว เรียงจากจำนวน signup มากไปน้อย แต่ละแถว = ชื่อ source (จาก UTM parameter, ถ้าไม่มี UTM แสดงเป็น "ไม่ระบุที่มา") + จำนวน signup ชิดขวา (`tabular-nums`) — ใช้ `<ul>`/`<li>` ธรรมดา + `flex justify-between` ต่อแถว ไม่ต้องสร้าง Table component ใหม่ทั้งระบบสำหรับ list 5 แถว
- การ์ดนี้กว้างเต็ม 2 คอลัมน์บน desktop (`lg:col-span-2`) ส่วนการ์ดตัวเลขเดี่ยว 5 ใบข้างบนใช้ความกว้างปกติเหมือนการ์ดอื่นในหน้า

**Grid**: การ์ดตัวเลขเดี่ยว 5 ใบใช้ grid เดิม `grid-cols-1 md:grid-cols-2 lg:grid-cols-4` ต่อจาก section "รายงาน" — Top Sources card อยู่แถวถัดไปเต็มความกว้างที่เหลือ (`lg:col-span-2`, จัดกึ่งกลางถ้าเหลือพื้นที่ว่างข้างเดียว)

**Disclaimer ใต้ heading "การเติบโต"** (มิเรอร์ pattern DAU/WAU/MAU ของ WYN-050 — ต้องแสดงตลอดไม่ใช่ tooltip ซ่อน): `<p className="text-xs text-muted-foreground mt-1">` ข้อความ: "Retention นับจากผู้ใช้ที่กลับมามีกิจกรรมบนแพลตฟอร์ม ไม่ใช่แค่เปิดเว็บทิ้งไว้ · ช่องทางนับจากลิงก์ที่มี UTM parameter เท่านั้น ผู้ใช้ที่พิมพ์ URL เข้าเองจะขึ้นเป็น \"ไม่ระบุที่มา\""

Interactions: ไม่มี interaction ใหม่ — การ์ดทั้งหมดไม่ clickable (มิเรอร์กฎเดิมของ WYN-050 ข้อ "ไม่ clickable ไม่ link ไปหน้าอื่นในรอบนี้")

States (มิเรอร์ WYN-050 ทุกจุด ไม่คิดใหม่):
- **Loading (ครั้งแรก)**: skeleton การ์ดตำแหน่งเดียวกับ layout จริง (รวม section ใหม่ในการโหลดครั้งเดียวกันกับ 4 section เดิม ไม่มี loading แยก)
- **Loaded**: ตัวเลขจริงทั้ง 5 การ์ด + Top Sources list
- **Refreshing**: ตัวเลขเดิมค้างไว้ ปุ่มรีเฟรช disabled+spin เหมือนเดิม
- **Error**: รวมอยู่ใน error state เดียวกันของทั้งหน้า (RPC เดียวกัน ไม่มี error state แยกเฉพาะ section ใหม่)
- **Top Sources ว่าง** (ยังไม่มี signup ที่มี UTM เลย เช่นช่วง Phase 1 closed beta ที่ยังไม่ทำ paid channel): แสดงข้อความ "ยังไม่มีข้อมูลช่องทาง" กลางการ์ดแทน list ว่าง — **ไม่ใช่ error** เป็น empty state ปกติที่คาดไว้ตั้งแต่ Phase 1-2

Responsive Behavior: เหมือน WYN-050 ทุกประการ (desktop-first, breakpoint มาตรฐาน Tailwind) — Top Sources card ที่ปกติกว้าง 2 คอลัมน์บน desktop ยุบเหลือ 1 คอลัมน์เต็มความกว้างบนมือถือ/แท็บเล็ต (`col-span-1` ที่ breakpoint ต่ำกว่า `lg`)

Accessibility: stat card ใหม่ทั้ง 5 ใบใช้ `aria-label` pattern เดียวกับ WYN-050 (เช่น `aria-label="สมัครสำเร็จ 24 ชั่วโมงล่าสุด: 12 คน อัตราการสมัครสำเร็จ 80 เปอร์เซ็นต์"` รวมตัวเลขหลัก+รองในประโยคเดียว) — Top Sources list ใช้ `<ul>` จริง (ไม่ใช่ `<div>` ซ้อน) ให้ screen reader อ่านเป็นรายการได้ถูกต้อง แต่ละ `<li>` มี text ชื่อ source + จำนวนต่อเนื่องกัน (ไม่ต้องใส่ `aria-label` แยกเพราะ text content ที่เห็นอ่านแล้วเข้าใจตรงอยู่แล้ว)

Design Rules:
- **ไม่มี graph/chart** — ต่อยอดกฎเดิมของ WYN-050 ตรงๆ (Top Sources เป็น list ตัวเลข ไม่ใช่ bar chart)
- **Section ใหม่ต่อท้ายเสมอ ไม่แทรกกลาง** ระหว่าง section เดิม 4 อัน
- ใช้ WYN Cyan (`--primary`) กับ icon เท่านั้น เหมือน WYN-050 — ไม่มีเกณฑ์สีแดง/เตือนสำหรับ section นี้ (ต่างจาก Reports card เพราะตัวเลข growth ไม่มี "เกณฑ์อันตราย" ที่ชัดเจนแบบ pending report)
- Top Sources card เป็น `Card` ธรรมดา ไม่ใช่ `StatCard` (component คนละแบบ อย่าพยายามยัด list เข้า `StatCard` เดิม)

Handoff: AI Coding
- ต่อยอด RPC `admin_dashboard_metrics()` เดิมของ WYN-050 ให้คืนข้อมูล section ใหม่มาด้วยในคำเรียกเดียวกัน (1 round-trip เดิม ไม่เพิ่ม RPC ที่สอง) — โครงสร้าง object ใหม่ต้องมี: `signup_started_24h`, `signup_completed_24h`, `signup_conversion_pct`, `activation_pct_24h`, `activation_count_24h`, `retention_d1_pct`, `retention_d7_pct`, `top_sources` (array สูงสุด 5 รายการ `{source: string, count: number}` เรียงมากไปน้อย, `source` เป็น `"ไม่ระบุที่มา"` เมื่อไม่มี UTM)
- Event table ใหม่ที่ Product spec ระบุ (`signup_started`/`signup_completed`/`first_core_action`/`session_start`) เป็นการตัดสินใจ schema ของ AI Coding เอง (Design ไม่ล็อกโครงสร้างตาราง) แต่ **ต้องคำนวณ metric ข้างบนจากข้อมูลจริงได้ตรงตามนิยาม**: Activation = สัดส่วนผู้ใช้ที่ signup วันนั้นแล้วมี `first_core_action` ภายใน 24 ชม.; D1/D7 Retention = สัดส่วนผู้ใช้ที่ signup แล้วมี `session_start` เพิ่มในวันที่ 1/7 หลังจากนั้น
- RLS ของ event table: insert-only จาก client ตัวเอง (`auth.uid() = user_id` หรือเทียบเท่า), ไม่มี select policy ให้ client เลย — อ่าน aggregate ได้เฉพาะผ่าน RPC role admin เท่านั้น (ตาม Acceptance Criteria ที่ Product ระบุไว้แล้ว)
- component ใหม่ที่ต้องสร้างจริง: `components/admin/top-sources-card.tsx` เท่านั้น — ส่วนการ์ดตัวเลข 5 ใบใช้ `StatCard` เดิมของ WYN-050 ตรงๆ ไม่ต้องแก้ `stat-card.tsx`
