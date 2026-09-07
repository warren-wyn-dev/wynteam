# Product Task — WYN-132

Status: ready-for-coding — AI Design ทำ spec เต็มแล้ว (2026-09-07) — Founder อนุมัติ wireframe ข้อความแทน visual mockup แล้ว ไม่มีจุดค้าง พร้อมส่ง AI Coding
Owner: AI Design → AI Coding

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

Design spec เต็มที่ `.wyn/docs/design/wyn-132-dm-message-edit-pin.md` — ตรวจ schema จริงของ `messages`/`delete_message()`/realtime subscription เดิมแล้ว สรุปการตัดสินใจหลัก:

- **Edit**: คอลัมน์ใหม่ `messages.edited_at`, RPC `edit_message()` mirror `delete_message()`'s ท่าเดิม (security definer, ไม่มี client UPDATE policy) — จำกัดเข้มงวดเฉพาะข้อความ text ล้วน (`image_url is null and shared_content_id is null`) ตาม Requirement เป๊ะ — reuse realtime `onUpdate` channel เดิมที่มีอยู่แล้วสำหรับ View Once ได้ตรงๆ ไม่ต้อง subscribe เพิ่ม
  - **พบจุดที่ต้องระวังจากการอ่านโค้ดจริง**: `_onRealtimeMessageUpdate` ปัจจุบันแทนที่ทั้งแถวจาก raw payload (ไม่มี `reply_to` embed) — ถ้าข้อความที่แก้ไขเป็น reply จะทำให้ reply-quote preview หายจากหน้าจอฝั่งอีกคนชั่วคราว ต้อง merge เฉพาะฟิลด์ที่เปลี่ยน ไม่ใช่แทนที่ทั้งก้อน (ระบุไว้ในเอกสารเป็นข้อควรระวังให้ AI Coding)
- **Pin**: ตารางใหม่ `message_pins` (composite PK `conversation_id, message_id`), RPC `pin_message()`/`unpin_message()` (จำกัด 3 ต่อบทสนทนา, ทั้งสองฝ่าย pin/unpin ได้เท่ากันตาม Requirement) + แก้ `delete_message()` เดิมให้ auto-unpin (เพราะเป็น soft-delete ผ่าน UPDATE ไม่ใช่ DELETE จริง FK cascade ใช้ไม่ได้)
- Pinned bar ใต้ AppBar + bottom sheet รายการปักหมุด reuse กลไก jump-to-message เดิมจาก reply-quote (WYN-031) ตรงๆ
- Realtime pin/unpin: channel เบาๆ แบบเดียวกับ `subscribeToConversationMeta` — fetch รายการใหม่ทั้งหมดทุกครั้งที่มี event (ไม่ patch จาก payload เพื่อเลี่ยงปัญหา REPLICA IDENTITY ของ DELETE payload)
- มี UI ใหม่จริง (edit-mode composer bar, pinned bar, pinned bottom sheet) → ต้องมี visual mockup ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" — session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความในเอกสาร
- แนะนำ gate ด้วย Staged Rollout (WYN-125) เพราะมี UI ใหม่จริงที่ผู้ใช้ทั่วไปยังไม่เคยเห็น

Handoff: **รอ Founder ยืนยัน 1 เรื่อง** — wireframe ข้อความในเอกสารเพียงพอสำหรับอนุมัติ หรือรอ session ที่มีเครื่องมือสร้างภาพ mockup จริงก่อน — หลังยืนยันแล้วส่งต่อ AI Coding ได้ทันที (schema/RPC/RLS พร้อมสมบูรณ์แล้ว ไม่มีจุดกำกวมด้าน technical)
