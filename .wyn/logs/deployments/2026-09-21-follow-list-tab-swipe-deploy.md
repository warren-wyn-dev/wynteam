# Deployment Log — Follow list (followers/following) tab-swipe

**Release**: Add swipe gesture between กำลังติดตาม/ผู้ติดตาม tabs, matching Profile's tab-swipe
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `web/components/profile-follow-list-route.tsx` — เพิ่ม swipe ซ้าย-ขวาสลับ กำลังติดตาม/ผู้ติดตาม ก๊อปพฤติกรรม/threshold จาก Profile's tab-swipe — ต่างจาก Profile ตรงที่ 2 แท็บนี้เป็นคนละ route กัน (`/profile/[id]/following` vs `/followers`) จึงเรียก `router.push()` แทนการสลับ local state ตอนสวิปครบ threshold

**PR**: [#577](https://github.com/warren-wyn-dev/wynteam/pull/577) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #163 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35552195914) — **success** ทุก step

**Production Verification**: รอ Founder ยืนยัน physical device ว่าสวิปสลับแท็บ กำลังติดตาม/ผู้ติดตาม ลื่นและถูกต้อง

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff จำกัดอยู่ที่ 1 ไฟล์ ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น
