-- WYN-130: Club Invite Link (generate/revoke/expiration/max-uses)
--
-- Adds `public.club_invite_links` + `public.club_invite_link_uses`
-- (attribution tracking, no UI this round) + 4 RPCs
-- (create_club_invite_link/revoke_club_invite_link/
-- preview_club_invite_link/redeem_club_invite_link). Founder locked
-- "ทางเลือก A" (2026-09-07, .wyn/company/DECISIONS.md): a valid invite
-- link joins a Private Club immediately, skipping Join Request/Approve
-- entirely.
--
-- See .wyn/tasks/active/WYN-130-club-invite-link.md and
-- .wyn/docs/design/wyn-130-club-invite-link.md for the full spec.
--
-- SAFETY: purely additive -- 2 brand new tables, 4 new RPCs, no
-- existing table/column touched. Re-runnable throughout (`if not
-- exists`/`or replace`).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

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

drop policy if exists "Owners/admins can view their club's invite links" on public.club_invite_links;
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

-- RPC 1: create_club_invite_link() -- Owner/Admin เท่านั้น
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

-- RPC 2: revoke_club_invite_link() -- Owner/Admin เท่านั้น
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

-- RPC 3: preview_club_invite_link() -- ทุกคนเรียกได้ รวม guest/anonymous
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

-- RPC 4: redeem_club_invite_link() -- join จริง. Founder ยืนยันทางเลือก A
-- (2026-09-07, .wyn/company/DECISIONS.md): invite link ที่ valid =
-- อนุมัติล่วงหน้าในตัวเสมอ ไม่ว่า club จะเป็น public หรือ private -- `for
-- update` บนแถวลิงก์ตอน select กันสองคนกด max-uses ช่องสุดท้ายพร้อมกันแบบ
-- race (คุมเข้มกว่า pin_message ของ WYN-132 เพราะเป็นเรื่อง "จำนวนครั้ง
-- ใช้งานสูงสุด" ที่ Owner ตั้งใจจำกัดไว้จริงจัง).
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

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.club_invite_links; -- expect 0 rows right after apply
