# AI Design — WYN-132: DM Message Actions — Edit + Pin (1:1 Chat)

Owner: AI Design
ต่อยอดจาก Product Task `.wyn/tasks/active/WYN-132-dm-message-edit-pin.md`

WYN design system ที่อนุมัติแล้ว: ใช้ token/component เดิมทั้งหมด (`WynColors`, `WynSpacing`, `ActionSheetRow`/`ActionSheetBody`, `_MessageBubble` เดิมของ `ConversationScreen`) — ไม่มีทิศทาง visual ใหม่

## โครงสร้างที่ตรวจสอบจากโค้ดจริงแล้ว

- `public.messages` (WYN-031): `text`, `image_url`, `shared_content_type`/`shared_content_id` (WYN-033), `deleted_at`, `reply_to_message_id` — ไม่มีคอลัมน์ edit ใดๆ ตอนนี้
- `delete_message(p_message_id)` RPC: soft delete โดย null-out `text`/`image_url`/`shared_content_*` แล้ว set `deleted_at` — เป็น RPC เดียวที่แก้ไข `messages` row ที่มีอยู่แล้ว (ไม่มี client UPDATE policy บน `messages` เลย — ทุก mutation ของแถวเดิมต้องผ่าน RPC เท่านั้น)
- `subscribeToConversationMessages(conversationId, onInsert, {onUpdate})`: subscribe UPDATE event บน `messages` อยู่แล้ว (ใช้สำหรับ View Once ปัจจุบัน) — **reuse ได้ตรงๆ สำหรับ Edit** ไม่ต้องสร้าง channel ใหม่
- `_showMessageMenu(message)` ใน `ConversationScreen`: bottom sheet เดิม (ตอบกลับ/ลบ/รายงาน) — จุดต่อขยายสำหรับ Edit/Pin
- `_scrollToMessage(messageId)` + `_bringMessageIntoBuildRange`: กลไก jump-to-message ที่มีอยู่แล้วจาก reply-quote (WYN-031) — reuse ตรงๆ สำหรับ "แตะข้อความปักหมุด → jump ไปตำแหน่งจริง"

## Schema / Data Model

### Edit Message

1. เพิ่มคอลัมน์บน `messages`:
   ```sql
   alter table public.messages add column if not exists edited_at timestamptz;
   ```
2. RPC ใหม่ `edit_message`, mirror `delete_message()`'s ท่าเดิม (security definer, ไม่มี client UPDATE policy):
   ```sql
   create or replace function public.edit_message(p_message_id uuid, p_text text)
   returns void
   language plpgsql
   security definer
   set search_path = public
   as $$
   declare
     v_trimmed text := trim(coalesce(p_text, ''));
   begin
     if length(v_trimmed) = 0 then
       raise exception 'Message text cannot be empty';
     end if;

     update public.messages
     set text = v_trimmed, edited_at = now()
     where id = p_message_id
       and sender_id = auth.uid()
       and deleted_at is null
       -- Requirement: "เฉพาะข้อความ text เท่านั้น" -- ตีความอย่างเคร่งครัด
       -- ตัดข้อความที่มีรูป/shared-content แนบออกทั้งหมด แม้จะมี caption
       -- text อยู่ด้วยก็ตาม เพื่อไม่ให้กำกวมว่า "แก้ไขได้แค่ caption
       -- ของรูปไหม" -- ถ้า Founder ต้องการแก้ caption ของรูป/shared
       -- content ทีหลัง ทำเป็น fast-follow แยก ไม่ใช่ scope รอบนี้
       and image_url is null
       and shared_content_id is null;

     if not found then
       raise exception 'Message not found, not yours, deleted, or not a plain text message';
     end if;
   end;
   $$;

   grant execute on function public.edit_message(uuid, text) to authenticated;
   ```
   ไม่ต้องแก้ RLS ใดๆ บน `messages` (RPC bypass ผ่าน security definer เหมือน `delete_message`)

### Pin Message

