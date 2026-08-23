# Product Task — WYN-032

Status: backlog
Owner: AI Product Manager

Feature: Message Request flow (Accept/Delete/Block/Report)

Goal: ป้องกันไม่ให้คนแปลกหน้าส่งข้อความเข้ากล่องข้อความหลักของผู้ใช้ได้โดยตรง — ข้อความแรกจากคนที่ผู้ใช้ยังไม่รู้จัก (ยังไม่ได้ follow) ต้องผ่านการตัดสินใจ Accept/Delete/Block/Report ก่อน — task ที่ 2 ของ Phase 2 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 18: "Message Request: คนที่ไม่รู้จักส่งข้อความ → Accept/Delete/Block/Report"

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031) — โดยเฉพาะผู้ใช้ที่มี follower เยอะ/เป็นที่รู้จัก ซึ่งเสี่ยงโดนข้อความจากคนแปลกหน้าจำนวนมากที่สุด

Problem: WYN-031 (1:1 Chat) เปิดให้ผู้ใช้ทักใครก็ได้ทันทีโดยไม่มี gate ใดๆ เลย — เป็นความเสี่ยง spam/harassment ที่ยอมรับไว้แล้วตั้งแต่ตอนทำ WYN-031 (บันทึกไว้ใน Risks section ของ `.wyn/tasks/approved/WYN-031-chat-1to1.md` ว่า "ยอมรับความเสี่ยงนี้ตาม Roadmap ที่ Founder แยก 2 task ไว้แล้วโดยเจตนา ไม่ใช่ oversight") — WYN-031 เตรียม `conversations.status` column ไว้ล่วงหน้าแล้ว (`'active'`/`'pending'`, insert เป็น `'active'` เสมอในตอนนั้น) เพื่อไม่ต้อง rework schema ก้อนใหญ่ตอนนี้

Requirements:

**นิยาม "คนที่ไม่รู้จัก" (การตัดสินใจหลักของ task นี้)**
- ใช้กติกาแบบ Instagram: ผู้รับ**ยังไม่ได้ follow ผู้ส่ง** ณ เวลาที่เริ่มบทสนทนา = "ไม่รู้จัก" → บทสนทนาเริ่มที่ `status = 'pending'` แทน `'active'`
- ผู้รับ**follow ผู้ส่งอยู่แล้ว** ณ เวลานั้น = "รู้จัก" → `status = 'active'` ทันทีเหมือน WYN-031 เดิมทุกประการ ไม่ผ่าน gate ใดๆ เลย
- ตรวจทิศทางเดียว (follower→following) ไม่ใช่ mutual follow — เพราะเจตนาคือ "ผู้รับเลือกเชื่อใจคนนี้อยู่แล้วหรือไม่" ไม่ใช่ "ทั้งคู่รู้จักกันไหม"
- ประเมินครั้งเดียวตอนสร้างบทสนทนาเท่านั้น (ไม่ re-evaluate ทีหลังถ้า follow สถานะเปลี่ยนไปหลังจากนั้น — มิเรอร์ที่ `status` ของบทสนทนาเป็น one-way state เดิมอยู่แล้วตาม WYN-031)

**ฝั่งผู้รับ (ที่ยังไม่ตัดสินใจ)**
- เห็นข้อความที่ส่งมาได้ปกติ (อ่านได้ ไม่ซ่อน) แต่**พิมพ์ตอบไม่ได้จนกว่าจะกด Accept** — ต้องมี 4 ปุ่มปฏิบัติการชัดเจน: Accept / Delete / Block / Report
  - **Accept**: บทสนทนากลายเป็นปกติทันที (`status → 'active'`) ทั้งสองฝ่ายคุยกันได้เต็มรูปแบบเหมือน WYN-031 ทุกประการนับจากนี้ไป
  - **Delete**: คำขอหายไปจากมุมมองผู้รับทันที — ผู้ส่งไม่ได้รับแจ้งเตือนใดๆ ว่าถูกปฏิเสธ (มิเรอร์พฤติกรรมมาตรฐานที่ผู้ใช้คุ้นเคยจาก Instagram/Messenger) — ถ้าผู้ส่งทักมาใหม่อีกครั้งในอนาคต เริ่มคำขอใหม่ตามปกติ (ไม่มี cooldown/บล็อกถาวรจากการ Delete เพียงอย่างเดียว)
  - **Block**: reuse กลไก Block เดิมของ WYN-027 ตรงๆ (`block_user()`) — ผู้ส่งส่งข้อความหาไม่ได้อีกต่อไปเลย (ผ่าน `internal.is_blocked_either_way()` ที่ WYN-031 ใช้อยู่แล้ว)
  - **Report**: reuse กลไก Report เดิมของ WYN-026 ตรงๆ (`submit_report()`, `target_type = 'user'` — รายงานตัวบุคคลที่ทักมา ไม่ใช่ข้อความเดี่ยว เพราะเจตนาของปุ่มนี้คือ "รายงานคนที่ทักมาแบบไม่พึงประสงค์") — ยังรายงานข้อความเดี่ยวได้แยกต่างหากผ่านเมนู long-press เดิมของ WYN-031 ถ้าต้องการ (`target_type = 'message'`)

