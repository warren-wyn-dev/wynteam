# Design — WYN-039 (Private Account + Follow Request)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-039-private-account-follow-request.md` — อ่านก่อนเริ่ม
> Design system: **Cyan `#00C8FF` เป็น primary ตาม DS-001–008** — Rainbow (DS-009) ไม่ใช้ใน flow นี้เลย เหมือน WYN-031/032 (นี่คือ utility flow ไม่ใช่จุดที่ต้องการ accent สี)

## ภาพรวม — 7 การตัดสินใจเชิง scope

1. **`follows` table เดิม (WYN-008) ไม่แตะโครงสร้างเลย — ยังคงหมายถึง "accepted follow" เท่านั้นเหมือนเดิม 100%** สร้างตารางใหม่แยก `follow_requests` สำหรับ state "pending" แทนการเพิ่ม `status` column เข้า `follows` — ต่างจาก WYN-032 ที่ต่อยอด `conversations.status` เพราะ `conversations` ตอนนั้นยังใหม่/เพิ่งมีจาก WYN-031 เดียว แต่ `follows` ที่นี่มี call site ใช้งานอยู่แล้วจำนวนมาก (`FollowRepository`, `home_feed`/`saved_feed`, `get_or_create_conversation()`, badge count ต่างๆ) การเพิ่ม column ใหม่แล้วต้องไล่แก้ทุกจุดให้กรอง `status='accepted'` เสี่ยง regression สูงกว่าการแยกตารางใหม่ที่ไม่กระทบของเดิมเลยแม้แต่บรรทัดเดียว (ตาม RULES.md "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น")
2. **จุดศูนย์กลางของการ gate เนื้อหาคือ RLS ของตาราง `drops` เพียงจุดเดียว** (ต่อยอด pattern เดิมของ WYN-027 ตรงๆ — `drop policy ...; create policy "..., excluding X"`) ไม่ใช่การเพิ่มเงื่อนไขแยกใน `home_feed`/`saved_feed`/search/hashtag ทีละจุด เพราะทุก view/query เหล่านั้น query ผ่าน `public.drops`/`public.redrops` ด้วย `security_invoker = true` อยู่แล้ว (ยืนยันจากอ่าน schema จริง) ดังนั้น RLS ของ `drops` จะ cascade ไปเองทุกทาง **รวมถึงปิดช่องโหว่ ReDrop ที่ Product's Risk เตือนไว้โดยอัตโนมัติ** — ต่างจาก Mute (WYN-028) ที่ตั้งใจ gate แค่ระดับ `home_feed` เท่านั้น (เพราะ mute ไม่ใช่การบล็อกเต็มรูปแบบ ยังเปิดโปรไฟล์ดูตรงๆ ได้) แต่ Private ต้องเป็นการบล็อกเต็มรูปแบบเหมือน Block ไม่ใช่แบบ Mute
3. **Follower/Following "จำนวน" (count) กับ "รายชื่อ" (list) แยกกลไกกัน** — จำนวนต้องเห็นได้เสมอไม่ว่าใครดู (ตาม Product AC "เห็นสถิติตัวเลข") ผ่าน RPC ใหม่ `follower_count()`/`following_count()` (`security definer`, bypass RLS, คืนแค่ตัวเลข — **มิเรอร์ `drop_view_count()` ของ WYN-038 ตรงๆ**) ส่วนรายชื่อจริง (`fetchFollowers`/`fetchFollowing`) ผ่าน RLS ปกติของ `follows` ที่จะถูกจำกัดสำหรับบัญชี Private (ดู Data Notes)
4. **หน้าโปรไฟล์ที่ล็อก มิเรอร์ `_buildBlockedBanner`/`isBlockedEitherWay` ของ WYN-027 ตรงๆ** — เพิ่มเงื่อนไขที่ 3 ควบคู่กัน (`isBlockedEitherWay` / `isLockedPrivate` / ปกติ) ไม่ใช่ทำ UI แยกระบบใหม่
5. **Follow Requests list เป็นหน้าจอใหม่จริงจอเดียว มิเรอร์ `MessageRequestListScreen` ของ WYN-032 เกือบทั้งหมด** ต่างแค่ query source และ action (Accept/Reject แทน Accept/Delete/Block/Report — ไม่มี Block/Report ในหน้านี้เพราะยังไม่ได้เป็น follower กันจริง ยังไม่มีช่องทางส่งข้อความ/เนื้อหาถึงกันให้ต้อง report)
6. **Reject ไม่แจ้งเตือนผู้ขอ, Accept แจ้งเตือน** — มิเรอร์ Message Request's Delete/Accept ตรงๆ ตามที่ Product ระบุไว้แล้ว
7. **Settings เพิ่มแค่ 1 บรรทัดใหม่ (toggle เดียว) ใน section "ความเป็นส่วนตัว" ใหม่** — ต่อจาก pattern เดิมของ `SettingsScreen` (เพิ่มทีละ section ตามงานจริง ไม่ pre-build) DM Permissions/Mention/Comment ตาม Master Spec section 35 ไม่ทำรอบนี้ (WYN-045)

