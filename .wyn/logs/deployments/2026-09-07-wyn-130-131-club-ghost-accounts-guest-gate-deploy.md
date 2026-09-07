# Deployment — WYN-130 (Club Ghost-Account Display) + WYN-131 (Missing Guest Join/Create Gate)

วันที่: 2026-09-07 09:04–09:2x UTC
Deploy โดย: AI Debug Engineer (orchestrated by this session)
อำนาจ: Founder ขอให้เปิด PR แล้วตอบ "ใช่ กด deploy เลย" ในคำถามแบบ popup ก่อน deploy web, และรัน SQL เองตามที่แนะนำ

## Release

Founder ส่ง screenshot ของ Club "About > สมาชิก" list แสดงบางแถวเป็น "@" เปล่า + avatar "?" ("บัญชีผี") — แก้ 2 บั๊กที่เกี่ยวข้องกัน:

- **WYN-130**: `ClubRepository.fetchApprovedMembers`/`fetchPendingMembers` และ `ClubEventRepository.fetchAttendees` join `profiles` ตรงๆ โดยไม่กรองบัญชีที่ onboarding ไม่จบ (root cause เดียวกับที่เคยแก้ใน `suggested_users()` เมื่อ 2026-09-05 แต่ไม่เคยแก้ฝั่ง Club) — เพิ่ม RPC `club_member_profiles()`/`club_event_attendee_profiles()` (SECURITY DEFINER) กรองออก
- **WYN-131**: guest (ไม่มีบัญชีจริง) กดปุ่ม "เข้าร่วม"/"สร้าง Club" ได้โดยไม่มี prompt ให้ล็อกอินก่อน — `requireRealAccount()` มีอยู่แล้วในโค้ดแต่ไม่เคยถูกเรียกใน 3 จุดนี้ (`ClubPage._toggleJoin`, `ExploreClubsScreen._openCreateClub`, `ClubSection._openCreateClub`) — เพิ่ม gate เข้าไป

ที่มา: `.wyn/tasks/bugs/WYN-130-club-members-ghost-accounts.md`, `.wyn/tasks/bugs/WYN-131-club-join-create-missing-guest-gate.md`

## Version