**ฝั่งผู้ส่ง (ที่รอการตอบรับ)**
- ยังคงพิมพ์/ส่งข้อความเพิ่มได้ตามปกติระหว่างที่สถานะยัง pending (ไม่ล็อกจำนวนข้อความ — Block/Report ที่มีอยู่แล้วเป็นกลไกป้องกัน spam มาตรฐานของโปรเจกต์นี้ ไม่ใช่ rate limit ใหม่ ตาม Risk ที่ยอมรับไว้)
- เห็นสถานะ "รอการตอบรับ" แบบไม่บล็อกการใช้งาน (บทสนทนายังอยู่ใน Chat Inbox ของตัวเองตามปกติ)

**Message Requests เป็นรายการแยกจาก Chat Inbox หลัก**
- ไม่ปนกับกล่องข้อความหลัก (ที่มีแต่บทสนทนา `active`) — ต้องมีทางเข้าแยก (เช่น banner จำนวนคำขอค้างที่ด้านบนของ Chat Inbox)
- บทสนทนาที่ pending และผู้ใช้คนนั้นเป็น**ผู้รับ** (ไม่ใช่ผู้ส่ง) ไม่ควรปรากฏใน Chat Inbox หลักเลยจนกว่าจะ Accept — ป้องกันความสับสนระหว่าง "ข้อความที่รู้จักอยู่แล้ว" กับ "คำขอที่ยังไม่ตัดสินใจ"
- Badge จำนวนคำขอค้าง (รวมกับ unread ปกติ) ต้องแสดงบนไอคอน Chat เดิมของ Home ที่ WYN-031 สร้างไว้แล้ว — ผู้ใช้ต้องไม่พลาดคำขอใหม่

**Notification**
- Master Spec section 20 ระบุ "Message Request" เป็น Notification type แยกจาก "New Message" — task นี้เพิ่มเฉพาะ `message_request` (แจ้งผู้รับเมื่อมีคำขอใหม่) — **"New Message" notification สำหรับบทสนทนาปกติไม่อยู่ในสโคปนี้** (WYN-031 เองก็ไม่ได้ทำไว้ อาศัย Realtime+badge เท่านั้น) เป็น gap ที่ยอมรับไว้ต่อเนื่องจาก WYN-031 ไม่ใช่ regression ของ task นี้

Acceptance Criteria:
- [ ] ผู้ใช้ A (ที่ B ยังไม่ได้ follow) ทักผู้ใช้ B เป็นครั้งแรก → เข้า "คำขอข้อความ" ของ B ไม่ใช่กล่องข้อความหลักทันที
- [ ] B follow A อยู่แล้วก่อนหน้า → A ทัก B → เข้ากล่องข้อความหลักทันที ไม่ผ่าน gate ใดๆ (เหมือน WYN-031 เดิม)
- [ ] B เปิดคำขอข้อความ อ่านข้อความที่ A ส่งมาได้ปกติ แต่พิมพ์ตอบไม่ได้จนกว่าจะกด Accept
- [ ] B กด Accept → บทสนทนาใช้งานได้ปกติทันทีทั้งสองฝ่าย เหมือน WYN-031 ทุกประการนับจากนี้
- [ ] B กด Delete (ไม่ Accept) → คำขอหายจากมุมมอง B ทันที A ไม่ได้รับแจ้งเตือนว่าถูกปฏิเสธ — A ทักใหม่ได้ เริ่มคำขอใหม่
- [ ] B กด Block จากหน้าคำขอ → A block แล้วจริง ส่งข้อความหา B ไม่ได้อีกต่อไป (reuse WYN-027)
- [ ] B กด Report จากหน้าคำขอ → เข้า Moderation Queue เดิมของ WYN-026 ได้จริง (`target_type = 'user'`)
- [ ] A ยังส่งข้อความเพิ่มได้ระหว่างที่ B ยังไม่ตัดสินใจ (ไม่ถูกบล็อกเอง)
- [ ] B ได้รับ notification `message_request` เมื่อมีคำขอใหม่เข้ามา
- [ ] Badge บนไอคอน Chat ของ Home รวมจำนวนคำขอข้อความที่ยังไม่ตัดสินใจเข้ากับ unread ปกติ
- [ ] Regression: WYN-031's 1:1 Chat เดิม (บทสนทนาที่ follow กันอยู่แล้ว, ข้อความ Text/Image/Reply/Delete/Read-Unread/Mute/Block/Report เดิมทุกจุด) ทำงานเหมือนเดิมทุกประการ ไม่มี gate เพิ่มสำหรับคนที่รู้จักกันอยู่แล้ว

