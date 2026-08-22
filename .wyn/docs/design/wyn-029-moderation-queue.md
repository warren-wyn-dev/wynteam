# Design Spec — WYN-029: Moderation Queue + Action

อ้างอิง Design System ที่อนุมัติแล้ว (ไม่คิดทิศทาง visual ใหม่): `.wyn/docs/design/ds-001-color-system.md` (Cyan เป็น accent ≤15% ของจอเท่านั้น, ห้ามใช้สีแดงกับปุ่มยืนยัน — ดูเหตุผลใน Screen 4), `.wyn/docs/design/ds-008-responsive-accessibility.md` (touch target ≥44×44, textScale 130%, ห้ามแตะไฟล์ `pop_*.dart`)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-029-moderation-queue.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `SettingsScreen` (WYN-027/028 — entry point ใหม่เพิ่มเป็น section ที่ 2), `ReportSheet`/`showReportSheet` (WYN-026 — โครง bottom sheet ที่มี category/detail/loading/error state ครบ), `block_dialogs.dart`'s `AlertDialog` (WYN-027 — ไม่ใช้สีแดงกับปุ่มยืนยัน), `BlockedListScreen`/`MutedListScreen`/`FollowListScreen` (โครงแถว list + pagination), `NotificationListScreen`/`WynNotification` (WYN-012/015/021 — โครง notification list ที่จะขยาย type ใหม่), `ViewProfileScreen._buildBlockedBanner` (WYN-027 — รูปแบบ banner ที่จะ reuse กับ Restrict), `AuthGate` (WYN-002 — จุดที่ต้องเพิ่ม gate ใหม่), `CreateDropScreen`/`DropDetailScreen`'s comment composer/`CreateClubScreen` (จุดที่ต้อง disable ปุ่มโพสต์เมื่อถูก Restrict)

## ภาพรวมแนวทาง: เครื่องมือภายในขั้นต่ำ ประกอบจาก pattern เดิมทั้งหมด ไม่ประดิษฐ์ของใหม่

Product's Recommendation ระบุตรงๆ ว่านี่คือเครื่องมือชั่วคราวที่จะถูกแทนที่ด้วย WYN Admin (Phase 7) — งานออกแบบรอบนี้จึงเป็นการ **ประกอบ pattern ที่อนุมัติแล้วทั้งหมดเข้าด้วยกัน** ไม่ใช่คิด visual ใหม่: bottom sheet ของ Action ใช้โครงเดียวกับ `ReportSheet` เป๊ะ, banner ของ Restrict ใช้โครงเดียวกับ Blocked banner ของ WYN-027 เป๊ะ, list ใช้โครงเดียวกับ `BlockedListScreen`/`NotificationListScreen`, entry point ต่อยอด `SettingsScreen` section ที่มีอยู่แล้ว

**สิ่งที่เป็น UI จริงมี 4 กลุ่ม**: (1) Moderation Queue (entry point + list + detail + 6-action confirm flow), (2) การแจ้งผลต่อผู้ถูกดำเนินการ (Warning/Remove Content ผ่านระบบ notification เดิม), (3) หน้าจอปิดกั้นตอน login (Suspend/Ban), (4) banner+ปุ่ม disabled ตอนพยายามโพสต์ (Restrict) — ไม่มีจุดใดต้องสร้าง visual language ใหม่

**ตัดสินใจเชิง scope ที่สำคัญ 3 ข้อ (บันทึกไว้ตรงๆ เพราะ Product spec ไม่ได้ระบุละเอียดถึงระดับนี้ — เป็นการตีความ HOW ภายใน WHAT ที่อนุมัติแล้ว ไม่ใช่การเปลี่ยน scope):**

1. **Remove Content ใช้กลไกเดียวกับ Warning** (ส่ง notification ระบบบอกเหตุผล) **แทนการสร้าง "grayed-out tile + dialog" ใหม่ในทุก grid/comment list ที่มีอยู่ (Drop grid, Pop grid, Club Post list, Comment list)** — เนื้อหาที่ถูกลบหายไปจากทุกคนแม้แต่เจ้าของเอง (เหมือนลบเองทุกประการ) เจ้าของรู้เหตุผลผ่าน notification แทนที่จะเห็น placeholder ค้างอยู่ในตำแหน่งเดิม เหตุผล: Requirement เขียนแค่ "ผู้เขียนเห็นว่าเนื้อหาถูกลบเพราะละเมิดกฎ" ซึ่ง notification ก็ทำให้ "เห็น" ได้ตรงตามตัวอักษร โดยไม่ต้องแตะ 4+ ไฟล์ grid/list ที่ต่างกันเพื่อเพิ่ม state ใหม่ที่ซับซ้อนกว่ามาก — ตรงกับ Product's Recommendation ที่ขอไม่ให้ over-invest
2. **Target type `club`**: 4 action ที่อิงบัญชี (Warning/Restrict/Suspend/Ban) กระทำต่อ **เจ้าของ Club (`owner_id`)** เพราะ Master Spec ไม่ได้แยก "บัญชี" ออกจาก Club ไว้ต่างหาก และ WYN-027's Report flow (Screen 7) ก็เคยตัดสินใจแบบเดียวกันมาก่อนแล้วว่า Club ไม่มี "ผู้แต่งเนื้อหา" แยกจาก owner — Remove Content ไม่แสดงเลยสำหรับ target นี้ (Product spec ระบุชัดว่าเฉพาะเนื้อหา ไม่ใช้กับ User/Club และ Club ทั้ง Club เองก็ไม่มีกลไก soft-delete ใดๆ ในระบบตอนนี้)
3. **ไม่มี claim/"reviewing" mechanic ในรอบนี้** — เปิดดู Report ไม่เปลี่ยน status เป็น `reviewing` เอง (Queue อ่าน `pending`/`reviewing` ปนกันเป็น list เดียวไม่แยก badge) เพราะ Product ระบุแค่ "FIFO อย่างง่าย ไม่ทำ priority scoring" และมี moderator ไม่กี่คนในรอบนี้ (Founder/ทีมภายใน) — ความเสี่ยงที่ moderator 2 คนดู report เดียวกันพร้อมกันมีน้อยและ RPC (Screen 4) ปฏิเสธการ action ซ้ำอยู่แล้วถ้าเกิดขึ้นจริง

