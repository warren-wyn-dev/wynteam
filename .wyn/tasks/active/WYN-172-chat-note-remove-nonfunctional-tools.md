# Design Task — WYN-172

Status: approved (Founder ตัดสินใจแล้ว — ส่งต่อ Coding พร้อม WYN-171)
Owner: AI Design → Founder → รอ Coding
Screen: WYNOS Web Chat Inbox — Note Composer (`web/components/chat-inbox-parity.tsx`,
`web/app/chat-notes.css`)
Purpose: เอาปุ่ม "สถานที่"/"อีโมจิ" ในหน้าเขียนโน้ตออก เพราะพบระหว่าง audit ฟังก์ชันโน้ต (2026-09-19) ว่า
ปุ่มทั้งสองไม่มี `onClick` ใดๆ เลย — กดแล้วไม่ทำอะไร แต่มี `aria-label` ทำให้ screen reader ประกาศราวกับใช้
งานได้จริง เป็นการหลอกผู้ใช้ (pattern เดียวกับที่ AI Design ปฏิเสธไม่เพิ่มปุ่ม filter ปลอมใน WYN-170)
User Flow: ไม่เปลี่ยนฟังก์ชันหลัก (พิมพ์โน้ต/แชร์/ลบยังทำงานเหมือนเดิมทุกประการ) แค่เอา UI ที่ไม่ทำงานออก
Components: เอา `<div className="wyn-note-tools">` ทั้งบล็อก (ปุ่ม "สถานที่" + "อีโมจิ") ออกจาก
`chat-inbox-parity.tsx`, เอา CSS ที่เกี่ยวข้องออกจาก `chat-notes.css` (`.wyn-note-tools`, `.wyn-note-tool`,
`.wyn-note-tool > span`, `.wyn-note-tool small`) รวมถึง responsive override ที่เกี่ยวข้อง
(`@media (max-height: 760px)` มี `.wyn-note-tools { margin-top: 14px }` ต้องเอาออกด้วย)
Interactions: ไม่มี (ลบ UI ที่ไม่มี interaction อยู่แล้วออก)
States: ไม่มีผลต่อ state ใดๆ ของ composer (ไม่แตะ noteDraft/noteSaving/noteOpen)
Responsive Behavior: หลังเอาออก ต้องตรวจว่า layout ของ `.wyn-note-stage` (avatar + editor) ยังดูสมดุลดี
ไม่เหลือช่องว่างแปลกๆ ด้านล่าง — ถ้าดูโหว่เกินไป ให้ปรับ spacing เล็กน้อยได้ (เช่น `padding-bottom` ของ
`.wyn-note-stage`) แต่ไม่ต้องรื้อ layout ใหม่
Accessibility: การลบปุ่มที่ไม่ทำงานออกทำให้ accessibility ดีขึ้นเอง (screen reader จะไม่ประกาศปุ่มหลอกอีก
ต่อไป)
Design Rules: ไม่ประดิษฐ์ปุ่ม/ฟีเจอร์ใหม่มาแทน ถ้า Founder อยากได้ฟีเจอร์ตำแหน่ง/อีโมจิจริงในอนาคต ต้องเป็น
งานแยกที่ผ่าน Product Manager ก่อน (เป็นฟีเจอร์ใหม่ ไม่ใช่แค่ UI cleanup)
Handoff: พร้อมส่ง Coding ทันที รวมไปกับ WYN-171 (ไฟล์เดียวกัน คนละจุดในไฟล์ ไม่ทับซ้อนกัน) ความเสี่ยง
regression ต่ำมาก (ลบ UI ที่ไม่เคยมีการเรียกใช้ logic ใดๆ)
