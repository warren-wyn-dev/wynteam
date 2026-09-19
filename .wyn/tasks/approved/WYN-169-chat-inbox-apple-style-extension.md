# Design Task — WYN-169

Status: coding done — ส่งต่อ AI QA & Security
Owner: AI Design → Founder → AI Coding → รอ AI QA & Security → AI Deploy & DevOps
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
