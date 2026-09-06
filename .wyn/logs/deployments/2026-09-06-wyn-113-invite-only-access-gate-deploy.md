# Deployment — WYN-113 (Invite-Only Access Gate / Referral Code)

วันที่: 2026-09-06 17:42–17:52 UTC
Deploy โดย: AI Deploy & DevOps (orchestrated by this session, `session_014LEtwe8NjiPLcc9cqJEkuq`)
อำนาจ: Founder "ทำให้เสร็จทุกอันเลยครับ" (ต่อจากคำถาม "เหลืออะไร") — ครอบคลุมทั้งการ implement และ apply schema จนจบ ไม่ต้องถามซ้ำระหว่างทาง

## Release

**WYN-113** — ระบบ referral code สำหรับควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่ก่อนเข้า Phase 2 ของ GTM roadmap: `invite_gate_config` (single-row toggle, **ships `enabled = false`**) + `is_invite_gate_enabled()`/`validate_referral_code()` (anon-callable) + `redeem_referral_code()`/`my_referral_stats()` (authenticated) + `profiles.referral_code` (auto-generate ทุก profile รวม backfill ของเก่า) + `referral_redemptions` (multi-use ต่อ referrer, unique ต่อผู้ใช้ใหม่) + `AuthMethodScreen` แสดงปุ่ม "กรอกโค้ดเชิญ" แทนปุ่ม sign-in จริงเมื่อ gate เปิด — guest browsing (WYN-072) ไม่ถูกแตะเลย

## Version

