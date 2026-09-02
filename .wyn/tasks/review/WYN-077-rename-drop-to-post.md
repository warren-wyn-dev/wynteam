# Feature Request — WYN-077

Status: backlog (ยังไม่เริ่ม — รอหยิบขึ้นมาทำตามลำดับ Phase)
Phase: Phase 0 — Global rename
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 1/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เปลี่ยนคำว่า "Drop" เป็น "โพสต์" และ "ReDrop" เป็น "รีโพสต์" ทั้งแอป
Goal: ให้ศัพท์ที่ผู้ใช้เห็นเป็นภาษาไทยที่เข้าใจง่าย สอดคล้องกับ brand ปัจจุบัน
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "เปลี่ยนจากคำว่า Drop เป็น โพสต์ หรือ รีดรอป เป็น รีโพสต์"
Requirements:
- ไล่หาทุกจุดที่ขึ้นคำว่า "Drop"/"ReDrop" ใน UI string ทั้ง `app/` (bottom nav, ปุ่มโพสต์, ช่อง search placeholder, ปุ่ม tab บนโปรไฟล์ ฯลฯ) แล้วเปลี่ยนเป็น "โพสต์"/"รีโพสต์"
- ตรวจว่ามีคำว่า Drop/ReDrop หลุดไปใน error message, notification text, deep-link label ด้วยหรือไม่
- **ไม่แตะ** ชื่อตัวแปร/class/table/column ในโค้ด (`drop_id`, `DropCard` ฯลฯ) — เปลี่ยนเฉพาะข้อความที่ผู้ใช้เห็น เพื่อลดความเสี่ยง regression
Acceptance Criteria:
- [ ] grep หาคำว่า "Drop"/"ReDrop" ที่เหลืออยู่ใน UI string ทั้งแอปแล้วต้องไม่มีเหลือ (ยกเว้นชื่อโค้ดภายใน)
- [ ] หน้าที่เคยมีคำว่า Drop/ReDrop (bottom nav, post composer, search placeholder, profile tab, repost header) แสดง "โพสต์"/"รีโพสต์" ถูกต้อง
Dependencies: ไม่มี — งานอิสระ ควรทำก่อนงานอื่นเพราะหลายข้อ (7, 9, 26) อ้างอิงหน้าจอเดียวกัน
Priority: สูง (ทำก่อนสุด กระทบทุกหน้าจอ เสี่ยงต่ำ)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เผลอเปลี่ยนชื่อ field/table ในโค้ดจนพัง | ต่ำ | จำกัดการเปลี่ยนเฉพาะ UI string เท่านั้น |
Recommendation: อนุมัติ ทำได้ทันทีเป็นงานแรก
Handoff: AI Coding ทำตรงได้เลย (ไม่ต้องผ่าน Design เพราะเป็นแค่เปลี่ยนข้อความ)
