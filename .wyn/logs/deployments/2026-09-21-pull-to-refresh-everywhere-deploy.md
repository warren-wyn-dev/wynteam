# Deployment Log — Pull-to-refresh badge everywhere + 3 new screens

**Release**: Roll out the pull-to-refresh badge (PR #575) to every screen that has it, add the gesture to 3 screens that should have it
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `web/components/ui/pull-to-refresh-indicator.tsx` (ใหม่) — shared component ของ badge indicator แทนโค้ดซ้ำ 7 จุด
- Home, Notifications, Bookmarks, Club detail (แท็บโพสต์), Profile — เปลี่ยนมาใช้ shared component
- Notifications, Club detail, Profile Follow List — ขยาย touch coverage ให้ครอบทั้งหน้า (ไม่ใช่แค่ list ใต้ header) ตามที่แก้ Profile ไปแล้วใน PR #574
- เพิ่ม pull-to-refresh ใหม่ 3 หน้า: Explore Clubs, My Clubs, Profile Follow List (followers/following) — ทั้งหมดเป็นหน้ารายการที่ไม่มี realtime subscription
- Chat inbox — พิจารณาแล้วไม่เพิ่ม เพราะมี realtime subscription (`subscribeMyMessages`) อยู่แล้ว

**PR**: [#576](https://github.com/warren-wyn-dev/wynteam/pull/576) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #162 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35551663193) — **success** ทุก step

**Production Verification**: รอ Founder ยืนยัน physical device ทั้ง 5 หน้าที่เปลี่ยน badge + 3 หน้าใหม่ที่เพิ่ม pull-to-refresh

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff กระทบ 8 ไฟล์ (1 ไฟล์ใหม่ + 7 แก้ไข) ไม่แตะ business logic/schema ปลอดภัยที่จะ revert ทันที
