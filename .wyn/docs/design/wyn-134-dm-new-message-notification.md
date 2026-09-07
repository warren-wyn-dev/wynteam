# AI Design — WYN-134: DM "New Message" Notification

Owner: AI Design
ต่อยอดจาก Product Task `.wyn/tasks/active/WYN-134-dm-new-message-notification.md`

WYN design system ที่อนุมัติแล้ว: ไม่มีหน้าจอใหม่ในงานนี้ (แค่ notification type ใหม่ + wording ใหม่) — ใช้ token/pattern เดิมของ `NotificationListScreen`/`_MessageBubble` 100% ไม่มีทิศทาง visual ใหม่

## โครงสร้างที่ตรวจสอบจากโค้ดจริงแล้ว (ต้องอิงตามนี้)

- `public.conversations` (WYN-031): `status` ('active'/'pending'), `user_a_id`/`user_b_id`, `requested_by`
- `public.messages` (WYN-031): AFTER INSERT คือจุดเดียวที่ข้อความใหม่เกิดขึ้น (ไม่มี RPC ส่งข้อความ ใช้ RLS INSERT ตรงๆ)
- `public.notifications` (WYN-012, ขยายโดย WYN-015/029/032/043): มีคอลัมน์ `conversation_id` อยู่แล้ว (เพิ่มโดย WYN-032 สำหรับ `message_request`) — reuse ได้ทันที ไม่ต้องเพิ่มคอลัมน์ใหม่
- `public.conversation_mutes` (WYN-031): per-conversation mute, plain RLS, `(conversation_id, user_id)` primary key
- `internal.notification_enabled(user_id, category)`: มี category `'messages'` อยู่แล้ว (ใช้ร่วมกับ `message_request` ใน `get_or_create_conversation()`)
- `public.mark_conversation_read(p_conversation_id)`: RPC ที่ `ConversationScreen` เรียกอยู่แล้ว 3 จุด — `initState`, realtime-message-received (`_onRealtimeMessage`), resume-from-background (`_resubscribeAndRefresh`)
- Push delivery infra (WYN-016): `notifications` INSERT → Supabase Database Webhook → `send-push-notification` Edge Function (`supabase/functions/send-push-notification/_lib.ts`) → FCM. Foreground push ไม่ auto-แสดง banner อยู่แล้ว (ดู `push_notification_service.dart` doc comment) — แค่ trigger `onForegroundMessage` เพื่อ refresh badge

## Schema / Data Model

1. เพิ่ม `'new_message'` เข้า `notifications_type_check` constraint (mirror `message_request` เป๊ะ):
   ```sql
   alter table public.notifications
     add constraint notifications_type_check
     check (type in (
       ..., 'message_request', 'new_message', ...
     ));
   ```
2. Trigger function ใหม่ `notify_new_message()`, `AFTER INSERT ON public.messages`, `security definer`:
   ```sql
   create or replace function public.notify_new_message()
   returns trigger
   language plpgsql
   security definer
   set search_path = public
   as $$
   declare
     v_conversation public.conversations;
     v_recipient uuid;
   begin
     select * into v_conversation from public.conversations where id = new.conversation_id;
     -- pending บทสนทนามี message_request ของ WYN-032 แจ้งเตือนอยู่แล้ว -- ไม่ยิงซ้ำ
     if v_conversation is null or v_conversation.status <> 'active' then
       return new;
     end if;

     v_recipient := case when v_conversation.user_a_id = new.sender_id
                          then v_conversation.user_b_id
                          else v_conversation.user_a_id end;

     if exists (
       select 1 from public.conversation_mutes
       where conversation_id = new.conversation_id and user_id = v_recipient
     ) then
       return new;
     end if;

     if internal.notification_enabled(v_recipient, 'messages') then
       insert into public.notifications (recipient_id, actor_id, type, conversation_id)
       values (v_recipient, new.sender_id, 'new_message', new.conversation_id);
     end if;

     return new;
   end;
   $$;

   create trigger messages_notify_new_message
     after insert on public.messages
     for each row execute function public.notify_new_message();
   ```
   ไม่ต้องเช็ค block/posting-restriction ซ้ำในนี้ — `messages` INSERT policy บล็อก sender ที่ blocked-either-way/posting-blocked ไว้แล้วที่ RLS ก่อนจะถึง trigger เลย (แถวจะไม่ถูก insert ตั้งแต่แรกถ้าไม่ผ่าน RLS)
3. แก้ `mark_conversation_read()` ให้เคลียร์ `new_message` notification ของบทสนทนานั้นด้วย ในทรานแซคชันเดียวกัน (ดูเหตุผลเต็มในหัวข้อ "การตัดสินใจสำคัญ" ด้านล่าง):
   ```sql
   create or replace function public.mark_conversation_read(p_conversation_id uuid)
   ...
   begin
     ...
     update public.conversations set ... where id = p_conversation_id and v_me in (user_a_id, user_b_id);
     if not found then raise exception 'Conversation not found, or you are not a participant'; end if;

     update public.notifications
     set is_read = true
     where recipient_id = v_me
       and conversation_id = p_conversation_id
       and type = 'new_message'
       and is_read = false;
   end;
   $$;
   ```

