# Design Spec — WYN-026: User Safety (Block / Mute / Report)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Cyan/Orange color system ปัจจุบันตาม `.wyn/docs/design/ds-001-color-system.md` — ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-026-user-safety-block-mute-report.md` (R1-R6, Acceptance Criteria, Risks)
อ้างอิง Pattern ที่มีอยู่แล้ว: ตาราง/RLS ของ `follows` + self-follow CHECK guard (WYN-008, `.wyn/docs/design/wyn-008-follow.md`), ฟังก์ชัน `club_role()` เป็น single reusable authorization primitive ที่ทุก policy/RPC เรียกใช้ร่วมกัน (WYN-014), pattern "..." more-menu ของ `ClubPostCard._openMoreMenu` (`showModalBottomSheet` + `SafeArea(Wrap(ListTile...))`), pattern "fetch related-table ids แล้ว filter" ของ `DropRepository._fetchFollowedAuthorIds`/`HomeRepository._fetchFollowedAuthorIds`, `saves` table's polymorphic `content_type`/`content_id` shape

## ทิศทางภาพรวม

งานนี้มีสองส่วนที่ต้องแยกความคิดให้ชัดตั้งแต่ต้น เพราะ Product Risk R2 เตือนไว้ตรงๆ ว่า "Mute/Block ปนกันจนทำ effect ผิด":

1. **Block ต้องซ่อนเนื้อหาแบบสมมาตรและกว้าง** (ทั้งสองทิศทาง, ทุกจุดที่ระบบมีอยู่จริง — feed/grid/search/comment/notification/profile) → กลไกหลักคือ **แก้ RLS ของตารางเนื้อหาโดยตรง** ไม่ใช่ filter ฝั่ง client เพราะมีจุด query กระจายอยู่ ~20 จุดใน 6 repository ไฟล์ (ดูรายการทั้งหมดด้านล่าง) การพึ่ง client filter แม้แต่จุดเดียวที่ลืมก็รั่วทันที
2. **Mute ต้องซ่อนเฉพาะ "ฟีด" ของผู้ mute เท่านั้น ทางเดียว** (R4: "ยังเห็น/ติดต่อกันได้ตามปกติในจุดอื่น เช่น comment คนอื่นยังเห็น") → **ห้ามใช้กลไกเดียวกับ Block** (แก้ RLS ของ `drops`/`pops` ตรงๆ จะ over-apply ไปโดน Profile grid/Search/notification ด้วย ซึ่งผิด R4) กลไกที่ถูกต้องคือ filter เฉพาะที่ระดับ "หน้าฟีด" เท่านั้น (view `home_feed` ระดับ SQL + explicit exclude-list ใน repository method เฉพาะ 4 จุดที่เป็นฟีดจริงๆ)

ทั้งสองกลไกอยู่คนละตารางกันเสมอ (`user_blocks` vs `user_mutes`) ไม่มีจุดไหนอ่านสองตารางนี้ปนกันในเงื่อนไขเดียว — นี่คือการป้องกัน R2 ที่ระดับสถาปัตยกรรม ไม่ใช่แค่ตั้งใจไม่ทำผิดตอนเขียนโค้ด

---

## ส่วนที่ 1: Data & Filtering Architecture (ส่วนสำคัญที่สุดของ spec นี้)

### 1.1 ตารางใหม่

#### `user_blocks` — mirror `follows` ทุกประการ (self-relationship guard เดียวกับ WYN-008)

```sql
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id)
);

-- เหตุผลเดียวกับ follows_blocked_id_idx: PK คุ้มครองแค่ (blocker_id, ...) เป็น
-- leading column — is_blocked() ด้านล่างต้องค้นทิศตรงข้าม (blocked_id = X) ด้วย
-- ซึ่ง PK ช่วยไม่ได้ ต้องมี index แยก
create index if not exists user_blocks_blocked_id_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;
```

**RLS — ตั้งใจ "แคบกว่า" `follows` (ซึ่ง select-all-authenticated) เพราะ block list เป็นข้อมูลส่วนตัว:**

```sql
-- เห็นเฉพาะแถวที่ตัวเองเป็นคน block เท่านั้น (ไม่ใช่ทั้งสองฝ่ายเหมือนที่ร่างแรก
-- ของ R1 อาจตีความได้ว่า "blocked_id = auth.uid() ก็เห็นได้" — ตัดสินใจไม่ให้ฝ่าย
-- ที่ถูก block query ตรงเห็นรายชื่อคนที่ block ตัวเอง เพื่อไม่ให้เกิด "ใครบล็อกฉันบ้าง"
-- ซึ่งเป็นข้อมูลที่แพลตฟอร์มส่วนใหญ่ (IG/Twitter) ก็ไม่เปิดเผยตรงๆ เช่นกัน)
create policy "Users can view their own blocks"
  on public.user_blocks
  for select
  to authenticated
  using (auth.uid() = blocker_id);

create policy "Users can block others as themselves"
  on public.user_blocks
  for insert
  to authenticated
  with check (auth.uid() = blocker_id);

-- Unblock: เฉพาะคนที่กด block เท่านั้นที่ยกเลิกได้ (ฝ่ายถูก block ยกเลิกเองไม่ได้)
create policy "Users can remove their own blocks"
  on public.user_blocks
  for delete
  to authenticated
  using (auth.uid() = blocker_id);
```

**ปัญหาที่ต้องแก้ก่อนไปต่อ**: ถ้า `user_blocks` select เห็นได้เฉพาะ `blocker_id = auth.uid()` แล้วเราจะเขียน RLS ของ `drops`/`pops`/ฯลฯ ให้ตรวจ "ทิศตรงข้ามด้วย" (คนที่ถูกฉัน block เห็นเนื้อหาฉันไม่ได้ **และ** คนที่ block ฉันไว้ ฉันก็เห็นเนื้อหาเขาไม่ได้) ได้อย่างไร ในเมื่อ subquery ที่อยู่ใน policy ของตารางอื่นก็ยังต้องผ่าน RLS ของ `user_blocks` เองด้วย (Postgres บังคับ row-security แบบ recursive แม้เป็น subquery ในนิยาม policy ของตารางอื่น) — ถ้าอ่านแถวที่ `blocker_id` เป็นอีกฝ่าย (ไม่ใช่ตัวเอง) subquery จะไม่เห็นแถวนั้นเลยเพราะ policy select ข้างบนกันไว้

**ทางแก้ (mirror `club_role()` pattern ของ WYN-014 — single reusable authorization primitive)**: สร้างฟังก์ชัน `security definer` ที่ bypass RLS ภายในตัวเอง คืนแค่ `boolean` (ไม่คืนข้อมูลแถวจริง) — วิธีนี้ทำให้ทุก policy อื่นในระบบเรียกใช้ได้โดยไม่ต้องเปิด select ของ `user_blocks` ให้กว้างขึ้น:

```sql
create or replace function public.is_blocked(user_a uuid, user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks
    where (blocker_id = user_a and blocked_id = user_b)
       or (blocker_id = user_b and blocked_id = user_a)
  );
$$;
```

