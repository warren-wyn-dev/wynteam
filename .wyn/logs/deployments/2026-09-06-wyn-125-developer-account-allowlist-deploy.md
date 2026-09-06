# Deployment — WYN-125 (Developer Account Allowlist / Staged Rollout Mechanism)

วันที่: 2026-09-06 16:51–17:04 UTC
Deploy โดย: AI Deploy & DevOps (orchestrated by this session, `session_012WhqiQtGqTNPE9BXr65dWr`)
อำนาจ: Founder อนุมัติผ่านคำถามแบบ popup ให้สร้าง PR + merge เข้า main ทันทีหลัง QA PASS, และยืนยัน username ชุดแรก (`@warren`, `@wynos_online`) ก่อน apply จริง

## Release

**WYN-125** (เดิมชื่อ WYN-124 ก่อนแก้ ID collision — ดู DECISIONS.md) — กลไก "developer account allowlist" ทั่วไปที่ใช้ซ้ำได้ข้ามฟีเจอร์: ตาราง `public.developer_accounts` (RLS, ไม่มี policy) + ฟังก์ชัน `public.is_developer_account()` (SECURITY DEFINER, fail-closed) + `DeveloperAccessService` ฝั่ง client + 2 GitHub Actions workflow สำหรับ Founder จัดการ allowlist เอง — **ยังไม่มีฟีเจอร์ไหนถูกผูกกับ flag นี้จริงในรอบนี้** (ส่งมอบแค่กลไก ตามขอบเขตที่ Design/Product spec กำหนด)

ที่มา: Founder ถามปรึกษาว่า deploy WYNOS ตอนนี้อัปเดตทุกเครื่องพร้อมกัน อยากอัปเดตไปหาบัญชีนักพัฒนาก่อน — ดู `.wyn/company/DECISIONS.md` entry "[2026-09-06] Staged Rollout สำหรับ WYNOS"

## Version