3. ตารางใหม่ `message_pins`:
   ```sql
   create table if not exists public.message_pins (
     conversation_id uuid not null references public.conversations (id) on delete cascade,
     message_id uuid not null references public.messages (id) on delete cascade,
     pinned_by uuid not null references public.profiles (id) on delete cascade,
     pinned_at timestamptz not null default now(),
     primary key (conversation_id, message_id)
   );

   create index if not exists message_pins_conversation_idx
     on public.message_pins (conversation_id, pinned_at desc);

   alter table public.message_pins enable row level security;

   create policy "Participants can view pinned messages in their conversations"
     on public.message_pins
     for select
     to authenticated
     using (
       exists (
         select 1 from public.conversations c
         where c.id = conversation_id and auth.uid() in (c.user_a_id, c.user_b_id)
       )
     );

   -- ไม่มี insert/update/delete policy ให้ client -- pin_message()/
   -- unpin_message() ด้านล่างเป็นทางเดียวที่แก้ตารางนี้ได้ (เหมือนท่า
   -- messages/club_members ทุกจุดที่ต้อง cross-row business logic --
   -- ในที่นี้คือ "จำกัด 3 ต่อบทสนทนา")
   ```
4. RPC `pin_message`:
   ```sql
   create or replace function public.pin_message(p_message_id uuid)
   returns void
   language plpgsql
   security definer
   set search_path = public
   as $$
   declare
     v_me uuid := auth.uid();
     v_conversation_id uuid;
     v_deleted_at timestamptz;
     v_count int;
   begin
     select conversation_id, deleted_at into v_conversation_id, v_deleted_at
     from public.messages where id = p_message_id;

     if v_conversation_id is null then
       raise exception 'Message not found';
     end if;
     if v_deleted_at is not null then
       raise exception 'Cannot pin a deleted message';
     end if;
     if not exists (
       select 1 from public.conversations c
       where c.id = v_conversation_id and v_me in (c.user_a_id, c.user_b_id)
     ) then
       raise exception 'Not a participant of this conversation';
     end if;

     select count(*) into v_count from public.message_pins where conversation_id = v_conversation_id;
     if v_count >= 3 then
       raise exception 'At most 3 pinned messages allowed per conversation';
     end if;

     insert into public.message_pins (conversation_id, message_id, pinned_by)
     values (v_conversation_id, p_message_id, v_me)
     on conflict (conversation_id, message_id) do nothing;
   end;
   $$;

   grant execute on function public.pin_message(uuid) to authenticated;
   ```
5. RPC `unpin_message`:
   ```sql
   create or replace function public.unpin_message(p_message_id uuid)
   returns void
   language plpgsql
   security definer
   set search_path = public
   as $$
   declare
     v_me uuid := auth.uid();
   begin
     delete from public.message_pins mp
     using public.conversations c
     where mp.message_id = p_message_id
       and mp.conversation_id = c.id
       and v_me in (c.user_a_id, c.user_b_id);

     if not found then
       raise exception 'Pinned message not found, or you are not a participant';
     end if;
   end;
   $$;

   grant execute on function public.unpin_message(uuid) to authenticated;
   ```
   หมายเหตุ: ตั้งใจไม่จำกัดว่า unpin ได้เฉพาะคนที่ pin เอง — ตรงตาม Requirement "ผู้เข้าร่วมบทสนทนาฝ่ายใดฝ่ายหนึ่งก็ปักหมุดได้" (implicitly รวม unpin ด้วย เพราะ DM เป็นพื้นที่ 2 คนเท่าเทียมกัน ไม่มีลำดับชั้นแบบ Club)
6. **แก้ `delete_message()` ที่มีอยู่แล้ว** ให้ auto-unpin (FK `on delete cascade` ใช้ไม่ได้ เพราะ `delete_message()` เป็น soft-delete ผ่าน UPDATE ไม่ใช่ DELETE จริงบน `messages` row):
   ```sql
   create or replace function public.delete_message(p_message_id uuid)
   ...
   begin
     update public.messages
     set text = null, image_url = null, shared_content_type = null, shared_content_id = null, deleted_at = now()
     where id = p_message_id and sender_id = auth.uid() and deleted_at is null;

     if not found then
       raise exception 'Message not found, already deleted, or not yours';
     end if;

     delete from public.message_pins where message_id = p_message_id;
   end;
   $$;
   ```
