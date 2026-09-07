# AI Design — WYN-130: Club Invite Link (expire/max-uses/revoke)

Owner: AI Design
ต่อยอดจาก Product Task `.wyn/tasks/active/WYN-130-club-invite-link.md`

WYN design system ที่อนุมัติแล้ว: reuse component เดิมทั้งหมด (`ActionSheetRow`, confirm-dialog pattern ของ `confirmDeletePost`/`confirmBlock`, list-row shape ของ `FollowListScreen`/`ClubMembersTab`) — ไม่มีทิศทาง visual ใหม่

## ✅ Founder ตัดสินใจแล้ว (2026-09-07) — Private Club + Invite Link = ทางเลือก A

**Founder เลือกทางเลือก A**: กดลิงก์เชิญที่ valid สำหรับ Private Club → **join ทันที ข้าม Join Request/Approve เลย** — บันทึกไว้ใน `.wyn/company/DECISIONS.md` (2026-09-07) แล้ว RPC 4 ด้านล่าง lock เป็นทางเลือก A เรียบร้อย พร้อมส่ง AI Coding

เนื้อหาด้านล่างเก็บ trade-off ทั้งสองทางไว้เป็น record ประกอบการตัดสินใจ (ไม่ใช่คำถามที่ยังค้างอยู่แล้ว)

**บริบทที่ตรวจสอบจากโค้ดจริง**: ปัจจุบัน `club_members` INSERT policy (WYN-014) กำหนดตายตัวว่า Private club → insert ได้แค่ `status = 'pending'` เท่านั้น (ต้องรอ `approve_club_member()` โดย Owner/Admin เสมอ) — ไม่มีทางเลี่ยงเลยแม้แต่ทางเดียวในโค้ดปัจจุบัน คำถามคือ **invite link ควรเป็นข้อยกเว้นของกฎนี้หรือไม่**

### ทางเลือก A — Invite Link = อนุมัติล่วงหน้าในตัว (join ทันที ข้าม pending แม้เป็น Private Club)

- Pattern เดียวกับ Discord invite link ทุกประการ — ตรงกับที่ Product Task แนะนำไว้
- ข้อดี: growth loop ลื่นที่สุด คนกดลิงก์แล้วเข้าได้เลยไม่ต้องรอ Owner มาอนุมัติทีละคน (Owner สร้างลิงก์ = อนุมัติทุกคนที่ถือลิงก์นี้ไว้ล่วงหน้าแล้วในตัว) เหมาะกับ use case ที่ Product ระบุไว้ตรงๆ (แปะ bio, กลุ่มเพื่อนสนิท)
- ข้อเสีย/ความเสี่ยง (ตรงกับที่ AI PM เตือนไว้แล้วใน Risks): เปลี่ยน security semantics ของคำว่า "Private" — เดิม Private = "ต้องผ่านการอนุมัติของ Owner/Admin ทุกคน ไม่มีข้อยกเว้น" กลายเป็น "Private ที่มีลิงก์เชิญหลุดออกไป = ใครก็เข้าได้ทันที" ถ้าลิงก์ถูก re-share/หลุดไปที่สาธารณะ (screenshot, forward ต่อ, โพสต์ผิดที่) คนแปลกหน้าเข้าได้ทันทีโดย Owner ไม่ทันรู้ตัว จนกว่าจะสังเกตเห็นแล้วกด revoke เอง — ไม่มีกลไก "ขออนุมัติย้อนหลัง"/เตะออกอัตโนมัติถ้าพบว่าลิงก์หลุด
- บรรเทาความเสี่ยงได้บางส่วนด้วย: คำเตือนชัดเจนตอนสร้างลิงก์ ("ใครก็ตามที่มีลิงก์นี้เข้าร่วมได้ทันที"), revoke ทำได้ทันที, Owner/Admin ยังคง kick/ban สมาชิกที่เข้ามาแบบนี้ทีหลังได้เหมือนสมาชิกทั่วไปทุกประการ (ไม่ได้เสียอำนาจควบคุมถาวร)

### ทางเลือก B — Invite Link = ทางลัดการค้นพบ/สมัครเท่านั้น (ยังคงต้องผ่าน Join Request/Approve เหมือนเดิมสำหรับ Private Club)