---

## Screen 1: Entry Point — `SettingsScreen`, section ใหม่ "เครื่องมือผู้ดูแล"

Purpose: ทางเข้าเดียวสู่ Moderation Queue ที่ผู้ใช้ทั่วไปไม่มีทางเห็นแม้แต่ทางเข้า

User Flow: เปิดโปรไฟล์ตัวเอง → แตะปุ่มตั้งค่า (มีอยู่แล้ว) → `SettingsScreen` → ถ้า `platformRole != user` เห็น section ใหม่ "เครื่องมือผู้ดูแล" ต่อจาก section "ความปลอดภัย" เดิม มี 1 แถว "คิวตรวจสอบรายงาน" → แตะ → เปิด `ModerationQueueScreen`

Components:
- **`Profile` model ต้องมี field ใหม่ `platformRole`** (`user`/`moderator`/`admin`, default `user`) — `ProfileRepository.fetchProfile()` ต้อง select คอลัมน์ `platform_role` เพิ่ม (ปัจจุบัน select เจาะจงคอลัมน์อยู่แล้ว ไม่ใช่ `select('*')`)
- **ไม่ query เพิ่มสำหรับ Settings เอง** — `ViewProfileScreen._load()` fetch profile ตัวเองอยู่แล้วทุกครั้งที่เปิดหน้าโปรไฟล์ (`data.profile`) จึงส่ง `data.profile.platformRole` เข้า `SettingsScreen(platformRole: ...)` เป็น constructor param ตรงๆ แทนที่จะให้ `SettingsScreen` ยิง query ของตัวเอง — นอกจากประหยัด query แล้วยังเป็นเหตุผลด้าน security-in-depth ที่ดีกว่า: ค่าที่ใช้ตัดสินใจแสดงผลมาจาก row ที่ RLS ยืนยันแล้วว่าเป็นของ `auth.uid()` เอง ไม่มีทางส่ง userId อื่นเข้ามาแทนที่ได้จากทาง UI นี้
- `SettingsScreen` เปลี่ยนจาก `StatelessWidget` เป็นรับ `required PlatformRole platformRole` param ใหม่ — เพิ่ม section ที่ 2 (หัวข้อ "เครื่องมือผู้ดูแล" style เดียวกับ "ความปลอดภัย" — `titleSmall` สี `outline`) ตามด้วย `ListTile` เดียว: `Icons.shield_outlined`, title "คิวตรวจสอบรายงาน", trailing `Icons.chevron_right` — **แสดงเฉพาะเมื่อ `platformRole != PlatformRole.user`** (ครอบทั้ง section รวมหัวข้อ ไม่ใช่แค่ซ่อนแถว — ผู้ใช้ทั่วไปต้องไม่เห็นแม้แต่หัวข้อ section ว่างเปล่า)

Interactions: แตะแถว → เปิด `ModerationQueueScreen`

States: ไม่มี loading ใหม่ (ใช้ค่าที่ `ViewProfileScreen` fetch มาแล้ว เหมือนที่ section "ความปลอดภัย" เดิมไม่มี loading ของตัวเอง)

Design Rules: **ไม่ทำ UI ใดๆ ให้ผู้ใช้ตั้งค่า/ขอสิทธิ์ `platform_role` ของตัวเองหรือคนอื่นในแอปเลย** ตรงตาม Product spec ("ตั้งค่าได้เฉพาะทาง Supabase โดยตรง") — section นี้เป็น**ทางเข้า**เท่านั้น ไม่ใช่หน้าจัดการสิทธิ์

---

## Screen 2: `ModerationQueueScreen` — รายการ Report

Purpose: แสดง Report ที่ยังไม่ปิดเคส (`pending`/`reviewing`) เรียงเก่าไปใหม่ ให้ moderator ไล่ดูทีละอัน

Components: โครงแถวเดียวกับ `BlockedListScreen`/`NotificationListScreen` (padding, spacing, `RefreshIndicator`, infinite-scroll pagination pattern เดียวกันทุกประการ) แต่ **ไม่มี avatar** (แทนที่ด้วย `Icon` เล็กบอกประเภท target — `Icons.person_outline` user, `Icons.image_outlined` drop, `Icons.comment_outlined` drop_comment/club_post_comment, `Icons.groups_outlined` club, `Icons.article_outlined` club_post — วงกลม `surfaceContainerHigh` พื้นหลัง ไม่ใช้ Cyan เพราะไม่ใช่ brand-emphasis moment ตาม DS-001 ข้อ 6) แต่ละแถว 3 บรรทัด:
1. **Category · Target type** (`titleSmall`) เช่น "หลอกลวง (Scam) · โพสต์ Drop" — ใช้ `ReportCategory.label` เดิมจาก WYN-026 ตรงๆ, เพิ่ม `ReportTargetType.label` ใหม่ (Thai: "ผู้ใช้"/"โพสต์ Drop"/"คอมเมนต์ Drop"/"Club"/"โพสต์ Club"/"คอมเมนต์โพสต์ Club")
2. **สรุปเนื้อหาเป้าหมายแบบย่อ** (`bodyMedium`, 1 บรรทัด `overflow: ellipsis`) เช่น "@username" (user) / แคปชัน Drop ตัดสั้น (drop) / ข้อความคอมเมนต์ตัดสั้น (comment) / ชื่อ Club (club/club_post) — ถ้าเนื้อหาถูกลบไปแล้วก่อนหน้า (เช่นถูก Remove Content ไปแล้วจาก report อื่น หรือเจ้าของลบเอง) แสดง "(เนื้อหานี้ถูกลบไปแล้ว)" แทน ไม่ error
3. **รายละเอียดจากผู้รายงาน** (`bodySmall`, สี `onSurfaceVariant`, ตัดสั้น 1 บรรทัดถ้ามี) + **เวลาที่รายงาน** (`labelSmall`, `relativeTimeLabel` เดิมจาก WYN-012) ชิดขวาแบบ trailing เหมือน `NotificationListScreen`

