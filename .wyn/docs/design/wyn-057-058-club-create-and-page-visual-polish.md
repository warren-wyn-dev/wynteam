# Design Spec — WYN-057/058: Create Club + Club Page — Visual Polish (Founder follow-up, 2026-08-24)

> โดย AI Design — 2026-08-24
> ต่อจาก WYN-056 (Explore Club redesign) — Founder ขอให้ทำหน้าที่เหลือของ Club ต่อ (Create Club, Club Page) ให้ครบตามทิศทาง WYNOS ที่ยกระดับไว้แล้ว
> อ้างอิง: `.wyn/docs/design/ds-001-color-system.md`, `.wyn/docs/design/wyn-056-club-discovery-visual-refresh.md`, `.wyn/docs/design/wyn-014-club-core.md` (Screen 2/3)

## บริบทสำคัญที่ต้องเข้าใจก่อนออกแบบ

แอปนี้ธีมมืด+cyan เป็น **global theme** อยู่แล้ว (`WynTheme.dark`/`WynColors.socialDarkScheme`) — `CreateClubScreen`/`ClubPage` **ไม่ได้ขาดธีมมืด** (ทุก `Scaffold`/`TextField`/`FilledButton` ดึงสีจาก `colorScheme` อัตโนมัติอยู่แล้ว) ดังนั้นงานนี้ไม่ใช่ "เพิ่ม dark mode" แต่เป็นการ **ปรับรายละเอียด (polish) จุดเล็กๆ ที่ยังดูเป็น default Material ทั่วไป** ให้เข้ากับภาษาภาพที่ WYN-056 วางไว้แล้ว (glow บาง, การ์ดไร้เงา, cyan เป็น accent จุดเดียวไม่ใช่ทั้งจอ)

ไม่พบ mockup ต้นฉบับของ `ClubPage` จาก Founder โดยตรง (บรีฟเดิมมีแค่ 3 หน้าจอ: CLUB hero, Create Club, Explore Club) — งานส่วน Club Page นี้จึงเป็นการต่อยอดภาษาภาพเดียวกันด้วยเหตุผล ไม่ใช่การ copy จากภาพ

---

## Screen 1: `CreateClubScreen` — ปรับ Cover picker

Purpose: ตอนนี้ที่ตัด Icon picker ออกแล้ว (Founder decision, 2026-08-24) เหลือ Cover picker เป็นจุดอัปโหลดรูปเดียวของฟอร์ม ควรให้มัน "รู้สึกสำคัญ" มากขึ้นแทนที่จะเป็นกล่องเทาเรียบๆ

Components: `_buildCoverPicker()` เปลี่ยนจาก `Container` พื้นทึบ `surfaceContainerHighest` → เพิ่ม:
- กรอบเส้นประ (`DashedBorder` ทำเองด้วย `CustomPaint`) สี `colorScheme.outline` แทนขอบทึบ — สื่อว่า "ยังไม่มีเนื้อหา รอเพิ่ม" (pattern มาตรฐานของ upload placeholder ทั่วไป ไม่ใช่การลอก layout ของแอปคู่แข่งเจาะจง)
- ไอคอนกล้อง (`Icons.add_photo_alternate_outlined`) อยู่ในวงกลมพื้น `primaryContainer` ขนาด 44px (แทนไอคอนลอยเดี่ยวๆ) — mirror แนวคิด glow-circle เดียวกับ hero icon ของ WYN-056 (Screen 1) แต่ไม่มี `BoxShadow` glow ที่นี่ (จุดนี้เป็น placeholder ไม่ใช่ hero — ถ้าใส่ glow จะเกิน 1 จุดเด่นต่อจอโดยไม่จำเป็น)
- ข้อความ 2 บรรทัด: "แตะเพื่อเลือกรูปปก" (`bodyMedium`) + "แนะนำอัตราส่วน 16:9" (`labelSmall`, สี `onSurfaceVariant`) — ให้คำแนะนำอัตราส่วนที่มีอยู่แล้วใน design intent (WYN-014) แต่ไม่เคยแสดงเป็นข้อความมาก่อน

Interactions: เหมือนเดิมทุกประการ (`_pickCover` ไม่เปลี่ยน logic)

States: เมื่อมีรูปแล้ว (`_coverBytes != null`) แสดงรูปเต็ม `AspectRatio` เหมือนเดิม ไม่มีกรอบเส้นประทับซ้อน (กรอบเส้นประ = placeholder state เท่านั้น)

