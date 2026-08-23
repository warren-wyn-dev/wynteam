# Product Task — WYN-036

Status: approved
Owner: AI Product Manager

Feature: Draft System

Goal: ให้ผู้ใช้บันทึก Drop ที่ยังเขียนไม่เสร็จไว้ก่อน แล้วกลับมาแก้ไข/โพสต์ทีหลังได้ — task ที่สามของ Phase 3 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 3 ("ผู้ใช้ทำได้: Save Draft, Edit Draft, Delete Draft, Continue Editing — Draft ต้องเป็น Private")

Target User: ผู้ใช้ที่กำลังเขียน Drop (รูปภาพหรือโพล) อยู่แล้วถูกขัดจังหวะ (โทรศัพท์เข้า, เปลี่ยนใจอยากคิดคำต่อก่อน, ไม่มั่นใจรูปที่เลือก) ไม่อยากให้สิ่งที่พิมพ์ไว้หายไปเฉยๆ เวลาปิดหน้าจอ

Problem: ตอนนี้กด X ปิดหน้า Create Drop เมื่อไหร่ก็ตาม เนื้อหาที่พิมพ์/รูปที่เลือกไว้หายทันทีไม่มีทางกู้คืน (ปิดแล้ว state หายทั้งหมด ไม่มีการถามหรือบันทึกใดๆ) ทั้งที่ Master Spec ระบุ Draft เป็นความสามารถพื้นฐานตั้งแต่ต้น

Requirements:

**Save Draft**
- จุดเดียวที่ทำให้เกิด Draft: **กด X (หรือกด back ปิดหน้าจอ) ตอนมีเนื้อหาที่ยังไม่ได้แชร์** (โหมดรูป: เลือกรูปแล้วและ/หรือพิมพ์แคปชันแล้ว, โหมดโพล: พิมพ์คำถามแล้วและ/หรือพิมพ์ตัวเลือกอย่างน้อย 1 ช่องแล้ว) → เด้ง dialog "บันทึกเป็นร่างก่อนออกไหม?" 3 ตัวเลือก: "บันทึกร่าง" / "ทิ้ง" / "ยกเลิก" (ยกเลิก = อยู่ในหน้าเดิมต่อ) — ไม่มีปุ่ม "บันทึกร่าง" แยกต่างหากบน AppBar เพื่อไม่ให้ปุ่มรก (ตัดสินใจโดย Product ลด scope UI)
- **Draft ไม่ต้องผ่านการ validate ครบเหมือนตอนแชร์จริง** (เช่น โพลมีแค่ 1 ตัวเลือกก็บันทึกร่างได้ ทั้งที่แชร์จริงต้องมีอย่างน้อย 2) — นี่คือจุดประสงค์ของ Draft คือเก็บงานที่ยังไม่เสร็จ
- ผู้ใช้ที่ถูก Restrict/Suspend/Ban **ยังบันทึก Draft ได้ปกติ** (การร่างส่วนตัวไม่ใช่การโพสต์ ไม่กระทบใคร) — ที่โดนบล็อกคือตอนกด "แชร์" จริงเท่านั้น (ระบบเดิมทำอยู่แล้ว ไม่ต้องแก้)

**Edit Draft / Continue Editing**
- แตะ Draft จาก Draft list → เปิดหน้า Create Drop เดิม prefill เนื้อหาทั้งหมด (โหมดรูป/โพล, รูปเดิม, แคปชัน/คำถามเดิม, ตัวเลือกโพลเดิม, ระยะเวลาโหวตเดิม) แก้ไขต่อได้ทันที
- บันทึกร่างซ้ำ (กด X อีกครั้งหลังแก้ไข) → **อัปเดตร่างเดิม ไม่สร้างซ้ำ**
- กด "แชร์" จาก Draft ที่เปิดมา → สร้าง Drop จริง (ผ่าน flow เดิมของ Drop/Poll ทุกอย่าง รวม validate เต็มรูปแบบ) แล้ว**ลบ Draft ทิ้งอัตโนมัติ**

**Delete Draft**
- ลบ Draft จาก Draft list โดยตรงได้ (long-press → เมนู "ลบร่าง" + ยืนยัน) ไม่ต้องเปิดเข้าไปแก้ก่อน

