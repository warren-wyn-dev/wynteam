# Product Task — WYN-134

Status: design-complete — AI Design ทำ spec เต็มแล้ว (2026-09-07) พร้อมส่งต่อ AI Coding ทันที (ไม่มีจุดที่ต้องรอ Founder ตัดสินใจเพิ่ม)
Owner: AI Design → AI Coding

Feature: DM "New Message" Notification

Goal: แจ้งเตือนผู้ใช้เมื่อมีข้อความ DM ใหม่เข้ามาและไม่ได้เปิดหน้าบทสนทนานั้นอยู่ — ปิด known gap ที่ยอมรับไว้ตั้งแต่ WYN-032 อย่างเป็นทางการ ("New Message notification สำหรับบทสนทนาปกติไม่อยู่ในสโคปนี้" — บันทึกไว้ใน `.wyn/tasks/approved/WYN-032-message-request.md`)

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031/032)

Problem: ตอนนี้ผู้ใช้รู้ว่ามีข้อความใหม่ได้แค่ตอนเปิดแอปแล้วเห็น unread badge เอง หรือถ้าเปิดหน้าสนทนาค้างไว้ก็เห็นแบบ realtime — **แต่ถ้าปิดแอปหรืออยู่หน้าจออื่น จะไม่รู้เลยว่ามีคนทักมา** ต่างจาก Club ที่มี WYN-116 (re-engagement notification) แจ้งเตือนเมื่อมีโพสต์ใหม่แล้ว — Private Chat เป็นโดเมนเดียวที่ยังไม่มี notification ประเภทนี้เลย ทั้งที่เป็นความเสี่ยง retention เดียวกับที่ WYN-116 แก้ให้ Club ไปแล้ว

Requirements:
- Notification type ใหม่ `new_message` (โครงสร้างขนานกับ `message_request` ที่มีอยู่แล้วจาก WYN-032 — reuse `notifications` table เดิม ไม่สร้างตารางใหม่)
- ส่งเมื่อมีข้อความใหม่เข้าบทสนทนาที่ `status = 'active'` (ไม่ใช่ pending — pending มี `message_request` แจ้งเตือนแยกอยู่แล้วจาก WYN-032) และผู้รับไม่ได้เปิดหน้าบทสนทนานั้นอยู่ ณ ขณะนั้น (เช็คง่ายๆ ด้วย client state ที่มีอยู่แล้ว ไม่ต้องสร้าง presence system ใหม่สำหรับ task นี้)
- **เคารพ Mute บทสนทนา** ที่มีอยู่แล้วจาก WYN-031 (per-conversation notification mute) — บทสนทนาที่ mute ไว้ ไม่สร้าง notification ใหม่เลย
- v1 เก็บง่าย: 1 ข้อความใหม่ = 1 notification row (ไม่ทำ batching/collapsing "มี X ข้อความใหม่จาก Y" รอบนี้ — เหมือน pattern ที่ WYN-116 ใช้กับ Club) — ถ้าพบว่าบทสนทนาที่คุยถี่มากสร้าง notification รกเกินไปจริงในทางปฏิบัติ ค่อยพิจารณา batching เป็น fast-follow

Acceptance Criteria:
- [ ] ได้รับข้อความใหม่ขณะไม่ได้เปิดหน้าบทสนทนานั้น → เกิด notification `new_message` ทันที
- [ ] เปิดหน้าบทสนทนานั้นอยู่พอดี → ไม่เกิด notification ซ้ำ (มี realtime อยู่แล้วในหน้าจอ)
- [ ] บทสนทนาที่ mute ไว้ → ไม่มี notification เกิดขึ้นเลย
- [ ] บทสนทนาที่ยังเป็น pending (message request) → ไม่เกิด `new_message` ซ้ำกับ `message_request` เดิม

Dependencies: WYN-031 (Chat 1:1, Mute mechanism), WYN-032 (Message Request, `message_request` notification pattern เดิมให้ mirror ตาม), WYN-043 (notification infra)

