# Design — WYN-034 (ReDrop: Standard + Quote)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-034-redrop.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `home_feed` view (WYN-007/018/024/028) และ pattern "resolve เนื้อหาผ่าน repository เดิม ไม่ denormalize" ที่ WYN-033 วางไว้
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้

## ภาพรวม — 6 การตัดสินใจเชิง scope

1. **ตารางใหม่ 1 ตาราง `redrops`** (`drop_id` FK cascade, `redropper_id`, `quote_text` nullable [null = Standard, ไม่ null = Quote]) — partial unique index กัน Standard ซ้ำ ไม่กัน Quote ซ้ำ
2. **`home_feed` view ไม่เพิ่ม `content_type` ใหม่** — ReDrop (ทั้ง Standard/Quote) ยังคงเป็น `content_type = 'drop'` เดิม แค่แถวมาจาก `redrops` join `drops` แทนที่จะมาจาก `drops` ตรงๆ พร้อมคอลัมน์เสริม nullable ใหม่ 6 ตัว (`redrop_id`/`redropper_id`/`redropper_username`/`redropper_display_name`/`redropper_avatar_url`/`quote_text`) — `id`/`author_id`/`image_url`/`caption`/`like_count`/`comment_count` ทั้งหมดยังชี้ไปที่ **Drop ต้นทาง** เสมอ ไม่ใช่ตัว redrop เอง เพราะฉะนั้น Like/Comment/Save ที่มีอยู่แล้วทำงานถูกต้องทันทีไม่ต้องแก้อะไรเลย (กดไลค์การ์ดที่เห็นผ่าน ReDrop = ไลค์ Drop ต้นทางจริง เหมือนที่ Master Spec ต้องการ "เครดิตเจ้าของเดิมต้องยังอยู่")
3. **`rankingScore()` (WYN-018) ไม่ต้องแก้เลยสักบรรทัด** — เพราะ `like_count`/`comment_count`/`author_id` ของแถวที่มาจาก ReDrop ยังคงเป็นของ Drop ต้นทางเป๊ะ สูตรเดิมทำงานถูกต้องอัตโนมัติ มีแค่ `created_at` ของแถวที่เปลี่ยนความหมายเป็น "เวลาที่ ReDrop เกิดขึ้น" (ไม่ใช่เวลาโพสต์ Drop เดิม) เพื่อให้ ReDrop ที่เพิ่งเกิดขึ้นสดใหม่ในฟีดจริง — เจตนา ไม่ใช่บั๊ก
4. **ปุ่ม 🔄 เปิด action sheet เล็ก 2 ตัวเลือกเสมอ** ("🔄 ReDrop" หรือ "ยกเลิก ReDrop" ถ้าเคย Standard ไปแล้ว / "💬 Quote ReDrop") — ไม่ทำเป็น single-tap-toggle ตรงๆ เหมือน Like เพราะ ReDrop คือการกระจายเนื้อหาไปหา follower ตัวเอง ผลกระทบกว้างกว่าการกดไลค์ ต้องมี intent ชัดเจนกว่า (มิเรอร์ UX ที่คุ้นเคยของแพลตฟอร์มอื่นที่มี Repost/Quote คู่กัน)
5. **Quote ReDrop ไม่มี engagement ของตัวเอง** (ตามที่ Product spec's Risk ยอมรับไว้) — นับรวมเข้า `redrop_count` ของ Drop ต้นทางเท่านั้น ไม่มี like/comment แยก
6. **Mute/Block ต้องเช็คทั้ง 2 ฝั่ง** สำหรับแถวที่มาจาก ReDrop: เจ้าของ Drop เดิม (`author_id`, ผ่าน RLS เดิมของ `drops` ที่ join เข้ามา) และผู้ ReDrop (`redropper_id`, เช็คตรงบน `redrops`) — ทั้ง mute filter ใน view และ RLS ของ `redrops` เอง

---

## Screen 1 — ปุ่ม 🔄 ReDrop บน Drop Card (Home + `DropDetailScreen`)

**Purpose**: ทางเข้าหลักของ ReDrop ทั้ง 2 แบบ

**ตำแหน่ง**: แทนที่ปุ่ม 🔄 ที่ยังไม่เคย implement บน `HomeDropCard`/`DropDetailScreen`'s action row (คู่กับ Like/Comment/Share/Save เดิม) — ไอคอนเปลี่ยนสีเป็น primary (Cyan) เมื่อ `redroppedByMe == true` (มิเรอร์ Like button's filled-heart state เดิมเป๊ะ) พร้อมตัวเลข `redrop_count` ข้างไอคอน

