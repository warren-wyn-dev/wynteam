# Product Task — WYN-134

Status: active — Founder อนุมัติให้ทำต่อ (2026-09-07, Phase A ลำดับ P1) → ส่งต่อ AI Design
Owner: AI Product Manager → AI Design

Feature: DM "New Message" Notification

Goal: แจ้งเตือนผู้ใช้เมื่อมีข้อความ DM ใหม่เข้ามาและไม่ได้เปิดหน้าบทสนทนานั้นอยู่ — ปิด known gap ที่ยอมรับไว้ตั้งแต่ WYN-032 อย่างเป็นทางการ ("New Message notification สำหรับบทสนทนาปกติไม่อยู่ในสโคปนี้" — บันทึกไว้ใน `.wyn/tasks/approved/WYN-032-message-request.md`)

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031/032)

Problem: ตอนนี้ผู้ใช้รู้ว่ามีข้อความใหม่ได้แค่ตอนเปิดแอปแล้วเห็น unread badge เอง หรือถ้าเปิดหน้าสนทนาค้างไว้ก็เห็นแบบ realtime — **แต่ถ้าปิดแอปหรืออยู่หน้าจออื่น จะไม่รู้เลยว่ามีคนทักมา** ต่างจาก Club ที่มี WYN-116 (re-engagement notification) แจ้งเตือนเมื่อมีโพสต์ใหม่แล้ว — Private Chat เป็นโดเมนเดียวที่ยังไม่มี notification ประเภทนี้เลย ทั้งที่เป็นความเสี่ยง retention เดียวกับที่ WYN-116 แก้ให้ Club ไปแล้ว

Requirements:
- Notification type ใหม่ `new_message` (โครงสร้างขนานกับ `message_request` ที่มีอยู่แล้วจาก WYN-032 — reuse `notifications` table เดิม ไม่สร้างตารางใหม่)
- ส่งเมื่อมีข้อความใหม่เข้าบทสนทนาที่ `status = 'active'` (ไม่ใช่ pending — pending มี `message_request` แจ้งเตือนแยกอยู่แล้วจาก WYN-032) และผู้รับไม่ได้เปิดหน้าบทสนทนานั้นอยู่ ณ ขณะนั้น (เช็คง่ายๆ ด้วย client state ที่มีอยู่แล้ว ไม่ต้องสร้าง presence system ใหม่สำหรับ task นี้)
- **เคารพ Mute บทสนทนา** ที่มีอยู่แล้วจาก WYN-031 (per-conversation notification mute) — บทสนทนาที่ mute ไว้ ไม่สร้าง notification ใหม่เลย
- v1 เก็บง่าย: 1 ข้อความใหม่ = 1 notification row (ไม่ทำ batching/collapsing "มี X ข้อความใหม่จาก Y" รอบนี้ — เหมือน pattern ที่ WYN-116 ใช้กับ Club) — ถ้าพบว่าบทสนทนาที่คุยถี่มากสร้าง notification รกเกินไปจริงในทางปฏิบัติ ค่อยพิจารณา batching เป็น fast-follow

Acceptance Criteria:
- [ ] ได้รับข้อความใหม่ขณะไม่ได้เปิดหน้าบทสนทนานั้น → เกิด notification `new_message` ทันที
- [ ] เปิดหน้าบทสนทนานั้นอยู่พอดี → ไม่เกิด notification ซ้ำ (มี realtime อยู่แล้วในหน้าจอ)
- [ ] บทสนทนาที่ mute ไว้ → ไม่มี notification เกิดขึ้นเลย
- [ ] บทสนทนาที่ยังเป็น pending (message request) → ไม่เกิด `new_message` ซ้ำกับ `message_request` เดิม

Dependencies: WYN-031 (Chat 1:1, Mute mechanism), WYN-032 (Message Request, `message_request` notification pattern เดิมให้ mirror ตาม), WYN-043 (notification infra)

Priority: **P1 — สูงสุดในกลุ่ม Phase A** เพราะเป็น known gap ที่กระทบ retention โดยตรง คล้ายปัญหาเดียวกับที่ WYN-116 แก้ให้ Club ไปแล้วและ Founder เคยให้ priority สูงตอนนั้นด้วยเหตุผลเดียวกัน

Risks: ต่ำ — ต่อยอด pattern ที่มีอยู่แล้ว (`message_request` notification) ตรงๆ ไม่มีความเสี่ยงเชิงสถาปัตยกรรม ความเสี่ยงเดียวคือ notification volume ถ้าผู้ใช้คุยกันถี่มาก (ยอมรับไว้ใน v1 ตามที่ระบุ)

Recommendation: อนุมัติ scope ได้ทันที แนะนำให้ทำก่อนอันอื่นใน Phase A

Handoff: รอ Founder ยืนยัน priority ของ Phase A ทั้งชุดก่อนส่งต่อ AI Design