---

## Screen 1 — Settings: section "ความเป็นส่วนตัว" (ใหม่ ใน `SettingsScreen` เดิม)

**Purpose**: จุดเดียวที่เปลี่ยนบัญชีเป็น Public/Private

**ตำแหน่ง**: section ใหม่ต่อจาก "ความปลอดภัย" (Safety) เดิมที่ WYN-027/028/029 เพิ่มไว้แล้ว — ชื่อหัวข้อ "ความเป็นส่วนตัว"

**Components**: `SwitchListTile` เดียว — title "บัญชีส่วนตัว (Private Account)", subtitle "เฉพาะผู้ติดตามที่คุณอนุมัติเท่านั้นที่จะเห็น Drop ของคุณได้" — โหลด/แสดงค่า `profile.isPrivate` ปัจจุบัน (จาก `ProfileRepository`, ใช้ future ที่ `ViewProfileScreen` โหลดไว้แล้วส่งต่อมา เหมือนที่ `platformRole` ถูกส่งเข้ามาแล้วในปัจจุบัน — ไม่ query ซ้ำ)

**Interactions**: สลับ toggle → optimistic update UI ทันที → เรียก `ProfileRepository.updateIsPrivate(bool)` → error → revert toggle + `SnackBar` "เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง" — สลับ Private → Public **ไม่ต้อง confirm dialog** (แม้จะ auto-approve pending requests ทั้งหมด ก็เป็นสิ่งที่ผู้ใช้ตั้งใจทำอยู่แล้วตอนกดเปิด Public ไม่ใช่ผลข้างเคียงที่ไม่คาดคิด) — สลับ Public → Private ก็ไม่ต้อง confirm เช่นกัน (mirrors ความเรียบง่ายของ toggle อื่นทุกจุดในแอปนี้ที่ไม่มี confirm)

**States**: Loading (toggle disabled ระหว่างเรียก DB), Error (revert + snackbar) — ไม่มี empty state (มีค่าเสมอ default false)

**Accessibility**: `Semantics(label: 'บัญชีส่วนตัว เปิดอยู่/ปิดอยู่ กดเพื่อสลับ')` ตาม pattern toggle อื่นในโปรเจกต์

---

## Screen 2 — `ViewProfileScreen`: สถานะที่ 3 "Locked Private" (เพิ่มควบคู่ `isBlockedEitherWay` เดิม)

**เงื่อนไขเข้าสู่สถานะนี้**: `!isOwnProfile && profile.isPrivate && !isFollowingAccepted && !isBlockedEitherWay` (Block มาก่อนเสมอ — ถ้าถูกบล็อกอยู่แล้วให้แสดง Blocked banner เดิมของ WYN-027 ต่อไป ไม่ทับซ้อนกับ Locked)

