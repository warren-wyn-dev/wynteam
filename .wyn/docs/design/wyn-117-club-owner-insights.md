# Design — WYN-117 (Club Owner Insights)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-117-club-owner-insights.md` — อ่านก่อนเริ่ม
> **สถานะ**: Design เสร็จแล้ว — ไม่มี dependency กับ WYN-115/116/123/124/125/126 (Product spec ระบุไว้ตรงๆ ว่าทำคู่ขนานได้) แต่ตามลำดับ roadmap ที่ Founder วางไว้ยังอยู่หลัง WYN-115/116 (เสร็จแล้ว) — Coding ทำได้เมื่อถึงคิวปกติ ไม่ต้องรอ WYN-123/124/125/126
> Design system: token เดิม (Sapphire, light-only, system font) ตามที่ยืนยันไว้ใน `wyn-123-club-channels.md`

Product spec ชี้ไปที่ pattern ของ Admin Dashboard (`admin/components/admin/dashboard-metrics.tsx`/`stat-card.tsx`) เป็นต้นแบบ — **หยิบมาแค่แนวคิด** (ตัวเลขเปล่าๆ ไม่มีกราฟ, ไอคอนเป็นแค่ของตกแต่งไม่ใช่สัญญาณ, delta แสดงด้วยเครื่องหมาย/น้ำหนักตัวอักษรไม่ใช่สีเขียว-แดง) **ไม่ใช่ตัว component จริง** เพราะ Admin เป็นคนละ stack (Next.js/shadcn/Zinc palette) กับแอป WYN Social (Flutter/WYNOS token) — แปลงเป็น Flutter widget ใหม่ที่ใช้ token เดิมของ Club (`WynColors`/`WynSpacing`/`WynTypography`) ทั้งหมด

---

## Screen 1 — ทางเข้า: แถวใหม่ใน "..." เมนูของ ClubPage

**Purpose**: ให้ Owner/Admin เข้าถึงหน้าสถิติได้ โดยไม่ทำให้ TabBar (ที่จะมี 4 tab แล้วหลัง WYN-124: โพสต์/สมาชิก/เกี่ยวกับ/แชท) แน่นขึ้นไปอีก

**การตัดสินใจ**: **ไม่ทำเป็น tab ใหม่** — Insights เป็นฟีเจอร์ staff-only 100% (Moderator ทั่วไปก็เข้าไม่ได้ ตาม Product spec) ต่างจาก 4 tab ที่มีอยู่/กำลังจะมีซึ่งทุกสมาชิกเข้าถึงได้หมด จึงเข้ากับรูปแบบ "แถวในเมนู '...' ที่ role-gated" ที่ `ClubPage._openMoreMenu` มีอยู่แล้วพอดี (แก้ไขข้อมูล Club/เปลี่ยนความเป็นส่วนตัว/จัดการสิทธิ์สมาชิก ล้วน gate ด้วย `role.canManageClub` เหมือนกัน) — เพิ่มแถวใหม่ **"Insights"** ในกลุ่มเดียวกันนั้นเลย

**User Flow**: เมนู "..." → (เห็นเฉพาะ Owner/Admin) แตะ "Insights" → เปิดหน้าสถิติใหม่

**Components**: `ActionSheetRow` ไอคอน `Icons.bar_chart_outlined` label "Insights" — วางต่อจาก "จัดการสิทธิ์สมาชิก" แถวสุดท้ายในกลุ่ม staff-only เดิม

**Design Rules**: ไม่มี component ใหม่ — แถวเดียวกับที่มีอยู่แล้ว

---

## Screen 2 — หน้า Club Insights

**Purpose**: สรุปตัวเลขการเติบโต/engagement ของ Club ในช่วง 7 หรือ 30 วัน

**User Flow**: เปิดจาก Screen 1 → ค่าเริ่มต้นแสดงช่วง "7 วัน" → แตะสลับเป็น "30 วัน" ได้ → เห็นตัวเลข 4 กลุ่มอัปเดตตามช่วงที่เลือกทันที