- Commit merge: `616b928` เข้า `main` ผ่าน PR [#285](https://github.com/warren-wyn-dev/wynteam/pull/285)
- ระหว่างทางเจอ ID collision จริง (WYN-124 ชนกับ "Club Invite Notification" ของอีก session ที่ merge เข้า main ไปก่อน) — rename เป็น WYN-125 ทั้งหมด ก่อน merge, และเจอ merge conflict ใน `schema.sql`/`DECISIONS.md` ถึง 2 รอบ (main เดินหน้าไปเร็วมากระหว่างที่ PR เปิดอยู่ — WYN-118 Club Events landed ระหว่างทาง) — resolve โดยเก็บทุก section ไว้ครบ ไม่มี logic ถูกทับ ยืนยันด้วยการรัน `psql -f schema.sql` จริงบน Postgres local หลัง merge (ไม่มี error ใหม่ ทุก error ที่เจอเป็น pre-existing "schema storage does not exist" ที่ไม่เกี่ยวกับงานนี้)
- รายละเอียดเต็มของ ID collision: `.wyn/company/DECISIONS.md` entry "[2026-09-06] ID collision: WYN-124 ชนกันอีกครั้ง (ครั้งที่ 5)"

## QA Status

**PASS** (2026-09-06) — `.wyn/tasks/active/WYN-125-staged-rollout-developer-first.md` "AI QA & Security Output" — รันจริงเอง (ไม่เชื่อรายงานจาก AI Coding เฉยๆ): `supabase/tests/wyn_125_developer_accounts_test.sh` 20/20 PASS, regression suite เดิม 37/38 PASS (1 fail pre-existing ไม่เกี่ยวข้อง ยืนยันด้วย `git worktree`), `flutter analyze` 0 issues, `flutter test` 1293/1293 — CI บน PR #285 เขียวครบทุก job (Flutter, Admin, Supabase Edge Functions, schema.sql ordering)

## Build Status

CI run บน PR #285 ก่อน merge: **success** ครบทุก job — ไม่มี `deploy-web.yml` (Vercel) run ในรอบนี้ เพราะงานนี้ไม่แตะ UI/client behavior ที่สังเกตเห็นได้ (ไม่จำเป็นต้อง deploy web ใหม่ — schema + workflow เท่านั้นที่ต้อง apply)

## Deployment Target

Supabase production database (ผ่าน Supabase Management API, ไม่ใช่ Vercel/web)

## Changes

- `supabase/schema.sql` — เพิ่ม section "WYN-125" (ตาราง `developer_accounts` + ฟังก์ชัน `is_developer_account()` + grant execute)
- `.github/workflows/wyn125-apply-developer-accounts-schema.yml` (ใหม่) — apply-to-production workflow
- `.github/workflows/wyn125-manage-developer-accounts.yml` (ใหม่) — list/add/remove developer account โดย username
- `app/lib/core/developer_access/developer_access_service.dart` (ใหม่) — client accessor, **ยังไม่มีจุดเรียกใช้จริงในแอป**
- `supabase/tests/wyn_125_developer_accounts_test.sh` (ใหม่)
- **ไม่มี UI ใดถูกแก้** — ผู้ใช้ทั่วไป 100% ไม่เห็นความเปลี่ยนแปลงใดๆ เลย

## Deployment Result

**สำเร็จทุกขั้นตอน**:

1. PR #285 merge เข้า `main` — สำเร็จ (`616b928`)
2. รัน `wyn125-apply-developer-accounts-schema.yml` (run [#1](https://github.com/warren-wyn-dev/wynteam/actions/runs/34047193295)) — **success**, สร้างตาราง+ฟังก์ชัน+grant บน production จริง
3. รัน `wyn125-manage-developer-accounts.yml` action=add username=warren (run [#1](https://github.com/warren-wyn-dev/wynteam/actions/runs/34047386089)) — **success**
4. รัน `wyn125-manage-developer-accounts.yml` action=add username=wynos_online (run [#2](https://github.com/warren-wyn-dev/wynteam/actions/runs/34047409679)) — **success**
5. รัน `wyn125-manage-developer-accounts.yml` action=list (run [#3](https://github.com/warren-wyn-dev/wynteam/actions/runs/34047434560)) — ยืนยัน log จริง: ทั้งสอง username อยู่ใน `developer_accounts` แล้ว

## Production Verification

**ยืนยันได้เองจริงผ่าน GitHub Actions job log ตรง** (ไม่ใช่แค่ workflow "success" เฉยๆ — อ่าน log ของ action=list ที่ query ตาราง `developer_accounts` join `profiles` จริง):

```json
[
  {"username": "warren", "label": "Added via GitHub Actions (warren)", "added_at": "2026-09-06 17:03:33+00"},
  {"username": "wynos_online", "label": "Added via GitHub Actions (wynos_online)", "added_at": "2026-09-06 17:03:58+00"}
]
```

**ข้อจำกัดของการยืนยันรอบนี้**: นี่คือ infrastructure ที่ไม่มี UI ผูกอยู่เลย — จึงไม่มี "ลองใช้จริงในเบราว์เซอร์" ให้ทำ (ไม่มีอะไรให้กดในแอป flag นี้ยังไม่ถูกเรียกจากที่ไหนเลย) การยืนยันที่ทำได้สูงสุดในตอนนี้คือระดับ database (ตาราง/ฟังก์ชัน/allowlist ถูกต้องตาม QA spec) ซึ่งทำครบแล้ว — **เมื่อมีฟีเจอร์จริงในอนาคตมาผูกกับ `isDeveloperAccount()`** งานนั้นจะต้องผ่าน Production Verification ของตัวเองอีกรอบ (ตาม WORKFLOW.md) ก่อนถือว่า flag ใช้งานได้จริงในทางปฏิบัติ

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **ปิดการเข้าถึงทันทีโดยไม่ต้อง deploy ใหม่**: รัน `wyn125-manage-developer-accounts.yml` action=remove ลบ username ที่ต้องการออกจาก allowlist — ปลอดภัย 100% เพราะ fail-closed อยู่แล้ว (ลบคนออกแล้วคนนั้นกลับไปเป็น `false` เหมือนผู้ใช้ทั่วไปทันที)
2. **ถอด mechanism ทั้งหมด**: `drop function public.is_developer_account(); drop table public.developer_accounts;` ผ่าน Supabase Management API — ปลอดภัยเพราะไม่มีโค้ด client ใดเรียกใช้ฟังก์ชันนี้อยู่เลยในรอบนี้ (ไม่มี breaking dependency)
3. **ระดับ git**: `git revert -m 1 616b928` บน `main` — เป็น additive-only change ทั้งหมด revert ได้ปลอดภัย

**ไม่มี migration ที่ทำลายข้อมูลเดิม** — ตารางใหม่ทั้งหมด ไม่มีการแก้ตาราง/ฟังก์ชันที่มีอยู่ก่อนเลย

## สถานะ Task

- `.wyn/tasks/active/WYN-125-staged-rollout-developer-first.md` → ย้ายไป `.wyn/tasks/approved/` (mechanism deploy สำเร็จและยืนยันระดับ database แล้ว) — **ยังไม่ `completed`** เพราะเป็น infrastructure ที่รอฟีเจอร์จริงมาผูกใช้งานก่อนถึงจะถือว่า "ใช้งานได้จริงตามที่ Founder ต้องการ" ครบวงจร (ปิด task เต็มรูปแบบเมื่อมีฟีเจอร์แรกทดสอบผ่าน flag นี้สำเร็จ)
- ขั้นตอนถัดไป: เมื่อมีฟีเจอร์ใหม่ที่ Founder ต้องการ staged-rollout ให้ AI Design/AI Coding เรียก `DeveloperAccessService.isDeveloperAccount()` ตามตัวอย่างใน design doc (`.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md`)