7. Fetch pinned messages: query ธรรมดาผ่าน RLS ปกติ (ไม่ต้องมี RPC พิเศษ เพราะ SELECT policy ข้อ 3 อนุญาตอยู่แล้ว):
   ```sql
   select mp.message_id, mp.pinned_at, mp.pinned_by, m.text, m.image_url, m.deleted_at, m.sender_id
   from public.message_pins mp
   join public.messages m on m.id = mp.message_id
   where mp.conversation_id = $1
   order by mp.pinned_at desc;
   ```

## Realtime

- **Edit**: reuse `subscribeToConversationMessages`'s `onUpdate` callback เดิม 100% ไม่ต้อง subscribe เพิ่ม — `messages` UPDATE event เดิมที่ตอนนี้ใช้กับ View Once จะยิงสำหรับ `edit_message()` ด้วยเช่นกัน (เป็น UPDATE บนตารางเดียวกัน)
  - **จุดที่ AI Coding ต้องระวัง (พบระหว่างตรวจโค้ดจริง)**: `_onRealtimeMessageUpdate` ปัจจุบันแทนที่ทั้งแถวด้วย `ChatMessage.fromMap(payload.newRecord)` ตรงๆ — payload ดิบของ `postgres_changes` **ไม่มี** embed ของ `reply_to` (เหมือนที่ comment ของ `_handleRealtimeInsert` อธิบายไว้แล้วสำหรับ insert) ดังนั้นถ้าข้อความที่ถูกแก้ไขเป็น reply อยู่ การแทนที่ทั้งแถวแบบเดิมจะทำให้ reply-quote preview หายไปจากหน้าจอฝั่งอีกคนจนกว่าจะ reload/pull-to-refresh — ต้อง merge เฉพาะฟิลด์ที่เปลี่ยนจริง (`text`, `edited_at`) เข้ากับ `_messages[index]` เดิมแทนการแทนที่ทั้งก้อน (คงค่า `replyPreviewText`/`replyPreviewImageUrl`/`replyPreviewDeletedAt` เดิมไว้ เพราะ `reply_to_message_id` ไม่มีทางเปลี่ยนจากการ edit) — เป็นการแก้ pattern ที่มีอยู่แล้วให้ปลอดภัยขึ้น ไม่ใช่ regression ใหม่จากงานนี้ (View Once เดิมไม่โดนปัญหานี้เพราะรูป View Once ไม่เคยเป็น reply ในทางปฏิบัติ)
- **Pin/Unpin**: subscribe เบาๆ แบบเดียวกับ `subscribeToConversationMeta` — channel ใหม่ `conversation-pins-$conversationId` ฟัง INSERT+DELETE บน `message_pins` filter `conversation_id = eq.$conversationId` → เมื่อมี event ใดๆ เกิดขึ้น **fetch รายการ pinned ใหม่ทั้งหมดใหม่** (ไม่พยายาม patch จาก payload) เพราะ DELETE payload ของ Postgres logical replication ไม่รับประกันว่ามีคอลัมน์ครบ (ขึ้นกับ REPLICA IDENTITY) — fetch-on-any-change ปลอดภัยกว่าและ query เบามาก (สูงสุด 3 แถว join)

## UI / UX Flow

### Edit

1. Long-press ข้อความ text ของตัวเอง (ที่ไม่มีรูป/shared content แนบ, ยังไม่ถูกลบ) → `_showMessageMenu` เดิม เพิ่มแถวใหม่ **"แก้ไข"** (icon `Icons.edit_outlined`) ต่อจาก "ตอบกลับ" ก่อน "ลบ"
2. กด "แก้ไข" → composer ด้านล่างเปลี่ยนเป็น **edit mode**: แถบแบนเนอร์เหนือ text field (โครงเดียวกับแถบ "กำลังตอบกลับ" ที่มีอยู่แล้วสำหรับ `_replyTo` — เปลี่ยนแค่ label เป็น "กำลังแก้ไขข้อความ" + ปุ่ม X ยกเลิก) พร้อม prefill ข้อความเดิมใน `TextField` และโฟกัสทันที ปุ่มส่งเปลี่ยนไอคอนจากกระดาษเครื่องบินเป็นเครื่องหมายถูก (✓ บันทึก)
3. กดยืนยัน → เรียก `ChatRepository.editMessage(messageId, text)` → optimistic update ทันที (คล้าย pattern optimistic ของ `_send()`) → สำเร็จเคลียร์ edit mode กลับ composer ปกติ / ล้มเหลว SnackBar "แก้ไขข้อความไม่สำเร็จ ลองใหม่อีกครั้ง" (mirror wording เดิมของ `_deleteMessage`) และคงข้อความที่พิมพ์ไว้ในแถบแก้ไขไม่หาย
4. บับเบิลที่มี `editedAt != null` แสดง label เล็ก สีเทา (mirror wording การลบ "ข้อความนี้ถูกลบแล้ว" แต่ไม่ใช่ placeholder แทนเนื้อหา — วางต่อท้าย/ใต้เนื้อหาข้อความจริงในบับเบิลเดียวกัน) ข้อความ: **"แก้ไขแล้ว"** — แสดง**ถาวรเสมอ**ไม่มี tap-to-reveal/ซ่อน (ตรงตาม Requirement "ห้ามซ่อน")