- Invite link ทำหน้าที่แค่: (1) พาไปหน้า preview ของ Club ได้ตรงๆ แม้ยังไม่เคย follow/รู้จักใครในนั้น (แก้ปัญหาหลักที่ Problem ระบุไว้: "คนที่ยังไม่ follow เรา/ยังไม่ได้ใช้ WYN เข้าไม่ถึง") (2) เมื่อกด "เข้าร่วม" จาก preview นี้ → สร้างแถว `club_members` แบบ `status = 'pending'` เหมือนการ join จากหน้า Club ปกติทุกประการ ไม่ auto-approve — **Owner ยังต้องกด "อนุมัติ" เองเหมือนเดิม** เพียงแต่ตอนนี้มี **ข้อมูลเพิ่ม** ในคิวอนุมัติว่า "คนนี้มาจากลิงก์ไหน" (ใช้ `club_invite_link_uses` ที่เก็บไว้อยู่แล้วช่วย Owner ตัดสินใจไวขึ้นว่าเชื่อถือได้แค่ไหน)
- ข้อดี: **ไม่เปลี่ยน security semantics ของ "Private" เลยแม้แต่นิดเดียว** — Owner ยังคุมทุกคนที่เข้า Private club 100% เหมือนวันแรก ไม่มีความเสี่ยงใหม่จากลิงก์หลุด (ลิงก์หลุดไปก็แค่มีคนขอเข้าเยอะขึ้น ไม่ใช่มีคนเข้าไปแล้วโดยไม่รู้ตัว)
- ข้อเสีย: Growth loop ช้ากว่า/friction สูงกว่า Discord — ไม่ตรงกับ mental model "invite link = เข้าได้เลย" ที่คนคุ้นเคยจาก Discord/Telegram ส่วนใหญ่ ผู้ใช้อาจงงว่า "ทำไมกดลิงก์แล้วยังต้องรออนุมัติอีก" ทำให้ value ของฟีเจอร์นี้ลดลงมากสำหรับ Private Club โดยเฉพาะ (ยังมีประโยชน์เต็มที่สำหรับ Public Club อยู่ดี เพราะ Public join ทันทีอยู่แล้วโดยไม่เกี่ยวกับทางเลือกนี้เลย)

### AI Design ตัดสินใจเองไม่ได้เพราะ

นี่คือ trade-off ระหว่าง growth/UX กับ security/control ของ Owner โดยตรง ไม่มีคำตอบที่ "ถูกทางเทคนิค" — เป็นเรื่องที่ RULES.md ระบุชัดว่าต้อง Founder ตัดสินใจ (การเปลี่ยนแปลงที่กระทบ "สถาปัตยกรรมความปลอดภัย"/policy ระดับนี้) **AI Design ไม่มี tool ยิง popup คำถามแบบเลือกตอบ (AskUserQuestion) ในสภาพแวดล้อมนี้ จึงเขียนคำถามนี้ไว้ชัดเจนในเอกสารแทน และแจ้ง Founder ตรงๆ ในสรุปงานท้าย session** ตาม RULES.md ข้อ "ถ้าไม่มี tool ให้เขียนเป็นคำถามชัดเจนในเอกสารและแจ้ง Founder"

**คำถามที่ต้องการคำตอบ**: เลือก **A** (join ทันทีแม้ Private) หรือ **B** (ยังต้องขออนุมัติเหมือนเดิมแม้มาจากลิงก์)?

Public Club ไม่มีคำถามนี้เลย — join ทันทีอยู่แล้วทั้งสองทางเลือก (Public เดิมก็ join ทันทีไม่ผ่าน approve อยู่แล้วตั้งแต่ WYN-014) ผลของคำถามนี้กระทบ **เฉพาะ Private Club** เท่านั้น

Schema ด้านล่างเขียนไว้ให้รองรับทั้งสองทาง (comment กำกับจุดที่ต่างกันไว้ชัดเจน) — AI Coding รอคำตอบก่อนเลือก branch ที่จะ implement จริง ไม่ implement ทั้งสองทางพร้อมกัน

## โครงสร้างที่ตรวจสอบจากโค้ดจริงแล้ว

