# Design Task — WYN-170

Status: active (รอ Founder ดู demo v3 + อนุมัติ scope สุดท้าย ก่อนส่ง AI Coding)
Owner: AI Design → รอ Founder → AI Coding → AI QA & Security → AI Deploy & DevOps
Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`)
Purpose: แก้จุดบกพร่องที่พบจากภาพหน้าจอจริงที่ Founder ส่งมา ("ออกแบบหน้าใหม่ได้ไหม มันไม่สวย") ผ่าน 3 รอบ
feedback: v1 (ท้ายรายการกันพื้นที่ว่าง) → v2 (Founder อนุมัติขยาย: squircle card + Notes row solo state) →
v3 (Founder ส่งภาพอ้างอิง Instagram จริง: เปลี่ยนแถวกลับเป็นเรียบแบน + เพิ่มแท็บ "กล่องข้อความ/คำขอ" แทนปุ่ม
header เดิม)
User Flow: เปลี่ยนวิธีเข้าถึง "คำขอข้อความ" จาก modal popup เป็นแท็บสลับเนื้อหาในหน้าเดิม (ฟังก์ชันยอมรับ/ลบ
เหมือนเดิมทุกประการ)
Components:
- "ท้ายรายการ" (end-of-list marker, ข้อความ "เห็นข้อความล่าสุดแล้ว") ต่อท้าย `.chat-list` เสมอ
- แถวบทสนทนา: เรียบแบน (ไม่มีการ์ด/มุมโค้งแบบ v2) แต่คง press-scale `:active`
- `.wyn-chat-notes` เพิ่ม modifier `.is-solo` (เมื่อ `notes.length === 0`) ลด min-height
- ใหม่: `.wyn-chat-tabs` — แท็บ "กล่องข้อความ"/"คำขอ" (มี badge) ใต้ช่องค้นหา แทนปุ่ม "คำขอ N" เดิมใน header
  (ปุ่มเดิมถูกเอาออก) — ไม่เพิ่มปุ่ม filter icon (ยังไม่มีฟีเจอร์รองรับจริง)
Interactions: press-scale บนแถวแชท/แท็บ (สูตร WYN-163/167/169), กดแท็บ "คำขอ" แสดงรายการคำขอแทนที่ในพื้นที่
เดิม (ไม่ใช่ modal), ยอมรับ/ลบ เรียก logic เดิม (`decide()`) ไม่เปลี่ยน
States: `activeTab: "inbox" | "requests"` แทน `requestsOpen: boolean` เดิม, state ที่ 3 ของรายการแชท ("มี
ข้อความ + จบรายการแล้ว"), solo-state ของ Notes row
Responsive Behavior: ไม่เปลี่ยน ใช้ breakpoint เดิม
Accessibility: แท็บมี aria-selected/aria-pressed ชัดเจน, badge มี aria-label, ท้ายรายการมีข้อความจริงอ่านได้,
press-scale อยู่ใต้ prefers-reduced-motion เดิม, touch target ≥44px เหมือนเดิม
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md` — ใช้ token/motion/
รัศมี/badge pattern เดิมทั้งหมด ไม่ประดิษฐ์ใหม่, ไม่แตะปุ่มย้อนกลับ/`.route-*` ที่ใช้ร่วมหลายหน้าจอ, ไม่แตะ
เนื้อหา/ฟังก์ชันการ์ดโน้ต, ไม่เพิ่มปุ่ม filter, เอาปุ่ม "คำขอ" header เดิมออก (ฟังก์ชันย้ายไปแท็บแทน)
Handoff: รอ Founder ดู demo v3 ก่อนส่ง AI Coding — ไฟล์ที่แตะ: `chat-inbox-parity.tsx` (เพิ่ม JSX + เปลี่ยน
`requestsOpen`→`activeTab` + ย้าย requests list ออกจาก modal), `chat-notes.css` (CSS marker + แท็บ + แถวเรียบ
แบน + `.is-solo` + ลบ CSS ปุ่ม header เดิม) ความเสี่ยง regression **กลาง** (แตะ interaction/state logic จริง
ไม่ใช่แค่ presentational — QA ต้องทดสอบ flow ยอมรับ/ลบคำขอผ่าน tab ใหม่อย่างละเอียด)

## ลำดับเหตุการณ์

1. v1: เสนอแค่ท้ายรายการ + press feedback พร้อม demo — Founder ถาม "โอเค แก้แค่นี้หรอ"
2. v2: เสนอขยายเป็น squircle card + Notes row solo state — **Founder อนุมัติ "ขยาย — ทำให้ครบ"** พร้อม demo
3. v3: Founder ส่งภาพอ้างอิง Instagram จริง ("ตัวอย่าง") — ถาม 2 คำถาม (สไตล์แถว, เพิ่มแท็บไหม) **Founder
   ตอบ: เปลี่ยนเป็นเรียบแบน + เพิ่มแท็บด้วย** — กำลังอัปเดต demo ให้ดูก่อนส่ง Coding (เพราะเปลี่ยน
   interaction/state logic จริง ไม่ใช่แค่ CSS อีกต่อไป)