`is_blocked(a, b)` เป็นฟังก์ชันเดียวที่ทุก policy ด้านล่างเรียกใช้ — ห้ามให้ query ไหนเขียน subquery ตรงเข้า `user_blocks` เอง (นอกจาก `BlockRepository`/ฟังก์ชันนี้เอง) เพื่อไม่ให้ logic สมมาตรกระจายซ้ำหลายที่แล้วพลาดจุดใดจุดหนึ่ง

#### `user_mutes` — ไม่ต้องมีฟังก์ชันสมมาตรแบบ Block เพราะ Mute เป็นทิศทางเดียวเสมอ

```sql
create table if not exists public.user_mutes (
  muter_id uuid not null references public.profiles (id) on delete cascade,
  muted_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint user_mutes_no_self_mute check (muter_id <> muted_id)
);

alter table public.user_mutes enable row level security;

-- เต็มรูปแบบ "เห็น/แก้ได้เฉพาะแถวของตัวเอง" ตาม R1 ตรงตัว 100% (ไม่มีปัญหาแบบ
-- user_blocks เพราะ mute ไม่เคยต้องเช็คสมมาตร — ทุก query ที่ filter ด้วย mute
-- ล้วนเช็คแค่ "ฉัน mute เขาไหม" ซึ่ง auth.uid() = muter_id ตรงกับ select policy พอดี)
create policy "Users can view their own mutes"
  on public.user_mutes
  for select
  to authenticated
  using (auth.uid() = muter_id);

create policy "Users can mute others as themselves"
  on public.user_mutes
  for insert
  to authenticated
  with check (auth.uid() = muter_id);

create policy "Users can remove their own mutes"
  on public.user_mutes
  for delete
  to authenticated
  using (auth.uid() = muter_id);
```

#### `reports` — ตาม R2 พร้อมแก้ gap หนึ่งจุดในสเปกเดิม

```sql
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  -- R2 ของ Product spec ระบุ enum('drop','user','comment') — ขาด 'pop' ไป
  -- ทั้งที่แอปมีเนื้อหาประเภท Pop เท่าเทียม Drop ทุกประการ (ทั้งคู่ query ผ่าน
  -- home_feed เดียวกัน, ทั้งคู่มี comment, ทั้งคู่ควร report ได้เหมือนกัน) — Design
  -- ตัดสินใจเพิ่ม 'pop' เข้า enum เพื่อไม่ให้ Pop เป็นช่องโหว่ safety ที่ไม่มีทาง
  -- report เลย (ดู Screen 2 ด้านล่าง) เป็นการเติมช่องว่างของสเปก ไม่ใช่เปลี่ยนทิศทาง
  target_type text not null check (target_type in ('drop', 'pop', 'user', 'comment')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now(),
  -- กันสแปม report ซ้ำต่อ target เดียวกัน (Risk R3 ของ Product spec) — ไม่ต้องทำ
  -- rate-limit ซับซ้อนตามที่สเปกบอกไว้ตรงๆ
  constraint reports_no_duplicate unique (reporter_id, target_type, target_id)
);

alter table public.reports enable row level security;

create policy "Users can submit reports as themselves"
  on public.reports
  for insert
  to authenticated
  with check (auth.uid() = reporter_id);

-- ตั้งใจไม่มี select/update policy ให้ client เลยตาม R2 ("select/update สงวนไว้
-- สำหรับ future moderator role") — แม้แต่ reporter เองก็ query ดูรายงานของตัวเอง
-- ย้อนหลังไม่ได้ในรอบนี้ (feedback "ส่งรายงานแล้ว" มาจาก insert สำเร็จตรงๆ ไม่ต้อง
-- select กลับมา) เพิ่ม select/update policy ตอนสร้างหน้า moderator จริงในอนาคต
```

#### `content_not_interested` — เก็บ signal "ไม่สนใจ" (R5) แยกจาก `reports` โดยตั้งใจ

Product spec เปิดให้ Design เลือกระหว่าง "เทียบเคียง `reports`" กับ "ตารางแยกเล็กๆ" — เลือก **ตารางแยก** เพราะ `reports` คือคิวสำหรับ moderator ตรวจสอบเนื้อหาที่มีปัญหา (มี `status`/`reason` ที่มีความหมายเชิง moderation) ส่วน "ไม่สนใจ" คือ **preference ส่วนตัวของผู้ใช้คนเดียว ไม่มีใครต้องมาตรวจสอบ** — คนละโมเดลข้อมูล/RLS กันโดยธรรมชาติ mirror shape ของ `saves` (polymorphic `content_type`/`content_id`) ที่พิสูจน์แล้วในระบบตรงๆ:

```sql
create table if not exists public.content_not_interested (
  user_id uuid not null references public.profiles (id) on delete cascade,
  content_type text not null check (content_type in ('drop', 'pop')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, content_type, content_id)
);

alter table public.content_not_interested enable row level security;

create policy "Users can view their own not-interested signals"
  on public.content_not_interested
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can mark content not interested as themselves"
  on public.content_not_interested
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can remove their own not-interested signals"
  on public.content_not_interested
  for delete
  to authenticated
  using (auth.uid() = user_id);
```

รอบนี้ไม่มี UI ไหนอ่านตารางนี้กลับมา (insert-only จาก UI, ดู Screen 1) — ตรงตาม R5 ที่ระบุชัดว่า "ยังไม่ต้องเชื่อมเข้า ranking algorithm จริง...บันทึกเป็น foundation only" การมี select/delete policy ไว้ล่วงหน้าคือ future-proofing ไม่ใช่ fake functionality (ไม่มีปุ่ม/หน้าจอไหนอ้างว่าทำงานแล้วแต่จริงๆ ไม่ทำงาน)

### 1.2 Auto-unfollow เมื่อ Block (R3, ทั้งสองทิศทาง) — DB trigger ไม่ใช่ client-side call

ตัดสินใจใช้ trigger (ไม่ใช่ให้ `BlockRepository.block()` เรียก `FollowRepository.toggleFollow()` สองครั้งเพิ่มจาก client) ด้วยเหตุผลเดียวกับที่ schema.sql อธิบายไว้แล้วสำหรับ `notifications` trigger ทั้ง 5 ตัว: **"guarantee the side-effect happens every time regardless of which client code path caused it"** — ถ้าอนาคตมีทางเข้าอื่นมา insert `user_blocks` (เช่น admin tool, migration script, retry logic) ก็ยังการันตี auto-unfollow เสมอ ไม่ต้องพึ่งวินัยของทุก caller

```sql
create or replace function public.user_blocks_auto_unfollow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;

create trigger user_blocks_auto_unfollow
  after insert on public.user_blocks
  for each row execute function public.user_blocks_auto_unfollow();
```

และแก้ `follows`' insert policy เดิมให้กันการ follow กันใหม่ระหว่างที่ยัง block กันอยู่ (R3 "ห้าม follow กันได้อีกถ้ายัง block อยู่"):

