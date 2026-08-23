# Product Task — WYN-037

Status: approved
Owner: AI Product Manager

Feature: Edit / Delete Drop (time window + soft delete/restore)

Goal: ให้ผู้ใช้แก้ไขแคปชันของ Drop ตัวเองได้ภายในกรอบเวลาที่กำหนด และลบ Drop แบบกู้คืนได้ภายในกรอบเวลาที่กำหนด — task ที่สี่ของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 4: "ผู้ใช้แก้ไข Drop ของตัวเองได้ ตั้งกฎได้ เช่น 'แก้ไขภายใน 30 นาที' และ: Delete, Soft Delete, Restore ในช่วงเวลาที่กำหนด — Admin ตรวจสอบประวัติได้"

Target User: ผู้ใช้ที่พิมพ์แคปชันผิด/อยากแก้คำหลังโพสต์ไปแล้วไม่นาน และผู้ใช้ที่กดลบ Drop ผิดพลาด/เปลี่ยนใจอยากได้กลับคืนมา

Problem: ตอนนี้ระบบมีแค่ "ลบ Drop ของตัวเอง" แบบถาวร (`DropRepository.deleteDrop()` เป็น hard DELETE จริง — กดลบแล้วหายทันทีไม่มีทางกู้คืน) และ**ไม่มีการแก้ไข Drop เลยแม้แต่จุดเดียว** (พิมพ์แคปชันผิดต้องลบทิ้งแล้วโพสต์ใหม่เท่านั้น สูญเสีย Like/Comment/ReDrop เดิมทั้งหมด) ทั้งที่ Master Spec ระบุทั้งสองความสามารถนี้เป็นพื้นฐานตั้งแต่ต้น

Requirements:

**Edit Drop**
- แก้ไขได้เฉพาะ **แคปชัน** เท่านั้น (รูปภาพ, ตัวเลือกโพล ไม่สามารถแก้ไขได้เลยไม่ว่ากรณีใด — เปลี่ยนรูป/ตัวเลือกหลังคนเห็น/โหวตไปแล้วจะทำให้เข้าใจผิด) — ใช้ได้ทั้ง Drop แบบรูปภาพและแบบโพล (แคปชันของโพล = คำถามของโพล ใช้ field เดียวกันอยู่แล้วตั้งแต่ WYN-035)
- **กรอบเวลาแก้ไข: 30 นาทีนับจากเวลาโพสต์** (`created_at`) ตามตัวอย่างที่ Master Spec ระบุตรงๆ — เกินเวลานี้ปุ่ม/เมนู "แก้ไข" หายไป ไม่มีทางแก้ได้อีก
- แก้ไขสำเร็จ → แสดงป้ายกำกับ "แก้ไขแล้ว" ต่อจากเวลาโพสต์ (โปร่งใสกับผู้ดูคนอื่นว่าเนื้อหาถูกแก้ไข ไม่ใช่ของเดิมทั้งหมด) — ไม่ต้องมี edit history แบบเต็มรูปแบบ (ดู Risks)
- ลบแคปชันจนว่างได้ (แคปชันเป็น optional อยู่แล้วตั้งแต่สร้าง Drop)

**Delete Drop → Soft Delete**
- กดลบ Drop → **ไม่ใช่ hard delete อีกต่อไป** เปลี่ยนเป็น soft delete (ซ่อนจากทุกที่ทันที: Home Feed, Search, Profile grid, ReDrop ของ Drop นี้, การเข้าถึงตรงผ่านลิงก์/แจ้งเตือนเดิม — เหมือนถูกลบจริงสำหรับทุกคนยกเว้นเจ้าของ) แต่**เจ้าของยังกู้คืนได้ภายในกรอบเวลาที่กำหนด**
- **กรอบเวลากู้คืน: 30 วันนับจากเวลาลบ** (ตัวเลขที่ Product กำหนดเอง — Master Spec บอกแค่ "ในช่วงเวลาที่กำหนด" ไม่ได้ระบุตัวเลข, 30 วันมิเรอร์ retention ของถังขยะที่ผู้ใช้คุ้นเคยอยู่แล้ว เช่น Gmail/Google Photos) — เกินกรอบเวลานี้ กู้คืนไม่ได้อีกต่อไป (ดู Risks เรื่องไม่มี physical purge job)
- Dialog ยืนยันก่อนลบเปลี่ยนข้อความให้สื่อว่ากู้คืนได้ในกรอบเวลา ไม่ใช่ลบถาวรทันที
- ผู้ใช้ที่ถูก Restrict/Suspend/Ban **ยังแก้ไข/ลบ/กู้คืน Drop ของตัวเองได้ปกติ** — นี่คือการจัดการเนื้อหาที่โพสต์ไปแล้ว ไม่ใช่การโพสต์เนื้อหาใหม่ (คนละเรื่องกับ "ถูกบล็อกไม่ให้โพสต์ใหม่" ที่ระบบเดิมทำอยู่แล้ว) — ตัดสินใจโดย Product มิเรอร์เหตุผลเดียวกับที่ WYN-036 อนุญาต Restricted user บันทึก Draft ได้ปกติ

