# Deployment Log — Profile tab swipe + pull-to-refresh GA

**Release**: Profile tab swipe gesture (new) + widen pull-to-refresh from developer accounts to everyone
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android` (`webkit-iphone` รันไม่ได้ใน sandbox นี้ — ไม่มี browser binary, ไม่เกี่ยวกับ diff นี้)

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `web/components/profile-route.tsx` — เพิ่ม swipe ซ้าย-ขวาสลับแท็บ สื่อ/รีโพสต์/ถูกใจ (ก๊อปพฤติกรรม/threshold จาก Home's tab-swipe)
- `web/components/profile-route.tsx`, `notifications-route.tsx`, `bookmarks-route.tsx`, `club-detail-golden.tsx` — ลบ staged-rollout gate (`useIsDeveloperAccount`, WYN-125/WYN-182) ออกจาก pull-to-refresh ทั้ง 4 จุด ตาม Founder decision ("ปล่อยให้ใช้ทุกคนเลย") — Home's ของเดิมไม่เคย gate อยู่แล้ว, Club detail ยังคงเงื่อนไข `tab === "posts"` เดิมไว้ (คนละเรื่องกับ developer gate)

**PR**: [#573](https://github.com/warren-wyn-dev/wynteam/pull/573) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #159 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35544391147) — **success** ทุก step (preflight / Vercel deploy / verify production routes)

**Production Verification**: GitHub Actions "Verify production routes" ผ่าน (sandbox เข้า `wynos.online` ตรงไม่ได้) — รอ Founder ยืนยัน physical device: (1) สวิปแท็บ Profile ลื่น ไม่ชนกับ pull-to-refresh gesture (2) pull-to-refresh ใช้งานได้จริงด้วยบัญชีทั่วไป (ไม่ใช่แค่ `warren`/`wynos_online`) ทั้ง 4 หน้า (Profile, Club posts tab, Notifications, Bookmarks)

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น additive (gesture ใหม่) + การลบเงื่อนไข gate (ไม่แตะ business logic/schema) ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น
