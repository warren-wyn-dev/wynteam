# Deployment — WYN-120: ลบโพสต์แล้วหน้าโปรไฟล์ไม่หาย

วันที่: 2026-09-06 08:14–08:17 UTC
Deploy โดย: AI Deploy & DevOps (session `session_013hvSGovkwhxpPFbFEKAvAu`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team — Founder สั่ง deploy ตรงๆ ("AI Deploy & DevOps แล้ว deploy ขึ้น production เลย")

## Release

WYN-120 — แก้บั๊ก `DropRepository.fetchById()` ไม่ filter `deleted_at` ทำให้เจ้าของโพสต์ที่เพิ่งลบโพสต์ตัวเองยังเห็นโพสต์นั้นค้างอยู่ในหน้าโปรไฟล์/ถูกใจ/hashtag feed (RLS author-exception ของ WYN-037 ทำให้ query เดิมยังคืนแถวที่ถูกลบกลับมา)

## Version

Commit: `8e42ae9` (feature branch) → merge commit `02b5a21` เข้า `main` ผ่าน PR #276
PR: https://github.com/warren-wyn-dev/wynteam/pull/276

## QA Status

**หมายเหตุสำคัญ — ไม่ผ่าน flow QA ปกติแบบ 6 บทบาทเต็ม**: งานนี้ Founder รายงานบั๊กสดโดยตรง (ไม่ผ่าน AI QA & Security ก่อน) ผมในบทบาท AI Debug Engineer เป็นผู้ reproduce/หา root cause/แก้/verify เอง โดยพิสูจน์ด้วย regression test จริงที่รันกับ PostgreSQL 16 local + `schema.sql` จริง + RLS จริง (`supabase/tests/wyn_120_delete_drop_not_disappearing_from_profile_test.sh` — 6 checks, ALL PASSED) แทนการมี AI QA & Security อีกคนตรวจซ้ำอิสระ — Founder เป็นผู้ merge PR เข้า `main` เองโดยตรง (ถือเป็นการอนุมัติของ Founder เอง ซึ่งมีอำนาจสูงสุดอยู่แล้วตาม RULES.md) แล้วสั่ง deploy ต่อทันที

## Build Status

- CI บน PR #276 (commit `8e42ae9`, run #209): **success ทั้งหมด** — `Flutter` (analyze+test — ตรวจยืนยันย้อนหลังหลัง merge แล้วว่า conclusion: success, ไม่ใช่แค่เชื่อว่าน่าจะผ่าน), `Admin (Next.js)`, `Supabase Edge Functions`, `schema.sql ordering`
- `deploy-web.yml` run #90 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34021289825), triggered บน `main` @ `02b5a21`: **success** ครบทุก step (08:14:15–08:17:00 UTC)

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Changes

- `app/lib/features/drop/data/drop_repository.dart` — `fetchById()`: เพิ่ม `.isFilter('deleted_at', null)`
- `supabase/tests/wyn_120_delete_drop_not_disappearing_from_profile_test.sh` (ใหม่) — regression test
- `.wyn/tasks/bugs/WYN-120-*.md`, `.wyn/learning/{LESSONS_LEARNED,MISTAKES}.md` — เอกสารประกอบ
- **ไม่มี migration ไม่มี schema/RLS เปลี่ยน** — เป็น client-side Dart query change ล้วนๆ (เพิ่ม filter ให้เข้มงวดขึ้นเท่านั้น)

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #90 status `success` ครบทุก step

## Production Verification

**สิ่งที่ AI ยืนยันได้เอง (curl ตรงต่อ production จริง, ไม่ใช่แค่เชื่อ workflow log):**

| ตรวจสอบ | ผล |
|---|---|
| `GET /` | HTTP 200 |
| `GET /drop/x` (SPA rewrite ของ WYN-114 ไม่พัง) | HTTP 200 — regression check |
| `/og-image.png` md5 | `76b00bbf...` ตรงกับไฟล์ที่ commit เป๊ะ — ไม่ถูกแตะ |
| `main.dart.js` เป็น build ใหม่จริง (ไม่ใช่ cache เดิม) | `Last-Modified: 2026-09-06 08:17:43 UTC` — ตรงกับช่วงเวลาที่ deploy เพิ่งเสร็จ (run เสร็จ 08:17:00) ไม่ใช่ build เก่าค้าง |
| bundle มีการอ้างอิง `deleted_at` string literal | พบ 8 จุด (string literal ของ Postgrest column name รอดจากการ minify เพราะเป็น runtime argument ไม่ใช่ Dart identifier) — สอดคล้องกับโค้ดที่ deploy |

**สิ่งที่ยืนยันเองไม่ได้ ต้องรอ Founder ทดลองใช้จริง** (ตาม `.wyn/company/WORKFLOW.md` หัวข้อ "Production Verification คือใครยืนยัน"): บั๊กนี้เป็นพฤติกรรมฝั่ง client ที่ต้อง login จริงถึงจะทดสอบได้ (ลบโพสต์ของตัวเอง → ต้องเห็นมันหายจากหน้าโปรไฟล์ทันทีโดยไม่ต้อง reload) sandbox นี้ไม่มี Supabase auth session จริงให้ทดสอบ end-to-end แบบ interactive ได้ — **รอ Founder ยืนยันด้วยการลองลบโพสต์จริงบนแอปว่าหายจากโปรไฟล์ทันทีหรือไม่**

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #90 (run #89 — WYN-114) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 02b5a21` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น client-side query filter ล้วนๆ ย้อนกลับได้ปลอดภัย 100%

## สถานะ Task

ย้าย `.wyn/tasks/bugs/WYN-120-*.md` → `.wyn/tasks/completed/` ได้เมื่อ **Founder ยืนยันแล้วว่าลบโพสต์จริงแล้วหายจากโปรไฟล์ทันที** (ตาม WORKFLOW.md — deploy สำเร็จทางเทคนิคอย่างเดียวไม่พอ) ระหว่างนี้คงไว้ที่ `.wyn/tasks/bugs/` พร้อม status อัปเดตแล้ว
