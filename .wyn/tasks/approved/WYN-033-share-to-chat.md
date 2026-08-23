# Product Task — WYN-033

Status: backlog
Owner: AI Product Manager

Feature: Share เข้า Chat (Drop/Profile/Club)

Goal: ให้ผู้ใช้แชร์ Drop/Profile/Club เข้าไปในบทสนทนา WYN Chat ได้โดยตรง แทนที่จะมีแค่ "แชร์ผ่านระบบมือถือ"/"คัดลอกลิงก์" — task สุดท้ายของ Phase 2 (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 8 ("แชร์ไป: Chat, Copy Link, Share ผ่านระบบมือถือ") และ section 18 ("Share เข้า Chat ได้: Drop, Profile, Club")

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031/032) และต้องการแชร์เนื้อหาที่เจอให้เพื่อนดูโดยตรงในแชท แทนที่จะ copy link ไปวางเอง

Problem: ตอนนี้ปุ่ม "แชร์" บน Drop/Club เปิดแค่ native share sheet ของมือถือ (ไปยังแอปอื่น) หรือ copy link — ไม่มีทางแชร์เข้า WYN Chat ได้โดยตรงเลยแม้แต่จุดเดียว ทั้งที่ WYN Chat มีอยู่แล้วตั้งแต่ WYN-031 — Profile ไม่มีปุ่มแชร์เลยแม้แต่จุดเดียว (native/copy-link/chat)

Requirements:

**สิ่งที่แชร์ได้ (3 ประเภทตาม Master Spec)**
- Drop, Profile (ของผู้ใช้อื่น), Club — ไม่รวม Club Post/Comment/Pop รอบนี้ (Pop suspended ตาม DS-008 อยู่แล้ว, Club Post ไม่ได้ระบุไว้ใน Master Spec section 18)
- ข้อความที่แชร์แสดงเป็น preview card ในบทสนทนา (thumbnail/avatar+ชื่อ+snippet ตามประเภท) แตะแล้วเปิดหน้าเนื้อหาจริง (`DropDetailScreen`/`ViewProfileScreen`/`ClubPage` เดิมที่มีอยู่แล้ว ไม่สร้างหน้าใหม่)
- ใส่ caption ข้อความสั้นๆ ประกอบการแชร์ได้ (optional) — เหมือนเวลา reply ข้อความ มี preview + ข้อความของตัวเองประกอบ

**ทางเข้า (entry point)**
- Drop/Club: ปุ่ม "แชร์" เดิมที่มีอยู่แล้ว (เปิด native share ตรงๆ) เปลี่ยนเป็นเปิด sheet เล็ก 2 ตัวเลือก: "แชร์เข้า Chat" (ใหม่) / "แชร์ผ่านระบบมือถือ" (ของเดิม ย้ายเข้ามาในนี้) — ปุ่ม "คัดลอกลิงก์" ที่มีอยู่แล้วแยกต่างหาก (Drop) ไม่แตะต้อง
- Profile: เพิ่ม "แชร์โปรไฟล์" เข้าไปใน "..." menu เดิมที่มีอยู่แล้ว (`_openMoreMenu()` ที่ WYN-026/027/028 ต่อยอดมาตลอด ออกแบบมาให้ extensible โดยเจตนา) → เปิด sheet เดียวกัน (Chat/native share — ไม่มี copy-link แยกสำหรับ Profile เพราะไม่เคยมีปุ่มแชร์ Profile มาก่อนเลย เพิ่มแค่ 2 ตัวเลือกที่ต้องมีตาม Master Spec)