- `public.clubs`: `privacy` ('public'/'private'), `owner_id`
- `public.club_members`: `role` (owner/admin/moderator/member), `status` (pending/approved/banned), primary key `(club_id, user_id)`
- `public.club_role(club_id, user_id)`: authorization primitive มาตรฐานของทุก Club RPC — reuse สำหรับเช็คสิทธิ์ owner/admin ตอนสร้าง/revoke ลิงก์
- `club_members` INSERT policy (WYN-014): client เขียนตรงได้เฉพาะ `status='approved'` คู่กับ `privacy='public'` หรือ `status='pending'` คู่กับ `privacy='private'` เท่านั้น — **RPC ใหม่ที่เขียนในงานนี้เป็น security definer จึง bypass policy นี้ได้ทั้งสองทาง (A/B) โดยไม่ต้องแก้ policy เดิมเลย** (เหมือนที่ `get_or_create_conversation()`/`approve_club_member()` bypass RLS ปกติของตารางที่ตัวเองเขียนอยู่แล้ว)
- Deep linking (WYN-119): `DeepLinkService` map `Uri.base.path` เป็นปลายทางอยู่แล้ว 5 แบบ (`/club/:id`, `/drop/:id`, `/pop/:id`, `/@:username`, `/club-post/:id`) รองรับ guest ผ่าน Anonymous Sign-In (WYN-072) แล้วด้วย — **งานนี้เพิ่ม pattern ที่ 6**: `/club-invite/:code`
- `guest_gate.dart`'s `requireRealAccount()`: ใช้ทั่วแอปเพื่อกัน anonymous user ทำ action จริง (join/like/comment) — reuse ตรงๆ สำหรับปุ่ม "เข้าร่วม" ในหน้า preview ของลิงก์เชิญ ไม่ต้องสร้างกลไกใหม่

## Schema / Data Model

```sql
create table if not exists public.club_invite_links (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  code text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz,
  max_uses integer,
  use_count integer not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint club_invite_links_max_uses_positive check (max_uses is null or max_uses > 0)
);

create unique index if not exists club_invite_links_code_idx on public.club_invite_links (code);
create index if not exists club_invite_links_club_id_idx on public.club_invite_links (club_id, created_at desc);

alter table public.club_invite_links enable row level security;

create policy "Owners/admins can view their club's invite links"
  on public.club_invite_links
  for select
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- ไม่มี insert/update/delete policy ให้ client -- RPC ด้านล่างเท่านั้น
-- (เหมือน club_members ทุกจุด)

-- Requirement: "Track ว่าสมาชิกใหม่แต่ละคน join ผ่านลิงก์ไหน" -- เก็บ
-- data ไว้เฉยๆ ยังไม่ต้องมี UI แสดงผลรอบนี้ (Owner Insights ในอนาคต)
create table if not exists public.club_invite_link_uses (
  link_id uuid not null references public.club_invite_links (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  used_at timestamptz not null default now(),
  primary key (link_id, user_id)
);
-- ไม่มี SELECT policy เลยในรอบนี้ตามที่ Requirement บอกว่าไม่บังคับ UI --
-- เขียนได้ทางเดียวผ่าน redeem_club_invite_link() (security definer)
-- อ่านทีหลังผ่าน RPC ใหม่เมื่อ Owner Insights ต้องการจริง (ไม่ scope รอบนี้)
alter table public.club_invite_link_uses enable row level security;
```

### RPC 1 — สร้างลิงก์เชิญ (Owner/Admin เท่านั้น)

```sql
create or replace function public.create_club_invite_link(
  p_club_id uuid,
  p_expires_in_days integer default null, -- null = ไม่มีวันหมดอายุ; ค่าที่ UI ให้เลือก: null/1/7/30
  p_max_uses integer default null          -- null = ไม่จำกัด; ค่าที่ UI ให้เลือก: null/10/50/100
)
returns public.club_invite_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_code text;
  v_row public.club_invite_links;
begin
  if coalesce(public.club_role(p_club_id, v_me), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to create invite links for this club';
  end if;
  if p_max_uses is not null and p_max_uses <= 0 then
    raise exception 'max_uses must be positive';
  end if;

  loop
    v_code := substr(md5(random()::text || clock_timestamp()::text), 1, 10);
    begin
      insert into public.club_invite_links (club_id, code, created_by, expires_at, max_uses)
      values (
        p_club_id,
        v_code,
        v_me,
        case when p_expires_in_days is null then null
             else now() + (p_expires_in_days || ' days')::interval end,
        p_max_uses
      )
      returning * into v_row;
      exit;
    exception when unique_violation then
      -- ชนกันของ code (โอกาสน้อยมาก, 10 ตัวอักษรจาก md5) -- สุ่มใหม่แล้วลองอีกรอบ
      continue;
    end;
  end loop;

  return v_row;
end;
$$;

grant execute on function public.create_club_invite_link(uuid, integer, integer) to authenticated;
```

