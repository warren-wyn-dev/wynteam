# Design Task — WYN-170

Status: approved (Founder อนุมัติ scope สุดท้าย "เอาแบบนี้เลย" — ส่งต่อ AI Coding)
Owner: AI Design → Founder → รอ AI Coding → AI QA & Security → AI Deploy & DevOps
Screen: WYNOS Web Chat Inbox (`/chat`, `web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css`)
Purpose: แก้จุดบกพร่องที่ Founder พบจากภาพหน้าจอจริง ("ออกแบบหน้าใหม่ได้ไหม มันไม่สวย") ผ่าน 6 รอบ feedback
(ดูสรุปเต็มที่ `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md` หัวข้อ "สรุปขอบเขตสุดท้าย (v6)")
User Flow: เปลี่ยนวิธีเข้าถึง "คำขอข้อความ" จาก modal popup เป็นปุ่ม toggle เดียวที่สลับเนื้อหาในหน้าเดิม,
เอาปุ่มเขียนข้อความใหม่ออกจากหน้านี้ (เริ่มแชทใหม่ผ่านหน้าโปรไฟล์แทน — ของเดิมที่มีอยู่แล้ว)
Components:
- Header: ซ้าย = ปุ่มย้อนกลับ ← เดิม (ไม่เปลี่ยน), กลาง = title "ข้อความ" ชิดซ้าย (เปลี่ยนจาก center), ขวา =
  ปุ่ม "คำขอ" ตัวเดียว (toggle, มี badge) — ไม่มีปุ่มเขียนข้อความใหม่/ปุ่มลอยในหน้านี้แล้ว
- Search bar: ลดความสูง 50px → 40px
- Notes row: เพิ่ม `.is-solo` modifier ลด min-height เมื่อมีแค่การ์ดตัวเอง
- Chat list rows: ทรงเรียบแบน (ไม่มีการ์ด/มุมโค้ง) + press-scale `:active`
- ท้ายรายการ: end-of-list marker ("เห็นข้อความล่าสุดแล้ว") ต่อท้าย `.chat-list` เสมอ
- Requests: ย้ายจาก modal เป็น inline panel แทนที่ `.chat-list` เมื่อ toggle "คำขอ" active
Interactions: press-scale บนแถวแชท/ปุ่ม "คำขอ" (สูตร WYN-163/167/169), toggle "คำขอ" สลับเนื้อหาแบบ inline,
ยอมรับ/ลบคำขอเรียก `decide()` เดิมไม่เปลี่ยน
States: `activeTab: "inbox" | "requests"` แทน `requestsOpen: boolean` เดิม, state ที่ 3 ของรายการแชท ("มี
ข้อความ + จบรายการแล้ว"), solo-state ของ Notes row
Responsive Behavior: ไม่เปลี่ยน ใช้ breakpoint เดิม
Accessibility: ปุ่ม "คำขอ" มี aria-pressed/aria-selected ชัดเจนว่า active หรือไม่, badge มี aria-label,
ท้ายรายการมีข้อความจริงอ่านได้, press-scale อยู่ใต้ prefers-reduced-motion เดิม — **หมายเหตุ**: search bar
40px ต่ำกว่า touch target ขั้นต่ำ DS-008 (44px) เล็กน้อย เป็นค่าที่ Founder ขอเจาะจงโดยรู้ตัว ให้ QA ตรวจสอบ
usability จริงและรายงานถ้ามีปัญหาชัดเจน
Design Rules: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md` — ใช้ token/motion/
รัศมี/badge pattern เดิมทั้งหมด ไม่ประดิษฐ์ใหม่, ไม่แตะ `.route-*` ที่ใช้ร่วมหลายหน้าจอ, ไม่แตะเนื้อหา/ฟังก์ชัน
การ์ดโน้ต, ไม่เพิ่มปุ่ม filter (ยังไม่มีฟีเจอร์รองรับจริง)
Handoff: พร้อมส่ง AI Coding ทันที — ไฟล์ที่แตะ: `web/components/chat-inbox-parity.tsx` (เปลี่ยน
`requestsOpen`→`activeTab`, ย้าย requests list ออกจาก modal เป็น inline panel, ลบปุ่ม/state/logic ของ
new-message modal ทั้งหมด — `newOpen`/`findPeople`/`startConversation`/`people`/`peopleQuery`/`finding`,
title เปลี่ยน text-align), `web/app/chat-notes.css` (CSS marker ท้ายรายการ, ปุ่ม "คำขอ" toggle ใหม่, แถวแชท
เรียบแบน + press-scale, `.is-solo` modifier, search bar 40px, ลบ CSS ของปุ่ม compose/FAB ที่ไม่ใช้แล้ว) —
**ไฟล์เดียวกับที่ WYN-169 เพิ่งแตะเมื่อไม่กี่ชั่วโมงก่อน ต้องตรวจไม่ให้ชนกับ motion CSS ของ WYN-169** ความเสี่ยง
regression **กลาง** (แตะ interaction/state logic จริง โดยเฉพาะ flow ยอมรับ/ลบคำขอที่ย้ายจาก modal มาเป็น
inline — QA ต้องทดสอบละเอียด ไม่ใช่แค่ดูภาพ)

## ลำดับเหตุการณ์ (6 รอบ feedback)

1. v1: เสนอแค่ท้ายรายการกันพื้นที่ว่าง + press feedback พร้อม demo — Founder ถาม "โอเค แก้แค่นี้หรอ"
2. v2: เสนอขยายเป็น squircle card + Notes row solo state — **Founder อนุมัติ "ขยาย — ทำให้ครบ"**
3. v3: Founder ส่งภาพอ้างอิง Instagram จริง — ตอบ: เปลี่ยนแถวกลับเป็นเรียบแบน + เพิ่มแท็บกล่องข้อความ/คำขอ
4. Founder ดู demo v3 แล้วตอบ "ก็โอเคนะ มันมีฟังชั่นโน๊ตด้วย" + ขอลดช่องค้นหา 50px→44px
5. Founder ส่งภาพ annotate ขอย้ายแท็บเข้า header แทนปุ่มย้อนกลับ/เขียนข้อความใหม่ + ลดช่องค้นหาอีกเป็น 40px
   — ตรวจโค้ดพบ swipe-back ไม่ทำงานจริงในหน้านี้ แต่ bottom nav มองเห็นอยู่แล้วตลอด จึงปลอดภัย
6. Founder ดู demo v4 แล้วขอเอาแท็บ "กล่องข้อความ" ออก คืนปุ่มย้อนกลับ ← เหลือปุ่ม "คำขอ" ตัวเดียวเป็น toggle
7. Founder ขอย้าย title "ข้อความ" ไปชิดซ้าย
8. Founder ถามปุ่มดินสอลอยคืออะไร แล้วขอเอาออก — ตรวจโค้ดพบทางเริ่มแชทใหม่อีกทาง (ปุ่ม "ส่งข้อความ" ในหน้า
   โปรไฟล์) ไม่ทำให้ผู้ใช้ติดค้าง จึงเอาออกได้
9. **Founder ดู demo v6 แล้วตอบ "เอาแบบนี้เลย" — อนุมัติ scope สุดท้าย** ส่งต่อ AI Coding

Demo สุดท้ายที่ Founder อนุมัติ: `https://claude.ai/artifact/2LA78untcXJXUzsHNhrpgG`