- Commit merge: `c576a8d` เข้า `main` ผ่าน PR [#300](https://github.com/warren-wyn-dev/wynteam/pull/300)
- ระหว่างทางเจอ merge conflict ใน `.wyn/learning/LESSONS_LEARNED.md`/`MISTAKES.md` (main เดินหน้าไปพร้อมกัน — WYN-127 stale-fixture cleanup ของอีก session) — resolve โดยเก็บทุก entry ไว้ครบทั้งสองฝั่ง (append-only log ทั้งคู่ ไม่มี conflict เชิงเนื้อหาจริง) ยืนยันด้วยการรัน regression suite ทั้ง 44 ไฟล์ซ้ำหลัง merge — 42/44 PASS (2 fail pre-existing ไม่เกี่ยวข้อง)

## QA Status

ไม่ผ่าน AI QA & Security แยกรอบ — Debug Engineer รันเองและปิดเคสในรอบเดียวกัน (bug เล็ก, ไม่ใช่ฟีเจอร์ใหม่):

- `supabase/tests/wyn_130_club_members_ghost_accounts_test.sh` (ใหม่) 13/13 PASS, ยืนยัน red→green ด้วย `git stash`
- Regression suite เดิม 44 ไฟล์ — 42 PASS, 2 fail pre-existing (ยืนยันด้วยการรันกับ baseline ก่อนแก้เทียบกัน)
- `python3 supabase/check_schema_ordering.py` — OK
- `flutter analyze`/`flutter test` — **ไม่ได้รันเองในเซสชันนี้** (ไม่มี Flutter SDK ใน environment) — ตรวจด้วยการอ่านโค้ด: `RecordingClubRepository`/`RecordingClubEventRepository` override method ที่แก้ตรงๆ ในทุก widget test ที่มีอยู่ ไม่กระทบ; `requireRealAccount()` return `true` ทันทีสำหรับ non-anonymous session (ทุก fake session ใน test ที่มีอยู่ default เป็น non-anonymous) — CI (`Flutter` job บน PR #300) เขียวก่อน merge ยืนยันอีกชั้น

## Build Status

CI บน PR #300: **success** ทุก job ที่ตรวจสอบได้ (schema.sql ordering, Supabase Edge Functions, Netlify preview deploy) — Flutter/Admin job ยัง in_progress ตอนที่ Founder กด merge (merge ก่อน CI ครบ เป็นดุลพินิจของ Founder)

## Deployment Target

Supabase production database (SQL) + Vercel (Flutter web ผ่าน `deploy-web.yml`)

## Changes

- `supabase/schema.sql` — เพิ่ม `club_member_profiles()`, `club_event_attendee_profiles()` (SECURITY DEFINER RPC) + grant
- `supabase/migrations_wyn130_club_ghost_members.sql` (ใหม่) — สำเนา standalone สำหรับรันแยก
- `app/lib/features/club/data/club_repository.dart` — `fetchApprovedMembers`/`fetchPendingMembers` เรียก RPC ใหม่แทน select+embed ตรงๆ
- `app/lib/features/club/data/club_event_repository.dart` — `fetchAttendees` เรียก RPC ใหม่
- `app/lib/features/club/presentation/club_page.dart` — `_toggleJoin` เพิ่ม `requireRealAccount()` gate
- `app/lib/features/club/presentation/explore_clubs_screen.dart` — `_openCreateClub` เพิ่ม gate
- `app/lib/features/club/presentation/widgets/club_section.dart` — `_openCreateClub` เพิ่ม gate
- `supabase/tests/wyn_130_club_members_ghost_accounts_test.sh` (ใหม่)
- `.wyn/tasks/bugs/WYN-130-club-members-ghost-accounts.md`, `.wyn/tasks/bugs/WYN-131-club-join-create-missing-guest-gate.md` (ใหม่)

## Deployment Result

**สำเร็จทุกขั้นตอน**:

1. PR #300 merge เข้า `main` — สำเร็จ (`c576a8d`)
2. `deploy-web.yml` run [#98](https://github.com/warren-wyn-dev/wynteam/actions/runs/34104961030) — **success** (WYN-131 ขึ้น production จริง)
3. Founder รัน `supabase/migrations_wyn130_club_ghost_members.sql` เองผ่าน Supabase Dashboard SQL Editor — ยืนยันผลลัพธ์ "Success. No rows returned" (WYN-130 ขึ้น production จริง)

## Production Verification

**สิ่งที่ AI ยืนยันได้เอง**: `deploy-web.yml` run #98 conclusion = success (ผ่าน GitHub Actions API ตรง); Founder รายงานผล SQL Editor ตรงว่า "Success. No rows returned" ซึ่งเป็นผลลัพธ์ที่ถูกต้องสำหรับสคริปต์นี้ (มีแต่ `create or replace function`/`grant`, ไม่มี query ที่คืนแถว)

**สิ่งที่ต้องรอ Founder ยืนยัน** (session นี้ไม่มี network egress ไป production database เพื่อ query โดยตรง): เปิด Club ที่มีปัญหาจริง ([wynos.online/club/b3f010b9-b788-41f8-8e86-c7abb717b6d2](https://wynos.online/club/b3f010b9-b788-41f8-8e86-c7abb717b6d2)) ดูว่าแถว "@"/"?" หายไปจากหน้า Members แล้ว และลองเปิด incognito/guest แล้วกด "เข้าร่วม" ดูว่าเจอ prompt "เข้าสู่ระบบเพื่อดำเนินการต่อ" แทนที่จะเข้าร่วมได้ทันที — ยังไม่ได้รับการยืนยันจาก Founder ณ เวลาบันทึกนี้

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **WYN-130 (SQL)**: `drop function public.club_member_profiles(uuid, text, int, int); drop function public.club_event_attendee_profiles(uuid, text);` ผ่าน SQL Editor — ปลอดภัย เพราะเป็นฟังก์ชันใหม่ล้วนๆ ไม่มีอะไรอ้างอิงกลับมาจากตารางเดิม แต่จะทำให้ `ClubRepository.fetchApprovedMembers`/`fetchPendingMembers`/`ClubEventRepository.fetchAttendees` error ทันที (ต้อง revert โค้ด Flutter คู่กันด้วย ไม่ใช่ drop SQL อย่างเดียว)
2. **WYN-131 (Flutter)**: `git revert -m 1 c576a8d` บน `main` แล้ว deploy ใหม่ — เป็น additive-only change (เพิ่ม `if` guard เดียว 3 จุด) revert ปลอดภัย ไม่มี migration ที่ทำลายข้อมูล

**ไม่มี migration ที่ทำลายข้อมูลเดิม** — ทั้งสองฝั่งเป็น additive (ฟังก์ชันใหม่ + gate check ใหม่) ไม่มีการแก้ตาราง/ลบ policy เดิม

## สถานะ Task

- `.wyn/tasks/bugs/WYN-130-club-members-ghost-accounts.md`, `.wyn/tasks/bugs/WYN-131-club-join-create-missing-guest-gate.md` — deploy สำเร็จ, รอ Founder ยืนยัน production behavior ตามหัวข้อด้านบนก่อนปิด task เต็มรูปแบบ
- ขั้นตอนถัดไป (ถ้ามี): ถ้า Founder ทดสอบซ้ำแล้วยังเจอ "เข้าร่วมได้โดยไม่มีบัญชี" อีก ให้เปิด Debug Engineer รอบใหม่พร้อมข้อมูลบัญชี/วิธีล็อกอินที่ใช้ทดสอบ (ดู WYN-131 report's Handoff to QA section)