### RPC 2 — เพิกถอนลิงก์ (Owner/Admin เท่านั้น)

```sql
create or replace function public.revoke_club_invite_link(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_club_id uuid;
begin
  select club_id into v_club_id from public.club_invite_links where id = p_link_id;
  if v_club_id is null then
    raise exception 'Invite link not found';
  end if;
  if coalesce(public.club_role(v_club_id, v_me), '') not in ('owner', 'admin') then
    raise exception 'Not permitted to revoke invite links for this club';
  end if;

  update public.club_invite_links
  set revoked_at = now()
  where id = p_link_id and revoked_at is null;

  if not found then
    raise exception 'Invite link already revoked, or not found';
  end if;
end;
$$;

grant execute on function public.revoke_club_invite_link(uuid) to authenticated;
```

### RPC 3 — Preview ลิงก์ (ทุกคนเรียกได้ รวม guest/anonymous — ใช้ตอนเปิดหน้า preview ก่อนตัดสินใจเข้าร่วม)

```sql
create or replace function public.preview_club_invite_link(p_code text)
returns table (
  status text, -- 'valid' | 'expired' | 'revoked' | 'exhausted' | 'not_found'
  club_id uuid,
  club_name text,
  club_privacy text,
  club_icon_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when l.id is null then 'not_found'
      when l.revoked_at is not null then 'revoked'
      when l.expires_at is not null and l.expires_at < now() then 'expired'
      when l.max_uses is not null and l.use_count >= l.max_uses then 'exhausted'
      else 'valid'
    end,
    c.id, c.name, c.privacy, c.icon_url
  from public.club_invite_links l
  right join (select p_code as code) req on true
  left join public.clubs c on c.id = l.club_id
  where l.code = req.code or l.code is null
  limit 1;
$$;

grant execute on function public.preview_club_invite_link(text) to authenticated;
```

### RPC 4 — Redeem ลิงก์ (join จริง) — **จุดที่ branch ตามคำตอบของ Founder**

```sql
create or replace function public.redeem_club_invite_link(p_code text)
returns uuid -- club_id เมื่อสำเร็จ
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_link public.club_invite_links;
  v_club public.clubs;
  v_already_approved boolean;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_link from public.club_invite_links where code = p_code for update;
  if v_link.id is null then raise exception 'Invite link not found'; end if;
  if v_link.revoked_at is not null then raise exception 'This invite link has been revoked'; end if;
  if v_link.expires_at is not null and v_link.expires_at < now() then
    raise exception 'This invite link has expired';
  end if;
  if v_link.max_uses is not null and v_link.use_count >= v_link.max_uses then
    raise exception 'This invite link has reached its usage limit';
  end if;

  select * into v_club from public.clubs where id = v_link.club_id;

  if exists (
    select 1 from public.club_members
    where club_id = v_club.id and user_id = v_me and status = 'banned'
  ) then
    raise exception 'You have been banned from this club';
  end if;

  -- Founder ยืนยันทางเลือก A (2026-09-07, .wyn/company/DECISIONS.md):
  -- invite link ที่ valid = อนุมัติล่วงหน้าในตัวเสมอ ไม่ว่า club จะเป็น public หรือ private
  insert into public.club_members (club_id, user_id, role, status)
  values (v_club.id, v_me, 'member', 'approved')
  on conflict (club_id, user_id)
  do update set status = 'approved'
  where public.club_members.status = 'pending';
  -- upgrade แถว pending เดิม (จาก join ปกติที่ยังไม่ได้รับอนุมัติ) เป็น approved ทันที
  -- ให้สอดคล้องกับเจตนาของทางเลือก A ("ลิงก์เชิญ = อนุมัติล่วงหน้าแล้ว") --
  -- ไม่ทำอะไรกับแถวที่เป็น approved/banned อยู่แล้ว (do update ...where... กรองไว้)

  select exists (
    select 1 from public.club_members
    where club_id = v_club.id and user_id = v_me and status = 'approved'
  ) into v_already_approved;

  -- นับ use_count/บันทึก attribution เฉพาะตอนเป็นการเข้าร่วมใหม่จริง
  -- (ไม่ใช่การกดลิงก์ซ้ำของสมาชิกเดิม/คนที่ pending อยู่แล้วจาก join ปกติ)
  if not exists (select 1 from public.club_invite_link_uses where link_id = v_link.id and user_id = v_me) then
    update public.club_invite_links set use_count = use_count + 1 where id = v_link.id;
    insert into public.club_invite_link_uses (link_id, user_id) values (v_link.id, v_me);
  end if;

  return v_club.id;
end;
$$;

grant execute on function public.redeem_club_invite_link(text) to authenticated;
```

