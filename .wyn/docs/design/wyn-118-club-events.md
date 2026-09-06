# Design — WYN-118 (Club Events)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-118-club-events.md` — อ่านก่อนเริ่ม
> **สถานะ**: Design เสร็จแล้ว — Product spec ระบุให้ทำหลัง WYN-116 (เสร็จแล้ว) เพื่อ reuse infra แจ้งเตือน — ไม่มี dependency กับ WYN-123/124/125/126 ทำได้เมื่อถึงคิวปกติตาม roadmap (หลัง WYN-117)
> Design system: token เดิม (Sapphire, light-only, system font) ตามที่ยืนยันไว้ใน `wyn-123-club-channels.md`

Product spec เปิดให้ Design ตัดสินใจตำแหน่งเอง ("การ์ดด้านบน Posts tab หรือแท็บใหม่ Events — ให้ Design ตัดสินใจตำแหน่งที่ไม่ทำให้ Club Page แน่นเกินไป") — **ตัดสินใจ: ไม่ทำ tab ใหม่** ด้วยเหตุผลเดียวกับ WYN-117: TabBar จะมี 4 tab แล้วหลัง WYN-124 (โพสต์/สมาชิก/เกี่ยวกับ/แชท) เพิ่มอีก tab จะเทอะทะเกินไปตามที่ Product เตือนไว้ตรงๆ — ใช้ **การ์ดสรุปกิจกรรมถัดไป** ที่หัว Posts tab แทน (คล้ายกับที่ WYN-123's Channel switcher วางไว้ใต้ TabBar เหนือลิสต์โพสต์ — Events การ์ดอยู่ตำแหน่งเดียวกัน วางเหนือ Channel switcher อีกที ถ้ามีทั้งคู่)

---

## Screen 1 — การ์ดกิจกรรมถัดไป (บน Posts tab)

**Purpose**: บอกว่ามีกิจกรรมที่จะถึงเร็วๆ นี้ โดยไม่ต้องเปิดหน้าแยกก่อน

**User Flow**: เปิด Club → tab โพสต์ → ถ้ามีกิจกรรมที่ยังไม่ผ่านไป เห็นการ์ดแคบๆ 1 ใบเหนือลิสต์โพสต์ (ใต้ Channel switcher ของ WYN-123 ถ้า Club นั้นมีหลาย Channel) แสดงกิจกรรม**ที่ใกล้ที่สุดเพียงใบเดียว** → แตะการ์ด → เปิดหน้ารายการกิจกรรมเต็ม (Screen 2)

**Components**: การ์ดแนวนอน ขอบ `hairline`, พื้น `surfaceTint` (สีเดียวกับพื้นผิวเรียบอื่นๆ ของระบบ เช่น incoming chat bubble) — ไอคอน `Icons.event_outlined` สี `sapphire` ซ้ายสุด, กลางการ์ดมีชื่อกิจกรรม (`titleSmall`) + วันเวลาแบบย่อ ("เสาร์นี้ 18:00 น.") ใต้ชื่อ (`labelSmall`/`graphite`), ขวาสุดมี chevron บอกว่าแตะได้

**Interactions**: แตะการ์ด = เปิด Screen 2 ตรงไปที่แท็บ "กำลังจะถึง" — ไม่มี RSVP shortcut ที่การ์ดนี้ (ต้องเข้าไปดูรายละเอียดก่อนเสมอ กันการกด RSVP พลาดโดยไม่ได้อ่านรายละเอียด)

**States**: ไม่มีกิจกรรมที่จะถึงเลย → **ไม่ render การ์ดนี้เลย** (ไม่ใช่ซ่อนแบบเผื่อพื้นที่) — Club ที่ไม่เคยใช้ Events เลยหน้าตาเหมือนก่อนมี WYN-118 ทุกประการ ตรงกับหลัก "ไม่ทำให้ Club Page แน่นเกินไป" ที่ Product ระบุตรงๆ, มีมากกว่า 1 กิจกรรมพร้อมกัน → แสดงแค่ **ใบที่ใกล้ที่สุด** ใบเดียวเสมอ (ใบอื่นดูได้ใน Screen 2)

**Design Rules**: reuse โทนสี/พื้นผิวเดิม ไม่มีสีใหม่ — ระยะห่างจาก TabBar/Channel switcher/ลิสต์โพสต์ตาม `space3`/`space4` มาตรฐาน

---

## Screen 2 — รายการกิจกรรม (กำลังจะถึง / ผ่านไปแล้ว)

**Purpose**: ดูกิจกรรมทั้งหมดของ Club แยกอนาคต/อดีตชัดเจน

**User Flow**: เปิดจาก Screen 1 หรือจาก Screen 1's การ์ด → เห็น tab คู่ "กำลังจะถึง" / "ผ่านไปแล้ว" → เลื่อนดูรายการ → แตะกิจกรรมใดเปิด Screen 4 (รายละเอียด+RSVP) → (staff เท่านั้น) ปุ่ม "+ สร้างกิจกรรม" เปิด Screen 3

**Components**:
- Header `AppBar` (back + title "กิจกรรม") — มิเรอร์ shell เดิม
- **Tab คู่**: "กำลังจะถึง" / "ผ่านไปแล้ว" — **reuse widget/pattern เดียวกับ "ทั้งหมด"/"ยังไม่อ่าน" ของ `ChatInboxScreen`** (client-side filter เหนือลิสต์เดียวที่โหลดมาแล้ว ไม่ใช่ query แยก 2 รอบ) ค่าเริ่มต้นเปิดที่ "กำลังจะถึง" เสมอ (เรียงจากใกล้สุดไปไกลสุด) ส่วน "ผ่านไปแล้ว" เรียงจากล่าสุดไปเก่าสุด
- รายการแต่ละแถว: ชื่อกิจกรรม (`titleSmall`), วันเวลาเต็ม + ไอคอนสถานที่ (`Icons.link` ถ้าออนไลน์ / `Icons.place_outlined` ถ้าออฟไลน์) ใต้ชื่อ, ป้ายเล็กมุมขวาแสดงจำนวนคนตอบ "ไป" (เช่น "12 คนจะไป") — มิเรอร์รูปแบบแถวของ `ClubMembersTab`
- FAB "+ สร้างกิจกรรม" — **เห็นเฉพาะ Owner/Admin/Moderator** (`canModeratePosts`, สิทธิ์ระดับเดียวกับ Pin ตาม Product's Acceptance Criteria ข้อ 1) มิเรอร์ FAB เดิมของ `ClubPostsTab` (สี sapphire, ไอคอน +)

**States**: ไม่มีกิจกรรมในแท็บที่เปิดอยู่ → ใช้ `EmptyStateBlock` (ไอคอน `event_outlined` ในวงกลม tint, หัวข้อ "ยังไม่มีกิจกรรมที่จะถึง" หรือ "ยังไม่มีกิจกรรมที่ผ่านมา" ตามแท็บ)

**Accessibility**: แต่ละแถวมี `Semantics` รวมชื่อ+วันเวลา+จำนวนคนไป เป็นประโยคเดียว

**Design Rules**: ไม่มี component ใหม่ — tab pair/FAB/empty-state ล้วน reuse ของเดิม

---

## Screen 3 — สร้าง/แก้ไข Event (Owner/Admin/Moderator)

**Purpose**: กำหนดชื่อ, รายละเอียด, วันเวลา, สถานที่ของกิจกรรม

**User Flow**: เปิดจาก FAB (Screen 2) → กรอกฟอร์ม → กด "สร้างกิจกรรม" → pop กลับไป Screen 2 พร้อมกิจกรรมใหม่ในลิสต์

**Components** (มิเรอร์ shell ของ `EditClubInfoScreen`/`CreateClubPostScreen`):
- Text field "ชื่อกิจกรรม" (บังคับ)
- Text field "รายละเอียด" (ไม่บังคับ, multi-line)
- **วันเวลา**: แถวเดียวมี 2 ปุ่ม "เลือกวันที่"/"เลือกเวลา" — ใช้ `showDatePicker`/`showTimePicker` ของ Flutter (Material มาตรฐาน) ตรงๆ ไม่สร้าง calendar widget เอง — ปุ่มทั้งสองรับสีจาก `Theme.of(context).colorScheme` อัตโนมัติอยู่แล้ว (sapphire) เพราะเป็น dialog มาตรฐานของระบบ
- **สถานที่**: `SegmentedButton<EventLocationType>` 2 ตัวเลือก "ออนไลน์" / "ออฟไลน์" (**reuse widget เดียวกับที่ WYN-115/WYN-117 ใช้แล้ว** ไม่ใช่ของใหม่) — เลือก "ออนไลน์" โชว์ text field "ลิงก์" (validate เป็น URL คร่าวๆ), เลือก "ออฟไลน์" โชว์ text field "สถานที่" (ข้อความอิสระ ไม่มี map picker ตามที่ Product ระบุ "ไม่ต้องมี map integration ใน V1")

**Interactions**: ปุ่ม "สร้างกิจกรรม" กดได้เมื่อชื่อ+วันที่+เวลา+สถานที่ (ลิงก์หรือที่อยู่ตามโหมด) ไม่ว่าง — error inline สีแดงใต้ฟอร์ม (มิเรอร์ convention เดิมของฟอร์มกลุ่มนี้)

**States**: โหมดแก้ไข (แก้กิจกรรมที่สร้างไปแล้ว) เหมือนโหมดสร้างทุกอย่าง แค่ปุ่มเปลี่ยนเป็น "บันทึก" และมีปุ่ม "ลบกิจกรรม" เพิ่ม (สีแดง, มี `AlertDialog` ยืนยันก่อนเสมอ — มิเรอร์ pattern เดียวกับ "ลบ Channel" ของ WYN-123)

**Design Rules**: ไม่มี component ใหม่ทั้งฟอร์ม — ทุกส่วนยืมจาก pattern ที่มีอยู่แล้ว

---

## Screen 4 — รายละเอียด Event + RSVP

**Purpose**: ดูรายละเอียดเต็มของกิจกรรมและตอบรับเข้าร่วม

**User Flow**: เปิดจาก Screen 2 → เห็นรายละเอียดเต็ม + 3 ปุ่ม RSVP → แตะปุ่มใดปุ่มหนึ่ง → คำตอบบันทึกทันที (optimistic) → เห็นจำนวน+รายชื่อคนตอบแต่ละสถานะ

**Components**:
- ส่วนหัว: ชื่อกิจกรรม (`headlineSmall`), วันเวลาเต็ม + สถานที่ (ลิงก์ที่แตะเปิดได้ถ้าออนไลน์ / ข้อความที่อยู่ถ้าออฟไลน์), รายละเอียด (`bodyLarge`)
- **แถว RSVP**: `SegmentedButton<RsvpStatus>` 3 ตัวเลือก "ไป" / "อาจจะไป" / "ไม่ไป" — **reuse widget เดียวกันอีกครั้ง** (ตัวที่ 3 ในเอกสารนี้ที่ยืม `SegmentedButton` เดิมมาใช้ซ้ำ — ยิ่งตอกย้ำว่าไม่มีการคิด component ใหม่) ค่าเริ่มต้น = ยังไม่ได้เลือก (ไม่ highlight ปุ่มใดจนกว่าจะตอบ)
- **สรุปผู้ตอบรับ**: 3 ส่วน "ไป (N)" / "อาจจะไป (N)" / "ไม่ไป (N)" แต่ละส่วนแตะขยายดูรายชื่อได้ (รายการ avatar+ชื่อ มิเรอร์แถวของ `ClubMembersTab` เป๊ะ)
- (staff เท่านั้น) เมนู "..." มีแถว "แก้ไขกิจกรรม"/"ลบกิจกรรม" เปิด Screen 3

**Interactions**: แตะ RSVP = บันทึกทันที เปลี่ยนได้ตลอด (กดใหม่ทับของเดิม ไม่ใช่ toggle ปิด — สถานะ RSVP มี 3 ทาง ไม่ใช่ binary ปิด/เปิดเหมือน Like) — optimistic update, revert เงียบเมื่อ error เหมือน pattern ทั้งระบบ

**States**: กิจกรรมผ่านไปแล้ว → ปุ่ม RSVP เปลี่ยนเป็น disabled/ซ่อน (ตอบรับกิจกรรมที่ผ่านไปแล้วไม่มีความหมาย) แต่ยังดูสรุปผู้ตอบรับเดิมได้ (ข้อมูลประวัติ)

**Accessibility**: `SegmentedButton` มี built-in semantics ของ Flutter อยู่แล้ว, ส่วนสรุปผู้ตอบรับมี `Semantics` ระบุจำนวนก่อนรายชื่อ

**Design Rules**: ไม่มี component ใหม่

---

## หมายเหตุถึง Coding (ต่อยอด WYN-116)

แจ้งเตือน "reminder ก่อนกิจกรรมเริ่ม" (Requirements ข้อ 4 ของ Product) ให้ fan-out เฉพาะสมาชิกที่ RSVP ไว้แล้ว (ไป/อาจจะไป — ไม่ใช่ทุกสมาชิก Club) ผ่าน trigger/notification type ใหม่ที่ต่อยอด infra ของ WYN-116 (`internal.notification_enabled()`, `notification_settings.club` category เดิม) ไม่ต้องสร้างระบบแจ้งเตือนแยก — ระยะเวลา "ก่อนเริ่ม" เท่าไหร่ (เช่น 1 ชม./1 วันก่อน) ไม่ได้ระบุใน Product spec ให้ Coding เสนอค่าเริ่มต้นที่สมเหตุสมผล (เอกสารไว้เหมือนที่ WYN-116 เคยทำกับ throttle window) แล้วยืนยันกับ Product/Founder ก่อน ship

## Handoff

ส่งต่อ **AI Coding** — ตาราง Event/RSVP ใหม่ + RLS ตาม trust model เดิมของ Club (approved member เห็น/RSVP ได้, สิทธิ์สร้าง/แก้/ลบ = `canModeratePosts` เดียวกับ Pin) ไม่มี dependency ต้องรอ ทำได้เมื่อถึงคิวปกติ (หลัง WYN-117 ตามลำดับ roadmap)

หลัง Coding เสร็จ → ส่งต่อ **AI QA & Security**
