# Design — WYN-031 (1:1 Chat)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-031-chat-1to1.md` — อ่านก่อนเริ่ม
> Design system: **Cyan `#00C8FF` เป็น primary ตาม DS-001–008 ทั้งหมด** — Rainbow (DS-009) ใช้ได้แค่ 2 จุดที่ล็อกไว้แล้วเท่านั้น (Trending ring / feed-mode indicator ของ Home) **ห้ามใช้ใน Chat แม้แต่จุดเดียว** ไม่มีข้อยกเว้น

## ภาพรวม — 6 การตัดสินใจเชิง scope

1. **ไม่มี group chat, ไม่มี message request gate รอบนี้** — ตรงตาม Product spec เป๊ะ แต่ schema เตรียม `status` column ไว้ล่วงหน้าให้ WYN-032 ต่อยอด
2. **Conversation เป็น 2-column pair table ไม่ใช่ junction table** — `conversations.user_a_id`/`user_b_id` (canonical ordering: uuid เล็กกว่าอยู่ `user_a_id` เสมอ) มิเรอร์ pattern เดียวกับ `blocks`/`mutes` ที่โปรเจกต์นี้ใช้อยู่แล้วสำหรับ pair relationship — ไม่ใช้ junction table (`conversation_participants`) เพราะ scope นี้ไม่มี group chat ที่จำเป็นต้องรองรับ N participants จริง การใช้ junction table ตอนนี้คือ over-engineer ก่อนมี requirement จริง
3. **Read status เก็บเป็น timestamp ต่อฝั่งบนแถว `conversations` เอง** (`user_a_last_read_at`/`user_b_last_read_at`) ไม่ใช่ per-message read receipt — คำนวณ unread count จาก `count(messages where created_at > my_last_read_at and sender_id <> me)`
4. **Soft-delete message = null-out content จริง ไม่ใช่แค่ flag** — `delete_message()` RPC เดียวที่บังคับ set `text = null, image_url = null, deleted_at = now()` พร้อมกันเสมอ ไม่เปิดทางให้ raw UPDATE ทำแบบอื่นได้ (ป้องกันบทเรียนเดิมของโปรเจกต์: RLS row-level ไม่ใช่ column-level — เนื้อหาต้องหายจริงจากแถว ไม่ใช่แค่ UI ซ่อน)
5. **ส่งข้อความ = RLS INSERT ตรงๆ ไม่ต้องมี RPC** (ต่างจาก report/block/appeal ที่ต้องมี RPC เพราะมี multi-step server logic) — validation ทั้งหมด (ไม่ blank/ไม่ block/ไม่ posting-blocked/participant จริง) แสดงเป็น RLS `with check` + CHECK constraint ได้ครบ มิเรอร์ pattern เดียวกับ `drops`/`club_posts` ที่ไม่มี RPC สร้างเนื้อหาเลย
6. **Mute บทสนทนา (`conversation_mutes`) เป็นตารางใหม่แยกขาดจาก `mutes` เดิมของ WYN-028 โดยสิ้นเชิง** — RLS insert/delete ตรงๆ ไม่มี RPC (มิเรอร์ `follows`/`mutes` เดิม)

---

## Screen 1 — Chat Icon Entry Point

**Purpose**: ทางเข้า Chat Inbox จากทุกหน้าจอหลัก โดยไม่เป็น Bottom Nav tab ตาม Master Spec

**ตำแหน่ง (แก้ระหว่าง Coding — ดู "Coding deviation" ด้านล่าง)**: ไอคอน 💬 ลอย (floating overlay ใน `Stack`, ไม่ใช่ `AppBar`) มุมขวาบนของ `HomeFeedScreen` วางบนพื้นผิว `Material` วงกลมของตัวเอง (ไม่พึ่งพื้นหลัง AppBar) — เดิมออกแบบไว้เป็นปุ่มใน `AppBar` ข้าง notification bell แต่ AppBar กิน Column space จริงและทำให้ header ที่เดิมก็ตึงอยู่แล้ว (ClubSection + Trending + feed-mode toggle) ล้นจอบนหน้าจอเตี้ย — เปลี่ยนเป็น overlay ที่ไม่กิน layout space แทน

