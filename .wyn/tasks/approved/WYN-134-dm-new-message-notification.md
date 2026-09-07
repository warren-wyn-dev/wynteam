# Product Task — WYN-134

Status: **Merged เข้า main แล้ว** (PR #311, 2026-09-07) — เหลือรอ Founder รัน migration SQL + deploy edge function + deploy web จริง ดู `.wyn/logs/deployments/2026-09-07-wyn-134-136-137-138-139-phase-a-go-live-package.md`
Owner: AI Design → AI Coding → AI QA & Security → AI Deploy & DevOps → รอ Founder ดำเนินการ deploy จริง

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

## AI Coding Output (2026-09-07)

Implement ตาม design spec ตรงๆ ทุกจุด ตรวจสอบ schema.sql จริงแล้วยืนยันว่า `mark_conversation_read()`/`get_or_create_conversation()`/`conversation_mutes`/`internal.notification_enabled('messages')`/`notifications.conversation_id` ยังตรงกับที่ Design อ้างอิงไว้ 100% ไม่มีจุดขัดแย้ง

**ไม่ gate ด้วย Staged Rollout** ตามที่ Design แนะนำ (ปิด known gap ของ Chat เดิม ไม่ใช่ฟีเจอร์ใหม่) — เข้าเกณฑ์ข้อยกเว้นใน `.wyn/company/WORKFLOW.md`

Files Changed:
- `supabase/schema.sql` — เพิ่ม `'new_message'` เข้า `notifications_type_check` (dynamic drop+recreate pattern เดิม), trigger function ใหม่ `notify_new_message()` + `messages_notify_new_message` trigger, แก้ `mark_conversation_read()` ให้เคลียร์ `is_read` ของ `new_message` แถวที่เกี่ยวข้อง
- `app/lib/features/notification/data/notification.dart` — เพิ่ม `NotificationType.newMessage` + case ใน `_typeFromString`
- `app/lib/features/notification/presentation/notification_list_screen.dart` — เพิ่ม case ใน `_openNotification` (เปิด `ConversationScreen` ตรง mirror `messageRequest`) และ `_messageFor` ("$name ส่งข้อความถึงคุณ")
- `app/lib/features/push/presentation/push_notification_service.dart` — เพิ่ม `case 'new_message':` เข้ากลุ่มเดียวกับ `case 'message_request':`
- `supabase/functions/send-push-notification/_lib.ts` — เพิ่ม `case "new_message":` ใน `messageFor()` (คำเดียวกับฝั่ง Dart เป๊ะ)
- `app/test/notification_list_screen_test.dart` — เพิ่ม fixture `newMessageNotification()` + test group "new_message notification (WYN-134)" (message wording + tap-opens-ConversationScreen)
- `app/test/notification_test.dart` — เพิ่ม parse-test สำหรับ `type: "new_message"` (มิเรอร์ regression test เดิมของ `redrop`/`club_invite`)
- `supabase/functions/send-push-notification/_lib.test.ts` — เพิ่ม test สำหรับ `messageFor("new_message", ...)` และ `buildDataPayload` กับ `type: "new_message"`
- `supabase/tests/wyn_134_dm_new_message_notification_test.sh` — regression test ใหม่ (SQL/RLS/trigger level) รัน 10 checks ผ่านหมด: unread notification เกิดเมื่อ active+ไม่ mute+เปิดแจ้งเตือน, ไม่เกิดซ้ำเมื่อ mute/ปิดแจ้งเตือนหมวด messages, ไม่เกิดเลยสำหรับ conversation ที่ pending, ทำงานถูกทั้ง 2 ทิศทาง (least/greatest user_a/user_b), `mark_conversation_read()` เคลียร์ unread ได้จริงและยังคง reject non-participant/update last_read_at เหมือนเดิม (regression WYN-031)

Reason: ปิด known gap ที่ยอมรับไว้ตั้งแต่ WYN-032 — Private Chat เป็นโดเมนเดียวที่ยังไม่มี "new message" notification ทั้งที่ Club มี WYN-116 แล้ว

Tests:
- `bash supabase/tests/wyn_134_dm_new_message_notification_test.sh` — PASS ทั้ง 10 checks (รันจริงกับ PostgreSQL 16 local)
- `deno test` ใน `supabase/functions/send-push-notification/` — PASS 39/39
- `flutter analyze` (ทั้ง repo) — No issues found
- `flutter test` (ทั้ง repo) — PASS ทั้งหมด (ดู build log ประกอบ)

Build: ไม่มี build step แยกสำหรับงานนี้ (ไม่มี UI ใหม่ที่ต้อง build/ดู mockup)

Known Issues: ไม่มี — push (Database Webhook) อาจมาถึงอุปกรณ์ในเสี้ยววินาทีที่หน้าจอเปิดอยู่พอดีก่อน `markConversationRead()` จะทัน แต่แอปไม่โชว์ OS banner ตอน foreground อยู่แล้ว (พฤติกรรมเดิมของ WYN-016) จึงไม่มีผลกระทบที่ผู้ใช้เห็นจริง ตามที่ Design ระบุไว้แล้วว่ายอมรับได้

Handoff: ส่งต่อ AI QA & Security — ตรวจ 4 AC ตาม Acceptance Criteria ด้านบน (ได้ข้อความใหม่ขณะไม่เปิดหน้า → notification เกิด, เปิดหน้าอยู่พอดี → ไม่ซ้ำ, mute → ไม่มีเลย, pending → ไม่เกิดซ้ำกับ message_request)

## AI QA & Security Report (2026-09-07)

รายงานเต็ม: `.wyn/docs/qa/2026-09-07-wyn-134-136-137-138-139-phase-a-qa.md`

ตรวจสอบอิสระทั้งหมด (ไม่เชื่อผลที่ AI Coding รายงานมาตรงๆ): รัน `flutter analyze`/`flutter test` เองใหม่ (1433/1433 ผ่าน, 0 issues — ตรงกับที่ AI Coding รายงาน) และรัน `supabase/tests/wyn_134_dm_new_message_notification_test.sh` ซ้ำ (10/10 PASS) กับ PostgreSQL 16 จริง ภายใต้ role `authenticated` จริง ไม่ใช่ superuser ตรวจครบทั้ง 4 AC: ข้อความใหม่ขณะไม่เปิดหน้า → notification เกิดจริง, เปิดหน้าอยู่พอดี → `mark_conversation_read()` เคลียร์ unread ไม่ซ้ำ, mute → ไม่มี notification เลย, pending conversation → ไม่เกิดซ้ำกับ `message_request` เดิม ตรวจ regression ของ `mark_conversation_read()` (ยัง update `last_read_at`/reject non-participant เหมือนเดิม) ตรวจ push wording (`_lib.ts`) ตรงกับ `notification_list_screen.dart` คำต่อคำ ไม่โชว์เนื้อหาข้อความจริง (privacy) ตรวจการตัดสินใจไม่ gate ด้วย Staged Rollout ว่าเข้าเกณฑ์ข้อยกเว้นจริง (ปิด known gap ของฟีเจอร์เดิม ไม่ใช่ฟีเจอร์ใหม่ ไม่มี UI ใหม่)

ไม่พบบั๊ก ไม่พบช่องโหว่ security

**Final Status: PASS**
