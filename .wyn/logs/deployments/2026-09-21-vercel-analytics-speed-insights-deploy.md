# Deployment Log — Vercel Analytics + Speed Insights

**Release**: เพิ่ม real production monitoring (Core Web Vitals + page analytics) ตามคำขอ Founder
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Deployment Target**: Production (`wynos.online`, Vercel)

**Changes**:
- `web/package.json` — เพิ่ม `@vercel/analytics`, `@vercel/speed-insights`
- `web/app/layout.tsx` — เพิ่ม `<Analytics />` + `<SpeedInsights />` เป็น sibling ของ `QueryProvider` ที่ root layout (ครอบคลุมทุกหน้าอัตโนมัติ)

**PR**: [#579](https://github.com/warren-wyn-dev/wynteam/pull/579) (`claude/web-beta1-readiness-7hysen` → `main`) — Founder merge เอง

**Deployment Result**:
- `WYN-158 Production Deploy` run #165 (https://github.com/warren-wyn-dev/wynteam/actions/runs/35555681599) — **success** ทุก step

**ขั้นตอนที่เหลือ (ต้องทำเองใน Vercel dashboard — ทำแทนไม่ได้)**:
1. เข้า Vercel dashboard ของโปรเจกต์นี้
2. แท็บ **Analytics** → กด Enable
3. แท็บ **Speed Insights** → กด Enable

ก่อนกด Enable ทั้ง 2 อย่าง component จะไม่เก็บ/แสดงข้อมูลอะไรเลย (ไม่ error แค่เงียบ) ทำได้ฟรีบนแผน Hobby

**Production Verification**: รอ Founder enable ใน dashboard แล้วเข้าใช้งานจริงสัก 2-3 วัน ถึงจะเริ่มเห็นข้อมูล Core Web Vitals จริงใน dashboard

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น additive ล้วนๆ (เพิ่ม monitoring script) ไม่กระทบ business logic ปลอดภัยที่จะ revert ทันที
