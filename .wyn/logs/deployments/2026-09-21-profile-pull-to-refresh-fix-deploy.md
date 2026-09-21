# Deployment Log — Profile pull-to-refresh unreachable/invisible fix

**Release**: Fix for PR #573's Profile pull-to-refresh widening — Founder tested live, gesture didn't work at all
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Root Cause** (พบด้วยการ reproduce ผ่าน throwaway Playwright/CDP fixture):
1. Touch handler เดิมครอบแค่ `<ProfileFeed>` (ใต้ header/bio/สถิติ/ปุ่ม/แท็บ) — Home header สั้นเลยไม่มีปัญหา แต่ Profile header ยาวจนเต็มจอพอดีเวลา scroll ไปบนสุด ลากจากจุดไหนก็ตามที่เป็นธรรมชาติจึงไม่โดนจุดที่รับ touch เลย
2. Spinner เดิมวางแบบ inline ตรงจุดเริ่ม feed ถูกดันลงไปไกลมาก ต่อให้ลากโดนจริงก็ไม่เห็น spinner

**Changes**:
- `web/components/profile-route.tsx` — ย้าย `usePullToRefresh` จาก `ProfileFeed` ขึ้นไปที่ `ProfileInner`, touch handler ครอบทั้งหน้า (topbar ถึง feed) แทน — `ProfileFeed` รับ trigger ผ่าน `route-refresh-runtime` pub/sub เดิม (ตัวเดียวกับที่ bottom-nav tap-to-refresh ใช้) แทน hook instance ของตัวเอง — spinner เปลี่ยนเป็น `position: fixed` pin ไว้บนสุดจอเสมอ

**PR**: [#574](https://github.com/warren-wyn-dev/wynteam/pull/574) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #160 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35550257694) — **success** ทุก step (preflight / Vercel deploy / verify production routes)

**Production Verification**: GitHub Actions "Verify production routes" ผ่าน — รอ Founder ยืนยัน physical device อีกรอบว่าลากแล้วเห็น spinner บนสุดจอจริง + รีเฟรชสำเร็จจริง

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff จำกัดอยู่ที่ 1 ไฟล์ (`profile-route.tsx`) ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น
