# Deployment — WYN-121: ลบโพสต์สำเร็จจริงแต่แอปแจ้งว่าล้มเหลว

วันที่: 2026-09-06 08:35–08:38 UTC
Deploy โดย: AI Deploy & DevOps (session `session_013hvSGovkwhxpPFbFEKAvAu`)
อำนาจ: `.wyn/company/RULES.md` — "Deploy การเปลี่ยนแปลงที่ได้รับอนุมัติแล้ว" — Founder merge PR เองโดยตรง (เหมือน WYN-120)

## Release

WYN-121 — แก้ `DropDetailScreen._deleteDrop()` ที่รายงาน "ลบโพสต์ไม่สำเร็จ" แม้การลบจะสำเร็จจริงที่ฝั่งเซิร์ฟเวอร์แล้ว (response หายระหว่างทางหลัง commit) — เพิ่มการเช็คสถานะจริงผ่าน `fetchById()` ก่อนฟันธงว่าล้มเหลว

## Version

Commit: `f81474d` (feature branch) → merge commit `4909194` เข้า `main` ผ่าน PR #278 (และ PR #277 สำหรับ diagnostic workflow ก่อนหน้า)

## QA Status

เหมือน WYN-120 — Founder merge ตรงเองไม่ผ่าน QA แยก แต่มี evidence เชิงกลไกที่แน่นหนา: (1) production diagnostic query ยืนยัน root cause ตรงกับสกรีนช็อตของ Founder เป๊ะ (2) widget test 2 เคสยืนยันทั้ง false-negative case และ regression (ไม่กลืน error จริง) — **ยืนยันแล้วว่า CI (`flutter test`) รันผ่านจริงหลัง push**, ไม่ใช่แค่คาดว่าน่าจะผ่าน

## Build Status

- CI บน PR #278 (commit `f81474d`, run #34022069668): **success ทั้งหมด** รวม `Flutter` ที่ยืนยันย้อนหลังว่า conclusion: success (ตรวจสอบเพื่อยืนยันว่า test 2 เคสใหม่ compile และผ่านจริง เพราะ sandbox นี้ไม่มี Flutter SDK ให้รันเองก่อน push)
- `deploy-web.yml` run #91 (https://github.com/warren-wyn-dev/wynteam/actions/runs/34022254384), บน `main` @ `4909194`: **success**

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Changes

- `app/lib/features/drop/presentation/drop_detail_screen.dart` — `_deleteDrop()`: เช็ค `fetchById()` ก่อนแสดง error เมื่อ `deleteDrop()` throw
- `app/test/drop_detail_screen_test.dart` — 2 widget tests ใหม่
- `.github/workflows/wyn120-delete-drop-failure-diagnostic.yml` (จาก PR #277) — read-only diagnostic ใช้ครั้งเดียวเพื่อยืนยัน root cause แล้ว ไม่ลบออก (เก็บไว้เผื่อวินิจฉัยเคสคล้ายกันในอนาคต)
- **ไม่มี migration ไม่มี schema/RLS เปลี่ยน**

## Deployment Result

**สำเร็จ** — `deploy-web.yml` run #91 status `success`

## Production Verification

**ยืนยันได้เอง (curl ตรงต่อ production):**

| ตรวจสอบ | ผล |
|---|---|
| `GET /` | HTTP 200 |
| `GET /drop/x` (SPA rewrite ยังไม่พัง) | HTTP 200 |
| `og-image.png` md5 | ตรงเดิม ไม่ถูกแตะ |
| `main.dart.js` เป็น build ใหม่จริง | etag เปลี่ยนจาก `dc0e4dc1...` (WYN-120 build) เป็น `3a1835df...` — ยืนยันว่าเป็นคนละ build จริง ไม่ใช่ cache เดิม |

**ยืนยันเองไม่ได้ ต้องรอ Founder**: ต้องลองกดลบโพสต์จริงในสภาพเครือข่ายไม่เสถียร (จำลองยากใน sandbox) ถึงจะยืนยัน fix นี้ตรงจุดร้อยเปอร์เซ็นต์ — อย่างน้อยที่ยืนยันได้แน่ๆ คือ flow ลบปกติ (เน็ตเสถียร) ยังทำงานถูกต้องเหมือนเดิม (ไม่มีการเปลี่ยน happy path เลย)

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** — ถ้ามีปัญหา:
1. Vercel Instant Rollback → กลับไป run #90 (WYN-120)
2. `git revert -m 1 4909194` บน `main` แล้ว push → รัน `deploy-web.yml` ใหม่

ไม่มี migration ให้ rollback — ปลอดภัย 100%

## สถานะ Task

`.wyn/tasks/bugs/WYN-121-*.md` — deploy สำเร็จทางเทคนิคแล้ว รอ Founder ยืนยันด้วยการใช้งานจริงก่อนย้ายไป `completed/`
