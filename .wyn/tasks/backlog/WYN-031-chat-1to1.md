# Product Task — WYN-031

Status: backlog
Owner: AI Product Manager

Feature: 1:1 Chat (Basic DM)

Goal: ให้ผู้ใช้สองคนส่งข้อความส่วนตัวถึงกันได้ (Text/Image/Reply/Delete/Read-Unread) เป็นก้าวแรกของ WYN Chat — Phase 2 ของ Roadmap (`.wyn/docs/product/wyn-v1.0.0-roadmap.md`), Master Spec section 18

Target User: ผู้ใช้ทุกคนที่ต้องการสื่อสารส่วนตัวกับผู้ใช้อื่นแบบ 1:1 (ไม่ใช่ group chat รอบนี้)

Problem: WYN ยังไม่มีช่องทางสื่อสารส่วนตัวเลยแม้แต่จุดเดียว — ทุกปฏิสัมพันธ์ที่มีอยู่ตอนนี้ (Comment/Follow/Like) เป็น public ทั้งหมด — Master Spec ระบุ Chat เป็น 1 ใน 4 แกนหลักของ V1.0 (Drop + Club + Chat + Discovery) แต่ยังไม่มีอะไรในระบบเลยแม้แต่ตาราง DB — Phase 1 (Safety & Trust Foundation) เพิ่งปิดครบแล้ว (Report/Block/Mute/Moderation/Appeal) ซึ่งเป็นเหตุผลที่ Roadmap จงใจวาง Chat ไว้เป็น Phase ถัดไปทันที ไม่ใช่ก่อนหน้า

Requirements:

**ขอบเขตรอบนี้ vs WYN-032 (Message Request)**
- รอบนี้ (WYN-031) เป็น "Basic 1:1 Chat" — **ผู้ใช้ที่ล็อกอินแล้วเริ่มบทสนทนากับใครก็ได้ทันที ไม่มี gate ใดๆ** (ยังไม่มี Message Request/Accept flow) — WYN-032 จะเพิ่ม gate สำหรับข้อความแรกจาก "คนแปลกหน้า" (คนที่ยังไม่ได้ follow กัน) ทีหลัง ตาม Roadmap ที่แยก 2 task ไว้ชัดเจน
- **ข้อกำหนดสำหรับ Design/Coding**: ออกแบบ schema ของ `conversations` ให้มีคอลัมน์ `status` (เช่น `'active'`/`'pending'`) ตั้งแต่ต้น แม้ว่ารอบนี้จะ insert เป็น `'active'` เสมอ (ไม่มี logic ใดใช้ `'pending'` จริงในรอบนี้) — เพื่อให้ WYN-032 ต่อยอดด้วยการเพิ่ม logic กำหนดค่าเริ่มต้นแบบมีเงื่อนไข (follow กันแล้ว → `'active'` / ไม่ follow → `'pending'`) โดยไม่ต้อง migrate ข้อมูลเดิมหรือเปลี่ยน schema shape ทีหลัง — ป้องกัน rework ก้อนใหญ่ตอน WYN-032

