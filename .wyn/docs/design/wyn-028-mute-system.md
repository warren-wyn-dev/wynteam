# Design Spec — WYN-028: Mute System

อ้างอิง Design System ที่อนุมัติแล้ว (ไม่คิดทิศทาง visual ใหม่): `.wyn/docs/design/ds-001-color-system.md`, `.wyn/docs/design/ds-008-responsive-accessibility.md`
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-028-mute-system.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `ViewProfileScreen`'s More menu (WYN-026/027 — เผื่อไว้แล้วให้เพิ่มรายการต่อได้), `SettingsScreen`/`BlockedListScreen` (WYN-027 — Muted List เป็น section ที่ 2 ของหน้าเดียวกัน ไม่ใช่หน้าใหม่), `FollowListScreen` (แถว tap-to-profile ปกติ), `_toggleFollow` (optimistic toggle ไม่มี dialog ยืนยัน)

## ภาพรวมแนวทาง: เบากว่า Block ทุกมิติ ทั้ง data layer และ UI

WYN-028 มี scope แคบกว่า WYN-027 มาก เพราะ Requirement เขียนไว้ตรงข้ามกับ Block ทุกข้อ (one-directional, ไม่กระทบ Follow, ไม่จำกัด interaction, ไม่มี notification ใดๆ) — สิ่งที่ต้องออกแบบจริงมีแค่ 3 จุด: (1) toggle เข้า/ออกจาก More menu เดิม ไม่มี confirm dialog เพราะ reversible/เงียบ/ไม่กระทบใคร (2) filter ที่ `home_feed` view เท่านั้น (3) Muted List section ใน `SettingsScreen` เดิม

**ข้อแตกต่างสำคัญจาก Block ที่ต้องยึดตาม**: Product spec ใช้คำว่า "Unblock ได้จากหน้า Settings → Safety → Blocked List **เท่านั้น**" (WYN-027) แต่ WYN-028 เขียนแค่ "Unmute ได้จาก Settings → Safety → Muted List" **ไม่มีคำว่า "เท่านั้น"** — ต่างจาก Block ที่ตั้งใจกันมือลื่นเพราะผลกระทบรุนแรง (ตัด Follow, ทั้งสองฝ่ายเห็นผล) Mute แทบไม่มีความเสี่ยงจากการกดพลาด (มองไม่เห็นจากอีกฝ่ายเลย, undo ได้ทันทีไม่มีผลกระทบใดๆ ค้างอยู่) จึงออกแบบให้ **Unmute ทำได้ทั้งจาก Profile More menu โดยตรง (toggle) และจาก Muted List** — ต่างจาก Block ที่บล็อกทางลัดไว้ตรงๆ

**Data layer ก็เบากว่า**: Block ต้องใช้ RPC (`block_user()`/`unblock_user()`) เพราะมี side-effect ที่ต้องทำอะตอมมิก (ลบ Follow relationship ทั้งสองทิศทาง) — Mute ไม่มี side-effect ใดๆ เลย จึงไม่ต้องมี RPC เลย ใช้ direct table insert/delete ผ่าน RLS policy ธรรมดา เหมือน `follows` table ไม่ใช่เหมือน `blocks` table

**เรื่อง RLS self-referential trap ที่ WYN-027 เจอ (บันทึกใน DECISIONS.md ว่าต้องระวังในงานนี้โดยเฉพาะ) — ยืนยันว่าไม่เกิดในรอบนี้**: filter ของ Mute อยู่ใน `home_feed` VIEW โดยตรง (ไม่ใช่ RLS policy ของ `drops`/`pops` เอง) และ subquery เช็ค exists จากตาราง `mutes` ที่ RLS ของมันเอง (`using (auth.uid() = muter_id)`) กรองด้วยเงื่อนไข**เดียวกัน**กับที่ subquery ต้องการอยู่แล้ว (ทั้งคู่คือ "แถวที่ muter_id = auth.uid() ของฉันเอง") ไม่ใช่กรองด้วยเงื่อนไขอื่นที่ขัดกันแบบที่เกิดกับ `drop_author_id` — จึงไม่ต้องใช้ security-definer helper function ใดๆ ในจุดนี้ ใช้ inline subquery ตรงๆ ได้ปลอดภัย (รายละเอียดเหตุผลเต็มอยู่ใน Screen 3)

---

## Screen 1: Entry Point — Profile More menu (toggle, ไม่ใช่ dialog)