**Recently Deleted (กู้คืน)**
- หน้าจอใหม่ "รายการที่ลบ" เข้าถึงจากหน้า Settings (เห็นเฉพาะเจ้าของบัญชี) แสดง Drop ที่ตัวเองลบไว้ (ยังไม่พ้นกรอบเวลา 30 วัน) พร้อมปุ่ม "กู้คืน" ต่อรายการ
- กู้คืนแล้ว → Drop กลับมาปรากฏใน Home Feed/Search/Profile/ReDrop เดิมทุกจุดทันที เหมือนไม่เคยถูกลบ

Acceptance Criteria:
- [ ] Drop ของตัวเองที่โพสต์มาไม่เกิน 30 นาที มีเมนู "แก้ไข" ให้กด แก้ไขแคปชันแล้วบันทึกสำเร็จ แสดงป้าย "แก้ไขแล้ว"
- [ ] Drop ของตัวเองที่โพสต์เกิน 30 นาทีแล้ว ไม่มีตัวเลือก "แก้ไข" ให้เห็นเลย
- [ ] แก้ไขแคปชันของ Drop แบบโพล (คำถาม) ได้เหมือนกัน ไม่กระทบตัวเลือก/ผลโหวตเดิม
- [ ] กด "ลบ" Drop ของตัวเอง → เด้ง dialog ยืนยันสื่อว่ากู้คืนได้ในกรอบเวลา → ยืนยันแล้ว Drop หายจาก Home Feed/Search/Profile grid ของตัวเองและคนอื่นทันที
- [ ] Drop ที่ถูกลบ (soft delete) เข้าถึงตรงผ่าน URL/ลิงก์เดิมไม่ได้อีกสำหรับคนอื่น (เหมือนถูกลบจริง)
- [ ] ReDrop ของ Drop ที่ถูกลบ (soft delete) หายไปจาก feed ของทุกคนด้วยเช่นกัน (ไม่เหลือค้างให้เห็นเนื้อหาที่ถูกลบผ่าน ReDrop)
- [ ] เจ้าของเปิดหน้า "รายการที่ลบ" ใน Settings เห็น Drop ที่ตัวเองลบไว้ (ยังไม่พ้น 30 วัน) กด "กู้คืน" แล้ว Drop กลับมาปรากฏทุกจุดเหมือนเดิม (รวม ReDrop เดิมที่เคยหายไปด้วย)
- [ ] Drop ที่ลบเกิน 30 วันแล้ว กู้คืนไม่ได้อีก (ปุ่มกู้คืน/เรียก RPC ตรงถูกปฏิเสธ)
- [ ] ผู้ใช้ที่ถูก Restrict ยังแก้ไข/ลบ/กู้คืน Drop ของตัวเองได้ปกติ
- [ ] Drop ของ user A, user B แก้ไข/ลบ/กู้คืนไม่ได้เลยไม่ว่าทางไหน (ตรวจสอบด้วย SQL โดยตรงด้วย role `authenticated`)
- [ ] Comment เดิมของ Drop ที่ถูกลบ (soft delete) เข้าถึงไม่ได้จากคนอื่นเช่นกัน (ปิดช่องทางอ้อมที่อาจยังเห็น comment ได้ทั้งที่ตัว Drop ถูกซ่อนไปแล้ว)
- [ ] Regression: Drop/Poll/ReDrop/Draft ที่ไม่เกี่ยวข้องกับ Edit/Delete ทำงานเหมือนเดิมทุกจุด, moderator's "Remove Content" (WYN-029) ยังคง hard-delete เหมือนเดิมไม่เปลี่ยนแปลง