**Components**:
- Header (avatar/display name/@username/bio) แสดงตามปกติทุกอย่างเหมือนเดิม **ไม่ซ่อน** — เฉพาะ Drop grid/tabs เท่านั้นที่ถูกล็อก
- แถวจำนวน Followers/Following (`_FollowCountTarget`) **ยังแสดงตัวเลขจริงตามปกติ** (ผ่าน RPC ใหม่ที่ bypass RLS ดู Data Notes ข้อ 3) — แต่แตะแล้ว**เปิดไม่ได้** ถ้าผู้ดูไม่ใช่ follower/เจ้าของ (แตะแล้วไม่มีอะไรเกิดขึ้น หรือแสดง `SnackBar` สั้น "ต้องติดตามก่อนถึงจะดูรายชื่อได้" — เลือก SnackBar เพื่อไม่ให้ผู้ใช้คิดว่าปุ่มพัง)
- ปุ่ม Follow (แทนที่ตำแหน่งเดิมของ `OutlinedButton` ที่มีอยู่แล้ว WYN-008) เปลี่ยน label/พฤติกรรมตามสถานะ 3 แบบ:
  - ยังไม่เคยขอ: "ติดตาม" → กด → เรียก `FollowRequestRepository.sendRequest()` → เปลี่ยนเป็น "ขอติดตามแล้ว" ทันที (optimistic)
  - ขอแล้ว รอ Accept: "ขอติดตามแล้ว" (`OutlinedButton` สีเทาเข้มกว่าปกติเล็กน้อยแสดงสถานะ passive) → กดซ้ำ → confirm dialog สั้น "ยกเลิกคำขอติดตาม {username}?" → ยืนยัน → เรียก `cancelRequest()` → กลับเป็น "ติดตาม"
  - ถูก Accept แล้ว: "กำลังติดตาม" ทำงานเหมือน WYN-008 เดิมทุกประการ (unfollow ได้ปกติ ไม่มี confirm — ต่างจาก cancel-request ตรงๆ เพราะ unfollow เป็น action ที่มีอยู่แล้วเดิม ไม่ต้องเปลี่ยน UX เดิม)
- แถบ/ข้อความล็อก แทนที่พื้นที่ Drop grid ทั้งหมด (มิเรอร์ `_buildBlockedBanner` ตำแหน่ง/ขนาดเป๊ะ): ไอคอน `Icons.lock_outline`, ข้อความ "บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู Drop ของ {username}"
- **ยังคง TabBar เดิมไว้ (Drop/ReDrops/Pop) แต่ทุก tab แสดง lock banner เดียวกันแทนเนื้อหา** (ไม่ใช่ซ่อน TabBar ไปเลย — สอดคล้องกับที่ Blocked persona เดิมทำ คือแทนที่เนื้อหาแต่ละ tab ด้วยข้อความอธิบาย ไม่ใช่ลบ tab ทิ้ง)

**ReDrops tab กรณีพิเศษ**: ถ้าเนื้อหาต้นฉบับที่ถูก ReDrop เป็นของบัญชี Private อื่น (ไม่ใช่เจ้าของโปรไฟล์ที่กำลังดูอยู่) และผู้ดูไม่ได้ follow ต้นฉบับนั้น — แถวนั้นจะหายไปจาก `ProfileRedropsTab` เองโดยอัตโนมัติจาก RLS (ข้อ 2 ด้านบน) ไม่ต้องเขียน logic UI แยกจัดการเคสนี้เพิ่ม

**Accessibility**: banner ใช้ `Semantics(label: 'บัญชีนี้เป็นส่วนตัว ติดตามเพื่อดู Drop')` ครอบทั้งก้อนเหมือน `RestrictionBanner`/`_buildBlockedBanner` เดิม

---

## Screen 3 — Follow Requests List (`FollowRequestListScreen`, จอใหม่)

**Purpose**: รายชื่อคำขอติดตามที่ยังไม่ตัดสินใจ — เฉพาะเจ้าของบัญชี Private เท่านั้นที่มีข้อมูลในนี้

**ทางเข้า**: badge จำนวนคำขอค้าง วางไว้ที่ `ViewProfileScreen` ของตัวเอง ต่อจากแถว Followers/Following count เดิม (WYN-008) — แสดงเป็นแถวเล็กคล้าย Screen 1 ของ WYN-032 ("คำขอติดตาม (N)" + `Icons.person_add_alt` + `chevron_right`) **เฉพาะเมื่อ `profile.isPrivate == true` และมีคำขอค้างอย่างน้อย 1 รายการ** (ซ่อนไปเลยถ้าเป็น Public หรือไม่มีคำขอค้าง — บัญชี Public ไม่มีทางมีคำขอค้างอยู่แล้วโดยธรรมชาติของ flow)

**Components**: มิเรอร์ `MessageRequestListScreen`/`FollowListScreen` shape ตรงๆ — แต่ละแถว: avatar, username/display name, เวลาแบบ relative ("ขอติดตามเมื่อ..."), ปุ่มคู่ Accept (`FilledButton`, Cyan, ขนาดเล็กพอดีแถว)/Reject (`OutlinedButton`) อยู่ใน `trailing`

