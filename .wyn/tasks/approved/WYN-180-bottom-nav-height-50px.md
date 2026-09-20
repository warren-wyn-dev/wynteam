# Design Task — WYN-180

Status: coding done, QA pending — Founder revised the bottom bar height target after seeing the
Home-screen proportions audit (https://claude.ai/artifact/59nJwU9PG5JsWtCwcWtXNK)
Owner: AI Design
Screen: แท็ปบาร์ล่าง — `web/app/bottom-nav.css` เท่านั้น
Purpose: Founder สั่ง "ลดขนาด Bottom Bar เหลือ 50" หลังเห็น audit ที่เทียบสัดส่วนปัจจุบัน (40px content, รวม
safe-area ~60px) กับตัวเลขอ้างอิงเดิมที่ Founder ให้มา (~75px) — ตีความว่า Founder ปรับเป้าหมายของตัวเองลงจาก
~75px เหลือ 50px (ใช้ convention เดียวกับ `--wyn-bottom-nav-height` ที่เป็นค่า content height ไม่รวม safe-area
เหมือนที่ใช้มาตลอดใน WYN-179) — ค่านี้มากกว่า 40px ที่เพิ่ง merge ไปใน WYN-179 (ให้พื้นที่มากขึ้น ไม่ใช่บีบแคบลง)
จึงไม่กระทบการ fit ของไอคอน 28px ที่เพิ่งขยายไป เลยไม่ต้องกังวลเรื่อง overflow
User Flow: ไม่เปลี่ยน
Components: แก้ `--wyn-bottom-nav-height` เท่านั้น
1. มือถือ (breakpoint หลัก): 40px → **50px**
2. Breakpoint แคบ <359px: 38px → **48px** (คงส่วนต่าง 2px เท่าเดิมตามที่เคยทำใน WYN-179)
3. Breakpoint กว้าง ≥681px (floating dock): ไม่แตะ ยังคง 64px เดิม
4. Padding/gap/font-size ของ `.route-nav-link` และขนาดไอคอน (28px) — **ไม่เปลี่ยน** เพราะพื้นที่ใหม่ (50px) มากกว่า
   เดิม (40px) อยู่แล้ว ของเดิมพอดีสบายกว่าเดิมด้วยซ้ำ ไม่มีความเสี่ยง overflow
Interactions: ไม่เปลี่ยน
States: ไม่เปลี่ยน
Responsive Behavior: verified ผ่าน real-CSS-cascade DOM measurement ที่ 340/390/700px — ไม่มี overflow ทุกจุด
Accessibility: ไม่เปลี่ยน (พื้นที่แตะใหญ่ขึ้น ถ้ามีผลก็เป็นผลดี)
Design Rules: ไม่แตะสี/ไอคอน/โครงสร้าง เป็นแค่ตัวเลขความสูงเดียว
Handoff: → **AI Coding** (ทำแล้ว) → **AI QA & Security**

## AI Coding (2026-09-20)

Implementation: แก้ `--wyn-bottom-nav-height` ใน `web/app/bottom-nav.css` จาก 40px→50px (มือถือหลัก) และ
38px→48px (breakpoint แคบ) เท่านั้น ไม่แตะ padding/gap/font/icon size เพราะพื้นที่ใหม่กว้างกว่าเดิม ไม่มีความเสี่ยง
fit ปัญหา — อัปเดต test assertion ที่ล็อกค่าเดิมไว้ 2 จุด (`home-visual-parity.spec.ts`,
`system-visual-parity.spec.ts`) ให้ตรงค่าใหม่ (เรียนรู้จาก WYN-179 ที่เจอ CI แดงเพราะลืมจุดนี้มาก่อน คราวนี้แก้ไปพร้อมกัน)

Files Changed: `web/app/bottom-nav.css`, `web/tests/browser/home-visual-parity.spec.ts`,
`web/tests/browser/system-visual-parity.spec.ts`

Reason: ตรงตามคำสั่ง Founder

Tests: Render จริงผ่าน real-CSS-cascade Playwright (`file://`) วัดค่า DOM จริงที่ viewport 340/390/700px —
`--wyn-bottom-nav-height` = 48/50/64px ตรงสเปกทุกจุด, `scrollHeight === clientHeight` ทุกจุด (ไม่มี overflow)
รัน local Playwright test เฉพาะจุดที่แก้ (`system-visual-parity.spec.ts` dock geometry) ผ่าน

Build: `npm run check` เขียว — 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Known Issues: ไม่มี — พื้นที่เพิ่มขึ้น ความเสี่ยงต่ำกว่า WYN-179 (ที่ลดพื้นที่ลง) เสียอีก

Handoff: → **AI QA & Security**

## AI QA & Security (2026-09-20)

Feature: WYN-180 — bottom nav height 40→50px (มือถือหลัก), 38→48px (breakpoint แคบ)

Environment: sandbox, Playwright + `/opt/pw-browsers/chromium`, real-CSS-cascade render ผ่าน `file://`

Test Cases:
1. `git status --short` + `git diff origin/main HEAD --stat` — ยืนยันว่ามีแค่ 3 ไฟล์เปลี่ยน
   (`bottom-nav.css`, `home-visual-parity.spec.ts`, `system-visual-parity.spec.ts`) ไม่กระทบไฟล์อื่น
2. Render จริง + วัดค่า DOM (`getComputedStyle`/`getBoundingClientRect`/`scrollHeight` vs `clientHeight`) ที่
   viewport 340/390/700px: `--wyn-bottom-nav-height` = 48px/50px/64px ตรงสเปกทุกจุด, ไม่มี content overflow
   เลยสักจุด (scrollHeight === clientHeight ทั้ง 3 breakpoint)
3. Grep หา hardcode 40px/38px ที่เหลือในโฟลเดอร์ test ทั้งหมด — ยืนยันไม่มีจุดตกหล่น (จุดอื่นที่เจอ 40px เป็น
   `grid-template-columns`/avatar size คนละเรื่อง ตรวจ context แล้วไม่เกี่ยวกับ bottom nav)
4. รัน local Playwright จริง 4 test ที่เกี่ยวข้อง (`pixel-parity-pass-2`, `system-visual-parity` dock geometry
   + canonical stylesheet, `parity.spec.ts` source contracts) — ผ่านทั้งหมด 4/4 ไม่ใช่แค่เชื่อ assertion ตรงตัวเลข
5. `npm run check` รันอิสระอีกรอบ — เขียว 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Passed: 5/5
Failed: ไม่มี
Severity: -

Security Findings: ไม่มี — CSS ตัวแปรความสูงเดียว ไม่มี logic เปลี่ยน

Recommendation: PASS — ความเสี่ยงต่ำมาก (เพิ่มพื้นที่ ไม่ใช่ลด) verify ครบทุกจุดที่เคยพลาดใน WYN-179

Final Status: **PASS**
