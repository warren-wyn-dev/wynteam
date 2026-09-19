# Design Task — WYN-170

Status: active (รอ Founder อนุมัติ scope ก่อนส่ง AI Coding)
Owner: AI Design → รอ Founder → AI Coding → AI QA & Security → AI Deploy & DevOps
Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`)
Purpose: แก้จุดบกพร่องที่พบจากภาพหน้าจอจริงที่ Founder ส่งมา ("ออกแบบหน้าใหม่ได้ไหม มันไม่สวย") — พื้นที่ว่าง
โล่งขนาดใหญ่ท้ายรายการแชทเมื่อมีข้อความไม่พอเต็มจอ (ไม่มี state นี้ออกแบบไว้เลยในโค้ดเดิม) + เพิ่ม press
feedback ให้แถวบทสนทนา ไม่ใช่การรื้อ layout/IA ทั้งหน้า
User Flow: ไม่เปลี่ยน
Components: เพิ่ม "ท้ายรายการ" (end-of-list marker) ต่อท้าย `.chat-list` เสมอ, เพิ่ม `:active` press-scale ให้
`.wyn-chat-inbox .flutter-chat-list .chat-row`
Interactions: press-scale `transform: scale(0.96)` บนแถวบทสนทนา (สูตรเดียวกับ WYN-163/167/169)
States: เพิ่ม state ที่ 3 ที่ขาดไปของรายการแชท ("มีข้อความ + จบรายการแล้ว") แยกจาก empty เดิมและ loading เดิม
Responsive Behavior: ไม่เปลี่ยน ใช้ breakpoint เดิม
Accessibility: ท้ายรายการมีข้อความจริงอ่านได้ (ไม่ใช่แค่ไอคอน), press-scale อยู่ใต้ prefers-reduced-motion
เดิมที่มีอยู่แล้วในไฟล์
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md` — ใช้ token/motion
เดิมทั้งหมด ไม่ประดิษฐ์ใหม่, ไม่แตะ Notes row/ปุ่มย้อนกลับ/`.route-*` ที่ใช้ร่วมหลายหน้าจอ, ไม่รื้อ layout/IA
Handoff: พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ scope — 2 ไฟล์ (`chat-inbox-parity.tsx` เพิ่ม JSX,
`chat-notes.css` เพิ่ม CSS) ความเสี่ยง regression ต่ำ ไม่แตะ data/logic

## คำถามรอ Founder ตอบ

1. เห็นด้วยกับขอบเขตนี้ไหม (เติม "ท้ายรายการ" กันพื้นที่ว่างโล่ง + press feedback ให้แถวบทสนทนา ไม่รื้อ
   layout/Notes row ทั้งหมด)?
2. ข้อความ "ท้ายรายการ" อยากให้เขียนว่าอะไร (เสนอ: "เห็นข้อความล่าสุดแล้ว") หรือให้ AI Design เลือกเอง?
