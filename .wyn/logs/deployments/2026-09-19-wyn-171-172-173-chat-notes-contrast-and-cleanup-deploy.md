# Deployment Log — WYN-171 / WYN-172 / WYN-173

Release: Chat Inbox Notes composer — dark-mode contrast fixes + dead-button cleanup
Version: no WYNOS version change (bug fix + UI cleanup, not a version-gated release)
QA Status: PASS ทั้ง 3 เรื่อง (WYN-171, WYN-172, WYN-173) — ดูรายละเอียดใน section "QA Verification"
ของแต่ละ task file (`.wyn/tasks/bugs/WYN-171-...md`, `.wyn/tasks/completed/WYN-172-...md`,
`.wyn/tasks/bugs/WYN-173-...md`)
Build Status: `npm run check` (lint + typecheck + build) เขียวก่อนเปิด PR — 0 error, 3 warning เดิมที่ไม่
เกี่ยวข้อง (pre-existing)
Deployment Target: Production (Vercel, ผ่าน GitHub Actions workflow `WYN-158 Production Deploy`)

## Changes

- **WYN-171 (บั๊ก HIGH)**: `.wyn-chat-note-card.is-mine .wyn-chat-note-bubble` background hardcode
  `#f7f7f8` (ประกาศซ้ำ 2 จุด) → `var(--wyn-surface)` — แก้ dark mode contrast ของการ์ด "โน้ตของคุณ"
  (1.07:1/3.32:1 → 18.88:1/5.32:1 dark, 18.49:1/4.98:1 → 18.97:1/5.11:1 light)
- **WYN-172 (UI cleanup)**: ลบปุ่ม "สถานที่"/"อีโมจิ" (ไม่มี onClick) ออกจาก note composer พร้อม CSS ที่
  เกี่ยวข้องทั้งหมด และปรับ `.wyn-note-stage` min-height ลง (318px→240px, 285px→210px) ให้ layout ไม่โหว่
- **WYN-173 (บั๊ก HIGH ใหม่ที่ QA เจอเอง)**: `.wyn-note-info-card` background hardcode `#f7f7f8` →
  `var(--wyn-surface)` — pattern เดียวกับ WYN-171 เป๊ะ อยู่ในไฟล์เดียวกัน (1.07:1/3.32:1 → 18.88:1/5.32:1
  dark, 18.49:1/4.98:1 → 18.97:1/5.11:1 light)

Files changed: `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`
Branch: `claude/ux-ui-button-design-ult3lz` → `main` ผ่าน PR #551
Commits: `21bbef58` (WYN-171/172 fix) → `aa9082d1` (docs) → `2fc3dda3` (QA docs + WYN-173 filed) →
`83df6f79` (WYN-173 fix) → `9000736d` (QA docs) → merge commit `d3ffcbfd`

## Deployment Result

Founder merge PR #551 เองโดยตรงบน GitHub เร็วมาก (~43 วินาทีหลังเปิด PR ตอน 14:57:33 UTC, merge เสร็จ
14:58:16 UTC) — เร็วกว่า CI ของ PR เองที่ยังรันไม่เสร็จตอนนั้น (เหมือนที่เกิดกับ PR #550 ของ WYN-170 มาก่อน)
จึงต้อง monitor CI **หลัง** merge บน `main` commit ที่เกิดขึ้นจริง (`d3ffcbfd`) แทน

## Production Verification

หลัง merge ตรวจสอบ workflow ทั้ง 2 ตัวที่ trigger บน `main` commit `d3ffcbfd` โดยตรง (ไม่ใช่แค่เชื่อว่า
"merge แล้ว = สำเร็จ"):

- **CI** (run #1388, `35450341417`) — **success** ทั้ง 5 job: Flutter (flutter analyze + push
  reliability regression + flutter test), Admin (Next.js) (lint + typegen + tsc), schema.sql ordering,
  Supabase PostgreSQL integration (RLS regression), Supabase Edge Functions (Deno) — เสร็จ 14:58:19 →
  15:02:02 UTC
- **WYN-158 Production Deploy** (run #138, `35450341460`) — **success** ทุก step: Production preflight →
  Deploy to Vercel production → **Verify production routes** ผ่าน — เสร็จ 14:58:19 → 14:59:49 UTC

ทั้งสอง workflow เขียวสมบูรณ์ ไม่มี job ไหนล้มเหลว

## Rollback Plan

การเปลี่ยนแปลงทั้งหมดเป็น CSS/JSX ที่ย้อนกลับได้ง่าย — ถ้าพบปัญหาหลัง deploy:
1. `git revert -m 1 d3ffcbfd` บน `main` (ต้องระบุ `-m 1` เพราะเป็น merge commit มี 2 parent) แล้ว push
   ผ่าน PR ใหม่ตามขั้นตอนปกติ (ต้องขออนุมัติ Founder ก่อน merge เหมือนเดิม)
2. ไม่มี migration/schema change ใดๆ ในรอบนี้ — rollback ไม่กระทบข้อมูล production เลย
3. ความเสี่ยงต่ำมาก: ทั้ง 3 เรื่องเป็น CSS 1-property change (WYN-171/173) หรือ UI element removal ที่ไม่มี
   logic ผูกอยู่ (WYN-172) ไม่แตะ core note-saving logic เลย

## Process Note

นี่เป็นครั้งที่ 2 ติดต่อกัน (หลัง WYN-170/PR #550) ที่ Founder merge PR เองก่อน CI ของ PR จะรันเสร็จ — ย้ำ
บทเรียนเดิมจาก deployment log ก่อนหน้า: **"PR merged" ไม่เท่ากับ "CI เขียว"** ต้องตรวจสอบ CI/deploy workflow
บน `main` commit จริงที่เกิดขึ้นหลัง merge อย่างอิสระเสมอ ไม่ใช่แค่เชื่อว่า merge สำเร็จแล้วจบงาน — รอบนี้ยัง
พบว่า WYN-158 Production Deploy ทำงานเร็วมาก (deploy + verify เสร็จใน ~1.5 นาที) ทำให้ monitor ทันได้ไม่ยาก
