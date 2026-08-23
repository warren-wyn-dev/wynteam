# Design — WYN-032 (Message Request flow)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-032-message-request.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `.wyn/docs/design/wyn-031-chat-1to1.md` — ใช้ schema/screens เดิมของ WYN-031 เป็นฐาน ไม่สร้างระบบใหม่ขนาน
> Design system: **Cyan `#00C8FF` เป็น primary ตาม DS-001–008 ทั้งหมด** — Rainbow (DS-009) ห้ามใช้ใน Chat แม้แต่จุดเดียว เหมือน WYN-031

## ภาพรวม — 5 การตัดสินใจเชิง scope

1. **`conversations.requested_by` เป็น column ใหม่เดียวที่เพิ่ม** (nullable, FK ไปยัง `profiles`) — บทสนทนา `active` เดิมทั้งหมดจาก WYN-031 ไม่ต้องมีค่านี้เลย ไม่ใช่ breaking change ต่อ schema เดิม
2. **`get_or_create_conversation()` ตัดสินใจ `status` เองตอนสร้างครั้งแรกเท่านั้น** — เช็คทิศทางเดียวว่าผู้รับ (`p_other_user_id`) follow ผู้เรียก (`auth.uid()`) อยู่แล้วหรือไม่ ถ้าใช่ = `'active'` (เหมือน WYN-031 เดิมทุกประการ) ถ้าไม่ = `'pending'` + บันทึก `requested_by = auth.uid()` + insert notification `message_request` — ไม่ re-evaluate ทีหลังถ้าความสัมพันธ์ follow เปลี่ยนไป (บทสนทนาที่มีอยู่แล้วเจอ existing row ก่อนเสมอ ไม่ผ่าน logic นี้ซ้ำ)
3. **ไม่สร้างหน้าจอแยกสำหรับดูคำขอ** — reuse `ConversationScreen` เดิมตรงๆ เพิ่มสถานะที่ 4 ในพื้นที่ composer (ต่อจาก Blocked/Restricted/Suspended ที่ WYN-031 มีอยู่แล้ว): "ฉันเป็นผู้รับที่ยังไม่ตัดสินใจ" → แสดงแถบ Accept/Delete/Block/Report แทน composer, ข้อความยังอ่านได้ปกติทุกอย่างเหมือนเดิม
4. **Message Requests list เป็นหน้าจอใหม่จริงจอเดียว** (`MessageRequestListScreen`) — มิเรอร์ `ChatInboxScreen`'s list shape เกือบทั้งหมด ต่างแค่ query source (`message_requests` view ใหม่) และไม่มี unread-dot (ทุกแถวคือ "ยังไม่ตัดสินใจ" อยู่แล้วโดยนิยาม)
5. **Block/Report จากหน้าคำขอ reuse RPC เดิมของ WYN-026/027 ตรงๆ ไม่มี RPC ใหม่** — มีแค่ 2 RPC ใหม่จริงคือ `accept_message_request()`/`delete_message_request()`

---

## Screen 1 — Message Requests Banner (บน `ChatInboxScreen` เดิม)

**Purpose**: ทางเข้ารายการคำขอข้อความที่ยังไม่ตัดสินใจ โดยไม่ปนกับกล่องข้อความหลัก

**ตำแหน่ง**: แถบเล็กด้านบนสุดของ `ChatInboxScreen` (เหนือรายการบทสนทนา) — แสดงเฉพาะเมื่อมีคำขอค้างอย่างน้อย 1 รายการ (ซ่อนไปเลยถ้าไม่มี ไม่โชว์ "0 คำขอ")

**Components**: `ListTile`-style banner พื้นหลัง `surfaceContainer` จาง, ไอคอน `Icons.mail_outline`, ข้อความ "คำขอข้อความ (N)", `trailing: Icons.chevron_right`

**Interactions**: แตะ → เปิด `MessageRequestListScreen` (Screen 2)

---

## Screen 2 — Message Requests List (`MessageRequestListScreen`)

