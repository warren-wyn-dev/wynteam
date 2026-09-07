# Deployment — WYN-127 (Club Channels) / WYN-128 (Club Group Chat) / WYN-129 (Club Role Badges)

วันที่: 2026-09-07
Deploy โดย: AI Deploy & DevOps (`session_014LEtwe8NjiPLcc9cqJEkuq`)
Branch: `claude/club-exploration-feature-71rl06` (`7b67643`), pushed to origin

## Release

สามฟีเจอร์จาก `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ("ทำไม Club ยังไม่รู้สึกเหมือน Discord"):

- **WYN-127 — Club Channels**: แบ่งฟีดของ Club เป็นหลายห้อง (`#ทั่วไป` default + ห้องที่ Owner/Admin สร้างเพิ่ม)
- **WYN-129 — Club Role Badge**: ป้ายคอสเมติกข้างชื่อสมาชิก แยกขาดจากระบบสิทธิ์ (`club_role()`) 100%
- **WYN-128 — Club Group Chat**: ห้องแชทสด real-time ต่อ channel (ตาราง `club_channel_messages` ใหม่ทั้งหมด ไม่แตะระบบแชท 1-1 เดิม)

ทั้ง 3 ฟีเจอร์ถูก gate ด้วย `DeveloperAccessService.isDeveloperAccount()` (WYN-125) ตามนโยบาย Staged Rollout — ผู้ใช้ทั่วไป **ไม่เห็นการเปลี่ยนแปลงใดๆ เลย** จนกว่า Founder จะสั่งเปิด มีแค่ `@warren`/`@wynos_online` (allowlist ปัจจุบัน) ที่เห็นของใหม่หลัง deploy

## QA Status

**PASS รอบ 2 (2026-09-07)** — ดู "QA Output รอบ 2" ในทั้ง 3 ไฟล์:
`.wyn/tasks/backlog/WYN-127-club-channels.md`, `.wyn/tasks/backlog/WYN-128-club-group-chat.md`, `.wyn/tasks/backlog/WYN-129-club-role-badges.md`

รอบ 1 FAIL ด้วย 3 เหตุผล (ขาด staged-rollout gate, WYN-129 RLS update-retarget gap, WYN-128 ไม่มีทาง report ข้อความแชท) — Debug Engineer แก้ครบ (`005708b`, `1bb6fa4`) แล้ว QA ตรวจซ้ำอิสระด้วย live PostgreSQL 16.13 + exploit script ของ QA เอง ยืนยัน PASS ทั้ง 3 จุด

## Build Status — ยืนยันเองซ้ำในรอบนี้ (ไม่เชื่อรายงาน QA เฉยๆ)

รันจริงบน branch head (`7b67643`) ด้วย Flutter SDK ที่มีอยู่ในเครื่อง (`/tmp/flutter-sdk`, 3.47.2 stable — ตรงกับเวอร์ชันที่ CI/deploy-web.yml ใช้คือ 3.47.1, ห่างกัน 1 patch เท่านั้น):