Purpose: เพิ่มรายการ "ปิดเสียง"/"เปิดเสียง" (สลับตามสถานะปัจจุบัน) เข้าเมนู More ของ `ViewProfileScreen` ระหว่าง "รายงาน" และ "บล็อก"

User Flow: เปิดโปรไฟล์คนอื่น → แตะ More → เมนูมี 3 รายการ (เมื่อไม่มี block relationship): "รายงาน" → "ปิดเสียง"/"เปิดเสียง" (ตามสถานะ) → "บล็อก" → แตะรายการ mute → ปิดเมนูทันที → toggle เกิดขึ้นเบื้องหลัง (optimistic) → SnackBar ยืนยันผล

Components: `ListTile` (`Icons.volume_off` เมื่อยังไม่ mute แสดงว่า "ปิดเสียง" จะเกิดอะไรถ้ากด / `Icons.volume_up` เมื่อ mute อยู่แล้วแสดงว่า "เปิดเสียง" จะเกิดอะไรถ้ากด — ไอคอนสื่อ**การกระทำที่จะเกิดขึ้น**เมื่อกด ไม่ใช่สถานะปัจจุบัน ตามธรรมเนียม toggle ทั่วไปของแอป เช่น bookmark/favorite ที่มีอยู่แล้ว) — **แสดงเฉพาะเมื่อรู้สถานะ mute แน่ชัดแล้วเท่านั้น** (`_isMuted != null`) เหมือนเงื่อนไขเดียวกับที่ "บล็อก" ใช้กับ `_blockRelationship` — กันไม่ให้ label ผิดตอนที่ยังโหลดไม่เสร็จ

Interactions: แตะ → `Navigator.of(sheetContext).pop()` ก่อน (pattern เดียวกับ "รายงาน"/"บล็อก") → optimistic toggle: อัปเดต `_isMuted` ทันที (สลับค่า) → เรียก insert/delete บนตาราง `mutes` เบื้องหลัง → สำเร็จ: SnackBar "ปิดเสียง @username แล้ว" หรือ "เปิดเสียง @username แล้ว" → ล้มเหลว: revert `_isMuted` กลับค่าเดิม + SnackBar error ("ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง") — **pattern นี้คือ `_toggleFollow` ทุกประการ** ไม่ใช่ pattern ของ Block's confirm-dialog

States: ไม่มี dialog ยืนยันเลย (ต่างจาก Block ตรงๆ) เพราะ reversible เต็มร้อย ไม่มีใครเห็นผลเลยนอกจากตัวเอง — การเพิ่ม dialog ยืนยันสำหรับ action ที่กระทบแค่ตัวเองและ undo ได้ทันทีจะเป็นแรงเสียดทานเกินความจำเป็น (เทียบกับ Follow/Unfollow ในแอปที่ไม่มี dialog เหมือนกัน)

Design Rules: ตำแหน่งอยู่ระหว่าง "รายงาน" กับ "บล็อก" ตามลำดับ severity ต่ำไปสูงที่ WYN-027 วางกฎไว้แล้ว (Report ≈ กลาง เพราะเป็นการแจ้งแพลตฟอร์ม ไม่ใช่ action ต่อความสัมพันธ์ / Mute เบาสุดในบรรดา 2 action ที่กระทบ "ฉันเห็นเขาไหม" / Block หนักสุด) — **ไม่แสดงรายการ mute เลยเมื่อมี block relationship อยู่แล้ว** (ไม่ว่าทิศทางไหน) เพราะ More menu ในสถานะ Blocked (WYN-027 Screen 3) เหลือแค่ "รายงาน" เท่านั้นตามกฎเดิม — Mute ซ้ำซ้อนกับ Block ที่บังคับใช้แรงกว่าอยู่แล้ว

---

## Screen 2: `home_feed` view — Mute filter (data layer, ไม่มี UI ใหม่)

Purpose: ทำให้ "โพสต์ของผู้ถูก Mute หายไปจาก Home Feed ของผู้ Mute เท่านั้น" เป็นจริงที่จุดเดียว ไม่ต้องแก้ทุกจุดที่เรียก Home feed