หมายเหตุ implementation: `for update` บนแถวลิงก์ตอน select กันสองคนกด max-uses ช่องสุดท้ายพร้อมกันแบบ race (ไม่เหมือน `pin_message` ของ WYN-132 ที่ยอมรับ race ได้เพราะผลกระทบต่ำ — ตรงนี้คุมเข้มกว่าเพราะเป็นเรื่อง "จำนวนครั้งใช้งานสูงสุด" ที่ Owner ตั้งใจจำกัดไว้จริงจัง)

## UI / UX Flow

### จุดเข้าถึง

`club_page.dart`'s `_openMoreMenu()` (เมนู "เพิ่มเติม ⋮" ที่ gate ด้วย `role.canManageClub` อยู่แล้ว — Owner/Admin) เพิ่มแถวใหม่ **"ลิงก์เชิญ"** (icon `Icons.link`) ต่อจาก "จัดการสิทธิ์สมาชิก" → เปิดหน้าใหม่ `ClubInviteLinksScreen`

### `ClubInviteLinksScreen`

- AppBar: "ลิงก์เชิญ"
- **ถ้า `club.privacy == 'private'` และ Founder เลือกทางเลือก A**: banner เตือนสีเหลือง/ส้มอ่อนด้านบนสุดของหน้า (ไอคอน warning) ข้อความ: **"ใครก็ตามที่มีลิงก์นี้จะเข้าร่วม Club ส่วนตัวนี้ได้ทันที โดยไม่ต้องรออนุมัติ — ระวังอย่าแชร์ต่อไปยังคนที่ไม่ต้องการให้เข้าร่วม"** (ถ้าเลือกทางเลือก B ไม่ต้องมี banner นี้เลย เพราะพฤติกรรมไม่เปลี่ยนจากเดิม)
- ปุ่มลอย/ปุ่มหัวรายการ **"+ สร้างลิงก์เชิญใหม่"** → เปิด bottom sheet ฟอร์ม:
  - "วันหมดอายุ": radio 4 ตัวเลือก — ไม่มีวันหมดอายุ / 1 วัน / 7 วัน / 30 วัน
  - "จำนวนครั้งใช้งานสูงสุด": radio 4 ตัวเลือก — ไม่จำกัด / 10 ครั้ง / 50 ครั้ง / 100 ครั้ง
  - ปุ่ม "สร้างลิงก์" → เรียก `create_club_invite_link` → สำเร็จ ปิด sheet, แสดงลิงก์ใหม่ที่หัวลิสต์ พร้อม SnackBar/dialog สั้นๆ ที่มีปุ่ม "คัดลอกลิงก์" ทันที (ให้ก็อปไปแชร์ต่อได้เลยโดยไม่ต้องกลับมาหาในลิสต์)
