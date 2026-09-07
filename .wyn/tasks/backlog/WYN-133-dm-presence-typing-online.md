# Product Task — WYN-133

Status: backlog
Owner: AI Product Manager

Feature: DM Presence — Typing Indicator + Online/Offline + Last Seen (1:1 Chat)

Goal: ให้บทสนทนา 1:1 รู้สึก "มีชีวิต" แบบแอปแชทที่คุ้นเคย — เห็นว่าอีกฝ่าย "กำลังพิมพ์..." อยู่ไหม, ออนไลน์อยู่ไหม, ใช้งานล่าสุดเมื่อไหร่ — ตรงกับสเปกข้อ 10 (Typing Indicator, Online/Offline Status, Last Seen)

Target User: ผู้ใช้ทุกคนที่ใช้ WYN Chat (WYN-031/032)

Problem: WYN Chat วันนี้เป็น request-response ล้วนๆ สำหรับสัญญาณสถานะ (มี realtime แค่สำหรับข้อความใหม่ ตาม WYN-031) — ไม่มีสัญญาณใดๆ บอกว่าอีกฝ่าย "อยู่ตรงนั้นไหม" เลย ทำให้การคุยรู้สึกเหมือนส่ง SMS มากกว่าแชทสมัยใหม่

Requirements:

**Typing Indicator**
- ใช้ Supabase Realtime Presence channel ต่อบทสนทนา — ฝั่งที่กำลังพิมพ์ broadcast สถานะ "typing" ให้อีกฝ่ายเห็นแบบ real-time (debounce เพื่อไม่ spam event ทุกตัวอักษร) หยุดพิมพ์เกิน ~3 วินาที → indicator หายไปเอง

**Online/Offline + Last Seen**
- Online = มี session แอปเปิดอยู่จริง (ใช้ Presence heartbeat ระดับ global ต่อ user ไม่ใช่ต่อบทสนทนา)
- Last Seen = เวลาที่ user ปิด/พ้นสถานะ online ล่าสุด แสดงแบบ relative time ("ใช้งานล่าสุด 5 นาทีที่แล้ว")

**Privacy setting ใหม่ (บังคับทำพร้อมกัน ไม่ใช่ fast-follow)**
- ผู้ใช้ต้องปิดการแสดง Online/Last Seen ของตัวเองได้จาก Settings — ใช้กติกาแบบ reciprocal (มาตรฐานที่ผู้ใช้คุ้นเคยจาก WhatsApp): **ถ้าปิดของตัวเอง จะมองไม่เห็นของคนอื่นด้วยเช่นกัน** ไม่ใช่ปิดฝ่ายเดียวแล้วยังแอบดูคนอื่นได้ — ต้องทำพร้อมฟีเจอร์หลักตั้งแต่รอบแรก เพราะเป็นข้อมูลอ่อนไหวเรื่อง privacy ตาม `.wyn/company/RULES.md` (ปกป้องข้อมูลผู้ใช้) ไม่ควรปล่อยออกไปก่อนแล้วค่อยตามมาทีหลัง
- Typing Indicator **ไม่มี** privacy toggle แยก (เป็นสัญญาณชั่วคราวระดับบทสนทนา ไม่ใช่ข้อมูลสะสมแบบ Last Seen — ความเสี่ยง privacy ต่ำกว่ามาก)

Acceptance Criteria:
- [ ] พิมพ์ข้อความในแชท → อีกฝ่ายเห็น "กำลังพิมพ์..." แบบ real-time หยุดพิมพ์ไม่นาน indicator หายไปเอง
- [ ] เห็นสถานะออนไลน์/ออฟไลน์ + last seen ของอีกฝ่ายในหน้าบทสนทนา
- [ ] ปิดการแสดง online/last seen ของตัวเองได้จาก Settings
- [ ] ปิดของตัวเองแล้ว → มองไม่เห็นของคนอื่นเช่นกัน (reciprocal)

Dependencies: WYN-031 (Chat 1:1), Supabase Realtime Presence (infra เดียวกับที่ WYN-128 พิสูจน์แล้วว่าใช้งานได้จริงในโปรเจกต์นี้)

Priority: P2 — engagement signal ที่มีคุณค่า แต่ไม่ใช่ core functionality

Risks: ต้องทำ privacy toggle พร้อมกันตั้งแต่แรกตามที่ระบุไว้ — ถ้าข้าม risk คือข้อมูล "ใครใช้แอปตอนไหน" หลุดโดยผู้ใช้ไม่ยินยอม ซึ่งขัด RULES.md โดยตรง ไม่ใช่แค่ UX gap ธรรมดา

Recommendation: อนุมัติ scope ได้ แต่ **ต้องล็อกไว้ใน Design ว่า privacy toggle เป็นส่วนหนึ่งของ MVP ไม่ใช่ nice-to-have แยก**

Handoff: รอ Founder ยืนยัน priority ของ Phase A ทั้งชุดก่อนส่งต่อ AI Design
