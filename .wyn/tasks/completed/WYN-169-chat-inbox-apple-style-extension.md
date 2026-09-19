# Design Task — WYN-169

Status: เสร็จสมบูรณ์ — Founder ยืนยัน production จริงแล้ว ("โอเคแล้ว", 2026-09-19 — ยืนยันรวมกับ WYN-170
เพราะ UI ของ WYN-169 ถูกแทนที่ด้วย WYN-170 ไปแล้วก่อนได้รับการยืนยันแยก)
Owner: AI Design → Founder → AI Coding → AI QA & Security → AI Deploy & DevOps → รอ Founder ยืนยัน production จริง
Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`)
Purpose: ขยายภาษา press-scale motion จาก WYN-163/167 มาที่ปุ่ม header 2 จุดของ Chat Inbox
(`.wyn-chat-compose-action`, `.wyn-chat-requests-link`) — ขอบเขตแคบเหมือน WYN-167 เป๊ะ ไม่แตะขนาด/สี/layout
User Flow: ไม่เปลี่ยน
Components: `.wyn-chat-compose-action`, `.wyn-chat-requests-link` (ทั้งคู่ประกาศใน `chat-notes.css` เท่านั้น
ไม่ใช้ร่วมกับหน้าอื่น — ยืนยันด้วย grep แล้ว)
Interactions: press-scale `transform: scale(0.96)` (สูตรเดียวกับ WYN-163/167)
States: เพิ่ม pressed state ใหม่ 2 จุด
Responsive Behavior: ไม่เปลี่ยน
Accessibility: เพิ่ม `prefers-reduced-motion` fallback (ปัจจุบัน `chat-notes.css` ไม่มีเลย)
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-169-chat-inbox-apple-style-extension.md` — **ไม่แตะ**
`.flutter-chat-header-action` (ปุ่มย้อนกลับ — ประกาศซ้ำ 4 ไฟล์ CSS ต้องตรวจ cascade ก่อนแยกต่างหาก), **ไม่แตะ**
`.route-primary`/`.route-secondary`/`.route-pill`/`.route-icon-button` (ใช้ร่วมหลายหน้าจอ), **ไม่ทำ** WYN-159
(backlog เดิม — rebuild หน้าแชทแบบเธรดเต็มรูปแบบ, สมมติฐานสี Cyan ล้าสมัยไม่ตรงกับโค้ดจริง)
Handoff: พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ scope — ไฟล์เดียว (`web/app/chat-notes.css`), ความเสี่ยง
regression ต่ำมาก

## Founder Approval (2026-09-19)

1. เห็นด้วยกับขอบเขตนี้ไหม? — **Founder ตอบ "เห็นด้วย"** อนุมัติขอบเขต WYN-169 ตามที่เสนอ (ปุ่ม header
   2 จุดเท่านั้น ไม่แตะปุ่มย้อนกลับ/การ์ดโน้ต/ไม่ทำ WYN-159)
2. อยากให้หยิบ WYN-159 มาทบทวนใหม่เป็นงานแยกในอนาคตไหม? — **Founder ตอบ "ใช่"** บันทึกไว้ที่
   `.wyn/tasks/backlog/WYN-159-chat-web-threads-redesign.md` แล้ว (ยัง backlog รอจัดลำดับงาน)

ส่งต่อ AI Coding ทันที

## AI Coding (2026-09-19)

Implementation: เพิ่ม `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1);` ในบล็อกฐานของ
`.wyn-chat-compose-action` และ `.wyn-chat-requests-link` พร้อม rule `:active { transform: scale(0.96); }`
ใหม่ต่อท้ายแต่ละ class (สูตร/ค่าคัดลอกจาก `.wyn-home-header-action`/`.wyn-post-follow-pill` ใน `home.css`
เป๊ะทุกตัวอักษร) และเพิ่ม `@media (prefers-reduced-motion: reduce) { .wyn-chat-compose-action,
.wyn-chat-requests-link { transition: none; } }` ที่ท้ายไฟล์ (ก่อนหน้านี้ไฟล์นี้ไม่มี reduced-motion
handling เลย)

