# Product Full Spec — WYN-099

Status: full spec complete (2026-09-02) — ready for AI Design
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` ข้อ 4/28, `.wyn/tasks/backlog/WYN-099.md`

Feature: การตั้งค่าความเป็นส่วนตัวของแท็บ "ถูกใจ" บนโปรไฟล์

Goal: ให้ผู้ใช้ควบคุมได้ว่าใครเห็นรายการโพสต์ที่ตัวเองกดถูกใจได้บ้าง (ทุกคน / เพื่อน / เฉพาะฉัน)

Target User: ผู้ใช้ WYN Social ทุกคน

## Problem — สถานะปัจจุบันจริง (ตรวจโค้ดแล้ว)

`ViewProfileScreen` มีแท็บ "ถูกใจ" อยู่แล้ว (`ProfileLikesTab`) พร้อม `PrivacyNoticeBanner` ที่บอกผู้ใช้ตรงๆ ว่า **"คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน"** — เป็นการตัดสินใจแบบเปิดเผยจากรอบก่อนหน้า (`DropRepository.fetchLikedByAuthor` มี doc comment ยืนยันชัดว่า "Founder decision 2026-08-24 makes this tab itself public...no new RLS is needed") Founder ตอนนี้ (ข้อ 4/28) ต้องการย้อนมติเดิมบางส่วน: เพิ่มตัวเลือกปิด/จำกัดการมองเห็นได้ ไม่ใช่เปิดสาธารณะตายตัวอีกต่อไป

**Query ปัจจุบัน**: `DropRepository.fetchLikedByAuthor()` ยิง `.from('drop_likes').select('drops!inner(...)').eq('user_id', authorId)` ตรงผ่าน PostgREST — `drop_likes`/`pop_likes` มี SELECT RLS policy `using (true)` (เปิดให้ authenticated ทุกคนอ่านได้หมด) เพราะตารางเดียวกันนี้ยังถูกใช้คำนวณ `like_count`/`liked_by` (top-3 avatar) ของ**ทุกโพสต์**ใน `home_feed` view — เป็นคนละวัตถุประสงค์กับ "แท็บถูกใจของโปรไฟล์คนคนหนึ่ง"

## Data Model Impact (ตรวจ schema.sql จริงแล้ว)

**คอลัมน์ใหม่:**
```sql
alter table public.profiles
  add column if not exists likes_visibility text not null default 'everyone'
  check (likes_visibility in ('everyone', 'friends', 'only_me'));