```sql
-- แทนที่ policy เดิม "Users can follow others as themselves"
create policy "Users can follow others as themselves"
  on public.follows
  for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and not public.is_blocked(follower_id, following_id)
  );
```

### 1.3 Checklist เต็ม: ทุกจุด query เนื้อหาข้าม user ที่มีอยู่จริงในโค้ดปัจจุบัน (Product Risk R1)

ตรวจด้วย `grep` จริงในโค้ด (ไม่ใช่เดาจากความจำ) — พบ query point ที่ query ตาราง/view เนื้อหาข้าม user ทั้งหมด **26 method ใน 8 ไฟล์** แบ่งตามกลไก filter ที่ถูกต้อง:

#### กลุ่ม A — Block filter อัตโนมัติผ่าน RLS (แก้ policy ครั้งเดียว ไม่ต้องแตะ Dart เลย)

แก้ select policy ที่มีอยู่แล้วของตารางเหล่านี้ (เดิมทุกอันเป็น `using (true)` แบบ select-all-authenticated) ให้เพิ่มเงื่อนไข `and not public.is_blocked(<author column>, auth.uid())`:

| ตาราง | Author column ที่เช็ค | Query point ที่ได้ประโยชน์อัตโนมัติ |
|---|---|---|
| `drops` | `author_id` | `DropRepository.fetchFeed`, `fetchByAuthor`, `fetchFollowingFeed`, `fetchRankedFeed`, `fetchById`, `searchByCaption` (6 method) |
| `pops` | `author_id` | `PopRepository.fetchFeed`, `fetchByAuthor`, `searchByCaption`, `fetchById` (4 method) |
| `drop_comments` | `author_id` (ของ comment เอง ไม่ใช่ของ Drop) | `DropRepository.fetchComments` |
| `pop_comments` | `author_id` (ของ comment เอง) | `PopRepository.fetchComments` |
| `notifications` | `actor_id` | `NotificationRepository.fetchNotifications`, `countUnread` (เพิ่มเงื่อนไขต่อจาก `recipient_id = auth.uid()` เดิม) |

ตัวอย่าง policy ที่ต้องแก้ (แทนที่ของเดิม ไม่ใช่เพิ่มใหม่):

```sql
create policy "Drops are viewable by authenticated users"
  on public.drops for select to authenticated
  using (not public.is_blocked(author_id, auth.uid()));

create policy "Pops are viewable by authenticated users"
  on public.pops for select to authenticated
  using (not public.is_blocked(author_id, auth.uid()));

create policy "Drop comments are viewable by authenticated users"
  on public.drop_comments for select to authenticated
  using (not public.is_blocked(author_id, auth.uid()));

create policy "Pop comments are viewable by authenticated users"
  on public.pop_comments for select to authenticated
  using (not public.is_blocked(author_id, auth.uid()));

create policy "Users can view their own notifications"
  on public.notifications for select to authenticated
  using (auth.uid() = recipient_id and not public.is_blocked(actor_id, auth.uid()));
```

**ผลพลอยได้ที่สำคัญที่สุดของกลไกนี้**: `home_feed` และ `saved_feed` (ทั้งคู่ประกาศ `security_invoker = true` แล้วตั้งแต่ WYN-007/WYN-013) เป็น view ที่ query ตาราง `drops`/`pops` ตรงๆ ภายในนิยามของมันเอง — เพราะ `security_invoker = true` ทำให้ RLS ของผู้เรียกจริง (ไม่ใช่เจ้าของ view) มีผลกับทุกตารางที่ view join ด้วย **แก้แค่ policy ของ `drops`/`pops` ที่เดียว ก็ทำให้ `HomeRepository.fetchFeed`, `fetchTrending`, `fetchRankedFeed`, และ `SavedRepository` ที่อ่านผ่านทั้งสอง view นี้ถูก filter block ไปด้วยโดยอัตโนมัติ ไม่ต้องแก้ view SQL หรือ Dart เลยแม้แต่บรรทัดเดียว** — นี่คือเหตุผลหลักที่ต้องเลือกกลไก "แก้ที่ RLS ของตารางต้นทาง" แทนที่จะ filter ทีละจุดใน Dart

#### กลุ่ม B — `profiles` (RLS ใหม่ที่ไม่สมมาตร — ตั้งใจให้ฝ่าย block ยังเห็นฝ่ายที่ถูก block ได้)

ถ้าใช้ `not is_blocked(id, auth.uid())` ตรงๆ กับ `profiles` จะพัง **หน้าจัดการ Block list เอง** (Screen 5 ด้านล่าง) เพราะฝ่ายที่กด block ก็จะมองไม่เห็น profile ของคนที่ตัวเอง block ไปแล้วเช่นกัน (join `profiles!user_blocks_blocked_id_fkey` จะได้ null) จึงต้องเว้นข้อยกเว้นให้ฝ่าย blocker ยังคง query เห็น:

```sql
-- แทนที่ policy เดิม "Profiles are viewable by authenticated users"
create policy "Profiles are viewable unless the viewer is blocked by them"
  on public.profiles for select to authenticated
  using (
    not public.is_blocked(id, auth.uid())
    or exists (
      select 1 from public.user_blocks
      where blocker_id = auth.uid() and blocked_id = profiles.id
    )
  );
```

ผลลัพธ์: X บล็อก Y แล้ว → **Y มองไม่เห็น profile ของ X เลย** (fetchProfile ได้ 0 แถว, หายจาก search) แต่ **X ยังมองเห็น profile ของ Y ได้ตามปกติ** (ไว้จัดการ unblock, ดู avatar/username ในหน้า Block list) — เป็นพฤติกรรมเดียวกับ Instagram/Twitter ที่ Block ทำให้ profile หายไปจากฝั่งที่ถูก block เท่านั้น

Query point ที่ได้ประโยชน์อัตโนมัติจากอันนี้: `ProfileRepository.fetchProfile`, `fetchProfileByUsername`, `searchProfiles` (3 method)

**ผลข้างเคียงที่ต้องแก้โค้ด (ไม่ใช่ RLS อย่างเดียวพอ)**: `FollowRepository.fetchFollowers`/`fetchFollowing` embed `profiles` ผ่าน FK (`follower:profiles!follows_follower_id_fkey(*)`) — เมื่อ RLS ซ่อน profile ของฝ่ายใดฝ่ายหนึ่ง PostgREST จะคืนแถวนั้นมาโดยที่ field embed เป็น `null` แทนที่จะไม่คืนแถวเลย ถ้าไม่ handle จุดนี้ `Profile.fromMap(row['follower'] as Map<String, dynamic>)` จะ crash เพราะ cast `null` เป็น `Map` **ต้องเพิ่มการกรอง row ที่ embed เป็น null ทิ้งใน `FollowRepository.fetchFollowers`/`fetchFollowing` ทั้งสอง method** — เป็น side-effect ที่ต้องแก้ตรงๆ ใน Dart เพราะ RLS แก้ไม่ได้ (มันคือพฤติกรรมของ PostgREST embed ไม่ใช่ RLS)