**Interactions**: แตะ 🔄 → เปิด `showModalBottomSheet` เล็ก:
- ถ้า `redroppedByMe == false`: "🔄 ReDrop" (Standard, ทำทันทีไม่ต้องยืนยันซ้ำ ปิด sheet + ไอคอนเปลี่ยนเป็น filled + count +1) / "💬 Quote ReDrop" (เปิด Screen 2)
- ถ้า `redroppedByMe == true`: "ยกเลิก ReDrop" (ลบ Standard ReDrop ทันที ไอคอนกลับเป็น outline + count -1) / "💬 Quote ReDrop" (ยังเปิดได้อิสระ ไม่ผูกกับสถานะ Standard — เป็นคนละ action กัน)

**States**: กด "🔄 ReDrop"/"ยกเลิก ReDrop" ล้มเหลว → snackbar "ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง" ไอคอน revert กลับสถานะเดิม (มิเรอร์ Like button's optimistic-update-then-revert-on-error ที่มีอยู่แล้ว)

---

## Screen 2 — Quote ReDrop Composer (หน้าจอใหม่)

**Purpose**: เขียนความคิดเห็นประกอบ Drop ที่จะ ReDrop

**User Flow**: เปิดจาก Screen 1's "💬 Quote ReDrop" → พิมพ์ข้อความ → "โพสต์" → snackbar ยืนยัน → pop กลับ

**Components**:
- `AppBar`: title "Quote ReDrop", ปุ่ม "โพสต์" ที่ trailing (disable เมื่อข้อความว่างหรือกำลังส่ง)
- `TextField` multiline ไม่มี label (placeholder "เพิ่มความคิดเห็น...") จำกัด 500 ตัวอักษร (reuse ตรรกะความยาวเดียวกับ `CreateDropScreen`'s caption field)
- ใต้ TextField: preview card ของ Drop ต้นทาง แบบ read-only ไม่ลบ/แก้ไขได้ (reuse pattern เดียวกับ WYN-033's shared-content preview — ในที่นี้ resolve ตรงจาก object ที่ส่งเข้ามาแล้ว ไม่ต้อง fetch ซ้ำเพราะผู้ใช้กำลังดู Drop นั้นอยู่แล้วตอนกด Quote ReDrop)

**Interactions**: "โพสต์" → insert แถว `redrops` ใหม่ (`quote_text` ไม่ null) → snackbar "ReDrop แล้ว" → pop กลับ

**States**: ส่งไม่สำเร็จ → snackbar error ไม่ปิดหน้าจอ (ข้อความที่พิมพ์ไว้ไม่หาย ลองส่งซ้ำได้)

---

## Screen 3 — Feed Card Label (Home + Profile "ReDrops" tab)

**Purpose**: บอกผู้ใช้ว่าการ์ดที่เห็นมาจาก ReDrop ไม่ใช่ Drop ต้นฉบับที่คนที่ตัวเอง follow โพสต์เอง

**Components** (แถบบางๆ เหนือการ์ด Drop ปกติ เมื่อ `redropId != null`):
- "🔄 ReDrop โดย @{redropperUsername}" (สีเทา ตัวเล็ก) — แตะแล้วเปิด Profile ของผู้ ReDrop (ไม่ใช่เจ้าของ Drop เดิม)
- ถ้า `quoteText != null` (Quote ReDrop): แสดงข้อความของผู้ ReDrop เป็นข้อความปกติ **เหนือ** การ์ด Drop ต้นทาง (การ์ด Drop ต้นทางกลายเป็นเหมือน embedded preview ใต้ข้อความ คล้าย Quote ReDrop composer ตอนเขียน)
- ตัวการ์ด Drop เอง (avatar/username/รูป/caption/สถิติ) **ไม่เปลี่ยนแปลงเลย** ไม่ว่าจะมาจาก ReDrop หรือไม่

---

## Screen 4 — Profile "ReDrops" Tab ใหม่

**Purpose**: ตาม Master Spec section 9's Tabs: Drops, ReDrops, Media, Likes — เพิ่มแค่ "ReDrops" รอบนี้ (Media/Likes ไม่อยู่ใน scope ของ task นี้ ยังคงเป็น "Drop"/"Pop"/"บันทึก" เดิมที่มีอยู่)

**ตำแหน่ง**: เพิ่ม `Tab` ใหม่ใน `ViewProfileScreen`'s `TabBar` เดิม ระหว่าง "Drop" กับ "Pop" (ตามลำดับที่ Master Spec ระบุ: Drops, ReDrops, ...) — icon `Icons.repeat`

**Components**: ใช้ widget โครงเดียวกับ `ProfileDropGridTab` เดิม (grid) หรือ list ตาม pattern ที่ Design ประเมินว่าเหมาะกว่าตอน Coding เห็นข้อมูลจริง (แนะนำ **list ไม่ใช่ grid** เพราะ Quote ReDrop มีข้อความประกอบที่ grid tile เล็กๆ แสดงไม่ได้ ต่างจาก Drop tab เดิมที่เป็นแค่รูปล้วนๆ) — แสดง label "🔄 ReDrop โดย @username" (ของเจ้าของ Profile ที่กำลังดู เสมอ ไม่ใช่ผู้ดู) + การ์ด Drop ต้นทางแบบเดียวกับ Screen 3

**Interactions**: แตะการ์ด → เปิด `DropDetailScreen` ของ Drop ต้นทาง (ไม่ใช่หน้าจอแยกสำหรับ redrop)

---

## Screen 5 — Data & Enforcement Notes (สำหรับ AI Coding โดยเฉพาะ)

```sql
create table if not exists public.redrops (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  redropper_id uuid not null references public.profiles (id) on delete cascade,
  quote_text text,
  created_at timestamptz not null default now(),
  constraint redrops_quote_text_length
    check (quote_text is null or char_length(quote_text) between 1 and 500)
);

-- Standard ReDrop (quote_text is null) ต่อ (drop_id, redropper_id) ทำได้แค่ 1 แถว --
-- Quote ReDrop ไม่ถูกจำกัด ทำซ้ำ Drop เดิมได้หลายครั้งคนละข้อความ
create unique index if not exists redrops_standard_unique
  on public.redrops (drop_id, redropper_id) where quote_text is null;
create index if not exists redrops_drop_idx on public.redrops (drop_id);
create index if not exists redrops_redropper_created_idx
  on public.redrops (redropper_id, created_at desc);

alter table public.redrops enable row level security;

-- exists(...drops...) ทำหน้าที่ 2 อย่างพร้อมกันโดยไม่ต้องเขียน block-check
-- ซ้ำเอง: (1) piggyback บน drops' own SELECT policy ที่ block-aware อยู่
-- แล้ว (ถ้า viewer block/ถูก block กับเจ้าของ Drop เดิม แถวนั้นจะมองไม่
-- เห็นจาก subquery นี้เลย -- ไม่ใช่ self-referential trap แบบ WYN-027
-- เจอ เพราะเราแค่ต้องการรู้ "เห็นแถวนี้ไหม" ไม่ได้ต้องดึง author_id ออกมา
-- จากแถวที่อาจถูกซ่อน) (2) กรอง Drop ที่ถูกลบไปแล้วออกไปด้วย (แม้ปกติ
-- cascade delete จะลบแถว redrops ทิ้งไปพร้อมกันอยู่แล้ว เป็น defensive
-- backstop เฉยๆ)
create policy "Redrops are viewable by authenticated users, excluding blocked redroppers"
  on public.redrops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), redropper_id)
    and exists (select 1 from public.drops d where d.id = drop_id)
  );

create policy "Users can redrop as themselves, excluding blocked authors and moderation-blocked accounts"
  on public.redrops
  for insert
  to authenticated
  with check (
    auth.uid() = redropper_id
    and not internal.is_posting_blocked(auth.uid())
    and exists (
      select 1 from public.drops d
      where d.id = drop_id and not internal.is_blocked_either_way(auth.uid(), d.author_id)
    )
  );

create policy "Users can delete their own redrops"
  on public.redrops
  for delete
  to authenticated
  using (auth.uid() = redropper_id);

-- home_feed's 3rd branch -- content_type ยังเป็น 'drop' เสมอ, id/author_id/
-- image_url/caption/like_count/comment_count ชี้ Drop ต้นทางเสมอ (ดูข้อ 2
-- ของภาพรวม) -- redrop_id/redropper_*/quote_text เป็น null สำหรับแถว
-- drop/pop ปกติ 2 branch เดิม (ต้องเติม null::... ให้ตรง column ให้ครบ
-- ทั้ง 3 branch ไม่งั้น UNION ALL พังเรื่อง column type ไม่ตรงกัน)
select
  d.id, 'drop'::text as content_type, d.author_id,
  prof.username as author_username, prof.display_name as author_display_name,
  prof.avatar_url as author_avatar_url,
  r.created_at,  -- เวลา ReDrop เกิดขึ้น ไม่ใช่เวลาโพสต์ Drop เดิม -- ดูข้อ 3
  d.caption, d.image_url,
  null::text as video_url, null::text as thumbnail_url,
  null::integer as duration_seconds, null::bigint as view_count,
  (select count(*) from public.drop_likes where drop_id = d.id) as like_count,
  (select count(*) from public.drop_comments where drop_id = d.id) as comment_count,
  (select count(*) from public.redrops where drop_id = d.id) as redrop_count,
  r.id as redrop_id, r.redropper_id,
  redropper.username as redropper_username,
  redropper.display_name as redropper_display_name,
  redropper.avatar_url as redropper_avatar_url,
  r.quote_text
from public.redrops r
join public.drops d on d.id = r.drop_id
join public.profiles prof on prof.id = d.author_id
join public.profiles redropper on redropper.id = r.redropper_id
where not exists (
  select 1 from public.mutes
  where muter_id = auth.uid() and muted_id in (d.author_id, r.redropper_id)
)
-- (แถว drop/pop เดิม 2 branch: เติม null::uuid as redrop_id,
-- null::uuid as redropper_id, null::text as redropper_username,
-- null::text as redropper_display_name, null::text as redropper_avatar_url,
-- null::text as quote_text, และ redrop_count เติมด้วย
-- (select count(*) from public.redrops where drop_id = d.id) สำหรับ
-- branch drop -- pops ไม่รองรับ ReDrop เติม null::bigint ไปเลย)

-- fetchFollowingFeed (HomeRepository) ต้องกรองด้วย author_id **หรือ**
-- redropper_id อยู่ใน followingIds -- ไม่งั้น ReDrop ของคนที่ follow อยู่
-- จะไม่โผล่ในแท็บ "ติดตาม" เลยถ้าไม่ได้ follow เจ้าของ Drop เดิมด้วย
-- (ขัดเจตนาหลักของฟีเจอร์ที่ต้องการขยายการมองเห็น) -- ใช้
-- .or('author_id.in.(...),redropper_id.in.(...)') ของ supabase-flutter
-- แทน .inFilter('author_id', ...) เดิม

-- rankingScore()/fetchTrending()/fetchRankedFeed() ไม่ต้องแก้เลย -- ดูข้อ
-- 3 ของภาพรวม

-- redroppedByMe (สำหรับปุ่ม 🔄 toggle state) fetch แบบเดียวกับ
-- likedByMe/savedByMe เดิม: query redrops where redropper_id = auth.uid()
-- and quote_text is null and drop_id in (candidate ids)

-- notifications: เพิ่ม type ใหม่ 'redrop' เข้า CHECK เดิม, reuse
-- drop_id column เดิม (ที่ like_drop/comment_drop ใช้อยู่แล้ว) --
-- actor_id = redropper_id, recipient_id = Drop ต้นทาง's author_id --
-- ไม่แจ้งเตือนถ้า redrop เนื้อหาตัวเอง (มิเรอร์ like/comment เดิมที่ไม่
-- แจ้งเตือนตัวเองเช่นกัน)

-- reports: เพิ่ม 'redrop' เข้า target_type CHECK เดิม + branch ใหม่ใน
-- submit_report() มิเรอร์ 'club_post_comment' branch เป๊ะ:
--   exists (select 1 from public.redrops where id = p_target_id and redropper_id <> v_reporter)
```

**ไม่มี RPC ใหม่** — สร้าง/ลบ ReDrop ใช้ RLS INSERT/DELETE ตรงๆ บน `redrops` (มิเรอร์ `drop_likes`/`saved_drops` เดิมที่ไม่มี RPC เช่นกัน เพราะทุกเงื่อนไข expressible เป็น RLS check ล้วนๆ)

---

## Handoff

AI Coding — เริ่มจาก (1) SQL: `redrops` table+RLS+partial unique index, `home_feed` view 3rd branch (ระวัง UNION ALL column type ให้ตรงทั้ง 3 branch), `notifications`/`reports` CHECK ขยาย + `submit_report()` branch ใหม่ (2) Flutter data layer: `Redrop`-related fields บน `HomeFeedItem`/`Drop` (`redropId`/`redropperId`/`redropperUsername`/`redropperDisplayName`/`redropperAvatarUrl`/`quoteText`/`redropCount`/`redroppedByMe`), `DropRepository`/`HomeRepository` ขยาย fetch+toggle+quote methods, `fetchFollowingFeed`'s `.or()` filter fix (3) ปุ่ม 🔄 + action sheet บน `HomeDropCard`/`DropDetailScreen` (Screen 1) (4) `QuoteRedropScreen` ใหม่ (Screen 2) (5) feed card label widget ใช้ร่วมกันทั้ง Home และ Profile ReDrops tab (Screen 3) (6) `ViewProfileScreen`'s "ReDrops" tab ใหม่ (Screen 4) — ทดสอบ regression ของ WYN-018 ranking/WYN-024 mute/WYN-027 block/WYN-028 mute เดิมทุกจุดว่ายังทำงานปกติ โดยเฉพาะ `rankingScore()`'s output ต้องไม่เปลี่ยนสำหรับแถว drop/pop ที่ไม่เกี่ยว ReDrop เลย
