# Deployment — WYN-114: real share-link domain + Vercel SPA rewrite

วันที่: 2026-09-06 07:15–07:26 UTC
Deploy โดย: AI Deploy & DevOps (session `session_013hvSGovkwhxpPFbFEKAvAu`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" อยู่ในอำนาจของ AI Team — งานนี้ผ่าน Product → Coding → QA FAIL → Debug Engineer → QA PASS ครบตาม WORKFLOW.md แล้ว

## Release

WYN-114 — (1) แก้ share link 5 จุด (`dropShareLink`/`popShareLink`/`clubShareLink`/`clubPostShareLink`/`profileShareLink`) จากโดเมนปลอม `wyn.app` เป็นโดเมนจริง `wynos.online` (2) แก้บั๊กที่พบระหว่างทาง — Vercel hosting ไม่มี SPA rewrite ทำให้ทุก path นอกจาก `/` ได้ HTTP 404 ตรงๆ

## Version

Commit: `33b92a9` (feature branch tip หลัง merge conflict resolve กับ `main`) → merge commit `be0f456` เข้า `main` ผ่าน PR #271
PR: https://github.com/warren-wyn-dev/wynteam/pull/271 (เปิดและ merge โดย AI Deploy & DevOps เอง — เจอ merge conflict จริงระหว่างทางกับ PR #269 อีก session หนึ่งที่แก้ `app/.gitignore` ตำแหน่งเดียวกัน แก้โดยเก็บทั้งสองส่วนไว้ ไม่มีอะไรหาย)

## QA Status

**PASS แบบมีเงื่อนไข** (2026-09-06) — ดู `.wyn/tasks/bugs/WYN-114-vercel-404-no-spa-rewrite.md` หัวข้อ "AI QA & Security Output — Re-verification" — QA ยืนยัน regression risk หลักด้วยเอกสารทางการของ Vercel (`vercel.json` reference doc) ก่อน PASS พร้อมระบุ curl checklist บังคับหลัง deploy

## Build Status

- CI บน PR #271 หลัง merge conflict resolve (commit `33b92a9`, run #201): **success ทั้งหมด** รวม `Flutter` (analyze+test), `Admin (Next.js)`, `Supabase Edge Functions`, `schema.sql ordering`
- `deploy-web.yml` run #89 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34018964206): **success** ครบทุก step รวม `flutter build web --release` และ "Deploy to Vercel production"

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Changes

- `app/lib/features/{drop,pop,club,profile}/presentation/*.dart` — โดเมน share link 5 จุด: `wyn.app` → `wynos.online`
- `app/web/vercel.json` (ใหม่) — SPA catch-all rewrite `{"rewrites":[{"source":"/(.*)","destination":"/index.html"}]}`
- `app/.gitignore` — เพิ่ม `!/web/vercel.json`
- **ไม่มี migration ไม่มี schema/RLS เปลี่ยน**

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #89 status `success` ครบทุก step

## Production Verification

**ยืนยันได้เองจริงครบทั้ง 2 ชุด ด้วย curl ตรงต่อ production** (session นี้มี network egress จริง):

| Path | ผลก่อน deploy | ผลหลัง deploy |
|---|---|---|
| `/drop/x` | HTTP 404 (Vercel) | **HTTP 200** ✅ |
| `/pop/x` | HTTP 404 | **HTTP 200** ✅ |
| `/club/x` | HTTP 404 | **HTTP 200** ✅ |
| `/club-post/x` | HTTP 404 | **HTTP 200** ✅ |
| `/@x` | HTTP 404 | **HTTP 200** ✅ |

**Regression check ที่สำคัญที่สุด** — static asset เดิมต้องไม่ถูก rewrite ทับ:

| Path | ผล | หมายเหตุ |
|---|---|---|
| `/og-image.png` | HTTP 200, `image/png`, 33297 bytes | **md5sum ตรงกับไฟล์ที่ commit เป๊ะ** (`76b00bbf...`) — ไม่ถูกแตะเลย |
| `/favicon.png` | HTTP 200, `image/png` | ปกติ |
| `/manifest.json` | HTTP 200, `application/json` | ปกติ |
| `/` | HTTP 200 | ปกติ |

ตรวจ body ของ `/drop/x` เพิ่มเติม (ไม่ใช่แค่ status code) — ยืนยันว่าเป็น Flutter app's `index.html` จริง (ไม่ใช่ Vercel 404 text/plain แบบก่อนหน้า)

**สรุป: ทั้ง fix หลัก (share link เปิดได้จริง) และ regression concern ที่ QA เตือนไว้ (static asset ไม่พัง) ยืนยันสำเร็จ 100% ด้วยข้อมูลจริงจาก production ไม่ใช่แค่เชื่อ workflow log**

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #89 (run #88 — add-to-home guide, หรือ run #87 — WYN-113) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: `git revert -m 1 be0f456` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

**ไม่มี migration ให้ rollback** — ไม่มี schema/database เปลี่ยนแปลงในรอบนี้เลย เป็น client-side string + static hosting config ล้วนๆ ย้อนกลับได้ปลอดภัย 100%

## สถานะ Task

ย้าย `.wyn/tasks/approved/WYN-114-share-link-real-domain.md` → `.wyn/tasks/completed/` ได้ทันที — ยืนยันได้เชิงกลไก 100% ด้วย curl ตรงๆ ไม่ต้องรอ Founder ทดลองใช้เพิ่มเติม (เหมือนกรณี WYN-113)
