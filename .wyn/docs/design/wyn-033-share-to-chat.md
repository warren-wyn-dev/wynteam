# Design — WYN-033 (Share เข้า Chat)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-033-share-to-chat.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `.wyn/docs/design/wyn-031-chat-1to1.md`/`wyn-032-message-request.md` — ใช้ schema/screens เดิมเป็นฐาน ไม่สร้างระบบขนาน
> Design system: **Cyan `#00C8FF` เป็น primary ตาม DS-001–008 ทั้งหมด** — Rainbow (DS-009) ห้ามใช้ใน Chat แม้แต่จุดเดียว เหมือน WYN-031/032

## ภาพรวม — 5 การตัดสินใจเชิง scope

1. **`messages` เพิ่ม 2 column ใหม่แบบ polymorphic ไม่มี FK** (`shared_content_type text check (in ('drop','profile','club'))`, `shared_content_id uuid`) — มิเรอร์ pattern เดียวกับ `reports.target_type`/`target_id` ที่มีอยู่แล้วในโปรเจกต์นี้ (อ้างอิงได้ 3 ตารางต่างกัน ไม่มี FK เดียวที่ครอบคลุมได้)
2. **ไม่ denormalize เนื้อหาลง `messages` เลย** — เก็บแค่ type+id, resolve ผ่าน repository เดิมตอนแสดงผลจริง (`DropRepository.fetchById()`/`ClubRepository.fetchClub()`/`ProfileRepository.fetchProfile()`) — ทำให้ RLS/block-visibility เดิมทำงานถูกต้องอัตโนมัติ ไม่ต้องเขียนกลไก privacy ใหม่เลยสักจุด (มิเรอร์ pattern ที่ `NotificationListScreen` ใช้อยู่แล้วสำหรับ dropId/popId/clubPostId — resolve ตอนเปิดดู ไม่ join เข้าแถวแจ้งเตือน)
3. **หน้าเลือกบทสนทนาเป็น single-tap-to-send** — แตะแถวเดียวส่งทันที ไม่มี multi-select/ปุ่มยืนยันซ้ำ (ตาม Product spec's Risk ที่ยอมรับไว้แล้ว)
4. **Share sheet มีแค่ 2 ตัวเลือก** (แชร์เข้า Chat / แชร์ผ่านระบบมือถือ) — ปุ่ม "คัดลอกลิงก์" ของ Drop ที่แยกอยู่แล้วไม่เปลี่ยน ไม่ยุบรวม
5. **`ConversationScreen` เพิ่ม `ClubRepository`/`ClubPostRepository` เป็น optional param ใหม่** (มิเรอร์ pattern เดิมของ `DropRepository`/`ProfileRepository` ฯลฯ ที่มีอยู่แล้ว) — จำเป็นสำหรับเปิด `ClubPage` จริงตอนแตะ preview card ประเภท club

---

## Screen 1 — Share Sheet (บน Drop/Club ปุ่ม "แชร์" เดิม)

**Purpose**: ทางเลือกเมื่อกด "แชร์" — เพิ่ม "แชร์เข้า Chat" เข้าไปข้าง "แชร์ผ่านระบบมือถือ" เดิม

**ตำแหน่ง**: ปุ่ม "แชร์" (ไอคอน `Icons.share_outlined`) ของ `DropDetailScreen`/`ClubPage` เดิม — `onPressed` เปลี่ยนจากเรียก `_share()` ตรงๆ เป็นเปิด `showModalBottomSheet` เล็ก 2 รายการ

**Components**: `ListTile` × 2 — "แชร์เข้า Chat" (icon `Icons.chat_bubble_outline`) / "แชร์ผ่านระบบมือถือ" (icon `Icons.ios_share`, เรียก `_share()` เดิมตรงๆ)

**Interactions**: แตะ "แชร์เข้า Chat" → ปิด sheet → เปิด `ShareToChatScreen` (Screen 3) พร้อม `sharedContentType`/`sharedContentId`/preview label ที่เกี่ยวข้อง

---

## Screen 2 — "แชร์โปรไฟล์" ใน Profile's "..." Menu เดิม

**Purpose**: ทางเข้าแชร์ Profile — ไม่เคยมีปุ่มแชร์ Profile มาก่อนเลย

**ตำแหน่ง**: เพิ่ม `ListTile` ใหม่ใน `_openMoreMenu()` เดิมของ `ViewProfileScreen` (ที่ WYN-026/027/028 ต่อยอดมาตลอด) — วางไว้บนสุด (ก่อน "รายงาน") เพราะไม่ใช่ safety action แยกกลุ่มด้วย `Divider` บางๆ จาก 3 รายการเดิม (รายงาน/ปิดเสียง/บล็อก)

**Components**: `ListTile(leading: Icons.share_outlined, title: 'แชร์โปรไฟล์')` — แตะแล้วเปิด Share Sheet (Screen 1's เดียวกัน แต่ไม่มีตัวเลือก native-share แยก เพราะ Profile ไม่เคยมี — ใช้ sheet เดียวกันได้เพราะ 2 ตัวเลือกเหมือนกันทั้ง 3 ประเภท)

---

## Screen 3 — Share to Chat Picker (`ShareToChatScreen`)

**Purpose**: เลือกบทสนทนา (เดิมหรือใหม่) เพื่อส่งเนื้อหาที่แชร์เข้าไป

**User Flow**: เปิดจาก Share Sheet → เห็นรายการบทสนทนาเดิม + ช่องค้นหา → แตะแถว/ผลค้นหา → ส่งทันที → snackbar ยืนยัน → `Navigator.pop()` กลับไปจุดเริ่มแชร์ (ไม่พาเข้าบทสนทนา)

**Components**:
- `AppBar`: title "แชร์เข้า Chat"
- แถบ preview เล็กด้านบน (ไม่ทำอะไร แค่ยืนยันว่ากำลังแชร์อะไรอยู่): icon/thumbnail เล็ก + label ("แชร์ Drop"/"แชร์โปรไฟล์ @username"/"แชร์ Club {name}")
- `TextField` ค้นหา (มิเรอร์ `SearchUserResultsTab`'s query pattern — debounce/min-length เดียวกัน) — reuse `ProfileRepository.searchProfiles()` ตรงๆ
- ถ้าช่องค้นหาว่าง: แสดงรายชื่อบทสนทนาที่มีอยู่แล้ว (reuse `ChatRepository.fetchInbox()`/`ChatInboxScreen`'s row shape — avatar+ชื่อ ไม่ต้องมี preview ข้อความล่าสุด/unread dot เพราะไม่เกี่ยวกับหน้านี้)
- ถ้าช่องค้นหาไม่ว่าง: แสดงผลค้นหาผู้ใช้แทน (avatar+username+display name)

**Interactions**: แตะแถวบทสนทนาเดิม → เรียก `sendMessage()` ตรงด้วย `conversationId` ที่มีอยู่แล้ว — แตะผลค้นหา → เรียก `getOrCreateConversation()` ก่อน (ผ่าน gate ของ WYN-032 ตามปกติ) แล้ว `sendMessage()` — ทั้งสองทางจบด้วย snackbar "แชร์แล้ว" + pop กลับ

**States**: Loading/Empty ("ยังไม่มีบทสนทนา — ค้นหาผู้ใช้เพื่อเริ่มแชร์")/Error ต่อการส่ง (snackbar "แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง" ไม่ปิดหน้าจอ ให้ลองแถวอื่นได้)

---

## Screen 4 — Shared Content Preview Card (ใน `ConversationScreen`'s message bubble)

**Purpose**: แสดงเนื้อหาที่แชร์มาให้ดูได้ทันทีในบทสนทนา โดยไม่ denormalize เนื้อหาจริงลงแถว

**Components** (แทนที่/เพิ่มเข้าไปในพื้นที่เนื้อหาของ `_MessageBubble` เดิม เมื่อ `message.sharedContentType != null`):
- Container พื้นหลังจางกว่า bubble เล็กน้อย, มุมโค้ง, มี border บาง — โครงสร้างตามประเภท:
  - **Drop**: thumbnail สี่เหลี่ยม (มิเรอร์ ratio เดียวกับ image message ที่มีอยู่แล้ว) + แถวล่าง avatar เล็ก+username ผู้โพสต์ + caption 1 บรรทัด (ถ้ามี)
  - **Profile**: avatar วงกลม + display name + @username + bio 1 บรรทัด (ถ้ามี)
  - **Club**: icon สี่เหลี่ยมมุมโค้ง (หรือ placeholder ถ้าไม่มี) + ชื่อ Club + description 1 บรรทัด (ถ้ามี)
- Loading: skeleton แถวเดียวกว้างเท่า card (ไม่ใช้ spinner เดี่ยวกลาง เพราะ card มีขนาดคงที่อยู่แล้ว)
- ไม่พบ/ถูกลบ/ถูกบล็อกไม่ให้เห็น: "เนื้อหานี้ไม่พร้อมใช้งาน" ตัวเอียงสีเทา ไม่มี tap action (มิเรอร์ข้อความ "ข้อความนี้ถูกลบ" ของ deleted message เดิม)
- Caption (ถ้าผู้แชร์พิมพ์ประกอบ): แสดงเป็นข้อความปกติใต้ card เหมือน text message ทั่วไป (ใช้ `message.text` เดิม ไม่ต้อง field ใหม่)

**Interactions**: แตะ card (เมื่อโหลดสำเร็จเท่านั้น) → เปิดหน้าเนื้อหาจริง (`DropDetailScreen`/`ViewProfileScreen`/`ClubPage` เดิม) — long-press ยังเปิดเมนู reply/delete/report เดิมได้ปกติทุกประการ (ไม่เปลี่ยนพฤติกรรม)

**Fetch timing**: lazy ต่อ bubble ตอน build ครั้งแรก (`FutureBuilder`-style), cache ผลลัพธ์ไว้ใน state ของ `_MessageBubble`'s parent (`_ConversationScreenState`) แบบ `Map<String, Object?>` keyed ด้วย `'$type:$id'` กัน fetch ซ้ำตอน scroll ทำให้ widget rebuild

---

## Screen 5 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

```sql
alter table public.messages
  add column if not exists shared_content_type text
    check (shared_content_type is null or shared_content_type in ('drop', 'profile', 'club'));
alter table public.messages
  add column if not exists shared_content_id uuid;

-- messages_not_blank_unless_deleted ต้องขยายเงื่อนไข: เพิ่ม
-- "or shared_content_id is not null" (การ์ดแชร์เนื้อหาไม่มี text/image_url
-- เลยก็ยังไม่ถือว่า blank -- caption เป็น optional เสมอ)

-- delete_message() ต้อง null-out shared_content_type/shared_content_id
-- ด้วย ไม่ใช่แค่ text/image_url เดิม -- บทเรียนเดียวกับที่โปรเจกต์นี้ยึด
-- มาตลอด (RLS row-level ไม่ใช่ column-level)

-- ไม่มี RLS/policy ใหม่ใดๆ เพิ่ม -- messages INSERT/SELECT policy เดิม
-- ของ WYN-031/032 ครอบคลุมแถวที่มี shared_content_* อยู่แล้วโดยอัตโนมัติ
-- (เงื่อนไขเดิมไม่แคร์ว่า text/image_url/shared_content_id field ไหน
-- ถูกใช้งาน) -- ความปลอดภัยของ*เนื้อหาที่ถูกอ้างอิง*เกิดจาก RLS เดิมของ
-- drops/clubs/profiles เอง ตอน resolve ฝั่ง client ไม่ใช่ policy ใหม่
-- บนตัว messages
```

**ไม่มี RPC ใหม่** — ส่งข้อความแชร์เนื้อหาใช้ path เดิมทุกประการ (`messages` INSERT ตรงๆ ผ่าน `ChatRepository.sendMessage()` ที่ขยายรับ `sharedContentType`/`sharedContentId` เพิ่ม 2 param optional)

---

## Handoff

AI Coding — เริ่มจาก (1) SQL: 2 column ใหม่ + ขยาย CHECK constraint + แก้ `delete_message()` (2) Flutter data layer: ขยาย `ChatMessage`/`ChatRepository.sendMessage()` (3) `ShareToChatScreen` ใหม่ (4) Share Sheet widget ใช้ร่วมกัน 3 จุด (Drop/Club ปุ่มแชร์เดิม, Profile's "..." menu ใหม่) (5) `ConversationScreen`'s shared-content preview card (Screen 4) + `ClubRepository`/`ClubPostRepository` param ใหม่ — ทดสอบ regression ของ WYN-031/032 เดิมทุกจุดว่ายังทำงานปกติ