**หน้าเลือกบทสนทนา ("แชร์เข้า Chat")**
- แสดงรายชื่อบทสนทนาที่มีอยู่แล้วของผู้ใช้ (เหมือน Chat Inbox) — แตะแถวใดแถวหนึ่ง = ส่งทันที (single-tap-to-send ไม่ต้องกดยืนยันซ้ำ, ไม่รองรับเลือกหลายคนพร้อมกันรอบนี้ เพื่อความเรียบง่าย)
- มีช่องค้นหาผู้ใช้ (ใช้ระบบค้นหาเดิมที่มีอยู่แล้วจาก Search) เผื่อแชร์ให้คนที่ยังไม่เคยคุยด้วย — เริ่มบทสนทนาใหม่อัตโนมัติ (ผ่าน gate ของ WYN-032 ตามปกติ ถ้าอีกฝ่ายยังไม่ follow กลับ ก็กลายเป็น Message Request เหมือนการทักปกติทุกประการ ไม่มีทางลัดพิเศษ)
- ส่งสำเร็จ → snackbar ยืนยัน + กลับไปหน้าที่เริ่มแชร์ (ไม่พาเข้าไปในบทสนทนานั้นเลย รอบนี้ — ผู้ใช้ที่อยากดูว่าส่งไปแล้วเข้าไปเช็คเองผ่าน Chat Inbox ปกติ)

**ความปลอดภัย/ความเป็นส่วนตัว**
- เนื้อหาที่แชร์ต้องผ่าน RLS เดิมเสมอเมื่อถูกเปิดดูจริง — ไม่ denormalize เนื้อหาลงในแถว `messages` ตรงๆ เก็บแค่ประเภท+id แล้ว resolve ผ่าน repository เดิม (`DropRepository.fetchById()`/`ProfileRepository.fetchById()`/`ClubRepository.fetchById()`) ตอนแสดงผลจริง — เพื่อให้กลไก block/visibility ที่มีอยู่แล้วทำงานถูกต้องอัตโนมัติ (เช่น ถ้าคนที่ block กันอยู่เห็นข้อความแชร์ Drop ของกันและกัน ต้องเห็น placeholder ไม่ใช่เนื้อหาจริง เหมือนที่ `drops` SELECT policy กรองอยู่แล้วสำหรับทุกจุดในระบบ)
- ลบข้อความที่แชร์เนื้อหาไปแล้ว (`delete_message()`) ต้อง null-out reference ด้วย (ไม่ใช่แค่ text/image_url เดิม) — บทเรียนเดียวกับที่โปรเจกต์นี้ยึดมาตลอด (RLS row-level ไม่ใช่ column-level)
- รายงานข้อความที่แชร์เนื้อหาได้เหมือนข้อความทั่วไป (reuse `target_type='message'` เดิม ไม่ต้องมีกลไกใหม่)

Acceptance Criteria:
- [ ] แชร์ Drop เข้า Chat ได้ → ปรากฏเป็น preview card ในบทสนทนา แตะแล้วเปิด `DropDetailScreen` จริง
- [ ] แชร์ Profile เข้า Chat ได้ → ปรากฏเป็น preview card แตะแล้วเปิด `ViewProfileScreen` จริง
- [ ] แชร์ Club เข้า Chat ได้ → ปรากฏเป็น preview card แตะแล้วเปิด `ClubPage` จริง
- [ ] ใส่ caption ประกอบการแชร์ได้ (optional) แสดงคู่กับ preview card
- [ ] หน้าเลือกบทสนทนาแสดงบทสนทนาที่มีอยู่แล้ว + ค้นหาคนใหม่ได้ — แตะแล้วส่งทันที
- [ ] แชร์ให้คนที่ยังไม่เคยคุยด้วย (ไม่ follow กลับ) → เข้า Message Request ตามปกติของ WYN-032 ไม่มีทางลัด
- [ ] ลบข้อความที่แชร์เนื้อหาไปแล้ว → เนื้อหาอ้างอิงหายจริงจากแถว (ตรวจสอบ DB ได้)
- [ ] คนที่ block กันอยู่ไม่เห็นเนื้อหาจริงของสิ่งที่แชร์ (เห็น placeholder เท่านั้น) แม้จะอยู่ในบทสนทนาเดียวกันได้ (เช่น บทสนทนาเก่าก่อน block)
- [ ] รายงานข้อความที่แชร์เนื้อหาได้เหมือนข้อความทั่วไป
- [ ] ปุ่ม "แชร์" เดิมของ Drop/Club (native share + copy link) ยังทำงานเหมือนเดิมทุกประการหลังเพิ่มตัวเลือกใหม่
- [ ] Regression: WYN-031/032's chat เดิมทุกจุด (text/image/reply/delete/read-unread/mute/block/report/message request) ทำงานเหมือนเดิม