## การตัดสินใจสำคัญ: วิธีทำ AC "เปิดหน้าบทสนทนาอยู่พอดี → ไม่เกิด notification ซ้ำ" โดยไม่สร้าง presence system ใหม่

Trigger ทำงานแบบ synchronous ทันทีที่ sender INSERT ข้อความ — ณ จุดนั้น server **ไม่มีทางรู้ได้เลย**ว่า recipient เปิดหน้าจอ ConversationScreen ค้างอยู่หรือไม่ (ไม่มี presence signal ใดๆ ในงานนี้ตาม requirement) ดังนั้น trigger จะ insert แถว `new_message` เสมอเมื่อเงื่อนไข active/ไม่ mute/เปิด notification ผ่านหมด — **แถวถูกสร้างจริงเสมอ 1:1 กับข้อความ ตรงตาม "v1 เก็บง่าย: 1 ข้อความใหม่ = 1 notification row"**

สิ่งที่ทำให้ผู้ใช้ไม่รู้สึกว่า "ซ้ำ" คือฝั่งอ่าน ไม่ใช่ฝั่งเขียน: `ConversationScreen._onRealtimeMessage()` (โค้ดเดิมของ WYN-031) เรียก `markConversationRead()` ทันทีทุกครั้งที่ได้รับข้อความใหม่จากอีกฝ่ายผ่าน realtime ขณะหน้าจอนั้นเปิดอยู่ — **นี่คือ "client state ที่มีอยู่แล้ว" ที่ Requirement ชี้ไว้** งานนี้แค่ต่อพฤติกรรมของ RPC เดิมตัวนี้ (ข้อ 3 ด้านบน) ให้เคลียร์ `is_read` ของ `new_message` แถวที่เพิ่งเกิดไปด้วยในตัว ไม่ต้องเพิ่ม client call site ใหม่เลยสักจุด (repository/UI ของ ConversationScreen ไม่ต้องแก้อะไรสำหรับกลไกนี้)

ผล: แถวยังถูกสร้างเสมอ (มี id จริง, นับใน "ประวัติ" ได้ถ้าต้องการ) แต่จะถูก mark-read แทบจะทันที (ในรอบ round-trip เดียวกับที่ realtime message มาถึง + `markConversationRead()` เดิมที่มีอยู่แล้ว) ก่อนที่ badge/list จะมีโอกาสแสดงเป็น unread ให้เห็น — ผลลัพธ์ที่ผู้ใช้สัมผัสได้ตรงตาม AC แม้ว่าในทางเทคนิคจะมี row ที่ "unread แว้บเดียว" อยู่จริงเสี้ยววินาที (ยอมรับได้ ไม่มีผลต่อ UX)

**ข้อยกเว้นที่ยอมรับไว้**: push (Database Webhook) ยิงจากการ INSERT ทันที ก่อนที่ client จะมีโอกาสเรียก `markConversationRead()` เสมอ — เป็นไปได้ที่ push จะ "มาถึง" อุปกรณ์ในเสี้ยววินาทีที่หน้าจอเปิดอยู่พอดี แต่เพราะแอปนี้ไม่แสดง OS banner ตอน foreground อยู่แล้ว (พฤติกรรมเดิมของ WYN-016, ดู `push_notification_service.dart`) จึงไม่มีผลกระทบที่ผู้ใช้เห็นจริง — ตรงนี้ไม่ใช่บั๊กใหม่ เป็นพฤติกรรมเดิมของระบบ push ทั้งระบบ

## Dart / Client (สเปกให้ AI Coding — ไม่ใช่ AI Design เขียนเอง)

1. `app/lib/features/notification/data/notification.dart`: เพิ่ม `NotificationType.newMessage` + case `'new_message'` ใน `_typeFromString` (mirror `messageRequest` เป๊ะ — ใช้ `conversationId`/`actorId` เดิม ไม่ต้องเพิ่ม field ใหม่)
2. `app/lib/features/notification/presentation/notification_list_screen.dart`:
   - `_messageFor`: `case NotificationType.newMessage: return '$name ส่งข้อความถึงคุณ';`
     - **ตั้งใจไม่โชว์เนื้อหาข้อความจริง** (ต่างจาก `likeDrop`/`commentDrop` ที่โชว์ `contentPreview` ของโพสต์สาธารณะได้) — เนื้อหา DM เป็นข้อมูลส่วนตัว ไม่ควร denormalize ไปโชว์ในลิสต์แจ้งเตือน/push tray โดยไม่จำเป็น เป็นการตัดสินใจเชิง privacy ที่ตั้งใจ ไม่ใช่ scope ที่ลืมทำ
   - `_openNotification`/switch case ใหม่: เหมือน `case NotificationType.messageRequest:` เป๊ะ — เปิด `ConversationScreen` ด้วย `conversationId`/`actorId` เดิม (copy-paste เคสเดียวกัน)