#### กลุ่ม C — `club_posts` / `club_post_comments` (ส่วนขยายเกิน AC เดิม — แนะนำแต่ไม่บังคับ)

R3/AC ของ Product spec ไม่ได้เอ่ยถึง Club โดยตรง (Club มี role-based visibility ของตัวเองอยู่แล้วจาก WYN-014) แต่สองผู้ใช้ที่ block กันยังอยู่ Club เดียวกันได้ และจะยังเห็นโพสต์ของกันในนั้น — **แนะนำ**ให้เพิ่มเงื่อนไขเดียวกันเพื่อความสม่ำเสมอ (ไม่บังคับตาม literal AC แต่สอดคล้องกับเจตนา "มองไม่เห็นเนื้อหาของกันและกัน" ของ R3):

```sql
-- แทนที่ policy เดิมของ club_posts (เพิ่ม and ท้าย using เดิม)
using (
  public.club_role(club_id, auth.uid()) is not null
  and not public.is_blocked(author_id, auth.uid())
)
```

ทำเดียวกันกับ `club_post_comments`' select policy (เพิ่ม `and not public.is_blocked(author_id, auth.uid())` ต่อจากเงื่อนไข club membership เดิม) — เขียนไว้ตรงนี้เพื่อให้ Coding ทำหรือข้ามอย่างมีข้อมูลครบ ไม่ใช่ลืมเพราะไม่มีใครพูดถึง (ถ้า Product ไม่ต้องการ ให้ตัดข้อนี้ออกจาก scope ตอน Coding ชัดเจน ไม่ใช่ default ไม่ทำแบบเงียบๆ)

#### กลุ่ม D — Mute filter: **ห้ามใช้ RLS ของตารางเนื้อหา** ต้อง filter เฉพาะที่ระดับ "ฟีด" เท่านั้น (โค้ด Dart, per-method)

ตาม R4 มิวต์ต้องไม่กระทบ Profile grid/Search/notification — จึงเลือก 2 กลไกแยกกัน:

**D1. `home_feed` view — แก้ SQL ของ view โดยตรง (auto ครอบคลุมทั้ง 3 method ของ `HomeRepository`)**

เพิ่ม `and not exists (...)` ใน `where`/join condition ของทั้งสองครึ่ง (`drop`/`pop`) ของ `UNION ALL` ใน `home_feed`:

```sql
-- ตัวอย่างครึ่ง drop ของ home_feed (ครึ่ง pop ทำเหมือนกันแค่เปลี่ยน d เป็น p)
from public.drops d
join public.profiles prof on prof.id = d.author_id
where not exists (
  select 1 from public.user_mutes m
  where m.muter_id = auth.uid() and m.muted_id = d.author_id
)
```

เพราะ `home_feed` เป็น `security_invoker = true` อยู่แล้ว `auth.uid()` ในนิยาม view จะ resolve เป็นผู้เรียกจริงเสมอ — ปลอดภัยเขียนตรงในนี้ได้เลย ครอบคลุม `HomeRepository.fetchFeed`, `fetchTrending`, `fetchRankedFeed` ทั้งสามอัตโนมัติเพราะทั้งสามอ่านผ่าน view เดียวกัน

**ห้ามเพิ่มเงื่อนไข mute ใน `saved_feed`** — Saved tab คือ bookmark ที่ผู้ใช้ตั้งใจเก็บเอง ไม่ใช่ "ฟีด" ตามความหมายของ R4 การซ่อนโพสต์ที่ผู้ใช้กด save ไว้เองออกจาก Saved tab เพียงเพราะ mute คนโพสต์ทีหลังจะขัดความคาดหวังผู้ใช้ (ผิดกับ Block ที่ auto-inherit RLS ของ `drops`/`pops` มาแล้วตามกลุ่ม A ซึ่งถูกต้องเพราะ Block ตั้งใจซ่อนทุกที่จริงๆ)

**D2. Query point ที่ query `drops`/`pops` ตรงๆ (ไม่ผ่าน `home_feed`) — ต้องเพิ่ม explicit exclude step ใน Dart แต่ละจุด**

Mirror pattern ที่มีอยู่แล้วในไฟล์เดียวกัน (`DropRepository._fetchFollowedAuthorIds`, `HomeRepository._fetchFollowedAuthorIds`) — fetch เซ็ต id ที่ mute ไว้จาก `user_mutes` (`.eq('muter_id', userId)`) แล้ว exclude ออกจาก query หลักหรือ filter ผลลัพธ์ก่อน return:

| ไฟล์ / Method | เหตุผลที่ต้องแก้ตรงจุด (ไม่ผ่าน home_feed) |
|---|---|
| `DropRepository.fetchFeed` | Drop tab "ล่าสุด" query `drops` ตรง ไม่ผ่าน view |
| `DropRepository.fetchFollowingFeed` | Drop tab "กำลังติดตาม" — exclude เพิ่มจาก `followingIds` ที่ fetch มาแล้ว |
| `DropRepository.fetchRankedFeed` | Drop tab "สำหรับคุณ" — exclude ก่อนคำนวณ ranking score |
| `PopRepository.fetchFeed` | Pop tab feed หลัก (vertical swipe) — query `pops` ตรง |

**ห้ามแก้จุดต่อไปนี้ด้วย mute (คงพฤติกรรมเดิมตาม R4 ตรงตัว):** `fetchByAuthor` (Profile grid ของทุก repository), `searchByCaption` (Search Drop/Pop tab ทุก repository), `fetchById` (เปิดจาก notification/mention/share link), `fetchComments` (comment ทุกจุด), `ProfileRepository.searchProfiles`/`fetchProfile` (mute ไม่ซ่อนตัวตนผู้ใช้ ต่างจาก Block โดยสิ้นเชิง)