**ไม่แสดงตัวตนผู้รายงานที่ใดในแถวเลย** ตรงตาม Requirement — field นี้ไม่ถูกดึงมาด้วยซ้ำในฝั่ง query (ดู Handoff)

**ไม่มี tap target ซ้อนในแถว** (ต่างจากที่คิดไว้ตอนแรกว่าควรมีลิงก์แยกไปเนื้อหาโดยตรงจากแถว) — **แถวทั้งแถวคือ 1 tap target เดียวเปิด `ModerationReportDetailScreen`** ลิงก์ไปเนื้อหาจริงอยู่ใน Detail screen แทน (Screen 3) เพื่อเลี่ยงปัญหา gesture ซ้อนกันในแถวที่มีข้อมูลแน่นอยู่แล้ว (บทเรียนเดียวกับที่ WYN-013 แก้เรื่อง tap-to-profile ชนกับ tap การ์ดเดิม) — Requirement ข้อ "ลิงก์เปิดดูเนื้อหา/โปรไฟล์จริงได้" ยังเป็นจริงอยู่ แค่อยู่ห่างออกไป 1 tap ไม่ใช่ inline บนแถว

States:
- Loading: `CircularProgressIndicator` กลางจอ (เหมือนทุก list ในแอป)
- Empty: `Icons.inbox_outlined` ขนาดใหญ่ + "ไม่มีรายงานที่รอตรวจสอบ" (เหมือนโครง empty state ของ `NotificationListScreen`)
- Error: "โหลดรายชื่อไม่สำเร็จ" + ปุ่มลองใหม่ (pattern มาตรฐาน)

Responsive/Accessibility: infinite-scroll เดียวกับทุก list, ทดสอบ textScale 130% ไม่ overflow (บรรทัด 2 ตัดด้วย ellipsis อยู่แล้วป้องกันเรื่องนี้ในระดับหนึ่ง), แต่ละแถวมี `Semantics` label รวม category+target type+summary+เวลา (excludeSemantics แบบเดียวกับแถวอื่นๆ ในแอป)

Design Rules: **ไม่ทำ badge แยกสถานะ `pending` vs `reviewing`** ตามการตัดสินใจ scope ข้อ 3 ด้านบน — ทุกแถวหน้าตาเหมือนกันหมด เรียงตามเวลาเก่าไปใหม่เท่านั้น

---

## Screen 3: `ModerationReportDetailScreen`

Purpose: ให้ moderator เห็นบริบทเต็มก่อนตัดสินใจ Action + ลิงก์ไปดูเนื้อหา/โปรไฟล์จริง

Components (บนลงล่าง):
1. **การ์ดลิงก์เนื้อหา** — `Container` พื้น `surfaceContainer` (`radiusMd`) กดได้ทั้งใบ: icon ประเภท target (เดียวกับ Screen 2) + label เต็ม (เช่น "โพสต์ Drop ของ @username" — ดึง username เจ้าของเนื้อหามาแสดงด้วยเสมอสำหรับ target ที่เป็นเนื้อหา ไม่ใช่แค่ user target) + `Icons.chevron_right` ชิดขวา — แตะ → เปิดหน้าจริง:
   - `user` → `ViewProfileScreen(userId: target_id)`
   - `drop` → `DropDetailScreen` (fetch by id ก่อนเปิด เหมือน `NotificationListScreen._openDrop`)
   - `drop_comment` → เปิด **`DropDetailScreen` ของ Drop ต้นทาง** (resolve `drop_id` จาก comment ก่อน — คอมเมนต์เองไม่มีหน้าเดี่ยวในแอป เหมือนที่ `NotificationListScreen` ไม่เคยต้องเปิดคอมเมนต์เดี่ยวมาก่อน)
   - `club` → `ClubPage(clubId: target_id)`
   - `club_post` → `ClubPostDetailScreen` (fetch by id)
   - `club_post_comment` → เปิด **`ClubPostDetailScreen` ของโพสต์ต้นทาง** (resolve `club_post_id` จาก comment ก่อน เหมือน `drop_comment`)
   - ถ้าเนื้อหาถูกลบไปแล้ว → SnackBar เดียวกับที่ `NotificationListScreen` ใช้อยู่แล้ว ("Drop นี้ถูกลบไปแล้ว"/"โพสต์นี้ถูกลบไปแล้ว") ไม่เปิดหน้าเปล่า
