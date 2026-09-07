# Product Task — WYN-138

Status: go-live package พร้อมแล้ว (2026-09-07) — รอ Founder ดำเนินการ deploy จริง (merge → migration → deploy web) ดู `.wyn/logs/deployments/2026-09-07-wyn-134-136-137-138-139-phase-a-go-live-package.md`
Owner: AI Design → AI Coding → AI QA & Security → AI Deploy & DevOps → รอ Founder ดำเนินการ deploy จริง

Feature: DM Message Actions — Edit Message + Pin Message (1:1 Chat)

Goal: ให้ผู้ใช้แก้ไขข้อความที่ส่งไปแล้วได้ (ข้อความ text) และปักหมุดข้อความสำคัญไว้ดูง่ายในบทสนทนา 1:1 — ตรงกับสเปกข้อ 10 (Edit Message, Pin Message)

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031/032)

Problem: WYN-031 ออกแบบไว้ให้ **ลบ**ข้อความได้ (soft delete) แต่ไม่มี **แก้ไข**เลย — พิมพ์ผิด/อยากเปลี่ยนคำ ต้องลบทิ้งแล้วพิมพ์ใหม่ ทำให้บทสนทนาขาดความต่อเนื่อง — และไม่มีทาง "ปักหมุด" ข้อความสำคัญ (เช่น นัดเวลา/ที่อยู่/ลิงก์) ให้หาเจอง่ายทีหลัง ต้อง scroll ย้อนหาเองอย่างเดียว

Requirements:

**Edit Message**
- แก้ไขได้เฉพาะข้อความ**ของตัวเอง** และเฉพาะ**ข้อความ text** เท่านั้น (ไม่รองรับแก้ image message รอบนี้ — ถ้าอยากเปลี่ยนรูป ให้ลบแล้วส่งใหม่เหมือนเดิม)
- ไม่จำกัดเวลาแก้ไข (มิเรอร์ Drop Edit ที่ไม่มี time window เดิม — ไม่สร้างกติกาใหม่ที่ไม่สอดคล้องกับส่วนอื่นของระบบ)
- ข้อความที่แก้ไขแล้วต้องแสดง label "แก้ไขแล้ว" (edited indicator) ถาวรติดกับข้อความนั้นเสมอ — **ห้ามซ่อน** เพื่อความโปร่งใส (ป้องกันการใช้ edit หลอกลวงอีกฝ่ายว่าพิมพ์อะไรไปตอนแรก)
- ไม่เก็บ/แสดงประวัติการแก้ไขเดิม (overwrite ตรงๆ) — เป็นข้อจำกัดที่ยอมรับไว้รอบนี้ ถ้า Founder ต้องการดู edit history แบบ Slack/Discord ทีหลัง ทำเป็น fast-follow แยก

**Pin Message**
- ผู้เข้าร่วมบทสนทนา**ฝ่ายใดฝ่ายหนึ่งก็ปักหมุดได้** (ต่างจาก Club Chat ที่จำกัดสิทธิ์เฉพาะ Admin — ดู WYN-135 — เพราะ DM เป็นบทสนทนาระหว่างคน 2 คนที่เท่าเทียมกัน ไม่มีลำดับชั้น)
- จำกัดจำนวนข้อความที่ปักหมุดพร้อมกันได้สูงสุด **3 ข้อความต่อบทสนทนา** (ป้องกันการปักหมุดจนรก มิเรอร์ pattern ทั่วไปของแอปแชทที่คุ้นเคย) — ปักเกินต้อง unpin อันเก่าก่อน
- ข้อความที่ปักหมุดแล้วแสดงในแถบ/ปุ่มแยกที่หัวบทสนทนา แตะแล้ว jump ไปยังตำแหน่งข้อความจริง
- ข้อความที่ถูกลบไปแล้วต้องถูก unpin อัตโนมัติ (ไม่ปล่อยให้ pinned bar ชี้ไปยังข้อความที่ไม่มีอยู่จริง)

Acceptance Criteria:
- [ ] แก้ไขข้อความ text ของตัวเองได้ ข้อความแสดง "แก้ไขแล้ว" ทันที
- [ ] แก้ไขข้อความของคนอื่น/ข้อความรูปภาพไม่ได้
- [ ] ปักหมุดข้อความได้สูงสุด 3 ข้อความต่อบทสนทนา ทั้งสองฝ่ายปักได้เท่ากัน
- [ ] แตะข้อความที่ปักหมุด → jump ไปตำแหน่งจริงในบทสนทนา
- [ ] ลบข้อความที่ปักหมุดอยู่ → หายจากรายการปักหมุดอัตโนมัติ