### Pin

5. Long-press ข้อความใดก็ได้ (ของตัวเองหรือของอีกฝ่าย, ที่ไม่ถูกลบ) → `_showMessageMenu` เพิ่มแถวใหม่ท้ายสุด: **"ปักหมุดข้อความ"** (ยังไม่ปักอยู่) หรือ **"เลิกปักหมุด"** (ปักอยู่แล้ว) — ต้อง fetch สถานะ pinned ของข้อความนั้นตอนเปิดเมนู (เช็คจาก local pinned-list ที่โหลดไว้แล้วในหน้าจอ ไม่ต้อง query ใหม่)
6. กด "ปักหมุดข้อความ" ขณะที่ปักครบ 3 อันแล้ว → เรียก RPC ตามปกติ (ไม่ precompute count ฝั่ง client ก่อนเปิดเมนู เพื่อความเรียบง่าย) → ได้ error กลับมาจาก `pin_message()` → SnackBar **"ปักหมุดได้สูงสุด 3 ข้อความต่อบทสนทนา ยกเลิกอันเก่าก่อน"**
7. **Pinned bar**: เมื่อบทสนทนามีข้อความปักหมุด ≥ 1 อัน แสดงแถบบางๆ ใต้ AppBar เหนือ list ข้อความทันที (สูง ~40px, พื้นหลัง `WynColors.paper` เข้มกว่าเล็กน้อย/มี top hairline) — โครง: ไอคอนหมุด + preview ข้อความที่ปักหมุด**ล่าสุด** (1 บรรทัด, ellipsis) + ตัวนับ "1/3" ถ้ามีมากกว่า 1 อัน + chevron ขวา แตะที่แถบทั้งแถบ (ไม่ใช่แค่ตัวข้อความ) → เปิด bottom sheet **"ข้อความที่ปักหมุด"**
8. Bottom sheet รายการปักหมุด: แต่ละแถวโชว์ preview ข้อความ (หรือ "รูปภาพ" ถ้าเป็น image message ที่ถูกปักหมุดไว้ก่อนถูกลบไม่ได้เพราะลบแล้ว auto-unpin) + ชื่อผู้ส่ง + เวลาที่ปักหมุด + ปุ่ม "เลิกปักหมุด" ท้ายแถว แตะตัวแถว (ไม่ใช่ปุ่มเลิกปักหมุด) → ปิด sheet แล้ว `_scrollToMessage(messageId)` (reuse กลไก reply-jump เดิมทุกจุด)

## Wireframe (text description)

```
AppBar: [<] [avatar] ชื่อผู้ใช้                [เพิ่มเติม ⋮]
─────────────────────────────────────────
📌 "นัดเจอกันพรุ่งนี้ 5 โมงเย็นนะ"      1/3   ›   <- Pinned bar (ถ้ามี)
─────────────────────────────────────────
                                   [ข้อความของอีกฝ่าย]
[ข้อความของฉัน — แก้ไขแล้ว]
   แก้ไขแล้ว                                <- label ถาวร สีเทาเล็ก
                                   ...
─────────────────────────────────────────
[กำลังแก้ไขข้อความ            ✕]        <- แถบ edit mode (แทนแถบ reply)
[ TextField (prefilled) ...        ✓ ]
```

## Edge Cases