Dependencies: WYN-005 (Drop core), WYN-034 (ReDrop — ต้องหายไปด้วยเมื่อต้นฉบับถูกลบ), WYN-035 (Poll — แคปชัน/คำถามใช้ field เดียวกัน), WYN-029 (Moderation's Remove Content — ต้องไม่ชนกัน ยังคง hard-delete แยกกันเป็นคนละกลไก) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P1 — task ที่สี่ของ Phase 3 ตามลำดับ Roadmap ต่อจาก WYN-034/035/036

Risks:
- **ไม่มี edit history แบบเต็มรูปแบบ** (เก็บแค่ "แก้ไขแล้วเมื่อไหร่" ไม่เก็บเนื้อหาก่อนแก้ไขแต่ละเวอร์ชัน) — Master Spec พูดถึง "Admin ตรวจสอบประวัติได้" แต่ WYN Admin (เว็บ) ยังไม่มีอยู่จริงในระบบเลย (repo gap ที่บันทึกไว้ตั้งแต่ต้น Roadmap) การสร้าง audit trail เต็มรูปแบบตอนนี้จะไม่มีใครใช้ได้จริง — ยอมรับ scope reduction นี้ ถ้า Founder ต้องการ full edit history ต้องแจ้งเป็น follow-up พร้อมกับสร้าง WYN Admin
- **ไม่มี physical purge job หลังพ้น 30 วัน** — แถวที่ลบเกินกรอบเวลาแค่ "กู้คืนไม่ได้อีก" (RPC ปฏิเสธ) แต่ตัวแถวใน DB ยังอยู่จริงจนกว่าจะมี cron/Admin job มาล้างจริง — มิเรอร์ pattern เดียวกับที่ WYN-029's `expires_at` ใช้อยู่แล้ว (auto-expiry ผ่านการเช็คเวลา ไม่ใช่ cron) เพราะระบบยังไม่มี cron infrastructure จริง
- **แก้ไขคำถามโพลหลังมีคนโหวตแล้วได้** (ภายในกรอบ 30 นาที) — อาจทำให้คนที่โหวตไปแล้วงงว่าโหวตอะไรอยู่ (คำถามเปลี่ยนแต่ตัวเลือก/ผลโหวตเดิมไม่เปลี่ยน) — ยอมรับความเสี่ยงนี้เพราะกรอบเวลาสั้นมาก (30 นาที) และไม่ต่างจากพฤติกรรม edit ของแพลตฟอร์มอื่นที่ก็ไม่บล็อกกรณีนี้เช่นกัน (X/Twitter Edit ก็อนุญาต)
- **แก้ไขแคปชันไม่ trigger mention resolution ใหม่** — ใช้ plain text field ธรรมดา ไม่ใช่ `MentionInput` (ตัดสินใจโดย Product เพื่อไม่ให้ดูเหมือนรองรับ mention ใหม่ทั้งที่ไม่ insert `drop_mentions`/แจ้งเตือนจริง) — มิเรอร์ gap เดียวกับที่ WYN-036's Draft continue-editing ยอมรับไว้แล้ว ถ้าผู้ใช้เพิ่ม @mention ใหม่ตอนแก้ไข จะไม่มีการแจ้งเตือนคนที่ถูกแท็กใหม่

Recommendation:
1. Schema: เพิ่ม 2 คอลัมน์ใหม่บน `drops` — `edited_at timestamptz` (null จนกว่าจะแก้ไขครั้งแรก), `deleted_at timestamptz` (null = ยังไม่ถูกลบ) — **ไม่มี UPDATE/DELETE RLS policy แบบ raw client เลย** ทุกการแก้ไข/ลบ/กู้คืนผ่าน RPC (SECURITY DEFINER) 3 ตัวเท่านั้น: `edit_drop()` (เช็คเจ้าของ+ยังไม่ลบ+ยังอยู่ในกรอบ 30 นาที), `soft_delete_drop()` (เช็คเจ้าของ+ยังไม่เคยลบ), `restore_drop()` (เช็คเจ้าของ+ลบไปแล้ว+ยังอยู่ในกรอบ 30 วัน) — มิเรอร์ pattern เดียวกับ `create_poll_drop()`/`apply_moderation_action()` ที่ธุรกิจกฎซับซ้อนใช้ RPC แทน RLS ตรงๆ
2. SELECT RLS ของ `drops` ต้องขยายให้ `deleted_at is null or auth.uid() = author_id` — จุดนี้จุดเดียวพอสำหรับซ่อน Drop ที่ถูกลบจากทุกที่ (Home Feed/Search/Profile/ReDrop's join) เพราะทุก view ที่มีอยู่แล้ว (`home_feed`/`saved_feed`) เป็น `security_invoker = true` และ join ตรงกับ `public.drops` — RLS กรองที่ table เดียวพอ **ไม่ต้องแก้ view ทั้งสองเลย**
3. SELECT RLS ของ `drop_comments` ต้องขยายเช่นกันให้เช็คว่า Drop แม่ยังมองเห็นได้อยู่ (ไม่งั้นจะเป็นช่องทางอ้อมเห็น comment ของ Drop ที่ถูกซ่อนไปแล้วได้ทั้งที่ตัว Drop เองมองไม่เห็น) — เป็นช่องโหว่ใหม่ที่เกิดจาก soft delete โดยตรง (hard delete เดิมไม่มีปัญหานี้เพราะ comment cascade หายไปพร้อมกัน) ต้องปิดพร้อมกันในรอบนี้
4. `redrops.drop_id references public.drops(id) on delete cascade` เดิมไม่ต้องแก้ (soft delete ไม่ทำให้ cascade ทำงาน แต่ RLS ที่ข้อ 2 กรอง join ให้อัตโนมัติอยู่แล้ว โดยไม่ต้องพึ่ง cascade)
5. ลบ policy "Users can delete their own drops" (DELETE ตรง) ทิ้งไปเลย — self-delete ต้องผ่าน `soft_delete_drop()` เท่านั้น ปิดช่องทาง hard-delete ของผู้ใช้เองไปโดยสิ้นเชิง (moderation's `apply_moderation_action()` ยังคง hard-delete ตรงเหมือนเดิม เพราะเป็น SECURITY DEFINER คนละฟังก์ชัน ไม่ผ่าน policy นี้อยู่แล้ว ไม่กระทบกัน)
6. Design ควรเปลี่ยนปุ่ม delete-only (IconButton เดียว) บน DropDetailScreen ของ Drop ตัวเอง ให้เป็นเมนู `more_vert` (มิเรอร์ pattern เดิมที่ `_openDropMoreMenu` ใช้กับ Drop คนอื่นอยู่แล้ว) มีตัวเลือก "แก้ไข" (โชว์เฉพาะยังอยู่ในกรอบเวลา) และ "ลบ"

Handoff: AI Design — ออกแบบเมนู more_vert ของ Drop ตัวเอง (แก้ไข/ลบ), หน้าจอ/dialog แก้ไขแคปชัน (plain text field ไม่ใช้ MentionInput), ป้าย "แก้ไขแล้ว", ข้อความ dialog ยืนยันลบแบบใหม่ (สื่อว่ากู้คืนได้), หน้าจอ "รายการที่ลบ" ใหม่ (เข้าจาก Settings), schema เบื้องต้นที่แนะนำ (2 คอลัมน์ + RPC 3 ตัว + RLS ขยาย 2 จุด) ให้ AI Coding ต่อยอดได้ทันที

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): `drops` เพิ่ม 2 คอลัมน์ `edited_at`/`deleted_at` (nullable ทั้งคู่) — **ไม่มี raw client UPDATE/DELETE policy บน `drops` เลย** ทุกการแก้ไข/ลบ/กู้คืนผ่าน RPC 3 ตัว (SECURITY DEFINER, ล็อกแถวด้วย `for update` กันแข่งกัน): `edit_drop()` (เช็คเจ้าของ+ยังไม่ลบ+`created_at > now() - 30 นาที`), `soft_delete_drop()` (เช็คเจ้าของ+ยังไม่เคยลบ), `restore_drop()` (เช็คเจ้าของ+ลบไปแล้ว+`deleted_at > now() - 30 วัน`) — ลบ policy "Users can delete their own drops" (DELETE ตรง) ทิ้งไปเลย self-delete ต้องผ่าน `soft_delete_drop()` เท่านั้น — ขยาย SELECT policy ของ `drops` ให้เพิ่ม `deleted_at is null or auth.uid() = author_id` จุดเดียวก็ครอบคลุม Home Feed/Search/Profile/ReDrop's join ทั้งหมดเพราะทุก view เป็น `security_invoker = true` — ขยาย SELECT policy ของ `drop_comments` ให้เช็คว่า Drop แม่ยังมองเห็นได้อยู่ด้วย ปิดช่องทางอ้อมเห็น comment ของ Drop ที่ถูกซ่อนไปแล้ว

**Flutter**: `Drop` model เพิ่ม `editedAt`/`deletedAt` (nullable) + `wasEdited` getter + `withEditedCaption()` — `DropRepository.deleteDrop()` เปลี่ยนไปเรียก RPC `soft_delete_drop` แทน raw DELETE (ชื่อเมธอดเดิมไม่เปลี่ยน ลด diff ที่ call site), เพิ่ม `editDrop()`/`restoreDrop()`/`fetchDeletedDrops()` ใหม่ — `EditDropCaptionScreen` ใหม่ (plain `TextField` ไม่ใช้ `MentionInput` ตามที่ Design ระบุ) — `RecentlyDeletedDropsScreen` ใหม่ เข้าจาก `SettingsScreen`'s ListTile ใหม่ — `DropDetailScreen` เปลี่ยนปุ่มลบเดี่ยวเป็นเมนู `more_vert` (มิเรอร์ `_openDropMoreMenu` เดิม) มี "แก้ไข" (โชว์เฉพาะยังอยู่ในกรอบ 30 นาที ตาม client-side clock — enforcement จริงอยู่ที่ RPC) + "ลบ" เสมอ, เพิ่มป้าย "แก้ไขแล้ว" ต่อชื่อผู้เขียน — `confirm_delete_drop_dialog.dart` เขียนใหม่ทั้งไฟล์ (ไม่ reuse `confirmDeletePost` เดิมอีกต่อไป เพราะข้อความ "ลบแล้วไม่สามารถกู้คืนได้" ไม่จริงอีกต่อไปสำหรับ Drop โดยเฉพาะ — comment/Pop ยังใช้ dialog เดิมเหมือนเดิม ไม่กระทบ)

**บั๊กจริงที่พบและแก้ระหว่างเขียนโค้ด**: ไม่มี — เขียนตาม Design spec ตรงๆ ผ่านทั้ง `flutter analyze`/`flutter test` (576/576) และ SQL regression 22/22 ใหม่ทันทีรอบแรก แต่พบ **regression 2 จุดในสคริปต์เก่า** (`wyn_034`/`wyn_035`'s เช็คเดิมที่เคย `delete from public.drops` ตรงๆ ตอนนี้เป็น no-op เงียบๆ เพราะไม่มี DELETE policy เหลืออยู่แล้ว) — แก้โดยเปลี่ยนทั้งสองจุดให้เรียก `soft_delete_drop()` แทน แล้วปรับ expected value ให้ตรงกับพฤติกรรมใหม่ (แถว ReDrop/drop_polls/drop_poll_votes ไม่ cascade หายไปอีกต่อไป เพราะไม่มี hard DELETE จริงเกิดขึ้น) พร้อม comment อธิบายเหตุผลไว้ในทั้งสองสคริปต์

**Tests**: `flutter analyze` สะอาด 0 issues — `flutter test` **595/595 ผ่าน** ก่อนรอบ QA (เพิ่มจาก 576 เดิม: `edit_drop_caption_screen_test.dart` ใหม่ 4 เคส, `recently_deleted_drops_screen_test.dart` ใหม่ 6 เคส, `drop_test.dart` +4 [`edited_at`/`deleted_at`/`withEditedCaption`], `drop_detail_screen_test.dart` +4 [กลุ่ม "Edit/Delete (WYN-037)"], `settings_screen_test.dart` +1)

**SQL live verification**: เขียน `supabase/tests/wyn_037_edit_delete_drop_test.sh` ใหม่ (22 checks) รันภายใต้ role `authenticated` จริง ครอบ: edit ในกรอบเวลาสำเร็จ/เกินกรอบเวลา raise/คนอื่น edit ไม่ได้เลย, soft delete ซ่อนจากคนอื่นแต่เจ้าของยังเห็น/ลบซ้ำ raise, restore ในกรอบเวลาสำเร็จ/เกินกรอบเวลา raise, คนอื่น delete/restore ของคนอื่นไม่ได้, **ReDrop ของ Drop ที่ถูกลบหายจาก feed แม้แต่คนที่ ReDrop เอง (พิสูจน์ว่า RLS จุดเดียวพอ ไม่ต้องแก้ view)**, comment ของ Drop ที่ถูกลบมองไม่เห็นจากคนอื่นแต่เจ้าของยังเห็น, ผู้ใช้ Restricted ยัง edit/delete/restore ของตัวเองได้, regression Drop/Poll ปกติยังทำงาน — **22/22 PASS** — รันซ้ำ 10 สคริปต์เดิมทั้งหมด (รวมที่แก้ไขแล้ว) ผ่านหมดไม่มี cross-task regression

**Acceptance Criteria — ไล่ตรวจครบทั้ง 13 ข้อ**: ครบทุกข้อ (dialog ยืนยัน 3 ปุ่ม, บันทึกร่าง/ทิ้ง/ยกเลิกทำงานถูกต้อง, แก้ไขในกรอบเวลาสำเร็จ+ป้าย "แก้ไขแล้ว", เกินกรอบเวลาไม่มีตัวเลือกแก้ไข, แก้ไขคำถามโพลได้ไม่กระทบตัวเลือก/ผลโหวต, ลบซ่อนทันทีจากทุกที่, เข้าถึงผ่านลิงก์เดิมไม่ได้, ReDrop ของ Drop ที่ลบหายไปด้วย, กู้คืนได้ในกรอบ 30 วัน+กลับมาทุกจุดรวม ReDrop, เกิน 30 วันกู้คืนไม่ได้, Restricted ทำได้ปกติ, คนอื่นแก้ไข/ลบ/กู้คืนไม่ได้เลย, comment ของ Drop ที่ลบเข้าถึงไม่ได้)

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS (2 บั๊กจริงพบและแก้ก่อนอนุมัติ)

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — task นี้เปลี่ยนกลไก delete จาก hard เป็น soft ทั่วทั้งระบบ (กระทบ RLS ของหลายตารางพร้อมกัน) ต้องตรวจ RLS interaction ระหว่างตารางอย่างละเอียดเป็นพิเศษ

**สิ่งที่ทำ**:
1. อ่าน `git diff` ทั้งหมดของ task นี้โดยตรงทุกไฟล์ ไม่เชื่อสรุปจาก Coding Output
2. รัน `flutter analyze`/`flutter test` อิสระเอง — ตรงกัน: 0 issues, 597/597
3. รัน SQL regression ทั้ง 11 สคริปต์อิสระเอง — ตรงกัน: ผ่านหมด ไม่มี cross-task regression
4. **พบบั๊กจริงจุดที่ 1**: `EditDropCaptionScreen`'s `_canSave` เช็คแค่ "ข้อความเปลี่ยนจากเดิมไหม" ไม่เช็คว่าข้อความใหม่ว่างเปล่าหรือไม่ — สำหรับ Drop แบบโพล แคปชันคือ "คำถาม" ของโพล ถ้าแก้ไขจนว่างเปล่าจะเหลือโพลที่มีตัวเลือก/ผลโหวตอยู่แต่ไม่มีคำถามอธิบายเลย สร้างความสับสนให้ทุกคนที่โหวตไปแล้ว — เขียน test จำลองสถานการณ์จริง ยืนยันว่า test **fail จริงกับโค้ดเดิม** (ปุ่มบันทึก enabled ทั้งที่ข้อความว่าง) แล้วแก้โดยเพิ่ม param `isPollQuestion` บังคับห้ามบันทึกว่างเปล่าเมื่อเป็นคำถามโพล ต่อสายจาก `DropDetailScreen._editDrop()` ผ่าน `_drop.isPoll` — รัน test ซ้ำผ่านหลังแก้
5. **พบบั๊กจริงจุดที่ 2 (ร้ายแรงกว่า — self-referential RLS)**: เขียน SQL regression check ใหม่ (CHECK10c) พิสูจน์ว่าคนแปลกหน้าคอมเมนต์บน Drop ที่ถูกลบไม่ได้ — พบว่า Coding's `drop_comments` INSERT policy fix (`not exists (select 1 from public.drops d where d.id = ... and d.deleted_at is not null)`) **ใช้งานไม่ได้จริงเลย**: subquery นั้นถูกกรองด้วย RLS ของ `drops` เองอีกชั้นหนึ่งด้วย (เพราะเป็นการอ่านตาราง `drops` ธรรมดา ไม่ใช่ SECURITY DEFINER) — สำหรับคนแปลกหน้า `drops`' SELECT policy ซ่อนแถวที่ถูกลบไปแล้วเสมอ ทำให้ `exists()` เป็น false เสมอไม่ว่าแถวจะถูกลบจริงหรือไม่ → `not exists()` เป็น true เสมอ → เช็คนี้**ไม่เคยบล็อกใครได้จริงเลยสักครั้ง** — ยืนยันด้วย manual reproduction ตรงใน psql (insert สำเร็จจริงแม้ Drop ถูกลบไปแล้ว) ก่อนสรุปว่าเป็นบั๊กจริง ไม่ใช่แค่ทฤษฎี — แก้โดยเพิ่มฟังก์ชันใหม่ `internal.is_drop_deleted()` (SECURITY DEFINER, มิเรอร์ `internal.drop_author_id()` เดิม) ให้ bypass RLS ของ `drops` ตรงๆ แทนการอ่านผ่าน policy ปกติ — ยืนยันด้วย regression test (CHECK10c) ที่ **fail จริงกับโค้ดเดิม (แม้จะมี "fix" อยู่แล้วก็ตาม), pass หลังแก้จริง** — รัน SQL ทั้ง 11 สคริปต์ซ้ำหลังแก้ **ผ่านหมด**
6. ไล่เทียบ Acceptance Criteria ทั้ง 13 ข้อกับโค้ดจริงทีละข้อ — ครบทุกข้อ
7. ตรวจ `drop_polls`'s SELECT policy (piggyback บน `drops` เหมือนกัน) ว่าไม่โดนปัญหาเดียวกับข้อ 5 — ยืนยันไม่โดน เพราะเป็นทิศทาง SELECT-on-SELECT ล้วนๆ (ไม่ใช่ WITH CHECK/INSERT) ซึ่งพฤติกรรม RLS ซ้อนกันบังเอิญให้ผลลัพธ์ที่ถูกต้องพอดี ต่างจากกรณี INSERT ที่ทิศทางตรงข้ามทำให้เกิดบั๊ก
8. ตรวจ `drop_comments` SELECT policy fix ของ Coding (คนละจุดจาก INSERT fix) ด้วยเหตุผลเดียวกับข้อ 7 — ยืนยันว่าถูกต้อง ไม่มีปัญหาแบบเดียวกับ INSERT policy

**ผลลัพธ์**: **WYN-037 — PASS** (หลังแก้ 2 บั๊กจริงที่ QA พบ) — `flutter analyze` 0 issues, `flutter test` 597/597 (595 เดิม + 2 regression test ใหม่ที่ QA เพิ่มเพื่อยืนยันบั๊ก #1 + การแก้), SQL regression 23/23 ของ WYN-037 เอง (22 เดิม + CHECK10c ใหม่สำหรับบั๊ก #2) + ผ่านครบทั้ง 11 สคริปต์ ไม่มี cross-task regression

Handoff: AI Deploy & DevOps — commit/push/PR/merge/deployment log
