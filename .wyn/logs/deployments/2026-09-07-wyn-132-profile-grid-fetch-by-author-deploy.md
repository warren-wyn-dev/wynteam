# Deployment — WYN-132: ลบโพสต์แล้วหน้าโปรไฟล์ไม่หาย (ยังไม่หาย แม้รีเฟรชทั้งหน้าใหม่)

วันที่: 2026-09-07 11:23–11:38 UTC
Deploy โดย: AI Debug Engineer / AI Deploy & DevOps (session นี้)
อำนาจ: Founder สั่งตรงๆ ในแชท ("PR และ deploy ต่อเลย") — ตาม `.wyn/company/RULES.md` "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team อยู่แล้ว และ Founder มีอำนาจสูงสุดสั่ง deploy ตรงได้เสมอ (precedent เดียวกับ WYN-120)

## Release

WYN-132 — แก้ `DropRepository.fetchByAuthor()` ไม่ filter `deleted_at` ทำให้หน้าโปรไฟล์ (แท็บ Drops) ยังแสดงโพสต์ที่เพิ่งลบไปแล้ว แม้ปิดแท็บ/รีเฟรชหน้าใหม่ทั้งหมด — บั๊กคนละตัวกับ WYN-120 (ซึ่งแก้ `fetchById()` ไปแล้วและยัง deploy ถูกต้อง) รายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-132-profile-grid-fetch-by-author-missing-deleted-at-filter.md`

## Version

Commit: `be24105` (feature branch `claude/post-delete-not-removed-1zvs1r`) → merge commit `dc7f968` เข้า `main` ผ่าน PR #305 (Founder merge เอง)
PR: https://github.com/warren-wyn-dev/wynteam/pull/305

## QA Status

**หมายเหตุสำคัญ — ไม่ผ่าน flow QA ปกติแบบ 6 บทบาทเต็ม เหมือน WYN-120**: Founder รายงานบั๊กสดเอง ผมในบทบาท AI Debug Engineer เป็นผู้ reproduce/หา root cause/แก้/verify เอง ด้วย regression test จริงที่รันกับ PostgreSQL 16 local + `schema.sql` จริง + RLS จริง (`supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh` — 8/8 checks ALL PASSED) + รีรัน `wyn_120_*` (6/6) และ `wyn_037_*` (23/23) ยืนยันไม่มี cross-task regression — Founder เป็นผู้ merge PR เข้า `main` เองโดยตรง (ถือเป็นการอนุมัติของ Founder เอง) แล้วสั่ง deploy ต่อทันที

## Build Status

- CI บน PR #305 (commit `be24105`, run #299/34116417438): `schema.sql ordering`/`Admin (Next.js)`/`Supabase Edge Functions` = success, `Flutter` (analyze ผ่าน) แต่ **`flutter test` แดง 1/1386** — ตรวจสอบแล้วยืนยันว่า **ไม่เกี่ยวกับการเปลี่ยนแปลงนี้เลย**:
  - Test ที่แดง: `club_posts_tab_test.dart: a full page of posts shows a "ดูโพสต์เพิ่มเติม" button that loads the next page` — `A Timer is still pending even after the widget tree was disposed` (`GoTrueClient.startAutoRefresh` timer leak ใน `RecordingClubPostRepository`'s fake `SupabaseClient`) — ไม่แตะ `DropRepository`/`ProfileDropGridTab` เลยแม้แต่บรรทัดเดียว
  - รีรัน failed job 1 ครั้ง (`rerun_failed_jobs`) เพื่อพิสูจน์ว่าเป็น flake — **ล้มเหลวซ้ำแบบเป๊ะทุกประการ** (stack trace เดียวกัน) → ไม่ใช่ flake เป็นบั๊กจริงที่ deterministic
  - ตรวจ CI ของ `main` ย้อนหลัง พบว่า **แดงมาตั้งแต่ก่อน PR #305 จะถูกสร้างด้วยซ้ำ**: PR #304 merge (`81ca692`, run 34111287568) และ PR #303 merge (`5a84318`, run 34110505254) ล้มเหลวด้วย test/stack trace เดียวกันเป๊ะทุกตัวอักษร ส่วน PR #302 (`e280995`) ยังเขียวอยู่ — สรุปว่า **regression นี้ถูกนำเข้ามาโดยงาน WYN-130 (ghost-account-fix, PR #303/#304) ไม่เกี่ยวกับ WYN-132 นี้เลย**
  - **ไม่ block การ deploย รอบนี้**: `deploy-web.yml` รัน `flutter build web --release` เท่านั้น ไม่รัน `flutter test` จึงไม่ถูกกระทบ — แต่บันทึกไว้ที่นี่เพื่อความโปร่งใส และแจ้ง Founder แล้วในแชทว่า `main`'s CI แดงค้างอยู่ 3 merge ติดกัน ยังไม่มีใครแก้ — เสนอเปิด task แยกให้แก้ (ยังไม่ได้รับคำตอบ ณ เวลา deploy นี้)
- `deploy-web.yml` run #101 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34117418649), triggered บน `main` @ `dc7f968` (workflow_dispatch): **success** ครบทุก step (11:35:40–11:38:26 UTC)

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Changes

- `app/lib/features/drop/data/drop_repository.dart` — `fetchByAuthor()`: เพิ่ม `.isFilter('deleted_at', null)`
- `supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh` (ใหม่) — regression test
- `.wyn/tasks/bugs/WYN-132-*.md` (ใหม่), `WYN-120-*.md` (cross-ref), `.wyn/learning/{LESSONS_LEARNED,MISTAKES}.md` — เอกสารประกอบ
- **ไม่มี migration ไม่มี schema/RLS เปลี่ยน** — เป็น client-side Dart query change ล้วนๆ (เพิ่ม filter ให้เข้มงวดขึ้นเท่านั้น) เหมือน WYN-120 ทุกประการ

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #101 status `success` ครบทุก step

## Production Verification

**สิ่งที่ AI ยืนยันได้เอง (curl ตรงต่อ production จริง):**

| ตรวจสอบ | ผล |
|---|---|
| `GET /` | HTTP 200 |
| `GET /drop/x` (SPA rewrite ของ WYN-114 ไม่พัง) | HTTP 200 — regression check |
| `main.dart.js` เป็น build ใหม่จริง | `Last-Modified: 2026-09-07 11:38:48 UTC` — ตรงกับเวลาที่ deploy เพิ่งเสร็จ (run เสร็จ 11:38:26 UTC) ไม่ใช่ build เก่าค้าง, `cache-control: public, max-age=0, must-revalidate` (ไม่มี stale cache ฝั่ง server/CDN) |
| workflow run's `head_sha` ตรงกับ commit ที่มี fix จริง | `dc7f9680881bba3b5957b6526f076edaf3ebbdca` = merge commit ของ PR #305 ที่มี `be24105` (WYN-132's fix) อยู่ในนั้น — ยืนยันตรงกว่าการ grep string literal ในบันเดิลที่ minify แล้ว |

**สิ่งที่ยืนยันเองไม่ได้ ต้องรอ Founder ทดลองใช้จริง** (ตาม `.wyn/company/WORKFLOW.md` หัวข้อ "Production Verification คือใครยืนยัน"): บั๊กนี้เป็นพฤติกรรมฝั่ง client ที่ต้อง login จริงถึงจะทดสอบได้ (ลบโพสต์ของตัวเอง → ปิดแท็บ/รีเฟรชหน้าใหม่ทั้งหมด → เข้าโปรไฟล์อีกครั้ง → ต้องไม่เห็นโพสต์นั้นแล้ว) sandbox นี้ไม่มี Supabase auth session จริงให้ทดสอบ end-to-end แบบ interactive ได้ — **รอ Founder ยืนยันด้วยการลองลบโพสต์จริงบนแอปว่าหายจากโปรไฟล์ทันทีทั้งสองเคส (กลับจาก Detail และรีเฟรชทั้งหน้าใหม่)**

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #101 (run #90 — WYN-120) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 dc7f968` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่ (workflow_dispatch)

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น client-side query filter ล้วนๆ ย้อนกลับได้ปลอดภัย 100%

## สถานะ Task

`.wyn/tasks/bugs/WYN-132-*.md` ยังอยู่ที่ `bugs/` (ไม่ย้ายไป `completed/`) จนกว่า **Founder ยืนยันแล้วว่าลบโพสต์จริงแล้วหายจากโปรไฟล์ทันที ทั้งกรณีกลับจาก Detail และกรณีรีเฟรชทั้งหน้าใหม่** (ตาม WORKFLOW.md — deploy สำเร็จทางเทคนิคอย่างเดียวไม่พอ)

## Open item ที่พบระหว่างทาง (ไม่ได้อยู่ใน scope ของ WYN-132)

`main`'s CI (`flutter test`) แดงมาตั้งแต่ PR #303 (WYN-130 ghost-account-fix) — ดูหัวข้อ "Build Status" ด้านบน แจ้ง Founder แล้วในแชท เสนอเปิด task แยกให้แก้ (root cause คล้าย WYN-072 ที่เคยแก้แล้ว: inject fake repository แทนการสร้าง `SupabaseClient` จริงในเทสต์) — รอ Founder ตัดสินใจว่าจะให้แก้ตอนนี้หรือแยกเป็น task ใหม่
