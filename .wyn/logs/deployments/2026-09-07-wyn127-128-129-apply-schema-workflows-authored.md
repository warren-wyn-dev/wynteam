# Deployment log — WYN-127/128/129 apply-schema GitHub Actions workflows (authored, not triggered)

วันที่: 2026-09-07
โดย: AI Deploy & DevOps (`session_014LEtwe8NjiPLcc9cqJEkuq`)
Commit: `4f5bdf0` (pushed directly to `main`, ตามธรรมเนียมเดิม `9603f30`)

## ขอบเขตงานรอบนี้

Founder ขอให้เขียนไฟล์ GitHub Actions workflow สำหรับ apply migration ของ
WYN-127 (Club Channels) / WYN-129 (Club Role Badges) / WYN-128 (Club
Group Chat) เท่านั้น **ห้าม trigger เอง** — รอบ trigger จริง (ถ้าจำเป็น)
เป็นของคนละขั้นตอนที่มีคนคอยดู log สดๆ

## Release / QA Status

QA PASS ครบทั้ง 3 ฟีเจอร์ (รอบ 2, ดู
`.wyn/logs/deployments/2026-09-07-wyn-127-128-129-club-discord-identity-go-live-package.md`)
PR #297 merge เข้า `main` แล้ว (`fe36249`)

## Build Status

- ตรวจ 3 ไฟล์ migration (`supabase/migrations_wyn127_club_channels.sql`,
  `supabase/migrations_wyn129_club_member_badges.sql`,
  `supabase/migrations_wyn128_club_channel_messages.sql`) เทียบกับ
  section ที่ตรงกันใน `supabase/schema.sql` — **ตรงกันทุก statement**
  รวมจุดที่ QA/Debug แก้เพิ่มหลัง QA รอบ 1 FAIL: WYN-129's UPDATE policy
  ได้ target-membership check (`club_role(club_id, user_id) is not
  null`), WYN-128 มี `club_channel_message_reads` + reports.target_type/
  `submit_report()`/`apply_moderation_action()` รองรับ
  `'club_channel_message'` ครบ
- Validate ด้วย local scratch PostgreSQL 16 (ตาม convention เดิมของ
  `supabase/tests/*.sh`/`supabase/check_schema_ordering.py`): โหลด
  `supabase/schema.sql` จาก commit `5498928` (commit ก่อน WYN-127/128/129
  ทั้งหมด — จุดก่อน `0cc2395` roadmap doc) เข้า DB เปล่าพร้อม stub
  `auth`/`storage` schema + role `authenticated`/`anon` สำเร็จ 100%
  ไม่มี error
- Seed ข้อมูลจำลอง "production ก่อนมี WYN-127" (Club เก่า 1 อัน + post
  เก่า 1 อัน) แล้วรันสคริปต์ SQL ที่ extract ออกมาจากไฟล์ workflow จริง
  (ผ่าน mock ของ `run_sql` ที่เปลี่ยนจาก curl→Supabase API เป็น psql
  ตรงๆ กับ DB ทดสอบ เพื่อทดสอบ escaping ของ bash/dollar-quote จริง ไม่ใช่
  แค่ SQL เปล่าที่พิมพ์เอง) เรียงลำดับ **WYN-127 → WYN-129 → WYN-128**:
  - ทั้ง 3 ไฟล์รันผ่านไม่มี error รอบแรก
  - Backfill ถูกต้อง: club เก่าได้ default channel "ทั่วไป", post เก่าได้
    `channel_id` ชี้ไปห้องนั้น (`count(*) where channel_id is null` = 0)
  - `reports_target_type_check` ขยายรองรับ `'club_channel_message'`
    สำเร็จ, ฟังก์ชัน `mark_club_channel_read`/`get_unread_channel_counts`/
    `submit_report`/`apply_moderation_action` ถูกสร้าง/แทนที่ครบ
  - **รันซ้ำรอบ 2 ทั้ง 3 ไฟล์**: idempotent 100% — ไม่มี error, ไม่มีแถว
    ซ้ำ/เปลี่ยนแปลงเพิ่ม (INSERT/UPDATE เป็น 0 rows ทุกจุดที่ควรเป็น no-op)
  - `pg_dump --schema-only` ของตารางที่เกี่ยวข้องหลัง apply ตรงกับโครงสร้าง
    ที่ `supabase/schema.sql`'s WYN-127/128/129 section อธิบายไว้ทุก
    ประการ (column, constraint, FK, index, RLS policy, trigger)

## Deployment Target

GitHub Actions (`.github/workflows/`) — เพิ่มไฟล์ใหม่ 3 ไฟล์:

- `.github/workflows/wyn127-apply-club-channels-schema.yml`
- `.github/workflows/wyn129-apply-club-member-badges-schema.yml`
- `.github/workflows/wyn128-apply-club-channel-messages-schema.yml`

ทั้ง 3 ไฟล์เป็น `workflow_dispatch` เท่านั้น **ยังไม่ได้ trigger รันเลย**
ตามที่ Founder สั่งชัดเจน