**States**: Loading/Empty ("ยังไม่มีคำขอติดตาม")/Error+Retry/List — มิเรอร์ `FollowListScreen` ทุกจุด (ไม่มี pagination ก็ได้ในรอบแรกถ้าจำนวนคำขอทั่วไปไม่เยอะเท่า follower list — แต่ใช้ `FollowRepository.pageSize` เดิมเพื่อความสม่ำเสมอถ้า Coding เห็นว่าเพิ่ม pagination ไม่ยาก)

**Interactions**:
- **Accept** → เรียก `acceptFollowRequest(requesterId)` → optimistic remove แถวออกจาก list ทันที → คนนั้นกลายเป็น follower จริง (นับใน Followers count ทันที)
- **Reject** → confirm dialog สั้น "ปฏิเสธคำขอติดตามจาก {username}? ผู้ขอจะไม่ได้รับแจ้งเตือน" → ยืนยัน → เรียก `rejectFollowRequest(requesterId)` → optimistic remove

---

## Screen 4 — Notification: `follow_request` / `follow_request_accepted`

**Components**: แถวมาตรฐานของ `NotificationListScreen` เดิม — `follow_request`: "{username} ขอติดตามคุณ" แตะ → เปิด `FollowRequestListScreen` ตรง (ไม่ใช่เปิดโปรไฟล์ผู้ขอ เพราะ action ที่ต้องทำคือ Accept/Reject ไม่ใช่ดูโปรไฟล์เฉยๆ) — `follow_request_accepted`: "{username} ยอมรับคำขอติดตามของคุณแล้ว" แตะ → เปิดโปรไฟล์ผู้ที่ accept (เหมือน notification `follow` ปกติ)

**Data**: `actor_id` = ผู้ขอ (สำหรับ `follow_request`) / ผู้ accept (สำหรับ `follow_request_accepted`) — เป็นการกระทำปกติของผู้ใช้จริงทั้งคู่ ไม่ใช่กรณี null-actor แบบ moderation

---

## Screen 5 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