Dependencies: WYN-031 (1:1 Chat — ต้อง merge เข้า `main` แล้ว, ใช้ `conversations.status` column ที่เตรียมไว้แล้วต่อ), WYN-026 (Report — reuse `target_type = 'user'`), WYN-027 (Block — reuse `block_user()`) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P0 — task ที่ 2 ของ Phase 2 ตาม Roadmap ที่ Founder ล็อกสเปกแล้ว ("ต่อเลย" หลัง WYN-031 เสร็จ)

Risks:
- **ไม่มี rate limit บนจำนวนข้อความที่ผู้ส่งส่งได้ระหว่าง pending**: ผู้ไม่หวังดีอาจส่ง spam หลายข้อความก่อนที่ผู้รับจะกด Block/Report — ยอมรับความเสี่ยงนี้เพราะ Block/Report ที่มีอยู่แล้วเป็นกลไกมาตรฐานของโปรเจกต์นี้ (ไม่มี feature ไหนในระบบทำ rate limit บนการส่งข้อความ/โพสต์เลยสักจุดเดียว) การเพิ่ม rate limit ใหม่ไม่อยู่ในสโคปที่ Master Spec ระบุไว้
- **Delete ไม่ใช่การบล็อกถาวร**: คนที่ถูก Delete คำขอสามารถทักใหม่ได้ไม่จำกัดจำนวนครั้ง (แค่ Block เท่านั้นที่หยุดถาวร) — เป็นพฤติกรรมที่ผู้ใช้คุ้นเคยจากแอปอื่น (Delete = "ไม่สนใจตอนนี้" ไม่ใช่ "ห้ามติดต่ออีก") ถ้า Founder ต้องการให้ Delete มีผลแรงกว่านี้ (เช่น auto-block หลัง Delete ซ้ำ N ครั้ง) ต้องแจ้งก่อนเริ่ม Design
- **"New Message" notification ยังไม่มี** (ต่อเนื่องจาก WYN-031): ผู้ใช้ที่ปิดแอปอยู่จะไม่ได้รับแจ้งเตือนข้อความใหม่จากบทสนทนาที่ accept แล้ว รู้แค่ตอนเปิดแอปเข้ามาดู badge — เป็น fast-follow ที่แนะนำแยกต่างหาก ไม่ผูกกับ task นี้
- **นิยาม "รู้จัก" แบบ one-directional follow อาจไม่ตรงกับสัญชาตญาณทุกคน** (เช่น คนที่ follow เราแต่เราไม่ได้ follow กลับ ยังถือเป็น "คนแปลกหน้า" จากมุมมองของเราเมื่อเขาทักมา) — เป็นทางเลือกที่ตั้งใจเลือกเพราะเรียบง่ายและตรงกับ mental model ของแอป DM ส่วนใหญ่ที่ผู้ใช้คุ้นเคย ถ้า Founder ต้องการ mutual-follow แทน ต้องแจ้งก่อนเริ่ม Design (เปลี่ยนแค่เงื่อนไข query เดียวใน `get_or_create_conversation()` ไม่กระทบโครงสร้างอื่น)