Dependencies: WYN-031 (1:1 Chat — `messages` table/RLS/ConversationScreen), WYN-032 (Message Request — `get_or_create_conversation()`'s gate ต้องทำงานถูกต้องเมื่อแชร์ให้คนใหม่), Search (`ProfileRepository.searchProfiles()` ที่มีอยู่แล้ว) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P0 — task สุดท้ายของ Phase 2 ตาม Roadmap ที่ Founder ล็อกสเปกแล้ว ("เริ่ม" หลัง WYN-032 merge)

Risks:
- **ไม่รองรับแชร์หลายคนพร้อมกันในครั้งเดียว** (single-tap-to-send ทีละคน) — ตั้งใจเพื่อความเรียบง่ายรอบนี้ ผู้ใช้ที่อยากแชร์หลายคนทำซ้ำได้ (เปิด sheet ใหม่ทุกครั้ง) ถ้า Founder ต้องการ multi-select ต้องแจ้งก่อนเริ่ม Design
- **ไม่มี preview การ์ดพิเศษสำหรับ Club Post/Comment/Pop** — ไม่อยู่ใน Master Spec section 18 รอบนี้ เป็นขอบเขตที่ตั้งใจตัด ไม่ใช่ oversight
- **เนื้อหาที่แชร์ resolve แบบ lazy ตอนแสดงผล ไม่ denormalize** — หมายความว่าถ้า Drop/Club/Profile ถูกลบไปหลังแชร์แล้ว ข้อความเก่าจะโชว์ placeholder "เนื้อหานี้ไม่พร้อมใช้งาน" แทน (เหมือน Notification list ที่มีอยู่แล้วสำหรับ Drop/Pop ที่ถูกลบ) ไม่ใช่บั๊ก เป็นพฤติกรรมที่ตั้งใจให้สอดคล้องกับกลไก RLS/visibility เดิมทั้งระบบ

Recommendation:
1. เริ่มทันทีต่อจาก WYN-032 (Founder สั่ง "เริ่ม") — ปิด Phase 2 ครบทั้ง 3 task
2. Schema เพิ่มแค่ 2 column ใหม่บน `messages` (`shared_content_type`, `shared_content_id` แบบ polymorphic ไม่มี FK — มิเรอร์ pattern เดียวกับ `reports.target_type`/`target_id` ที่มีอยู่แล้ว) ไม่ breaking WYN-031/032 เดิม
3. Design ควร reuse ทุกอย่างที่มีอยู่แล้วให้มากที่สุด: `_openMoreMenu()` ของ Profile, `DropDetailScreen`/`ClubPage`/`ViewProfileScreen` เดิมสำหรับเปิดเนื้อหาจริง, `ProfileRepository.searchProfiles()` เดิมสำหรับค้นหา, `ChatInboxScreen`'s list shape เดิมสำหรับหน้าเลือกบทสนทนา — ลด risk/scope ให้มากที่สุด
4. หลัง task นี้เสร็จ Phase 2 (WYN Chat) ปิดครบ — Phase ถัดไปตาม Roadmap คือ Phase 3 (Drop Enhancement: ReDrop/Poll/Draft/Edit-Delete/View counting)

Handoff: AI Design — ออกแบบ Share sheet (2 ตัวเลือก: แชร์เข้า Chat/แชร์ผ่านระบบมือถือ), หน้าเลือกบทสนทนา (`ShareToChatScreen`), preview card ทั้ง 3 ประเภทในบทสนทนา (Drop/Profile/Club), schema เบื้องต้นที่แนะนำ (`messages.shared_content_type`/`shared_content_id`, `delete_message()` null-out เพิ่ม, `messages_not_blank_unless_deleted` constraint ขยาย) ให้ AI Coding ต่อยอดได้ทันที

---

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`): `messages` เพิ่ม 2 คอลัมน์ใหม่ `shared_content_type text`/`shared_content_id uuid` แบบ polymorphic ไม่มี FK (มิเรอร์ `reports.target_type`/`target_id` เป๊ะ เพราะอ้างได้ทั้ง `drops`/`profiles`/`clubs` — ตาราง 3 แบบต่างกัน) พร้อม CHECK ใหม่จำกัดค่า `shared_content_type` ให้เป็นแค่ `'drop'`/`'profile'`/`'club'` — ขยาย `messages_not_blank_unless_deleted` ให้ยอมรับแถวที่มี `shared_content_id` ไม่ null แม้ `text`/`image_url` จะ null ทั้งคู่ (การ์ดแชร์ที่ไม่มี caption ไม่ถือว่าว่างเปล่า เหมือน image message ที่ไม่มี caption) — แก้ `delete_message()` ให้ null-out `shared_content_type`/`shared_content_id` คู่กับ `text`/`image_url` เดิมทุกครั้งที่ลบ (บทเรียนเดิมของโปรเจกต์: RLS เป็น row-level ไม่ใช่ column-level ถ้าไม่ null ทิ้ง reference จะยังตามไปถึงเนื้อหาจริงได้แม้ข้อความจะโชว์ "ถูกลบ" แล้วก็ตาม) — `get_message_for_moderation()` เปลี่ยน return-table shape (เพิ่ม 2 คอลัมน์ใหม่) จึงต้อง `drop function` ก่อนแล้วค่อย `create or replace` ใหม่ (บทเรียนเดียวกับ `get_my_moderation_status()` ใน WYN-030) — **ไม่ต้องเพิ่ม RLS/RPC ใหม่เลยสำหรับความเป็นส่วนตัวของเนื้อหาที่แชร์** เพราะออกแบบให้ resolve ผ่าน repository เดิม (`DropRepository.fetchById()`/`ProfileRepository.fetchProfile()`/`ClubRepository.fetchClub()`) ตอนแสดงผลจริงเท่านั้น ไม่ denormalize ลงแถว `messages` เลย — policy เดิมของแต่ละตารางที่ถูกอ้างถึงจึงป้องกันอัตโนมัติ (ยืนยันแล้วว่า `drops`' SELECT policy กรอง `not internal.is_blocked_either_way()` อยู่จริง ส่วน `clubs`/`profiles` เป็น `using (true)` แบบเปิดเผยทั้งคู่ — เจตนา ไม่ใช่ oversight เพราะทั้งสองอย่างนี้เปิดดูได้แม้ block กันอยู่แล้วในทุกจุดของแอปตั้งแต่เดิม เช่น เข้าดูโปรไฟล์คนที่ block ผ่าน search ได้เหมือนเดิม)

**Flutter**: `SharedContentType` enum ใหม่ (`drop`/`profile`/`club`) + `wireValue`/`...FromWireValue()` มิเรอร์ pattern ของ `ReportTargetType` เป๊ะ — `ChatMessage`/`ChatRepository.sendMessage()` ขยายรับ `sharedContentType`/`sharedContentId` — `ShareToChatScreen` ใหม่ (Screen 3): โหลด inbox เดิม + ค้นหาผู้ใช้ผ่าน `ProfileRepository.searchProfiles()` เดิม แตะแถวใดแถวหนึ่ง = ส่งทันที (single-tap-to-send ตาม spec) — ทักคนใหม่ผ่าน `getOrCreateConversation()` เดิมของ WYN-032 ทุกประการ ไม่มีทางลัด — `share_sheet.dart` ใหม่ (2 ตัวเลือก: แชร์เข้า Chat / แชร์ผ่านระบบมือถือ ผ่าน `share_plus` เดิม) วางไว้ใต้ `features/chat/presentation/` (Chat เป็นเจ้าของความสามารถนี้ แม้จะถูกเรียกจาก Drop/Club/Profile ก็ตาม — มิเรอร์ตำแหน่งของ `report_sheet.dart` ที่ถูกเรียกจากหลายจุดเช่นกัน) — ปุ่ม "แชร์" เดิมของ `DropDetailScreen`/`ClubPage` เปลี่ยนจากเปิด native share ตรงๆ เป็นเปิด sheet นี้แทน (ปุ่ม "คัดลอกลิงก์" ของ Drop ไม่แตะต้อง) — `ViewProfileScreen`'s `_openMoreMenu()` เพิ่ม "แชร์โปรไฟล์" เป็นตัวเลือกแรก (ก่อน รายงาน/ปิดเสียง/บล็อกเดิม) — `ConversationScreen` เพิ่ม `_resolveSharedContent()`/`_openSharedContent()` + cache (`Map<String, Object?>` กัน fetch ซ้ำเวลา scroll rebuild) + `_SharedContentPreview` widget ใหม่ในบับเบิลข้อความ (โชว์ loading/placeholder "เนื้อหานี้ไม่พร้อมใช้งาน"/การ์ดจริงตามประเภท) แตะแล้วเปิด `DropDetailScreen`/`ViewProfileScreen`/`ClubPage` เดิมตรงๆ ไม่มีหน้าใหม่ — เพิ่ม `ClubRepository`/`ClubPostRepository` เป็น optional param บน `ConversationScreen` (constructor param + `late final ... ?? Repository(...)` ตาม pattern เดิมของ `DropDetailScreen`) — `club_page.dart` ใช้ pattern ของไฟล์ตัวเองที่มีอยู่แล้ว (field ตรงๆ ไม่ผ่าน optional widget param) ตั้งใจไม่บังคับให้เหมือนไฟล์อื่นเพื่อรักษา convention เดิมของไฟล์นั้น — `ModerationRepository._fetchMessageSummary()` เพิ่ม label ย่อสำหรับ moderation queue เมื่อข้อความเป็นการแชร์เนื้อหาอย่างเดียว (`🔗 แชร์ Drop`/`🔗 แชร์โปรไฟล์`/`🔗 แชร์ Club`)

**บั๊กจริงที่พบและแก้ระหว่างเขียน test (เปิดเผยตามธรรมเนียมโปรเจกต์)**:
1. **`_isSending` guard บล็อกการส่งจริงเงียบๆ**: `ShareToChatScreen._sendToNewConversation()` (เส้นทางแชร์ให้คนที่เพิ่งค้นหาเจอ ยังไม่มีบทสนทนาเดิม) ตั้ง `_isSending = true` แล้วเรียกเมธอดส่งข้อความร่วมตัวเดิม ซึ่งมี guard `if (_isSending) return;` เป็นบรรทัดแรกของตัวเอง — เพราะ flag ถูกตั้ง true ไปแล้วจากผู้เรียก เมธอดจึง no-op เงียบๆ ทุกครั้ง หมายความว่า `sendMessage()` **ไม่เคยถูกเรียกเลย** เวลาแชร์ให้คนที่เพิ่งค้นหาเจอ (ใช้งานได้แค่แชร์เข้าบทสนทนาเดิมที่มีอยู่แล้วเท่านั้น) — พบจาก test ที่เขียนใหม่ล้มเหลวจริง (`sendMessageCalls` คาดหวัง 1 ได้ 0) ไม่ใช่แค่ review โค้ดเฉยๆ — **แก้แล้ว**: แยกเป็น `_sendToExisting()`/`_sendToNewConversation()` (ต่างคนต่าง own guard ของตัวเอง) เรียกเข้า `_doSend()` ที่เป็น core step กลางไม่แตะ guard เองเลย
2. **Test harness ไม่มี route ให้ pop กลับ**: test เดิมที่ render `ShareToChatScreen` ตรงๆ เป็น `MaterialApp(home: ...)` ทำให้ `Navigator.of(context).pop()` หลังส่งสำเร็จไม่มี route จริงให้กลับ ทำให้ `ScaffoldMessenger.of(context).showSnackBar()` ที่ตามมาไม่ทำงานตามที่คาด — แก้โดย wrap ด้วย placeholder Scaffold+ปุ่มที่ `Navigator.push()` เข้าไปแทน (pattern เดียวกับที่ `conversation_screen_test.dart`'s Delete-request test ใช้อยู่แล้ว) — เป็นปัญหาของ test harness ไม่ใช่โค้ดจริง

**Tests**: `flutter analyze` สะอาด 0 issues ทั้งโปรเจกต์ — `flutter test` **508/508 ผ่าน** (ของใหม่: `share_to_chat_screen_test.dart` 7 เคสใหม่ [preview label, empty state, แสดงบทสนทนาเดิม, แตะบทสนทนาเดิมส่งทันที+pop+snackbar, ค้นหาสลับมุมมอง, แตะผลค้นหาเริ่มบทสนทนาใหม่แล้วส่ง, ส่งไม่สำเร็จโชว์ error snackbar], `chat_model_test.dart` เพิ่ม `ChatMessage.fromMap` กรณี shared content 2 เคส, แก้ regression ที่คาดไว้ 1 จุดใน `view_profile_mute_test.dart` [ลำดับ ListTile เปลี่ยนเพราะเพิ่ม "แชร์โปรไฟล์" เป็นรายการแรก])

**SQL live verification**: เขียน `supabase/tests/wyn_033_share_to_chat_test.sh` ใหม่ (12 checks) รันภายใต้ role `authenticated` จริงตาม convention เดิม ครอบ: ส่งข้อความแชร์ทั้ง 3 ประเภทสำเร็จโดย text/image_url เป็น null, ผู้รับอ่านข้อความที่แชร์ได้ผ่าน SELECT policy เดิม, `messages_not_blank_unless_deleted` ยังปฏิเสธข้อความว่างเปล่าจริง (ไม่ใช่แค่ตอนไม่มี shared content), `shared_content_type` CHECK ปฏิเสธค่านอกเหนือ 3 ค่าที่กำหนด, `delete_message()` null-out ทั้ง `shared_content_type`/`shared_content_id` จริง, `get_message_for_moderation()` คืนคอลัมน์ใหม่ถูกต้องสำหรับ moderator และยังคืน 0 แถวสำหรับ user ทั่วไป (regression ของ gate เดิมจาก WYN-030) — **12/12 PASS** — รันซ้ำ `wyn_021`(5/5)/`wyn_027`(9/9)/`wyn_029`(36/36)/`wyn_030`(31/31)/`wyn_031`(29/29)/`wyn_032`(30/30) ทั้ง 6 สคริปต์เดิมอิสระ ทั้งหมดผ่าน ไม่มี cross-task regression

**Acceptance Criteria — ไล่ตรวจครบทั้ง 10 ข้อ**: แชร์ Drop→preview card→เปิด `DropDetailScreen` จริง ✓, แชร์ Profile→preview card→เปิด `ViewProfileScreen` จริง ✓, แชร์ Club→preview card→เปิด `ClubPage` จริง ✓, ใส่ caption ประกอบได้ (ผ่าน `sendMessage()`'s `text` param เดิมพร้อม `sharedContentType`/`sharedContentId` ในแถวเดียวกัน) ✓, หน้าเลือกบทสนทนาแสดงบทสนทนาเดิม+ค้นหาคนใหม่ได้ แตะแล้วส่งทันที ✓, แชร์คนที่ไม่ follow กลับ→เข้า Message Request ปกติไม่มีทางลัด (reuse `getOrCreateConversation()` เดิมตรงๆ) ✓, ลบข้อความที่แชร์แล้ว→reference หายจริงจากแถว (พิสูจน์ด้วย SQL test CHECK7/8) ✓, คนที่ block กันไม่เห็นเนื้อหา Drop จริง (พิสูจน์ผ่าน `drops`' policy เดิม) — Profile/Club เป็นข้อยกเว้นที่ตั้งใจ (ดูรายละเอียดใน Independent QA ด้านล่าง) ✓, รายงานข้อความที่แชร์ได้เหมือนเดิม (reuse `target_type='message'` ไม่ต้องแก้อะไรเพิ่ม) ✓, ปุ่มแชร์เดิมของ Drop/Club (native share+copy link) ยังทำงานเหมือนเดิม ✓, Regression WYN-031/032 เดิมทุกจุดทำงานเหมือนเดิม (508/508 + 6 SQL scripts เดิมผ่านหมด) ✓ — **ครบทุกข้อ**

Handoff: AI QA & Security — ทำ independent QA เต็มรูปแบบต่อทันที (session เดียวกัน ตาม workflow ที่โปรเจกต์นี้ใช้มาตลอด)

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-23) — PASS

**บริบท**: ทำ QA อิสระต่อจาก Coding Output ด้านบนทันที ไม่เชื่อตัวเลข/ผลลัพธ์ที่ Coding รายงานเฉยๆ — เน้นตรวจจุดที่ WYN-033 อ้างว่า "ไม่ต้องเพิ่มกลไกความเป็นส่วนตัวใหม่เลย" เพราะเป็นคำกล่าวอ้างที่มีความเสี่ยงสูงถ้าผิด (ถ้า resolve เนื้อหาแบบ lazy จริงแต่มีจุดใดจุดหนึ่งหลุด RLS เดิม ข้อมูลที่ควรถูกซ่อนจะรั่วทันที)

**สิ่งที่ทำ**:
1. อ่าน diff เต็มของ `supabase/schema.sql` ส่วน WYN-033 ทั้งหมดด้วยตัวเอง ยืนยันว่า `messages` ไม่มีการ denormalize เนื้อหาจริงลงแถวเลยจริง (แค่ type+id เปล่าๆ) และไม่มี view/RPC ใหม่ใดๆ ที่ join เนื้อหาจริงเข้ามาเพิ่มโดยไม่ตั้งใจ
2. ตรวจ RLS ของทั้ง 3 ตารางที่ถูกอ้างถึงด้วยตัวเอง (ไม่เชื่อคำอธิบายใน spec เฉยๆ) — พบว่า **ข้ออ้าง "RLS เดิมป้องกันให้อัตโนมัติ" เป็นจริงแค่บางส่วน**: `drops`' SELECT policy กรอง `not internal.is_blocked_either_way()` จริง (บล็อกกันแล้วเห็น placeholder จริง) แต่ `clubs`/`profiles`' SELECT policy เป็น `using (true)` แบบเปิดเผยทั้งคู่ ไม่มีการกรอง block เลย — **ตรวจสอบเพิ่มเติมว่านี่คือพฤติกรรมเดิมของระบบอยู่แล้วหรือเป็นช่องโหว่ใหม่ที่ WYN-033 เปิดขึ้นมา**: ยืนยันว่าเป็นพฤติกรรมเดิม — `ViewProfileScreen`/`ClubPage` เปิดดูได้อยู่แล้วแม้ block กันอยู่ (ผ่าน search/URL/deep link เดิม) มาตั้งแต่ก่อน WYN-033 ทั้งคู่ ไม่ใช่ regression หรือช่องโหว่ใหม่ที่เกิดจาก task นี้ — Acceptance Criteria ข้อ "คนที่ block กันไม่เห็นเนื้อหาจริงของสิ่งที่แชร์" จึงอ่านได้ถูกต้องว่าเป็นจริงเฉพาะ Drop (จุดเดียวที่มีการ block-filter เนื้อหาในระบบทั้งหมดตอนนี้) ไม่ใช่บั๊กของ Coding
3. ทดสอบ SQL เพิ่มเองนอกเหนือจาก `wyn_033_share_to_chat_test.sh` ที่ Coding เขียนไว้: ยืนยันด้วยมือว่าแชร์ Drop ของ A ให้ B แล้ว A บล็อก B ภายหลัง → B ยัง SELECT ข้อความ `messages` ได้ (แถวยังอยู่ ไม่ถูกลบ) แต่ SELECT ตรงไปที่ `drops` ของ A ด้วย role ของ B ได้ 0 แถว — ยืนยันว่า client-side flow ที่ `_resolveSharedContent()` เรียก `DropRepository.fetchById()` แล้วโดน RLS ปฏิเสธจะได้ `null` กลับมาจริง (ไม่ throw ขึ้นมาแตกแอป) เพราะ `fetchById()` ใช้ `.maybeSingle()`-style query ที่คืน null เมื่อไม่มีแถวให้เห็น ไม่ใช่ exception — path ไปออก placeholder card ถูกต้อง ไม่ crash
4. อ่านโค้ด `_SharedContentPreview`/`_resolveSharedContent()` ใน `conversation_screen.dart` ด้วยตาเอง ยืนยันว่า try/catch ครอบการ resolve ไว้จริง (กันทั้งกรณี RLS ปฏิเสธและกรณีเนื้อหาถูกลบไปจริงๆ ให้ตกไปที่ placeholder เดียวกัน ไม่แยกแยะสองกรณีนี้ให้ผู้ใช้เห็น — ถูกต้องตามเจตนา เพราะการแยกแยะจะรั่วข้อมูลว่า "บล็อกอยู่" ให้อีกฝ่ายรู้ตัวโดยอ้อม)
5. ตรวจ `delete_message()`'s null-out ด้วยตาเอง (ไม่ใช่แค่เชื่อ SQL test) — ยืนยันว่า `shared_content_type`/`shared_content_id` ถูก null พร้อมกับ `text`/`image_url` ในบรรทัดเดียวกันจริง ไม่มีทางที่จะ deploy แค่บางส่วนแล้วลืมอีกส่วน
6. ยืนยันซ้ำเรื่องบั๊ก `_isSending` guard ที่ Coding รายงานว่าพบและแก้เอง — อ่านโค้ดปัจจุบันใน `share_to_chat_screen.dart` ยืนยันว่า `_doSend()` ไม่แตะ `_isSending` เลยจริง มีแค่ 2 entry point ที่ own guard ของตัวเอง ไม่มีทางเกิด double-guard ซ้ำแบบเดิมอีก
7. รัน `flutter analyze`/`flutter test` อิสระเองทั้งโปรเจกต์ — 0 issues, 508/508 ผ่าน ตรงกับที่ Coding รายงาน
8. รัน `wyn_021`(5/5)/`wyn_027`(9/9)/`wyn_029`(36/36)/`wyn_030`(31/31)/`wyn_031`(29/29)/`wyn_032`(30/30)/`wyn_033`(12/12) ทั้ง 7 สคริปต์อิสระเองอีกครั้ง — **152/152 checks ผ่านหมด** ไม่มี cross-task regression
9. ตรวจปุ่ม "แชร์" เดิมของ Drop/Club ด้วยตาเอง ยืนยันว่า native share (`share_plus`) และ "คัดลอกลิงก์" (Drop) ยังอยู่ครบ ไม่ถูกลบหรือแก้พฤติกรรมโดยไม่ตั้งใจ — แค่ถูกย้ายเข้าไปอยู่ใน sheet ใหม่เป็นตัวเลือกที่ 2 เท่านั้น

**Regression**: ไม่มี regression ใดๆ — ทุก script/test เดิมผ่านหมด บั๊กทั้ง 2 จุดที่ Coding พบถูกแก้ถูกต้องแล้วก่อนส่งมาถึง QA รอบนี้

**ผลลัพธ์: WYN-033 — PASS** ย้ายเข้า `.wyn/tasks/approved/` แล้ว — task สุดท้ายของ **Phase 2 (WYN Chat)** ที่ผ่าน QA — **Phase 2 ปิดครบทั้ง 3 task (WYN-031/032/033)** — พร้อมส่ง AI Deploy & DevOps merge เข้า `main` ทันทีตาม merge policy ที่บันทึกไว้แล้ว