3. `app/lib/features/push/presentation/push_notification_service.dart`: เพิ่ม `case 'new_message':` เข้ากลุ่มเดียวกับ `case 'message_request':` (เรียก `_openConversation` เดิม)
4. `supabase/functions/send-push-notification/_lib.ts`: เพิ่ม `case "new_message": return \`${actorName} ส่งข้อความถึงคุณ\`;` ใน `messageFor()` (mirror คำเดียวกับข้อ 2 เป๊ะ ตาม comment เดิมของไฟล์นี้ที่บังคับให้ 2 ภาษาตรงกันคำต่อคำ)

## Wireframe (ไม่มีหน้าจอใหม่ — อธิบายจุดที่เปลี่ยน)

`NotificationListScreen` แถวเดิม (avatar + ข้อความ + เวลา + unread dot) โชว์แถวใหม่แบบเดียวกับ `follow`/`messageRequest` ทุกประการ:

```
[avatar]  <ชื่อ> ส่งข้อความถึงคุณ            5 นาทีที่แล้ว   •(unread dot)
```

แตะแถว → เปิด `ConversationScreen` ตรง — เหมือน `messageRequest` เป๊ะ ไม่มี intermediate screen

## Edge Cases

- ข้อความที่ 2, 3, ... ในบทสนทนาเดียวกันติดๆ กันขณะที่ recipient ไม่เปิดแอปเลย → ได้ notification row แยกทุกข้อความจริง (ตาม spec "v1 ไม่ batch") —ยอมรับว่าอาจดู "รก" ถ้าคุยถี่มาก ตามที่ Requirement ระบุไว้แล้วว่าเป็น trade-off ที่ตั้งใจของ v1
- ข้อความที่เป็น View Once/ไม่มี text (แค่รูป) → ยังคง trigger `new_message` ตามปกติ (ไม่พิเศษเป็นกรณีแยก) เพราะข้อความ preview ไม่ถูกโชว์อยู่แล้วตามข้อ 2 ด้านบน (privacy) จึงไม่มีความเสี่ยงหลุด preview ของรูป View Once ไปโผล่ใน notification
- บทสนทนาที่ mute ไว้ตั้งแต่ก่อนงานนี้ → ไม่มี `new_message` เกิดเลย (เช็คผ่าน `conversation_mutes` เดิม) — ตรง AC
- บทสนทนา `pending` → ไม่มี `new_message` เกิดเลย (trigger คืนค่าเงียบๆ ทันทีที่เจอ `status <> 'active'`) — `message_request` เดิมทำหน้าที่นี้อยู่แล้วครั้งเดียวตอนสร้างบทสนทนา ไม่ยิงซ้ำทุกข้อความที่ requester พิมพ์ระหว่างรอ accept (ถูกต้องแล้ว ไม่ใช่บั๊ก)
- Backward-compat: แถว `new_message` เก่าที่มีอยู่ก่อน migration นี้ไม่มีทางเกิดขึ้น (type ใหม่ทั้งหมด ไม่มี data เก่าต้อง migrate)
- ผู้ใช้เก่าที่ไม่เคยตั้งค่า `notification_settings` แถวของตัวเอง → `internal.notification_enabled` fail-open เป็น `true` ตามพฤติกรรมเดิม (ไม่ต้องแก้อะไรเพิ่ม)

## Design Rules

ไม่มีการเปลี่ยนแปลงต่อ Design System (สี/spacing/token) — ใช้ของเดิม 100%

## Handoff

AI Coding — งานนี้แทบไม่มี UI ใหม่เลย (แค่ 1 แถวข้อความใหม่ในลิสต์ที่มีอยู่แล้ว, ไม่มีหน้าจอใหม่) จึงไม่จำเป็นต้องมี visual mockup/Artifact ตามกติกา "ขอดูรูปก่อน เขียนโค้ดนะ" (2026-09-03) — เป็น decision ที่ AI Design ตัดสินใจเองได้เพราะไม่มี "รูป" ใหม่ให้ดูจริง (ข้อความล้วนในโครง `_messageFor` เดิม) หากต้องการยืนยันเพิ่มเติม แนะนำ Founder ดู entry ใหม่ในลิสต์แจ้งเตือนจริงหลัง deploy (staged rollout ผ่าน developer account ตาม WYN-125 ก่อนเปิดทุกคน — ดูหัวข้อถัดไป)

**Staged Rollout (WYN-125)**: งานนี้เป็น backend trigger + wording เท่านั้น ไม่มี UI ที่ gate ด้วย `isDeveloperAccount()` ได้อย่างมีความหมาย (ทุกคนเห็น notification list เดิมอยู่แล้ว) — เข้าเกณฑ์ "bug fix ของฟีเจอร์ที่มีอยู่แล้ว/ไม่ต้อง gate" ในทางปฏิบัติเพราะมันคือการเติม gap ของ non-negotiable existing UX (Chat) ไม่ใช่ฟีเจอร์ใหม่ที่ผู้ใช้ต้อง "ค้นพบ" — **แนะนำไม่ gate** แต่ AI Coding ควรยืนยันกับ Founder อีกครั้งก่อน merge ถ้าไม่แน่ใจ ตามกติกา WORKFLOW.md
