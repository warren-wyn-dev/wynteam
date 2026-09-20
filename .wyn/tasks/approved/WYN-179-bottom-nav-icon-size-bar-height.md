# Design Task — WYN-179

Status: coding done, QA pending — Founder chose Option C from the button/interaction demo
(https://claude.ai/artifact/RERjh7EmnTbXtE6sv1ve9N) plus two explicit sizing asks
Owner: AI Design
Screen: แท็ปบาร์ล่าง (bottom navigation) ทั้งระบบเว็บ — `web/app/bottom-nav.css` เท่านั้น (ไม่แตะ `bottom-navigation.tsx`
รอบนี้ ไม่มีการเปลี่ยนไอคอน/โครงสร้าง)
Purpose: Founder ขอ "ปุ่มไอคอนใหญ่ขึ้น แต่แท็ปบาร์ลดความสูงลงเท่าแพลตฟอร์มอื่น" ต่อจากที่เลือก Option C (baseline, ไม่มี
pill/elevated treatment) ในรอบก่อนหน้า — ตีความ "แพลตฟอร์มอื่น" เป็นบาร์ทรงกระชับแบบ Instagram/TikTok-style ที่ icon
ใหญ่กว่าสัดส่วนความสูงบาร์ (ไม่ใช่ Android Material 3 ที่สูงกว่านี้อีก) เพราะ Founder พูดถึง "ลดความสูงลง" คู่กับ "ไอคอน
ใหญ่ขึ้น" พร้อมกัน — ถ้าตีความผิดให้ Founder แก้ตัวเลขได้ทันทีจากภาพ before/after ที่แนบ
User Flow: ไม่เปลี่ยน
Components: ปรับเฉพาะตัวเลขใน `bottom-nav.css`:
1. `--wyn-bottom-nav-height` (มือถือ): 44px → **40px**
2. `.route-nav-glyph`/`.route-create-button`/`.route-nav-icon-wrap` (ไอคอน): 24px → **28px**
3. `.route-nav-link` padding: `2px 3px 3px` → `1px 3px 2px`, gap: 2px → 1px (บีบให้พอดีกับพื้นที่ที่เหลือหลังไอคอนใหญ่ขึ้น)
4. label font-size: 11.5px → **10px**
5. Breakpoint แคบ (<359px): height 42px→38px, font 10.5px→9.5px, ไอคอน 24px→**26px** (เล็กกว่าฐาน 28px เล็กน้อย
   เพราะพื้นที่แคบกว่า)
6. Breakpoint กว้าง (≥681px, floating dock): **ไม่แตะ** — ยังคง 64px เดิม เพราะ Founder น่าจะหมายถึงประสบการณ์มือถือหลัก
   ไม่ใช่ floating dock บนจอกว้าง (ถ้า Founder อยากให้ปรับด้วยจะแจ้งแก้เพิ่ม)
Interactions: ไม่เปลี่ยน (press-feedback จาก WYN-178 ยังอยู่ครบ)
States: ไม่เปลี่ยน
Responsive Behavior: ตามข้อ 5-6 ข้างบน — verified ผ่าน real-CSS-cascade render ที่ width 390px (มือถือทั่วไป)
Accessibility: ไอคอนใหญ่ขึ้นช่วย legibility; touch target ยังคง full-column-height (44-40px ยังเกิน 44px มาตรฐานไม่ครบ
เป๊ะที่ 40px แต่ทั้งคอลัมน์กว้าง ~78px คลิกได้ทั้งพื้นที่ ไม่ใช่แค่ไอคอน — เหมือนพฤติกรรมเดิมที่ไม่เคยเป็นปัญหา)
Design Rules: ไม่แตะสี/ไม่แตะ Option A/B (Founder เลือก C แล้ว) ไม่แตะไอคอนรูปทรง (WYN-178 อนุมัติแล้ว)
Handoff: → **AI Coding** (ทำแล้ว ดูด้านล่าง) → **AI QA & Security**

## AI Coding (2026-09-20)

Implementation: แก้ `web/app/bottom-nav.css` เท่านั้น ตามตัวเลขข้างบนทุกจุด

Files Changed: `web/app/bottom-nav.css`

Reason: ตรงตามคำขอ Founder

Tests: Render จริงผ่าน real-CSS-cascade Playwright (`file://` โหลด `design-system.css`+`bottom-nav.css` ตรงจาก repo
ไม่ผ่าน static server — เทคนิคใหม่ที่เสถียรกว่า http.server ในรอบนี้) เทียบ before (44px/24px, hand-copied ค่าเดิม) vs
after (40px/28px) ทั้ง light และ dark mode ที่ viewport 390px (มือถือทั่วไป) — ไม่มี clipping/overflow, สัดส่วนดูโปร่ง
ขึ้นตามที่ขอ

Build: `npm run check` เขียว — 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Known Issues: ยังไม่ verify breakpoint <359px และ ≥681px ด้วย real render (แก้แค่ตัวเลข ความเสี่ยง regression ต่ำ
เพราะโครงสร้างเดิมไม่เปลี่ยน) — เสนอให้ QA ตรวจเพิ่มถ้าเป็นไปได้

Handoff: → **AI QA & Security**

## AI QA & Security (2026-09-20)

Feature: WYN-179 — bottom nav icon size (24→28px) + bar height (44→40px) + related breakpoints

Environment: sandbox, Playwright + `/opt/pw-browsers/chromium`, real-CSS-cascade render via `file://` (โหลด
`design-system.css`+`bottom-nav.css` ตรงจาก path จริงในเครื่อง — วิธีนี้เสถียรกว่า http.server ที่เคยใช้ในรอบก่อนๆ
ของ session นี้ ไม่ต้องพึ่ง background process เลย)

Test Cases:
1. `git diff -- web/app/bottom-nav.css` — ยืนยันว่าทุกการเปลี่ยนแปลงเป็นแค่ตัวเลข (height/size/padding/gap/font-size)
   ตามที่ระบุใน spec ทุกจุด ไม่มีอะไรนอกเหนือ ไม่กระทบไฟล์อื่นเลย (`git status --short` ยืนยันมีแค่ไฟล์นี้เปลี่ยน)
2. Render จริง viewport 390px (มือถือทั่วไป) — วัดค่าจริงด้วย `getBoundingClientRect()`/`getComputedStyle()` ไม่ใช่
   ดูด้วยตาอย่างเดียว: `--wyn-bottom-nav-height` คำนวณได้ 40px ตรงสเปก, glyph render 28×28px ตรงสเปก, `link.scrollHeight
   (37) === link.clientHeight (37)` → **ไม่มี content overflow ออกนอกกรอบ** ยืนยันด้วยตัวเลขจริงไม่ใช่การเดาจากภาพ
3. Breakpoint แคบ <359px (ทดสอบจริงที่ viewport 340px): `--wyn-bottom-nav-height` = 38px ตรงสเปก, glyph 26×26px ตรง
   สเปก, `scrollHeight (35) === clientHeight (35)` → ไม่มี overflow เช่นกัน (นี่คือจุดที่ AI Coding ทำเครื่องหมายเป็น
   known issue ไว้ — ตรวจแล้วผ่าน)
4. Breakpoint กว้าง ≥681px/floating dock (ทดสอบจริงที่ viewport 700px): `--wyn-bottom-nav-height` ยังคง 64px
   (ไม่ถูกแตะจริงตามที่ตั้งใจ), glyph ยังคงขนาดฐานใหม่ 28×28px (ไม่มี override เฉพาะ breakpoint นี้ ถูกต้องตามสเปกข้อ 6),
   `scrollHeight (56) === clientHeight (56)` → พื้นที่ 64px เหลือเฟือสำหรับไอคอน 28px ไม่มี overflow
5. Light + dark mode ที่ viewport 390px (`page.emulateMedia`) — เทียบ before (44px/24px, hand-reconstructed จาก git
   history ของค่าเดิม) vs after (40px/28px) เห็นชัดว่าบาร์เตี้ยลง/ไอคอนใหญ่ขึ้นจริงตามคำขอ Founder ไม่มี clipping ทั้ง
   2 theme
6. Touch target: คอลัมน์แต่ละแท็บกว้าง ~78px ที่ 390px (78×40 = พื้นที่แตะต่อแท็บใหญ่กว่า Apple HIG ขั้นต่ำ 44×44
   หลายเท่าในแนวนอน แม้แนวตั้งจะเหลือ 40px ก็ตาม) และ ~68px ที่ breakpoint แคบสุด 340px — พฤติกรรมเดิมของแอปนี้ก็ไม่เคย
   ใช้ 44px แนวตั้งเต็มอยู่แล้ว (เดิม 44px ก็ไม่เป๊ะ 44 เพราะรวม safe-area แล้ว) ไม่ถือเป็น regression ใหม่
7. `npm run check` (lint + typecheck + `next build`) รันอิสระอีกรอบ — เขียว 0 error, warning เดิม 3 จุดไม่เกี่ยวข้อง

Passed: 7/7
Failed: ไม่มี
Severity: -

Security Findings: ไม่มี — CSS ตัวเลขล้วนๆ ไม่มี logic/data/auth เปลี่ยนแปลง

Recommendation: PASS — verify ครบทั้ง 3 breakpoint ด้วยตัวเลขจริงจาก DOM ไม่ใช่แค่ดูภาพ ทุกจุดตรงสเปกไม่มี overflow

Final Status: **PASS**

## Post-merge-attempt CI fix (2026-09-20)

`browser-qa` CI failed on PR #558 after this change pushed: 4 pre-existing source-contract tests
(`home-visual-parity.spec.ts`, `pixel-parity-pass-2.spec.ts`, `system-visual-parity.spec.ts`,
`parity.spec.ts`) hardcoded the old bottom-nav numbers (44px height, 24px icon, 11.5px label) as
"this must never change" assertions — legitimate contract tests doing their job, correctly catching
that this PR intentionally changes those numbers. Updated all 4 to the new Founder-approved values.
Verified 4/5 locally (the 5th, `home-visual-parity.spec.ts`, needs a real page load and hit this
sandbox's pre-existing `chromium_headless_shell-1243` binary mismatch — same limitation documented
earlier this session, unrelated to this change); its edit is the same mechanical value swap and the
40px/28px numbers were already confirmed correct via direct DOM measurement in the QA pass above.
`npm run check` green. Pushed as commit `6bcb6703`.
