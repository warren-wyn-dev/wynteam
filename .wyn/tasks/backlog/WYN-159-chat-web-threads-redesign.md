# Design Task — WYN-159

Status: backlog
Owner: AI Design
Screen: Chat Inbox (`components/chat-inbox-parity.tsx`) + Conversation (`components/chat-routes.tsx`) — WYNOS web (`web/`)
Purpose: ปรับหน้าแชทเว็บให้รู้สึก restrained/โล่ง/ทันสมัยแบบที่ Founder ขอ ("เหมือนเธรด") โดยพอร์ต message-grouping/bubble-tail/timestamp-reveal/read-receipt spec ที่อนุมัติแล้วสำหรับ Flutter (`wyn-031-chat-message-grouping-bubble-spec.md`) มาให้เว็บ — ไม่เปลี่ยนสี/ไม่คิดทิศทาง visual ใหม่ ใช้ DS-001 (Cyan+ดำ/ขาว/เทา) เดิม ห้าม Rainbow ในหน้าแชท
User Flow: ไม่เปลี่ยนจากเดิม (เข้าจาก bottom nav Chat tab → inbox → conversation) — เปลี่ยนแค่การแสดงผล/จังหวะ ไม่เปลี่ยนวิธีใช้งาน
Components: ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-159-chat-web-threads-redesign.md`
Interactions: tap bubble ตัวเอง = แสดงปุ่มลบ + timestamp พร้อมกัน (รวมกับพฤติกรรมเดิมจาก PR #498), tap bubble อีกฝ่าย = แสดง timestamp เฉยๆ
States: เพิ่ม read-receipt state บน bubble ส่งออกล่าสุด, ใช้ `is-pending` เดิมสำหรับ sending
Responsive Behavior: ไม่เปลี่ยน composer/safe-area ที่แก้ไปแล้วใน PR #498 — ทดสอบ 3 project เดิม (webkit-iphone/chromium-android/chromium-desktop)
Accessibility: bubble ต้องมี aria-label รวมผู้ส่ง+เวลา+เนื้อหาแม้ timestamp ไม่โชว์ถาวร, touch target ≥44px (DS-008), unread dot ใหม่ต้อง aria-hidden
Design Rules: ห้าม Cyan/Rainbow ในหน้าแชท, ห้าม liquid-glass, ใช้ token `--wyn-*` เดิมเท่านั้น ไม่ประดิษฐ์สีใหม่
Handoff: ดูลำดับงานเต็มที่ `.wyn/docs/design/wyn-159-chat-web-threads-redesign.md#handoff` — แนะนำให้ทำภาพเปรียบเทียบก่อน-หลังให้ Founder ดูก่อน AI Coding เริ่ม (ตามกติกาถาวร WYN-141) รอ Founder ยืนยันว่าต้องการดูภาพก่อนหรือให้เริ่ม coding ได้เลย

## Update (2026-09-19) — Founder ยืนยันอยากทบทวนใหม่

ระหว่างออกแบบ WYN-169 (Chat Inbox motion extension) AI Design ตรวจพบว่าเอกสารนี้อ้างอิง "DS-001 ยืนยันสีแบรนด์
WYN คือ Cyan `#00C8FF`" ซึ่ง**ไม่ตรงกับโค้ดจริงของเว็บ ณ วันที่ 19 ก.ย. 2026** — เว็บใช้ระบบ token
`--wyn-bg`/`--wyn-text`/`--wyn-surface` (ขาว-ดำ-เทา) + `--wyn-accent:#e0203d` (แดง สงวนไว้เฉพาะ error) ไม่มี
Cyan อยู่ในระบบเลย (สมมติฐานสีน่าจะอ้างอิงจาก Flutter's `wyn_colors.dart` คนละ track กับเว็บ) — ถาม Founder
ว่าอยากให้ทบทวนงานนี้ใหม่เป็นงานแยกไหม **Founder ตอบ "ใช่ อยากให้ทบทวนใหม่"**

**สถานะ**: ยังเป็น backlog เหมือนเดิม ยังไม่ได้เริ่มงาน — แค่บันทึกว่า Founder ต้องการให้มีการทบทวนสเปกทั้งฉบับ
ใหม่ (โดยเฉพาะ DS-001/สมมติฐานสี Cyan ที่ล้าสมัย) เป็นงานแยกในอนาคต ก่อนจะส่งต่อ AI Design ทำสเปกจริงหรือส่ง
AI Coding — ยังไม่ได้กำหนดคิว/ลำดับความสำคัญ รอ Founder หรือ Product Manager จัดลำดับงานนี้เข้า roadmap ทีหลัง