**Purpose**: รายชื่อคำขอข้อความทั้งหมดที่ยังไม่ตัดสินใจ

**User Flow**: เปิดจาก Screen 1 → เห็นรายการ → แตะแถวใดแถวหนึ่ง → เปิด `ConversationScreen` ในสถานะ "pending-as-recipient" (Screen 3)

**Components**: มิเรอร์ `ChatInboxScreen`'s list/pagination/`RefreshIndicator` shape ตรงๆ — แต่ละแถว: avatar ของผู้ส่ง, username/display name, preview ข้อความล่าสุดที่ส่งมา (ตัด 1 บรรทัด, กติกาแสดงผลเดียวกับ `ChatInboxScreen` — รูปแสดง "📷 รูปภาพ", ข้อความว่างไม่มีทางเกิดเพราะ CHECK constraint กันไว้แล้ว), เวลาแบบ relative — **ไม่มี unread dot** (ทุกแถวในหน้านี้ "ยังไม่ตัดสินใจ" อยู่แล้วโดยนิยาม ไม่ต้องแยกอ่าน/ไม่อ่าน)

**States**: Loading/Empty ("ยังไม่มีคำขอข้อความ")/Error+Retry/List+pagination — มิเรอร์ `ChatInboxScreen` ทุกจุด

**Interactions**: แตะแถว → เปิด `ConversationScreen` (ไม่ mark-as-read เพราะคำขอไม่มีแนวคิด read/unread แบบ Chat ปกติ — การเปิดดูไม่เปลี่ยนสถานะใดๆ จนกว่าจะกด Accept/Delete/Block/Report จริง)

---

## Screen 3 — `ConversationScreen`'s สถานะที่ 4: Pending Request (ผู้รับ)

**Purpose**: ให้ผู้รับอ่านข้อความที่ยังไม่ Accept ได้เต็มที่ พร้อมตัดสินใจ โดยไม่เปิดทางพิมพ์ตอบจนกว่าจะ Accept

**เงื่อนไขเข้าสู่สถานะนี้**: `conversation.status == 'pending' && conversation.requestedBy != currentUserId` (ผู้ใช้ปัจจุบันไม่ใช่คนที่เริ่มบทสนทนา) — ถ้า `requestedBy == currentUserId` (ผู้ส่งเปิดดูบทสนทนาของตัวเองที่ยัง pending) ให้แสดง composer ปกติเหมือน WYN-031 ทุกประการ เพิ่มแค่ label เล็ก "รอการตอบรับ" เหนือ composer แบบไม่ block การพิมพ์

**Components** (แทนที่พื้นที่ composer เดิม — มิเรอร์ตำแหน่ง/ขนาดของ `RestrictionBanner`/Blocked/Suspended message เดิมที่ WYN-031 มีอยู่แล้ว):
- ข้อความอธิบายสั้น: "{username} ต้องการส่งข้อความถึงคุณ"
- แถวปุ่ม 2 คู่: **Accept** (`FilledButton`, Cyan) + **Delete** (`OutlinedButton`) แถวบน — **Block** + **Report** (ตัวหนังสือเทา, ขนาดเล็กกว่า, `TextButton`) แถวล่าง — แยกระดับความสำคัญทางสายตาชัดเจน (Accept/Delete คือการตัดสินใจหลัก, Block/Report คือทางเลือกรอง)