**ความเป็นส่วนตัว (Private)**
- Draft **มองเห็นได้เฉพาะเจ้าของเท่านั้น** ไม่ปรากฏใน Home Feed/Search/Profile คนอื่น/ที่ไหนเลยนอกจาก Draft list ของเจ้าของเอง — **ไม่ใช่ `drops` row** เลยด้วยซ้ำ (ตารางแยกต่างหาก `drop_drafts` ไม่แตะ `home_feed`/Like/Comment/ReDrop/Search/Notification/Report ที่มีอยู่แล้วเลยแม้แต่จุดเดียว) — เป็นการตัดสินใจสถาปัตยกรรมหลักที่ลด blast radius/ความเสี่ยงต่อระบบเดิมให้เหลือน้อยที่สุด มิเรอร์แนวทางเดียวกับที่ WYN-034/WYN-035 แยกตารางใหม่ของตัวเองไม่แตะ `drops` เดิม

**Draft list**
- Tab ใหม่ "ร่าง" ใน Profile ของตัวเอง (เห็นเฉพาะเจ้าของโปรไฟล์ มิเรอร์ tab "บันทึก" เดิมที่ WYN-013 วางไว้) แสดง grid รูปแบบเดียวกับ tab อื่นๆ เรียงตามเวลาแก้ไขล่าสุดก่อน (`updated_at` ไม่ใช่ `created_at` — แก้ไขร่างแล้วต้องขึ้นบนสุด)
- Draft ที่เป็นโพล (ไม่มีรูป) แสดง placeholder เดียวกับที่ WYN-035 ทำไว้แล้ว (`PollPlaceholderTile`) reuse ตรงๆ

Acceptance Criteria:
- [ ] กำลังเขียน Drop (มีรูปหรือแคปชันแล้ว) กด X → เด้ง dialog ถาม 3 ตัวเลือก
- [ ] กด "บันทึกร่าง" → บันทึกจริง ปิดหน้าจอ, Draft โผล่ใน tab "ร่าง" ของ Profile ตัวเอง
- [ ] กด "ทิ้ง" → ปิดหน้าจอโดยไม่บันทึกอะไรเลย (ถ้าเป็น Draft เดิมที่เปิดมาแก้ ค่าที่แก้ไม่ถูกบันทึก แต่ Draft เดิมยังอยู่เหมือนเดิม)
- [ ] กด "ยกเลิก" → dialog ปิด อยู่หน้าเดิมต่อ ไม่มีอะไรเกิดขึ้น
- [ ] ไม่มีเนื้อหาอะไรเลย (ไม่ได้เลือกรูป/ไม่ได้พิมพ์อะไร) กด X → ปิดทันทีไม่เด้ง dialog
- [ ] แตะ Draft จาก tab "ร่าง" → เปิด Create Drop prefill เนื้อหาครบ (โหมด/รูป/แคปชัน/ตัวเลือกโพล/ระยะเวลา) ตรงกับที่บันทึกไว้ทุกจุด
- [ ] แก้ไข Draft แล้วกด "บันทึกร่าง" ซ้ำ → อัปเดตร่างเดิม ไม่มีร่างซ้ำโผล่ขึ้นมาใหม่
- [ ] เปิด Draft แล้วกด "แชร์" → สร้าง Drop จริงสำเร็จ + Draft หายจาก tab "ร่าง" อัตโนมัติ
- [ ] Draft ที่ยังไม่ครบเงื่อนไขแชร์จริง (เช่น โพลมีตัวเลือกเดียว) เปิดมาแล้วปุ่ม "แชร์" ต้อง disabled เหมือนตอนพิมพ์ใหม่ปกติ (ไม่ข้าม validate)
- [ ] ลบ Draft จาก tab "ร่าง" โดยตรงได้ (ไม่ต้องเปิดเข้าไปก่อน) พร้อมยืนยันก่อนลบ
- [ ] ผู้ใช้ที่ถูก Restrict บันทึก Draft ได้ปกติ แต่กด "แชร์" ไม่ได้เหมือนเดิม (ระบบเดิม)
- [ ] Draft ของ user A ไม่มีทางเห็นได้จาก user B เลยไม่ว่าทางไหน (ตรวจสอบด้วย SQL โดยตรงด้วย role `authenticated`)
- [ ] tab "ร่าง" ไม่โผล่เมื่อดู Profile คนอื่น (เห็นเฉพาะโปรไฟล์ตัวเอง)
- [ ] Regression: Drop/Poll ที่แชร์ปกติ (ไม่ผ่าน Draft) ทำงานเหมือนเดิมทุกจุด, Home Feed/ranking/Like/Comment/ReDrop เดิมไม่เปลี่ยนแปลง