**ข้อความ (Message)**
- ประเภทเนื้อหา: **Text** (บังคับความยาวสูงสุด — แนะนำ 2000 ตัวอักษร ยาวกว่า caption ปกติของ Drop/Club Post เพราะบทสนทนามักยาวกว่าโพสต์เดี่ยว) และ/หรือ **Image** (1 รูปต่อ 1 ข้อความ ไม่ใช่ multi-image gallery แบบ Drop/Club Post — แชทเน้นความเร็วในการส่ง ไม่ใช่การจัดชุดรูป) — ข้อความต้องมีอย่างน้อยหนึ่งอย่าง (text หรือ image) ห้ามส่งข้อความเปล่า
- **Reply**: ตอบกลับข้อความใดข้อความหนึ่งในบทสนทนาเดียวกันได้ (แสดง quote ของข้อความต้นทางแบบย่อ) — จำกัดแค่ 1 ชั้น (reply ไปยัง reply อื่นไม่ได้) มิเรอร์ข้อจำกัดเดียวกับ WYN-022 (Reply Comment ของ Drop/Club Post)
- **Delete Message**: ลบข้อความของตัวเองเท่านั้น — เป็น **soft delete** (แสดง placeholder เช่น "ข้อความนี้ถูกลบ" แทนที่จะหายไปเงียบๆ) **ต่างจาก** Drop Comment (WYN-005, hard delete) เพราะบริบทต่างกัน: บทสนทนา 1:1 ต้องรักษาความต่อเนื่อง โดยเฉพาะถ้ามีข้อความอื่น reply ไปยังข้อความที่ถูกลบแล้ว (reply ต้องยังอ้างอิงได้ว่า "ตอบกลับข้อความที่ถูกลบไปแล้ว" ไม่ใช่ dangling reference)
- **Read/Unread**: ระดับ**บทสนทนา** ไม่ใช่ระดับข้อความ (ไม่ใช่ read receipt ✓✓ ต่อข้อความแบบ WhatsApp เต็มรูปแบบ) — เก็บ "อ่านถึงข้อความล่าสุดชิ้นไหนแล้ว" ต่อผู้เข้าร่วมแต่ละคน ใช้คำนวณ unread badge/count ได้ — Basic DM ตามที่ Founder ระบุไว้ตรงๆ ใน Master Spec ไม่ over-engineer เป็น per-message read receipt

**Conversation List (กล่องข้อความ)**
- รายชื่อบทสนทนาเรียงตามข้อความล่าสุดก่อน (ไม่ใช่ตามเวลาสร้างบทสนทนา) แสดง preview ข้อความล่าสุด + unread badge
- เข้าถึงผ่าน **ไอคอน Chat แยกต่างหาก ไม่ใช่ Bottom Nav tab** (ตาม Master Spec: "Chat ไม่ต้องเป็น Bottom Tab — เข้าผ่าน 💬 Chat icon") — ต้องตัดสินใจตำแหน่งไอคอนนี้ร่วมกับ WYN-024 ที่เพิ่งปรับ Bottom Nav ใหม่ (Home/Search/Drop/Notifications/Profile) น่าจะอยู่แถว AppBar ของ Home เดิมที่เคยมี Search bar ก่อนย้ายเป็น tab

**Realtime**
- ข้อความใหม่ต้องขึ้นแบบ real-time ระหว่างที่ทั้งสองฝ่ายเปิดหน้าสนทนาอยู่ ไม่ต้องกด refresh/pull-to-refresh เอง — **นี่เป็นจุดแรกในโปรเจกต์ที่ต้องใช้ Supabase Realtime subscription จริงจัง** (ทุกฟีเจอร์ก่อนหน้า Like/Comment/Follow/Notification เป็น request-response ธรรมดา ไม่มี requirement ให้ realtime ขนาดนี้)

**Integration กับระบบ Safety ที่มีอยู่แล้ว (Phase 1)**
- **Block (WYN-027)**: สองฝ่ายที่ block กัน (ทิศทางใดก็ตาม) ส่งข้อความหากันไม่ได้เลย — reuse `internal.is_blocked_either_way()` ที่มีอยู่แล้วตรงๆ ไม่สร้างกลไกใหม่ — บทสนทนาเดิม (ถ้ามีก่อน block) **ยังเปิดดูประวัติได้ (read-only)** ไม่ลบ/ซ่อนหายไปเงียบๆ (มิเรอร์พฤติกรรมมาตรฐานของ Messenger/Instagram DM ที่ผู้ใช้ทั่วไปคุ้นเคย)
- **Mute — เป็นแนวคิดใหม่ แยกจาก WYN-028 โดยสิ้นเชิง**: "Mute บทสนทนา" หมายถึงปิดการแจ้งเตือนจากบทสนทนานั้นโดยเฉพาะ (per-conversation notification mute) **ไม่ใช่** WYN-028's user-level content mute (ที่ซ่อนเนื้อหาใน Home Feed) — สองอย่างนี้เป็นคนละกลไก คนละตาราง คนละความหมาย ต้องไม่สับสน/ไม่ reuse ตาราง `mutes` เดิม
- **Report (WYN-026)**: reuse `reports` table + `submit_report()` ตรงๆ — `target_type = 'message'` **ถูกเผื่อไว้แล้วใน CHECK constraint ตั้งแต่ WYN-026** (ดู `supabase/schema.sql` comment "Message reserved for WYN-031/032 Phase 2") แต่ `submit_report()`'s validation logic ยังไม่มี branch รองรับ (ตกไปที่ `else` "Unsupported report target type") — งานนี้ต้องเพิ่ม `elsif p_target_type = 'message'` branch จริง — report เป้าหมายเป็น**ข้อความเดี่ยว**ไม่ใช่ทั้งบทสนทนา (สอดคล้องกับ pattern เดิมที่ report เจาะจงเนื้อหาเดียว)
- **Restrict/Suspend/Ban (WYN-029)**: ผู้ใช้ที่โดน Restrict/Suspend/Ban ส่งข้อความใหม่ไม่ได้เหมือนเนื้อหาประเภทอื่น — reuse `internal.is_posting_blocked()` ตรงๆ เป็น RLS INSERT guard บน `messages` — ยังคง**อ่านบทสนทนาเดิมได้ปกติ** (READ ไม่เคยถูกบล็อกในระบบนี้เลยสักจุดเดียว ตาม pattern ที่ทั้งโปรเจกต์ยึดมาตลอด)