Accessibility: `Semantics` label เดิมคงไว้ ("แตะเพื่อเลือกรูปปก"/"รูปปกที่เลือก")

Design Rules: ไม่ใช้ `BackdropFilter`/blur ใดๆ (เส้นประวาดด้วย `CustomPaint`/`DashPath` ธรรมดา ไม่ใช่ glass), สีทุกจุดอ้างอิง `colorScheme`

---

## Screen 2: `ClubPage` — Header Join button ยกน้ำหนักภาพเป็นปุ่มหลักจริง

Purpose: ปุ่ม Join บนหน้า Club เป็น action ที่สำคัญที่สุดของหน้านี้ (แปลงคนดูเป็นสมาชิก) แต่ปัจจุบันเป็น `OutlinedButton` เดียวกับปุ่มรอง — ยกระดับให้เด่นขึ้นตอนยัง "เข้าร่วม" ได้ (ยังไม่ได้เข้าร่วม) ตามหลัก visual hierarchy เดียวกับปุ่ม "+ สร้าง Club" ของ WYN-056 ที่เป็น `FilledButton` เต็มพื้น cyan

Components: `_buildJoinButton()` เปลี่ยนจาก `OutlinedButton` เดี่ยวเป็น:
- สถานะ "เข้าร่วม" (ยังไม่ใช่สมาชิก) → **`FilledButton`** พื้น `colorScheme.primary` (cyan เต็ม) + ตัวหนังสือ `onPrimary` — จุดนี้อยู่ในกติกา DS-001 ข้อ 6 ที่อนุญาต Cyan เป็นพื้นปุ่มหลักได้อยู่แล้ว
- สถานะ "เข้าร่วมแล้ว"/"รออนุมัติ" → คงเป็น `OutlinedButton` (ไม่ต้องการให้เด่นเพราะไม่ใช่ action ที่ต้องชวนกดอีกต่อไป) — **ปรับสีเพิ่มเติมจากเดิม**: เดิม "รออนุมัติ" ใช้สี `primary` (cyan) ทั้งที่กดไม่ได้ (disabled) ต่างจาก "เข้าร่วมแล้ว" ที่ใช้ `outline` — งานนี้รวมให้ทั้งสองสถานะที่กดไม่ได้/ไม่ใช่ action หลักใช้สี `outline` เหมือนกัน (สีเดิมของปุ่ม disabled ไม่ควรใช้สีแบรนด์) ไม่ใช่ "เหมือนเดิมทุกประการ"

Interactions/States/Accessibility: เหมือนเดิมทุกประการ (`_toggleJoin`/`_confirmLeave`/`Semantics` label เดิมไม่เปลี่ยน) — เปลี่ยนแค่ widget type ของสถานะ "เข้าร่วม" เท่านั้น

Design Rules: ปุ่มเดียวในหน้าที่เป็นพื้น cyan เต็ม ไม่ขัดกับกติกา ≤15% พื้นที่จอต่อเนื่อง (ปุ่มเดียวขนาดมาตรฐาน ไม่ใช่พื้นที่กว้าง)

---

## Handoff: AI Coding —

1. `create_club_screen.dart`: แก้เฉพาะ `_buildCoverPicker()` — เพิ่ม `CustomPaint`/dashed border + ไอคอนวงกลม + ข้อความ 2 บรรทัด ไม่แตะ logic การอัปโหลด/state อื่นในไฟล์
2. `club_page.dart`: แก้เฉพาะ `_buildJoinButton()` — เปลี่ยนสถานะ "เข้าร่วม" จาก `OutlinedButton` เป็น `FilledButton`, คงสถานะอื่นเดิม, คง `Key`/`Semantics` เดิมทั้งหมด
3. ไม่แตะ schema/RLS/repository ใดๆ — เป็น visual polish ล้วน
4. รัน `flutter analyze`/`flutter test` เต็ม suite ยืนยันไม่มี regression กับ `club_page_test.dart`/`create_club_screen_test.dart` เดิม

## Handoff รวม

ส่งต่อ AI Coding (`/code`) — Acceptance Criteria เต็มที่ `.wyn/tasks/approved/WYN-057-create-club-visual-refresh.md`/`.wyn/tasks/approved/WYN-058-club-page-visual-refresh.md`
