# Product Task — WYN-133

Status: design-complete — AI Design ทำ spec เต็มแล้ว (2026-09-07) รวม privacy toggle เป็นส่วนหนึ่งของ MVP ตามที่กำหนด — รอ Founder ยืนยันว่า wireframe ข้อความเพียงพอแทน visual mockup ก่อนส่งต่อ AI Coding
Owner: AI Design → รอ Founder ยืนยัน mockup → AI Coding

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

## AI Design Output (2026-09-07)

Design spec เต็มที่ `.wyn/docs/design/wyn-133-dm-presence-typing-online.md` — ตรวจ pattern Presence ที่พิสูจน์แล้วจริงจาก WYN-128 (`club_channel_chat_repository.dart`) + RLS ของ `profiles` จริงแล้ว สรุปการตัดสินใจหลัก:

- **พบความเสี่ยง privacy สำคัญระหว่างตรวจโค้ด**: `profiles` มี SELECT policy `using (true)` — authenticated ทุกคนอ่านได้ทุกคอลัมน์ทุกแถว ถ้าเก็บ `last_seen_at`/`show_online_status` เป็นคอลัมน์บน `profiles` ตรงๆ จะรั่วให้ทุกคนเห็นได้ทันทีโดยไม่ผ่าน reciprocal check เลย ขัด Requirement + RULES.md โดยตรง — **แก้โดยแยกตารางใหม่ `user_presence`** (mirror `notification_settings`'s ท่าเดิม: SELECT policy จำกัดแค่เจ้าของแถวเท่านั้น) แล้วเปิดทางอ่านค่าคนอื่นได้ทางเดียวผ่าน RPC `get_conversation_partner_presence()` ที่บังคับ reciprocal check (`ทั้งสองฝั่งต้องเปิดถึงจะเห็นได้`) ในตัว
- **Typing**: per-conversation Presence channel (`track({typing: bool})`, debounce เริ่ม track ตอน state เปลี่ยนเท่านั้น, auto-clear 3 วิทั้งฝั่งส่งและฝั่งรับเป็น safety net) — ไม่มี privacy gate ตาม Requirement
- **Online**: Presence channel ระดับ **global ต่อแอป** (wire ที่ `RootShell` จุดเดียวกับ `PushNotificationService`) ไม่ใช่ต่อบทสนทนา — แยกจาก **Last Seen** ที่ persist ถาวรผ่าน RPC `touch_my_presence()` เรียกตอน app lifecycle pause (best-effort, ยอมรับ known limitation ถ้าแอปถูก kill กะทันหัน)
- Privacy toggle: แถว Switch ใหม่ใน `_PrivacyScreen` เดิม (settings_screen.dart) พร้อม helper text อธิบาย reciprocal ให้ผู้ใช้เข้าใจก่อนกดปิด
- AppBar subtitle 3 สถานะ (กำลังพิมพ์/ออนไลน์/ใช้งานล่าสุด) reuse `relativeTimeLabel()` ที่มีอยู่แล้วใน `text_utils.dart`
- มี UI ใหม่จริง → ต้องมี visual mockup ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" — session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความในเอกสาร
- แนะนำ gate ด้วย Staged Rollout (WYN-125) รวมถึง**ไม่ track/subscribe presence channel เลย**สำหรับผู้ใช้ทั่วไป (ไม่ใช่แค่ซ่อน UI) เพื่อประหยัด resource

Handoff: **รอ Founder ยืนยัน 1 เรื่อง** — wireframe ข้อความในเอกสารเพียงพอสำหรับอนุมัติ หรือรอ session ที่มีเครื่องมือสร้างภาพ mockup จริงก่อน — หลังยืนยันแล้วส่งต่อ AI Coding ได้ทันที (schema/RPC/RLS/privacy model พร้อมสมบูรณ์แล้ว ไม่มีจุดกำกวมด้าน technical)