Acceptance Criteria:
- [ ] ผู้ใช้ A เริ่มบทสนทนากับผู้ใช้ B ได้ทันทีโดยไม่มี gate ใดๆ (ยังไม่มี Message Request รอบนี้)
- [ ] ส่งข้อความ Text/Image/ทั้งคู่ได้ ส่งข้อความเปล่า (ไม่มีทั้ง text และ image) ทำไม่ได้
- [ ] Reply ไปยังข้อความก่อนหน้าในบทสนทนาเดียวกันได้ แสดง quote ของข้อความต้นทาง — reply ไปยัง reply อื่นทำไม่ได้ (จำกัด 1 ชั้น)
- [ ] ลบข้อความของตัวเองได้ (soft delete, เห็น placeholder "ข้อความนี้ถูกลบ") — ลบข้อความของอีกฝ่ายไม่ได้
- [ ] ข้อความที่ถูกลบแล้วแต่มีคน reply ไปแล้ว ยังแสดง reply นั้นได้ปกติ (อ้างอิงไปยัง placeholder ไม่ crash/หาย)
- [ ] เปิดหน้าสนทนา → ข้อความใหม่จากอีกฝ่ายขึ้นแบบ real-time โดยไม่ต้อง refresh
- [ ] Conversation List เรียงตามข้อความล่าสุด แสดง unread badge ถูกต้อง และ badge หายไปเมื่อเปิดอ่านบทสนทนานั้นแล้ว
- [ ] ผู้ใช้ A block ผู้ใช้ B (หรือกลับกัน) → ทั้งสองฝ่ายส่งข้อความหากันไม่ได้อีก แต่ยังเปิดดูประวัติเดิมได้ (read-only)
- [ ] Mute บทสนทนาหนึ่งแล้ว ไม่ได้รับ notification จากบทสนทนานั้นอีก แต่ยังเห็นข้อความใหม่ปกติถ้าเปิดแอปเข้ามาดู — บทสนทนาอื่นที่ไม่ได้ mute ไม่ถูกกระทบ
- [ ] Report ข้อความเดี่ยวได้ ผ่านเข้า Moderation Queue เดิมของ WYN-029 ได้จริง (target_type = 'message')
- [ ] ผู้ใช้ที่โดน Restrict/Suspend/Ban ส่งข้อความใหม่ไม่ได้ (ถูก RLS ปฏิเสธ) แต่ยังอ่านบทสนทนาเดิมได้ปกติ
- [ ] Regression: WYN-026/027/028/029 (Report/Block/Mute/Moderation) เดิมทำงานปกติหลังเพิ่ม Chat

Dependencies: WYN-026 (Report — ต้องเพิ่ม `message` branch), WYN-027 (Block — reuse `internal.is_blocked_either_way()`), WYN-029 (Restrict/Suspend/Ban — reuse `internal.is_posting_blocked()`) — ทั้งหมด merge เข้า `main` แล้ว ไม่ block

Priority: P0 — task แรกของ Phase 2 ตาม Roadmap ที่ Founder ล็อกสเปกแล้ว