Priority: **P1 — สูงสุดในกลุ่ม Phase A** เพราะเป็น known gap ที่กระทบ retention โดยตรง คล้ายปัญหาเดียวกับที่ WYN-116 แก้ให้ Club ไปแล้วและ Founder เคยให้ priority สูงตอนนั้นด้วยเหตุผลเดียวกัน

Risks: ต่ำ — ต่อยอด pattern ที่มีอยู่แล้ว (`message_request` notification) ตรงๆ ไม่มีความเสี่ยงเชิงสถาปัตยกรรม ความเสี่ยงเดียวคือ notification volume ถ้าผู้ใช้คุยกันถี่มาก (ยอมรับไว้ใน v1 ตามที่ระบุ)

Recommendation: อนุมัติ scope ได้ทันที แนะนำให้ทำก่อนอันอื่นใน Phase A

Handoff: รอ Founder ยืนยัน priority ของ Phase A ทั้งชุดก่อนส่งต่อ AI Design

## AI Design Output (2026-09-07)

Design spec เต็มที่ `.wyn/docs/design/wyn-134-dm-new-message-notification.md` — ตรวจ schema/pattern จริงของ `conversations`/`messages`/`notifications`/`conversation_mutes`/push infra (WYN-016/031/032/043) แล้ว สรุปการตัดสินใจหลัก:

- Reuse `notifications.conversation_id` เดิม (เพิ่มโดย WYN-032) ตรงๆ ไม่มีคอลัมน์ใหม่ — เพิ่มแค่ `'new_message'` เข้า `notifications_type_check`
- Trigger ใหม่ `notify_new_message()` (`AFTER INSERT ON messages`) mirror `get_or_create_conversation()`'s การ insert `message_request` เดิมเป๊ะ: เช็ค `status='active'`, ไม่ mute, `internal.notification_enabled(recipient, 'messages')`
- **จุดสำคัญที่สุด**: AC "เปิดหน้าบทสนทนาอยู่พอดี → ไม่เกิด notification ซ้ำ" ทำได้โดยไม่ต้องสร้าง presence system ใหม่ — แก้ `mark_conversation_read()` (RPC เดิมที่ `ConversationScreen` เรียกอยู่แล้วทุกครั้งที่ได้รับข้อความ realtime ขณะเปิดหน้าจอ) ให้เคลียร์ `is_read=true` ของ `new_message` แถวที่เกี่ยวข้องไปด้วยในทรานแซคชันเดียวกัน — ไม่ต้องแก้ client เลยสักจุด
- Dart: เพิ่ม `NotificationType.newMessage` (mirror `messageRequest` ทุกจุด: `_typeFromString`, `_messageFor` = "$name ส่งข้อความถึงคุณ", tap → `ConversationScreen` ตรง), เพิ่ม case ใน `push_notification_service.dart` และ `_lib.ts`'s `messageFor()` (ต้องตรงคำต่อคำตามกติกาเดิมของไฟล์นั้น)
- **ตั้งใจไม่โชว์เนื้อหาข้อความจริงใน notification/push** (privacy — ต่างจาก like/comment ที่โชว์ caption โพสต์สาธารณะได้)
- ไม่มี UI ใหม่ที่ต้องมี visual mockup (แค่ 1 แถวข้อความใหม่ในลิสต์แจ้งเตือนเดิม) — ไม่ต้องรอ Artifact ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" เพราะไม่มี "รูป" ใหม่ให้ดู
- แนะนำไม่ gate ด้วย Staged Rollout (WYN-125) เพราะเป็นการปิด known gap ของ Chat ที่มีอยู่แล้ว ไม่ใช่ฟีเจอร์ใหม่ที่ผู้ใช้ต้อง "ค้นพบ" — AI Coding ควรยืนยันกับ Founder อีกครั้งถ้าไม่แน่ใจ

Handoff: AI Coding — ไม่มีจุดที่ต้องรอ Founder ตัดสินใจเพิ่มเติมสำหรับ task นี้ เริ่ม implement ได้ทันที