**ส่วนขยายที่แนะนำ (ไม่บังคับ เหมือนกลุ่ม C)**: `ClubPostRepository.fetchFromJoinedClubs` (Home's "จาก Club ของคุณ" toggle) ก็เป็น "ฟีด" ในความหมายเดียวกัน — แนะนำ mirror D2's exclude-step ที่นี่ด้วยเพื่อความสม่ำเสมอของประสบการณ์ แต่ไม่ใช่ AC บังคับ

### 1.4 ข้อควรระวังสำหรับ WYN-024 (Drop multi-image, ยังอยู่ backlog — ยังไม่มีโค้ดจริงตอนนี้)

เมื่อ WYN-024 เพิ่มตาราง `drop_images` (child table ของ `drops`) ในอนาคต **ห้าม**เขียน policy ของ `drop_images` ให้เรียก `is_blocked()` ซ้ำเอง — ให้เขียนเป็น `using (exists (select 1 from public.drops d where d.id = drop_images.drop_id))` แทน (subquery กลับไปที่ `drops` ซึ่ง Postgres จะบังคับผ่าน policy ของ `drops` เองอยู่แล้วซึ่งมี block filter ติดมาด้วยตามกลุ่ม A) — วิธีนี้การันตีว่าตารางลูกที่เพิ่มเข้ามาทีหลังไม่มีทาง "ลืม" ใส่ block filter เพราะมันไม่ต้องรู้เรื่อง block เลย แค่พึ่ง parent table เป็น single source of truth

### 1.5 สรุปตารางเปรียบเทียบ Block vs Mute (กันสับสนตอน implement)

| ประเด็น | Block | Mute |
|---|---|---|
| ทิศทาง | สมมาตร (ทั้งสองฝ่ายมองไม่เห็นกัน) | ทางเดียว (เฉพาะฝ่าย mute ไม่เห็นอีกฝ่าย) |
| ผู้ถูกกระทำรู้ตัวไหม | รู้ (follow หลุด, เห็นปุ่ม "เลิกบล็อก" ถ้าเปิดโปรไฟล์ตัวเอง... จริงๆ ไม่รู้ตัวทันทีเพราะ profile หายไปเงียบๆ แต่ผลลัพธ์ปรากฏชัดถ้าสังเกต) | ไม่รู้ตัวเลย (R4 ระบุตรงๆ) |
| กลไก filter | RLS ของตารางเนื้อหาต้นทาง (`drops`/`pops`/`*_comments`/`notifications`/`profiles`) | เฉพาะ view `home_feed` + 4 method ที่เป็น "ฟีด" จริงๆ ใน Dart |
| Comment | ซ่อน (คอมเมนต์ของคนที่ block กันหายไปจริง) | ไม่ซ่อน (เห็นคอมเมนต์ปกติ) |
| Search/Profile grid | ซ่อน | ไม่ซ่อน |
| Notification | ซ่อน | ไม่ซ่อน |
| Follow เดิม | Auto-unfollow ทั้งสองทิศ (DB trigger) | ไม่กระทบ follow เลย |
| Follow ใหม่ | ห้าม follow กันได้อีกระหว่าง block | ยัง follow/unfollow กันได้ปกติ |

---

## ส่วนที่ 2: Screens

### Screen 1 — More Menu บนการ์ด Drop (Home feed / Drop Detail / Search / Hashtag feed)

Purpose: ให้ผู้ใช้ Report หรือกด "ไม่สนใจ" เนื้อหาของคนอื่นได้ตรงจากทุกจุดที่เห็นการ์ด Drop โดยไม่ต้องเปิดโปรไฟล์คนโพสต์ก่อน

User Flow: เห็นการ์ด Drop ของคนอื่น (ไม่ใช่ของตัวเอง) → แตะไอคอน "..." → เปิด bottom sheet → เลือก "รายงาน" (เปิด Screen 3) หรือ "ไม่สนใจ" (ซ่อนการ์ดทันที ไม่มี undo ในรอบนี้)

Components:
- `IconButton(Icons.more_vert)` — reuse ตำแหน่ง/pattern เป๊ะจาก `ClubPostCard`'s header (`_openMoreMenu`): อยู่ท้าย header row เดียวกับ avatar+ชื่อผู้เขียน, แสดง**เฉพาะเมื่อ `authorId != currentUserId`** (คู่ตรงข้ามกับเงื่อนไข delete/pin ของ ClubPostCard ที่โชว์เฉพาะเจ้าของ/moderator — ตรงนี้โชว์เฉพาะที่**ไม่ใช่**เจ้าของ ตาม R6 "โปรไฟล์ตัวเอง...Block/Mute/Report ตัวเองไม่มีความหมาย")
- ต้องเพิ่มใน**ทุกจุดที่มี header การ์ด Drop อยู่แล้วในปัจจุบัน**: `HomeDropCard` (Home feed — ปัจจุบันไม่มีปุ่ม Follow ในการ์ดนี้ด้วยซ้ำ ต้องเพิ่ม `more_vert` ใหม่ทั้งหมด), `DropDetailScreen`'s header row (มีอยู่แล้ว: `[Expanded ชื่อ] [Follow ถ้า !isOwnDrop] [Delete ถ้า isOwnDrop]` — เพิ่ม `more_vert` ต่อจากปุ่ม Follow เมื่อ `!isOwnDrop`, mutually exclusive กับ Delete เหมือนที่ Follow เป็นอยู่แล้ว)
- `showModalBottomSheet` → `SafeArea(child: Wrap(children: [ListTile...]))` — pattern เดียวกับ `ClubPostCard._openMoreMenu`/`ClubPage`'s edit menu เป๊ะ ไม่ประดิษฐ์ UI ใหม่:
  - `ListTile(leading: Icon(Icons.flag_outlined), title: Text('รายงาน'))` → ปิด sheet แล้วเปิด Screen 3 (target_type: 'drop', target_id: drop.id)
  - `ListTile(leading: Icon(Icons.visibility_off_outlined), title: Text('ไม่สนใจ'))` → ปิด sheet, insert `content_not_interested` (content_type: 'drop'), เอาการ์ดออกจาก list ปัจจุบันทันที (optimistic, in-memory removal เท่านั้น ไม่ refetch)

Interactions:
- "ไม่สนใจ": ลบ item ออกจาก `_drops`/feed list ที่แสดงอยู่ **เฉพาะ session ปัจจุบัน** ทันที พร้อม `SnackBar` สั้นๆ "ซ่อนโพสต์นี้แล้ว" — **ห้ามใช้คำที่สื่อว่าระบบจะแนะนำโพสต์แบบนี้น้อยลงในอนาคต** (เช่น "จะเห็นโพสต์แบบนี้น้อยลง") เพราะยังไม่เชื่อมเข้า ranking จริงตาม R5 — ข้อความต้องตรงกับสิ่งที่เกิดขึ้นจริงเท่านั้น (ซ่อนแค่ใบนี้ ตอนนี้)
- ถ้า insert `content_not_interested` fail (เช่น network) → การ์ดที่ลบไปแล้วไม่ต้อง revert กลับ (เหมือน pattern silent-fail ของ load-more ใน `FollowListScreen`) เพราะผลลัพธ์ที่ผู้ใช้เห็น (การ์ดหาย) ไม่ผูกกับความสำเร็จของ insert โดยตรงในทางที่ทำให้ user สับสนถ้า revert
- "รายงาน": ปิด sheet ปัจจุบันก่อนเปิด Screen 3 (ไม่ nest sheet ซ้อน sheet)

States: ไม่มี loading state ระดับ sheet เอง (การ insert เป็น fire-and-forget สำหรับ "ไม่สนใจ" เหมือน Like/Save toggle อื่นๆ ในแอป)

Accessibility: `IconButton` more_vert มี `tooltip: 'ตัวเลือกเพิ่มเติม'`, ListTile ทั้งสองมี label ชัดเจนจาก `title` อยู่แล้ว (มาตรฐาน Flutter ListTile semantics)

Design Rules: ห้าม custom sheet styling ใหม่ — ใช้ default `showModalBottomSheet`/`SafeArea`/`Wrap`/`ListTile` เหมือน `ClubPostCard`/`ClubPage` ทุกประการ (ความสม่ำเสมอ ไม่ใช่ reinvent)

---

### Screen 2 — More Menu บน Pop clip (ส่วนขยายเกิน literal R5 — ดูเหตุผลด้านล่าง)

**หมายเหตุสำคัญ**: R5 ของ Product spec เขียนถึงแค่ "การ์ด Drop" ไม่ได้เอ่ยถึง Pop ตรงๆ — Design ตัดสินใจใส่ More Menu เดียวกันให้ Pop ด้วยเพราะ (1) Pop เป็นเนื้อหาสาธารณะเท่าเทียม Drop ทุกประการ (query ผ่าน `home_feed` เดียวกัน, มี comment เหมือนกัน) การเว้น Pop ไว้ไม่มี Report/Not Interested เลยจะเป็นช่องโหว่ safety ที่ขัดกับ WYN Vision ("ให้ความสำคัญกับความปลอดภัยมากกว่าแพลตฟอร์มเดิม") อย่างชัดเจน (2) ต้นทุนต่ำมาก เพราะเป็นการ mirror UI pattern เดียวกับ Screen 1 เป๊ะ ไม่มีอะไรใหม่ (3) schema `reports.target_type` ต้องมี `'pop'` อยู่แล้วไม่ว่าจะทำ UI รอบนี้หรือไม่ (ดู 1.1) — **ถ้า Founder/Product ไม่ต้องการให้ Pop มี More Menu รอบนี้ ให้ตัด Screen 2 ออกจาก scope ตอน Coding ได้ทันที ไม่กระทบ Screen 1/3/4/5**

Purpose: เหมือน Screen 1 แต่สำหรับ Pop clip (`PopClipView`)

Components:
- `IconButton(Icons.more_vert, color: Colors.white)` — วางในตำแหน่งเดียวกับปุ่ม Follow/Delete ที่มีอยู่แล้วในแถว header ของ `PopClipView` (`[Flexible ชื่อ] [Follow ถ้า !isOwnPop] [Delete ถ้า isOwnPop]`) — เพิ่มต่อจากปุ่ม Follow เมื่อ `!isOwnPop`, สี `Colors.white` ให้ตรงกับปุ่มอื่นบน scrim มืดเหมือนเดิม (ไม่ใช่สี Primary เหมือน Screen 1 ที่อยู่บนพื้นขาว — เหตุผลเดียวกับที่ WYN-008 อธิบายไว้แล้วสำหรับปุ่ม Follow: "ต่างกันได้แค่สี ให้เข้ากับพื้นหลังมืด/สว่างของแต่ละบริบท")
- `showModalBottomSheet` เนื้อหาเดียวกับ Screen 1 ทุกประการ (Report/ไม่สนใจ) แค่ `target_type: 'pop'`

Interactions: เหมือน Screen 1 — "ไม่สนใจ" ลบ clip ออกจาก `PageView` ปัจจุบันในหน่วยความจำ (ไม่ refetch)

Accessibility: เหมือน Screen 1

Design Rules: ห้ามเปลี่ยน sheet styling ให้ต่างจาก Screen 1 (สอง entry point ต้องรู้สึกเป็นเมนูเดียวกัน เหมือนปุ่ม Follow ที่ WYN-008 ตั้งกฎไว้ว่า "ต้องมีสไตล์เดียวกันทุกที่ที่ปรากฏ")

---

### Screen 3 — Report Sheet (shared component, ใช้ร่วมทั้ง Drop/Pop/Profile)

Purpose: ให้ผู้ใช้เลือกเหตุผล report แล้วส่งเข้า `reports` จริง พร้อม feedback ว่าสำเร็จ

User Flow: เปิดจาก Screen 1/2/4 (more menu → "รายงาน") → เห็นรายการเหตุผลแบบเลือกได้ → เลือก 1 อย่าง → กดยืนยัน → ปิด sheet พร้อม SnackBar ยืนยัน

Components:
- `showModalBottomSheet` ใหม่ (`SafeArea` + คงรูปแบบ list เดียวกับ sheet อื่น) แสดงหัวข้อ "ทำไมถึงรายงานโพสต์นี้" (หรือ "รายงานผู้ใช้นี้" ถ้าเปิดจาก Screen 4) ตามด้วยรายการ `RadioListTile`/`ListTile` เหตุผลคงที่ (เก็บเป็น `const List` ใน widget เดียว ใช้ร่วมทุก target_type เพราะ generic พอ ไม่ต้องแยกชุดคำถามตาม type):
  - "สแปมหรือโฆษณา"
  - "คุกคามหรือกลั่นแกล้ง"
  - "เนื้อหาไม่เหมาะสม"
  - "ข้อมูลเท็จ"
  - "อื่นๆ"
- ปุ่ม "ส่งรายงาน" (`Primary Button`, disabled จนกว่าจะเลือกเหตุผลอย่างน้อยหนึ่งอย่าง)

Interactions:
- กดส่ง → insert `reports` (`reporter_id` = ตัวเอง auto, `target_type`/`target_id` มาจาก parameter, `reason` = label ภาษาไทยที่เลือกตรงๆ — ไม่ต้อง mapping เป็น enum แยกเพราะ column เป็น `text` ธรรมดา)
- สำเร็จ → ปิด sheet, `SnackBar` "ส่งรายงานแล้ว ขอบคุณที่ช่วยดูแลความปลอดภัยของ WYN" (ของจริง ตรงตาม AC "ของจริง ไม่ fake")
- ชนกับ `reports_no_duplicate` (report target เดิมซ้ำ) → catch unique-violation error โดยเฉพาะ (ไม่ใช่ catch-all) แสดง `SnackBar` แยกต่างหาก "คุณเคยรายงานเรื่องนี้ไปแล้ว" (ไม่ใช่ error message ทั่วไปที่ทำให้ดูเหมือนระบบพัง)
- error อื่นๆ (network ฯลฯ) → `SnackBar` "ส่งรายงานไม่สำเร็จ ลองใหม่อีกครั้ง" ปกติ

States: ปุ่มส่งมี loading spinner ระหว่างรอ (`ElevatedButton` + `CircularProgressIndicator` ขนาดเล็กแทน label เดิม — pattern เดียวกับปุ่ม submit ที่มีอยู่แล้วในแอป เช่น `CreateDropScreen`/`CreatePopScreen`)

Accessibility: แต่ละ `RadioListTile` ประกาศ label เหตุผลผ่าน `title` เดิมอยู่แล้ว (มาตรฐาน)

Design Rules: sheet นี้เป็น component เดียวใช้ร่วมทุก target_type (`drop`/`pop`/`user`) — รับ parameter `targetType`/`targetId` ไม่ hardcode วรรค content ต่าง type

---

### Screen 4 — More Menu บน `ViewProfileScreen` (โปรไฟล์คนอื่น)

Purpose: จุดรวมของ Block/Mute/Report ต่อผู้ใช้ทั้งคน (ต่างจาก Screen 1/2 ที่ report ต่อ "โพสต์")

User Flow: เปิดโปรไฟล์คนอื่น → แตะไอคอน "..." ใน AppBar → เปิด sheet → เลือก Block/Mute/Report

Components:
- `ViewProfileScreen`'s `AppBar.actions` ปัจจุบันมีแค่ `IconButton(Icons.logout)` เมื่อ `isOwnProfile` — เพิ่ม `IconButton(Icons.more_vert)` เมื่อ **`!isOwnProfile`** (คนละเงื่อนไข ไม่ชนกัน เพราะ logout กับ more-menu ไม่มีทางแสดงพร้อมกัน อยู่แล้วตามธรรมชาติของ `isOwnProfile`)
- ต้อง load สถานะ `isBlocked`/`isMuted` ตอนเปิดโปรไฟล์ (เหมือน `_loadFollowStatus` ที่มีอยู่แล้ว) — **ห้าม default เป็น false เสมอ** เหตุผลเดียวกับที่ WYN-008 เคยแก้ปัญหานี้มาแล้วกับปุ่ม Follow ("ไม่ default เป็น 'ติดตาม' เสมอ...ต้องรู้สถานะจริงจาก DB ก่อนแสดงปุ่ม") — sheet ซ่อนไว้จนกว่าทั้งสองสถานะโหลดเสร็จ (แสดง sheet ได้ก่อน แต่ ListTile ของ Block/Mute ต้อง disable/แสดง placeholder จนกว่าจะรู้สถานะจริง ไม่ใช่โชว์ "บล็อก" เดาไปก่อนแล้วสลับทีหลัง)
- `showModalBottomSheet` (pattern เดียวกับ Screen 1/2):
  - `ListTile(leading: Icon(isBlocked ? Icons.person_off : Icons.block), title: Text(isBlocked ? 'เลิกบล็อก' : 'บล็อก'))`
  - `ListTile(leading: Icon(isMuted ? Icons.visibility : Icons.visibility_off_outlined), title: Text(isMuted ? 'เลิกซ่อนจากฟีด' : 'ซ่อนโพสต์จากฟีด'))` — **ตั้งใจไม่ใช้คำว่า "Mute" ในข้อความ UI** เพื่อไม่ให้สับสนกับปุ่มปิดเสียงคลิป Pop ที่มีอยู่แล้ว (`Icons.volume_off`, ข้อความ "ปิดเสียงอยู่ กดเพื่อเปิดเสียง") ซึ่งเป็นคนละแนวคิดกันโดยสิ้นเชิง — เอกสารนี้อ้างอิงถึงฟีเจอร์นี้ว่า "Mute" เฉพาะตอนคุยกับทีม dev เท่านั้น
  - `ListTile(leading: Icon(Icons.flag_outlined), title: Text('รายงาน'))` → เปิด Screen 3 (target_type: 'user', target_id: profile.id)

Interactions:
- แตะ "บล็อก" → เปิด confirm dialog ใหม่ (component ใหม่ `core/widgets/confirm_block_dialog.dart` มิเรอร์รูปแบบ `confirmDeletePost` ที่มีอยู่แล้ว) ข้อความ: **"บล็อก {ชื่อ}? {ชื่อ} จะมองไม่เห็นเนื้อหาของคุณ และคุณจะมองไม่เห็นเนื้อหาของ {ชื่อ} เช่นกัน ถ้าติดตามกันอยู่ ระบบจะเลิกติดตามให้อัตโนมัติ"** — ต้อง confirm ก่อนเสมอ (ต่างจาก Mute ที่ไม่ต้อง confirm) เพราะ Block มีผลข้างเคียงที่มองเห็นได้ชัดกว่า (auto-unfollow, ทั้งสองทิศ) และเป็น action ที่ผู้ใช้ควรตั้งใจกดจริงๆ
- ยืนยันแล้ว → insert `user_blocks` → sheet ปิด, `_reload()` โปรไฟล์ (Drop/Pop grid tab จะกลายเป็นว่างเปล่าเองอัตโนมัติผ่าน RLS ทันที ไม่ต้องมี logic พิเศษฝั่ง client เพิ่ม)
- แตะ "เลิกบล็อก" → delete `user_blocks` ตรงๆ **ไม่ต้อง confirm dialog** (unblock เป็น action ที่ปลอดภัยกว่า กด block ซ้ำได้ตลอดถ้าเปลี่ยนใจ ไม่จำเป็นต้องมี friction)
- แตะ "ซ่อนโพสต์จากฟีด"/"เลิกซ่อนจากฟีด" → toggle `user_mutes` ตรงๆ ไม่ต้อง confirm (Mute ผู้ถูกกระทำไม่รู้ตัวอยู่แล้ว ความเสี่ยงต่ำกว่า Block มาก)

States: เหมือน Follow button pattern เดิม (`bool?` null = กำลังโหลด/ซ่อน action ไว้ก่อน)

Accessibility: Semantics label ของแต่ละ ListTile ประกาศสถานะปัจจุบันเสมอ (เช่น "บล็อกอยู่ กดเพื่อเลิกบล็อก") ตาม pattern เดียวกับปุ่ม Follow ที่ WYN-008 วางไว้เป็นมาตรฐานทั้งแอป

Design Rules: ห้ามลบปุ่ม Follow เดิมออกจากหน้านี้เมื่อยัง follow กันอยู่ก่อนกด Block — ปุ่ม Follow จะหายไปเองตามธรรมชาติหลัง `_reload()` เพราะ `isFollowing` จะกลายเป็น false จริงจาก DB (auto-unfollow trigger ทำงานแล้ว) ไม่ต้องมี special-case ซ่อนปุ่ม Follow ด้วยมือ

---

### Screen 5 — หน้าจัดการ Block list / Mute list (`SafetyListScreen`, หน้าใหม่)

**ตำแหน่งที่เลือก**: entry point ใหม่ในหน้าโปรไฟล์ตัวเอง (`ViewProfileScreen`'s `AppBar.actions`, ข้างปุ่ม logout เดิม เมื่อ `isOwnProfile`) — **ไม่สร้างหน้า Settings แยกใหม่** เหตุผล: (1) แอปยังไม่มีโครงสร้าง Settings เลยสักหน้า (`grep "Settings"` ในโค้ดไม่เจอเลย) การสร้าง Settings hub ใหม่ทั้งหน้าเพื่อใส่ entry point เดียวเป็นการเพิ่ม scope เกินกว่าที่ Product ขอ (ขัดกับกติกา "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น") (2) `ViewProfileScreen`'s AppBar เป็นที่ที่ผู้ใช้เจอ action ระดับบัญชีอยู่แล้ว (logout) — Block/Mute list เป็น action ระดับบัญชีเหมือนกัน อยู่ที่เดิมได้เลยตามธรรมชาติ (3) เมื่อแอปมีหน้า Settings จริงในอนาคต ย้าย entry point (แค่ `IconButton.onPressed`) มาไว้ใต้ Settings ได้โดยไม่ต้องแก้ `SafetyListScreen` เองแม้แต่บรรทัดเดียว

Purpose: ให้ผู้ใช้ดูรายชื่อที่ตัวเอง block/mute ไว้ และ unblock/unmute ได้ (AC: "Unblock/Unmute ทำได้จากรายการที่จัดการได้")

User Flow: `ViewProfileScreen` (ของตัวเอง) → แตะไอคอน (เช่น `Icons.shield_outlined`, tooltip "บัญชีที่บล็อก/ซ่อนไว้") → เปิด `SafetyListScreen` → สลับ tab "บล็อกอยู่" / "ซ่อนจากฟีดอยู่" → แตะ "เลิกบล็อก"/"เลิกซ่อน" ที่แถวใดก็ได้ทันที

Components: **reuse โครงสร้างของ `FollowListScreen` เกือบทั้งหมด** (`enum SafetyListMode { blocked, muted }` พารามิเตอร์เดียวแทนที่จะแยกไฟล์ — mirror `FollowListMode` เป๊ะ):
- `AppBar` title แยกตามโหมด: "บัญชีที่บล็อก" / "โพสต์ที่ซ่อนจากฟีด"
- ใช้ `TabBar` 2 แท็บด้านบนแทนการเปิดแยกหน้า (ต่างจาก Followers/Following ของ WYN-008 ที่เป็นสองปุ่มแยกจาก`ViewProfileScreen`) เพราะ Block/Mute list ทั้งคู่มาจาก entry point เดียวกัน (ไอคอนเดียว) ไม่มีตัวเลขนำทางแยกสองจุดแบบ Follower/Following count — สลับ tab ในหน้าเดียวคือ UX ที่เป็นธรรมชาติกว่า
- แต่ละแถว: `AvatarCircle` + display name + `@username` (โครงสร้างเดียวกับ `FollowListScreen`) **แต่ต่างจาก `FollowListScreen` สองจุด**:
  1. แถว**แตะได้จริง** เปิดโปรไฟล์เจ้าของ (ต่างจาก WYN-008 เดิมที่ตอนนั้นไม่มีปลายทางให้ไป — ตอนนี้ `ViewProfileScreen` มีอยู่แล้วและมีประโยชน์จริงที่จะดูก่อน unblock)
  2. มี `TextButton` ท้ายแถว "เลิกบล็อก"/"เลิกซ่อน" แยกเป็น tap target ของตัวเอง (ไม่ต้องเปิดโปรไฟล์แล้วเปิด more-menu อีกชั้นเพื่อ unblock — friction ต้องต่ำสำหรับ action ป้องกันตัวเอง)
- Empty state: "บล็อกอยู่" ว่าง → "คุณยังไม่ได้บล็อกใครเลย" / "ซ่อนจากฟีดอยู่" ว่าง → "คุณยังไม่ได้ซ่อนโพสต์ของใครจากฟีดเลย"
- Loading/Error/Infinite scroll: pattern เดียวกับ `FollowListScreen` ทุกประการ (spinner กลางจอ / ข้อความ+ปุ่มลองใหม่ / `pageSize` เดียวกัน)

Interactions:
- แตะ "เลิกบล็อก"/"เลิกซ่อน" → delete แถวออกจาก `user_blocks`/`user_mutes` ตรงๆ ทันที **ไม่ต้อง confirm dialog** (เหตุผลเดียวกับ Screen 4: unblock/unmute เป็น action แก้ไขได้ ไม่ทำลาย) → เอา item ออกจาก list ทันที optimistic (revert กลับถ้า fail เหมือน pattern toggle อื่นๆ ในแอป)

States: เหมือน `FollowListScreen`

Accessibility: แถวมี Semantics label รวม (ชื่อ+username) **บวก**ปุ่ม unblock/unmute แยกมี label ของตัวเอง ("เลิกบล็อก {ชื่อ}") ไม่รวมเข้ากับ label ของทั้งแถว — สอง affordance ต้องแยกจากกันชัดเจนสำหรับ screen reader (ต่างจาก `FollowListScreen` เดิมที่ทั้งแถวมี affordance เดียว)

Responsive Behavior: มือถือคอลัมน์เดียวเหมือนทุกหน้า list ในแอป

Design Rules: ห้าม reuse โค้ดแบบ copy-paste ทั้งไฟล์จาก `FollowListScreen` — ให้พิจารณา extract ส่วนที่ต่างกันจริง (tappable row + trailing action button) เป็น shared row widget ถ้า Coding เห็นว่าคุ้ม แต่ไม่บังคับ (ไม่ใช่ประเด็น design ตัดสินใจแทน Coding เรื่อง code structure ระดับนี้)

---

## Handoff รวม

ส่งต่อ AI Coding (`/code`) พร้อม checklist ในส่วนที่ 1.3 เป็นแหล่งอ้างอิงบังคับ (ไม่ใช่ optional) — ก่อนส่ง QA ต้องยืนยันด้วยตัวเองว่า:

1. Policy ของ `drops`/`pops`/`drop_comments`/`pop_comments`/`notifications`/`profiles`/`follows` (insert) ถูกแทนที่ตามที่ระบุใน 1.1/1.3 ครบทุกตาราง (ไม่ใช่แค่เพิ่มตารางใหม่ 4 ตัวเฉยๆ)
2. `home_feed` view SQL มีเงื่อนไข mute เพิ่มในทั้งสองครึ่งของ `UNION ALL`
3. `FollowRepository.fetchFollowers`/`fetchFollowing` กรอง row ที่ embedded profile เป็น null ทิ้ง (ผลข้างเคียงของ Screen 4/กลุ่ม B ที่ต้องแก้ตรงๆ)
4. `DropRepository.fetchFeed`/`fetchFollowingFeed`/`fetchRankedFeed` และ `PopRepository.fetchFeed` มี exclude-muted-authors step เพิ่ม (กลุ่ม D2) — และ**ยืนยันว่า `fetchByAuthor`/`searchByCaption`/`fetchById`/`fetchComments` ของทั้งสอง repository ไม่ถูกแตะเรื่อง mute เลย** (กันพลาดแบบ R2)
5. กลุ่ม C (club_posts/club_post_comments) และ Screen 2 (Pop more-menu) เป็นส่วนขยายที่ Coding เลือกทำหรือแจ้งตัดออกจาก scope ได้ตรงๆ ไม่ใช่ default ทำแบบไม่ได้บันทึกไว้

QA ต้องทดสอบ RLS จริงกับ Postgres แยกทุกจุดในตารางกลุ่ม A/B/C ของ 1.3 (ไม่เชื่อแค่จุดเดียวตามที่ Risk R1 ของ Product spec เตือนไว้) โดยเฉพาะเคส "บล็อกแล้ว unblock — เนื้อหากลับมาเห็นได้ปกติ" และเคส "mute drop tab ล่าสุด แต่ยังเห็นใน Search/Profile grid ของคนที่ mute ไว้" (พิสูจน์ mute ไม่ over-apply แบบ R2)
