# Design Spec — WYN-027: Block System

อ้างอิง Design System ที่อนุมัติแล้ว (ไม่คิดทิศทาง visual ใหม่): `.wyn/docs/design/ds-001-color-system.md`, `.wyn/docs/design/ds-008-responsive-accessibility.md`, `.wyn/docs/design/ds-009-rainbow-accent.md` (ไม่เกี่ยวข้อง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-027-block-system.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `ViewProfileScreen`'s More menu (WYN-026 — ออกแบบเผื่อไว้แล้วให้ WYN-027/028 เพิ่มรายการเข้าเมนูเดียวกันได้โดยไม่ต้องรื้อ), `ReportSheet`/`showReportSheet` (WYN-026), `confirmDeletePost`/`ClubPage._confirmLeave` (dialog ยืนยัน pattern), `FollowListScreen` (แถว list pattern), `ProfileDropGridTab`/`ProfilePopGridTab`'s `emptyText` param (WYN-013 — รับ string จากภายนอกอยู่แล้ว ไม่ต้องสร้าง widget ใหม่)

## ภาพรวมแนวทาง: บังคับใช้ที่ชั้นข้อมูล ไม่ใช่สร้าง UI ปิดกั้นใหม่แยกจุด

Requirement ส่วนใหญ่ของ WYN-027 ("ไม่เห็น Content กัน", "Interaction ถูกจำกัด") **ไม่ใช่ UI ใหม่** แต่เป็นผลจากการกรองที่ชั้นข้อมูล (RLS ที่ join ตาราง `blocks` ตามที่ Product's Risk แนะนำไว้แล้ว) — เมื่อเนื้อหาของอีกฝ่ายถูกกรองออกตั้งแต่ระดับ query/RLS แล้ว Home Feed/Search/Trending/Comment list จะไม่มีอะไรให้ต้อง "ปิดกั้น" เพิ่มในชั้น UI เลย (แถวที่ไม่ผ่าน RLS จะไม่ถูกส่งกลับมาตั้งแต่ต้น) — Screen 6 ("ผลของ Interaction ถูกจำกัด") จึงเป็นผลพลอยได้อัตโนมัติจาก data-layer filtering ไม่ใช่ component ใหม่ที่ต้องออกแบบแยก

สิ่งที่ **เป็น UI จริง** และต้องออกแบบมี 6 จุด: (1) Block entry point + confirmation dialog, (2) สถานะ Profile ของคนที่ Block กันอยู่ (บล็อกแล้วแต่ยังเปิดถึงได้ผ่าน Search), (3) Settings screen ขั้นต่ำ (ยังไม่มีเลยในแอป) + Blocked List, (4) ตัวเลือกเสริม "Block ผู้ใช้นี้ด้วย" ใน Report flow, (5) Follow button ที่ปิดใช้งานเมื่อ Block กันอยู่, (6) mention ที่ resolve ไม่ได้เมื่อ Block กันอยู่

---

## Screen 1: Entry Point — Profile More menu (ต่อยอดเมนูที่ WYN-026 เผื่อไว้)

Purpose: เพิ่ม "บล็อก" เข้าเมนู More ของ `ViewProfileScreen` ที่ WYN-026 ออกแบบไว้แล้วให้ขยายได้โดยไม่ต้องรื้อ

User Flow: เปิดโปรไฟล์คนอื่น (ที่ยังไม่ได้ Block กันอยู่) → แตะ More → เมนูมี 2 รายการ: "รายงาน" (เดิม) + "บล็อก" (ใหม่) → แตะ "บล็อก" → ปิดเมนู → เปิด dialog ยืนยัน (Screen 2)

Components: เพิ่ม `ListTile` ("บล็อก", `Icons.block`) ต่อจาก "รายงาน" ในเมนูเดิม — **เฉพาะเมื่อยังไม่มี block relationship กับโปรไฟล์นี้เท่านั้น** (ถ้า block กันอยู่แล้วไม่ว่าทิศทางไหน เมนูจะแสดงแบบ Screen 3 แทน ไม่ใช่รายการนี้)

Interactions: แตะ "บล็อก" → ปิด More menu ก่อน (pattern เดียวกับ "รายงาน") → เปิด dialog ยืนยัน

States: ปุ่มนี้ไม่มีสถานะ loading ของตัวเอง (loading เกิดใน dialog ยืนยัน — Screen 2)

Design Rules: "บล็อก" อยู่ล่างสุดของเมนู (ต่อจาก "รายงาน") เพราะเป็น action ที่กระทบเยอะกว่า Report — ลำดับ severity ต่ำไปสูงจากบนลงล่าง ตรงกับที่ WYN-026 วางไว้ว่าเมนูของ Club Post ("รายงาน" อยู่ล่างสุดของรายการที่มีผลกระทบสูงกว่าอย่าง Pin/Remove") ใช้หลักเดียวกัน

---

## Screen 2: Block Confirmation Dialog

Purpose: ให้ผู้ใช้เข้าใจผลกระทบก่อนยืนยัน Block จริง (ยกเลิก Follow ทั้งสองทิศทาง, ไม่เห็นกันอีก)

User Flow: แตะ "บล็อก" → dialog เปิด → อธิบายผลกระทบสั้นๆ → กด "บล็อก" ยืนยัน (หรือ "ยกเลิก") → บล็อกสำเร็จ → dialog ปิด + SnackBar "บล็อก @username แล้ว" → กลับสู่ ViewProfileScreen ที่ตอนนี้แสดงสถานะ Blocked (Screen 3)

Components: `AlertDialog` มาตรฐานเดียวกับ `confirmDeletePost`/`ClubPage._confirmLeave` (ไม่ใช่ dialog แบบใหม่):
- Title: `บล็อก @username?`
- Content: `คุณจะไม่เห็นเนื้อหาของกันและกันอีกต่อไป การติดตามระหว่างกัน (ถ้ามี) จะถูกยกเลิกทันที ยกเลิกการบล็อกได้ภายหลังที่ตั้งค่า`
- Actions: `TextButton` "ยกเลิก" (ปิด dialog เฉยๆ) + `TextButton` "บล็อก" (ยืนยัน)

Interactions: กด "บล็อก" → ปุ่มแสดง loading (หรือ dialog ปิดทันทีแบบ optimistic ก็ได้ ตาม pattern ปุ่ม Follow ที่มีอยู่แล้วในแอปที่ optimistic-update ก่อนค่อย sync — เลือก **optimistic** เพื่อความเร็ว: ปิด dialog ทันทีที่กด, แสดง SnackBar, แล้วค่อย sync ผลจริงเบื้องหลัง เหมือน `_toggleFollow` ที่มีอยู่แล้ว)

States:
- Success: SnackBar "บล็อก @username แล้ว", ViewProfileScreen reload เข้าสถานะ Blocked (Screen 3)
- Error (เช่น network fail): SnackBar "บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง", ViewProfileScreen ไม่เปลี่ยนสถานะ (เหมือน pattern error ของ `_toggleFollow`)

Design Rules: ปุ่ม "บล็อก" ใช้สี default ของ `TextButton` **ไม่ใช้สีแดง/error** — คงความสม่ำเสมอกับ `confirmDeletePost`/`_confirmLeave` ที่ไม่เคยใช้สีแดงสำหรับปุ่มยืนยัน action ที่มีผลกระทบเลยตลอดทั้งแอป (แม้จะเป็น destructive-ish) ห้ามคิดทิศทางใหม่เฉพาะจุดนี้

---

## Screen 3: `ViewProfileScreen` — Blocked persona (สถานะที่ 3 นอกจาก own/other)

Purpose: จัดการกรณีที่ผู้ใช้ยังเปิดถึงโปรไฟล์ของคนที่ Block กันอยู่ได้ (เช่น เจอจาก Search's User tab ที่ profile ยังค้นหาเจอได้ปกติ — ดู Screen 7) โดยไม่ละเมิดกฎ "ไม่มีปุ่ม Unblock ด่วนจาก Profile"

User Flow: เปิดโปรไฟล์ของคนที่มี block relationship กับตัวเอง (ไม่ว่าใครบล็อกใคร) → เห็น avatar/username ปกติ (โปรไฟล์พื้นฐานยังค้นหาเจอได้ — ไม่ได้ปิดกั้นทั้งระบบ) แต่ Follow/เนื้อหาถูกจำกัดตาม 2 แบบย่อย

Components:
- **แบบ A — ฉันเป็นคน Block เขา**: banner แถบเดียวใต้ avatar/username แทนที่ตำแหน่งปุ่ม Follow เดิม — ข้อความ "คุณบล็อกผู้ใช้นี้อยู่" (ไอคอน `Icons.block`, พื้นหลัง `surfaceContainer`, ไม่ใช้สีแดง/error ตามกติกาเดียวกับ Screen 2) **ไม่มีปุ่ม Unblock ในนี้เลย** ตามที่ Product ระบุตรงๆ — Followers/Following count ซ่อนไป (ไม่แสดงตัวเลข เพราะความสัมพันธ์ถูกตัดขาดแล้ว ตัวเลขไม่มีความหมายในบริบทนี้)
- **แบบ B — เขาบล็อกฉัน** (ฉันทำอะไรไม่ได้ ไม่ใช่ฝ่ายเลือก): banner ข้อความต่างออกไปเล็กน้อยเพื่อความสัตย์จริง — "ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้" (ไม่ใช้คำว่า "คุณบล็อก" เพราะไม่จริง) ไม่มีปุ่มใดๆ ในนี้เช่นกัน (ยกเลิกไม่ได้อยู่แล้วเพราะไม่ใช่ฝ่ายบล็อก)
- **Drop/Pop grid tab ทั้งสอง**: ส่ง `emptyText` ที่ต่างจากค่าเริ่มต้น — แบบ A: `"คุณบล็อกผู้ใช้นี้อยู่ จึงไม่เห็นเนื้อหาของเขา"`, แบบ B: `"ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้"` (ใช้กลไก `emptyText` param ที่ `ProfileDropGridTab`/`ProfilePopGridTab` มีอยู่แล้วจาก WYN-013 — **ไม่สร้าง widget ใหม่**) — สำคัญ: ต้องไม่ใช้ empty-text เดิม ("ยังไม่มี Drop เลย") เพราะจะสื่อผิดว่าเขาไม่มีเนื้อหาจริงๆ ทั้งที่แค่ถูกซ่อนจากมุมมองนี้
- **More menu**: ยังกดได้ แต่เหลือแค่ "รายงาน" (ไม่มี "บล็อก"/"เลิกบล็อก" ใดๆ ในเมนูนี้เลย ไม่ว่า A หรือ B — สอดคล้องกับ "ไม่มีปุ่ม Unblock ด่วนจาก Profile" ที่ Product ระบุ)

Interactions: ไม่มี action ใหม่ในหน้านี้เลยนอกจาก "รายงาน" ที่มีอยู่แล้ว — หน้านี้เป็น read-only โดยเจตนา

States: โหลด block-relationship status พร้อมกับ follow-status เดิม (เพิ่ม 1 query ขนาน ไม่ block การแสดงผลอื่น — ปุ่ม Follow/banner ซ่อนจนกว่าจะรู้สถานะจริง เหมือน pattern `_isFollowing == null` ที่มีอยู่แล้ว)

Design Rules: **ไม่เพิ่มทางลัดไป Settings→Safety จาก banner นี้เลย** แม้จะดูสะดวกกว่า — Product ระบุเจตนาไว้ตรงๆ ว่ากันมือลื่น การเพิ่ม shortcut จะขัดกับเจตนานั้นทันที

---

## Screen 4: Settings Screen (ใหม่ — ขั้นต่ำ) + Entry Point

Purpose: ที่อยู่ของ Blocked List (Product spec ระบุตายตัวว่า Unblock ทำได้ที่นี่ทางเดียว) — แอปยังไม่มีหน้า Settings เลยจนถึงตอนนี้ (Settings เต็มรูปแบบคือ WYN-045, Phase 5) จึงต้องสร้าง**เวอร์ชันขั้นต่ำ**รอบนี้ที่ขยายได้ทีหลังโดยไม่ต้องรื้อ

User Flow: เปิดโปรไฟล์ตัวเอง → แตะไอคอนตั้งค่าใหม่ (แยกจากปุ่ม logout เดิม) → `SettingsScreen` เปิด → แตะ "บัญชีที่ถูกบล็อก" → `BlockedListScreen` เปิด (Screen 5)

Components:
- **`ViewProfileScreen` AppBar (เฉพาะ `isOwnProfile == true`)**: เพิ่ม `IconButton` (`Icons.settings_outlined`, tooltip "ตั้งค่า") **ต่อจาก** ปุ่ม logout เดิม (ไม่แทนที่ ไม่ย้ายตำแหน่ง logout เดิม — คงพฤติกรรมเดิมของ WYN-013 ทุกประการ เพิ่มแค่ปุ่มใหม่)
- **`SettingsScreen`**: `Scaffold` + `AppBar(title: "ตั้งค่า")` + `ListView` มี 1 section เท่านั้นในรอบนี้: หัวข้อ "ความปลอดภัย" (`titleSmall`, สี `outline`) ตามด้วย `ListTile` เดียว "บัญชีที่ถูกบล็อก" (`Icons.block`, trailing `Icons.chevron_right`) — โครงสร้าง section-based นี้ตั้งใจให้ WYN-045 เพิ่ม section อื่น (Account/Privacy/Notifications ฯลฯ) ต่อท้ายได้ในอนาคตโดยไม่ต้องรื้อ

Interactions: แตะแถว "บัญชีที่ถูกบล็อก" → เปิด `BlockedListScreen`

States: ไม่มี loading (เป็น static list ของ section headers ในรอบนี้)

Responsive/Accessibility: มาตรฐานเดียวกับทุกหน้าจอ (touch target ≥44, contrast ผ่าน AA)

Design Rules: **ห้ามสร้างเมนูเกินกว่า "ความปลอดภัย" section เดียวในรอบนี้** แม้ Master Spec ข้อ 35 จะกำหนด section ครบ 7 หมวด (Account/Privacy/Notifications/Security/Safety/Data/Legal) — สร้างล่วงหน้าตอนนี้จะเป็น UI ที่กดแล้วไม่มีอะไรเกิดขึ้นจริง (WYN-045 ยังไม่เริ่ม) ซึ่งแย่กว่าไม่มีเมนูเลย

---

## Screen 5: `BlockedListScreen`

Purpose: ดูรายชื่อ + เลิกบล็อกได้ — เป็นทางเดียวที่ Unblock ทำได้ตาม Product spec

Components: **reuse โครงสร้างแถวของ `FollowListScreen` ทุกประการ** (avatar+ชื่อ/@username) — ต่างจาก `FollowListScreen` ตรงที่ **แถวไม่ใช่ tap target ไปโปรไฟล์** (ตั้งใจ — ป้องกันไม่ให้กลายเป็นทางลัดไปโปรไฟล์คนที่ถูกบล็อกโดยไม่จำเป็น) แต่ละแถวมีปุ่ม "เลิกบล็อก" (`OutlinedButton` เล็ก, ชิดขวา) แทน tap ทั้งแถว

Interactions: แตะ "เลิกบล็อก" → เปิด dialog ยืนยัน (`AlertDialog` เดียวกับ pattern Screen 2: "เลิกบล็อก @username?" / เนื้อหา "คุณจะเห็นเนื้อหาของกันและกันได้อีกครั้ง — การติดตามเดิม (ถ้ามี) จะไม่กลับมาอัตโนมัติ" / ปุ่ม "ยกเลิก"/"เลิกบล็อก") → ยืนยัน → แถวหายจาก list ทันที (optimistic)

States:
- Loading: skeleton/spinner ตอนโหลด list ครั้งแรก (pattern เดียวกับทุก list ในแอป)
- Empty: "ยังไม่มีบัญชีที่ถูกบล็อก"
- Error: "โหลดรายชื่อไม่สำเร็จ" + ปุ่มลองใหม่ (pattern มาตรฐาน)

Responsive Behavior: infinite-scroll/pagination เดียวกับ `FollowListScreen` ถ้ารายชื่อยาว (reuse pagination pattern ที่มีอยู่แล้ว ไม่ประดิษฐ์ใหม่)

Accessibility: ปุ่ม "เลิกบล็อก" มี `Semantics` label เต็ม "เลิกบล็อก @username"

Design Rules: ไม่มี bulk-unblock/select-multiple ในรอบนี้ (นอก scope ตาม AC ที่ระบุแค่ "แตะ Unblock รายคน")

---

## Screen 6: ผลของ Interaction ถูกจำกัด (ไม่มี UI ใหม่ — บันทึกไว้กันเข้าใจผิด)

Purpose: ยืนยันชัดเจนว่า Requirement ข้อนี้ **ไม่ต้องการ component ใหม่**

Design Rules:
- Home Feed/Search (Drop/Pop/Club tab)/Trending/Comment list: ไม่มี UI เปลี่ยนแปลงใดๆ — แถวของฝ่ายที่ Block กันอยู่ไม่ถูกส่งกลับมาตั้งแต่ query/RLS เลย จึงไม่มีอะไรให้ "ปิดกั้น" ในชั้น UI เพิ่ม
- **ผลข้างเคียงที่ยอมรับเป็น known limitation**: `commentCount`/ตัวเลขนับอื่นๆ เป็นค่า denormalized ที่นับรวมทุกคนไว้แต่ก่อน Block — เมื่อ comment ของฝ่ายที่ Block ถูกกรองออกจาก list ตัวเลขที่แสดง (เช่น "5 comments") อาจไม่ตรงกับจำนวนแถวที่เห็นจริง (เช่น เห็นแค่ 4 แถว) — เป็น trade-off ที่ยอมรับได้ (เหมือนแพลตฟอร์มอื่นๆ ทั่วไป) ไม่ใช่บั๊กที่ต้องแก้รอบนี้
- Drop/Pop Detail ที่เปิดผ่านลิงก์ตรง/notification เก่าไปยังเนื้อหาของฝ่ายที่ Block กันอยู่: **ไม่ต้องมี "disabled interaction" UI แยก** ตามที่ Product's wording แนะไว้ — ถ้า RLS กรองที่ระดับ `drops`/`pops`/`club_posts` SELECT เอง การเปิดตรงจะเจอ error state ที่มีอยู่แล้วในแอปทันที ("โหลด Drop ไม่สำเร็จ"/"โหลด Pop ไม่สำเร็จ" — เหมือนกรณีเนื้อหาถูกลบไปแล้ว) — ไม่ต้องสร้าง state ใหม่

---

## Screen 7: Report flow — ตัวเลือกเสริม "บล็อกผู้ใช้นี้ด้วย"

Purpose: ให้ Block ทำต่อจาก Report ได้ในขั้นตอนเดียวตามที่ Product ระบุ ("ไม่บังคับ")

User Flow: ส่ง Report สำเร็จ (target ที่มีเจ้าของเป็นคนชัดเจน — ดู Components) → แทนที่จะเป็นแค่ SnackBar เฉยๆ → SnackBar มีปุ่ม action "บล็อก" ต่อท้ายข้อความ → แตะ → เปิด dialog ยืนยันเดียวกับ Screen 2 (ใช้ user id ของเจ้าของเนื้อหาที่เพิ่ง report ไป)

Components: ขยาย `showReportSheet`/`ReportSheet` (WYN-026) เพิ่มพารามิเตอร์ optional **`associatedUserId`** — ผู้เรียกส่งเข้ามาเมื่อ target มีเจ้าของที่ระบุตัวได้ชัดเจน:
- `user` → `associatedUserId = targetId` เอง (กำลัง report ตัวบุคคลนั้นตรงๆ)
- `drop`/`drop_comment`/`club_post`/`club_post_comment` → `associatedUserId = authorId` ของเนื้อหานั้น
- **`club` → ไม่ส่ง `associatedUserId`** (ไม่เสนอ "Block" ต่อจาก Report Club — เจ้าของ Club ไม่ใช่ "ผู้แต่งเนื้อหา" ในความหมายเดียวกับ Drop/Comment และ Owner อาจไม่ได้ทำผิดเอง จึงไม่ผูก 2 action เข้าด้วยกันสำหรับ target ประเภทนี้)

เมื่อมี `associatedUserId`: SnackBar หลังส่ง Report สำเร็จเปลี่ยนจาก plain `SnackBar` เป็น `SnackBar` ที่มี `action: SnackBarAction(label: 'บล็อก', onPressed: ...)` เปิด dialog ยืนยัน Block (Screen 2) แบบเดียวกับทุกที่

Interactions/States: เหมือน Screen 2 ทุกประการ (dialog เดียวกัน)

Design Rules: ถ้า `associatedUserId` ระบุถึงตัวเอง (เช่น edge case ที่ RPC บล็อกไปแล้วก่อนหน้าใน `submit_report()`) หรือมี block relationship อยู่แล้ว → **ไม่แสดงปุ่ม "บล็อก" ใน SnackBar เลย** (ไม่ใช่แสดงแล้ว disable — ปุ่มเปล่าไม่มีความหมายถ้ากดแล้วไม่ได้ผลอะไร)

---

## Screen 8: Follow button — สถานะ Blocked

Purpose: ปิดใช้งาน Follow ทั้งสองทิศทางตราบเท่าที่ยัง Block กันอยู่ (ตาม AC)

Components: จุดที่มีปุ่ม Follow อยู่แล้วทั้งหมด (`DropDetailScreen`, `ViewProfileScreen`, `PopClipView`) — เมื่อโหลดสถานะแล้วพบว่ามี block relationship (ไม่ว่าทิศทางไหน) กับเจ้าของเนื้อหา:
- **`DropDetailScreen`/`PopClipView`**: ตามที่ Screen 6 ระบุ ปกติจะเจอ error state ("โหลด Drop ไม่สำเร็จ"/"โหลด Pop ไม่สำเร็จ") ก่อนถึงจุดนี้อยู่แล้วเพราะ RLS กรองออก — ปุ่ม Follow ที่นี่จึงไม่มีโอกาสแสดงสถานะ Blocked ในทางปฏิบัติ (ไม่ต้องออกแบบเพิ่ม) **รวมถึง `pops`/`pop_comments` ต้องมี RLS block-filter เดียวกับ `drops`/`drop_comments` ด้วย** (Pop ยังคงแสดงผลจริงใน Home feed แบบผสม แม้จะถอดออกจาก Bottom Nav tab แล้วตาม WYN-024 — RLS เป็นการแก้ที่ backend/`schema.sql` เท่านั้น **ไม่ถือว่าแตะไฟล์ Pop** ตามกติกาของ DS-008 ที่ห้ามเฉพาะการแก้ไฟล์ Flutter `pop_*.dart` โดยตรง จึงทำได้เต็มที่โดยไม่ต้องแก้ `PopClipView`/`HomePopCard` แม้แต่บรรทัดเดียว)
- **`ViewProfileScreen`**: ตาม Screen 3 (banner แทนที่ปุ่ม Follow ไปแล้วทั้งหมด ไม่ใช่ปุ่ม Follow แบบ disabled — ชัดเจนกว่าปุ่มสีเทาที่กดไม่ได้เฉยๆ)

Design Rules: ไม่ทำปุ่ม Follow แบบ "disabled แต่ยังมองเห็น" ที่ไหนเลย — ทุกจุดที่ Product ขอ "ปุ่ม Follow ถูกปิดใช้งาน" แทนที่ด้วย banner สื่อความหมายชัดเจนกว่า (Screen 3) ตามเหตุผลข้างต้น

---

## Screen 9: Mention resolution เมื่อ Block กันอยู่

Purpose: "พิมพ์ @username ของฝ่ายที่ Block กันอยู่ → ไม่ resolve เป็น mention ที่กดได้/ไม่ส่ง notification"

**การตัดสินใจ Design (ข้อจำกัดทางเทคนิคที่ต้องประกาศตรงๆ ไม่ปิดบัง)**: `HashtagText` (WYN-020/021) หา mention ด้วย regex ล้วนๆ ตอน render (`@username` เป็น pattern matching ธรรมดา ไม่รู้ว่า username นั้นมีตัวตนจริงหรือ Block กันอยู่หรือเปล่าจนกว่าจะถึงตอนแตะ) — การทำให้ mention ของคนที่ Block กันอยู่ **"แสดงเป็นข้อความธรรมดา" ตั้งแต่ตอน render** ต้องรู้ล่วงหน้าว่า username ไหนบ้างที่ Block อยู่ ซึ่งจะต้องส่ง blocked-username set ผ่าน 6 จุดที่เรียกใช้ widget นี้ทั้งหมด (`HomeDropCard`/`HomePopCard`/`DropDetailScreen`/`PopClipView`/`ClubPostCard`/`ClubPostDetailScreen`) — เป็นการเปลี่ยนแปลงกว้างเกินสัดส่วนของ requirement ข้อนี้ในรอบนี้

**ขอบเขตที่ทำจริงรอบนี้** (ครอบผลลัพธ์ที่สำคัญที่สุด 2 ใน 2 อย่างของ requirement):
1. **"ไม่ trigger notification"** — บังคับใช้ที่จุดสร้าง mention (insert `drop_mentions`/`club_post_mentions`) ไม่ใช่จุด render — ถ้ามี block relationship ระหว่างผู้โพสต์กับผู้ถูก mention ไม่สร้างแถว mention เลย (แม่นยำ 100% ไม่ใช่ best-effort)
2. **"ไม่ resolve เป็น mention ที่กดได้"** — แตะได้เหมือนเดิม (ยังเป็นสี tappable ตามปกติจนกว่าจะแตะ) แต่ `_openMentionedProfile` เช็ค block relationship ก่อน navigate ทุกครั้ง — ถ้ามี block relationship → **ไม่ทำอะไรเลย** (พฤติกรรมเดียวกับ mention ที่ resolve ไม่ได้อยู่แล้วในปัจจุบัน เช่น username พิมพ์ผิด/บัญชีถูกลบ — ไม่มี snackbar/error ใหม่ ใช้ pattern เงียบเดิม)

**สิ่งที่ไม่ทำในรอบนี้ (ประกาศไว้ตรงๆ)**: สี/สไตล์ตัวหนังสือของ mention ที่ Block กันอยู่ **ยังคงเป็นสี tappable ปกติจนกว่าจะแตะ** ไม่ใช่ "ข้อความธรรมดา" ตามตัวอักษรของ Requirement 100% — ผลลัพธ์ทางปฏิบัติ (กดแล้วไม่ไปไหน, ไม่มี notification) เหมือนกันทุกประการ ต่างแค่ภาพก่อนแตะ ถ้า Founder ต้องการให้ตรงตัวอักษร 100% ต้องขยาย scope เป็น task แยกที่แก้ทั้ง 6 call site

Design Rules: `MentionInput` (ตอนพิมพ์แคปชัน, autocomplete) ควรกรอง user ที่มี block relationship ออกจากผลการค้นหาด้วย เป็น defense-in-depth เพิ่มเติมที่ implement ได้ถูกกว่า (เป็น query filter เดียว ไม่ใช่ผูก 6 จุด) — ไม่ใช่ hard requirement แต่แนะนำทำถ้า Coding มีเวลา

---

## Handoff

ส่งต่อ AI Coding ตามลำดับที่แนะนำ (ความเสี่ยง regression จากต่ำไปสูง ตามที่ Product's Risk ก็เตือนไว้ว่านี่คืองานกระทบวงกว้างสุดของ Phase 1):

1. **Data layer ก่อนสุด**: ตาราง `blocks (blocker_id, blocked_id, created_at)` + unique constraint คู่ + helper function ตรวจ "มี block relationship ระหว่าง 2 คนไหม" (ทิศทางไหนก็ได้ — reuse ได้ทั้ง Follow-guard/RLS join/`ViewProfileScreen`) — RLS join เข้า `drops`/`club_posts`/`drop_comments`/`club_post_comments`/**`pops`/`pop_comments`**/`follows` ทุกจุดตาม Product's Risk แนะนำ (ทำให้ Screen 6 เป็นจริงอัตโนมัติ — `pops`/`pop_comments` รวมอยู่ด้วยแม้ Pop จะไม่มี Bottom Nav tab แล้ว เพราะยังโผล่ใน Home feed แบบผสมจริง เป็นการแก้ SQL ล้วนๆ ไม่ใช่การแก้ไฟล์ Flutter ของ Pop ที่ต้องห้าม)
2. Block ยกเลิก Follow ทั้งสองทิศทาง (trigger หรือทำใน RPC เดียวกับตอน insert `blocks`)
3. Screen 1-2 (entry point + confirm dialog บน `ViewProfileScreen`)
4. Screen 3 (Blocked persona ของ `ViewProfileScreen`)
5. Screen 4-5 (Settings ขั้นต่ำ + Blocked List)
6. Screen 7 (ต่อยอด `ReportSheet` เพิ่ม `associatedUserId` — ไฟล์เดียวที่แก้คือ `report_sheet.dart` + entry point 5 จุดที่เรียกมันอยู่แล้วจาก WYN-026 เพิ่ม param เดียว)
7. Screen 9 (mention insert-guard + tap-time check) ทำท้ายสุดเพราะแตะไฟล์ที่ใช้ร่วมกันเยอะที่สุด (`HashtagText`)

เก็บ regression test ให้ครบทุกไฟล์ที่แตะ โดยเฉพาะ `follow_repository`/`home_repository`/`search`-related tests เดิมต้องผ่านหมด (คู่ผู้ใช้ที่ไม่ได้ Block กันต้องไม่ได้รับผลกระทบใดๆ ตาม AC สุดท้าย) — **ไม่แก้ไฟล์ Flutter `pop_*.dart`/`PopClipView`/`HomePopCard` เลยสักบรรทัดตามกติการะงับพัฒนา (DS-008)** แต่ `pops`/`pop_comments` **ต้อง** ได้ RLS block-filter เดียวกับ `drops`/`drop_comments` ในขั้นตอนที่ 1 ด้วย เพราะ Pop ยังคงแสดงผลจริงใน Home feed แบบผสมอยู่ (แค่ถอด Bottom Nav tab เดี่ยวออกไปตาม WYN-024) — เป็นการแก้ที่ `schema.sql` ล้วนๆ ไม่ใช่การแก้ไฟล์ Pop ที่ต้องห้าม จึงยังอยู่ในกติกาที่อนุญาต
