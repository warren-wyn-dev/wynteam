# Design — WYN-039 (Private Account + Follow Request)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-039-private-account-follow-request.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `ViewProfileScreen`/`FollowRepository`/`FollowListScreen` (WYN-008) — มิเรอร์ UX pattern ของ Message Request (WYN-032, `.wyn/docs/design/wyn-032-message-request.md`) ให้มากที่สุดเท่าที่ทำได้ เพราะเป็นปัญหารูปแบบเดียวกัน (สร้างความสัมพันธ์ที่ต้องรออนุมัติก่อน)
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้

## ภาพรวม — 5 การตัดสินใจเชิง scope

1. **ไม่สร้างหน้าจอ Accept/Reject แยกทีละคน** — ทำเป็นหน้ารายการเดียว (`FollowRequestsScreen`) ที่มีปุ่ม Accept/Reject ต่อแถวเลย ต่างจาก Message Request ที่ต้องเปิด `ConversationScreen` แต่ละอันเพราะมีเนื้อหาข้อความให้อ่านก่อนตัดสินใจ — Follow Request ไม่มีอะไรให้ "อ่าน" มากไปกว่าหน้าโปรไฟล์ผู้ขอที่กดดูได้อยู่แล้ว จึงตัดสินใจตรงจากแถวได้เลยเร็วกว่า
2. **ปุ่ม Follow เดิม (3 จุด: `ViewProfileScreen`/`DropDetailScreen`/`PopClipView`) ขยายจาก 2 สถานะ (ติดตาม/กำลังติดตาม) เป็น 3 สถานะ (ติดตาม/ขอแล้ว/กำลังติดตาม)** — component เดิมทั้งหมด ไม่สร้างปุ่มใหม่ แค่เพิ่ม branch ที่ 3
3. **Grid ที่ถูกล็อกใช้ extension point ที่มีอยู่แล้ว** (`_gridEmptyText()` ใน `ViewProfileScreen` ที่รองรับ `isBlockedEitherWay` อยู่แล้ว) — เพิ่มเงื่อนไข `isPrivateLocked` เข้าไปอีกจุดเดียว ไม่ต้องสร้างกลไก empty-state ใหม่
4. **Reject ไม่ reuse Block/Report ของ WYN-026/027 แบบที่ Message Request ทำ** — คำขอติดตามปฏิเสธแล้วจบเลย ถ้าผู้ใช้อยากบล็อกคนขอจริงๆ ใช้ปุ่ม Block ที่มีอยู่แล้วในหน้าโปรไฟล์ของเขาได้อยู่แล้วโดยไม่ต้องมีทางลัดซ้ำจากหน้า Follow Requests (ตาม Product's Requirements)
5. **Settings เพิ่ม section ใหม่ "ความเป็นส่วนตัว"** (section แรกของ Settings ที่ไม่ใช่ "ความปลอดภัย" — ตอนนี้ Settings มีแค่ section เดียว) วางไว้เหนือ "ความปลอดภัย" เดิม (Privacy มาก่อน Safety ตามลำดับที่ Master Spec section 35 เขียนไว้: "Account → **Privacy** → Notifications → Security → Safety")

---

## Screen 1 — ปุ่ม Follow 3 สถานะ (`ViewProfileScreen`/`DropDetailScreen`/`PopClipView`)

**Purpose**: สื่อสารสถานะความสัมพันธ์ที่แท้จริง ไม่ให้ผู้ใช้เข้าใจผิดว่า "ขอแล้ว" คือ "ติดตามแล้ว"

**Components**: `OutlinedButton` เดิมทุกจุด (ไม่เปลี่ยนสไตล์/ตำแหน่ง) — ข้อความ/สี:
- `notFollowing` → "ติดตาม" (เหมือนเดิม)
- `pending` → "ขอแล้ว" (สีเดียวกับ `outline`/สีรอง ไม่ใช่สี primary — สื่อว่ายังไม่สำเร็จ ต่างจาก "กำลังติดตาม")
- `following` → "กำลังติดตาม" (เหมือนเดิม)

**Semantics label**: `notFollowing` → "กดเพื่อติดตาม" (เดิม), `pending` → "ส่งคำขอติดตามแล้ว กดเพื่อยกเลิกคำขอ", `following` → "กำลังติดตาม กดเพื่อเลิกติดตาม" (เดิม)

**Interactions**: กดปุ่มไม่ว่าสถานะไหนเรียก method เดียวกัน (`_toggleFollow`) — ฝั่ง data layer ตัดสินใจเองว่าเป็นการ follow/unfollow/cancel-request ตามสถานะปัจจุบัน (ดู Screen 6):
- `notFollowing` → กด → เรียก `followUser()` → ผลลัพธ์เป็น `pending` หรือ `following` ทันทีขึ้นอยู่กับว่าเป้าหมายเป็น Private หรือ Public (optimistic ตั้งค่าตาม `profile.isPrivate` ที่รู้อยู่แล้วฝั่ง client ก่อนเรียกจริง)
- `pending` → กด → เรียก `cancelFollowRequest()` (unfollow เดิม, ใช้ DELETE policy เดิมไม่เปลี่ยน) → กลับเป็น `notFollowing`
- `following` → กด → เรียก `unfollow()` เดิม → กลับเป็น `notFollowing`

**States**: เหมือนเดิมทุกจุด (nullable ระหว่างโหลด, ปุ่มซ่อนถ้าโหลดไม่สำเร็จ — มิเรอร์ pattern `_isFollowing == null` เดิมทั้ง 3 ไฟล์)

**Note สำหรับ `PopClipView`**: จุดนี้ไม่มีผู้ใช้เข้าถึงได้จริงแล้วตั้งแต่ WYN-024 (Pop ถูกถอดจาก Bottom Nav) — ต้องแก้ให้ compile ผ่านกับ signature ใหม่ของ `FollowRepository` เท่านั้น **ไม่ต้องออกแบบ/ทดสอบ UX 3 สถานะที่นี่ให้ประณีตเท่า 2 จุดแรก** (เปลี่ยนแค่พอให้ตรง type ใหม่ ข้อความ "ขอแล้ว" ใส่ไปเฉยๆ ได้โดยไม่ต้อง polish เพิ่ม)

---

## Screen 2 — Follow Requests List (`FollowRequestsScreen`)

**Purpose**: รายชื่อคำขอติดตามที่ยังไม่ตัดสินใจของบัญชีตัวเอง

**ทางเข้า**:
1. Settings → "ความเป็นส่วนตัว" section → `ListTile` ใหม่ "คำขอติดตาม" — **แสดงเฉพาะเมื่อ `profile.isPrivate == true`** (เป็น Public แล้วไม่มีทางมีคำขอค้างได้เลยตามที่ Product ออกแบบไว้ — auto-accept ทันทีตอนสลับเป็น Public) — ไม่มี badge ตัวเลขที่ Settings entry (เข้ากับ pattern เดิมของ Blocked List/Muted List ที่ไม่มี badge เช่นกัน)
2. Notification type `follow_request` (Screen 5) — แตะแล้วเปิดหน้านี้ตรง

**Components**: มิเรอร์ `MessageRequestListScreen`'s list shape (WYN-032) เกือบทั้งหมด — แต่ละแถว: avatar ผู้ขอ, username/display name, เวลาแบบ relative ("ขอเมื่อ...") แทนที่ preview ข้อความ (Follow Request ไม่มีข้อความให้ preview) — ปุ่ม **Accept** (`FilledButton` เล็ก, Cyan)/**Reject** (`OutlinedButton` เล็ก) ต่อท้ายแถวเลย (ต่างจาก Message Request ที่ต้องเปิดหน้าอื่นก่อน — เหตุผลอยู่ในภาพรวม ข้อ 1)

**States**: Loading/Empty ("ยังไม่มีคำขอติดตาม")/Error+Retry/List+pagination — มิเรอร์ `MessageRequestListScreen` ทุกจุด

**Interactions**:
- แตะแถว (นอกปุ่ม Accept/Reject) → เปิด `ViewProfileScreen` ของผู้ขอ (ดูโปรไฟล์ก่อนตัดสินใจได้ — โปรไฟล์เห็นได้เสมอตาม Product's Requirements)
- **Accept** → เรียก `acceptFollowRequest()` → optimistic ลบแถวออกจาก list ทันที → ล้มเหลว insert แถวกลับ + snackbar error
- **Reject** → เรียก `rejectFollowRequest()` (ไม่มี confirm dialog — ต่างจาก Message Request's Delete ที่มี confirm เพราะ Follow Request คืนสภาพง่ายกว่ามาก ผู้ขอกดขอใหม่ได้ทันทีไม่มีต้นทุนอะไรเสีย) → optimistic ลบแถวออกจาก list ทันที → ล้มเหลว insert แถวกลับ + snackbar error

---

## Screen 3 — Settings: "ความเป็นส่วนตัว" section ใหม่

**Purpose**: ทางเข้าเดียวของการเปลี่ยน Account Type

**ตำแหน่ง**: section ใหม่เหนือ "ความปลอดภัย" เดิมใน `SettingsScreen` (ดู Recommendation ของ Product ข้อลำดับ Master Spec section 35)

**Components**:
- Heading "ความเป็นส่วนตัว" (มิเรอร์สไตล์ heading "ความปลอดภัย" เดิมเป๊ะๆ — `titleSmall`/`outline` color)
- `SwitchListTile` — leading `Icons.lock_outline`, title "บัญชีส่วนตัว", subtitle "เฉพาะผู้ติดตามที่คุณอนุมัติเท่านั้นที่เห็น Drop และ Pop ของคุณได้" (subtitle อธิบายผลลัพธ์ตรงๆ ไม่ต้องเปิดหน้าอื่นเพื่อทำความเข้าใจ), value ผูกกับ `profile.isPrivate`
- `ListTile` "คำขอติดตาม" (Screen 2's ทางเข้าที่ 1) — แสดงเฉพาะ `profile.isPrivate == true` (ดู Screen 2)

**Interactions**: สลับ Switch → optimistic toggle ทันที → เรียก `ProfileRepository.setPrivate(bool)` → ล้มเหลว revert switch + snackbar error — **ไม่มี confirm dialog ตอนเปิดเป็น Private** (การกระทำย้อนกลับได้ง่าย ไม่ทำลายอะไร) **แต่ควรมี confirm dialog สั้นตอนเปลี่ยนกลับเป็น Public** เพราะมีผลข้างเคียงที่ย้อนกลับไม่ได้ (คำขอค้างทั้งหมด auto-accept ทันที ไม่สามารถ "เปลี่ยนใจ" เลือกอนุมัติทีละคนได้อีกถ้าพลาดกดสลับกลับ) — ข้อความ dialog: "เปลี่ยนเป็นบัญชีสาธารณะ? คำขอติดตามที่ค้างอยู่ทั้งหมดจะได้รับการอนุมัติทันที"

---

## Screen 4 — `ViewProfileScreen`: สถานะที่ถูกล็อก (ไม่ใช่ Follower ของบัญชี Private)

**เงื่อนไขเข้าสู่สถานะนี้**: `!isOwnProfile && profile.isPrivate && followStatus != FollowStatus.following` (ทั้ง `notFollowing` และ `pending` เข้าเงื่อนไขนี้เหมือนกัน — ส่งคำขอไปแล้วก็ยังล็อกอยู่จนกว่าจะได้รับอนุมัติ)

**สิ่งที่ยังเห็นปกติ** (ตาม Product's "โปรไฟล์ยังเห็นได้เสมอ"): avatar, ชื่อ/username, bio, ปุ่ม Follow (Screen 1), จำนวน Followers/Following (ตัวเลขเท่านั้น)

**สิ่งที่เปลี่ยน**:
1. `_FollowCountTarget`'s `onTap` (แถวจำนวน Followers/Following) → **ไม่ navigate** ในสถานะล็อก (เดิม `onTap` เปิด `FollowListScreen` เสมอ) — เปลี่ยนเป็น no-op เงียบๆ หรือ `SnackBar` สั้น "บัญชีนี้เป็นส่วนตัว" (ไม่ต้องเปลี่ยนตัวเลขเป็นสีจาง/ตัด `onTap` ทิ้งไปเลยก็ได้ถ้า Coding เห็นว่าง่ายกว่า — ทั้งสองแบบสื่อความหมายถูกต้อง ให้ Coding เลือกตามความสะดวกของโค้ดเดิม)
2. Grid ทุกแท็บ (Drop/ReDrops/Pop) → ใช้ extension point `_gridEmptyText()` เดิม เพิ่มเงื่อนไขใหม่ก่อน `isBlockedEitherWay` (ลำดับ priority: Blocked > Private-locked > ปกติ — ถ้าบล็อกกันอยู่ให้ข้อความ Blocked เดิมชนะเสมอ ไม่ปนกับข้อความ Private):
   ```
   if (isPrivateLocked) {
     return followStatus == FollowStatus.pending
       ? 'ส่งคำขอติดตามแล้ว รอการอนุมัติจาก ${profile.nameOrUsername}'
       : '${profile.nameOrUsername} เป็นบัญชีส่วนตัว ติดตามเพื่อดูเนื้อหา';
   }
   ```
   ข้อความสองแบบตามว่าส่งคำขอไปแล้วหรือยัง (ให้ผู้ใช้รู้สถานะของตัวเองชัดเจน ไม่ใช่ข้อความเดียวกันทุกกรณี)

**ไม่กระทบ**: Saved/Drafts tab (แสดงเฉพาะ `isOwnProfile` อยู่แล้ว ไม่มีทางเข้าถึงสถานะนี้ได้เลย), `_buildMyClubsSection()` (Club เป็นระบบ membership แยกจาก Follow อยู่แล้ว ไม่เกี่ยวกัน)

---

## Screen 5 — Notification: `follow_request`

**Purpose**: แจ้งเจ้าของบัญชี Private ทันทีที่มีคำขอใหม่

**Components**: แถวมาตรฐานของ `NotificationListScreen` เดิม (avatar ผู้ขอ + ข้อความ "{username} ขอติดตามคุณ") — icon มิเรอร์ประเภทเดียวกับ `follow` (คนละไอคอนเล็กน้อยถ้า Coding อยากแยก เช่น `person_add_outlined` แทน `person_outline` เดิมของ `follow` — ไม่บังคับต้องต่างกัน ถ้าใช้ icon เดียวกับ `follow` เดิมก็ยอมรับได้เพราะทั้งคู่คือ "มีคนสนใจติดตามคุณ")

**Interactions**: แตะ → เปิด `FollowRequestsScreen` (Screen 2) ตรง มิเรอร์ `clubJoinRequest`'s pattern (เปิดหน้ารายการที่มีคำขอนี้อยู่) ไม่ใช่มิเรอร์ `messageRequest`'s pattern (เปิดตรงไปยังรายการเดียว) เพราะ Follow Request ไม่มีหน้าจอเดี่ยวต่อคำขอ (ตาม Screen 2 — ตัดสินใจแล้วว่าไม่สร้าง)

**Data**: `actor_id` = ผู้ขอ (มีอยู่จริงเสมอ ไม่ใช่กรณี null-actor แบบ moderation)

---

## Screen 6 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

ยืนยัน Recommendation ข้อ 1–13 ของ Product ทั้งหมดตรงตามที่เขียนไว้ ไม่มีข้อขัดแย้งเชิง UX — เพิ่มรายละเอียดที่ Product ไม่ได้ระบุ:

```sql
-- profiles: คอลัมน์ใหม่ + policy update เดิมพอ (ไม่ต้องเปลี่ยน UPDATE policy เอง
-- เพราะ "Users can update their own profile" ที่มีอยู่แล้วครอบคลุมคอลัมน์ใหม่
-- นี้โดยอัตโนมัติอยู่แล้ว เหมือนที่ display_name/bio/avatar_url ทำมาก่อน)
alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- follows: status column มิเรอร์ conversations.status เป๊ะๆ
alter table public.follows
  add column if not exists status text not null default 'active'
  check (status in ('active', 'pending'));

-- ลบ INSERT policy ตรงทิ้ง -- follow_user() RPC เท่านั้นคือทางเขียนเดียว
drop policy "Users can follow others as themselves, excluding blocked relationships" on public.follows;

-- DELETE policy เดิม (auth.uid() = follower_id) ไม่ต้องแตะ

create or replace function public.follow_user(p_following_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_is_private boolean;
  v_status text;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  if p_following_id = v_me then raise exception 'Cannot follow yourself'; end if;
  if internal.is_blocked_either_way(v_me, p_following_id) then
    raise exception 'Cannot follow a blocked relationship';
  end if;

  select is_private into v_is_private from public.profiles where id = p_following_id;
  if v_is_private is null then raise exception 'User not found'; end if;

  v_status := case when v_is_private then 'pending' else 'active' end;

  insert into public.follows (follower_id, following_id, status)
  values (v_me, p_following_id, v_status);
  -- ไม่มี on conflict do nothing ตรงนี้ -- follow ซ้ำ (ไม่ว่า status ไหน)
  -- ควรพัง error ตรงๆ ให้ client เห็นชัดว่ามีความสัมพันธ์อยู่แล้ว ต่างจาก
  -- WYN-038's view record ที่ยอมรับ no-op เงียบๆ ได้เพราะไม่มีผลลัพธ์ทางธุรกิจ
  -- ให้ผู้ใช้ต้องรู้ตัว แต่ follow ซ้ำคือ client-side bug ที่ควรเห็น error ชัดเจน
end;
$$;

grant execute on function public.follow_user(uuid) to authenticated;

create or replace function public.accept_follow_request(p_follower_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.follows
  set status = 'active'
  where follower_id = p_follower_id and following_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'Follow request not found or already resolved';
  end if;
end;
$$;

create or replace function public.reject_follow_request(p_follower_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
  where follower_id = p_follower_id and following_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'Follow request not found or already resolved';
  end if;
end;
$$;

grant execute on function public.accept_follow_request(uuid) to authenticated;
grant execute on function public.reject_follow_request(uuid) to authenticated;

-- notify_follow(): branch ตาม status, เพิ่ม 'follow_request' เข้า
-- notifications_type_check ด้วย introspect-drop-recreate pattern เดิม
create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' then
    insert into public.notifications (recipient_id, actor_id, type)
    values (new.following_id, new.follower_id, 'follow');
  else
    insert into public.notifications (recipient_id, actor_id, type)
    values (new.following_id, new.follower_id, 'follow_request');
  end if;
  return new;
end;
$$;
-- trigger เดิม (follows_notify, AFTER INSERT) ไม่ต้องแก้ -- แค่ function ข้างในเปลี่ยน

-- Private -> Public auto-accept: trigger ใหม่บน profiles
create or replace function public.auto_accept_follow_requests_on_public()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.is_private = true and new.is_private = false then
    update public.follows set status = 'active'
    where following_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger profiles_auto_accept_on_public
  after update of is_private on public.profiles
  for each row execute function public.auto_accept_follow_requests_on_public();

-- Content visibility -- ฟังก์ชันกลางใช้ร่วม 4 จุด (drops/pops/drop_comments/pop_comments)
create or replace function internal.can_view_content(p_author_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    p_author_id = auth.uid()
    or not coalesce((select is_private from public.profiles where id = p_author_id), false)
    or exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = p_author_id and status = 'active'
    );
$$;

grant execute on function internal.can_view_content(uuid) to authenticated;

-- drops/pops SELECT policy: drop+recreate แบบเดิม เพิ่ม "and internal.can_view_content(author_id)"
-- ต่อจาก is_blocked_either_way/deleted_at เดิม -- ไม่ต้องแก้ home_feed/saved_feed view เลย

-- drop_comments/pop_comments SELECT policy: เพิ่มเงื่อนไขเดียวกันเช็คกับเจ้าของ
-- Drop/Pop แม่ (ไม่ใช่เจ้าของ comment เอง) -- มิเรอร์ตรรกะเดียวกับที่ WYN-037
-- เช็ค deleted_at ของ Drop แม่ใน drop_comments' SELECT policy อยู่แล้ว

-- get_or_create_conversation() (WYN-032): เพิ่ม "and status = 'active'" เข้า
-- exists (select 1 from follows where follower_id = ... and following_id = ...) เดิม
```

**FollowRepository เมธอดใหม่/เปลี่ยน**:
- `Future<FollowStatus> followStatus({required String userId})` แทนที่ `isFollowing()` เดิม — คืน enum `notFollowing`/`pending`/`following` จาก `select status from follows where follower_id = me and following_id = userId`
- `followUser(userId)` เรียก RPC `follow_user` (แทนที่ insert-path เดิมใน `toggleFollow()`) — `cancelFollowRequest(userId)`/`unfollow(userId)` ทั้งคู่เรียก DELETE เดิม (`cancelFollowRequest` เป็นแค่ alias ความหมายชัดเจนกว่า อาจใช้ method เดียวกันกับ unfollow เดิมเลยก็ได้ถ้า Coding เห็นว่าไม่ต้องแยก)
- `acceptFollowRequest(followerId)`/`rejectFollowRequest(followerId)` เรียก RPC ใหม่ 2 ตัว
- `fetchFollowRequests({page})` query `follows` ตรง (`.eq('following_id', me).eq('status', 'pending')`) join `profiles` มิเรอร์ `fetchFollowers()`/`fetchFollowing()` shape เดิม
- `countFollowers/countFollowing/fetchFollowers/fetchFollowing` ทั้ง 4 เมธอดเดิม: เพิ่ม `.eq('status', 'active')`

**ProfileRepository**: เพิ่ม `isPrivate` เข้า `Profile` model + `fromMap()`, เพิ่มเมธอด `setPrivate(bool)` (update ตรง ใช้ policy เดิม)

---

## Handoff

AI Coding — เริ่มจาก (1) SQL ทั้งหมดใน Screen 6 ตามลำดับ: `profiles.is_private`, `follows.status` + ลบ INSERT policy เดิม, `follow_user()`/`accept_follow_request()`/`reject_follow_request()`, แก้ `notify_follow()`, trigger ใหม่ `auto_accept_follow_requests_on_public`, `internal.can_view_content()` + ขยาย SELECT policy ของ `drops`/`pops`/`drop_comments`/`pop_comments` ทั้ง 4 จุด, เพิ่ม `'follow_request'` เข้า `notifications_type_check`, แก้ `get_or_create_conversation()`'s follows check ให้กรอง `status = 'active'` (2) Flutter data layer: `Profile.isPrivate`, `ProfileRepository.setPrivate()`, `FollowRepository` ตามรายการด้านบนทั้งหมด รวม enum `FollowStatus` ใหม่ (3) ปุ่ม Follow 3 สถานะทั้ง 3 จุด (Screen 1) (4) `FollowRequestsScreen` ใหม่ (Screen 2) + entry point ใน Settings (Screen 3) (5) `ViewProfileScreen`'s locked state (Screen 4) (6) notification type + `NotificationListScreen`'s 2 switch statement เพิ่ม case (Screen 5) — ทดสอบ regression ของ Public account (ค่าเริ่มต้น/ส่วนใหญ่ของระบบ) ว่าพฤติกรรมเหมือนเดิมทุกจุดไม่เปลี่ยนแปลงเลย โดยเฉพาะ Message Request (WYN-032) ที่ใช้ `follows` เป็นสัญญาณร่วมกัน ต้องพิสูจน์ว่า pending follow request ไม่ทำให้ message ข้ามขั้นตอนไปเป็น active ผิดๆ
