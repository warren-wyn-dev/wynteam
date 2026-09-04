# Design Spec — WYN-051 (WYN Admin User Management)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-051-admin-user-management.md`
อ้างอิง Design system: `.wyn/docs/design/wyn-049-admin-foundation.md` (shadcn neutral + WYN Cyan accent, ไม่คิดใหม่) — เพิ่ม component ใหม่ 4 ตัวที่ยังไม่มีใน `components/ui/` (`Dialog`/`Textarea`/`Select`/`Badge`) เขียนเองตาม shadcn source มาตรฐานเหมือน WYN-049 (`ui.shadcn.com` ยังบล็อกอยู่)

## Screen 1 — User Management (`app/(admin)/users/page.tsx`, แทนที่ placeholder เดิม)

Purpose: ค้นหาผู้ใช้เพื่อเข้าดูรายละเอียด/ดำเนินการ

User Flow:
1. เปิดหน้า → เห็นช่องค้นหา + คำแนะนำ "พิมพ์ username เพื่อค้นหา" (ยังไม่แสดงรายชื่อทั้งหมดตั้งแต่แรก — ป้องกันการโหลดผู้ใช้ทั้งระบบมาแสดงลอยๆ โดยไม่มี query)
2. พิมพ์แล้วกด Enter/ปุ่มค้นหา → แสดงรายการผลลัพธ์ (username, display name, platform_role badge, สถานะบัญชีปัจจุบันแบบย่อ)
3. คลิกแถวไหนก็ได้ → ไปหน้า `app/(admin)/users/[id]/page.tsx`

Components:
- `Input` (search, `placeholder="ค้นหาด้วย username"`) + `Button` ("ค้นหา") ในแถวเดียวกัน
- ผลลัพธ์: list ของแถว (ไม่ใช่ `Card` แยกทีละใบ — ใช้ `<Table>` แบบเรียบง่าย เพราะเทียบเป็นข้อมูลตารางล้วนๆ ไม่มี visual hierarchy ซับซ้อนแบบ stat card) แต่ละแถว: username + display_name, `Badge` role (`admin`=ม่วง, `moderator`=น้ำเงิน, `user`=เทา — สีที่ยืมจาก shadcn's ระบบ badge variant มาตรฐาน ไม่ใช่สีใหม่), `Badge` สถานะ (ปกติไม่แสดง badge เลยถ้าไม่มีอะไรผิดปกติ — "Restricted"/"Suspended"/"Banned" แสดงเป็นสีแดงเมื่อมีสถานะ active เท่านั้น มิเรอร์หลักการเดียวกับ WYN-050's Reports pending "ไม่ใช้สีแดงตายตัวเสมอ")

States:
- Idle (ยังไม่ค้นหา): ข้อความแนะนำกลางจอ
- Searching: ปุ่มค้นหา disabled+spin
- ผลลัพธ์ว่าง: "ไม่พบผู้ใช้ที่ตรงกับ '{query}'"
- มีผลลัพธ์: ตารางแถว

Design Rules: ไม่มี pagination ในรอบนี้ (limit ผลลัพธ์ที่ ~30 แถว พอสำหรับการค้นหาแบบเจาะจง — ถ้าเกิน 30 แถวแนะนำให้พิมพ์คำค้นที่เจาะจงกว่านี้ แสดงข้อความบอกใต้ตาราง ไม่ implement pagination UI เต็มรูปแบบตอนนี้)

---

## Screen 2 — User Detail (`app/(admin)/users/[id]/page.tsx`, หน้าใหม่)

Purpose: ดู Profile/สถานะ/Reports/ประวัติ และสั่ง action

