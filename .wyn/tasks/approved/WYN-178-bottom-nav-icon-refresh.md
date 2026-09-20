# Design Task — WYN-178

Status: coding done, ready for AI QA & Security — approved by Founder ("เอาแบบนี้ 100%")

## AI Coding (2026-09-19)

Implementation: แก้ไอคอนคลับ (3 คน) + แชท (บับเบิลกลม+จุดไข่ปลา 3 จุด) ใน `MaterialNavGlyph` (`bottom-navigation.tsx`),
เปลี่ยนสี hardcode เป็น `var(--wyn-text-secondary)`/`var(--wyn-text)` ใน `bottom-nav.css`, เพิ่ม press-feedback
(`var(--wyn-motion-duration/easing/press-scale)` + `prefers-reduced-motion`) ให้ `.route-nav-link`, ลบ dead prop
`notificationLabel`/`notificationBadge` ออกจาก `BottomNavigation` type และจุดเรียกใช้ทั้ง 2 จุด
(`app-bottom-nav-runtime.tsx`, และ `home-fixture.tsx` ที่ AI Design ไม่ได้ grep เจอตอนแรกเพราะ import
`BottomNavigation` ตรงแยกจาก `AppBottomNavHost` — เจอระหว่างเช็ค call site ทั้งหมดก่อนลบ type field), ลบ CSS
`.route-nav-badge` ที่ไม่มี consumer เหลือ — คงไว้ตามคำสั่ง: ไม่ลบ `usePublishBottomNav`/การคำนวณ badge ใน
`phase3-ui.tsx` (ยังใช้งาน `visible`/`userId` field อื่นอยู่ แม้ `notificationLabel`/`notificationBadge` ใน
store จะกลายเป็นไม่มีจุดใช้ปลายทางแล้วก็ตาม — เป็น residual dead code ระดับ shared-state เท่านั้น ไม่กระทบ build/runtime
ไม่ใช่ scope ของงานนี้)

Files Changed: `web/components/bottom-navigation.tsx`, `web/app/bottom-nav.css`,
`web/components/app-bottom-nav-runtime.tsx`, `web/components/home/home-fixture.tsx`

Reason: ตรงตาม spec ที่ Founder อนุมัติ ("เอาแบบนี้ 100%") — ดู task ด้านบน

Tests: ไม่มี automated test เฉพาะสำหรับ nav icon shape (SVG path) — QA ควรตรวจ visual จริงบน dev server

Build: `npm run check` (lint + typecheck + `next build`) เขียว — 0 error, 3 warning เดิมที่ไม่เกี่ยวข้อง
(pre-existing, คนละไฟล์กับที่แก้รอบนี้) build ผ่านทั้ง 31 route รวม `/dev/home-fixture` ที่เรียก
`BottomNavigation` ตรง (ยืนยันว่าการลบ prop ไม่ทำให้ fixture พัง)

Known Issues: residual dead code ใน `phase3-ui.tsx`/`app-bottom-nav-runtime.tsx`'s `BottomNavState` (notificationLabel/
notificationBadge fields ไม่มีจุดใช้ปลายทางแล้ว) — ตั้งใจไม่แตะตามขอบเขตงานนี้ เสนอเป็น follow-up cleanup แยกถ้า
Founder ต้องการ

Handoff: → **AI QA & Security**

## AI QA & Security (2026-09-19)

Feature: WYN-178 แท็ปบาร์ — ไอคอนคลับ/แชทใหม่ + token cleanup + press-feedback + ลบ dead code

Environment: sandbox (Next.js 16.3.5 Turbopack build, `npm run check`), Playwright + `/opt/pw-browsers/chromium`
โหลด CSS จริงจาก repo ผ่าน static file server (ไม่ใช่ dev server เพราะไม่มี Supabase credential ใน sandbox)
ประกอบ markup จริงจาก `bottom-navigation.tsx`/`bottom-nav.css`

Test Cases:
1. Diff SVG path string ของไอคอนคลับ/แชทใน `bottom-navigation.tsx` เทียบกับ spec ที่ Founder อนุมัติใน Artifact —
   ตรงกันทุกตัวอักษร
2. Render จริงผ่าน real-CSS-cascade harness (light + dark mode ผ่าน `page.emulateMedia`) — ไม่มี console error/page
   error ระหว่าง render, บาร์แสดงผลถูกต้องทั้ง 5 แท็บ, active state (หน้าหลัก) เป็นสีเข้ม+ตัวหนา, ที่เหลือเป็นสีเทา — ตรงทั้ง
   2 theme
