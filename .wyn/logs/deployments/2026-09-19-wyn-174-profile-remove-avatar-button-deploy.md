# Deployment Log — WYN-174

Release: Edit Profile — ปุ่มลบรูปโปรไฟล์
Version: ไม่มีการเปลี่ยน WYNOS version (ฟีเจอร์ย่อยที่ไม่ gate ด้วย version)
QA Status: PASS — ดู section "QA Verification" ใน `.wyn/tasks/completed/WYN-174-profile-remove-avatar-button.md`
Build Status: `npm run check` เขียวก่อนเปิด PR — 0 error, 3 warning เดิมที่ไม่เกี่ยวข้อง
Deployment Target: Production (Vercel ผ่าน GitHub Actions workflow `WYN-158 Production Deploy`)

## Changes

เพิ่มปุ่ม "ลบรูปโปรไฟล์" ในหน้าแก้ไขโปรไฟล์ (`EditProfile` component) แสดงเฉพาะตอนมี avatar อยู่แล้ว กดแล้ว
เซ็ต `avatar_url` เป็น `null` ผ่านฟังก์ชันใหม่ `removeProfileImage` (ใช้ RLS policy เดิม `"Users can update
their own profile"` ที่มีอยู่แล้ว ไม่มีการเปลี่ยน security architecture ใดๆ)

Files changed: `web/lib/phase3-data.ts`, `web/components/profile-route.tsx`, `web/app/profile-golden-final.css`
Branch: `claude/ux-ui-button-design-ult3lz` → `main` ผ่าน PR #555
Commits: `bdade1e5` (implement) → `f860445e` (QA docs) → merge commit `5b3f8fff`

## Deployment Result

Founder merge PR #555 เองโดยตรงบน GitHub อีกครั้ง (เร็วกว่า CI ของ PR เองที่ยังรันไม่เสร็จ — pattern
เดียวกับ PR #550/#551 ก่อนหน้านี้) จึง monitor CI **หลัง** merge บน `main` commit ที่เกิดขึ้นจริง
(`5b3f8fff`) แทน

## Production Verification

- **CI** (run #1398, `35460686261`) — **success** ทั้ง 5 job: Supabase Edge Functions (Deno), Admin
  (Next.js), Flutter (analyze + push reliability regression + flutter test), Supabase PostgreSQL
  integration (RLS regression), schema.sql ordering — เสร็จ 18:16:52 → 18:21:01 UTC
- **WYN-158 Production Deploy** (run #142, `35460686263`) — **success** ทุก step: Production preflight →
  Deploy to Vercel production → **Verify production routes** ผ่าน — เสร็จ 18:16:52 → 18:18:29 UTC

ทั้งสอง workflow เขียวสมบูรณ์ ไม่มี job ไหนล้มเหลว

## Rollback Plan

- `git revert -m 1 5b3f8fff` บน `main` (ต้องระบุ `-m 1` เพราะเป็น merge commit มี 2 parent — `git revert`
  เฉยๆ จะ error ทันที) แล้ว push ผ่าน PR ใหม่ตามขั้นตอนปกติ (ต้องขออนุมัติ Founder ก่อน merge เหมือนเดิม)
- ไม่มี migration/schema change ใดๆ ในรอบนี้ — ใช้ column `avatar_url` ที่มีอยู่แล้ว
- **สำคัญ**: นี่คือ **code-only rollback** — ลบแค่ปุ่ม/ฟังก์ชันออกจากโค้ด **ไม่คืนค่า `avatar_url` ที่ผู้ใช้
  กดลบไปแล้ว** ถ้ามีผู้ใช้กดปุ่ม "ลบรูปโปรไฟล์" ไปแล้วก่อน rollback ค่า `avatar_url` ของบัญชีนั้นจะยังเป็น
  `null` อยู่ต่อไปหลัง revert (ต้องให้ผู้ใช้อัปโหลดรูปใหม่เอง หรือกู้ URL เดิมจาก backup/audit log ด้วยมือ
  ถ้าจำเป็น — ไฟล์เดิมใน storage bucket `avatars` ไม่ได้ถูกลบตอนกดปุ่มนี้ แค่ไม่มี reference ชี้ไปแล้ว)
- ความเสี่ยงของการ deploy รอบนี้เองต่ำมาก: ปุ่มใหม่ทำแค่ set `avatar_url = null` ผ่าน RLS policy เดิม ไม่แตะ
  flow อัปโหลด/บันทึกโปรไฟล์เดิมเลย — ความเสี่ยงข้างต้นเป็นเรื่อง data ที่เกิดจากการใช้งานฟีเจอร์ปกติ ไม่ใช่
  บั๊กของ deploy นี้

## Process Note

ครั้งที่ 3 ติดต่อกัน (หลัง PR #550, #551) ที่ Founder merge PR เองก่อน CI ของ PR จะรันเสร็จ — ยังคงต้องตรวจสอบ
CI/deploy workflow บน `main` commit จริงหลัง merge อย่างอิสระเสมอ ตามที่บันทึกไว้ใน deployment log ก่อนหน้า
