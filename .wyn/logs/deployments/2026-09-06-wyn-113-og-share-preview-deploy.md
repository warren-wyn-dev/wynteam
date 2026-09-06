# Deployment — WYN-113: Open Graph / Twitter Card share preview

วันที่: 2026-09-06 05:41–06:00 UTC
Deploy โดย: AI Deploy & DevOps (session `session_013hvSGovkwhxpPFbFEKAvAu`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team — งานนี้ผ่าน Product → Design (Founder อนุมัติ mockup/copy) → Coding → QA (PASS) ครบตาม WORKFLOW.md แล้ว

## Release

WYN-113 — เพิ่ม Open Graph/Twitter Card meta tags ให้ `wynos.online` มี preview card เวลาถูกแชร์ (เดิมไม่มี tag เหล่านี้เลย)

## Version

Commit: `138c1a3` (feature branch tip) → merge commit `97403de` เข้า `main` ผ่าน PR #267
PR: https://github.com/warren-wyn-dev/wynteam/pull/267 (เปิดโดย AI Deploy & DevOps, **merge โดย Founder เอง** ผ่าน GitHub UI โดยตรงก่อนที่ AI จะกด merge — เห็นจาก `merged_by: warren-wyn-dev` ไม่ใช่บัญชี bot)

## QA Status

**PASS** (2026-09-06) — ดู `.wyn/tasks/approved/WYN-113-og-share-preview-cards.md` หัวข้อ "AI QA & Security Output" — ตรวจด้วย headless Chromium DOM dump, md5sum เทียบ git blob, secret scan, scope diff ครบก่อน PASS

## Build Status

- CI บน PR #267 (commit `138c1a3`): `schema.sql ordering` ✅, `Supabase Edge Functions` ✅, `Admin (Next.js)` ✅, `Flutter` (analyze+test) — Founder merge เร็วกว่าที่ job นี้จะรันเสร็จ
- **CI บน `main` หลัง merge** (run #192, commit `97403de`, trigger โดย push event): **success ทั้งหมดรวม Flutter** — ยืนยันว่า `flutter analyze`/`flutter test` ผ่านจริงบนโค้ดที่ deploy แล้ว ไม่ใช่แค่เดา
- `deploy-web.yml` run #87 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34015119521): **success** — `flutter build web --release --dart-define-from-file=dart_define.json` ผ่าน, deploy step ไป Vercel สำเร็จ

## Deployment Target

Vercel project "web" → `https://wynos.online` (Flutter Web release build, ตาม pattern เดิมทุกครั้ง)

## Changes

- `app/web/index.html` — เพิ่ม 9 meta tags (`og:type`/`og:url`/`og:title`/`og:description`/`og:image`, `twitter:card`/`twitter:title`/`twitter:description`/`twitter:image`)
- `app/web/og-image.png` (ใหม่) — รูป preview 1200×630, พื้น Ink `#12120F` + โลโก้/wordmark สีขาว + เส้นคั่น Sapphire (Founder เลือกหลังเปลี่ยนใจจาก Paper กลับมาเป็น Ink "จะได้เด่นๆ")
- `app/.gitignore` — เพิ่ม `!/web/og-image.png` กัน asset หายตอน regenerate (pattern เดียวกับ `firebase-messaging-sw.js`)
- **ไม่มี migration, ไม่มี schema/RLS เปลี่ยน, ไม่แตะ Dart code บรรทัดใดเลย**

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #87 (`workflow_dispatch`, trigger โดย AI Deploy & DevOps) status `success` ครบทุก step

## Production Verification

**ยืนยันได้เองจริง ไม่ใช่แค่เชื่อ workflow log** — session นี้มี network egress ถึง `wynos.online` จริง จึง curl ตรวจ production โดยตรง:

| รายการ | ผล |
|---|---|
| `curl https://wynos.online/` ตรวจ raw HTML | HTTP 200, มี meta tag ทั้ง 9 ตัวครบ ข้อความไทยถูกต้อง ไม่ mojibake — ตรงกับที่ QA ตรวจไว้ก่อน deploy ทุกตัวอักษร |
| `curl https://wynos.online/og-image.png` | HTTP 200, `content-type: image/png`, **md5sum ตรงกับไฟล์ที่ commit เป๊ะ** (`76b00bbf...`) — ยืนยันว่ารูปที่ deploy ขึ้นจริงไม่ใช่ไฟล์เก่า/ไฟล์ผิด ไม่ถูก build pipeline แก้ไขระหว่างทาง |

**สิ่งที่ยังไม่ได้ทำ (ไม่ใช่ blocker แต่ยังไม่ตรวจ)**: ยังไม่ได้วางลิงก์ผ่านหน้าเว็บ Facebook Sharing Debugger/Twitter Card Validator ตัวจริง (เป็น manual step ที่ต้องเปิดหน้าเว็บนั้นจริง) — แต่ข้อมูลดิบที่ scraper เหล่านั้นจะอ่าน (raw meta tag + รูปที่ URL ที่ระบุ) **ตรวจสอบแล้วว่าถูกต้องครบและ live จริง** ผ่าน curl ตรงๆ ด้านบน ต่างจากการเปิดหน้าเครื่องมือแค่เพื่อดู preview เฉยๆ ซึ่งเป็นขั้นยืนยันเสริมด้านความสวยงาม — **แนะนำ Founder ลองเปิด https://developers.facebook.com/tools/debug/ วางลิงก์ wynos.online ดูรอบเดียวเพื่อความสบายใจ** (ถ้าเพิ่งเคยแชร์ลิงก์นี้มาก่อนอาจต้องกด "Scrape Again" เพราะ Facebook cache preview เก่าไว้)

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหา ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #87 (run #86, commit `9c928346`) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 97403de` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น static asset ล้วนๆ ย้อนกลับได้ปลอดภัย 100% ไม่มีความเสี่ยงข้อมูลเสียหาย

## สถานะ Task

ย้าย `.wyn/tasks/approved/WYN-113-og-share-preview-cards.md` → `.wyn/tasks/completed/` ได้ทันที (ต่างจากงานที่ต้องรอ Founder ทดลองใช้จริงบนอุปกรณ์ถึงจะยืนยันได้ — งานนี้เนื้อหาที่ต้องยืนยัน (raw meta tag + รูป) ตรวจสอบได้เชิงกลไก 100% ด้วย curl ตรงๆ ไม่ต้องอาศัยการรับรู้ของมนุษย์)