Risks:
- **Realtime เป็นของใหม่ในโปรเจกต์**: ทุกฟีเจอร์ก่อนหน้าไม่เคยต้องใช้ Supabase Realtime subscription จริงจัง (Notification list ใช้ pull/refetch) — ต้องระวังเรื่อง subscription lifecycle (unsubscribe เมื่อออกจากหน้าจอ ป้องกัน memory leak/duplicate listener) และ RLS policy ต้องรองรับ Realtime อย่างถูกต้อง (Supabase Realtime เคารพ RLS ของ `select` policy เดิมอยู่แล้ว แต่ต้องทดสอบจริงว่า subscription filter ทำงานตรงตามที่ policy อนุญาต ไม่ใช่แค่ REST API)
- **"Mute" ในสเปก 1:1 Chat ของ Master Spec (section 18) เขียนสั้นๆ ไม่ชัดเจนว่าหมายถึง mute บทสนทนา (ตัดสินใจในนี้) หรือ reuse WYN-028's user-level mute เดิม** — ตัดสินใจแล้วว่าเป็นคนละกลไกกัน (ดู Requirements) เพราะความหมายที่ผู้ใช้คาดหวังจากปุ่ม "Mute" ในหน้าแชทคือ "ปิดแจ้งเตือนบทสนทนานี้" ไม่ใช่ "ซ่อนโพสต์ของคนนี้ทั้ง Home Feed" — ถ้า Founder มีความหมายอื่นในใจ ต้องแก้ก่อนเริ่ม Design
- **Soft-delete ของ Message เป็นครั้งแรกในโปรเจกต์ที่ตั้งใจทำ soft-delete แต่ต้น** (ต่างจาก Drop/Comment/Club Post ที่ hard-delete ทั้งหมด รวมถึง WYN-029's Remove Content ก็ hard-delete) — ต้องระวังไม่ให้ RLS SELECT policy รั่ว field ที่ควรซ่อนหลังลบ (เช่น image_url/text เดิม) ออกไปให้อีกฝ่ายเห็นผ่าน query ตรงๆ แม้ UI จะโชว์แค่ placeholder — เป็นบทเรียนเดียวกับที่โปรเจกต์นี้เจอมาแล้วหลายครั้ง (RLS row-level ไม่ใช่ column-level) ต้องทำ column-list discipline หรือ null-out field จริงตอน soft-delete ไม่ใช่แค่ตั้ง `is_deleted = true` แล้วปล่อย field เดิมค้างไว้ในแถว
- **Message Request gate ที่ยังไม่มีรอบนี้**: หมายความว่าใครก็ทักใครก็ได้ทันทีในรอบนี้ รวมถึงคนแปลกหน้าที่ไม่ได้ follow กัน — เป็นความเสี่ยง spam/harassment ชั่วคราวจนกว่า WYN-032 จะเสร็จ (Report/Block/Mute ที่มีอยู่แล้วช่วยบรรเทาได้บางส่วน แต่ไม่ใช่ preventive gate) — ยอมรับความเสี่ยงนี้ตาม Roadmap ที่ Founder แยก 2 task ไว้แล้วโดยเจตนา ไม่ใช่ oversight

Recommendation:
1. เริ่มทันทีหลัง Phase 1 ปิดครบ — Chat เป็น 1 ใน 4 แกนหลักของ V1.0 (Drop+Club+Chat+Discovery) ที่ยังไม่มีอะไรเลย ควรเริ่มก่อน Phase 3/4/5
2. ออกแบบ schema ให้รองรับ WYN-032 (Message Request) ตั้งแต่ต้นตาม "ข้อกำหนดสำหรับ Design/Coding" ด้านบน เพื่อไม่ต้อง rework ก้อนใหญ่ทีหลัง
3. WYN-033 (Share เข้า Chat) ควรทำหลัง WYN-031/032 เสร็จ เพราะต้องมี Conversation/Message UI ให้แชร์เข้าไปก่อน — ตรงตามลำดับที่ Roadmap วางไว้แล้ว
4. แนะนำให้ AI Design ตัดสินใจตำแหน่ง Chat icon ให้สอดคล้องกับ WYN-024's Bottom Nav ใหม่ (Home/Search/Drop/Notifications/Profile) — อาจอยู่แถว AppBar ของ Home ข้าง Notification bell เดิม

Handoff: AI Design — ออกแบบ Chat Inbox (Conversation List), หน้าสนทนา (message bubbles, reply quote, image, delete confirm, read/unread indicator), ตำแหน่ง Chat icon entry point, และหน้าจอ/ปุ่ม Mute conversation + Block/Report จากในหน้าแชท (reuse `block_dialogs.dart`/`ReportSheet` เดิมให้มากที่สุด) — ระบุ schema เบื้องต้นที่แนะนำ (`conversations`, `conversation_participants`, `messages`) ให้ AI Coding ต่อยอดได้ทันที พร้อมช่องทางเข้าถึง entry point ใหม่ (ไอคอนบนโปรไฟล์คนอื่น "ส่งข้อความ" ด้วย ไม่ใช่แค่ Chat icon กลาง)

---

## Design Output (2026-08-22)

ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-031-chat-1to1.md` สรุปสั้น:

- **Design system**: Cyan `#00C8FF` (DS-001–008) ทั้งหมด — Rainbow (DS-009) ไม่ใช้ใน Chat แม้แต่จุดเดียว (ล็อกไว้แค่ 2 จุดของ Home เดิม)
- **`conversations` เป็น 2-column pair table** (`user_a_id`/`user_b_id` canonical ordering บังคับด้วย `check (user_a_id < user_b_id)`) ไม่ใช้ junction table เพราะไม่มี group chat ในสโคปนี้ — Read status เก็บเป็น `user_a_last_read_at`/`user_b_last_read_at` บนแถวเดียวกันเลย ไม่ใช่ per-message read receipt
- **Soft-delete message ต้อง null-out เนื้อหาจริง** (`text`/`image_url` = null พร้อม `deleted_at`) ผ่าน RPC `delete_message()` เดียว ไม่เปิด UPDATE policy ตรงให้ client — ป้องกันบทเรียนเดิมของโปรเจกต์ (RLS row-level ไม่ใช่ column-level)
- **ส่งข้อความไม่มี RPC** — ใช้ RLS INSERT ตรงๆ (with check: participant จริง/ไม่ block/ไม่ posting-blocked) + CHECK constraint (ไม่ blank) + trigger กัน reply ข้ามบทสนทนา มิเรอร์ pattern ของ `drops`/`club_posts`
- **`conversation_mutes` แยกขาดจาก `mutes` (WYN-028) โดยสิ้นเชิง** — คนละความหมาย (ปิดแจ้งเตือนบทสนทนา vs ซ่อนเนื้อหา Home Feek) คนละตาราง RLS insert/delete ตรงๆ ไม่มี RPC
- **Realtime เป็นกลไกแรกในโปรเจกต์** — ทั้ง `ChatInboxScreen`/`ConversationScreen` subscribe `messages` insert ผ่าน `postgres_changes`, ต้อง unsubscribe ตอน `dispose()` เสมอ และ Coding ต้องทดสอบจริงว่า RLS ครอบ Realtime ด้วย ไม่ใช่แค่สมมติ
- **8 หน้าจอ/interaction**: Chat icon (Home AppBar), Chat Inbox, Conversation Screen (bubble+reply+image+composer+blocked/restricted states), ปุ่ม "ส่งข้อความ" บนโปรไฟล์คนอื่น, Delete confirm (reuse `ConfirmDeleteDialog`), Mute/Block/Report menu ในหน้าแชท, Realtime behavior spec, Data & Enforcement notes เต็มสำหรับ Coding

Handoff: AI Coding — เริ่มจาก data layer ตามลำดับใน design doc's Handoff section: (1) `conversations` + RLS + `get_or_create_conversation()`/`mark_conversation_read()`, (2) `messages` + RLS + reply-validity trigger + `delete_message()`, (3) `conversation_mutes` + RLS, (4) `submit_report()` เพิ่ม `message` branch, (5) `ReportTargetType`/`ModerationTargetSummary` ขยาย, (6) เปิด Realtime — แล้วเข้า UI (7)-(12) ตามลำดับใน design doc
