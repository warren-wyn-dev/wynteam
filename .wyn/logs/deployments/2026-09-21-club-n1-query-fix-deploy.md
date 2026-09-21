# Deployment Log — Club list N+1 query fix

**Release**: Fix N+1 query explosion (up to ~180 requests) on Explore Clubs / My Clubs
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Root Cause**: `mapClub()` ยิง request แยก 3 ครั้งต่อ Club (signed URL ปก + ไอคอน + นับสมาชิก) — Explore Clubs โหลด 3 หน้า (สูงสุด 60 Club) = สูงสุด ~180 round-trip ไปหา Supabase แค่เพื่อแสดงหน้าเดียว

**Changes**:
- `web/lib/phase3-data.ts` — เพิ่ม `mapClubs()` (batch version) รวม signed-URL request ทั้งหมดเป็น `createSignedUrls()` เดียว + นับสมาชิกด้วย query เดียว (`in("club_id", ids)` แล้วนับฝั่ง client) แทนยิงทีละ Club — เพิ่ม `fetchClubsByIds()` สำหรับ My Clubs
- `web/components/clubs-routes.tsx` — `MyClubs` ใช้ `fetchClubsByIds()` แทน `Promise.all(ids.map(fetchClub))`
- `web/components/chat-inbox-parity.tsx` — แก้ lint warning เดิม (`rows` คำนวณใหม่ทุก render) ด้วย `useMemo`

**PR**: [#578](https://github.com/warren-wyn-dev/wynteam/pull/578) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #164 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35553299783) — **success** ทุก step

**Production Verification**: รอ Founder ยืนยัน physical device ว่าหน้า Explore Clubs / My Clubs โหลดเร็วขึ้นชัดเจน

**หมายเหตุ**: อันนี้แก้จุดที่เจอจริงและมีผลกระทบชัดเจนที่สุดจากการตรวจสอบเชิงลึกครั้งนี้ แต่ "ทั้งระบบช้า/ไม่เสถียรทุกที่" เป็นคำร้องเรียนที่กว้างกว่าที่ code-level pass เดียวจะแก้ครบได้ — แนะนำเพิ่ม real production monitoring (web-vitals/error tracking) เป็น follow-up แยกถ้าอาการยังไม่หายหลังจากนี้

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff จำกัดอยู่ที่ 3 ไฟล์ business logic ไม่เปลี่ยนพฤติกรรมที่ผู้ใช้เห็น (แค่ลดจำนวน request) ปลอดภัยที่จะ revert ทันที