Dependencies: WYN-005 (Drop core), WYN-035 (Poll — Draft ต้อง prefill โหมดโพลได้ด้วย, reuse `PollPlaceholderTile`), WYN-013 (Profile tabs pattern เดิมที่ tab "ร่าง" มิเรอร์ตาม) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P1 — task ที่สามของ Phase 3 ตามลำดับ Roadmap ต่อจาก WYN-034/WYN-035

Risks:
- **ไม่มีปุ่ม "บันทึกร่าง" แยกต่างหาก** — ทางเดียวที่จะ Save Draft คือกด X แล้วเจอ dialog เท่านั้น ตัดเพื่อลด UI clutter (ไม่ต้องมีทั้งปุ่ม "แชร์" และ "บันทึกร่าง" แย่งพื้นที่ AppBar) มิเรอร์ pattern ของแอปส่วนใหญ่ (Twitter/IG) ที่ก็ใช้ close-intercept เป็นทางเข้าเดียวกันเช่นกัน — ถ้า Founder ต้องการปุ่มแยกชัดเจนกว่านี้ต้องแจ้งเป็น follow-up
- **ไม่มี auto-save ระหว่างพิมพ์** (เช่น ทุก 10 วินาที) — บันทึกเฉพาะตอนกด X + เลือก "บันทึกร่าง" เท่านั้น แอปถูก kill กลางคันจะเสียเนื้อหาที่ยังไม่ได้บันทึกทั้งหมด (ไม่ต่างจากพฤติกรรมปัจจุบันที่ไม่มี Draft เลย) — ยอมรับความเสี่ยงนี้เพื่อความเรียบง่าย ถ้า Founder ต้องการ auto-save ต้องแจ้งเป็น follow-up
- **ไม่จำกัดจำนวน Draft ต่อผู้ใช้** — มิเรอร์ ReDrop/Saved ที่ไม่จำกัดเช่นกัน ถ้าเป็นปัญหาจริงในอนาคต (สแปม Draft) ค่อยเพิ่ม limit ทีหลัง
- **Mention ในแคปชันของ Draft ไม่ถูกบันทึกแยกเป็น mentioned_user_ids** — เก็บแค่ raw text ของแคปชัน (รวม @mention/#hashtag ที่พิมพ์ไว้) ไม่ได้เก็บ resolved user id แยก เพราะ mention resolution ผูกกับ `MentionInput`'s interactive autocomplete widget ที่ยังไม่ trigger ใหม่จนกว่าจะพิมพ์/แก้ข้อความส่วนนั้นอีกครั้งตอนเปิด Draft — ถ้าผู้ใช้เปิด Draft แล้วกด "แชร์" ทันทีโดยไม่แตะแคปชันเลย mention เดิมอาจไม่ถูกบันทึกเป็น notification จริง (ตัวอักษร @username ยังอยู่ในข้อความเหมือนเดิม แค่ไม่ trigger `drop_mentions` insert) — ยอมรับเป็น scope reduction ที่สมเหตุสมผลเพราะ Draft ส่วนใหญ่ถูกเปิดมาเพื่อแก้ไขต่ออยู่แล้วไม่ใช่กด แชร์ ทันที

Recommendation:
1. Schema เพิ่ม 1 ตารางใหม่ `drop_drafts` (`author_id`, `image_url` nullable, `caption` nullable, `poll_options` nullable text[], `poll_duration_days` nullable int, `updated_at`) — RLS **แค่ 4 policy จำกัดทุกอย่างไว้ที่ `auth.uid() = author_id` เท่านั้น** (select/insert/update/delete) ไม่มี policy ให้คนอื่นเห็นเลยแม้แต่บรรทัดเดียว — CHECK ของ `poll_options` หลวมกว่า `drop_polls` เดิม (แค่ไม่เกิน 4 ช่อง ไม่ต้องครบ 2/ไม่ต้อง unique) เพราะ Draft ไม่ต้องสมบูรณ์
2. **ไม่แตะ `drops`/`home_feed`/`drop_polls` เลยแม้แต่บรรทัดเดียว** — Draft เป็นระบบแยกเต็มรูปแบบ การแชร์จาก Draft ใช้ `createDrop()`/`createPollDrop()` เดิมที่มีอยู่แล้วตรงๆ ไม่สร้าง RPC ใหม่ (ต่างจาก WYN-035 ที่ต้อง atomic เพราะมีหลายตารางเกี่ยวพันกัน — ที่นี่แค่ "สร้าง Drop ปกติ แล้วลบ Draft" เป็น 2 ขั้นตอนแยกกันได้ ไม่ critical ต้อง atomic เพราะ Draft ที่เหลือค้างอยู่ถ้าขั้นลบล้มเหลวไม่ใช่ security/data-integrity issue แค่ต้องลบมือทีหลัง)
3. Design ควร reuse close-button (X) เดิมเป็นทางเข้า Save Draft ผ่าน `PopScope` (ครอบคลุมทั้งปุ่ม X และปุ่ม back ของระบบด้วยกลไกเดียวกัน) แทนที่จะเพิ่มปุ่มใหม่
4. Coding ต้องรองรับกรณี "แก้ไข Draft เดิมแล้วบันทึกซ้ำ = update" ไม่ใช่ insert ใหม่ทุกครั้ง (เก็บ draft id ไว้ใน state ของหน้า Create Drop)

Handoff: AI Design — ออกแบบ close-intercept dialog (3 ตัวเลือก), การ prefill หน้า Create Drop จาก Draft (โหมดรูป/โพล/ระยะเวลา), tab "ร่าง" ใหม่ใน Profile (mirror tab "บันทึก" เดิม), grid tile ของ Draft (reuse `PollPlaceholderTile` สำหรับ Draft แบบโพล), schema เบื้องต้นที่แนะนำ (`drop_drafts` + RLS 4 policy) ให้ AI Coding ต่อยอดได้ทันที

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): ตารางใหม่ 1 ตัว `drop_drafts` (`author_id`, `image_url`/`caption`/`poll_options`/`poll_duration_days` ล้วน nullable, `created_at`/`updated_at`) — CHECK ใหม่ `valid_draft_poll_options()` (immutable function) หลวมกว่า `valid_poll_options()` ของ WYN-035 โดยตั้งใจ (แค่ 2-4 ช่อง + ยาวไม่เกิน 80 ตัวอักษรต่อช่อง ไม่บังคับครบ/ไม่บังคับ unique เพราะ Draft ยังไม่ต้องสมบูรณ์) — RLS 4 policy จำกัดทุกอย่างไว้ที่ `auth.uid() = author_id` เท่านั้น ไม่มี policy ให้คนอื่นเห็นเลยแม้แต่บรรทัดเดียว (ต่างจาก ReDrop/Poll ที่ piggyback SELECT บน policy ของตารางอื่น) — **ไม่แตะ `drops`/`home_feed`/`notifications`/`reports` เลยแม้แต่บรรทัดเดียว** ตามที่ Product ตัดสินใจไว้ (Draft เป็นระบบแยกเต็มรูปแบบ)