**การตัดสินใจสำคัญ**: filter ต้องอยู่ **ใน `home_feed` VIEW เอง** (เพิ่ม `where not exists (select 1 from mutes where muter_id = auth.uid() and muted_id = <author_id ของแถวนั้น>)` ในแต่ละครึ่งของ UNION ALL) **ไม่ใช่**เพิ่มเป็น RLS policy บนตาราง `drops`/`pops` ตรงๆ แบบที่ WYN-027 ทำกับ Block — เหตุผล: `drops`/`pops` ถูก query ตรงๆ จากหลายจุด (Search, `ProfileDropGridTab`/`ProfilePopGridTab` ผ่าน `fetchByAuthor`, Club ไม่เกี่ยวเพราะเป็นคนละตาราง) ถ้า filter mute ที่ RLS ของตารางเหล่านั้นจะกระทบทุกจุดที่ query มันโดยไม่ตั้งใจ ผิด Requirement ที่ระบุชัดว่า **"ไม่กระทบ Search, ไม่กระทบ Club Post ร่วม, ไม่กระทบ Profile"** — filter ที่ตัว `home_feed` view เท่านั้นจึงเป็นจุดเดียวที่ตรง scope เป๊ะ เพราะมีแค่ 3 จุดที่ query view นี้ (`HomeRepository.fetchFeed`/`fetchTrending`/`fetchFollowingFeed`) และทั้ง 3 จุดคือ "Home Feed" ในความหมายที่ Requirement ต้องการพอดี (ทั้งโหมด "สำหรับคุณ"/"ล่าสุด"/"ติดตาม" และแถว "กำลังนิยม" ที่อยู่ในหน้า Home เดียวกัน)

**ผลพลอยได้ที่ต้องประกาศตรงๆ**: การ filter ที่ view นี้หมายความว่า **แถว "กำลังนิยม" (Trending, WYN-017) ก็จะไม่แสดงโพสต์ของผู้ถูก Mute ให้ผู้ Mute เห็นด้วย** เพราะ `fetchTrending()` query view เดียวกัน — Product spec เขียนแค่ "Home Feed" เฉยๆ ไม่ได้พูดถึง Trending ตรงๆ แต่ AC's regression bullet เขียนกำกับ "Home Feed/Trending/Club Feed" ไว้ด้วยกัน ซึ่งตีความได้ว่า Trending อยู่ในขอบเขตที่ Mute ควรครอบคลุมเช่นกัน (สมเหตุสมผลด้วย: จะแปลกถ้าโพสต์หายจาก feed หลักแต่โผล่ในแถว Trending ของหน้าเดียวกัน) — Trending **score/engagement count เองไม่เปลี่ยน** (คนอื่นที่ไม่ได้ mute ยัง count ปกติ ตาม Risk ที่ Product เขียนไว้) มีแค่ **การแสดงผลต่อผู้ที่ mute คนนั้นเท่านั้น**ที่ถูกกรองออก

**ทำไมไม่ชนกับบั๊ก RLS self-referential trap ของ WYN-027**: บั๊กเดิมเกิดจาก subquery ไปเช็คตาราง (`drops`) ที่ตัวมันเองมี RLS filter ด้วยเงื่อนไข**อื่น** (block) ที่ไม่ตรงกับสิ่งที่ subquery ต้องการเช็ค (author id) ทำให้ RLS ซ่อนแถวที่ subquery ต้องเห็น ในกรณีนี้ subquery เช็ค `exists (select 1 from mutes where muter_id = auth.uid() and muted_id = ...)` และ RLS ของ `mutes` เองก็คือ `using (auth.uid() = muter_id)` — **เงื่อนไขทั้งสองตรงกันเป๊ะ** (กำลังหาแถวที่ `muter_id = auth.uid()` อยู่แล้ว RLS ก็อนุญาตให้เห็นแถวที่ `muter_id = auth.uid()` พอดี) ไม่มีการซ่อนแถวที่ subquery ต้องการเห็น จึงไม่เข้าข่ายกับดักเดิม ใช้ inline subquery ธรรมดาได้โดยไม่ต้องมี helper function แบบ `drop_author_id`

Design Rules: ไม่ต้องมี UI ใหม่ใดๆ ในจุดนี้ — Home Feed screen (ทุกโหมด + Trending) ไม่มีโค้ด Flutter ต้องแก้เลยแม้แต่บรรทัดเดียว เพราะ filter อยู่ที่ view/SQL ล้วนๆ

---

## Screen 3: Settings → Safety — เพิ่ม section ที่ 2 (ไม่ใช่หน้าใหม่)

Purpose: ที่อยู่ของ Muted List — Product's Recommendation ข้อ 3 ระบุตรงๆ ให้รวม Blocked List + Muted List ไว้หน้าเดียวกัน (2 section) แทนแยกหน้า

User Flow: เปิด `SettingsScreen` (มีอยู่แล้วจาก WYN-027) → เห็น section "ความปลอดภัย" เดิมที่ตอนนี้มี **2 แถว** แทน 1 แถว: "บัญชีที่ถูกบล็อก" (เดิม) + "บัญชีที่ปิดเสียง" (ใหม่) → แตะ "บัญชีที่ปิดเสียง" → `MutedListScreen` เปิด (Screen 4)