```sql
-- 1) profiles: account type
alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- 2) internal helper -- mirrors internal.is_blocked_either_way's placement/style
create or replace function internal.can_view_author_content(p_viewer uuid, p_author uuid)
returns boolean language sql stable as $$
  select p_author = p_viewer
    or not exists (select 1 from public.profiles where id = p_author and is_private)
    or exists (
      select 1 from public.follows
      where follower_id = p_viewer and following_id = p_author
    );
$$;

-- 3) follow_requests -- separate table, mirrors conversations.status's
-- pending-state idea but as its own table (see decision 1 above)
create table if not exists public.follow_requests (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (requester_id, target_id),
  constraint follow_requests_no_self check (requester_id <> target_id)
);

alter table public.follow_requests enable row level security;

-- ทั้งสองฝ่ายเห็น row ของตัวเองได้เสมอ -- คนอื่นเห็นไม่ได้เลย (ต่างจาก
-- follows เดิมที่เปิดกว้าง เพราะ pending request เป็นข้อมูลที่ควรเป็น
-- ความลับระหว่างคู่กรณีเหมือน message_requests ของ WYN-032)
create policy "Follow requests are viewable by the two parties only"
  on public.follow_requests for select to authenticated
  using (auth.uid() in (requester_id, target_id));

create policy "Users can send follow requests as themselves"
  on public.follow_requests for insert to authenticated
  with check (
    auth.uid() = requester_id
    and not internal.is_blocked_either_way(auth.uid(), target_id)
    and exists (select 1 from public.profiles where id = target_id and is_private)
    and not exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = target_id
    )
  );

-- requester ยกเลิกคำขอตัวเอง, target ปฏิเสธคำขอที่ส่งมาหาตัวเอง -- ทั้งคู่
-- ทำผ่าน DELETE ธรรมดา ไม่ต้องมี RPC (ต่างจาก WYN-032's delete_message_
-- request ที่ต้องมี RPC เพราะมี edge case requested_by ที่ซับซ้อนกว่า)
create policy "Requester or target can remove a follow request"
  on public.follow_requests for delete to authenticated
  using (auth.uid() in (requester_id, target_id));

-- Accept: ต้องเป็น RPC (ไม่ใช่ client insert ตรงๆ) เพราะต้อง insert
-- follows + delete follow_requests + insert notification เป็น transaction
-- เดียว และต้องยืนยันว่าเป็น target จริงเท่านั้นที่ accept ได้
create or replace function public.accept_follow_request(p_requester_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.follow_requests
  where requester_id = p_requester_id and target_id = auth.uid();
  if not found then
    raise exception 'Follow request not found or not yours to accept';
  end if;

  insert into public.follows (follower_id, following_id)
  values (p_requester_id, auth.uid())
  on conflict do nothing;

  insert into public.notifications (recipient_id, actor_id, type, ...)
  values (p_requester_id, auth.uid(), 'follow_request_accepted', ...);
end;
$$;

-- Reject = DELETE ธรรมดาจาก client ตรงๆ (RLS ข้างบนอนุญาตอยู่แล้ว) --
-- ไม่ต้องมี RPC แยก, ไม่ insert notification ใดๆ

-- Trigger: insert notification 'follow_request' ทุกครั้งที่มีคำขอใหม่ --
-- มิเรอร์ 13 trigger เดิมที่ WYN-016 อ้างถึง (ทุก notification type
-- ที่เป็น "การกระทำของผู้ใช้ปกติ" ใช้ trigger, ไม่ใช่ manual insert --
-- ยกเว้น message_request ของ WYN-032 ที่ insert manual ใน RPC เพราะ
-- เป็นส่วนหนึ่งของ get_or_create_conversation() อยู่แล้ว ที่นี่ follow_
-- requests insert ตรงจาก client ไม่ผ่าน RPC ใดๆ จึงต้องใช้ trigger)
create or replace function internal.notify_follow_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, actor_id, type, ...)
  values (new.target_id, new.requester_id, 'follow_request', ...);
  return new;
end;
$$;

create trigger trg_notify_follow_request
  after insert on public.follow_requests
  for each row execute function internal.notify_follow_request();

-- 4) Auto-approve pending requests เมื่อสลับ Private -> Public
create or replace function internal.auto_approve_on_public()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_private = false and old.is_private = true then
    insert into public.follows (follower_id, following_id)
    select requester_id, target_id from public.follow_requests
    where target_id = new.id
    on conflict do nothing;

    delete from public.follow_requests where target_id = new.id;
  end if;
  return new;
end;
$$;

create trigger trg_auto_approve_on_public
  after update of is_private on public.profiles
  for each row execute function internal.auto_approve_on_public();

-- 5) จุดศูนย์กลางของการ gate เนื้อหา -- ต่อยอด WYN-027 pattern ตรงๆ
drop policy "Drops are viewable by authenticated users, excluding blocked authors" on public.drops;
create policy "Drops are viewable by authenticated users, excluding blocked and locked-private authors"
  on public.drops for select to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and internal.can_view_author_content(auth.uid(), author_id)
  );

-- ต้องไล่ทำแบบเดียวกันกับทุกตารางที่มี author_id ตรงและอ้างถึง author
-- โดยตรง (ไม่ใช่ผ่าน drop_id): drop_comments (author_id เป็นของผู้
-- คอมเมนต์ ไม่ใช่เจ้าของ Drop -- คงเงื่อนไข exclude-blocked เดิมไว้
-- แต่เพิ่ม `and exists (select 1 from public.drops d where d.id =
-- drop_id)` ถ้ายังไม่มี -- มิเรอร์ pattern ที่ redrops SELECT policy
-- ใช้อยู่แล้ว WYN-034 เพื่อ cascade การ gate ของ drops ไปยัง
-- drop_comments/drop_likes/saves ทุกตารางที่ลูกของ drop_id -- ให้ AI
-- Coding grep หาทุกตารางที่มี `drop_id` แล้วตรวจว่ามี exists-check นี้
-- ครบหรือยัง ไม่ครบให้เพิ่ม)

-- 6) follows SELECT policy -- แยก "เห็น edge ของตัวเอง" ออกจาก
-- "เห็น edge ของคนอื่น" (คนอื่นเห็นได้เฉพาะที่ทั้งสองฝั่งเปิดให้ดูอยู่)
drop policy "Follows are viewable by authenticated users" on public.follows;
create policy "Follows are viewable by parties or when both sides are visible"
  on public.follows for select to authenticated
  using (
    auth.uid() in (follower_id, following_id)
    or (
      internal.can_view_author_content(auth.uid(), follower_id)
      and internal.can_view_author_content(auth.uid(), following_id)
    )
  );

-- 7) จำนวน Followers/Following ต้องเห็นได้เสมอไม่ว่า privacy จะเป็นแบบ
-- ไหน (ต่างจากรายชื่อ) -- มิเรอร์ drop_view_count() ของ WYN-038 ตรงๆ
create or replace function public.follower_count(p_user_id uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select count(*) from public.follows where following_id = p_user_id;
$$;

create or replace function public.following_count(p_user_id uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select count(*) from public.follows where follower_id = p_user_id;
$$;
```

