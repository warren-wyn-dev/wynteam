# Product Task — WYN-139

Status: **Merged เข้า main แล้ว** (PR #311, 2026-09-07) — เหลือรอ Founder รัน migration SQL + deploy web จริง ดู `.wyn/logs/deployments/2026-09-07-wyn-134-136-137-138-139-phase-a-go-live-package.md`
Owner: AI Design → AI Coding → AI QA & Security → AI Deploy & DevOps → รอ Founder ดำเนินการ deploy จริง

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

Design spec เต็มที่ `.wyn/docs/design/wyn-139-dm-presence-typing-online.md` — ตรวจ pattern Presence ที่พิสูจน์แล้วจริงจาก WYN-128 (`club_channel_chat_repository.dart`) + RLS ของ `profiles` จริงแล้ว สรุปการตัดสินใจหลัก:

- **พบความเสี่ยง privacy สำคัญระหว่างตรวจโค้ด**: `profiles` มี SELECT policy `using (true)` — authenticated ทุกคนอ่านได้ทุกคอลัมน์ทุกแถว ถ้าเก็บ `last_seen_at`/`show_online_status` เป็นคอลัมน์บน `profiles` ตรงๆ จะรั่วให้ทุกคนเห็นได้ทันทีโดยไม่ผ่าน reciprocal check เลย ขัด Requirement + RULES.md โดยตรง — **แก้โดยแยกตารางใหม่ `user_presence`** (mirror `notification_settings`'s ท่าเดิม: SELECT policy จำกัดแค่เจ้าของแถวเท่านั้น) แล้วเปิดทางอ่านค่าคนอื่นได้ทางเดียวผ่าน RPC `get_conversation_partner_presence()` ที่บังคับ reciprocal check (`ทั้งสองฝั่งต้องเปิดถึงจะเห็นได้`) ในตัว
- **Typing**: per-conversation Presence channel (`track({typing: bool})`, debounce เริ่ม track ตอน state เปลี่ยนเท่านั้น, auto-clear 3 วิทั้งฝั่งส่งและฝั่งรับเป็น safety net) — ไม่มี privacy gate ตาม Requirement
- **Online**: Presence channel ระดับ **global ต่อแอป** (wire ที่ `RootShell` จุดเดียวกับ `PushNotificationService`) ไม่ใช่ต่อบทสนทนา — แยกจาก **Last Seen** ที่ persist ถาวรผ่าน RPC `touch_my_presence()` เรียกตอน app lifecycle pause (best-effort, ยอมรับ known limitation ถ้าแอปถูก kill กะทันหัน)
- Privacy toggle: แถว Switch ใหม่ใน `_PrivacyScreen` เดิม (settings_screen.dart) พร้อม helper text อธิบาย reciprocal ให้ผู้ใช้เข้าใจก่อนกดปิด
- AppBar subtitle 3 สถานะ (กำลังพิมพ์/ออนไลน์/ใช้งานล่าสุด) reuse `relativeTimeLabel()` ที่มีอยู่แล้วใน `text_utils.dart`
- มี UI ใหม่จริง → ต้องมี visual mockup ตามกติกา "ขอดูรูปก่อนเขียนโค้ด" — session นี้ไม่มีเครื่องมือสร้างภาพ ทำได้แค่ wireframe ข้อความในเอกสาร
- แนะนำ gate ด้วย Staged Rollout (WYN-125) รวมถึง**ไม่ track/subscribe presence channel เลย**สำหรับผู้ใช้ทั่วไป (ไม่ใช่แค่ซ่อน UI) เพื่อประหยัด resource

Handoff: **รอ Founder ยืนยัน 1 เรื่อง** — wireframe ข้อความในเอกสารเพียงพอสำหรับอนุมัติ หรือรอ session ที่มีเครื่องมือสร้างภาพ mockup จริงก่อน — หลังยืนยันแล้วส่งต่อ AI Coding ได้ทันที (schema/RPC/RLS/privacy model พร้อมสมบูรณ์แล้ว ไม่มีจุดกำกวมด้าน technical)

Founder ยืนยันแล้ว 2026-09-07 (ดู `.wyn/company/DECISIONS.md` entry "[2026-09-07] Social 3-Domain Roadmap") — ไม่มีจุดค้าง ส่งต่อ AI Coding

## AI Coding Output (2026-09-07)

Implementation ครบตาม design spec ทั้ง SQL/Flutter:

- **Schema**: `public.user_presence` (แยกจาก `profiles` ตามที่ Design กำหนดเพื่อป้องกัน privacy leak ผ่าน `profiles`' SELECT policy `using (true)`), `touch_my_presence()`, `get_conversation_partner_presence()` — ทั้งหมดใน `supabase/schema.sql` + `supabase/migrations_wyn139_dm_presence.sql` (standalone migration ใหม่ตาม convention)
  - **พบและแก้บั๊กใน SQL ต้นฉบับของ Design ระหว่าง implement**: `get_conversation_partner_presence()`'s `return query select true, up.last_seen_at from user_presence up where up.user_id = v_other` คืน **0 แถว** (ไม่ใช่ 1 แถวที่มี `last_seen_at = null`) เมื่อ partner ไม่เคยมีแถว `user_presence` เลย (เช่น ผู้ใช้ใหม่ที่ online ต่อเนื่องมาตั้งแต่สมัครโดยไม่เคย background แอปเลย) — ขัดกับที่ design doc's Edge Cases เขียนไว้เองว่าคาดหวัง "last_seen_at เป็น null จริง" (คือคาดหวัง 1 แถว) ผลคือ client จะเข้าใจผิดว่า reciprocal check ไม่ผ่าน (`showOnline: false`) ทั้งที่จริงผ่าน ซ่อน "ออนไลน์" dot ของคนที่กำลังออนไลน์อยู่จริงไปเฉยๆ — แก้เป็น scalar subquery `select true, (select last_seen_at from user_presence where user_id = v_other)` ให้คืน 1 แถวเสมอเมื่อ reciprocal check ผ่าน บันทึกเหตุผลไว้ใน comment ทั้งใน schema.sql และ migration file แล้ว (เป็นการแก้ตรงไปตรงมา ไม่ใช่การเปลี่ยน intent ของ design จึงไม่หยุดรอถาม Founder)
- **Flutter data layer**: `PresenceRepository` ใหม่ (`app/lib/features/presence/data/presence_repository.dart`) ครอบทั้ง global online-presence channel (process-wide static cache + listener list มิเรอร์ `DeveloperAccessService`'s static-cache shape), per-conversation typing channel, และ DB read/write (`fetchShowOnlineStatus`/`setShowOnlineStatus`/`touchMyPresence`/`fetchConversationPartnerPresence`)
- **RootShell**: เปิด global presence channel ครั้งเดียวตอน launch (gate ด้วย `isDeveloperAccount()`), track/untrack + `touchMyPresence()` ตาม `AppLifecycleState` resumed/paused-detached, `stopGlobalPresence()` ตอน dispose (sign-out/account switch)
- **ConversationScreen**: AppBar subtitle ใหม่ใต้ชื่อ (ลำดับ: กำลังพิมพ์ > ออนไลน์ > ใช้งานล่าสุด > ไม่แสดงอะไร ตาม design), per-conversation typing channel + debounce 3s + safety-net timer ทั้งสองฝั่ง, reuse `relativeTimeLabel()` เดิม
- **Settings → ความเป็นส่วนตัว**: แถว Switch ใหม่ "แสดงสถานะออนไลน์และเข้าใช้งานล่าสุด" พร้อม helper text อธิบาย reciprocal
- **Staged Rollout**: ทุกจุด gate ด้วย `isDeveloperAccount()` ครบตามที่ Design ระบุ — non-developer ไม่เห็น AppBar subtitle เลย, ไม่เห็น Settings toggle เลย, และไม่ track/subscribe presence channel ใดๆ เลยทั้ง global (RootShell) และ per-conversation (ConversationScreen) — ยืนยันด้วย test ที่เช็ค call count ของ repository เป็น 0 ตรงๆ ไม่ใช่แค่เช็ค UI
- **Test ใหม่**: `conversation_screen_test.dart` +7 tests (gate on/off, typing indicator + safety-net timer, online/last-seen 4 states ตามลำดับความสำคัญ, reciprocal-fail ซ่อนทุกอย่าง, debounced typing broadcast + idle-timeout), `root_shell_test.dart` +4 tests (global channel start/gate, pause/resume track/untrack/touchMyPresence), `settings_screen_test.dart` +4 tests (gate on/off, toggle initial value + flip + revert-on-fail) — เพิ่ม `RecordingPresenceRepository` ใหม่ใน `test/support/`
- **flutter analyze**: 0 issues (ทั้งโปรเจกต์)
- **flutter test**: **1403/1403 PASS** (ทั้งโปรเจกต์)

Known Issues / จุดที่ตัดสินใจเอง (ไม่ใช่จุดค้างที่ต้องถาม Founder):
- แก้บั๊ก SQL ของ Design ตามที่อธิบายไว้ข้างบน (`get_conversation_partner_presence()`'s scalar subquery)
- Edge case ที่ design doc เองยอมรับไว้แล้วยังคงอยู่ตามเดิม: `last_seen_at` ไม่อัปเดตถ้าแอปถูก kill กะทันหัน (ไม่มี server-side heartbeat timeout ใน v1), 2 อุปกรณ์พร้อมกันนับเป็น online เดียว (ตามที่ design ตั้งใจ), presence ของอีกฝ่ายไม่ real-time เต็มรูปแบบเมื่อพวกเขาเปลี่ยน privacy toggle เอง (ต้อง fetch ใหม่ตอนเปิดหน้า/resume ไม่ใช่ postgres_changes)

Handoff: ส่งต่อ AI QA & Security

## AI QA & Security Report (2026-09-07)

รายงานเต็ม: `.wyn/docs/qa/2026-09-07-wyn-134-136-137-138-139-phase-a-qa.md`

**นี่คือ task ที่ตรวจเข้มที่สุดในรอบนี้เพราะเป็นข้อมูล privacy อ่อนไหวตาม RULES.md** รัน `flutter analyze`/`flutter test` เองอิสระ (1433/1433 ผ่าน, 0 issues) เขียน regression test SQL ใหม่ (`supabase/tests/wyn_139_dm_presence_test.sh`, 11 checks) ทดสอบตรงกับ RPC/RLS จริงบน PostgreSQL 16 ภายใต้ role `authenticated` จริง:

- **ตรวจ bugfix ของ `get_conversation_partner_presence()`**: ยืนยันว่าคืน 1 แถวเสมอ (ไม่ใช่ 0 แถว) เมื่อ partner ไม่เคยมีแถว `user_presence` มาก่อนและ reciprocal check ผ่าน — ตรงตามที่ AI Coding อธิบายว่าแก้บั๊กจาก design doc เดิม ยืนยันว่าแก้ถูกจริง
- **Reciprocal privacy check — ทดสอบทั้ง 2 ทิศทาง**: ปิดของตัวเอง (alice) → มองไม่เห็นของคนอื่น (bob) แม้ bob ยังเปิดอยู่, และกลับกัน bob (ผู้ใช้คนที่ query) ก็มองไม่เห็น alice เหมือนกันเพราะ alice ปิดของตัวเอง (สมมาตรทั้งคู่ทิศทาง) — เปิดกลับมาแล้วเห็นได้ปกติ ทดสอบอีกทิศทาง (bob ปิดของตัวเอง) ก็ทำให้ alice มองไม่เห็น bob เช่นกัน — reciprocal ทำงานถูกต้องจริงไม่มีทางเลี่ยง
- **การทดสอบ bypass ที่ร้องขอโดยเฉพาะ**: เรียก `SELECT * FROM user_presence WHERE user_id = <partner>` ตรงๆ ข้าม RPC ไปเลย (ทั้งที่ toggle ทั้งคู่เปิดอยู่) — **ถูก RLS บล็อก คืน 0 แถว** ยืนยันว่าไม่มีทางอ่านข้อมูล presence ของคนอื่นได้เลยนอกจากผ่าน RPC ที่บังคับ reciprocal check เท่านั้น
- non-participant เรียก RPC สำหรับบทสนทนาคนอื่นไม่ได้, เขียนแถว presence ของคนอื่นไม่ได้เลย (`with check (auth.uid() = user_id)`)
- **Staged rollout gate**: ยืนยันด้วย test ที่เช็ค call count ตรงๆ (`fetchConversationPartnerPresenceCalls == 0`, `subscribeTypingChannelCalls == 0`, `startGlobalPresenceCalls == 0` สำหรับ non-developer) ไม่ใช่แค่เช็คว่า UI ไม่แสดง — ยืนยันว่า non-developer ไม่ track/subscribe presence channel เลยจริงทั้ง global (RootShell) และ per-conversation (ConversationScreen)

ไม่พบบั๊ก ไม่พบช่องโหว่ security ไม่พบทางเลี่ยง reciprocal check ใดๆ

**Final Status: PASS**