**Interactions**:
- **Accept** → เรียก `acceptMessageRequest()` → บทสนทนากลายเป็น `active` ทันที (optimistic local state update, ไม่ต้อง reload ทั้งหน้า) → พื้นที่ composer เปลี่ยนเป็นแบบปกติทันที ไม่ต้องออกจากหน้าจอ
- **Delete** → confirm dialog สั้น ("ลบคำขอนี้? ผู้ส่งจะไม่ได้รับแจ้งเตือน") → ยืนยัน → เรียก `deleteMessageRequest()` → `Navigator.pop()` กลับไป `MessageRequestListScreen` (แถวนั้นหายไปจากลิสต์)
- **Block** → reuse `block_dialogs.dart`'s confirm+action เดิมของ WYN-027 ตรงๆ → หลัง block สำเร็จ `Navigator.pop()` กลับ (บทสนทนายังอยู่ในระบบแต่ blocked-either-way แล้ว จะไม่ปรากฏใน `message_requests` view อีกต่อไป — ดู Screen 5's Data Notes)
- **Report** → reuse `ReportSheet` เดิมของ WYN-026 ตรงๆ, `targetType: ReportTargetType.user`, `targetId: otherUserId` — ไม่ปิดหน้าจอหลัง report สำเร็จ (ผู้ใช้อาจยังต้องการ Delete/Block ต่อ)

**ข้อความยังอ่านได้ปกติเต็มรูปแบบ** — message list ด้านบน (bubble, reply quote, รูปภาพ, long-press เพื่อรายงานข้อความเดี่ยว) ทำงานเหมือน WYN-031 ทุกประการ ไม่มีการเปลี่ยนแปลงเลย — สิ่งเดียวที่เปลี่ยนคือพื้นที่ composer ด้านล่าง

---

## Screen 4 — Notification: `message_request`

**Purpose**: แจ้งผู้รับทันทีที่มีคำขอข้อความใหม่ (ไม่ต้องเปิดแอปเข้ามาเช็ค badge เอง)

**Components**: แถวมาตรฐานของ `NotificationListScreen` เดิม (avatar ผู้ส่ง + ข้อความ "{username} ส่งคำขอข้อความถึงคุณ") — แตะ → เปิด `ConversationScreen` ตรงในสถานะ pending-as-recipient (Screen 3) ทันที ไม่ผ่าน `MessageRequestListScreen`

**Data**: `actor_id` = ผู้ส่ง (ไม่ใช่กรณี null-actor แบบ moderation — นี่คือการกระทำปกติของผู้ใช้จริง ไม่ใช่การตัดสินใจของ moderator ที่ต้องซ่อนตัวตน) — insert โดย `get_or_create_conversation()` เอง ครั้งเดียวตอนสร้างคำขอใหม่ ไม่ insert ซ้ำถ้าเรียกซ้ำ (existing row เจอก่อนเสมอ)

---

## Screen 5 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