Recommendation:
1. เริ่มทันทีต่อจาก WYN-031 (Founder สั่ง "ต่อเลย") — ปิด gap ความเสี่ยง spam/harassment ที่ WYN-031 ยอมรับไว้ชั่วคราว
2. Schema เพิ่มแค่ 1 column ใหม่ (`conversations.requested_by`, nullable) — ไม่ใช่ breaking change ต่อ WYN-031 เดิม เพราะบทสนทนา `active` เดิมทั้งหมดไม่ต้องมีค่านี้เลย
3. Design ควร reuse `ConversationScreen`'s pattern ที่มีอยู่แล้ว (สลับพื้นที่ composer ตามสถานะ — Blocked/Restricted/Suspended ใช้ pattern นี้อยู่แล้วใน WYN-031) เพิ่มสถานะที่ 4 (pending-as-recipient) แทนที่จะสร้างหน้าจอแยกทั้งหมด — ลด risk/scope
4. WYN-033 (Share เข้า Chat) ควรทำหลัง task นี้เสร็จตามลำดับ Roadmap เดิม

Handoff: AI Design — ออกแบบ Message Requests list screen (entry point จาก banner บน Chat Inbox), ConversationScreen's สถานะที่ 4 (Accept/Delete/Block/Report action area แทน composer เมื่อผู้ใช้เป็นผู้รับที่ยังไม่ตัดสินใจ), schema เบื้องต้นที่แนะนำ (`conversations.requested_by`, `accept_message_request()`/`delete_message_request()` RPCs, `message_requests` view, `messages` INSERT policy ที่อนุญาตผู้ส่งเดิมส่งเพิ่มได้ระหว่าง pending, notification type `message_request`) ให้ AI Coding ต่อยอดได้ทันที

---

