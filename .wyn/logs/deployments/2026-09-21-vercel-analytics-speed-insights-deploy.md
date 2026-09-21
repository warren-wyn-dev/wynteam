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

**ขั้นตอน Vercel dashboard (ทำแทนไม่ได้ — Founder ทำเอง)**:
1. **Analytics** — เปิดสำเร็จแล้ว (2026-09-21) ไม่ต้องผูกบัตรเครดิต
2. **Speed Insights** — ยังไม่เปิด เพราะ Vercel ขอผูกบัตรเครดิตก่อนถึงจะเปิดได้ (ต่างจาก Analytics) Founder เลือก "ข้ามไปก่อน" — ยังไม่ผูกบัตร ค่อยว่ากันทีหลังถ้าต้องการ

โค้ด `<SpeedInsights />` ยังอยู่ในระบบตามเดิม ไม่ error แค่ยังไม่เก็บข้อมูลจนกว่าจะเปิดใช้งานในอนาคต

**Production Verification**: Analytics เปิดแล้ว — รอให้คนเข้าใช้งานจริงสัก 2-3 วัน ถึงจะเริ่มเห็นข้อมูล page view จริงใน Vercel dashboard

**Rollback Plan**: Revert merge commit ผ่าน PR แยก — diff เป็น additive ล้วนๆ (เพิ่ม monitoring script) ไม่กระทบ business logic ปลอดภัยที่จะ revert ทันที