Files Changed: `web/app/chat-notes.css` (ไฟล์เดียว, +17 บรรทัด, ไม่มีการลบ/แก้บรรทัดเดิม)

Reason: ขยายภาษา press-scale motion ของ WYN-163/167 มาที่ปุ่ม header 2 จุดของ Chat Inbox ตามที่ Founder
อนุมัติ ไม่แตะขนาด/สี/layout ของปุ่มทั้งสอง ไม่แตะ `.flutter-chat-header-action` (ปุ่มย้อนกลับ — ประกาศซ้ำ
4 ไฟล์ CSS), ไม่แตะ `.route-*` classes ที่ใช้ร่วมหลายหน้าจอ, ไม่ทำ WYN-159

Tests: ไม่มี automated test เดิมของ Chat Inbox ในโปรเจกต์ (ต่างจาก Home feed ที่มี `/dev/home-fixture` +
`home-visual-parity.spec.ts`) — ตรวจ diff ด้วยตาเทียบกับ `home.css` pattern เดิมทีละบรรทัด ยืนยันว่า
scope ตรงตาม design spec 100% (ไม่มีบรรทัดอื่นถูกแตะ) ลอง render หน้า `/chat` จริงในเครื่อง sandbox ไม่ได้
เพราะ environment นี้ไม่มีค่า Supabase/Firebase ตั้งค่าไว้ (หน้าขึ้น "ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS
สำหรับเว็บ") — ข้อจำกัดเดียวกับที่เจอตอน WYN-167 จนต้องทำ interactive HTML demo แทน (ดู Artifact
`https://claude.ai/artifact/U9m2roJRghCz7MhoAsgYcN` ที่ Founder ดูก่อนอนุมัติ scope ไปแล้ว ใช้ค่า CSS
ชุดเดียวกับที่ implement จริงในรอบนี้เป๊ะ)

Build: `npm run check` (lint + typecheck + build) ผ่านทั้งหมด — lint 0 errors (มี 3 warnings เดิมที่ไม่
เกี่ยวกับไฟล์นี้), typecheck ผ่าน, `next build` compile สำเร็จทุก route รวม `/chat`

Known Issues: ไม่มีการตรวจ live browser interaction ในรอบนี้เพราะข้อจำกัด environment ตามที่ระบุใน Tests
— ขอให้ AI QA & Security ตรวจเพิ่มเติมว่ามีวิธีทดสอบแบบ live ได้หรือไม่ (เช่น mock/fixture route ใหม่ หรือ
รอ staging), และตรวจ cross-browser/reduced-motion behavior ตามมาตรฐานเดิม

Handoff: ส่งต่อ AI QA & Security — ตรวจ regression บนหน้า Chat Inbox ทั้งหมด (ไม่ใช่แค่ 2 ปุ่มที่แก้),
ตรวจว่าปุ่มย้อนกลับยังไม่มี motion ตามที่ตั้งใจ, ตรวจ reduced-motion fallback ทำงานจริง, ตรวจว่าไม่มี CSS
อื่นใน `chat-notes.css` ถูกกระทบโดยไม่ตั้งใจ

## AI QA & Security (2026-09-19)

Feature: WYN-169 press-scale motion บน `.wyn-chat-compose-action` / `.wyn-chat-requests-link` (Chat Inbox
header), ยืนยันว่าปุ่มย้อนกลับ (`.flutter-chat-header-action`) ยังไม่มี motion ตามที่ออกแบบไว้