```sql
alter table public.conversations
  add column if not exists requested_by uuid references public.profiles (id) on delete cascade;

alter table public.conversations
  add constraint conversations_requested_by_is_participant
  check (requested_by is null or requested_by in (user_a_id, user_b_id));

-- get_or_create_conversation(): เพิ่ม logic ตัดสินใจ status ตอนสร้างแถวใหม่เท่านั้น
--   - ถ้า p_other_user_id follow auth.uid() อยู่แล้ว (exists ... follows where follower_id =
--     p_other_user_id and following_id = auth.uid()) -> status = 'active', requested_by = null
--   - ไม่งั้น -> status = 'pending', requested_by = auth.uid() + insert notification 'message_request'
--     (recipient_id = p_other_user_id, actor_id = auth.uid())
--   - แถวที่มีอยู่แล้ว (existing conversation) return ตรงๆ ไม่ผ่าน logic นี้ซ้ำ ไม่ insert notification ซ้ำ

create or replace function public.accept_message_request(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.conversations
  set status = 'active'
  where id = p_conversation_id and status = 'pending'
    and auth.uid() in (user_a_id, user_b_id)
    and requested_by is distinct from auth.uid();  -- ผู้ส่ง accept คำขอของตัวเองไม่ได้
  if not found then
    raise exception 'Message request not found, already accepted, or not yours to accept';
  end if;
end;
$$;

create or replace function public.delete_message_request(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.conversations
  where id = p_conversation_id and status = 'pending'
    and auth.uid() in (user_a_id, user_b_id)
    and requested_by is distinct from auth.uid();  -- ผู้ส่งลบคำขอของตัวเองไม่ได้ (มีแต่ Delete Message ปกติ)
  -- messages.conversation_id มี on delete cascade อยู่แล้วจาก WYN-031 -- ลบ conversation ลบข้อความทั้งหมดไปด้วยอัตโนมัติ
  if not found then
    raise exception 'Message request not found, already accepted, or not yours to delete';
  end if;
end;
$$;

-- messages INSERT policy: แก้จาก "status = 'active' เท่านั้น" เป็น
-- "active หรือ (pending และผู้ส่งคือ requested_by)" -- ผู้เริ่มคำขอยังส่งเพิ่มได้
-- ระหว่างรอ แต่ผู้รับส่งไม่ได้เลยจนกว่าจะ accept (ไม่มี INSERT policy ให้ทางอื่น)

create or replace view public.message_requests with (security_invoker = true) as
select
  c.id as conversation_id, c.created_at as conversation_created_at,
  case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end as other_user_id,
  op.username as other_username, op.display_name as other_display_name, op.avatar_url as other_avatar_url,
  lm.text as last_message_text, lm.image_url as last_message_image_url, lm.created_at as last_message_at
from public.conversations c
join public.profiles op on op.id = (case when c.user_a_id = auth.uid() then c.user_b_id else c.user_a_id end)
left join lateral (
  select m.text, m.image_url, m.created_at from public.messages m
  where m.conversation_id = c.id order by m.created_at desc limit 1
) lm on true
where c.status = 'pending'
  and c.requested_by <> auth.uid()  -- เฉพาะผู้รับเห็น ไม่ใช่ผู้ส่ง
  and auth.uid() in (c.user_a_id, c.user_b_id)
  and not internal.is_blocked_either_way(c.user_a_id, c.user_b_id);  -- block แล้ว = ไม่ต้องถามอีก

-- chat_inbox view: WHERE เดิม `auth.uid() in (...)` เพิ่มเงื่อนไข
-- `and (status = 'active' or requested_by = auth.uid())` -- ผู้ส่งเห็นคำขอของตัวเองใน
-- Inbox หลักตามปกติ (พร้อม label "รอการตอบรับ" ฝั่ง client), ผู้รับไม่เห็นจนกว่าจะ accept
-- เพิ่ม requested_by เป็นคอลัมน์ในผลลัพธ์ (ให้ client รู้ว่าใครต้องเป็นคน Accept)
```

**นับ badge**: `countPendingMessageRequests()` = `select count(*) from message_requests` (ใช้ view ที่กรอง block-either-way ไว้แล้ว ไม่ต้องเขียน RPC แยก) — Chat icon badge (Screen 1 ของ WYN-031) รวมค่านี้เข้ากับ `countUnreadConversations()` เดิม

**Report ข้อความเดี่ยวจากใน pending conversation**: ใช้เมนู long-press เดิมของ WYN-031 ได้ปกติทุกจุด (ไม่ต้องแก้อะไรเพิ่ม — RLS ของ `messages` SELECT policy ไม่เคยเช็ค `status` เลย ข้อความอ่านได้เสมอตราบใดที่เป็น participant)

---

## Handoff

AI Coding — เริ่มจาก (1) SQL: `requested_by` column + constraint, แก้ `get_or_create_conversation()`, `accept_message_request()`/`delete_message_request()` RPCs ใหม่, แก้ messages INSERT policy, `message_requests` view ใหม่, แก้ `chat_inbox` view, notification type `message_request` (2) Flutter data layer: ขยาย `Conversation`/`ChatMessage` models + `ChatRepository` (3) `MessageRequestListScreen` + banner บน `ChatInboxScreen` (4) `ConversationScreen`'s สถานะที่ 4 (5) notification type + badge sum — ทดสอบ regression ของ WYN-031 เดิมทุกจุดว่ายังทำงานปกติ (โดยเฉพาะบทสนทนาที่ follow กันอยู่แล้วต้อง active ทันทีไม่ผ่าน gate ใดๆ)