```
- **ทำไมไม่ reuse `InteractionPermission`/`dm_permission` ฯลฯ (WYN-045) ที่มีอยู่แล้ว**: ตรวจโค้ดพบว่า enum นั้นมี 3 ค่า `everyone`/`people_i_follow`/`no_one` — **`people_i_follow` คือคนที่ตัวเอง follow (ทางเดียว)** ไม่ใช่ mutual-follow "เพื่อน" ตามนิยามใหม่ของ WYN-097 — ใช้คนละความหมายกัน เอามาปนกันจะสับสน (ใครเห็นถูกใจได้ควรอิงนิยาม "เพื่อน" เดียวกับ audience selector ไม่ใช่ "คนที่ฉันไปตามเขา") จึงสร้างคอลัมน์/ค่าใหม่แยกที่ใช้คำว่า `friends` ตรงกับ WYN-097 แทน

**ไม่แก้ RLS ของ `drop_likes`/`pop_likes` เลย** — เหตุผลสำคัญที่สุดของสเปกนี้ (ดู Architecture Decision ด้านล่าง)

## Architecture Decision: ทำไมไม่ใช้ RLS ตรงๆ กับ `drop_likes`

การเพิ่ม RLS select policy ที่เช็ค `likes_visibility` ของเจ้าของ like แต่ละแถวบน `drop_likes`/`pop_likes` **โดยตรง** จะพังฟีเจอร์อื่นที่ใช้ตารางเดียวกันอยู่แล้วทันที เพราะ RLS กรองเป็นรายแถวไม่สนใจ query context:
- `like_count` (`select count(*) from drop_likes where drop_id = d.id`) จะนับผิด — ถ้าคนที่กด Like ตั้ง `likes_visibility = 'only_me'` แถวไลค์ของเขาจะถูกซ่อนจาก COUNT ด้วย ทำให้ยอดไลค์ของ**โพสต์คนอื่น**ต่ำกว่าความจริง ทั้งที่ Founder ต้องการแค่ซ่อน "แท็บถูกใจ" ของโปรไฟล์ ไม่ได้ต้องการซ่อนยอดไลค์ของโพสต์
- `liked_by` (top-3 avatar คนที่กดไลค์ ในทุกโพสต์) จะขาดหายไปเช่นกัน

**วิธีแก้ที่ถูกต้อง**: เพิ่ม SECURITY DEFINER RPC ใหม่ที่รวม permission check เข้ากับ query ในตัวเดียว แทนการยิง `.from('drop_likes')` ตรง — mirrors pattern เดียวกับ `rising_profiles()`/`suggested_users()` (WYN-040) และ 5 RPC ของ Club (WYN-014):

```sql
create or replace function internal.can_view_likes(p_viewer uuid, p_target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    p_viewer = p_target
    or (select likes_visibility from public.profiles where id = p_target) = 'everyone'
    or (
      (select likes_visibility from public.profiles where id = p_target) = 'friends'
      and internal.is_mutual_follow(p_viewer, p_target)  -- reuse WYN-097's function
    );
$$;

create or replace function public.fetch_liked_drops(p_target_user_id uuid, p_page int default 0)
returns setof public.drops
language sql stable security definer set search_path = public
as $$
  select d.* from public.drop_likes dl
  join public.drops d on d.id = dl.drop_id
  where dl.user_id = p_target_user_id
    and internal.can_view_likes(auth.uid(), p_target_user_id)
  order by dl.created_at desc
  offset p_page * 20 limit 20;
$$;
```
(เช่นเดียวกันสำหรับ Pop: `fetch_liked_pops`) — `DropRepository.fetchLikedByAuthor()` เปลี่ยนจากยิง `.from('drop_likes')` ตรง เป็นเรียก `_client.rpc('fetch_liked_drops', ...)` แทน

**ข้อจำกัดที่ยอมรับและต้องบันทึกไว้อย่างตรงไปตรงมา**: วิธีนี้ปิดช่องทางที่แอปตั้งใจให้ใช้ (RPC) ได้จริง แต่ **`drop_likes`/`pop_likes` table เองยังเปิด SELECT ให้ authenticated ทุกคนเหมือนเดิม** (`using (true)`) เพราะไม่แตะมัน — คนที่ยิง query ตรงแบบเก่า (`.from('drop_likes').select().eq('user_id', X)`) ผ่าน Supabase REST โดยตรง (ไม่ผ่าน RPC) จะยังเห็นรายการ drop_id ที่ X ไลค์ได้เหมือนเดิม (แม้ตัว Drop object เต็มจะโดน RLS ของ `drops` บล็อกถ้า X ตั้ง audience เป็นอย่างอื่น แต่กรณี "เฉพาะฉัน"/"เพื่อน" ของ likes_visibility ไม่ผูกกับ audience ของโพสต์ที่ถูกไลค์เลย — เป็นคนละเรื่องกัน) นี่คือช่องโหว่ที่เหลืออยู่จริงถ้าต้องการ "airtight" แบบล็อกที่ตาราง — **การจะปิดสนิทจริงต้องปิด RLS select ของ `drop_likes` ทั้งตาราง แล้วเขียน `like_count`/`liked_by` ใหม่ทั้งหมดผ่าน security-definer function/view แทน ซึ่งเป็นงานที่กระทบฟีเจอร์ like ที่ผ่าน QA และ deploy ไปแล้วทั่วทั้งแอป ใหญ่กว่าสโคปของ WYN-099 มาก** — สเปกนี้แนะนำให้ทำแค่ระดับ RPC (ปิดช่องทางที่ตั้งใจให้ใช้งานจริง) ในรอบนี้ และบันทึก residual risk นี้ไว้ชัดเจนให้ QA ตัดสินใจว่ายอมรับได้หรือต้องส่งกลับมาที่ Product

## Requirements (UI/UX)

**1. Settings > ความเป็นส่วนตัว** — เพิ่มแถวใหม่ (รูปแบบเดียวกับ `_PermissionSettingTile` ที่มีอยู่แล้ว 3 แถวสำหรับ dm/mention/comment permission):
- Label: "ใครเห็นสิ่งที่คุณถูกใจได้"
- Subtitle: "ควบคุมว่าใครเห็นแท็บถูกใจบนโปรไฟล์ของคุณ"
- ตัวเลือก: ทุกคน / เพื่อน / เฉพาะฉัน

**2. หน้าโปรไฟล์ (`ViewProfileScreen`)**:
- `PrivacyNoticeBanner` เดิม ("คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน") อัปเดตข้อความให้สะท้อนสถานะจริงตามที่ตั้งค่าไว้ — ถ้าตั้งเป็น "เฉพาะฉัน"/"เพื่อน" ให้เปลี่ยนเป็นข้อความที่ตรงกับตัวเลือกนั้น เช่น "เฉพาะคุณเท่านั้นที่เห็นแท็บนี้" แทนข้อความเดิมที่บอกว่าทุกคนเห็น (มิฉะนั้นข้อความจะขัดแย้งกับพฤติกรรมจริง)
- เมื่อคนอื่นเปิดโปรไฟล์เราแล้วไม่มีสิทธิ์ดูแท็บถูกใจ: แสดง empty state แทนเนื้อหา ข้อความ **"บัญชีนี้ซ่อนรายการที่ถูกใจไว้"** (ไม่ใช้ error/ไม่ crash)

## Edge Cases

1. **เจ้าของโปรไฟล์เปิดดูแท็บถูกใจของตัวเอง**: เห็นเสมอไม่ว่าตั้งค่าอะไร (`p_viewer = p_target` check ก่อนเงื่อนไขอื่นเสมอ)
2. **เลิก mutual follow หลังตั้ง `likes_visibility = 'friends'`**: เช็คสดเหมือน WYN-097 (ไม่ snapshot) — เลิกเป็นเพื่อนกันปุ๊บ มองไม่เห็นทันที
3. **โพสต์ที่ถูกไลค์เอง set audience เป็น "เฉพาะฉัน" (WYN-097)**: `fetch_liked_drops` join กับ `drops` โดยไม่เช็ค audience ของ drop เอง (เฉพาะ `likes_visibility` ของเจ้าของ like) — เพราะ RPC เป็น `security definer` จะ bypass RLS ของ `drops` ด้วย ต้องเพิ่มเช็คซ้อน: RPC ต้องกรองเฉพาะแถวที่ `internal.can_view_drop_audience(auth.uid(), d.*)` ผ่านด้วย ไม่งั้นจะเห็น "เพื่อนไลค์โพสต์ลับของคนอื่น" ที่ตัวเองไม่มีสิทธิ์เห็นตัวโพสต์เอง — **แก้แล้วใน SQL ด้านบน ต้องเพิ่ม `and internal.can_view_drop_audience(auth.uid(), d)` เข้าไปใน WHERE ของ `fetch_liked_drops` ด้วย** (นี่คือจุดที่ WYN-097/WYN-099 เชื่อมกันจริง ไม่ใช่แค่ dependency ผิวเผิน)
4. **ตั้งค่าเป็น "เฉพาะฉัน" แล้วเปลี่ยนใจภายหลัง**: เปลี่ยนได้ตลอด ไม่มี cooldown

## Acceptance Criteria

- [ ] ตั้งค่าเป็น "เฉพาะฉัน" → คนอื่นเปิดโปรไฟล์เรา เห็น empty state "บัญชีนี้ซ่อนรายการที่ถูกใจไว้" ไม่เห็นรายการจริง
- [ ] ตั้งค่าเป็น "เพื่อน" → เฉพาะ mutual-follow เห็น คนอื่นเห็น empty state เดียวกัน
- [ ] ตั้งค่าเป็น "ทุกคน" (default เดิม) → พฤติกรรมเหมือนก่อนหน้านี้ทุกประการ ไม่มี regression
- [ ] `like_count`/`liked_by` (avatar คนกดไลค์) ของทุกโพสต์ทั่วแอป **ไม่เปลี่ยนแปลง** ไม่ว่าใครตั้งค่า likes_visibility เป็นอะไร (นี่คือจุดพิสูจน์ว่า architecture ที่เลือกถูกต้อง)
- [ ] เรียก `fetch_liked_drops` RPC ตรงๆ (ไม่ผ่าน UI) ด้วย user ที่ไม่มีสิทธิ์ → คืนค่าว่างเปล่า
- [ ] เพื่อนไลค์โพสต์ "เฉพาะฉัน" ของคนอื่น (Edge Case 3) → ไม่ปรากฏในแท็บถูกใจที่เราเห็นได้แม้เราจะมีสิทธิ์ดูแท็บถูกใจของเพื่อนคนนั้นก็ตาม

## Dependencies
- **ทำคู่กับ WYN-097 เป็นหลัก**: ใช้ `internal.is_mutual_follow()` และ `internal.can_view_drop_audience()` ร่วมกันโดยตรง (ดู Edge Case 3) — แนะนำให้ Coding รอบเดียวกันทำทั้งสองงานติดกัน ไม่ใช่แค่ "เกี่ยวข้องกัน" แบบผิวเผิน

## Out of Scope (รอบนี้)
- ปิดกั้น `drop_likes`/`pop_likes` table select ให้สนิท 100% (ดู Architecture Decision — ต้องแลกกับความเสี่ยง regression ของ like_count/liked_by ทั้งแอป)
- Setting เดียวกันสำหรับ Club post likes (ไม่มี concept นี้ในระบบ Club เลย ไม่ได้ถูกร้องขอ)
- ตั้งค่าแยกระหว่าง Drop-likes กับ Pop-likes (รอบนี้ค่าเดียวคุมทั้งคู่ เพื่อความง่าย — Pop ถูกซ่อนอยู่แล้วตาม WYN-102 ด้วย)

## Risks

| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ลืม enforce ฝั่ง backend แล้วข้อมูลรั่วผ่าน API ตรง | สูง | ทดสอบเรียก RPC ตรงๆ ด้วย user ไม่มีสิทธิ์ (AC ข้อสุดท้าย) — **แต่ยอมรับ residual risk ที่ raw table query ยังเปิดอยู่ (ดู Architecture Decision) ต้องแจ้ง QA/Founder ให้รับทราบตรงๆ ไม่ใช่ปิดบัง** |
| R2 | แก้ RPC ผิดจุดจน like_count/liked_by ของทั้งแอปพัง (regression กว้าง) | สูง | ไม่แตะ RLS ของ `drop_likes`/`pop_likes` เลยตามที่ระบุ, ทดสอบ like_count ก่อน-หลังด้วยชุดข้อมูลเดียวกันต้องตรงกันเป๊ะ |
| R3 | Migration ต้องเช็ค production schema จริงก่อน apply เหมือน WYN-071/072 | กลาง | apply ผ่าน Supabase Dashboard SQL Editor ตรง ไม่พึ่ง schema.sql load สดทั้งไฟล์ (ปัญหาที่รู้แล้วจาก DECISIONS.md 2026-09-02) |

## Recommendation
เดินหน้าตามแนวทาง RPC-only (ไม่แตะ RLS ของตาราง likes เดิม) — เป็นทางที่ปลอดภัยที่สุดต่อฟีเจอร์เดิมที่ deploy ไปแล้ว แม้จะมี residual risk ที่ยอมรับได้ตามที่บันทึกไว้ชัดเจน

## Handoff
ส่งต่อ **AI Design** (`/design`) ร่วมกับ WYN-097 — ขอบเขต UI เล็กกว่า WYN-097 มาก (แค่ 1 แถวใหม่ใน Settings + 1 empty state) แต่ data-model/RPC ผูกกับ WYN-097 โดยตรง แนะนำให้ Design ทำเป็น addendum สั้นๆ ต่อท้าย WYN-097 ไม่ต้องแยกเอกสารใหญ่