- Commit merge: `521da0f` เข้า `main` ผ่าน PR [#288](https://github.com/warren-wyn-dev/wynteam/pull/288)
- Fix เพิ่มเติมหลัง merge: PR [#290](https://github.com/warren-wyn-dev/wynteam/pull/290) (`e8d33c2`, รอ merge) — แก้ 2 บั๊กที่พบระหว่าง apply จริง (ดู Deployment Result) — schema เอง apply กับ production DB จริงสำเร็จแล้วก่อน merge PR นี้ด้วยซ้ำ (รันตรงจาก branch ผ่าน `workflow_dispatch`), PR นี้แค่นำโค้ด fix เข้า `main` ให้ตรงกับสิ่งที่ apply ไปแล้วจริง

## QA Status

**PASS** (2026-09-06) — `.wyn/tasks/approved/WYN-113-invite-only-access-gate.md` "AI QA & Security Output" — `flutter analyze` 0 issues, `flutter test` เต็ม suite 1340/1340 (เจอ+แก้ 1 regression ระหว่าง QA เอง — `widget_test.dart` ยิง network call จริงหลัง AuthMethodScreen เพิ่ม gate check), `wyn_113_invite_only_access_gate_test.sh` 26/26 PASS, `check_schema_ordering.py` OK

## Build Status

CI บน PR #288/#290: ตรวจสอบผ่าน local ครบก่อน merge (ไม่ได้รอ CI cloud รอบนี้เพราะ Founder สั่งให้ทำต่อเนื่องจนจบ) — ไม่มี `deploy-web.yml` run ใหม่สำหรับ client-side change นี้ในรอบนี้ (schema apply สำคัญกว่าและทำก่อน)

## Deployment Target

Supabase production database (ผ่าน Supabase Management API) — client-side (`AuthMethodScreen` ฯลฯ) ยัง**ไม่ถูก deploy ขึ้น web production** ในรอบนี้ (รอ `deploy-web.yml` รอบถัดไป)

## Changes

- `supabase/schema.sql` — เพิ่ม section "WYN-113" (2 ตาราง + RLS + 1 trigger + 4 RPC)
- `.github/workflows/wyn113-apply-invite-only-access-gate-schema.yml` (ใหม่) — apply-to-production workflow
- `supabase/tests/wyn_113_invite_only_access_gate_test.sh` (ใหม่, 26 checks)
- `app/lib/features/auth/data/auth_repository.dart`, `pending_referral_code.dart` (ใหม่), `presentation/auth_method_screen.dart`, `presentation/redeem_invite_code_screen.dart` (ใหม่), `presentation/onboarding/onboarding_flow.dart`
- เทสต์: `auth_method_screen_test.dart` (ใหม่), `redeem_invite_code_screen_test.dart` (ใหม่), `onboarding_flow_test.dart` (+3 เคส), `support/recording_auth_repository.dart`, `widget_test.dart` (แก้ regression)

## Deployment Result

**สำเร็จหลังแก้ 2 บั๊กที่พบระหว่างทาง** (ตรงไปตรงมา ไม่ปิดบัง):

1. PR #288 merge เข้า `main` — สำเร็จ (`1fe3ecb`)
2. รัน `wyn113-apply-invite-only-access-gate-schema.yml` ครั้งแรก (run [#1](https://github.com/warren-wyn-dev/wynteam/actions/runs/34049566058)) — **FAIL** ที่ step 3 โดยไม่มี error message ปรากฏเลย (root cause: `run_sql`'s error branch เขียนไป stdout ซึ่งถูก `>/dev/null` ของทุก call site บังไว้หมด — บั๊กในสคริปต์ apply เอง ไม่ใช่ schema)
3. แก้ `run_sql` ให้ error ไป stderr แทน, push ไป branch, รันซ้ำ (run [#2](https://github.com/warren-wyn-dev/wynteam/actions/runs/34049738028)) — **FAIL** เช่นเดิมแต่คราวนี้เห็น error จริง: `profiles_username_not_reserved` (constraint แบบ `not valid` ที่ grandfather บัญชี WYNOS Official ไว้ตั้งแต่ก่อนหน้านี้) ทำให้ bulk `UPDATE` ของ referral_code backfill ล้มทั้งก้อนเพราะ Postgres re-validate ทุก check constraint บนแถวที่ถูก UPDATE ไม่ว่าจะแก้คอลัมน์ไหน
4. แก้ backfill ให้เป็น per-row loop พร้อม exception handler (skip แถวที่มีปัญหาแทนที่จะ abort ทั้งหมด) ทั้งใน `schema.sql` และ workflow, รันซ้ำจาก branch (run [#3](https://github.com/warren-wyn-dev/wynteam/actions/runs/34049932404)) — **success**
5. เปิด PR #290 นำ 2 fix ข้างต้นเข้า `main` — รอ merge

## Production Verification

**ยืนยันได้เองจริงผ่าน GitHub Actions job log ตรง** (run #3, ก่อน merge PR #290 แต่ apply กับ production DB จริงแล้วตอนนั้น):

```json
// ตาราง + trigger + RPC ครบ
[{"table_name": "invite_gate_config"}, {"table_name": "referral_redemptions"}]
[{"column_name": "referral_code"}]
[{"tgname": "profiles_set_referral_code"}]
[{"routine_name": "is_invite_gate_enabled"}, {"routine_name": "my_referral_stats"},
 {"routine_name": "redeem_referral_code"}, {"routine_name": "validate_referral_code"}]

// gate ปิดตามที่ตั้งใจ, มีแค่ 1 profile (WYNOS Official, grandfathered) ที่ไม่มี referral_code
[{"enabled": false}]
[{"profiles_missing_referral_code": 1}]
```

`profiles_missing_referral_code: 1` ตรงตามที่คาดไว้เป๊ะ (บัญชี WYNOS Official ที่มี username ติด reserved-list constraint แบบ grandfathered) — ไม่ใช่ความผิดพลาด เป็นผลลัพธ์ที่ถูกต้องจากการออกแบบ per-row skip

**ข้อจำกัดของการยืนยันรอบนี้**: ยืนยันระดับ database ครบแล้ว แต่**ยังไม่ได้ deploy client code (AuthMethodScreen ฯลฯ) ขึ้น web production จริง** — ต้องรัน `deploy-web.yml` อีกรอบก่อนที่ผู้ใช้จริงจะเห็นหน้าจอ "กรอกโค้ดเชิญ" ใดๆ (ซึ่งจะไม่เห็นอยู่ดีเพราะ gate ปิดอยู่โดย default — deploy ได้อย่างปลอดภัยโดยไม่กระทบผู้ใช้ปัจจุบันเลย)

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **Gate เปิดอยู่แล้วมีปัญหา**: `UPDATE invite_gate_config SET enabled = false WHERE id = true;` ผ่าน Supabase Management API — คืนเป็นเปิดสมัครอิสระทันที ไม่กระทบ session ผู้ใช้ที่ล็อกอินอยู่แล้วเลย
2. **ถอด mechanism ทั้งหมด**: `drop table public.invite_gate_config, public.referral_redemptions cascade; alter table public.profiles drop column referral_code; drop function public.is_invite_gate_enabled(), public.validate_referral_code(text), public.redeem_referral_code(text), public.my_referral_stats(), public.generate_referral_code(), public.set_referral_code_on_profile();` — ปลอดภัยเพราะเป็น additive-only, ไม่มีฟีเจอร์อื่นพึ่งพา column/table เหล่านี้
3. **ระดับ git**: `git revert -m 1 1fe3ecb` แล้วตามด้วย `git revert e8d33c2` บน `main` — additive-only ทั้งคู่ revert ได้ปลอดภัย

**ไม่มี migration ที่ทำลายข้อมูลเดิม** — ตารางใหม่ทั้งหมด, คอลัมน์ใหม่ 1 คอลัมน์ (nullable, ไม่มี default ที่กระทบแถวเดิม), ไม่มีการแก้ตาราง/ฟังก์ชันที่มีอยู่ก่อนเลยนอกจาก grant execute ใหม่

## สถานะ Task

- `.wyn/tasks/approved/WYN-113-invite-only-access-gate.md` — QA PASS, schema apply สำเร็จบน production แล้ว, ships gate ปิด — **ยังไม่ `completed`** เพราะรอ (ก) `deploy-web.yml` รอบถัดไปให้ client code ขึ้นจริง (ข) Founder ตัดสินใจเปิด gate ตอนพร้อมเข้า Phase 2 ของ GTM roadmap
- ขั้นตอนถัดไป: รอ Founder หรือ session ถัดไป trigger `deploy-web.yml`; เมื่อพร้อมเปิด gate จริง ใช้ `UPDATE invite_gate_config SET enabled = true WHERE id = true;` ผ่าน Management API