- แก้ไขข้อความรูป/ข้อความที่มี shared-content → ตัด option "แก้ไข" ออกจากเมนูตั้งแต่ client (`canEdit = isMine && message.text != null && message.imageUrl == null && message.sharedContentId == null && !message.isDeleted`) และ RPC เองก็ปฏิเสธซ้ำอีกชั้น (defense in depth เหมือนทุกจุดของ schema นี้)
- แก้ไขข้อความให้เป็นค่าว่าง (ลบข้อความทั้งหมดในกล่องแก้ไข) → ปุ่มยืนยันถูก disable (เหมือน `_canSend` เดิมที่ disable ปุ่มส่งตอนไม่มีเนื้อหา) — ถ้าต้องการ "ลบ" ให้ใช้ปุ่มลบเดิม ไม่ใช่แก้ไขให้ว่าง
- ข้อความที่ถูกลบไปแล้วระหว่างที่อีกฝ่ายกำลังเปิดเมนู "แก้ไข"/"ปักหมุด" ค้างอยู่ (race) → RPC ปฏิเสธด้วย error message ชัดเจน (`deleted_at is not null`/`not found`) → SnackBar ทั่วไป ไม่ crash
- ข้อความที่ถูกปักหมุดอยู่แล้วถูกลบ (โดยเจ้าของข้อความ) → `delete_message()` แก้ไขใหม่ auto-unpin ทันทีในทรานแซคชันเดียวกัน → Pinned bar/sheet อัปเดตแบบ realtime ผ่าน `conversation-pins-$conversationId` channel (ข้อ Realtime ด้านบน) โดยไม่ต้อง reload หน้าจอ
- ปักหมุด/เลิกปักหมุดพร้อมกันจากทั้ง 2 ฝั่ง (race แย่งช่องที่ 3) → `pin_message()` เช็ค count แบบ read-then-check ไม่ได้ wrap ด้วย `for update`/serializable — เป็นไปได้ในทางทฤษฎีที่ race กันแล้วเกิน 3 ชั่วขณะ (เช่น 4) ถ้ากดพร้อมกันเป๊ะๆ จาก 2 device — ยอมรับความเสี่ยงนี้ไว้ใน v1 (ผลกระทบต่ำมาก: จำกัดเกิน 1 แถวชั่วคราว ไม่ใช่ data corruption, ไม่ใช่ security issue) ตาม risk posture ต่ำของ feature นี้ทั้งฟีเจอร์ — ถ้า Founder ต้องการความแม่นยำระดับ concurrent-safe เป๊ะ แจ้งให้ Coding เพิ่ม `select ... for update` บนแถว `conversations` ก่อนนับได้ในภายหลัง

## Design Rules

ไม่มีการเปลี่ยนแปลงต่อ Design System (สี/spacing/token) — reuse component เดิมทั้งหมด (`ActionSheetRow`, bottom sheet ของ `_showConversationMenu`/`_showMessageMenu`, reply-preview-bar shape เดิม)

## Handoff

**ต้องการ visual mockup ก่อนส่ง AI Coding** ตามกติกา "ขอดูรูปก่อน เขียนโค้ดนะ" (2026-09-03) — งานนี้มี UI ใหม่จริง (edit-mode composer bar, pinned bar, pinned bottom sheet) session นี้มีเฉพาะเครื่องมืออ่าน/เขียนไฟล์ ไม่มีเครื่องมือสร้างภาพ/Artifact เชิงภาพ จึงทำได้แค่ wireframe เป็นข้อความ/ASCII ตามด้านบน — **แนะนำให้ Founder ยืนยันว่า wireframe ข้อความนี้เพียงพอสำหรับอนุมัติ หรือรอ session ที่มีเครื่องมือสร้างภาพ mockup จริงก่อน** ก่อนส่งต่อ AI Coding

**Staged Rollout (WYN-125)**: มี UI ใหม่จริง (ปุ่ม "แก้ไข"/"ปักหมุด" ในเมนู, pinned bar) — ต้อง gate ด้วย `DeveloperAccessService.isDeveloperAccount()` เป็นค่าเริ่มต้นตามมาตรฐาน (`isDeveloperAccount() == false` ต้องไม่เห็นแถวเมนูใหม่ 2 แถวนี้เลย และไม่เห็น pinned bar เลย แม้จะมีข้อมูล pinned จริงในฐานข้อมูลก็ตาม — เหมือนฟีเจอร์ยังไม่มีอยู่) จนกว่า Founder จะสั่งเปิดให้ทุกคน