**Components**: `IconButton(icon: Icons.chat_bubble_outline)` ห่อด้วย `Material(shape: CircleBorder(), elevation: 2)` + Badge (reuse `NotificationListScreen`'s unread-count badge widget/pattern เป๊ะ, cap ที่ "9+" เหมือนกัน)

**Interactions**: แตะ → เปิด `ChatInboxScreen` (push, ไม่ replace)

**Design Rules**: `IconButton`'s `tooltip` ทำหน้าที่ accessible label อัตโนมัติ (`'ข้อความ, N บทสนทนายังไม่อ่าน'`) — 44×44 touch target เต็ม (DS-008)

**Coding deviation (บันทึกไว้ตรงๆ)**: `AppBar` เดิมที่ design doc ฉบับแรกระบุไว้ทำให้ `root_shell_test.dart` ล้มจริงด้วย `RenderFlex overflow` บน default test viewport (800×600) — วัดแล้วพบว่า header เดิมของ Home มี margin เหลือแค่ ~22px ก่อนจะล้นอยู่แล้วแม้ไม่มีการเปลี่ยนแปลงใดๆ (fragile ตั้งแต่ต้น ไม่ใช่ปัญหาที่ WYN-031 สร้างขึ้นเอง แค่เป็นตัวที่ไปกระทบ margin ที่ตึงอยู่แล้วก่อน) แก้โดยเปลี่ยนจาก AppBar (กิน Column space แน่นอนไม่ว่าจะย่อแค่ไหน) เป็น floating overlay ใน `Stack` (ไม่กิน layout space เลย) — ยืนยันด้วย `flutter test` ว่า `root_shell_test.dart`/`home_feed_screen_test.dart`/`view_profile_screen_test.dart` ผ่านหมดหลังแก้

---

## Screen 2 — Chat Inbox (`ChatInboxScreen`)

**Purpose**: รายชื่อบทสนทนาทั้งหมดของผู้ใช้ เรียงตามข้อความล่าสุด

**User Flow**: เปิดจาก Screen 1 → เห็นรายการ → แตะแถวใดแถวหนึ่ง → เปิด `ConversationScreen` (Screen 3)

**Components**: มิเรอร์ `BlockedListScreen`/`MutedListScreen`'s list/pagination/`RefreshIndicator` shape ตรงๆ — แต่ละแถว: avatar ของอีกฝ่าย, username/display name, preview ข้อความล่าสุด (ตัด 1 บรรทัด, ถ้าเป็นรูปแสดง "📷 รูปภาพ" แทนแคปชัน, ถ้าข้อความถูกลบแสดง "ข้อความถูกลบ" ตัวเอียงสีเทา), เวลาแบบ relative (`relativeTimeLabel`), unread indicator (จุดกลม Cyan ขนาดเล็กมุมขวาบนของ avatar ถ้ามี unread — ไม่ใช้ตัวเลข count ต่อแถวเพื่อความเรียบง่าย ต่างจาก badge รวมของ Screen 1 ที่เป็นตัวเลข)

**States**: Loading (spinner กลางจอ), Empty ("ยังไม่มีบทสนทนา" + icon `Icons.chat_bubble_outline` มิเรอร์ empty state ของทุกหน้า list ในแอปนี้), Error+Retry (มิเรอร์ pattern เดิม), List+pagination (infinite scroll, page size 20 มิเรอร์ `ModerationRepository`/`AppealRepository` เดิม)

**Interactions**: แตะแถว → เปิดบทสนทนา (และ mark-as-read ทันทีที่เปิดสำเร็จ) — long-press แถว → bottom sheet เล็ก: "ปิดแจ้งเตือน"/"เปิดแจ้งเตือน" (toggle mute บทสนทนานี้, optimistic ไม่มี confirm dialog มิเรอร์ WYN-028's mute toggle)

**Accessibility**: `Semantics` รวมทุก field ของแถวเหมือน `_ModerationQueueRow`/`_AppealQueueRow`'s pattern (`excludeSemantics: true` + label รวม)

---

## Screen 3 — Conversation Screen (`ConversationScreen`)

**Purpose**: หน้าสนทนาหลัก — ดู/ส่งข้อความ

**User Flow**: เปิดจาก Inbox (Screen 2) หรือจากปุ่ม "ส่งข้อความ" บนโปรไฟล์คนอื่น (Screen 4) → โหลดข้อความล่าสุดก่อน (reverse-chronological, infinite scroll ขึ้นด้านบนเพื่อโหลดข้อความเก่ากว่า) → subscribe realtime สำหรับข้อความใหม่ → mark-as-read ทันทีที่เปิดสำเร็จและทุกครั้งที่ข้อความใหม่มาถึงขณะเปิดหน้าอยู่

**Components**:
- `AppBar`: avatar+username ของอีกฝ่าย (แตะเปิด `ViewProfileScreen`), ปุ่ม "..." เปิดเมนู (Mute toggle / บล็อก / ดูโปรไฟล์)
- Message list: `ListView.builder(reverse: true)` — bubble ของตัวเองชิดขวา (พื้น Cyan อ่อน `WynColors` token ที่มีอยู่แล้ว, ตัวหนังสือเข้ม), bubble ของอีกฝ่ายชิดซ้าย (พื้นเทาอ่อน `surfaceContainer`) — ข้อความที่ reply แสดง quote แถบเล็กด้านบน bubble (พื้นหลังจางกว่า + เส้นซ้ายบาง Cyan) มิเรอร์ shape ทั่วไปของ reply-quote ในแอปแชท
- ข้อความที่ถูกลบ: bubble โทนเทาจาง ข้อความ "ข้อความนี้ถูกลบ" ตัวเอียง ไม่มี long-press menu
- รูปภาพ: bubble แสดง thumbnail สี่เหลี่ยม (ไม่ crop บังคับ 1:1 เหมือน Drop — คงสัดส่วนจริงแต่จำกัด max height) แตะเปิด full-screen (reuse `EvidenceImageViewer`'s shape จาก WYN-030 ตรงๆ — เปลี่ยนแค่ชื่อ/ไม่ต้อง signed-URL ถ้า bucket เป็น public หรือใช้ signed-URL ถ้า private ตามที่ Coding ตัดสินใจ)
- Message composer (ล่างสุด, sticky เหนือ keyboard): ปุ่มแนบรูป (icon), `TextField` ขยายได้หลายบรรทัด (`minLines: 1, maxLines: 6`), ปุ่มส่ง (disable จนกว่าจะมี text หรือรูป) — ถ้ากำลัง reply แสดงแถบ quote เหนือ composer พร้อมปุ่ม "×" ยกเลิก reply

**Interactions**:
- Long-press bubble ของตัวเอง → เมนู: "ตอบกลับ" / "ลบ" (confirm dialog เล็ก มิเรอร์ `ConfirmDeleteDialog` เดิม)
- Long-press bubble ของอีกฝ่าย → เมนู: "ตอบกลับ" / "รายงาน" (เปิด `ReportSheet` เดิม, `targetType: message`)
- แตะ quote-reply ใน bubble → เลื่อนไปยังข้อความต้นทาง (scroll-to, ถ้าข้อความต้นทางถูกลบไปแล้วก็ยังเลื่อนไปตำแหน่งเดิมได้เห็น placeholder)

**States**: Loading initial (spinner), Empty (ยังไม่มีข้อความ — "เริ่มบทสนทนากับ @username" + avatar ใหญ่), ระหว่างส่ง (optimistic: bubble ขึ้นทันทีสีจางกว่าเล็กน้อยจนกว่า insert จะ confirm — ถ้า fail แสดงไอคอน retry เล็กๆ), ถูก block (ถ้าอีกฝ่าย block เรา หรือเรา block เขา — composer หายไปทั้งหมด แทนที่ด้วยข้อความ "คุณไม่สามารถส่งข้อความถึงผู้ใช้นี้ได้" เหมือน pattern ของ `RestrictionBanner`), ถูก Restrict/Suspend/Ban (composer หายเหมือนกัน ข้อความ "คุณถูกจำกัดการโพสต์ชั่วคราว" reuse `RestrictionBanner` ตรงๆ ถ้าเป็นไปได้)

**Responsive**: composer + keyboard ต้องไม่บัง bubble ล่างสุด (`SafeArea` + `viewInsets.bottom` มิเรอร์ pattern ที่ `AppealDecisionSheet`/`ModerationActionSheet` ใช้)

**Accessibility**: แต่ละ bubble มี `Semantics` บอกผู้ส่ง+เวลา+เนื้อหา, ปุ่มส่งมี label "ส่งข้อความ"

---

## Screen 4 — "ส่งข้อความ" Entry Point บนโปรไฟล์คนอื่น

**Purpose**: เริ่มบทสนทนาใหม่จากโปรไฟล์คนอื่น

**ตำแหน่ง**: `ViewProfileScreen` (คนอื่น ไม่ใช่ตัวเอง) — ปุ่ม "ส่งข้อความ" วางข้าง/ใต้ปุ่ม Follow เดิม (`OutlinedButton`, ไม่ใช่ปุ่มหลักเพื่อไม่แย่ง emphasis จาก Follow) — **ไม่แสดงปุ่มนี้เมื่ออยู่ในสถานะ Blocked persona** (มิเรอร์ที่ WYN-027 ทำกับปุ่ม Follow ไปแล้ว — Blocked persona เหลือแค่ More menu "รายงาน" เท่านั้น)

**Interactions**: แตะ → เรียก `get_or_create_conversation(other_user_id)` RPC → เปิด `ConversationScreen` ทันที (ไม่ว่าจะเป็นบทสนทนาใหม่หรือเดิมที่มีอยู่แล้ว)

---

## Screen 5 — Delete Message Confirm

**Purpose**: ป้องกันการลบข้อความโดยไม่ตั้งใจ

**Components**: reuse `ConfirmDeleteDialog` เดิมตรงๆ (มิเรอร์ทุกจุดที่ใช้อยู่แล้วในแอป — Drop/Comment/Club Post delete) ข้อความ "ลบข้อความนี้? การลบไม่สามารถย้อนกลับได้"

---

## Screen 6 — Mute Conversation / Block / Report จากในหน้าแชท

**Purpose**: ทางเข้า Safety actions จากภายในบทสนทนา ไม่ต้องออกไปหน้าโปรไฟล์ก่อน

**Components**: เมนู "..." บน `AppBar` ของ `ConversationScreen` (Screen 3) — รายการ: "ปิดแจ้งเตือนบทสนทนานี้"/"เปิดแจ้งเตือนบทสนทนานี้" (toggle, optimistic ไม่มี confirm — มิเรอร์ WYN-028), "บล็อก" (reuse `block_dialogs.dart`'s confirm dialog ตรงๆ — บล็อกสำเร็จแล้วเปลี่ยนหน้าจอเป็น blocked-state ทันทีตาม Screen 3's States), "ดูโปรไฟล์" (เปิด `ViewProfileScreen`)

**Design Rules**: ไม่มี "รายงานบทสนทนา" ระดับรวม — Report เจาะจงเป็นรายข้อความเท่านั้น (ตาม Product spec's Requirements) ทางเข้า Report จึงอยู่ที่ long-press ข้อความ (Screen 3) ไม่ใช่เมนูนี้

---

## Screen 7 — Realtime Behavior (ไม่ใช่หน้าจอ แต่เป็น interaction spec ข้ามหน้าจอ)

- `ChatInboxScreen` subscribe realtime ต่อ `messages` insert ที่ `conversation_id` อยู่ใน list ของบทสนทนาที่ผู้ใช้เป็น participant — เมื่อมีข้อความใหม่: อัปเดต preview+เวลา+ย้ายแถวขึ้นบนสุดทันที ไม่ต้อง refetch ทั้งหน้า
- `ConversationScreen` subscribe realtime ต่อ `messages` insert ที่ `conversation_id` ตรงกับหน้าที่เปิดอยู่พอดี — เมื่อมีข้อความใหม่จากอีกฝ่าย: append เข้า list ทันที + mark-as-read ทันที (เพราะกำลังดูอยู่)
- ทั้งสอง subscription ต้อง unsubscribe เมื่อออกจากหน้าจอ (`dispose()`) ป้องกัน memory leak/duplicate listener — นี่คือความเสี่ยงที่ Product spec ระบุไว้แล้วว่าเป็นของใหม่ในโปรเจกต์ ต้องระวังเป็นพิเศษตอน Coding/QA

---

## Screen 8 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

**`conversations` table**:
```
id uuid pk
user_a_id uuid references profiles (canonical: uuid เล็กกว่าเสมอ)
user_b_id uuid references profiles (canonical: uuid ใหญ่กว่าเสมอ)
status text default 'active' check (status in ('active', 'pending'))  -- WYN-032 จะใช้ 'pending' ทีหลัง รอบนี้ insert 'active' เสมอ
user_a_last_read_at timestamptz
user_b_last_read_at timestamptz
created_at timestamptz
unique (user_a_id, user_b_id)
check (user_a_id <> user_b_id)
check (user_a_id < user_b_id)  -- บังคับ canonical ordering ที่ระดับ constraint ไม่ใช่แค่ convention
```
RLS: select/update จำกัดเฉพาะ `auth.uid() in (user_a_id, user_b_id)` — ไม่มี insert policy ตรง (ผ่าน RPC `get_or_create_conversation` เท่านั้น เพราะต้อง normalize ลำดับ uuid + เช็ค block/self ก่อน)

**`get_or_create_conversation(p_other_user_id uuid) returns uuid`** (security definer): validate ไม่ใช่ตัวเอง, validate ไม่ block กัน (`internal.is_blocked_either_way`), normalize `least`/`greatest` ของ `auth.uid()`/`p_other_user_id` เป็น `user_a_id`/`user_b_id`, `insert ... on conflict (user_a_id, user_b_id) do nothing`, แล้ว `select id` กลับมาเสมอ (ทั้ง insert ใหม่หรือมีอยู่แล้ว)

**`mark_conversation_read(p_conversation_id uuid) returns void`** (security definer): validate caller เป็น participant, `update conversations set user_a_last_read_at = now() where id = p_conversation_id and user_a_id = auth.uid()` (และ branch เดียวกันสำหรับ `user_b_id`)

**`messages` table**:
```
id uuid pk
conversation_id uuid references conversations
sender_id uuid references profiles
text text
image_url text
reply_to_message_id uuid references messages (nullable, self-referential)
deleted_at timestamptz
created_at timestamptz
check (deleted_at is not null or text is not null or image_url is not null)  -- ข้อความเปล่าไม่ได้ เว้นแต่ถูกลบแล้ว
```
RLS select: `auth.uid() in (select user_a_id/user_b_id from conversations where id = conversation_id)` (join แบบเดียวกับ pattern ของตารางอื่นที่ join เข้า parent เพื่อเช็คสิทธิ์)
RLS insert (`with check`): sender_id = auth.uid() + caller เป็น participant ของ conversation + `not internal.is_blocked_either_way(...)` + `not internal.is_posting_blocked(auth.uid())` + conversation.status = 'active' (กัน edge case ล่วงหน้าไว้ให้ WYN-032)
Trigger (มิเรอร์ `prevent_nested_club_post_comment_reply` ของ WYN-021/022 เป๊ะ): ถ้า `reply_to_message_id` ไม่ null ต้องอยู่ใน `conversation_id` เดียวกัน มิฉะนั้น raise exception

**`delete_message(p_message_id uuid) returns void`** (security definer): validate `sender_id = auth.uid()`, `update messages set text = null, image_url = null, deleted_at = now() where id = p_message_id` — ไม่มี UPDATE policy ตรงให้ client เลย (RPC-only มิเรอร์ pattern ของ appeals/moderation_actions)

**`conversation_mutes` table** (แยกขาดจาก `mutes` ของ WYN-028 โดยสิ้นเชิง):
```
conversation_id uuid references conversations
user_id uuid references profiles
created_at timestamptz
primary key (conversation_id, user_id)
```
RLS: insert/delete ตรงๆ จำกัด `auth.uid() = user_id` (มิเรอร์ `follows`/`mutes` เดิม ไม่มี RPC)

**`submit_report()` (WYN-026) ต้องเพิ่ม branch**: `elsif p_target_type = 'message' then` validate message มีอยู่จริงและ `sender_id <> auth.uid()` (รายงานข้อความตัวเองไม่ได้ มิเรอร์ทุก target type อื่น) และ **caller ต้องเป็น participant ของ conversation ที่ message นั้นอยู่** (กันคนนอกบทสนทนา report ข้อความที่ตัวเองไม่มีสิทธิ์เห็นด้วยซ้ำ)

**Realtime**: เปิด `alter publication supabase_realtime add table messages;` (หรือเทียบเท่าตาม convention ของ schema.sql ถ้ามี publication อื่นอยู่แล้ว) — RLS SELECT policy ของ `messages` ต้องครอบ Realtime ด้วยอัตโนมัติ (Supabase Realtime เคารพ RLS ของ `postgres_changes` subscription) แต่ Coding ต้อง**ทดสอบจริง**ไม่ใช่แค่สมมติ เพราะเป็นกลไกแรกในโปรเจกต์นี้ที่ใช้ Realtime

**ModerationQueueScreen (WYN-029) เดิม**: `ReportTargetType` enum ต้องเพิ่ม `.message` case (icon แนะนำ `Icons.chat_bubble_outline`, label "ข้อความ") — `ModerationTargetSummary`/`fetchTargetSummary()` ต้องรองรับดึงเนื้อหาข้อความมาแสดงในคิว (ถ้าข้อความถูกลบไปแล้วก่อนถูก report ให้แสดง "ข้อความนี้ถูกลบไปแล้ว" เหมือน pattern ของ `!summary.exists` ที่มีอยู่แล้ว)

## Handoff

AI Coding — เริ่มจาก data layer ตามลำดับ: (1) `conversations` table + RLS + `get_or_create_conversation()`/`mark_conversation_read()` RPC, (2) `messages` table + RLS + reply-validity trigger + `delete_message()` RPC, (3) `conversation_mutes` table + RLS, (4) `submit_report()` เพิ่ม `message` branch, (5) `ReportTargetType`/`ModerationTargetSummary` ขยายรองรับ `message`, (6) เปิด Realtime บน `messages` — แล้วเข้า UI: (7) `ChatRepository` ใหม่, (8) Screen 1 (Chat icon บน Home AppBar), (9) Screen 2 (`ChatInboxScreen`), (10) Screen 3 (`ConversationScreen` — realtime subscription ต้องทดสอบจริง ไม่ใช่แค่ compile ผ่าน), (11) Screen 4 (ปุ่ม "ส่งข้อความ" บน `ViewProfileScreen`), (12) Screen 5/6 (Delete confirm, Mute/Block/Report menu)