- `flutter analyze` → **No issues found!**
- `flutter test` → **1377/1377 ผ่านทั้งหมด** (ตรงเป๊ะกับตัวเลขที่ QA รายงาน)
- `python3 supabase/check_schema_ordering.py` → **OK: no forward references found**
- **`schema.sql` โหลดเข้า PostgreSQL 16 เปล่าจริง (มี stub `auth`/`storage` schema + role `authenticated`/`anon` แบบเดียวกับ `supabase/tests/*.sh` ใช้)**: โหลดสำเร็จ 100% ไม่มี error แม้แต่บรรทัดเดียว (13,878 บรรทัด)
- **ตรวจ drift ระหว่าง 3 migration file กับ schema.sql**: อ่านทั้ง 3 ไฟล์ (`migrations_wyn127_club_channels.sql`, `migrations_wyn129_club_member_badges.sql`, `migrations_wyn128_club_channel_messages.sql`) เทียบกับ section ที่ตรงกันใน `schema.sql` ทีละบรรทัด — **statement ตรงกันทุกตัว ไม่มี drift** (ต่างกันแค่ `begin`/`commit` + `drop policy if exists` ก่อน `create policy` ในไฟล์ migration ซึ่งจำเป็นสำหรับการรันซ้ำได้บน DB ที่มีอยู่แล้ว ส่วนความหมาย/logic ตรงกัน 100%) — สำคัญเพราะทั้ง WYN-128/WYN-129 ถูกแก้เพิ่มหลัง QA รอบ 1 FAIL (RLS gap + report support) ต้องยืนยันว่าไฟล์ migration ที่จะให้ Founder รันเป็นเวอร์ชันล่าสุดจริง ไม่ใช่ของค้างก่อนแก้
- **ทดสอบลำดับการรัน migration จริงกับข้อมูลจำลอง "production ก่อนมีฟีเจอร์นี้"**: โหลด `schema.sql` ของ commit `e8d33c2` (จุดก่อน WYN-127/128/129 ทั้งหมด) ลง PostgreSQL เปล่า ใส่ข้อมูลจำลอง (Club เก่าที่มีโพสต์ pin อยู่แล้ว + Club เก่าที่ไม่มีโพสต์เลย) แล้วรัน 3 migration file ตามลำดับ **WYN-127 → WYN-129 → WYN-128** จริง:
  - ทั้ง 3 ไฟล์รันผ่านไม่มี error
  - โพสต์เก่าที่มีอยู่ก่อน migration ได้ `channel_id` ชี้ไปที่ห้อง "ทั่วไป" ที่สร้างให้อัตโนมัติ ถูกต้อง (ไม่มีโพสต์ไหน `channel_id is null` เหลือ)
  - Club เก่าที่ไม่มีโพสต์เลยก็ได้ channel default เช่นกัน
  - `reports_target_type_check` ถูกขยายให้รองรับ `'club_channel_message'` จริง
  - ตาราง `club_channel_messages`/`club_member_badges` ถูกสร้างสำเร็จ
  - **ทดสอบ negative case**: ลองรัน `migrations_wyn128_club_channel_messages.sql` ก่อน WYN-127 (ผิดลำดับ) บน DB จำลองแยกต่างหาก — ล้มเหลวทันทีตามคาด (`club_channels` ยังไม่มีให้ reference) แต่ **rollback สะอาดทั้งไฟล์** (มี `begin`/`commit` คลุมทั้งไฟล์) ไม่เหลือ state ครึ่งๆ กลางๆ ไว้เลย — ปลอดภัยแม้ Founder รันผิดลำดับโดยไม่ตั้งใจ แค่ต้องรันใหม่ตามลำดับที่ถูกต้อง

## Deployment Target

- Database: Supabase production (project `akawuzukstmbztyajxsr`) — **Founder รันเอง** ผ่าน Supabase Dashboard SQL Editor (AI session นี้ไม่มี Supabase Management API credentials เลย — ตรวจสอบแล้วว่าไม่มี `SUPABASE_*` env var ใดๆ ในเครื่อง — ตรงตามวินัยเดิมของโปรเจกต์)
- Web: wynos.online (Vercel production) ผ่าน `deploy-web.yml` (`workflow_dispatch` เท่านั้น, build Flutter web อยู่ในตัว workflow เอง)

## Changes (ไฟล์ที่เกี่ยวข้อง)

- `supabase/migrations_wyn127_club_channels.sql`, `supabase/migrations_wyn129_club_member_badges.sql`, `supabase/migrations_wyn128_club_channel_messages.sql` — ยังไม่ apply ต่อ production
- `supabase/schema.sql` — มี section WYN-127/128/129 ครบ (baked-in "load into empty DB" form) ตรงกับ migration files แล้ว
- Dart: `ClubChannel`/`ClubChannelSwitcher`, `ClubChannelMessage`/`ClubChannelChatRepository`/`ClubChannelChatView`, `ClubBadgeRepository`/`ClubBadgePill`, staged-rollout gate ผ่าน `DeveloperAccessService.isDeveloperAccount()` ทั่วทั้ง 3 ฟีเจอร์
- ไม่มีจุดใดแตะ `conversations`/`conversation_participants`/`messages` (WYN-031, แชท 1-1 เดิม) เลยแม้แต่บรรทัดเดียว — ยืนยันแล้วทั้งจาก QA และจากการอ่าน migration file เอง

## ขั้นตอนที่ Founder ต้องทำเพื่อ deploy จริง (เรียงลำดับ — ห้ามสลับ)