Components: เพิ่ม `ListTile` ที่ 2 ใต้ "บัญชีที่ถูกบล็อก" เดิมใน section "ความปลอดภัย" เดียวกัน — `Icons.volume_off`, title "บัญชีที่ปิดเสียง", trailing `Icons.chevron_right` (component/style เดียวกับแถวเดิมทุกประการ)

Interactions: แตะ → เปิด `MutedListScreen`

Design Rules: **ไม่สร้าง section ใหม่** — อยู่ใน section "ความปลอดภัย" เดียวกับ Blocked List ตามที่ Product ระบุ (Block/Mute/Report ล้วนเป็นเรื่อง safety เดียวกันในสายตาผู้ใช้)

---

## Screen 4: `MutedListScreen`

Purpose: ดูรายชื่อ + Unmute ได้ — เป็นทางที่ 2 ของ Unmute (นอกจาก toggle ใน Profile More menu)

Components: reuse โครงสร้างแถวของ `FollowListScreen`/`BlockedListScreen` — **ต่างจาก `BlockedListScreen` ตรงที่แถว "เป็น tap target ไปโปรไฟล์ได้ปกติ"** (เหมือน `FollowListScreen` ไม่ใช่เหมือน `BlockedListScreen`) เพราะ Mute ไม่ได้จำกัดการเข้าถึงโปรไฟล์เลยตาม Requirement ("เข้าไปดู Profile ของผู้ถูก Mute โดยตรง → ยังเห็นโพสต์ปกติทุกอย่าง") ไม่มีเหตุผลด้าน UX ที่ต้องกันไม่ให้แตะแถวไปโปรไฟล์แบบที่ Block ตั้งใจกัน (Block กันเพราะการเห็นโปรไฟล์คนที่เพิ่ง block อาจรู้สึกเผชิญหน้า — Mute ไม่มีมิตินั้นเลย) — แต่ละแถวยังคงมีปุ่ม "เปิดเสียง" (`OutlinedButton` เล็ก ชิดขวา เหมือน Blocked List's "เลิกบล็อก") แยกจาก tap-แถว เพื่อไม่ให้ปุ่มกับการ navigate ชนกัน (mirror ปัญหาเดียวกับปุ่ม More บนการ์ดที่เคยแก้ใน WYN-026)

Interactions: แตะแถว (นอกปุ่ม) → เปิด `ViewProfileScreen` ของคนนั้น / แตะ "เปิดเสียง" → **ไม่มี dialog ยืนยัน** (ตาม Screen 1 — Unmute ยิ่งไม่มีความเสี่ยงกว่า Mute อีก) → toggle ทันที optimistic → แถวหายจาก list ทันที

States:
- Loading: skeleton/spinner ตอนโหลด list ครั้งแรก (pattern เดียวกับ `BlockedListScreen`)
- Empty: "ยังไม่มีบัญชีที่ปิดเสียง"
- Error: "โหลดรายชื่อไม่สำเร็จ" + ปุ่มลองใหม่

Responsive Behavior: infinite-scroll/pagination เดียวกับ `BlockedListScreen`/`FollowListScreen`

Accessibility: ปุ่ม "เปิดเสียง" มี `Semantics` label เต็ม "เปิดเสียง @username" / แถวทั้งแถวมี Semantics label แยกสำหรับ navigate ไปโปรไฟล์ (เหมือน `FollowListScreen` แถว)

Design Rules: ไม่มี bulk-unmute ในรอบนี้ (นอก scope เดียวกับเหตุผลของ `BlockedListScreen`)

---

## Screen 5: Interaction/Follow/Notification — ไม่มี UI ใหม่เลย (บันทึกไว้กันเข้าใจผิด)

Design Rules:
- Follow button: **ไม่มีการเปลี่ยนแปลงใดๆ** ในทุกจุดที่มีปุ่ม Follow (`DropDetailScreen`/`ViewProfileScreen`/`PopClipView`) — Mute relationship ไม่ทำให้ปุ่ม Follow เปลี่ยนสถานะเลยตาม Requirement ("Follow relationship ไม่เปลี่ยนแปลง") ต่างจาก Block ที่ Screen 8 ของ WYN-027 ต้องแทนที่ปุ่มด้วย banner
- Like/Comment: ไม่มีการเปลี่ยนแปลงใดๆ — ทำได้ปกติทั้งสองทิศทางเสมอ ไม่มี defense-in-depth ใดๆ ต้องเพิ่มแบบที่ Block ทำ (WYN-027 Screen 6) เพราะ Mute ไม่ใช่การจำกัด interaction เลย
- Mention: ไม่มีการเปลี่ยนแปลงใดๆ — resolve/notify ได้ปกติทุกประการ ต่างจาก Block's Screen 9 โดยสิ้นเชิง
- Notification: **ห้ามมี notification/สัญญาณใดๆ เกี่ยวกับการถูก mute เด็ดขาด** — ไม่มี `notify_*` trigger ใหม่ใดๆ ผูกกับตาราง `mutes` เลยแม้แต่ตัวเดียว (ต่างจาก `blocks`/`reports` ที่ก็ไม่มี notification เหมือนกันอยู่แล้ว แต่ประเด็นนี้สำคัญพอที่ Product เน้นย้ำแยกเป็นข้อ จึงบันทึกไว้ชัดในนี้ด้วย)
- ViewProfileScreen ของผู้ถูก Mute (มุมมองของผู้ Mute เอง): ไม่มี banner ใดๆ ต่างจาก Blocked persona (WYN-027 Screen 3) โดยสิ้นเชิง — หน้าตาเหมือนเปิดโปรไฟล์คนทั่วไปทุกประการ มีแค่ More menu ที่ label เป็น "เปิดเสียง" แทน "ปิดเสียง"

---

## Handoff

ส่งต่อ AI Coding ตามลำดับ (เสี่ยง regression ต่ำกว่า WYN-027 มากเพราะ scope แคบและจุดเดียว):

1. **Data layer**: ตาราง `mutes (muter_id, muted_id, created_at)` + primary key คู่ + `check` constraint กัน self-mute (`mutes_no_self_mute`, mirror `blocks_no_self_block`) + RLS: SELECT (`using auth.uid() = muter_id`, เห็นเฉพาะของตัวเอง เหมือน `blocks`), INSERT (`with check auth.uid() = muter_id`), DELETE (`using auth.uid() = muter_id`) — **ไม่ต้องมี RPC** เพราะไม่มี side-effect ต้องทำอะตอมมิก (ต่างจาก `block_user()`/`unblock_user()`) ใช้ direct table insert/delete จาก client ได้เลยผ่าน RLS เหมือน `follows`
2. แก้ `home_feed` view เพิ่มเงื่อนไข `not exists (select 1 from public.mutes where muter_id = auth.uid() and muted_id = <author_id>)` ในทั้งสองครึ่งของ UNION ALL (Drop และ Pop) — inline subquery ธรรมดาปลอดภัย ไม่ต้องมี helper function (ดูเหตุผลเต็มใน Screen 2)
3. Screen 1 (entry point toggle ใน `ViewProfileScreen`'s More menu) — เพิ่ม `_isMuted` state คู่กับ `_blockRelationship` ที่มีอยู่แล้ว โหลดพร้อมกัน
4. Screen 3-4 (Settings section ที่ 2 + `MutedListScreen`) — `MutedListScreen` โครงสร้างเกือบเหมือน `BlockedListScreen` เป๊ะ ยกเว้นแถว tap-to-profile ได้ (ดู Screen 4)

เก็บ regression test ให้ครบ โดยเฉพาะ AC สุดท้าย: Home Feed/Trending/Club Feed ของคู่ผู้ใช้ที่ไม่ได้ Mute กันต้องไม่กระทบ, Follow/Like/Comment/Mention ระหว่างคู่ที่ Mute กันอยู่ต้องยังทำงานปกติทุกทิศทาง (ตรงข้ามกับ WYN-027 test suite ที่ยืนยันสิ่งเหล่านี้ถูก**บล็อก** — WYN-028 ต้องยืนยันสิ่งเดียวกัน**ไม่ถูกบล็อก**), และ regression กับ WYN-027 เอง (คู่ที่ทั้ง Mute และ Block กันพร้อมกัน — Block ต้องยัง dominant คือเนื้อหาหายทุกที่ไม่ใช่แค่ Home Feed, ไม่ใช่ mute ไป "ผ่อน" ผล Block ลง) — ไม่แตะไฟล์ Flutter `pop_*.dart`/`PopClipView`/`HomePopCard` เลยเหมือนกฎเดิม (DS-008) เพราะการแก้ทั้งหมดอยู่ที่ `home_feed` view (SQL ล้วน) ไม่ใช่ไฟล์ Pop โดยตรง