**Flutter**: `DropDraft` model ใหม่ (`fromMap`, `isPoll` getter) — `DropRepository` เพิ่ม `fetchDrafts()`/`saveDraft()` (insert เมื่อ `draftId == null` มิฉะนั้น update ทับแถวเดิม กัน Draft ซ้ำตอนบันทึกซ้ำ)/`deleteDraft()`/`createDropFromExistingImage()` (publish จาก Draft โดยไม่ re-upload รูปที่อัปโหลดไว้แล้ว — สกัดตรรกะ insert ร่วมของ `createDrop()`/`createDropFromExistingImage()` ออกเป็น `_insertDropWithImageUrl()` ส่วนตัว) — widget ใหม่ 2 ตัว: `DraftGridTile` (reuse `PollPlaceholderTile` ของ WYN-035 สำหรับ Draft แบบโพล, long-press ลบพร้อมยืนยัน) และ `ProfileDraftsTab` (tab "ร่าง" ใหม่ใน Profile ของตัวเอง, mirror `ProfileSavedTab`) — `CreateDropScreen` รับ `draft` param ใหม่, `_prefillFromDraft()` copy เนื้อหา Draft เข้า state ทั้งหมดตอน `initState()`, ห่อ `Scaffold` ด้วย `PopScope<bool>` (`canPop: !_hasUnsavedContent`) ให้ทั้งปุ่ม X และปุ่ม back ของระบบวิ่งผ่าน `_handleClose()` เดียวกัน (ยืนยันจาก Flutter framework source ว่า `Navigator.pop()` ตรงๆ ข้าม `canPop` เสมอ ไม่มีความเสี่ยง infinite loop) — dialog 3 ปุ่ม "บันทึกร่าง"/"ทิ้ง"/"ยกเลิก" ตาม Design spec เป๊ะ