1. **Merge branch เข้า `main`**: `claude/club-exploration-feature-71rl06` → `main` (เปิด PR แล้ว merge ตามธรรมเนียมเดิมของ repo) — ทดสอบ merge แบบ dry-run แล้วในรอบนี้ **ไม่มี conflict กับ `main` ปัจจุบัน** (`5498928`) พร้อม merge ได้ทันที
2. **รัน migration SQL ผ่าน Supabase Dashboard → SQL Editor ตามลำดับนี้เป๊ะๆ** (WYN-128 อ้างอิงตาราง `club_channels` ของ WYN-127 โดยตรง ต้องรันหลัง WYN-127 เท่านั้น — WYN-129 ไม่ผูกกับใครเลย จะแทรกตรงไหนก็ได้ แต่แนะนำรันเรียงตามนี้เพื่อความชัดเจน/ตรงกับที่ทดสอบมาแล้ว):
   1. `supabase/migrations_wyn127_club_channels.sql`
   2. `supabase/migrations_wyn129_club_member_badges.sql`
   3. `supabase/migrations_wyn128_club_channel_messages.sql`
   - แต่ละไฟล์มี `begin`/`commit` คลุมทั้งไฟล์อยู่แล้ว — ถ้ารันแล้ว error กลางทาง จะ rollback อัตโนมัติทั้งไฟล์ ไม่ทิ้ง state ค้าง ปลอดภัยที่จะแก้ปัญหาแล้วรันซ้ำ (ทุก statement เป็น `if not exists`/`or replace`/`drop ... if exists` อยู่แล้ว)
3. **ตรวจสอบหลังรัน migration** (SQL ยืนยัน, รันใน SQL Editor เดียวกัน):
   ```sql
   select count(*) from public.club_posts where channel_id is null; -- ต้องได้ 0
   select c.id from public.clubs c
     left join public.club_channels ch on ch.club_id = c.id
     where ch.id is null; -- ต้องไม่มีแถวใดเลย (ทุก Club มี channel แล้ว)
   select conname from pg_constraint where conname = 'reports_target_type_check'; -- ต้องเจอ 1 แถว
   ```
   (คำสั่ง VERIFY แบบเดียวกันมีอยู่ท้ายไฟล์ migration แต่ละไฟล์อยู่แล้ว)
4. **Deploy เว็บ**: ไปที่ GitHub Actions → `deploy-web.yml` → "Run workflow" (เลือก branch `main` หลัง merge ในขั้นตอน 1 แล้ว) — ไม่ต้อง build เองที่เครื่อง Founder, workflow build Flutter web ให้เองทั้งหมดแล้ว deploy ขึ้น Vercel production
5. **ตรวจสอบ production หลัง deploy** (ระดับที่ AI ยืนยันเองได้ในตอนนั้น): `curl -o /dev/null -w '%{http_code}' https://wynos.online/` ต้องได้ `200`, เช็คว่า `main.dart.js` เปลี่ยน hash/ขนาดจริง (ไม่ใช่ cache เดิม)
6. **ตรวจสอบด้วยบัญชีจริง (ต้อง Founder ทำเอง — AI ยืนยันเองไม่ได้)**: ล็อกอินด้วย `@warren` หรือ `@wynos_online` (อยู่ใน `developer_accounts` allowlist แล้ว) เปิด Club ใดก็ได้ → ต้องเห็นแถบ channel switcher, สร้าง/ลบ channel ได้ (ถ้าเป็น Owner/Admin), สลับ toggle "โพสต์ | แชท" เห็นห้องแชทจริง ส่งข้อความได้ real-time, ตั้ง/ถอด badge ให้สมาชิกได้ — จากนั้นล็อกอินด้วยบัญชีทั่วไป (ไม่อยู่ใน allowlist) เปิด Club เดียวกัน → **ต้องไม่เห็นการเปลี่ยนแปลงใดๆ เลย** เหมือนก่อน deploy ทุกประการ (นี่คือจุดพิสูจน์ staged-rollout gate ทำงานจริงบน production ไม่ใช่แค่ใน test)

## Production Verification

- **สิ่งที่ AI ยืนยันได้เอง (รอบนี้)**: build/test/schema-drift/migration-order ทั้งหมดตามหัวข้อ "Build Status" ด้านบน — ยืนยันจริงด้วยเครื่องมือ (PostgreSQL 16 local + Flutter SDK local) ไม่ใช่แค่เชื่อรายงาน QA
- **สิ่งที่ต้องรอ Founder ยืนยัน**: ทุกอย่างในขั้นตอน 5-6 ข้างบน — โดยเฉพาะข้อ 6 (ฟีเจอร์ทำงานจริงสำหรับบัญชีนักพัฒนา และผู้ใช้ทั่วไปไม่เห็นอะไรเปลี่ยนเลย) เพราะ AI session นี้ไม่มีทางเข้าถึง production Supabase/เว็บจริงเพื่อทดสอบเอง — Task จะย้ายจาก `approved/` ไป `completed/` ได้ก็ต่อเมื่อ Founder ยืนยันข้อนี้แล้วเท่านั้น (`.wyn/company/WORKFLOW.md`)

## Rollback Plan