Dependencies: WYN-031 (Chat 1:1 — เพิ่มคอลัมน์/ตารางใหม่บน `messages`/`conversations` เดิม)

Priority: P2 — ปรับปรุงประสบการณ์ที่มีอยู่แล้ว ไม่ใช่ความสามารถใหม่เชิงกลยุทธ์

Risks: Edit message มีความเสี่ยงด้าน trust เล็กน้อย (บรรเทาแล้วด้วย edited-indicator ถาวรที่ห้ามซ่อน) — ไม่มีความเสี่ยงเชิงสถาปัตยกรรม เป็นการต่อยอด schema เดิมตรงๆ

Recommendation: อนุมัติ scope ได้ทันที ไม่ต้องขออนุมัติ Founder เพิ่มเติม (ไม่แตะ Major Architecture)

Handoff: รอ Founder ยืนยัน priority ของ Phase A ทั้งชุดก่อนส่งต่อ AI Design

## AI Design Output (2026-09-07)

Design spec เต็มที่ `.wyn/docs/design/wyn-138-dm-message-edit-pin.md` — ตรวจ schema จริงของ `messages`/`delete_message()`/realtime subscription เดิมแล้ว สรุปการตัดสินใจหลัก:

- **Edit**: คอลัมน์ใหม่ `messages.edited_at`, RPC `edit_message()` mirror `delete_message()`'s ท่าเดิม (security definer, ไม่มี client UPDATE policy) — จำกัดเข้มงวดเฉพาะข้อความ text ล้วน (`image_url is null and shared_content_id is null`) ตาม Requirement เป๊ะ — reuse realtime `onUpdate` channel เดิมที่มีอยู่แล้วสำหรับ View Once ได้ตรงๆ ไม่ต้อง subscribe เพิ่ม
  - **พบจุดที่ต้องระวังจากการอ่านโค้ดจริง**: `_onRealtimeMessageUpdate` ปัจจุบันแทนที่ทั้งแถวจาก raw payload (ไม่มี `reply_to` embed) — ถ้าข้อความที่แก้ไขเป็น reply จะทำให้ reply-quote preview หายจากหน้าจอฝั่งอีกคนชั่วคราว ต้อง merge เฉพาะฟิลด์ที่เปลี่ยน ไม่ใช่แทนที่ทั้งก้อน (ระบุไว้ในเอกสารเป็นข้อควรระวังให้ AI Coding)
- **Pin**: ตารางใหม่ `message_pins` (composite PK `conversation_id, message_id`), RPC `pin_message()`/`unpin_message()` (จำกัด 3 ต่อบทสนทนา, ทั้งสองฝ่าย pin/unpin ได้เท่ากันตาม Requirement) + แก้ `delete_message()` เดิมให้ auto-unpin (เพราะเป็น soft-delete ผ่าน UPDATE ไม่ใช่ DELETE จริง FK cascade ใช้ไม่ได้)
- Pinned bar ใต้ AppBar + bottom sheet รายการปักหมุด reuse กลไก jump-to-message เดิมจาก reply-quote (WYN-031) ตรงๆ
- Realtime pin/unpin: channel เบาๆ แบบเดียวกับ `subscribeToConversationMeta` — fetch รายการใหม่ทั้งหมดทุกครั้งที่มี event (ไม่ patch จาก payload เพื่อเลี่ยงปัญหา REPLICA IDENTITY ของ DELETE payload)
- มี UI ใหม่จริง (edit-mode composer bar, pinned bar, pinned bottom sheet) → ต้องมี visual mockup ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" — session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความในเอกสาร
- แนะนำ gate ด้วย Staged Rollout (WYN-125) เพราะมี UI ใหม่จริงที่ผู้ใช้ทั่วไปยังไม่เคยเห็น

Handoff: **รอ Founder ยืนยัน 1 เรื่อง** — wireframe ข้อความในเอกสารเพียงพอสำหรับอนุมัติ หรือรอ session ที่มีเครื่องมือสร้างภาพ mockup จริงก่อน — หลังยืนยันแล้วส่งต่อ AI Coding ได้ทันที (schema/RPC/RLS พร้อมสมบูรณ์แล้ว ไม่มีจุดกำกวมด้าน technical)