**บั๊กจริงที่พบและแก้ระหว่างเขียนโค้ด (เปิดเผยตามธรรมเนียมโปรเจกต์)**: ไม่มี — Coding เขียนตาม Design spec ตรงๆ ไม่พบปัญหาระหว่างพัฒนา (บั๊กจริง 1 จุดถูกพบภายหลังโดย Independent QA ด้านล่าง ไม่ใช่ระหว่าง Coding)

**Tests**: `flutter analyze` สะอาด 0 issues — `flutter test` **575/575 ผ่าน** ก่อนรอบ QA (เพิ่มจาก 553 เดิม: `drop_draft_test.dart` ใหม่ 3 เคส, `draft_grid_tile_test.dart` ใหม่ 4 เคส, `profile_drafts_tab_test.dart` ใหม่ 5 เคส, `create_drop_screen_test.dart` +18 เคส [กลุ่ม "Draft (WYN-036)"], `view_profile_screen_test.dart` แก้ 1 เคสเดิมที่พังจากการเพิ่ม tab ที่ 5)

**SQL live verification**: เขียน `supabase/tests/wyn_036_draft_system_test.sh` ใหม่ (15 checks) รันภายใต้ role `authenticated` จริง ครอบ: insert/update ในที่เดิม (ไม่สร้างซ้ำ), คนอื่นอ่าน/แก้/ลบ Draft คนอื่นไม่ได้ (0-row no-op), ผู้ใช้ Restricted ยัง Draft ได้, `valid_draft_poll_options()` reject ตัวเลือกเกิน 4/ยาวเกิน 80 ตัวอักษร แต่ accept ตัวเลือกไม่ครบ/ซ้ำได้ (ตามเจตนา), ลบ profile cascade ลบ Draft, regression Drop/Poll ปกติยังทำงาน — **15/15 PASS** — รันซ้ำ 9 สคริปต์เดิมทั้งหมดไม่มี cross-task regression

**Acceptance Criteria — ไล่ตรวจครบทั้ง 14 ข้อ**: กด X มีเนื้อหาเด้ง dialog ✓, "บันทึกร่าง" บันทึกจริง+ปิดหน้า+โผล่ใน tab "ร่าง" ✓, "ทิ้ง" ปิดไม่บันทึก ✓, "ยกเลิก" อยู่หน้าเดิม ✓, ไม่มีเนื้อหากด X ปิดทันทีไม่เด้ง dialog ✓, แตะ Draft prefill ครบทุกจุด ✓, บันทึกซ้ำอัปเดตไม่สร้างซ้ำ ✓, แชร์จาก Draft สำเร็จ+ลบ Draft อัตโนมัติ ✓, Draft ไม่ครบเงื่อนไขปุ่มแชร์ disabled เหมือนพิมพ์ใหม่ ✓, ลบ Draft ตรงจาก list ได้พร้อมยืนยัน ✓, Restricted บันทึกได้แต่แชร์ไม่ได้ ✓, Draft คนอื่นเห็นไม่ได้เลย (พิสูจน์ด้วย SQL role `authenticated` จริง) ✓, tab "ร่าง" ไม่โผล่ดู Profile คนอื่น ✓, regression Drop/Poll ปกติไม่เปลี่ยนแปลง ✓ — **ครบทุกข้อ**

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS (1 bug ตัวจริงพบและแก้ก่อนอนุมัติ)

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — task นี้มี Draft state (โหมดรูป/`_imageBytes`/`_existingImageUrl` vs โหมดโพล/`_pollOptionControllers`) ที่อยู่ร่วมกันใน widget เดียว ต้องตรวจการสลับโหมดกลางคันเป็นพิเศษว่า state เก่าไม่รั่วไหลข้ามโหมด