## Design Output (2026-08-23)

ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-032-message-request.md` สรุปสั้น:

- **`conversations.requested_by` เป็น column ใหม่เดียวที่เพิ่ม** (nullable) — บทสนทนา `active` เดิมทั้งหมดจาก WYN-031 ไม่ต้องมีค่านี้เลย
- **`get_or_create_conversation()` ตัดสินใจ `status` ตอนสร้างครั้งแรกเท่านั้น** — เช็คทิศทางเดียว (ผู้รับ follow ผู้ส่งอยู่แล้วหรือไม่) ไม่ re-evaluate ทีหลัง
- **ไม่สร้างหน้าจอแยกสำหรับดูคำขอ** — reuse `ConversationScreen` เดิม เพิ่มสถานะที่ 4 ในพื้นที่ composer (ต่อจาก Blocked/Restricted/Suspended)
- **Message Requests list เป็นหน้าจอใหม่จริงจอเดียว** (`MessageRequestListScreen`) มิเรอร์ `ChatInboxScreen`'s list shape
- **Block/Report จากหน้าคำขอ reuse RPC เดิมของ WYN-026/027 ตรงๆ** — มีแค่ 2 RPC ใหม่จริงคือ `accept_message_request()`/`delete_message_request()`

Handoff: AI Coding — SQL (`requested_by` column + constraint, แก้ `get_or_create_conversation()`/messages INSERT policy/`chat_inbox` view, RPC ใหม่ 2 ตัว, `message_requests` view ใหม่, notification type ใหม่) → Flutter data layer → UI (banner + `MessageRequestListScreen` + `ConversationScreen`'s สถานะที่ 4 + notification wiring)

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): `conversations` เพิ่มคอลัมน์ `requested_by uuid` (nullable) พร้อม CHECK ใหม่ `conversations_requested_by_is_participant` (ต้องเป็นหนึ่งใน user_a_id/user_b_id หรือ null) — แก้ `get_or_create_conversation()` ให้ตรวจก่อนว่ามีแถวเดิมอยู่แล้วหรือไม่ (ถ้ามี return ตรงๆ ไม่ผ่าน logic ใหม่ซ้ำ) แล้วเช็คทิศทางเดียวว่าผู้รับ follow ผู้ส่งอยู่แล้วหรือไม่ (`exists (select 1 from follows where follower_id = p_other_user_id and following_id = v_me)`) ตัดสินใจ `'active'`/`'pending'` พร้อม insert notification `message_request` เฉพาะตอนสร้างแถวใหม่จริงและเป็น pending เท่านั้น (จัดการ race condition ด้วย `on conflict do nothing returning id` แล้ว fallback select ถ้าแพ้ race) — แก้ messages INSERT policy จาก "status='active' เท่านั้น" เป็น "active หรือ (pending และผู้ส่งคือ requested_by)" — เพิ่ม `accept_message_request()`/`delete_message_request()` RPCs ใหม่ (ทั้งคู่กัน requested_by เรียกใช้กับ request ของตัวเอง และกันคนนอกที่ไม่ใช่ participant เรียกได้เลย) — `delete_message_request()` เป็น hard DELETE ตรงๆ ไม่ใช่ flag (ใช้ `messages.conversation_id on delete cascade` ที่ WYN-031 วางไว้แล้วลบข้อความทั้งหมดไปด้วยอัตโนมัติ) — เพิ่ม view `message_requests` ใหม่ (กรอง `requested_by <> auth.uid()` ให้เห็นเฉพาะฝั่งผู้รับ + กรอง `not internal.is_blocked_either_way()` ออก) — แก้ `chat_inbox` view เพิ่มคอลัมน์ `requested_by` และเงื่อนไข WHERE ใหม่ (`status='active' or requested_by=auth.uid()`) ให้ pending conversation โชว์เฉพาะฝั่งผู้ส่งในกล่องข้อความหลัก — เพิ่ม `notifications.conversation_id` คอลัมน์ใหม่ (`on delete cascade` — ลบ conversation ที่ถูกปฏิเสธแล้วลบ notification ที่ชี้ไปด้วยอัตโนมัติ ผลข้างเคียงที่ตั้งใจไว้) + type `message_request` เข้า CHECK constraint

**Flutter**: `Conversation` model เพิ่ม `requestedBy` field — `ChatRepository` เพิ่ม `MessageRequest` model ใหม่ + `fetchMessageRequests()`/`countPendingMessageRequests()`/`acceptMessageRequest()`/`deleteMessageRequest()`/`fetchConversationMeta()` (fetch สดทุกครั้งที่เปิดหน้าจอ ไม่เชื่อ prop จาก list เดิมที่อาจ stale) — `MessageRequestListScreen` ใหม่ (มิเรอร์ `ChatInboxScreen`'s list/pagination shape) — `ChatInboxScreen` เพิ่ม banner ด้านบน (ซ่อนถ้าไม่มีคำขอค้าง) + realtime callback เดิมขยายให้ refresh badge count ด้วย — `ConversationScreen` เพิ่มสถานะที่ 4: `_isPendingAsRecipient`/`_isPendingAsRequester` getters ใหม่ตัดสินจาก `fetchConversationMeta()` ที่โหลดคู่กับ `_loadSafetyState()` เดิม (fail-open เป็น 'active' ระหว่างรอโหลด มิเรอร์ posture เดียวกับ `_blockRelationship`) — พื้นที่ composer เพิ่ม branch ใหม่ก่อน composer ปกติ (หลัง blocked/restricted/suspended ตามลำดับความสำคัญเดิม) แสดง Accept/Delete/Block/Report — ผู้ส่งเห็น label "รอการตอบรับ" แบบไม่ block การพิมพ์ — `NotificationType` เพิ่ม `messageRequest` + `WynNotification` เพิ่ม `conversationId` field — `NotificationListScreen` เพิ่ม `chatRepository` param + case ใหม่เปิด `ConversationScreen` ตรง — `RootShell`/`HomeFeedScreen` wiring (`_loadUnreadChatCount()` รวม `countPendingMessageRequests()` เข้ากับ `countUnreadConversations()` เดิม)

**Tests**: `flutter analyze` สะอาด 0 issues ทั้งโปรเจกต์ — `flutter test` **499/499 ผ่าน** (ของใหม่: `message_request_list_screen_test.dart` 4 เคส, `chat_model_test.dart` เพิ่ม `MessageRequest.fromMap`+`Conversation.requestedBy` 4 เคส, `chat_inbox_screen_test.dart` เพิ่ม banner 2 เคส, `conversation_screen_test.dart` เพิ่มกลุ่ม "Message Request (WYN-032)" 6 เคส [ผู้รับเห็น Accept/Delete/Block/Report แทน composer, Accept สำเร็จ, Delete ยืนยันแล้ว pop กลับ, Block สำเร็จสลับเป็นข้อความ blocked, Report เปิด ReportSheet ตรงเป้าหมาย user, ผู้ส่งเห็น composer ปกติ+label], `notification_list_screen_test.dart` เพิ่ม `message_request` 2 เคส)

**SQL live verification**: เขียน `supabase/tests/wyn_032_message_request_test.sh` ใหม่ (28 checks) รันภายใต้ role `authenticated` จริงตาม convention เดิม ครอบ: `get_or_create_conversation()`'s active-when-known/pending-when-unknown/idempotency/notification-fire-once, `chat_inbox`/`message_requests` visibility split (ผู้ส่งเห็นใน inbox หลัก ผู้รับเห็นใน requests แยก ไม่ปนกัน), messages INSERT policy (ผู้รับส่งไม่ได้เลยระหว่าง pending, ผู้ส่งยังส่งเพิ่มได้), `accept_message_request()`/`delete_message_request()` ทั้งคู่ (requester เรียกเองไม่ได้, **คนนอกที่ไม่ใช่ participant เรียกไม่ได้เลย**, recipient เรียกได้จริงพร้อม cascade ลบข้อความ, เริ่ม request ใหม่ได้หลังถูก delete ไม่ค้างตาย), `conversations_requested_by_is_participant` constraint, `message_requests` กรอง blocked-either-way ออกจริง — **28/28 PASS** — **พบ regression จริงระหว่างรัน**: `wyn_031_chat_test.sh` เดิม (ที่ fixture ไม่เคยตั้ง follow relationship ระหว่าง user คู่ทดสอบ) ล้มเหลวจริงเพราะ `get_or_create_conversation()` เปลี่ยนพฤติกรรมให้บทสนทนาที่ follow กันไม่อยู่กลายเป็น `pending` แทน `active` ทันที — แก้โดยเพิ่ม seed mutual follows ให้ทุกคู่ที่ script เดิมคาดหวังว่าต้อง active (ไม่ใช่บั๊กของโค้ด แต่เป็น fixture ของ regression script รุ่นก่อนที่ไม่ได้ออกแบบมาให้รองรับ gate ใหม่นี้) — รันซ้ำ `wyn_021`(5/5)/`wyn_027`(9/9)/`wyn_029`(36/36)/`wyn_030`(31/31)/`wyn_031`(29/29 หลังแก้) ทั้งหมดผ่าน ไม่มี cross-task regression เหลืออยู่

**Acceptance Criteria — ไล่ตรวจครบทั้ง 11 ข้อ**: ทักคนที่ไม่ follow → เข้าคำขอ ไม่ใช่กล่องหลักทันที ✓, follow กันอยู่แล้ว → active ทันทีไม่ผ่าน gate ✓, อ่านข้อความได้แต่พิมพ์ไม่ได้จนกว่าจะ Accept ✓, Accept → ใช้งานปกติทันทีทั้งสองฝ่าย ✓, Delete → หายจาก B ทันที A ไม่รู้ตัว ทักใหม่ได้ ✓, Block จากหน้าคำขอ → block จริง ✓, Report จากหน้าคำขอ → เข้า Moderation Queue จริง (`target_type='user'`) ✓, A ยังส่งเพิ่มได้ระหว่างรอ ✓, notification `message_request` ยิงจริง ✓, badge รวมคำขอค้าง+unread ปกติ ✓, Regression WYN-031 เดิมทำงานเหมือนเดิมทุกประการ (หลังแก้ fixture) ✓ — **ครบทุกข้อ**

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — ตรวจซ้ำเองทุกจุดที่มีความเสี่ยงด้านความปลอดภัย/ความถูกต้อง โดยเฉพาะจุดที่ WYN-032 เพิ่ม gate ใหม่เข้าไปในเส้นทางที่ WYN-031 เคยเปิดโล่งมาก่อน

**สิ่งที่ทำ**:
1. อ่าน diff เต็มของ `supabase/schema.sql` ส่วน WYN-032 ทั้งหมดด้วยตัวเอง รวมถึงจุดที่แก้ policy เดิมของ WYN-031 (ไม่ใช่แค่ของใหม่) — ยืนยัน `get_or_create_conversation()`'s race-condition handling ถูกต้อง (`on conflict do nothing returning id` แล้ว fallback select เมื่อแพ้ race ไม่ insert notification ซ้ำ), `accept_message_request()`/`delete_message_request()` ทั้งคู่กัน requested_by และคนนอกที่ไม่ใช่ participant ได้จริงในโค้ด (ไม่ใช่แค่ในคอมเมนต์)
2. **พบช่องโหว่จริง 1 จุดที่ร้ายแรงที่สุดของรอบนี้**: Product spec กำหนดว่าผู้ส่งต้องส่ง Text/Image/ทั้งคู่ได้ระหว่างที่ยัง pending — Coding แก้ `messages` INSERT policy ให้ผู้ส่ง (requested_by) ส่งข้อความต่อได้ระหว่าง pending จริง แต่ **ไม่ได้แก้ `chat-media` storage bucket's INSERT policy ให้ตรงกัน** — policy เดิมของ WYN-031 ยังคงบังคับ `c.status = 'active'` เท่านั้น ซึ่งหมายความว่าถ้าผู้ส่งพยายามส่ง**รูปภาพ**ระหว่างที่บทสนทนายัง pending การอัปโหลดรูปจะถูก RLS ปฏิเสธเงียบๆ ก่อนที่จะถึงขั้นตอน insert แถว `messages` เลยด้วยซ้ำ (`ChatRepository.sendMessage()` อัปโหลดรูปก่อน insert แถวเสมอ) — ขัด acceptance criteria ตรงๆ แม้ข้อความ text จะทำงานถูกต้องก็ตาม เป็นช่องโหว่ที่มองข้ามได้ง่ายเพราะ error จะไม่ปรากฏชัดในระดับ `messages` table เลย ต้องตามไปดู storage policy แยกต่างหาก
3. **แก้ทันที**: แก้ `"Participants can upload media to their conversations"` policy ให้เงื่อนไข status ตรงกับ `messages` INSERT policy เป๊ะ (`active` หรือ `pending` ที่ `requested_by = auth.uid()`) — เพิ่ม 2 checks ใหม่ (`CHECK10b`/`CHECK10c`) ใน `wyn_032_message_request_test.sh` พิสูจน์ว่าผู้ส่งอัปโหลดรูประหว่าง pending ได้จริง และผู้รับยังอัปโหลดไม่ได้เหมือนเดิม — รันซ้ำ **30/30 PASS**
4. ยืนยันซ้ำว่า regression fix ของ `wyn_031_chat_test.sh` (seed mutual follows) ที่ Coding ทำไว้ถูกต้องจริง — อ่านโค้ดยืนยันว่าไม่ได้ "ปิดปาก" ปัญหาด้วยการลด coverage แต่เพิ่ม fixture ให้ตรงกับพฤติกรรมใหม่ที่ถูกต้องแล้ว (บทสนทนาที่ follow กันอยู่แล้วต้องเป็น active เสมอ ไม่เกี่ยวกับ gate ใหม่)
5. รัน `wyn_021`(5/5)/`wyn_027`(9/9)/`wyn_029`(36/36)/`wyn_030`(31/31)/`wyn_031`(29/29)/`wyn_032`(30/30) ทั้ง 6 สคริปต์อิสระเองอีกครั้งหลังแก้ทุกจุด — **140/140 checks ผ่านหมด** ไม่มี cross-task regression
6. รัน `flutter analyze`/`flutter test` อิสระเองทั้งโปรเจกต์ — 0 issues, 499/499 ผ่าน ตรงกับที่ Coding รายงาน
7. ตรวจ `ConversationScreen`'s state-priority ordering ด้วยตา — ยืนยันว่า blocked/suspended/restricted ยังคงมาก่อน pending-as-recipient เสมอ (ลำดับ `if` ใน `_buildComposerArea()`) ถูกต้องตามที่ควรจะเป็น (บทสนทนาที่ blocked-either-way ไม่มีทางถูกแสดงเป็น pending request อยู่แล้วเพราะ `message_requests` view กรองออกไปตั้งแต่ query แต่ถ้าเกิด block ขึ้นทีหลังระหว่างยัง pending ก็ต้องแสดง blocked ก่อนเสมอ ซึ่งโค้ดทำถูก)
8. ตรวจ `notifications.conversation_id`'s `on delete cascade` — ยืนยันว่าเป็นผลข้างเคียงที่ตั้งใจและถูกต้อง (ลบ notification ที่ชี้ไปยัง conversation ที่ถูก decline แล้ว ไม่เหลือ dangling reference) ไม่ใช่บั๊ก

**Regression**: ไม่มี regression ใดๆ นอกจากช่องโหว่ storage policy ที่พบและแก้เองในข้อ 2-3 — ทุก script/test เดิมผ่านหมด

**ผลลัพธ์: WYN-032 — PASS (พบและแก้ 1 จุดร้ายแรงระหว่าง QA ก่อนอนุมัติ)** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — task ที่ 2 ของ **Phase 2 (WYN Chat)** ที่ผ่าน QA — พร้อมส่ง AI Deploy & DevOps merge เข้า `main` ทันทีตาม merge policy ที่บันทึกไว้แล้ว
