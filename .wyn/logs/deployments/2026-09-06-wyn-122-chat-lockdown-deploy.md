# Deployment — WYN-122: ปิดระบบแชท 1-on-1 ชั่วคราว เหลือเฉพาะ @warren ↔ @wynos_online

วันที่: 2026-09-06 10:42–10:48 UTC
Deploy โดย: AI Deploy & DevOps (session `session_013hvSGovkwhxpPFbFEKAvAu`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team — งานนี้ผ่าน Product → Design → Coding → QA FAIL → Debug Engineer → QA PASS (ยืนยันอิสระ 2 รอบ) ครบตาม WORKFLOW.md แล้ว และ Founder สั่งเปิดใช้งานจริงตรงๆ

## Release

WYN-122 — ปิดระบบแชท 1-on-1 ชั่วคราว เหลือเฉพาะคู่ @warren ↔ @wynos_online (Founder: "ปิดระบบ แชทไม่ให้คนใช้ทั่วไป ยกเว้น @warren กับ @wynos_online จะเอาไว้ทดสอบ ก่อนเปิดใช้งานจริง")

## Version

Commit: `fdf884d` (merge commit เข้า `main` ผ่าน PR #279)
PR: https://github.com/warren-wyn-dev/wynteam/pull/279

## QA Status

**PASS** (2 รอบ) — รอบแรก **FAIL** พบ `internal.chat_pair_allowed()` ขาด `grant execute ... to authenticated` (ยืนยันด้วยการ revoke จริงแล้วเห็น RLS พัง) → AI Debug Engineer แก้ (commit `b7f6417`) → QA รอบ 2 ยืนยันอิสระใหม่ทั้งหมด (database ใหม่, revoke/verify cycle เขียนเอง, `has_function_privilege()`, regression suite 18/18 + 5 ชุดเดิม) — **PASS** ดู `.wyn/tasks/approved/WYN-122-chat-lockdown-testers-only.md`

## Build Status

- CI บน PR #279 (commit ล่าสุด `7fbc431`): **success ทั้งหมด** (Flutter analyze+test, Admin, Supabase Edge Functions, schema.sql ordering)
- `deploy-web.yml` run #92 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34028258131): **success**

## Deployment Target

- Client: Vercel project "web" → `https://wynos.online`
- Backend: Supabase production project (ผ่าน GitHub Actions workflow, ไม่ใช่ manual SQL)

## Changes

- `supabase/schema.sql` — ตาราง `chat_lockdown`/`chat_lockdown_allowlist` ใหม่, ฟังก์ชัน `internal.chat_pair_allowed()`/`public.chat_lockdown_status()` ใหม่, แก้ `get_or_create_conversation()`/`count_unread_conversations()`, แก้ RLS policy 4 จุด
- `app/lib/features/chat/**`, `app/lib/features/profile/presentation/view_profile_screen.dart` — UI state "Locked" 3 จุด + SnackBar เฉพาะ 1 จุด
- **ไม่มีการลบ/แก้ไขข้อมูลเดิมใดๆ** — เป็น additive schema change + RLS ที่เข้มงวดขึ้นเท่านั้น

## Deployment Steps ที่ทำจริง (ตามลำดับ)

1. Merge PR #279 เข้า `main` (merge commit `fdf884d`)
2. รัน `wyn122-apply-chat-lockdown-schema.yml` บน `main` — สร้างตาราง/ฟังก์ชัน/RLS ทั้งหมดบน production จริง, resolve `@warren`/`@wynos_online` เป็น id จริงจาก username (ไม่ hardcode), populate allowlist — **สำเร็จ**, `chat_lockdown.enabled` ยังเป็น `false` ตามที่ตั้งใจ (แยก "ส่งกลไก" ออกจาก "เปิดสวิตช์")
3. รัน `wyn122-toggle-chat-lockdown.yml` ด้วย `action=enable` — เปิด lockdown จริงตามคำสั่ง Founder — **สำเร็จ**, `enabled` เปลี่ยนจาก `false` → `true` ยืนยันแล้ว
4. รัน `deploy-web.yml` (run #92) — deploy client build ใหม่ที่มี UI "Locked" state ครบ — **สำเร็จ**
5. รัน `wyn122-toggle-chat-lockdown.yml` ด้วย `action=status` (read-only) อีกครั้งเพื่อยืนยันสถานะสุดท้าย — **ยืนยัน `enabled: true` และ allowlist ถูกต้อง**

## Production Verification

**สิ่งที่ AI ยืนยันได้เอง (query/curl ตรงต่อ production จริง):**

| ตรวจสอบ | ผล |
|---|---|
| Allowlist บน production มีตรงกับ `@warren`/`@wynos_online` จริง | ✅ `warren` → `73429040-c7e9-4d5a-9285-5cdf7863a890`, `wynos_online` → `2447abdc-37ee-408f-9ce9-a8a5270b350d` (id หลังตรงกับที่เคยเห็นในงาน WYN-120/121 ก่อนหน้า — cross-check ตรงกัน) |
| `chat_lockdown.enabled` | ✅ `true` (เปิดใช้งานจริงแล้ว) |
| `GET /` | HTTP 200 |
| `GET /drop/x` (SPA rewrite, regression check จาก WYN-114) | HTTP 200 |
| `/og-image.png` md5 | `76b00bbf...` ตรงกับไฟล์ commit เป๊ะ — ไม่ถูกแตะ |
| `main.dart.js` เป็น build ใหม่จริง | `Last-Modified: 2026-09-06 10:47:49 UTC` ตรงกับช่วงเวลา deploy พอดี |
| Bundle มี string ของฟีเจอร์ใหม่จริง | พบ `chat_lockdown_status`/`temporarily closed for testing`/"ระบบแชทปิดปรับปรุงชั่วคราว" ใน `main.dart.js` ที่ deploy จริง |

**สิ่งที่ยืนยันเองไม่ได้ ต้องรอ Founder ทดลองใช้จริง**: พฤติกรรม UI แบบ end-to-end บนอุปกรณ์จริง (เปิดแอป → กดไอคอนแชท → เห็นข้อความ "ระบบแชทปิดปรับปรุงชั่วคราว" จริงไหม, ลองแชทกับ @wynos_online จากบัญชี @warren ว่าใช้งานได้ปกติจริงไหม) — sandbox นี้ไม่มี Supabase auth session จริงให้ทดสอบ interactive ได้

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **ปิด lockdown กลับคืนทันที (เร็วที่สุด, ไม่ต้อง deploy ใหม่)**: รัน GitHub Actions workflow `wyn122-toggle-chat-lockdown.yml` ด้วย `action=disable` — แชทกลับมาใช้งานได้ปกติสำหรับทุกคนทันที ไม่มีข้อมูลสูญหาย (นี่คือกลไกที่สร้างไว้ตาม Product spec's R2 โดยเฉพาะสำหรับจุดประสงค์นี้)
2. **Vercel Instant Rollback** (เฉพาะ UI): Vercel Dashboard → project "web" → Deployments → เลือก deployment ก่อนหน้า run #92 (run #91) → Promote to Production
3. **Schema**: ไม่มีการลบ/แก้ไขข้อมูลเดิมเลย — ถ้าต้องการเอากลไกออกทั้งหมด (ไม่ใช่แค่ปิดสวิตช์) ต้องขออนุมัติ Founder ก่อนเสมอ (drop table/function เป็นการเปลี่ยนแปลงโครงสร้างที่ทำลายล้างได้)

## สถานะ Task

ย้าย `.wyn/tasks/approved/WYN-122-chat-lockdown-testers-only.md` → `.wyn/tasks/completed/` ได้เมื่อ **Founder ยืนยันแล้วว่าใช้งานจริงได้ตามที่ต้องการ** (ตาม WORKFLOW.md — deploy สำเร็จทางเทคนิคอย่างเดียวไม่พอ) ระหว่างนี้คงไว้ที่ `approved/` พร้อม log นี้อ้างอิง