Founder ยืนยันแล้ว 2026-09-07 (ดู `.wyn/company/DECISIONS.md` entry "[2026-09-07] Social 3-Domain Roadmap") — ไม่มีจุดค้าง ส่งต่อ AI Coding

## AI Coding Output (2026-09-07)

Implementation ครบทั้งฝั่ง SQL และ Flutter ตาม design spec ตรงๆ ไม่มีจุดที่ต้องเบี่ยงจาก spec:

- **Schema**: `supabase/schema.sql` มี `messages.edited_at`, `edit_message()`, ตาราง `message_pins` + RLS SELECT policy, `pin_message()`/`unpin_message()`, `delete_message()` เวอร์ชันใหม่ที่ auto-unpin — commit จาก session ก่อนหน้า (`a4a204b`) ตรวจสอบแล้วตรงกับ design spec 100% ใช้ต่อได้เลย + เพิ่ม `supabase/migrations_wyn138_dm_message_edit_pin.sql` เป็น standalone migration แยกตาม convention ของโปรเจกต์ (commit `61e3e97`)
- **Flutter data layer**: `ChatMessage.editedAt`/`isEdited` ใหม่ (`chat_message.dart`), `PinnedMessage` model ใหม่ (`pinned_message.dart`), `ChatRepository` เพิ่ม `editMessage()`/`pinMessage()`/`unpinMessage()`/`fetchPinnedMessages()`/`subscribeToConversationPins()` + เพิ่ม `edited_at` เข้า `_messageColumns` select เดิม
- **Flutter UI (`conversation_screen.dart`)**: เมนู long-press เพิ่ม 2 แถวใหม่ "แก้ไข"/"ปักหมุดข้อความ"-"เลิกปักหมุด" (ทั้งคู่ gate ด้วย `isDeveloperAccount()` ตาม Staged Rollout), composer เปลี่ยนเป็น edit mode (แถบ "กำลังแก้ไขข้อความ" + prefill text + ปุ่มส่งเปลี่ยนเป็น ✓), บับเบิลแสดง label "แก้ไขแล้ว" ถาวรเมื่อ `isEdited` (**ตั้งใจไม่ gate ด้วย Staged Rollout** — ต่างจากเมนู/pinned bar เพราะ Requirement บังคับ "ห้ามซ่อน" เพื่อความโปร่งใส และ design spec's Staged Rollout note ระบุแค่ 2 จุดที่ต้อง gate ชัดเจน [เมนู 2 แถวใหม่ + pinned bar] ไม่รวม label — บันทึกเหตุผลไว้ใน comment ในโค้ดแล้ว), Pinned bar ใต้ AppBar + bottom sheet "ข้อความที่ปักหมุด" (reuse `_scrollToMessage` เดิมจาก reply-quote)
- **แก้จุดเสี่ยงที่ AI Design เตือนไว้**: `_onRealtimeMessageUpdate` เดิมแทนที่ทั้งแถวจาก raw payload ตรงๆ (ทำให้ reply preview หายชั่วคราวถ้า UPDATE เกิดกับข้อความที่เป็น reply) — แก้เป็น merge เฉพาะฟิลด์ที่เปลี่ยนจริง คงค่า `replyPreviewText`/`replyPreviewImageUrl`/`replyPreviewDeletedAt` เดิมไว้เสมอ (ปลอดภัยเพราะ `reply_to_message_id` ไม่เคยเปลี่ยนจาก UPDATE ใดๆ ในระบบนี้) — มี regression test คลุมเคสนี้โดยตรง
- **Test**: เพิ่ม 8 test ใหม่ใน `conversation_screen_test.dart` (non-developer ไม่เห็น UI ใหม่เลยแม้มีข้อมูล pinned จริง, edit สำเร็จ/ล้มเหลว, edit ไม่มีตัวเลือกสำหรับรูป/ข้อความคนอื่น, pin/unpin ผ่าน bottom sheet, pin cap error, regression test ของจุดเสี่ยง reply-preview) + 1 test ใหม่ใน `chat_model_test.dart` (`edited_at` parsing) — อัปเดต `RecordingChatRepository`/`RecordingDeveloperAccessService` (ใช้ของเดิมที่มีอยู่แล้ว) ให้รองรับ method ใหม่
- **flutter analyze**: 0 issues (ทั้งโปรเจกต์)
- **flutter test**: **1388/1388 PASS** (ทั้งโปรเจกต์ รวม 8 test ใหม่ของ WYN-138 + 1 test ของ `chat_model_test.dart`) — ติดตั้ง Flutter SDK 3.47.2 เองใหม่ในสภาพแวดล้อมนี้เพื่อรันจริง (ไม่มีมาก่อน)

Known Issues / จุดที่ตัดสินใจเอง (ไม่ใช่จุดค้างที่ต้องถาม Founder):
- "แก้ไขแล้ว" label ไม่ gate ด้วย Staged Rollout ตามที่อธิบายไว้ข้างบน — ผลคือถ้าบัญชี developer แก้ไขข้อความใน DM กับผู้ใช้ทั่วไป ฝั่งผู้ใช้ทั่วไปจะเห็น label "แก้ไขแล้ว" ได้ (ไม่เห็นปุ่มเมนู/pinned bar) — ตั้งใจตามเหตุผลด้าน anti-deception ข้างบน ไม่ใช่ bug
- Pin count race condition (2 ฝั่งกดปักหมุดพร้อมกันแย่งช่องที่ 3) ยอมรับความเสี่ยงตามที่ design spec ระบุไว้แล้วว่าเป็น low-risk trade-off ไม่ต้องแก้เพิ่ม

Handoff: ส่งต่อ AI QA & Security

## AI QA & Security Report (2026-09-07)

รายงานเต็ม: `.wyn/docs/qa/2026-09-07-wyn-134-136-137-138-139-phase-a-qa.md`

รัน `flutter analyze`/`flutter test` เองอิสระ (1433/1433 ผ่าน, 0 issues) เขียน regression test SQL ใหม่ (`supabase/tests/wyn_138_dm_message_edit_pin_test.sh`, 13 checks) ทดสอบตรงกับ RPC/RLS จริงบน PostgreSQL 16 (ไม่ใช่แค่ผ่าน UI):

- **แก้ไขข้อความ**: ทดสอบเรียก `edit_message()` ตรงๆ ยืนยันว่าแก้ได้เฉพาะข้อความ text ของตัวเอง — แก้ข้อความคนอื่น/ข้อความรูปภาพ/ข้อความที่ถูกลบ/ข้อความว่างเปล่า ถูกปฏิเสธจริงที่ระดับ RPC ทั้งหมด (ไม่ใช่แค่ UI ซ่อนปุ่ม) ยืนยันไม่มี client UPDATE policy บน `messages` เลย (query `pg_policies` ตรง) — ทางเดียวที่แก้ไขได้คือผ่าน RPC เท่านั้น
- **จุดเสี่ยงสำคัญ: reply-quote preview หายชั่วคราวตอน edit** — ตรวจโค้ด `_onRealtimeMessageUpdate()` จริงยืนยันว่า merge เฉพาะฟิลด์ที่เปลี่ยน (คง `replyPreviewText`/`replyPreviewImageUrl`/`replyPreviewDeletedAt` เดิมไว้) ไม่ใช่แทนที่ทั้งแถวจาก raw payload — แก้จริงตามที่ AI Coding อ้าง มี regression test ยืนยันด้วย
- **Pin cap 3 ข้อความ**: ทดสอบเรียก `pin_message()` ตรงๆ 4 ครั้ง — ปักได้แค่ 3 ครั้งแรก ครั้งที่ 4 ถูกปฏิเสธจริงที่ระดับ RPC (ไม่ใช่แค่ UI)
- **ลบข้อความที่ปักหมุด → auto-unpin**: ทดสอบตรงยืนยันว่า `delete_message()` ลบแถวออกจาก `message_pins` จริง
- ทั้งสองฝ่ายปัก/เลิกปักได้เท่ากัน, non-participant ปักไม่ได้

ไม่พบบั๊ก ไม่พบช่องโหว่ security ตรวจ Staged Rollout gate ครบ (เมนู "แก้ไข"/"ปักหมุดข้อความ" + pinned bar gate ด้วย `isDeveloperAccount()`, ยกเว้น label "แก้ไขแล้ว" ที่ตั้งใจไม่ gate ตามเหตุผล anti-deception — ตรวจแล้วสมเหตุสมผล ไม่ใช่บั๊ก)

**Final Status: PASS**