**หมายเหตุสำคัญที่สุดสำหรับ Coding**: ข้อ 5 (RLS ของ `drops`) คือกลไกหลักที่ทำให้ `home_feed`/`saved_feed`/Search (WYN-009)/Hashtag feed (WYN-020)/`DropDetailScreen.fetchById`/ReDrop ทุกจุด gate เนื้อหาถูกต้องโดยอัตโนมัติ **ตราบใดที่ query เหล่านั้นยัง query ผ่าน `public.drops`/`public.redrops` จริง ไม่ผ่าน SECURITY DEFINER function ใดที่ bypass RLS** — งานแรกที่ Coding ต้องทำก่อนเขียนโค้ดใหม่ใดๆ คือ `grep` หาทุกจุดที่ query Drop content (`from('drops')`, `.rpc(...)` ที่คืน Drop, view อื่นที่ join `drops`) แล้วยืนยันว่าไม่มีจุดไหน bypass RLS อยู่ก่อนแล้ว (จุดเดียวที่รู้อยู่แล้วว่าเป็น SECURITY DEFINER คือ `drop_view_count()` ของ WYN-038 ซึ่งปลอดภัยเพราะคืนแค่ตัวเลข ไม่คืนเนื้อหา)

**Client (Flutter) เปลี่ยนที่**:
- `FollowRepository`: เปลี่ยน `countFollowers`/`countFollowing` จาก `.from('follows').count()` เป็นเรียก RPC `follower_count`/`following_count` แทน (ตรงตามข้อ 7)
- `FollowRepository.isFollowing`: ไม่ต้องแก้ (query `follower_id=me`, RLS ข้อ 6 อนุญาตเห็น edge ของตัวเองเสมอ)
- `Profile` model: เพิ่ม `isPrivate` field
- `ProfileRepository`: เพิ่ม `updateIsPrivate(bool)`
- ใหม่: `FollowRequestRepository` (`sendRequest`/`cancelRequest`/`fetchPendingRequests`/`acceptRequest` [เรียก RPC]/`rejectRequest` [DELETE ตรง]/`hasPendingRequest`/`countPendingRequests` สำหรับ badge)
- `NotificationType`: เพิ่ม `followRequest`/`followRequestAccepted` (2 case ใหม่ต่อท้าย `messageRequest` เดิม มิเรอร์ pattern เดิมเป๊ะ)

---

## Handoff

AI Coding — ลำดับแนะนำ: (1) SQL ทั้งหมดในข้อ 1-7 ของ Screen 5 รวมถึงไล่ตรวจ/แก้ RLS ของตารางลูกทุกตัวที่อ้างถึง `drop_id` ให้ครบ (2) Flutter data layer (`Profile.isPrivate`, `FollowRequestRepository` ใหม่, แก้ `FollowRepository` ตามข้อ Client ด้านบน, `NotificationType` 2 case ใหม่) (3) Settings Screen 1 (toggle) (4) `ViewProfileScreen`'s Locked persona (Screen 2) + ปุ่ม Follow 3 สถานะ (5) `FollowRequestListScreen` (Screen 3) + badge entry point (6) Notification types (Screen 4) — **ทดสอบ regression ของ WYN-008/027/028/034/035 เดิมทุกจุดว่ายังทำงานปกติกับบัญชี Public** (โดยเฉพาะ Follow/Unfollow instant, Follower/Following list เดิม, Home feed ranking) ก่อนส่งต่อ QA ให้เน้นตรวจ 3 จุดเสี่ยงสุดตาม Product's Risks: (ก) ReDrop เป็นทางลัดข้าม private gate, (ข) ทุก entry point ที่ query Drop content ต้องถูก gate ครบไม่มีจุดไหนหลุด, (ค) `follow_requests` ไม่รั่วให้บุคคลที่สามเห็น