2. **Category** (`titleMedium`) + **รายละเอียดจากผู้รายงาน** เต็มไม่ตัด (`bodyMedium`, ถ้าไม่มีแสดง "ไม่มีรายละเอียดเพิ่มเติม" สี `outline`) + **เวลาที่รายงาน** (`bodySmall` สี `outline`)
3. **รายการปุ่ม Action** เรียงจากผลกระทบน้อยไปมาก (ตาม severity convention เดียวกับ WYN-026/027's More menu): No Action → Warning → Remove Content → Restrict → Suspend → Ban — `OutlinedButton` เต็มความกว้าง เรียงต่อกัน `space2` แต่ละปุ่ม สีเดียวกันหมด (neutral, **ไม่ใช้สีแดงแม้กับ Ban** — เหตุผลใน Screen 4) แต่ละปุ่มเปิด `ModerationActionSheet` (Screen 4) พร้อม action ที่เลือกไว้แล้ว
   - **"Remove Content" ไม่แสดงเลยเมื่อ target type เป็น `user` หรือ `club`** (5 ปุ่มแทน 6 — ตรงตาม Product spec ที่ระบุว่าใช้เฉพาะ target ที่เป็นเนื้อหา)

Interactions: กดปุ่ม Action ใดๆ → เปิด `ModerationActionSheet` → ยืนยันสำเร็จ → sheet ปิด + Detail screen ปิดตัวเอง (`Navigator.pop(true)`) กลับสู่ Queue พร้อม SnackBar "ดำเนินการแล้ว: {action label}" → Queue เอารายการนั้นออกจาก list ทันที (optimistic, ตาม pattern `BlockedListScreen._unblock`)

States: โหลด report detail ล้มเหลว (เช่น report ถูกดำเนินการไปแล้วโดย moderator คนอื่นระหว่างที่เปิดหน้าอยู่) → แสดง "รายงานนี้ถูกดำเนินการไปแล้ว" กลางจอ + ปุ่ม "กลับไปที่คิว" (`Navigator.pop(true)` ให้ Queue เอาแถวออกเหมือนกัน)

Accessibility: การ์ดลิงก์เนื้อหามี `Semantics` label เต็ม, ปุ่ม Action แต่ละปุ่มมี label ชัดเจน (เช่น "ดำเนินการ: คำเตือน")

Design Rules: หน้านี้เป็น **read-mostly** ไม่มี inline edit ใดๆ — การเปลี่ยนแปลงทั้งหมดเกิดผ่าน `ModerationActionSheet` เท่านั้น ไม่มีทางลัดกดปุ่มแล้วยืนยันทันทีแบบไม่มี sheet (ทุก Action ต้องผ่านหน้ากรอกเหตุผลเสมอตาม Requirement)

---

## Screen 4: `ModerationActionSheet` — reusable confirm flow ของทั้ง 6 Action

Purpose: เก็บเหตุผล (บังคับ) + ระยะเวลา (เฉพาะ Restrict/Suspend) ก่อนยืนยัน — **เป็น component เดียวใช้ซ้ำทั้ง 6 action** ไม่ใช่ 6 หน้าจอแยก

**ทำไม reuse เป็น component เดียวได้ (ตอบคำถามที่โจทย์ถาม)**: โครงสร้างข้อมูลที่ต้องเก็บต่างกันแค่ "มี duration picker หรือไม่" (Restrict/Suspend มี, อีก 4 action ไม่มี) — ส่วนที่เหลือ (header แสดงชื่อ action, ช่องเหตุผลบังคับ, ปุ่มยืนยันพร้อม loading/error state) เหมือนกันทุก action ทุกประการ ตรงกับรูปแบบ bottom sheet ที่ `ReportSheet` (WYN-026) วางไว้แล้วเป๊ะ (sheet เดียว parameterize ด้วยสิ่งที่เลือกมาก่อนหน้า) จึง **reuse โครง `ReportSheet` ทั้งดุ้น** แค่เปลี่ยนเนื้อหาฟอร์มด้านในและพารามิเตอร์ที่ส่งเข้ามา — ไม่มีเหตุผลด้าน UX ที่ต้องแยกเป็น 6 หน้าจอ เพราะ mental model ของ moderator คือ "เลือก action จาก Screen 3 มาแล้ว ตอนนี้แค่กรอกรายละเอียดที่ต้องมี"

Components:
- `showModalBottomSheet` โครงเดียวกับ `ReportSheet` ทุกประการ (handle bar, header, ปุ่มปิด X, `Flexible` + `SingleChildScrollView`)
- หัวข้อ (`titleMedium`): ชื่อ action ที่เลือก เช่น "ยืนยัน: คำเตือน (Warning)" / "ยืนยัน: แบนถาวร (Ban)"
- **Duration selector** (เฉพาะ Restrict/Suspend เท่านั้น) — `Wrap` ของ `ChoiceChip` 3 อัน: "1 วัน" / "3 วัน" / "7 วัน" เลือกได้ 1 อัน ไม่มีค่าเริ่มต้น (ต้องเลือกเองก่อนกดยืนยันได้) — label หัวข้อเหนือแถวชิป: "ระยะเวลา"
- **ช่องเหตุผล** (`TextField` multiline, บังคับกรอกเสมอทั้ง 6 action — ต่างจาก `ReportSheet` ที่บังคับเฉพาะ category "Other") label "เหตุผล (จำเป็น)" ตัวหนา — ใต้ช่องมีข้อความช่วยอธิบายที่**เปลี่ยนตาม action** เพื่อกันโมเดอเรเตอร์เข้าใจผิดว่านี่คือบันทึกภายในล้วนๆ:
  - No Action: "ปิดเคสนี้โดยไม่มีผลต่อผู้ใช้ เหตุผลนี้เก็บเป็นบันทึกภายในเท่านั้น"
  - Warning/Remove Content/Restrict/Suspend/Ban: "ผู้ใช้จะเห็นข้อความนี้โดยตรง เขียนให้ผู้ใช้เข้าใจได้"
  - Ban เพิ่มบรรทัดเตือนพิเศษสีเดียวกับ helper text (ไม่ใช่สีแดง แค่ตัวหนา): "แบนถาวร — ยกเลิกได้เฉพาะทาง Database โดย admin เท่านั้นในรอบนี้ (ยังไม่มีปุ่ม Unban ในแอป)" — ป้องกันการกดพลาดโดยไม่รู้ว่าย้อนกลับไม่ได้จาก UI
- ปุ่ม "ยืนยัน" เต็มความกว้าง — disabled จนกว่า: เหตุผลไม่ว่าง (ทุก action) **และ** เลือก duration แล้ว (เฉพาะ Restrict/Suspend)

Interactions: กดยืนยัน → ปุ่มแสดง loading, ฟอร์ม disabled (เหมือน `ReportSheet._submit`) → สำเร็จ → sheet ปิด (`Navigator.pop(true)`)

States: Loading/Error เหมือน `ReportSheet` เป๊ะ (inline error สีแดงเหนือปุ่ม "ดำเนินการไม่สำเร็จ ลองอีกครั้ง", sheet ไม่ปิดเอง) — Error กรณี "report ถูกดำเนินการไปแล้วโดยคนอื่น" ให้ปิด sheet เองพร้อม pop คืนค่าพิเศษที่บอก Detail screen ให้กลับไป Queue ทันที (ไม่ต้องให้ผู้ใช้กดปุ่มซ้ำ)

Design Rules: **ปุ่มยืนยันไม่ใช้สีแดงแม้แต่ Ban** — สืบทอด Design Rule ของ `confirmBlock`/`confirmDeletePost`/`ClubPage._confirmLeave` ที่ไม่เคยใช้สีแดงกับปุ่มยืนยัน action ที่มีผลกระทบตลอดทั้งแอป (WYN-027 Screen 2 ระบุไว้ตรงๆ ว่า "ห้ามคิดทิศทางใหม่เฉพาะจุดนี้") — ความรุนแรงของ Ban สื่อผ่านข้อความเตือนในฟอร์ม (ด้านบน) ไม่ใช่สี

---

## Screen 5: ผลลัพธ์ที่ผู้ใช้เห็น — Warning / Remove Content (ผ่านระบบ Notification เดิม)

Purpose: ทำให้ Requirement "Warning ส่ง notification ถึงผู้ถูก Report" และ "Remove Content ผู้เขียนเห็นว่าเนื้อหาถูกลบเพราะละเมิดกฎ" เป็นจริง โดยต่อยอดระบบ notification ที่มีอยู่แล้ว (WYN-012) ไม่สร้างระบบแจ้งเตือนใหม่

Components:
- เพิ่ม `NotificationType` ใหม่ 2 ค่า: `moderationWarning` (`moderation_warning`), `moderationContentRemoved` (`moderation_content_removed`)
- ข้อความ (`_messageFor` เดิมของ `NotificationListScreen`):
  - `moderationWarning` → "คุณได้รับคำเตือนจากทีมงาน WYN: {reason}"
  - `moderationContentRemoved` → "เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN — เหตุผล: {reason}"
- **ซ่อนตัวตนผู้ตรวจสอบ (reviewer) เสมอ — สำคัญเทียบเท่าการซ่อนตัวตนผู้รายงานใน WYN-026**: แถวของ 2 type นี้ **ไม่ใช้ `AvatarCircle(imageUrl: actorAvatarUrl, ...)` ของ actor จริง** (แม้ใน DB `actor_id` จะเก็บ `reviewer_id` จริงไว้เพื่อ audit trail ก็ตาม) — แทนที่ด้วยไอคอนระบบคงที่ (วงกลม `surfaceContainerHigh` + `Icons.shield_outlined` สี `onSurfaceVariant`, **ไม่ใช้ Cyan** เพราะไม่ใช่ brand-emphasis moment) และข้อความไม่อ้างชื่อ/username ของ reviewer เลย (ใช้คำว่า "ทีมงาน WYN" ตายตัว ไม่ใช่ `actorNameOrUsername`) — เหตุผล: ผู้ตรวจสอบอาจเจอ retaliation จากผู้ถูกดำเนินการได้เหมือนที่ WYN-026 ป้องกัน retaliation ต่อผู้รายงานไว้แล้ว หลักการเดียวกัน คนละทิศทาง
- ข้อความยาวได้เต็มความยาวจริงของ `reason` (แถวเดิมของ `NotificationListScreen` ไม่มี `maxLines` อยู่แล้ว จึง wrap เต็มโดยไม่ต้องเพิ่ม dialog แยกแสดงข้อความเต็ม)

Interactions: แตะแถว 2 type นี้ → **ไม่ navigate ไปไหน** (no-op) — Warning ไม่มีเนื้อหาให้เปิด (เป็นคำเตือนต่อบัญชี ไม่ผูกกับ content เดียว), Remove Content เนื้อหาที่อ้างถึงถูกลบไปแล้วจริง ไม่มีอะไรให้เปิด (ต่างจาก type อื่นที่กด mention/like แล้วเปิด Drop/Club Post ได้ปกติ)

Design Rules: **ไม่มี notification ใหม่สำหรับ Restrict/Suspend/Ban/No Action** — ตาม Requirement ที่ระบุกลไกบังคับใช้ของ 3 อย่างแรกไว้ชัดเจนแล้วว่าอยู่ที่หน้า login/ปุ่มโพสต์ ไม่ใช่ notification (Screen 6-7) และ No Action ไม่มีผลใดๆ ต่อผู้ใช้อยู่แล้วตามนิยาม

---

## Screen 6: Suspend/Ban — ปิดกั้นตอน Login + `AccountRestrictedScreen`

Purpose: ให้ Suspend/Ban "ไม่ปล่อยเข้าแอป" จริง ทั้งตอน login ใหม่และตอนที่มีเซสชันค้างอยู่ก่อนหน้า

User Flow (login ใหม่): กรอก OTP/OAuth สำเร็จ → Supabase auth ออก session จริง → `AuthGate` ตรวจ session ≠ null → **ตรวจสถานะ moderation ก่อน** (ก่อนเช็ค `hasUsername` ด้วยซ้ำ เพราะเป็น gate ที่แรงกว่า) → พบว่า suspended/banned อยู่ (และยังไม่หมดเขต) → sign out ทันที (background, best-effort เหมือน `_signOut`'s push-token deregistration) → แสดง `AccountRestrictedScreen` พร้อมเหตุผล/กำหนดเวลา → ผู้ใช้กด "ตกลง" → กลับสู่ `WelcomeScreen`

**กับดักที่ต้องระวัง (บันทึกไว้ตรงๆ เพราะเป็นจุดพังง่ายที่สุดของ flow นี้)**: `AuthGate.build()` ปัจจุบันเป็น `StreamBuilder<AuthState>` ล้วนๆ — ถ้า sign-out เกิดขึ้นแล้วปล่อยให้ `build()` อ่านค่า session จาก stream ตรงๆ เหมือนเดิม พอ sign-out เสร็จ stream จะยิง event `signedOut` ทันที ทำให้ `session == null` และ `build()` เด้งไป `WelcomeScreen` **ก่อน**ที่ผู้ใช้จะทันอ่านข้อความเลย (เพราะ `AuthGate`'s auth-listener เดิมก็ทำ `popUntil isFirst` อยู่แล้วเมื่อ signedOut) — ทางแก้: การพบว่า suspended/banned ต้องเก็บเป็น **local state ของ `_AuthGateState`** (เช่น `_blockedInfo` ที่ตั้งค่าด้วย `setState` แยกจาก stream) และ `build()` ต้องเช็ค local state นี้**ก่อน**เช็ค session จาก stream เสมอ — เมื่อ `_blockedInfo != null` ให้ render `AccountRestrictedScreen` ค้างไว้แบบนั้นไม่ว่า session จะเปลี่ยนสถานะอย่างไรก็ตาม จนกว่าผู้ใช้จะกด "ตกลง" เอง (ซึ่งค่อย `setState(() => _blockedInfo = null)` ให้ build() กลับไปอ่าน stream ตามปกติ)

User Flow (เซสชันค้างอยู่ก่อนหน้า ถูก Suspend/Ban ระหว่างใช้งาน): Product's Risk ยอมรับว่า JWT ที่ออกไปแล้วยังใช้ได้จนกว่าจะหมดอายุ/refresh เว้นแต่ระบบ invalidate เอง — **แนะนำ (ไม่ใช่ mandate สถาปัตยกรรมใหม่ เพราะเป็นรายละเอียด implementation ของ AI Coding)**: ตอนยืนยัน Suspend/Ban ใน `ModerationActionSheet` (Screen 4) ให้ Coding เรียกกลไก invalidate session ของเป้าหมายจริงร่วมด้วย (เช่นผ่าน security-definer RPC/Edge Function ที่เรียก Supabase Admin API `auth.admin.signOut(userId, scope: 'others')` — ต้องใช้ service role จึงทำได้แค่ backend ไม่ใช่ client) เป็นกลไกหลัก + AuthGate-level check (ข้างต้น) เป็น safety net ที่ทำงานแน่นอนเมื่อไหร่ก็ตามที่ app ถูกเปิดใหม่/กลับมา foreground แม้กลไกหลักจะพลาดไป — ประกาศไว้ตรงๆ ว่านี่ไม่ใช่ "instant" 100% ถ้า Coding เลือกไม่ทำกลไกหลัก แต่ก็ไม่เคยปล่อยให้ผู้ใช้ที่ session หมดอายุ/เปิดแอปใหม่หลุดผ่านไปได้เลย

Components — `AccountRestrictedScreen` (ใหม่, อยู่ใน `app/lib/features/auth/presentation/`):
- `Scaffold` เรียบ ไม่มี AppBar action ใดๆ (ไม่ใช่หน้าที่ควร back ได้ตามปกติ)
- Icon กลางจอ (`Icons.gpp_bad_outlined`, ขนาดใหญ่, สี `onSurfaceVariant` — ไม่ใช้สี error/แดงเพราะยังคงกติกาเดิม "ไม่ใช้สีแดงกับปุ่ม/สถานะที่ไม่ใช่ semantic error ของระบบจริงๆ"... แต่กรณีนี้เป็นสถานะที่ระบบ**ควร**สื่อว่าเป็นเรื่องจริงจัง จึงพิจารณาแยก: ใช้ **สี `error` ได้เฉพาะจุดนี้** เพราะเป็น semantic status สื่อความร้ายแรงจริง (เทียบเท่าข้อความ error อื่นๆ ในแอปที่ใช้สี error token อยู่แล้วตาม DS-001 ข้อ 4 "สีสถานะไม่ประดิษฐ์ใหม่" — สถานะบัญชีถูกระงับเข้าข่าย error state ของระบบ ไม่ใช่ "ปุ่มยืนยัน action" แบบที่กติกาห้ามสีแดงพูดถึง)
- หัวข้อ (`headlineSmall`): "บัญชีของคุณถูกระงับชั่วคราว" (Suspend) / "บัญชีของคุณถูกระงับถาวร" (Ban)
- เหตุผล (`bodyLarge`): "เหตุผล: {reason}" — ดึงจาก `moderation_actions` แถวล่าสุดที่เป็น suspend/ban ต่อบัญชีนี้
- **Suspend เท่านั้น**: บรรทัดเพิ่ม "ระงับถึงวันที่ {dd/MM/yyyy} (อีก {N} วัน)" + "เมื่อครบกำหนดคุณจะกลับมาใช้งานได้ตามปกติ"
- **Ban เท่านั้น**: "การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้" (ไม่สัญญาช่องทาง/เวลาที่ยังไม่มีจริง — ตรงตามกติกาความซื่อตรงที่ WYN-027 Screen 9 วางไว้)
- ปุ่ม "ตกลง" (`FilledButton`) — เคลียร์ local blocked-state (ด้านบน) กลับสู่ `WelcomeScreen`

Design Rules: หน้านี้ไม่มีทางกด "ย้อนกลับ"/"ปิด" แบบอื่นนอกจากปุ่ม "ตกลง" ที่ตั้งใจให้เป็นทางเดียว (ไม่ทำ `WillPopScope` ให้ปุ่ม back ของระบบข้ามหน้านี้ไปได้เฉยๆ)

---

## Screen 7: Restrict — ปุ่มโพสต์ถูกปิดใช้งาน + คำอธิบาย

Purpose: ทำให้ Restrict บล็อกเฉพาะการโพสต์ Drop/Comment/สร้าง Club จริง โดย Login/ดู/Like/Follow ยังปกติทุกประการ

Components — widget ใหม่ที่ใช้ร่วมกัน `RestrictionBanner` (อยู่ใน `app/lib/core/widgets/` เหมือน `confirm_delete_dialog.dart` ที่ถูกย้ายมาไว้ตรงนี้ตอน WYN-007 เพราะ Drop/Club ใช้ร่วมกัน):
- **Reuse โครง visual เดียวกับ `ViewProfileScreen._buildBlockedBanner` เป๊ะ** (Container พื้น `surfaceContainer`, `radiusMd`, icon + ข้อความกลาง) ไม่ใช่ของใหม่ — icon `Icons.lock_clock_outlined`
- ข้อความ: "คุณถูกจำกัดการโพสต์ชั่วคราวจนถึงวันที่ {dd/MM/yyyy} (อีก {N} วัน) เนื่องจาก: {reason}"

จุดที่ต้องแทรก banner นี้ + disable ปุ่มหลัก (ตรวจสถานะครั้งเดียวตอน `initState` ของแต่ละหน้า เหมือน pattern `_isFollowing`/`_isMuted` ที่โหลดครั้งเดียวไม่ re-poll):
1. **`CreateDropScreen`**: banner เหนือส่วนเลือกรูป, ปุ่ม "แชร์" ปิดใช้งานเพิ่มเติมจากเงื่อนไข `_canShare` เดิม (`!_isSharing && !_isCropping && _imageBytes != null && !_isRestricted`)
2. **Comment composer ของ `DropDetailScreen`** และ **Comment composer ของ `ClubPostDetailScreen`**: banner เหนือแถว TextField+ปุ่มส่ง, ปุ่มส่งปิดใช้งานเพิ่มเงื่อนไขเดียวกัน
3. **`CreateClubScreen`**: banner เหนือฟอร์ม, ปุ่ม "สร้าง Club" ปิดใช้งานเพิ่มเงื่อนไขเดียวกัน

**ไม่แตะ Pop** — Product spec เขียนแค่ "Drop/Comment (ไม่ระบุ Pop)/Club" และ Pop ถูกระงับการพัฒนาไว้ตาม `.wyn/company/DECISIONS.md` (2026-08-14)/DS-008 — **ไม่เพิ่ม Restrict enforcement ใดๆ ในไฟล์ `pop_*.dart`/`PopClipView` เลยในรอบนี้** ตรงตามกติกาเดิมที่ WYN-026/027 ก็ยึดถือมาตลอด (เก็บเป็น known gap รอ Pop ถูกปลดล็อกพัฒนาใหม่ในอนาคต เหมือนที่ DS-008 บันทึกไว้กับ touch-target 2 จุดของ Pop)

States: ถ้าระยะเวลาหมดเขตระหว่างที่ผู้ใช้ค้างอยู่ในหน้านั้นพอดี (edge case ต่ำมาก) — ตรวจสถานะแค่ตอน initState เหมือนที่ระบุไว้ข้างบน ไม่ re-poll แบบ real-time (ยอมรับ trade-off เดียวกับที่ WYN-012's badge ก็ไม่ re-poll ระหว่างอยู่ในหน้าเดิม) ผู้ใช้แค่ต้องออกแล้วกลับเข้าหน้าใหม่ถ้าหมดเขตพอดีตอนนั้น — ไม่ใช่บั๊ก เป็นการตัดสินใจ scope ขั้นต่ำ

Accessibility: `Semantics` label ของปุ่มที่ถูก disable ต้องบอกเหตุผล ไม่ใช่แค่ "ปิดใช้งาน" เฉยๆ (เช่น "แชร์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว")

---

## Screen 8: บันทึกเรื่อง Enforcement/Data layer (ไม่ใช่ UI ใหม่ — บันทึกไว้กันเข้าใจผิด)

Purpose: ยืนยันชัดเจนว่า 2 เรื่องนี้**ไม่มี** UI ใหม่ แต่ต้องบังคับใช้จริงที่ RLS/RPC (ตรงตาม Product's Risk ที่เตือนไว้แล้ว)

Design Rules:
- **`moderation_actions` (หรือชื่อเทียบเท่าที่ Coding เลือก) ต้องไม่เปิดให้ query กว้างแบบเดียวกับ `profiles`** — ต้องเห็นได้เฉพาะ (ก) reviewer/moderator/admin เอง (สำหรับ Queue/audit) และ (ข) เจ้าของบัญชีที่ถูกกระทำเห็น**สถานะปัจจุบันของตัวเอง**ได้ (สำหรับ Screen 6/7) **ห้ามเปิดให้ผู้ใช้คนอื่นดูเหตุผล/ประวัติการถูกดำเนินการของคนอื่นได้เด็ดขาด** — เหตุผลของการ suspend/ban/restrict คนหนึ่งเป็นข้อมูลอ่อนไหวเทียบเท่าที่ต้องปกป้องเหมือนตัวตนผู้รายงานใน WYN-026 คนละทิศทาง (ป้องกันการเปิดเผยว่าใครเคยทำผิดกฎอะไรให้คนอื่นสอดรู้)
- **แนะนำ RPC เดียวที่ทั้ง Screen 6 (login check) และ Screen 7 (restrict check) เรียกใช้ร่วมกัน** (เช่น `get_my_moderation_status()`, security-definer, คืนสถานะปัจจุบันของ `auth.uid()` เองเท่านั้น) แทนการ query ตารางตรงๆ จากทั้งสองจุดแยกกัน — ลดโอกาส logic ไม่ตรงกันระหว่าง 2 จุดที่ต้องตัดสิน "ตอนนี้ถูกจำกัดอยู่ไหม" เหมือนกันทุกประการ
- **Remove Content ต้องบังคับใช้ที่ RLS SELECT ของ `drops`/`drop_comments`/`club_posts`/`club_post_comments`** (กรองแถวที่ถูก moderation-remove ออกจากทุกคนรวมถึงเจ้าของเอง — ดูเหตุผลที่ Screen 5 เลือก mechanism นี้แทน grayed-out tile) **ไม่ใช่แค่ซ่อนที่ฝั่ง Dart** — มิฉะนั้นเนื้อหาที่ถูกลบยังเรียกดูตรงๆ ผ่าน id ได้อยู่
- **Restrict/Suspend ต้องบังคับใช้ที่ RLS INSERT ของ `drops`/`drop_comments`/`club_posts`/`club_post_comments`/`clubs` และตอน login** ไม่ใช่แค่ disable ปุ่มใน Screen 7 (Product's Risk ย้ำไว้แล้วว่าถ้าจำกัดแค่ฝั่ง UI ผู้ใช้ยังเรียก Supabase API ตรงได้) — ต้อง auto-expire แบบ on-read/on-write (เทียบ `expires_at < now()` ทุกจุดที่ enforce) ไม่พึ่ง batch job
- **ไม่มี UI ให้ Unban ในรอบนี้** (ตรงตาม Product spec ที่ไม่ได้ขอ และสอดคล้องกับที่ `platform_role` เองก็ไม่มี UI จัดการในรอบนี้เหมือนกัน) — ต้องทำผ่าน DB โดยตรงเท่านั้น

---

## Handoff

ส่งต่อ AI Coding ตามลำดับที่แนะนำ (data layer + security ก่อนเสมอ ตาม pattern ของ WYN-026/027/028):

1. **`platform_role` column บน `profiles`** (`text check in ('user','moderator','admin') default 'user'`) — **ไม่มี insert/update policy ใดๆ ให้ client แก้คอลัมน์นี้เลย** (ตั้งค่าได้ทาง Supabase Dashboard/SQL โดย Founder เท่านั้นตาม Product spec) — เพิ่ม field `platformRole` เข้า `Profile` model + `ProfileRepository.fetchProfile()`'s select list
2. **`reports` เพิ่ม RLS SELECT ใหม่ให้ moderator/admin เห็น queue ได้** (นอกเหนือจาก policy เดิมที่จำกัดแค่ reporter เห็นของตัวเอง) — ต้องยังคง**ไม่มีคอลัมน์/ทาง query ใดที่เปิดเผย `reporter_id` ให้ moderator เห็นชื่อผู้รายงาน** (Requirement ยืนยันซ้ำว่าแม้แต่ทีม moderation ก็ไม่ควรเห็นตัวตนผู้รายงานตามที่ WYN-026 ตั้งใจไว้แต่ต้น — ถ้าตีความว่า moderator ควรเห็นเพื่อ audit ภายใน ให้ยกกลับมาถาม Founder ก่อนตัดสินเอง เพราะ WYN-026's Requirement เขียนไว้ค่อนข้างเด็ดขาด)
3. **`moderation_actions` table** (`id, report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id, created_at`) + RLS ตาม Screen 8 (ไม่เปิดกว้าง) + **RPC `apply_moderation_action(report_id, action_type, reason, duration_days)`** (security-definer, mirror `submit_report()`'s pattern): validate `auth.uid()`'s `platform_role != 'user'` ก่อนทำอะไรทั้งสิ้น (ปิดช่องโหว่ privilege escalation ตาม Product's Risk ข้อ 1), resolve `target_user_id` จาก `reports.target_type/target_id` ตามกฎ Screen 3/ภาพรวม (user→ตัวเอง, content→author, club→owner_id), เปลี่ยน `reports.status` เป็น `actioned`/`dismissed`, insert แถว `moderation_actions`, และทำผลจริงตาม action (soft-delete content สำหรับ Remove Content, insert notification สำหรับ Warning/Remove Content, ตั้ง `expires_at` สำหรับ Restrict/Suspend, ตั้ง permanent flag สำหรับ Ban)
4. **`get_my_moderation_status()` RPC** (Screen 8) ที่ Screen 6 (AuthGate)/Screen 7 (Restrict banners) เรียกใช้ร่วมกัน
5. **RLS enforcement**: SELECT filter ของเนื้อหาที่ถูก moderation-remove, INSERT filter ของ Drop/Comment/Club ใหม่เมื่อ Restrict/Suspend ยังไม่หมดเขต, login-time check (Supabase Auth hook หรือ AuthGate-level RPC call ก่อนแสดง RootShell)
6. Screen 1 (Settings entry point) → Screen 2-4 (Queue list + Detail + Action sheet) → Screen 5 (Notification type ใหม่ 2 ค่า) → Screen 6 (`AccountRestrictedScreen` + AuthGate local-state gate — **ระวังกับดัก StreamBuilder ที่ระบุไว้ใน Screen 6 ให้ดี เขียน regression test ยืนยันว่าข้อความไม่หายไปทันทีหลัง sign-out**) → Screen 7 (`RestrictionBanner` + จุดแทรก 3 จุด)

เก็บ regression test ให้ครบ โดยเฉพาะ: บัญชี `platform_role = user` ปกติต้องไม่เห็น Settings section ใหม่เลย, เนื้อหาที่ยังไม่ถูก Remove Content ต้องไม่หายไปจากที่ไหน (regression กับ Drop/Pop/Club feed เดิมทั้งหมด), คู่ที่ไม่เกี่ยวข้องกับ Restrict/Suspend/Ban ใดๆ ต้องโพสต์/login ได้ปกติทุกประการ, และ **Pop ต้องไม่ถูกแตะไฟล์ใดเลยแม้แต่บรรทัดเดียว** ตามกติกาเดิม

**สิ่งที่ควรพิจารณาถาม Founder ก่อนเริ่ม (ไม่ใช่ Founder-authority ตาม RULES.md แต่เป็นจุดที่ Design ตีความเองแล้วอาจผิดเจตนา ควรยืนยันสั้นๆ ก่อน Coding เริ่ม)**:
- ข้อ 2 ด้านบน (reporter identity ให้ moderator เห็นได้หรือไม่)
- การตีความ `club` target ว่า Warning/Restrict/Suspend/Ban กระทำต่อ owner (ภาพรวมข้อ 2)
- กลไก Remove Content ใช้ notification แทน grayed-out tile (ภาพรวมข้อ 1)

ทั้ง 3 ข้อเป็นการตีความ HOW ภายใน WHAT ที่ Founder อนุมัติแล้ว ไม่ใช่การเปลี่ยนสถาปัตยกรรม/ความปลอดภัย/วิสัยทัศน์ตามนิยามของ RULES.md จึงไม่ใช่ APPROVAL_REQUIRED แต่แนะนำให้ AI Coding ยืนยันสั้นๆ กับ Founder ก่อนเริ่ม (หรือดำเนินการตามที่ Design ตัดสินใจไว้นี้ได้เลยถ้า Founder ไม่ทักท้วง เพราะเป็นค่าเริ่มต้นที่สมเหตุสมผลและย้อนกลับแก้ได้ในอนาคตโดยไม่กระทบโครงสร้างหลัก)

Handoff: AI Coding — เริ่มจาก data layer (ข้อ 1-5 ด้านบน) ตามลำดับที่แนะนำ
