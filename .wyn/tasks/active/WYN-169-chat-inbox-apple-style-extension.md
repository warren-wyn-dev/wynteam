# Design Task — WYN-169

Status: active (รอ Founder อนุมัติ scope ก่อนส่ง AI Coding)
Owner: AI Design → รอ Founder → AI Coding → AI QA & Security → AI Deploy & DevOps
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

## คำถามรอ Founder ตอบ

1. เห็นด้วยกับขอบเขตนี้ไหม (แค่ปุ่ม header 2 จุด ไม่แตะปุ่มย้อนกลับ/การ์ดโน้ต/ไม่ทำ WYN-159)?
2. อยากให้หยิบ WYN-159 มาทบทวนใหม่เป็นงานแยกในอนาคตไหม?