3. คำนวณ WCAG contrast จริง (ไม่เดา) ของ token ใหม่เทียบค่า hardcode เดิม:
   - Light inactive: เดิม `#737373` = 4.74:1 → ใหม่ `var(--wyn-text-secondary)` #6b6b6b = **5.33:1** (ดีขึ้น)
   - Light active: `var(--wyn-text)` #0a0a0a = **19.80:1**
   - Dark inactive: เดิม `#737373` (hardcode, ไม่มี dark override) = **4.43:1 ต่ำกว่า AA 4.5:1 — บั๊กเดิมที่ไม่เคยถูกจับ
     มาก่อน** → ใหม่ `var(--wyn-text-secondary)` #8a8880 (dark) = **5.91:1** (แก้บั๊กนี้ไปด้วยโดยไม่ตั้งใจ เป็นผลข้างเคียง
     ที่ดีของการเปลี่ยนไป token)
   - Dark active: `var(--wyn-text)` #ffffff = **21.00:1**
   สรุป: ไม่มี regression ด้าน contrast จุดไหนเลย และแก้บั๊ก AA fail เดิมในโหมดมืดไปด้วย
4. Grep หาจุดเรียก `<BottomNavigation>` ทั้งหมดในโค้ด — พบ 2 จุด (`app-bottom-nav-runtime.tsx`,
   `home-fixture.tsx`) ทั้งคู่แก้ไขถูกต้องแล้ว ไม่มี prop เก่าหลงเหลือ, ไม่มีจุดอื่นอ้างอิง `.route-nav-badge` ที่ถูกลบ
5. ตรวจ dot 3 จุดในไอคอนแชท — ใช้ `fill="currentColor" stroke="none"` ตรงๆ ไม่ผูกกับ `strokeWidth`/`selected` prop
   ของ parent svg เลย ยืนยันจากโค้ดจริงว่าจุดจะไม่หายไปหรือเปลี่ยนขนาดตอนสลับ active/inactive
6. ตรวจไฟล์ CSS อื่นที่กล่าวถึง bottom nav (`system-parity-final.css`, `parity.css`) — ยืนยันว่าไม่มี selector
   ชนกับ `.route-nav-link`/`.route-bottom-nav` จริง (เป็นแค่ comment อ้างอิง หรือ class คนละชุดของ mockup เก่า)
7. `npm run check` ยืนยันซ้ำอิสระ — lint/typecheck/build เขียว build ผ่านครบ 31 route รวม `/dev/home-fixture`
8. ตรวจไอคอน หน้าหลัก/โพสต์/โปรไฟล์ — ไม่มีการแก้ไข ตรงกับ spec เดิม (out of scope ของงานนี้ ไม่ต้องแก้)

Passed: 8/8
Failed: ไม่มี
Severity: -

Security Findings: ไม่มี — เป็นการเปลี่ยน SVG path/CSS token/dead-code cleanup ล้วนๆ ไม่มี user input, ไม่มี API call
ใหม่, ไม่มี auth/authorization surface เปลี่ยนแปลง

Recommendation: PASS — ไม่มี regression, แก้บั๊ก contrast เดิมที่ไม่เคยถูกจับได้เป็นผลพลอยได้ พร้อม deploy

Final Status: **PASS**
Owner: AI Design
Screen: แท็ปบาร์ล่าง (bottom navigation) ทั้งระบบเว็บ — `web/components/bottom-navigation.tsx`, `web/app/bottom-nav.css`
Purpose: ปรับไอคอน "คลับ" และ "แชท" ให้ตรงกับภาพอ้างอิงที่ Founder ส่งมา (ยืนยันครั้งที่ 2 ด้วยภาพเดิมทุกประการ พร้อมคำว่า
"เอาแบบนี้ 100%") พร้อมเก็บกวาด token/motion ให้ตรง design system ปัจจุบัน (WYN-163/176) — **ไม่ใช่**การปรับโครงสร้างใหม่
และ**ไม่ใช่**แนวทาง Apple-style/SF-Symbols ที่เคยเสนอเป็นทางเลือกเพิ่มเติม (Founder เลือกภาพอ้างอิงเดิม ไม่ใช่ตัวเลือก
Apple-style ที่มี filled-icon/circle-frame/accent-tint)
User Flow: ไม่เปลี่ยน — กดแท็บ → เปลี่ยนหน้า/toggle เหมือนเดิมทุกจุด
Components:
1. ไอคอน "คลับ" — จาก 2 คน (duo, วงกลม+เส้นบาง) → 3 คน (group: 2 หัวหน้า + 1 หัวหลังตรงกลางสูงกว่า, ไหล่โค้ง 2 อัน)
   ตรงภาพอ้างอิงที่ Founder ส่ง
