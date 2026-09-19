# Design Task — WYN-170

Status: active (รอ Founder อนุมัติ scope v2 ที่ขยายแล้ว ก่อนส่ง AI Coding)
Owner: AI Design → รอ Founder → AI Coding → AI QA & Security → AI Deploy & DevOps
Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`)
Purpose: แก้จุดบกพร่องที่พบจากภาพหน้าจอจริงที่ Founder ส่งมา ("ออกแบบหน้าใหม่ได้ไหม มันไม่สวย") — พื้นที่ว่าง
โล่งขนาดใหญ่ท้ายรายการแชท + ยกระดับความรู้สึกพรีเมียมของ Notes row (ตอนมีแค่การ์ดเดียว) และแถวบทสนทนา (ให้เป็น
squircle card แบบ WYN-163/167 แทน flat list) — Founder อนุมัติขยายขอบเขตจาก v1 (แค่ข้อ 1) เป็น v2 (ครบทั้ง 3
จุด) แล้ว ไม่ใช่การรื้อ layout/IA ทั้งหน้า
User Flow: ไม่เปลี่ยน
Components:
- เพิ่ม "ท้ายรายการ" (end-of-list marker, ข้อความ "เห็นข้อความล่าสุดแล้ว") ต่อท้าย `.chat-list` เสมอ
- แถวบทสนทนา (`.chat-row`) เปลี่ยนจาก flat list + เส้นคั่น เป็น squircle card (`background: var(--wyn-surface)`,
  `border-radius: 18px`, margin แทนเส้นคั่น) + เพิ่ม `:active` press-scale
- `.wyn-chat-notes` เพิ่ม modifier `.is-solo` (เมื่อ `notes.length === 0`) ลด min-height ให้พอดีกับการ์ดเดียว
Interactions: press-scale `transform: scale(0.96)` บนการ์ดแชท (สูตรเดียวกับ WYN-163/167/169)
States: เพิ่ม state ที่ 3 ของรายการแชท ("มีข้อความ + จบรายการแล้ว"), เพิ่ม solo-state ของ Notes row
Responsive Behavior: ไม่เปลี่ยน ใช้ breakpoint เดิม ปรับแค่ margin ของการ์ดให้สอดคล้อง padding เดิม
Accessibility: ท้ายรายการมีข้อความจริงอ่านได้ (ไม่ใช่แค่ไอคอน), press-scale อยู่ใต้ prefers-reduced-motion
เดิมที่มีอยู่แล้วในไฟล์, touch target ของการ์ดแชทยังคง ≥44px เหมือนเดิม
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md` — ใช้ token/motion/
radius เดิมทั้งหมด (18px ยืนยันแล้วว่าเป็นค่าที่ใช้ซ้ำมากในระบบ ไม่ประดิษฐ์ใหม่), ไม่แตะปุ่มย้อนกลับ/`.route-*`
ที่ใช้ร่วมหลายหน้าจอ, ไม่แตะเนื้อหา/ฟังก์ชันของการ์ดโน้ต, ไม่รื้อ layout/IA
Handoff: พร้อมส่ง AI Coding ทันทีหลัง Founder อนุมัติ scope v2 — 2 ไฟล์ (`chat-inbox-parity.tsx` เพิ่ม JSX +
conditional class, `chat-notes.css` เพิ่ม/แก้ CSS) ความเสี่ยง regression ต่ำ-กลาง ไม่แตะ data/logic

## ลำดับเหตุการณ์

1. เสนอ scope v1 (แค่ท้ายรายการ + press feedback) พร้อม demo — Founder ถาม "โอเค แก้แค่นี้หรอ"
2. AI Design เสนอขยาย scope ให้ครอบคลุม Notes row solo state + squircle card ของแถวแชท — **Founder อนุมัติ
   "ขยาย — ทำให้ครบ"**
3. อัปเดตดีไซน์ doc เป็น v2 แล้ว กำลังทำ demo ใหม่ให้ Founder ดูก่อนอนุมัติ scope สุดท้าย