- รายการลิงก์ที่ยังไม่ revoke ทั้งหมดของ club นี้ เรียงใหม่สุดก่อน แต่ละแถว:
  - โค้ด/URL แบบย่อ (`wynos.online/club-invite/AbCd12EfGh`)
  - บรรทัดรอง: "ใช้ไปแล้ว 3/50 ครั้ง" หรือ "ใช้ไปแล้ว 3 ครั้ง" (ถ้า unlimited) + "หมดอายุใน 6 วัน"/"ไม่มีวันหมดอายุ" + "สร้างเมื่อ ..."
  - ปุ่มท้ายแถว: ไอคอนคัดลอก + เมนู "⋮" → "เพิกถอนลิงก์นี้" (confirm dialog ก่อนเสมอ, mirror `confirmDeletePost`'s ท่าเดิม: "เพิกถอนลิงก์นี้? ใครก็ตามที่ถือลิงก์นี้อยู่จะใช้ไม่ได้อีกทันที")
  - ลิงก์ที่หมดอายุ/ใช้ครบแล้ว (แต่ยังไม่ revoke) แสดงแถวจางลง + label "หมดอายุแล้ว"/"ใช้ครบแล้ว" ต่อท้าย ไม่ลบออกจากลิสต์ทันที (ให้ Owner เห็นประวัติ)
- Empty state: "ยังไม่มีลิงก์เชิญ — สร้างลิงก์แรกเพื่อแชร์ Club นี้ไปที่อื่นได้เลย"

### หน้า Preview เมื่อกดลิงก์ (`/club-invite/:code`)

ใหม่: `ClubInvitePreviewScreen` (ไม่ใช่การเปิด `ClubPage` ตรงๆ — ต้องเช็คสถานะลิงก์ก่อนเสมอ):
1. เรียก `preview_club_invite_link(code)` ทันทีที่เปิดหน้า
2. `status == 'valid'`: แสดงการ์ด preview club (icon, ชื่อ, badge Public/Private เหมือนที่ `ClubDiscoveryCard`/`ClubMiniCard` ใช้อยู่แล้ว) + ปุ่ม **"เข้าร่วม"** ตัวใหญ่ท้ายจอ
   - ผู้ใช้ anonymous (guest, WYN-072/WYN-119) กดปุ่มนี้ → `requireRealAccount()` เดิม gate ทันที (พา sign-up ก่อน เหมือนทุก action จริงอื่นในแอป) — ไม่สร้างกลไกใหม่
   - ผู้ใช้จริงกด "เข้าร่วม" → เรียก `redeem_club_invite_link(code)` → สำเร็จ นำทางเข้า `ClubPage` จริงทันที (ถ้าทางเลือก A หรือ Public) หรือ (ถ้าทางเลือก B + Private) แสดงข้อความ "ส่งคำขอเข้าร่วมแล้ว รออนุมัติจาก Owner" แล้วพาเข้า `ClubPage` แบบ pending state เดิม (เหมือน join ผ่านหน้า Club ปกติทุกประการ)
3. `status` อื่นๆ ('expired'/'revoked'/'exhausted'/'not_found'): แสดง `EmptyStateBlock` สุภาพ ไม่มีปุ่ม "เข้าร่วม" — ข้อความตาม status:
   - `expired` → "ลิงก์เชิญนี้หมดอายุแล้ว"
   - `revoked` → "ลิงก์เชิญนี้ถูกเพิกถอนแล้ว"
   - `exhausted` → "ลิงก์เชิญนี้ถูกใช้งานครบจำนวนแล้ว"
   - `not_found` → "ไม่พบลิงก์เชิญนี้"
   - ทุกกรณี มีปุ่ม/ลิงก์รอง "ไปที่ WYN" กลับ Home ปกติ ไม่ค้างเป็น dead-end

### Deep Link routing

`DeepLinkService` เพิ่ม pattern `/club-invite/:code` → `ClubInvitePreviewScreen(code: code)` — mirror ทุกจุดของ 5 pattern เดิม (รองรับทั้ง authenticated และ guest ผ่านกลไก Anonymous Sign-In ของ WYN-119 ที่มีอยู่แล้ว, path ที่ code ไม่ตรง pattern fallback เข้า Home ตามปกติ)

## Wireframe (text)

```
ClubInviteLinksScreen:
AppBar: ลิงก์เชิญ
┌─────────────────────────────────────────┐
│ ⚠️ ใครก็ตามที่มีลิงก์นี้จะเข้าร่วม Club     │  <- เฉพาะ Private + ทางเลือก A
│    ส่วนตัวนี้ได้ทันที โดยไม่ต้องรออนุมัติ    │
└─────────────────────────────────────────┘
[+ สร้างลิงก์เชิญใหม่]

wynos.online/club-invite/AbCd12EfGh        [⧉][⋮]
ใช้ไปแล้ว 3/50 ครั้ง · หมดอายุใน 6 วัน

wynos.online/club-invite/XyZ98QwErT        [⧉][⋮]
ใช้ไปแล้ว 12 ครั้ง · ไม่มีวันหมดอายุ

──────────────────────────────────

ClubInvitePreviewScreen (เปิดจากลิงก์):
        [icon Club]
        ชื่อ Club
        🔒 Private Club · 128 สมาชิก

        [       เข้าร่วม       ]
```

## Edge Cases

- กดลิงก์ที่ตัวเองเป็นสมาชิกอยู่แล้ว (approved) → `redeem_club_invite_link` ทำงานแบบ idempotent (`on conflict do nothing`) → พาเข้า `ClubPage` ตรงๆ เหมือนกดลิงก์ `/club/:id` ปกติ ไม่แจ้ง error/ไม่นับ use_count ซ้ำ
- กดลิงก์ทั้งที่ถูก ban จาก club นั้นอยู่แล้ว → RPC ปฏิเสธชัดเจน ("You have been banned from this club") → หน้า preview แสดงข้อความนี้แทนปุ่ม "เข้าร่วม"
- กดลิงก์ขณะที่ตัวเองมี pending request อยู่แล้วจากทางอื่น (join ผ่านหน้า Club ปกติไว้ก่อนหน้า) → RPC 4 `on conflict ... do update set status = 'approved' where status = 'pending'` **อัปเกรดแถวเดิมเป็น approved ทันที** — สอดคล้องกับเจตนาของทางเลือก A ที่ Founder เลือก (invite link = อนุมัติล่วงหน้าแล้ว ไม่ควรปล่อยให้ค้าง pending ต่อ) เป็นการตัดสินใจของ AI Design ที่สอดคล้องโดยตรงกับคำตอบหลักของ Founder ไม่ใช่จุดที่ต้องถามเพิ่ม
- ลิงก์ที่ยังไม่หมดอายุแต่ Club ถูกลบไปแล้ว → เป็นไปไม่ได้ในทางปฏิบัติ (Club ไม่มีฟีเจอร์ลบ Club ในระบบตอนนี้ตามที่ตรวจสอบแล้ว — ถ้ามีในอนาคต `club_id ... on delete cascade` จะลบลิงก์ตามไปด้วยอัตโนมัติอยู่แล้ว)
- Owner/Admin ที่สร้างลิงก์ถูกถอด role/ออกจาก club ไปแล้ว → ลิงก์ที่สร้างไว้ก่อนหน้ายังใช้งานได้ตามปกติ (ไม่ผูกอายุลิงก์กับสถานะสมาชิกของผู้สร้าง — ตรงกับ pattern `created_by`/`reviewer_id` อื่นในระบบที่เป็นแค่ attribution ไม่ใช่ validity condition) — เฉพาะ Owner/Admin **ปัจจุบัน** เท่านั้นที่ revoke ได้ (เช็คสดทุกครั้งผ่าน `club_role()`)
- สร้างลิงก์พร้อมกันหลายอันจาก Owner/Admin คนละคน → ไม่มี limit จำนวนลิงก์ต่อ club ในสเปกนี้ (Requirement อนุญาตให้สร้างได้หลายลิงก์อยู่แล้ว) — ยอมรับได้ ไม่ใช่ gap

## Design Rules

ไม่มีการเปลี่ยนแปลงต่อ Design System — reuse component เดิมทั้งหมด (banner style เดียวกับ `RestrictionBanner`/`PrivacyNoticeBanner` ที่มีอยู่แล้วสำหรับ warning banner, `EmptyStateBlock` เดิมสำหรับสถานะลิงก์ที่ใช้ไม่ได้, badge Public/Private เดียวกับที่ `ClubDiscoveryCard`ใช้)

## Handoff

**พร้อมส่ง AI Coding แล้ว** — Founder ยืนยันทางเลือก A (2026-09-07) และอนุมัติให้ใช้ wireframe ข้อความแทน visual mockup จริงสำหรับรอบนี้ (บันทึกใน `.wyn/company/DECISIONS.md`) — RPC 4 lock แล้ว, schema/UI/deep-link/RLS พร้อมครบ 100%

**Staged Rollout (WYN-125)**: ต้อง gate ด้วย `isDeveloperAccount()` — `false`: ไม่เห็นแถว "ลิงก์เชิญ" ในเมนู More เลย, เปิดลิงก์ `/club-invite/:code` เก่าที่อาจมีคน (developer) สร้างไว้ก่อน fallback เข้า Home ปกติเงียบๆ (เหมือน path ที่ไม่รู้จัก) แทนที่จะพาไปหน้า preview จริง — จนกว่า Founder จะสั่งเปิดให้ทุกคน