2. ไอคอน "แชท" — จากบับเบิลสี่เหลี่ยมมีหาง (ไม่มีจุดข้างใน) → บับเบิลกลมมีหางเล็กมุมล่างซ้าย + จุดไข่ปลา 3 จุดตรงกลาง
   ตรงภาพอ้างอิงที่ Founder ส่ง
3. ไอคอน "หน้าหลัก" / "โพสต์" / "โปรไฟล์" — ตรงภาพอ้างอิงอยู่แล้ว **ไม่ต้องแก้รูปทรง**
Interactions: เพิ่ม press-feedback มาตรฐานเดียวกับทั้งระบบ (WYN-163/175/176) — `transform: scale(0.96)`,
`transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)`, ปิด transition ใต้ `prefers-reduced-motion: reduce`
— เดิมแท็ปบาร์เป็นจุดเดียวในแอปที่ยังไม่มี motion นี้
States: active = `var(--wyn-text)` + ตัวหนา, inactive = `var(--wyn-text-secondary)` — พฤติกรรมเดิมทุกประการ
เปลี่ยนแค่จาก hex hardcode (`#737373` / `color: var(--wyn-text, #111111)`) เป็น token ล้วน (ไม่มี fallback hex ซ้อน
เพราะ token มีอยู่แล้วเสมอใน `:root`) — **ไม่ใช้สี accent, ไม่มี filled/circle treatment แบบ Apple-style, คงกติกาเดิม
ใน `bottom-nav.css` ที่ระบุว่า "Active state uses darker/filled icon treatment only; no large selected tile"**
Responsive Behavior: ไม่เปลี่ยน (มือถือ 44px content height / desktop floating dock 64px เหมือนเดิม)
Accessibility: คง touch target ≥44px เดิม, `aria-label` ทุกไอคอนเดิมอยู่แล้วไม่กระทบ, ไอคอนใหม่ยังเป็น `aria-hidden="true"`
เหมือนเดิม (label ที่แท้จริงมาจาก `aria-label` บน `<Link>`)
Design Rules:
- ไม่แตะสี ไม่เพิ่ม accent — ตรง "ห้ามคิดทิศทาง visual ใหม่หากมี design system ที่อนุมัติแล้ว"
- ลำดับ/ป้ายกำกับ/จำนวนแท็บ (หน้าหลัก/คลับ/โพสต์/แชท/โปรไฟล์) **ไม่เปลี่ยน** — ตรงกับคำสั่งถาวรเดิมของ Founder
  (2026-09-16, ดู `.wyn/logs/deployments/2026-09-16-web-bottom-nav-revert-deploy.md`) พอดี ไม่ต้องแก้ DECISIONS.md
- Bonus cleanup (แนะนำให้ทำพร้อมรอบนี้ เพราะแตะไฟล์เดียวกันอยู่แล้ว): `BottomNavigation` component รับ prop
  `notificationLabel`/`notificationBadge` จาก `app-bottom-nav-runtime.tsx` แต่ไม่เคย destructure/render เลย — เป็น
  dead code ค้างจากก่อน revert PR #468 (ตอนนั้นมีแท็บแจ้งเตือนในแท็ปบาร์) badge จริงตอนนี้ไปแสดงที่ไอคอนแจ้งเตือนบน
  header แทนแล้ว (`home-header.tsx` มี `.wyn-home-chat-badge`) ไม่กระทบผู้ใช้แต่ควรลบ prop/CSS `.route-nav-badge` ที่ไม่มี
  consumer ทิ้งเพื่อความสะอาดของโค้ด (ตาม pattern เดียวกับ WYN-172)
Handoff: → **AI Coding**: แก้ 2 ไฟล์ (`web/components/bottom-navigation.tsx`, `web/app/bottom-nav.css`) ตาม spec ข้างต้น
ทั้งหมด รัน `npm run check` (lint+typecheck+build) ก่อนส่งต่อ QA เสมอ อ้างอิง preview ที่ Founder อนุมัติ:
https://claude.ai/artifact/9sn3tgjf4FK7v5UosLCZga (แถว "เสนอใหม่ (After)" อันแรกที่เคยเผยแพร่ — ไม่ใช่ 2 แถว Apple-style
ที่เพิ่มเข้ามาทีหลัง)