Environment: sandbox นี้ render หน้า `/chat` จริงไม่ได้ (ไม่มีค่า Supabase/Firebase — หน้าขึ้น "ยังไม่ได้
ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ" ตามที่ AI Coding รายงานไว้จริง) — ไม่มี fixture route สำหรับ Chat
Inbox อยู่แล้วในโปรเจกต์ (ต่างจาก Home ที่มี `/dev/home-fixture`) และ `ChatInboxParityRoute` ไม่รับ props
เลย (ดึงข้อมูลเองข้างในผ่าน hook) ทำให้สร้าง fixture แบบ Home ในรอบนี้ไม่คุ้มความเสี่ยง (ต้อง mock
data-fetching hook ภายใน ซึ่งเกินขอบเขตงาน CSS-only ชิ้นนี้ไปมาก) — แทนที่ด้วยการสร้างหน้าทดสอบแยก
(`/tmp` scratchpad, ไม่ commit) ที่ดึง **ไฟล์ CSS จริงจาก repo ตรงๆ** (`system-parity-lock.css` →
`pixel-parity-audit-closure.css` → `design-system.css` → `notifications-clean.css` → `chat-notes.css`
เรียงลำดับ import เดียวกับ `app/layout.tsx` เป๊ะ ยืนยัน import order จากไฟล์จริงก่อนสร้าง) ผ่าน static
file server ชั่วคราว (`python3 -m http.server`, ไม่ commit, ปิด process หลังใช้เสร็จ) ใช้ markup ของ header
คัดลอกจาก `chat-inbox-parity.tsx` บรรทัดจริง แล้วรัน Playwright (`playwright-core` +
`/opt/pw-browsers/chromium`) จำลอง `:active`/`prefers-color-scheme`/`prefers-reduced-motion` จริง — เป็น
วิธีที่แม่นยำกว่า mockup ด้วยค่าคัดลอกมือ (แบบ Artifact demo ที่ Founder เคยดู) เพราะดึง CSS ไฟล์จริงจาก
repo ทั้งหมด ไม่ใช่ค่าที่ AI พิมพ์ซ้ำเอง

Test Cases:
1. `.wyn-chat-compose-action`/`.wyn-chat-requests-link` มี `transition: transform` และเมื่อกดค้าง (mouse
   down จริงผ่าน Playwright, วัด mid-transition ที่ 80ms เข้า transition 160ms) `transform` ขยับเข้าใกล้
   `scale(0.96)` จริง (วัดได้ `matrix(0.956-0.958, ...)` ระหว่างเคลื่อนที่ — ตรงตามสูตร spring easing)
2. `.flutter-chat-header-action` (ปุ่มย้อนกลับ) กดค้างแล้ว `transform` ยังคง `"none"` ในทุกกรณี (light/dark
   × reduced-motion on/off) — ยืนยันว่าไม่มี motion ถูกเพิ่มเข้าไปจริง ตรงตามขอบเขตที่ออกแบบไว้
3. `@media (prefers-reduced-motion: reduce)` — เปิด emulation จริงผ่าน Playwright
   (`reducedMotion: "reduce"`) ยืนยันว่า `.wyn-chat-compose-action`/`.wyn-chat-requests-link` มี
   `transitionProperty` เป็น `"none"` และปุ่มยังคง snap ไป `scale(0.96)` ทันทีตอนกด (ไม่ใช่ไม่มี feedback
   เลย — behavior ถูกต้องตรงมาตรฐานเดิมของ WYN-163/167)
4. ตรวจ regression contrast (ป้องกันบั๊กแบบ WYN-168 ซ้ำ) — คำนวณ WCAG contrast ratio จริงจาก
   `getComputedStyle()` ของทั้ง 3 ปุ่ม (compose/requests/back) เทียบพื้นหลังจริง ทั้ง light และ dark mode:
   compose/requests = 19.80:1 (light) / 21:1 (dark), back button = 19.80:1 (light) / 21:1 (dark) — **ผ่าน
   WCAG AA (≥4.5:1) แบบขาดลอยทุกจุด ไม่มี regression** (พบ false positive ระหว่างตรวจรอบแรกที่โหลด CSS ไม่
   ครบ 4 ไฟล์ ทำให้ปุ่มย้อนกลับไม่มี `color` rule เลยและตกไปใช้สี link สีน้ำเงิน default ของ browser แทน —
   แก้โดยโหลด cascade ให้ครบตามลำดับ import จริงแล้ววัดซ้ำ ยืนยันว่าเป็นปัญหาจาก test harness เอง ไม่ใช่บั๊ก
   จริงในโค้ด — `color` ตัวจริงถูกกำหนดจาก `notifications-clean.css` (`color: var(--wyn-text) !important`)
   ซึ่งชนะทุกไฟล์อื่นเพราะเป็น `!important` เดียวที่ตั้งค่า `color` ของ class นี้)
5. ตรวจ diff ของ `web/app/chat-notes.css` ทีละบรรทัดเทียบ git history — ยืนยันว่ามีแค่ 17 บรรทัดที่เพิ่ม
   (2 × `transition` ในบล็อกฐาน, 2 × `:active` rule ใหม่, 1 × `@media (prefers-reduced-motion: reduce)`
   block ท้ายไฟล์) ไม่มีบรรทัดอื่นถูกลบ/แก้ไข ไม่มีผลกระทบต่อ `.wyn-chat-note-card`, `.route-*` classes,
   หรือ selector อื่นใดในไฟล์เดียวกัน
6. รัน `npm run check` (lint + typecheck + build) ซ้ำอิสระจาก AI Coding — ผ่านทั้งหมดตรงกับที่ AI Coding
   รายงาน (lint 0 errors/3 warning เดิมไม่เกี่ยวกับไฟล์นี้, typecheck ผ่าน, build ผ่านทุก route)

Passed: 6/6 test cases ข้างต้น

Failed: ไม่มี

Severity: N/A (ไม่พบบั๊ก)

Security Findings: ไม่มี — เป็น CSS-only change ไม่มี data flow/auth/input handling เกี่ยวข้อง

Recommendation: PASS — ส่งต่อ AI Deploy & DevOps ได้ทันที ไม่มี blocker ระดับใดเลย ข้อสังเกตเสริม (ไม่ใช่
blocker): โปรเจกต์ยังไม่มี automated visual-regression test ของ Chat Inbox เหมือนที่ Home feed มี
(`home-visual-parity.spec.ts` + `/dev/home-fixture`) — ถ้าต้องแก้ Chat Inbox บ่อยขึ้นในอนาคต ควรพิจารณา
สร้าง fixture route ถาวรแบบเดียวกัน (เป็นงานแยก ไม่ใช่ส่วนหนึ่งของ WYN-169 นี้)

Final Status: PASS

## AI Deploy & DevOps (2026-09-19)

Release: WYN-169 — Chat Inbox header button press-scale motion
Version: within WYNOS Web Beta1 — no version bump
QA Status: PASS (6/6 test cases, see above)
Build Status: `npm run check` green (independently re-run a 3rd time before opening PR); PR #549 CI 11/11
green on first push, no CI-red rounds needed
Deployment Target: Vercel production (`wynos.online`), existing project
Changes: `web/app/chat-notes.css` only, +17 lines
Deployment Result: PR #549 merged (`315e3acc`, Founder approved merge via popup confirmation), production
deploy workflow run #136 — all steps green (preflight, Vercel deploy, route verification), full `main`
CI workflow also green on the same commit. Full details: `.wyn/logs/deployments/2026-09-19-wyn-169-chat-inbox-motion-deploy.md`
Production Verification: AI-confirmed via the deploy workflow's own route-verification step — sandbox itself
cannot reach `wynos.online` directly. **รอ Founder เปิดเว็บจริงยืนยัน** ก่อนย้าย task นี้ไป `completed/`
Rollback Plan: fix-forward หรือ revert single commit (`web/app/chat-notes.css` only, additive-only change,
ไม่กระทบไฟล์อื่น) — hard rollback ต้องได้รับคำสั่ง Founder ชัดเจน