## Changes

เพิ่มไฟล์ workflow ใหม่ 3 ไฟล์ (923 บรรทัด รวม) — ไม่แก้ไฟล์เดิมไฟล์ใด
เลย ไม่แตะ `deploy-web.yml`

## หมายเหตุสำคัญ — สถานะ production ปัจจุบันจริงๆ

ตรวจ git history พบว่า **migration ทั้ง 3 ตัวถูก Founder รันเข้า Supabase
production ไปแล้วจริง** ผ่าน Supabase Dashboard SQL Editor โดยตรง (ไม่ใช่
ผ่าน workflow) ตั้งแต่เช้าวันนี้ (ดู
`.wyn/logs/deployments/2026-09-07-wyn-127-128-129-club-discord-identity-go-live-package.md`
และ `.wyn/company/CONTEXT.md` entry "[2026-09-07] WYN-127/128/129
migration + deploy เสร็จ (run #96)") และ `deploy-web.yml` ก็ trigger ไป
2 รอบแล้ว (run #96, #97 ล่าสุดหลัง Founder ขอปรับโครงสร้าง 3 แท็บใหม่)
ยืนยัน live บน `wynos.online` แล้ว

ดังนั้น **ไฟล์ workflow ทั้ง 3 ที่เพิ่มรอบนี้ไม่ใช่ของที่ต้อง trigger
เพื่อ deploy ฟีเจอร์เหล่านี้ให้ขึ้น production** (ขึ้นไปแล้ว) — เพิ่มไว้
ทีหลัง (retroactive) เพื่อให้มี IaC/CI path ที่ทำซ้ำได้และตรวจสอบได้
(auditable) เก็บไว้ใช้กรณี disaster recovery/ตั้ง environment ใหม่ในอนาคต
ตรงตามธรรมเนียมที่โปรเจกต์นี้ทำกับทุก schema change อื่นๆ (wyn118,
wyn125, ฯลฯ) — เพราะทุก statement เป็น idempotent (`if not exists`/
`or replace`/`drop ... if exists`) การมีไฟล์นี้อยู่จึงไม่กระทบ
production ปัจจุบันแม้จะถูก trigger รันซ้ำในอนาคตก็ตาม

## ลำดับการรัน (ถ้าถูก trigger ในอนาคต)

**WYN-127 → WYN-129 → WYN-128** (แนะนำ ตรงกับที่ validate ไว้) โดย
บังคับจริงมีแค่ **127 ต้องมาก่อน 128** เท่านั้น — เพราะ
`club_channel_messages.channel_id`/`club_channel_message_reads.channel_id`
ของ WYN-128 มี foreign key ชี้ไปที่ `public.club_channels` ที่ WYN-127
เป็นคนสร้าง รันสลับกันจะ error ทันที (`relation "public.club_channels"
does not exist`) — WYN-129 (`club_member_badges`) อ้างอิงแค่
`public.clubs`/`public.profiles` ที่มีอยู่แล้ว ไม่ผูกกับ WYN-127/128 เลย
รันตอนไหนก็ได้ — ใส่ไว้ตรงกลางเพื่อความชัดเจนเท่านั้น ไม่ใช่ requirement
จริง

wyn128 workflow มี comment อธิบายเรื่องนี้ไว้ชัดเจนในตัวไฟล์เองแล้ว
(ไม่ได้ผูก trigger-chaining อัตโนมัติ ตามที่ Founder สั่ง — เป็น
human-readable comment ให้คนกดรันเองอ่าน)

## Production Verification

- **สิ่งที่ AI ยืนยันได้เอง**: validate SQL ทั้งหมดตามหัวข้อ "Build
  Status" ข้างบน ด้วย local PostgreSQL 16 จริง ไม่ใช่แค่อ่านโค้ด
- **ไม่ได้แตะ production เลยในรอบนี้** — ไม่มี credential Supabase/GitHub
  Actions secret ใดๆ ในเครื่อง session นี้ และตามคำสั่ง Founder ห้าม
  trigger เองอยู่แล้ว
- Production ของฟีเจอร์นี้ (schema + web) ถูกยืนยันแล้วจากรอบ deploy
  จริงก่อนหน้า (run #96/#97) ตามที่บันทึกไว้ใน go-live package/CONTEXT.md

## Rollback Plan

ไม่มีอะไรให้ rollback จากรอบนี้ — เป็นการเพิ่มไฟล์ CI definition ล้วนๆ
ไม่กระทบ production/runtime ใดๆ ถ้าต้องการถอด ให้ `git revert` commit
`4f5bdf0` หรือลบ 3 ไฟล์นี้ออกได้ทันทีโดยไม่มีผลกระทบต่อระบบที่รันอยู่จริง

## สิ่งที่ยังไม่ได้ทำ (ตามขอบเขตที่ Founder กำหนด)

- ไม่ได้ trigger workflow ทั้ง 3 นี้เลย
- ไม่ได้แตะ `.github/workflows/deploy-web.yml`