User Flow:
1. เข้าจาก Screen 1 → เห็นข้อมูลผู้ใช้ครบ + ปุ่ม action 5 ปุ่ม (Warn/Restrict/Suspend/Ban/Unban)
2. กดปุ่ม action ใดๆ → เปิด `Dialog` เฉพาะของ action นั้น (รายละเอียดด้านล่าง) → กรอก → ยืนยัน → Dialog ปิด, หน้ารีเฟรชสถานะใหม่ (`router.refresh()` มิเรอร์ pattern เดียวกับ WYN-050's `RefreshButton`)

Components:

**Header ส่วนบน**: username (`text-2xl font-bold`) + display_name ใต้ (`text-muted-foreground`) + `Badge` role + `Badge` สถานะปัจจุบัน (ถ้ามี — "Restricted ถึง DD/MM/YYYY" / "Suspended ถึง DD/MM/YYYY" / "Banned" สีแดงเสมอเมื่อแสดง เพราะเป็นสถานะที่ active จริงๆ ไม่ใช่ metric ทั่วไปแบบ WYN-050's reports)

**แถบปุ่ม Action**: 5 ปุ่มเรียงแนวนอน — Warn (`variant="outline"`), Restrict (`variant="outline"`), Suspend (`variant="outline"`), Ban (`variant="destructive"` — สีแดงเด่นชัดกว่าปุ่มอื่น เพราะเป็น action รุนแรงที่สุด), Unban (`variant="outline"`, **disabled เมื่อผู้ใช้ไม่ได้อยู่ในสถานะ blocked** — กดไม่ได้ถ้าไม่มีอะไรให้ unban จริง ป้องกันความสับสน)

**Section "รายงานที่มีต่อผู้ใช้นี้"**: table แถวละ report (category, detail, status, created_at) — **ไม่มีคอลัมน์ reporter เลย** (ตรงตาม Product's Requirement 1 — VIEW เดิมซ่อนไว้อยู่แล้วโครงสร้าง) ว่างเปล่า → "ไม่มีรายงานต่อผู้ใช้นี้"

**Section "ประวัติการดำเนินการ"**: table แถวละ moderation action (action_type แปลไทย: Warn/Restrict/Suspend/Ban, reason, duration_days ถ้ามี, created_at, **reviewer username**, สถานะ "ถูกยกเลิกแล้ว" ถ้า `overturned_at` ไม่ null — แสดงเป็น `Badge` เทาจาง ไม่ใช่สีเตือน เพราะการถูกยกเลิกคือเรื่องดี ไม่ใช่ปัญหา) ว่างเปล่า → "ยังไม่มีประวัติการดำเนินการ"

**Dialog: Warn**
- `DialogTitle`: "ตักเตือนผู้ใช้"
- `Textarea` (reason, required, placeholder="เหตุผลในการตักเตือน")
- ปุ่มยืนยัน `variant="default"` (ไม่ destructive — Warn เป็น action เบาสุดใน 4 ตัว)

**Dialog: Restrict / Suspend** (โครงเดียวกัน ต่างแค่ title/wording)
- `Textarea` (reason, required)
- `Select` (duration: "1 วัน" / "3 วัน" / "7 วัน", required, ไม่มีค่า default ที่เลือกไว้ล่วงหน้า — บังคับให้ Admin ตั้งใจเลือกเอง ไม่ใช่กดยืนยันเผลอด้วยค่า default)
- ปุ่มยืนยัน `variant="outline"`

**Dialog: Ban** (severity สูงสุด — ใช้ typed-confirmation มิเรอร์ pattern เดียวกับ Flutter app's `delete_account_screen.dart` — WYN-047's "พิมพ์ข้อความยืนยันเพื่อลบบัญชีถาวร")
- `Textarea` (reason, required)
- ข้อความเตือน: "การ Ban เป็นการบล็อกถาวร ผู้ใช้จะโพสต์/ทำกิจกรรมใดๆ ไม่ได้อีก จนกว่าจะมีคน Unban"
- `Input` พิมพ์ยืนยัน: "พิมพ์ `{username}` เพื่อยืนยัน" — ปุ่มยืนยัน **disabled จนกว่าข้อความจะตรงกับ username เป๊ะ** (case-sensitive ตรงตัว มิเรอร์ Flutter's exact-match gate)
- ปุ่มยืนยัน `variant="destructive"`

**Dialog: Unban**
- `Textarea` (reason, required — สำหรับ audit trail "ทำไมถึง unban")
- ปุ่มยืนยัน `variant="default"`

Interactions: ทุก Dialog มี loading state ระหว่างเรียก RPC (ปุ่มยืนยัน disabled+spin) — สำเร็จ → ปิด Dialog + `router.refresh()` — ล้มเหลว → ข้อความ error ใน Dialog เอง (ไม่ปิด Dialog ให้ผู้ใช้แก้แล้วลองใหม่ได้)

States: Loading (ครั้งแรกของหน้า, skeleton แบบเดียวกับ WYN-050's `DashboardSkeleton` philosophy — โครงเดียวกับของจริง), Loaded, Error (retry button, ใช้ `app/(admin)/error.tsx` เดิมจาก WYN-050 ได้เลยไม่ต้องสร้างใหม่)

Responsive Behavior: Desktop-first ตาม WYN-049 — ปุ่ม action 5 ปุ่มยุบเป็น 2 แถวบนจอแคบผ่าน `flex-wrap` มาตรฐาน ไม่ต้องออกแบบ breakpoint พิเศษ

Accessibility: `Dialog` ใช้ Radix's focus-trap มาตรฐาน (ไม่ต้องเขียนเอง) — ปุ่ม Ban's typed-confirmation input มี `aria-describedby` ชี้ไปข้อความ "ต้องพิมพ์ username ให้ตรงเป๊ะ"

Design Rules:
- **ไม่มี action "Remove Content"/"No Action" ในหน้านี้เลย** (ตามที่ Product ล็อกสโคปไว้ — เป็นเรื่องเนื้อหา ไม่ใช่ผู้ใช้โดยตรง)
- **ไม่มีปุ่ม "Force Logout"** (เลื่อนออกตาม Product spec — ไม่ใส่ปุ่ม disabled ค้างไว้ที่กดไม่ได้ เพราะจะดูเหมือน bug ไม่ใช่ scope decision)
- สีแดง (`destructive`) ใช้เฉพาะ Ban เท่านั้นในกลุ่มปุ่ม action — Warn/Restrict/Suspend/Unban ใช้ `outline`/`default` ปกติ (ระดับความรุนแรงสื่อผ่านสีตามลำดับ ไม่ใช่ทุกปุ่มเป็นสีเดียวกันหมด)

Handoff: AI Coding — `admin_apply_user_action()`/`admin_unban_user()` เรียกผ่าน browser client ปกติ (client component ของ Dialog) ไม่ต้องผ่าน Server Action เพราะไม่มี cookie/redirect logic เกี่ยวข้อง (ต่างจาก sign-in/sign-out ของ WYN-049) — reload ข้อมูลด้วย `router.refresh()` เหมือน WYN-050's RefreshButton เป๊ะ

---

## Visual Refresh (2026-09-04) — Black & White Premium

**สถานะ**: Search/Detail flow, RPC calls, ปุ่ม action ทั้ง 5, Dialog ทั้ง 5 แบบ (Warn/Restrict/Suspend/Ban/Unban), Reports/History table **ไม่เปลี่ยนแม้แต่จุดเดียวในเชิงฟังก์ชัน** — re-skin ล้วนๆ ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-admin-design-system.md`

สิ่งที่เปลี่ยนจริง (visual เท่านั้น):
- **Role Badge (`admin`=ม่วง, `moderator`=น้ำเงิน, `user`=เทา เดิม) → เปลี่ยนทั้งชุดเป็น weight-based neutral** (ไม่มีสีอีกต่อไป): `admin` = pill พื้น `ink` เต็ม+ตัวหนังสือขาว, `moderator` = pill พื้น `gray-200`+ตัวหนังสือ `ink`, `user` = pill โปร่งใส border `gray-300`+ตัวหนังสือ `gray-600` — hierarchy สื่อผ่านความเข้มของพื้น ไม่ใช่ hue (ดูหัวข้อ 6.2 ของเอกสารระบบใหม่) นี่คือการเปลี่ยนแปลงที่ใหญ่ที่สุดของหน้านี้ เพราะเป็นสีตกแต่งที่ชัดเจนที่สุดจุดหนึ่งในระบบเดิม
- **Badge สถานะ (Restricted/Suspended/Banned)**: ยังเป็นสีแดง (`destructive`) เหมือนเดิมทุกประการเมื่อ active — ค่าตอนนี้คือ `#DC2626`/`#F87171` ตรงหัวข้อ 3.2 (critical alert ที่แท้จริง, ไม่เปลี่ยนพฤติกรรม "แสดงเฉพาะตอน active")
- **Badge shape**: จาก `rounded-md` (เหลี่ยมมน) → pill เต็ม (`rounded-full`) ทุก Badge ในหน้านี้ (role/status/history) — เปลี่ยนรูปทรงเดียวกันทั้งระบบ ไม่ใช่แค่หน้านี้
- **ปุ่ม Ban**: ยัง `variant="destructive"` (แดง) เหมือนเดิมทุกประการ — เป็น 1 ใน 3 กรณีที่กติกาสีใหม่อนุญาตให้มีสี (destructive action)
- **ปุ่ม Warn/Unban ที่ยืนยันแล้ว (`variant="default"` เดิม)**: ตอนนี้ = `ink` เต็ม+ตัวหนังสือขาว (เปลี่ยนจาก cyan เดิม)
- **History badge "ถูกยกเลิกแล้ว"**: ยังเป็น pill เทาจาง (`gray-100`+`gray-600`) เหมือนเดิม — **ไม่เปลี่ยนพฤติกรรม** (ยืนยันซ้ำว่า "ไม่ใช่สีเตือน" ยิ่งชัดเจนขึ้นเพราะตอนนี้ไม่มีสีอื่นให้เลือกเลยนอกจาก grayscale)
- **Card**: เอา shadow ออก เหลือ border `gray-200`

สิ่งที่ **ไม่เปลี่ยนเลย**: การค้นหา/limit 30 แถว, ปุ่ม action ครบทั้ง 5 (Warn/Restrict/Suspend/Ban/Unban), Ban's typed-confirmation gate, duration select (1/3/7 วัน) สำหรับ Restrict/Suspend, การไม่มีปุ่ม Force Logout/Remove Content, reviewer username ที่แสดงใน History, การซ่อน reporter identity ใน Reports table, responsive/accessibility requirements ทั้งหมด