**Components**:
- Header แบบ `AppBar` ปกติ (back chevron + title "Insights" ตาม `WynTypography.screenTitle(fontSize: 18)`) — มิเรอร์ shell เดียวกับ `ManageChannelsScreen` (WYN-123)
- **ตัวเลือกช่วงเวลา**: `SegmentedButton<int>` 2 ตัวเลือก "7 วัน" / "30 วัน" ค่าเริ่มต้น "7 วัน" — **reuse widget เดียวกับที่ WYN-115's Poll Composer ใช้เลือกระยะเวลาโพล** (`SegmentedButton<int>` 3 ปุ่ม) แค่ลดเหลือ 2 ตัวเลือก ไม่ใช่ widget ใหม่
- **Stat tile** (widget ใหม่ 1 ตัว `_InsightTile` — จำเป็นเพราะไม่มี stat-card แบบนี้ในแอป Flutter มาก่อน แต่โครงยืมจากแนวคิดของ Admin's `StatCard` เป๊ะ): การ์ดสี่เหลี่ยมมุมโค้ง `radiusMd`, ขอบ `hairline` (ไม่มีเงา — ตรงกับกติกา "การ์ดไร้เงา" ของ Club UI เดิม), ภายในมี:
  - แถวบน: label เล็ก (`labelSmall`/`graphite`) ซ้าย + ไอคอนประดับ (`graphite`, **ไม่ใช่สัญญาณ** ตามกติกาเดียวกับ Admin's icon ที่เป็นแค่ zinc-400 ตกแต่ง) ขวา
  - ตัวเลขใหญ่กลางการ์ด: `headlineMedium` (32px/700) สี `ink`, ใช้ `FontFeature.tabularFigures()` ให้ตัวเลขเรียงคอลัมน์สวย (Flutter เทียบเท่า `tabular-nums` ของ Admin)
  - แถวล่าง: sublabel เล็ก (`labelSmall`/`graphite`) เช่น "ใน 7 วันล่าสุด"
- Grid 2 คอลัมน์ (`GridView` หรือ `Wrap` กว้างเท่ากัน), เว้นระยะ `space3` ระหว่างการ์ด, padding รอบนอก `space4`
- **4 การ์ด** ตาม Requirements ของ Product: "สมาชิกใหม่" (ไอคอน `person_add_outlined`), "โพสต์ใหม่" (ไอคอน `article_outlined`), "ถูกใจ+คอมเมนต์รวม" (ไอคอน `favorite_outline`), "สมาชิก Active" (ไอคอน `bolt_outlined`, sublabel เพิ่ม "โพสต์/ไลค์/คอมเมนต์อย่างน้อย 1 ครั้ง")

**Interactions**: สลับ `SegmentedButton` → เรียก query ใหม่ตามช่วงที่เลือก, ระหว่างโหลดตัวเลขเก่ายังค้างอยู่ (ไม่กระพริบเป็นค่าว่าง) จนกว่าค่าใหม่มาแทนที่ (มิเรอร์ pattern loading แบบเงียบที่ `_toggleMute`/`_togglePin` ใช้ ไม่ใช่ full-screen spinner ทุกครั้งที่สลับ)

**States**: Club ใหม่ไม่มีข้อมูลเลย → ทุกการ์ดแสดง **"0" อย่างถูกต้อง** ไม่ error/crash (ตรงตาม AC ข้อ 3 ของ Product) — loading ครั้งแรก (ยังไม่เคยโหลดเลย) ใช้ `CircularProgressIndicator` กลางจอแบบเดียวกับหน้าอื่นๆ ในระบบ, error ใช้ปุ่ม "ลองใหม่" แบบเดิม

**Responsive Behavior**: grid 2 คอลัมน์คงที่ (จอมือถือที่แอปรองรับไม่กว้างพอจะทำ 3-4 คอลัมน์อย่างมีความหมาย)

**Accessibility**: `Semantics` ต่อการ์ดรวม label+ตัวเลข+sublabel เป็นประโยคเดียว (เช่น "สมาชิกใหม่ 12 คน ใน 7 วันล่าสุด") ไม่ใช่อ่านแยกเป็น 3 ท่อน

**Design Rules**: ไม่มีกราฟ/export ตามที่ Product กำหนดชัดเจน ("ไม่ต้องมี export/กราฟซับซ้อนใน V1") — สีตัวเลขเป็น `ink` เสมอ ไม่ใช้สีเขียว/แดงแทน "ดีขึ้น/แย่ลง" (มิเรอร์กติกาเดียวกับ Admin Dashboard's TrendBadge ที่จงใจไม่ใช้สีบอกทิศทาง)

## Handoff

ส่งต่อ **AI Coding** — เขียน RPC aggregate ใหม่ (นับที่ DB level ตามที่ Product's Risks เตือนไว้ ไม่ดึงข้อมูลดิบมาคำนวณฝั่ง client) มิเรอร์ pattern เดิมของ Admin Dashboard's RPC (`fetchAdminDashboardMetrics` เป็นต้น) แต่ scope เฉพาะ Club เดียวและ filter ด้วย `club_role()` ให้เฉพาะ Owner/Admin เรียกได้จริงที่ RLS ไม่ใช่แค่ซ่อน UI — ไม่มี dependency ต้องรอ ทำได้เมื่อถึงคิว

หลัง Coding เสร็จ → ส่งต่อ **AI QA & Security**