**สิ่งที่ทำ**:
1. อ่าน `git diff` ทั้งหมดของ task นี้โดยตรงทุกไฟล์ (schema/`drop_repository.dart`/`create_drop_screen.dart`/`view_profile_screen.dart`/widget ใหม่ 2 ตัว) ไม่เชื่อสรุปจาก Coding Output
2. รัน `flutter analyze`/`flutter test` อิสระเอง — ตรงกัน: 0 issues, 576/576 (นับรวมเคสใหม่ที่ QA เพิ่มด้านล่าง)
3. ตรวจ RLS ทั้ง 4 policy ของ `drop_drafts` ทีละบรรทัด — ยืนยันไม่มี exception/piggyback visibility ให้ใครนอกจากเจ้าของเลย
4. ไล่ path การสลับโหมด (`SegmentedButton.onSelectionChanged`) พบว่า**ไม่เคย clear** `_imageBytes`/`_existingImageUrl` ตอนสลับไปโหมดโพล — ตรวจว่า `_share()`/`_canShare` gate ด้วย `_mode == _ComposeMode.image` ถูกต้องอยู่แล้ว (publish ไม่รั่ว) แต่ **`_saveDraftAndClose()` ส่ง `imageBytes`/`existingImageUrl` แบบไม่ gate ตาม mode เลย** — เขียน test จำลองสถานการณ์จริง (เปิด Draft แบบมีรูป → สลับเป็นโหมดโพล → กรอกตัวเลือก → กด X → "บันทึกร่าง") ยืนยันว่า test **fail จริงกับโค้ดเดิม** (อัปโหลดรูปทิ้งเปล่าๆ + บันทึก `image_url` ปนเข้าไปในแถว Draft ที่ควรเป็นโพลล้วน) แล้วแก้โดย gate `imageBytes`/`existingImageUrl` ด้วย `_mode == _ComposeMode.image` ใน `_saveDraftAndClose()` — รัน test ซ้ำผ่านกับโค้ดที่แก้แล้ว ยืนยันทั้งสองทิศ (fail ก่อนแก้ / pass หลังแก้) ก่อนสรุปว่าแก้จริง
5. **Widget test gotcha เดิม (WYN-035 เคยเจอ) เกิดซ้ำ**: พบว่า `profile_drafts_tab_test.dart` ที่ Coding เขียนไว้สร้าง `RecordingDropRepository()`/`RecordingProfileRepository()` ข้างใน `testWidgets` body ตรงๆ (ไม่ใช่ `setUpAll`) ทำให้รัน full suite ร่วมกับไฟล์อื่นแล้วเจอ "A Timer is still pending" 5 เคส (แม้รันแยกไฟล์เดี่ยวๆ ผ่านหมด — เป็น pattern ที่ปรากฏเฉพาะตอนรันรวมกับ suite ทั้งหมดเพราะ FakeAsync zone ถูกแชร์ข้ามไฟล์) — แก้โดยย้าย instance ทั้งหมดไปสร้างใน `setUpAll` ตามธรรมเนียมเดิมของโปรเจกต์ รันซ้ำผ่านทั้งไฟล์เดี่ยวและ full suite
6. รัน SQL regression ทั้ง 10 สคริปต์ (`wyn_021` ถึง `wyn_036`) อิสระเอง — ตรงกัน: 196/196 checks ผ่านหมด ไม่มี cross-task regression
7. ไล่เทียบ Acceptance Criteria ทั้ง 14 ข้อกับโค้ดจริงทีละข้อ (ไม่ใช่แค่เชื่อ checklist ที่ Coding ทำเครื่องหมายไว้) — ครบทุกข้อ
8. ตรวจ `DropDraft.fromMap`/`draft_grid_tile.dart`/`profile_drafts_tab.dart` ทีละบรรทัด ไม่พบปัญหาเพิ่มเติม

**ผลลัพธ์**: **WYN-036 — PASS** (หลังแก้ 1 bug ตัวจริงที่ QA พบ) — `flutter analyze` 0 issues, `flutter test` 576/576 (575 เดิม + 1 regression test ใหม่ที่ QA เพิ่มเพื่อยืนยันบั๊ก+การแก้), SQL regression 15/15 ของ WYN-036 เอง + 196/196 รวมทั้ง 10 สคริปต์ ไม่มี cross-task regression

Handoff: AI Deploy & DevOps — commit/push/PR/merge/deployment log
