# AI Design — WYN-139: DM Presence — Typing Indicator + Online/Last Seen + Privacy Toggle

Owner: AI Design
ต่อยอดจาก Product Task `.wyn/tasks/active/WYN-139-dm-presence-typing-online.md`

WYN design system ที่อนุมัติแล้ว: reuse token เดิม + pattern Presence ที่พิสูจน์แล้วจาก WYN-128 (`club_channel_chat_repository.dart`'s `subscribeToChannel`'s online-count) — ไม่มีทิศทาง visual ใหม่ มีจอ Settings ใหม่ 1 แถวเท่านั้น (toggle ใน `_PrivacyScreen` ที่มีอยู่แล้ว)

## โครงสร้างที่ตรวจสอบจากโค้ดจริงแล้ว

- **Presence ที่พิสูจน์แล้วในโปรเจกต์นี้จริง** (`club_channel_chat_repository.dart`): `_client.channel(key, opts: RealtimeChannelConfig(key: myUserId))`, `channel.onPresenceSync(...)`, `channel.track({...})`, `channel.presenceState()` — ทั้งหมดเป็น pattern เดียวที่ระบบนี้เคยใช้งานจริง (ไม่มี Broadcast event ใดถูกใช้มาก่อนในโปรเจกต์นี้เลย) → **งานนี้เลือกใช้ Presence สำหรับทั้ง Typing และ Online ตามที่ Requirement ระบุไว้ตรงๆ อยู่แล้ว ("ใช้ Supabase Realtime Presence channel") และตรงกับ pattern เดียวที่พิสูจน์แล้วจริง**
- `public.profiles`: `select` policy คือ **`using (true)` — ทุก authenticated user อ่านได้ทุกแถวทุกคอลัมน์** (ยืนยันจากโค้ดจริงบรรทัด 15-19 ของ `schema.sql`) — RLS ในระบบนี้เป็น row-level ไม่ใช่ column-level (ยืนยันซ้ำจาก comment ของ `notifications.actor_id` เอง) **ข้อนี้สำคัญมาก**: ถ้าเก็บ `last_seen_at`/`show_online_status` เป็นคอลัมน์ตรงบน `profiles` จะรั่วให้ authenticated user **ทุกคน** อ่าน `last_seen_at` ของทุกคนได้ทันทีโดยไม่ผ่าน reciprocal check เลย ขัดกับ Requirement โดยตรงและขัด RULES.md (ปกป้องข้อมูลผู้ใช้) — **ต้องแยกตารางใหม่** (mirror `notification_settings`'s ท่าเดิมเป๊ะ: ตารางแยกที่มี SELECT policy จำกัดแค่ "เจ้าของแถวเท่านั้น")
- `app/lib/core/text_utils.dart`: มี `relativeTimeLabel(dateTime, {required now})` อยู่แล้ว ("5 นาทีที่แล้ว" ฯลฯ) — reuse ตรงๆ ไม่ต้องเขียนใหม่
- `app/lib/features/settings/presentation/settings_screen.dart`'s `_PrivacyScreen`: มี pattern การเพิ่ม privacy control ต่อแถวอยู่แล้ว (dm/mention/comment permission) — จุดที่เพิ่ม toggle ใหม่
- `ConversationScreen` มี `WidgetsBindingObserver`/`didChangeAppLifecycleState` อยู่แล้ว (ใช้ resubscribe ตอน resume) — pattern เดียวกันนี้ใช้สำหรับ presence lifecycle ได้เลย แต่ **online/last-seen ต้องเป็นระดับ global ต่อแอป ไม่ใช่ต่อหน้าจอ** (ตาม Requirement ข้อ "Online = มี session แอปเปิดอยู่จริง...ระดับ global ต่อ user") จึงต้องมี observer ระดับ root แยกต่างหาก ไม่ผูกกับ `ConversationScreen` เพียงอย่างเดียว

## Schema / Data Model

### ตารางใหม่ `user_presence` (แยกจาก `profiles` โดยเจตนา — ดูเหตุผลด้านบน)

```sql
create table if not exists public.user_presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  show_online_status boolean not null default true,
  last_seen_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_presence enable row level security;

-- เหมือน notification_settings เป๊ะ: เห็น/แก้ได้แค่แถวตัวเอง -- ไม่มี
-- policy ให้เห็นแถวคนอื่นเลย (การอ่านค่าคนอื่นต้องผ่าน RPC ด้านล่างเท่านั้น
-- ซึ่งบังคับ reciprocal check ในตัว)
create policy "Users can view their own presence row"
  on public.user_presence
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own presence row"
  on public.user_presence
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own presence row"
  on public.user_presence
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

### RPC 1 — อัปเดต last_seen ของตัวเอง (เรียกตอนแอปพ้นสถานะ foreground)

```sql
create or replace function public.touch_my_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_presence (user_id, last_seen_at)
  values (auth.uid(), now())
  on conflict (user_id) do update
    set last_seen_at = excluded.last_seen_at, updated_at = now();
end;
$$;

grant execute on function public.touch_my_presence() to authenticated;
```

### RPC 2 — อ่านสถานะของ "อีกฝ่าย" ในบทสนทนาหนึ่ง พร้อม reciprocal check ในตัว (จุดเดียวที่ client อ่านค่าคนอื่นได้)

```sql
create or replace function public.get_conversation_partner_presence(p_conversation_id uuid)
returns table (show_online boolean, last_seen_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_other uuid;
  v_my_show boolean;
  v_other_show boolean;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  select case when user_a_id = v_me then user_b_id
              when user_b_id = v_me then user_a_id end
  into v_other
  from public.conversations
  where id = p_conversation_id and v_me in (user_a_id, user_b_id);

  if v_other is null then
    raise exception 'Conversation not found, or you are not a participant';
  end if;

  select coalesce(up.show_online_status, true) into v_my_show
  from public.user_presence up where up.user_id = v_me;
  select coalesce(up.show_online_status, true) into v_other_show
  from public.user_presence up where up.user_id = v_other;

  -- Reciprocal (Requirement, มาตรฐาน WhatsApp): ต้องเปิดทั้งสองฝั่ง
  -- ถึงจะเห็นได้ -- ปิดฝั่งใดฝั่งหนึ่งพอ ทั้งคู่มองไม่เห็นกันและกันทันที
  if coalesce(v_my_show, true) = false or coalesce(v_other_show, true) = false then
    return query select false, null::timestamptz;
    return;
  end if;

  return query
    select true, up.last_seen_at
    from public.user_presence up
    where up.user_id = v_other;
end;
$$;

grant execute on function public.get_conversation_partner_presence(uuid) to authenticated;
```

### เปลี่ยนค่า `show_online_status` ของตัวเอง

Client เขียนตรงผ่าน RLS ปกติได้เลย (ไม่ต้องมี RPC พิเศษ เพราะเป็นแถวของตัวเอง — ใช้ policy ข้อ "Users can update their own presence row" ด้านบน):
```
upsert into user_presence (user_id, show_online_status) values (me, newValue) on conflict (user_id) do update set show_online_status = excluded.show_online_status, updated_at = now()
```

## Presence Channel Design (Realtime, ไม่ใช่ Postgres query — คนละกลไกกับด้านบน)

**"Online" (สด/live) ไม่มีทางมาจาก query ฐานข้อมูลได้เลย** — เป็นสถานะที่มีชีวิตอยู่แค่ในตัว Supabase Realtime server ตอน socket ยัง connect อยู่เท่านั้น ต่างจาก `last_seen_at` (ค่าที่ persist ถาวรใน DB) โดยสิ้นเชิง งานนี้จึงมี 2 กลไกคู่กัน:

1. **Global presence channel** (online สด): เปิด**ครั้งเดียวระดับแอป** ไม่ใช่ต่อหน้าจอ — แนะนำ wire ที่ `RootShell` (จุดเดียวกับที่ `PushNotificationService` ถูก wire อยู่แล้วตอนนี้ ระดับ root เดียวกัน) ไม่ใช่ใน `ConversationScreen`:
   - `channel = client.channel('presence-online-global', opts: RealtimeChannelConfig(key: myUserId))`
   - `track({'online_at': DateTime.now().toIso8601String()})` เมื่อ `AppLifecycleState.resumed`
   - `untrack()` + เรียก RPC `touch_my_presence()` เมื่อ `AppLifecycleState.paused`/`detached` (best-effort เหมือนทุก lifecycle hook อื่นในแอปนี้ — แอปถูก kill กะทันหันจะพลาด call นี้ ยอมรับเป็น known limitation เดียวกับทุกแอปแชทที่ไม่มี server-side heartbeat timeout)
   - ทุก `ConversationScreen`/หน้าจออื่นที่ต้องรู้ว่า "user X online ไหม" เช็คจาก `channel.presenceState()` ของ channel เดียวกันนี้ (global, key = user_id ของแต่ละคน) — ไม่ต้องเปิด channel ใหม่ต่อบทสนทนา
2. **Per-conversation typing channel**: เปิด/ปิดตามอายุของ `ConversationScreen` เท่านั้น (mirror `subscribeToChannel`'s per-screen scope ของ Club) — channel key `conversation-typing-$conversationId`:
   - `TextField.onChanged`: ถ้ายังไม่ได้ track เป็น typing → `track({'typing': true})` ทันที + เริ่ม `Timer(3s)` ถ้า timer เดิมมีอยู่แล้วให้ reset (debounce ตาม Requirement "debounce เพื่อไม่ spam event ทุกตัวอักษร" — track ใหม่เฉพาะตอน state เปลี่ยนจาก false→true ไม่ track ซ้ำทุก keystroke)
   - Timer ครบ 3 วินาทีไม่มี keystroke ใหม่ → `track({'typing': false})`
   - ส่งข้อความสำเร็จ → `track({'typing': false})` + cancel timer ทันที (เคลียร์ทันทีไม่ต้องรอ 3 วิ)
   - `dispose()` → `unsubscribe(channel)` (channel หายไปเอง ฝั่งอีกคนเห็น presence ของเรา leave ออกจาก state)
   - ฝั่งรับ: `onPresenceSync` อ่าน `presenceState()` หาแถวของ `otherUserId` เช็ค `typing == true` → แสดง indicator + เริ่ม timer client-side ของตัวเอง 3 วิ (safety net เผื่อ event `false`/leave หลุดหายระหว่างทาง — auto-clear เองแม้ไม่ได้รับ event ปิดจริง)
   - **Typing ไม่มี reciprocal privacy gate** ตาม Requirement ("ไม่มี privacy toggle แยก") — track/แสดงเสมอไม่ขึ้นกับ `show_online_status`

## UI / UX Flow

### ConversationScreen AppBar

Subtitle ใต้ชื่อ (ปัจจุบันไม่มีเลย — เพิ่มบรรทัดเล็กใต้ชื่อ, font 12px สีเทา `WynColors.inkFaded`/เทียบเท่า) ตามลำดับความสำคัญ (โชว์อันแรกที่เข้าเงื่อนไข):
1. อีกฝ่ายกำลังพิมพ์ → **"กำลังพิมพ์..."** (ไม่ขึ้นกับ privacy toggle)
2. ไม่ได้พิมพ์ + reciprocal check ผ่าน + online จริง (มีใน presence state) → จุดเขียวเล็ก (8px, `WynColors` เขียวมาตรฐานถ้ามี ไม่มีก็ใช้ material green 500 ชั่วคราวรอ token) + **"ออนไลน์"**
3. ไม่ได้พิมพ์ + reciprocal check ผ่าน + ไม่ online + มี `last_seen_at` → **"ใช้งานล่าสุด ${relativeTimeLabel(...)}"**
4. reciprocal check ไม่ผ่าน (ฝั่งใดฝั่งหนึ่งปิด) หรือยังไม่เคยมีข้อมูล `last_seen_at` เลย → **ไม่แสดงบรรทัดนี้เลย** (ไม่ใช่ error, แค่ไม่มีอะไรให้โชว์)

### Settings → ความเป็นส่วนตัว (`_PrivacyScreen`)

เพิ่มแถวใหม่ (Switch, ตำแหน่งใต้ 3 dropdown เดิม dm/mention/comment permission): **"แสดงสถานะออนไลน์และเข้าใช้งานล่าสุด"** พร้อม helper text ใต้แถว (เทา, 12px, บรรทัดเดียว — mirror wording ของ helper text อื่นในหน้าเดียวกัน): *"ถ้าปิด คุณจะไม่เห็นสถานะออนไลน์และเข้าใช้งานล่าสุดของคนอื่นด้วยเช่นกัน"* — สื่อ reciprocal ให้ผู้ใช้เข้าใจก่อนกดปิด ไม่ใช่แค่ปิดเงียบๆ

## Wireframe (text)

```
AppBar:
  [<]  [avatar]  ชื่อผู้ใช้
              🟢 ออนไลน์               <- หรือ "กำลังพิมพ์..." หรือ "ใช้งานล่าสุด 5 นาทีที่แล้ว" หรือว่างเปล่า
─────────────────────────────────────

Settings > ความเป็นส่วนตัว:
  ใครส่งข้อความหาคุณได้    [ทุกคน ▾]
  ใครกล่าวถึงคุณได้         [ทุกคน ▾]
  ใครคอมเมนต์โพสต์คุณได้    [ทุกคน ▾]
  ─────────────────────────────
  แสดงสถานะออนไลน์และเข้าใช้งานล่าสุด        [●○ เปิด]
  ถ้าปิด คุณจะไม่เห็นสถานะออนไลน์และเข้าใช้งาน
  ล่าสุดของคนอื่นด้วยเช่นกัน
```

## Edge Cases

- ผู้ใช้ใหม่ที่ไม่เคยมีแถว `user_presence` เลย (ยังไม่เคยเปิดแอปหลัง deploy งานนี้) → `get_conversation_partner_presence` อ่านได้ `null` แล้ว `coalesce(..., true)` ให้ default = เปิดอยู่ (`show_online_status` default `true` ตาม schema) แต่ `last_seen_at` เป็น `null` จริง → ฝั่ง client แสดงผลตามเงื่อนไขข้อ 4 ด้านบน (ไม่มีอะไรให้โชว์) จนกว่าจะมี event แรกจริง ไม่ error
- สองอุปกรณ์คนเดียวกัน (เช่น เปิดแอปทั้งมือถือ+เว็บพร้อมกัน) → `channel(key: myUserId)` เดียวกันจะมี 2 presence entries คนละ device แต่ key เดียวกัน (Supabase presence รองรับหลาย metadata ต่อ key ได้อยู่แล้วตามปกติ) → ฝั่งอ่านแค่เช็คว่า "มี entry อย่างน้อย 1 ตัวสำหรับ user นี้ไหม" ก็พอ ไม่ต้องสนใจจำนวน device — ถือว่า online ถ้ามีอย่างน้อย 1 session ใดก็ตามยัง connect อยู่ (ถูกต้องตาม intent ของ requirement)
- ปิด privacy toggle **ระหว่าง**ที่กำลังคุยอยู่ในหน้า ConversationScreen พอดี → ต้อง re-fetch `get_conversation_partner_presence` ทันที (ไม่ต้องรอ reload หน้าจอ) — เพราะ RPC นี้ query ค่าจาก DB ตรงๆ ไม่ cache ยาว จึง reactive ได้ง่ายด้วยการ re-call เมื่อ Settings เปลี่ยนค่าสำเร็จ (โดยเฉพาะฝั่งของตัวเอง — ฝั่งอีกคนจะเห็นผลก็ต่อเมื่อ re-fetch ครั้งถัดไป เช่น เปิดหน้าใหม่/pull-to-refresh ไม่ได้ real-time แบบ postgres_changes เพราะ `user_presence` ไม่ได้อยู่ใน `supabase_realtime` publication ในงานนี้ — acceptable, ไม่ critical เท่า typing/online สด)
- Presence channel disconnect กะทันหัน (ปิดแอป/เน็ตหลุด ไม่ใช่ graceful pause) → `last_seen_at` **ไม่อัปเดต** เพราะ `touch_my_presence()` ไม่มีโอกาสถูกเรียก (ไม่มี server-side heartbeat/timeout ใน v1) → ค่า "ใช้งานล่าสุด" อาจค้างเก่ากว่าความเป็นจริงในกรณีนี้ — ยอมรับเป็น known limitation ของ v1 (ตรงกับที่แอปแชททั่วไปก็มีปัญหาเดียวกันในระดับหนึ่งถ้าไม่มี heartbeat timeout ฝั่ง server)
- Reciprocal toggle ที่ปิดอยู่แล้วเปิดกลับ → เห็นข้อมูลของอีกฝ่ายทันทีที่เงื่อนไขทั้งสองฝั่งเป็น true (ไม่มี "รอ" ใดๆ เพิ่มเติม)

## Design Rules

ไม่มีการเปลี่ยนแปลงต่อ Design System — ใช้สี/spacing เดิม, ยืมสีเขียว "online dot" มาตรฐานถ้ายังไม่มีใน `WynColors` ให้ AI Coding เลือกจาก Material green 500 (`#4CAF50`) เป็นค่า placeholder ชั่วคราวจนกว่าจะมี token อย่างเป็นทางการ — ไม่ใช่การคิดทิศทางสีใหม่ เป็นแค่ accent จุดเล็กจุดเดียว

## Handoff

**ต้องการ visual mockup ก่อนส่ง AI Coding** ตามกติกา "ขอดูรูปก่อน เขียนโค้ดนะ" (2026-09-03) — มี UI ใหม่จริง (AppBar subtitle 3 สถานะ, Settings toggle ใหม่) session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความข้างต้น — **แนะนำให้ Founder ยืนยันว่าเพียงพอ หรือรอ session ที่มีเครื่องมือสร้างภาพก่อนอนุมัติ**

**Staged Rollout (WYN-125)**: ต้อง gate ทั้งสองส่วนด้วย `isDeveloperAccount()`:
- `isDeveloperAccount() == false`: ไม่เห็น AppBar subtitle ใหม่เลย (เหมือนเดิมทุกประการ ไม่มีบรรทัดว่างเปล่าค้างอยู่ใต้ชื่อด้วยซ้ำ), ไม่เห็นแถว Settings toggle ใหม่เลย, และ **ไม่ track/subscribe presence channel ใดๆ เลยทั้ง global และ per-conversation** (ประหยัด resource สำหรับผู้ใช้ทั่วไปที่ยังไม่เห็นฟีเจอร์นี้ ไม่ใช่แค่ซ่อน UI)
- `isDeveloperAccount() == true`: เห็นและใช้งานได้ครบตามสเปกนี้
- รอ Founder สั่งเปิดให้ทุกคนแยกต่างหาก