- **Database**: ทั้ง 3 migration เป็น additive ล้วน (ตารางใหม่ + คอลัมน์ใหม่ที่ backfill ครบก่อนจะ constrain NOT NULL) **ยกเว้นจุดเดียวที่ทำลายข้อมูลได้จริงถ้าใช้งานฟีเจอร์แล้ว**: ลบ channel จะ cascade ลบโพสต์ในห้องนั้นทันที (Founder ตัดสินใจเองไว้แล้ว "ประหยัดพื้นที่" ไม่ใช่บั๊ก) — ถ้าต้องถอย ให้:
  1. `revoke execute on function public.create_poll_club_post(...) from authenticated;`-ระดับ table: ปิด RLS insert/update/delete ของ `club_channels`/`club_channel_messages`/`club_member_badges` ชั่วคราวด้วย `drop policy` ถ้าจำเป็นต้องหยุดการเขียนทันทีโดยไม่ลบตาราง (ข้อมูลเดิมไม่หาย)
  2. หรือถอด mechanism ทั้งหมด: `drop table` ทั้ง 4 ตารางใหม่ (`club_channels`, `club_channel_messages`, `club_channel_message_reads`, `club_member_badges`) — ปลอดภัยเพราะ `club_posts.channel_id` เป็น FK ชี้ไปหา `club_channels` ด้วย `on delete cascade` จึงต้องพิจารณาก่อนว่ายอมรับให้โพสต์เก่าถูกลบตามไปด้วยหรือไม่ (ถ้าไม่ยอมรับ ต้อง `alter table club_posts drop column channel_id` แยกต่างหากก่อน ไม่ drop cascade)
- **Web**: Vercel Instant Rollback กลับ deployment ก่อนหน้า หรือ `git revert` commit merge บน `main` แล้ว trigger `deploy-web.yml` ใหม่
- **Staged-rollout gate เป็นเกราะสำคัญที่สุด**: ตราบใดที่ยังไม่เปิด flag ให้ผู้ใช้ทั่วไป ความเสี่ยงจริงต่อผู้ใช้จริงเกือบเป็นศูนย์ — ถ้าพบปัญหาหลัง deploy วิธีที่เร็ว/ปลอดภัยที่สุดคือลบ `@warren`/`@wynos_online` ออกจาก `developer_accounts` ชั่วคราวผ่าน SQL Editor เพื่อหยุดผลกระทบทันทีโดยไม่ต้อง rollback โค้ด/DB เลย

## สิ่งที่ AI Deploy & DevOps รอบนี้ **ไม่ได้ทำ** (ยืนยันตามข้อจำกัดที่กำหนดไว้)

- **ไม่ได้ apply migration SQL ใดๆ ต่อ Supabase production เลย** — ตรวจสอบแล้วว่า session นี้ไม่มี `SUPABASE_URL`/`SUPABASE_*` credential ใดๆ ในเครื่อง และไม่มี Supabase Management API access
- **ไม่ได้ merge branch เข้า `main`** และ **ไม่ได้เปิด PR** — session นี้ไม่มี `gh` CLI และไม่มี GitHub tool ให้เรียกใช้ในรอบนี้ (ต่างจาก session ก่อนหน้าบางรอบที่มี) จึงเตรียม dry-run merge ตรวจสอบไว้ให้แล้วว่าไม่มี conflict แต่การ merge จริงต้องให้ Founder หรือ session ที่มีสิทธิ์ GitHub ทำต่อ
- **ไม่ได้ trigger `deploy-web.yml`** — ด้วยเหตุผลเดียวกัน (ไม่มีสิทธิ์เข้าถึง GitHub Actions ในรอบนี้)
- **ไม่พบ credential/เครื่องมือใดๆ ที่เข้าถึง production จริงได้ในรอบนี้** — ไม่มีอะไรต้องรายงานเป็นข้อกังวลด้านความปลอดภัย (ตรงกันข้ามกับกรณี "พบเครื่องมือที่ไม่ควรมี" — รอบนี้คือไม่มีเครื่องมือเข้าถึง production เลยตามที่ควรจะเป็น)

## สถานะ Task

`.wyn/tasks/backlog/WYN-127-club-channels.md`, `.wyn/tasks/backlog/WYN-128-club-group-chat.md`, `.wyn/tasks/backlog/WYN-129-club-role-badges.md` → ย้ายไป `.wyn/tasks/approved/` (QA PASS ครบ, build/schema/migration-order ตรวจสอบอิสระซ้ำแล้ว, go-live package พร้อมส่งมอบให้ Founder) — **ยังไม่ deploy จริง** จนกว่า Founder จะดำเนินการตามขั้นตอนข้างบน แล้วยืนยัน Production Verification ข้อ 6 จึงจะย้ายไป `completed/` ได้
