# Feature Request — WYN-122

Status: **active — QA Round 1 FAIL (missing EXECUTE grant บน `internal.chat_pair_allowed()`) — ส่งต่อ AI Debug Engineer**
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (FAIL) → AI Debug Engineer

Feature: ปิดระบบแชท 1-on-1 ชั่วคราว เหลือเฉพาะ @warren ↔ @wynos_online (Chat Lockdown for Testing)

Goal: กันไม่ให้ผู้ใช้ทั่วไปใช้ฟีเจอร์แชทระหว่างช่วงทดสอบก่อนเปิดใช้งานจริง โดยเปิดให้เฉพาะบัญชี @warren คุยกับ @wynos_online กันเองได้เพื่อทดสอบ — ต้องบังคับใช้จริงที่ backend/RLS ไม่ใช่แค่ซ่อนที่ UI (Founder ระบุชัดเจน)

Target User: Founder (@warren) และบัญชีทดสอบ @wynos_online เท่านั้นที่ใช้แชทได้ในช่วงนี้ ผู้ใช้ทั่วไปทุกคน (รวมถึงกรณีสมมติที่ @warren พยายามแชทกับ user จริงคนอื่น) ถูกบล็อกหมด

Problem: ระบบแชท (WYN-031/032/033/045) เปิดใช้งานเต็มรูปแบบให้ผู้ใช้ทุกคนอยู่แล้ว แต่ Founder ต้องการพื้นที่ปิดสำหรับทดสอบก่อนเปิดฟีเจอร์นี้ให้สาธารณะจริง — ป้องกันไม่ให้ผู้ใช้จริงเจอบั๊ก/พฤติกรรมที่ยังไม่เสถียรของแชทระหว่างที่ยังทดสอบอยู่

## ยืนยันขอบเขต/พฤติกรรมกับ Founder แล้ว (ผ่าน AskUserQuestion 2 รอบ)

1. **การจับคู่ที่อนุญาต**: **เฉพาะคู่ @warren ↔ @wynos_online เท่านั้น** — ไม่ใช่ "ใครก็ได้คุยกับ 2 บัญชีนี้" ผู้ใช้ทั่วไป ("เอ") พยายามแชทกับ @warren ในช่วงนี้ก็ต้องถูกบล็อกเหมือนกัน (คำตอบ Founder ตรงๆ: "ไม่ได้เลย — เอแชทกับใครไม่ได้ทั้งนั้นช่วงปิดระบบ")
2. **UX เมื่อผู้ใช้ทั่วไปพยายามเข้าแชท**: เข้าหน้าแชทได้ตามปกติ (ไอคอน/ปุ่มไม่ซ่อน) แต่เจอข้อความ **"ระบบแชทปิดปรับปรุงชั่วคราว"** แทนเนื้อหาแชทจริง
3. **บทสนทนาเก่าของผู้ใช้ทั่วไป** (คุยกับคนอื่นที่ไม่ใช่ 2 บัญชีทดสอบ ตั้งแต่ก่อนปิดระบบ): **ซ่อนทั้งหมดระหว่างที่ระบบปิดอยู่** ไม่ใช่แค่ปิดการส่งข้อความใหม่ — ผู้ใช้จะเปิดดูประวัติแชทเก่าไม่ได้เลยจนกว่าจะเปิดระบบกลับคืน

## Requirements

### R1 — Backend enforcement (บังคับที่ database, ไม่ใช่แค่ UI)
กำหนด "allowlist" ผู้ใช้ที่ได้รับการยกเว้น (เริ่มต้น = {@warren, @wynos_online}) และกฎ: **การกระทำใดๆ ที่เกี่ยวกับแชทจะทำได้ก็ต่อเมื่อผู้เข้าร่วมสนทนาทั้งสองฝ่ายอยู่ใน allowlist ทั้งคู่** (ไม่ใช่แค่ฝ่ายใดฝ่ายหนึ่ง) ระหว่างที่ lockdown เปิดใช้งานอยู่ ครอบคลุมทุก path ที่มีอยู่แล้วของฟีเจอร์แชท:

- สร้างบทสนทนาใหม่ (`get_or_create_conversation()`)
- ส่งข้อความใหม่ (`messages` INSERT — ครอบคลุม Share to Chat โดยอัตโนมัติเพราะใช้ path เดียวกัน)
- **ดู/เปิดบทสนทนาเดิม** (`conversations`/`messages` SELECT) — ต้องซ่อนบทสนทนาเก่าที่ไม่ใช่คู่ที่ได้รับการยกเว้นด้วย ตามข้อ 3 ที่ยืนยันกับ Founder แล้ว
- Message Request ที่มีอยู่ก่อนหน้า (accept/reject) — ควรถูกบล็อกด้วยกฎเดียวกัน (ทั้งสองฝ่ายต้องอยู่ใน allowlist)

### R2 — ต้องเปิดกลับคืนได้ง่าย โดยไม่ต้อง deploy client ใหม่
Founder บอกไว้ชัดเจนว่านี่คือ "ก่อนเปิดใช้งานจริง" — เป็นสถานะชั่วคราว ต้องมีวิธี "เปิดกลับ" (ปลด lockdown ทั้งระบบให้ผู้ใช้ทุกคนใช้แชทได้ตามปกติเหมือนเดิม) โดยไม่ต้องแก้โค้ด Flutter/build ใหม่ทั้งแอป — แนะนำให้ Coding ออกแบบเป็น **data-driven toggle** (เช่น flag/ตาราง config ใน database ที่พลิกค่าได้ด้วย SQL statement เดียว) ไม่ใช่ hardcode เงื่อนไขไว้ในโค้ด RLS/RPC แบบที่ต้อง migration ใหม่ทุกครั้งที่จะเปิด/ปิด

### R3 — ไม่ทำลายข้อมูลเดิม
ห้ามลบ/แก้ไขข้อมูลบทสนทนา/ข้อความเก่าใดๆ ทั้งสิ้น การ "ซ่อน" ต้องเป็นการซ่อนด้วย RLS เท่านั้น (reversible 100%) เมื่อปลด lockdown แล้วทุกอย่างต้องกลับมาเหมือนเดิมทุกประการ ไม่มีข้อมูลสูญหาย

### R4 — UI
- Chat entry points (ไอคอนแชทใน Home, ปุ่ม "ข้อความ" ใน Profile ของคนอื่น, การกดเปิดจาก Notification/Push ที่เกี่ยวกับข้อความ) **ยังคงแสดงและกดได้ตามปกติ** ไม่ซ่อน ไม่ปิดการใช้งานปุ่ม
- เมื่อผู้ใช้ที่ไม่อยู่ใน allowlist เปิดเข้าไปในส่วนใดของแชท (Chat Inbox, บทสนทนาเดิม, หน้าเริ่มบทสนทนาใหม่) ให้แสดงข้อความ **"ระบบแชทปิดปรับปรุงชั่วคราว"** แทนเนื้อหาจริงทั้งหมด (แทนที่รายการบทสนทนาที่ว่างเปล่า/error ที่สับสน)
- ผู้ใช้ที่อยู่ใน allowlist (@warren, @wynos_online) ใช้งานแชทได้ตามปกติทุกประการ ไม่มี UI พิเศษเพิ่ม

### R5 — ไม่กระทบฟีเจอร์อื่น
เฉพาะแชท 1-on-1 (conversations/messages) เท่านั้น — ไม่แตะ comment บน Drop/Pop/Club post, ไม่แตะ Club (มีระบบของตัวเองแยกต่างหาก ไม่ใช่ "แชท" ตามที่ Founder หมายถึง)

## Acceptance Criteria

1. ผู้ใช้ A และ B ที่ไม่ใช่ @warren/@wynos_online: A พยายามเริ่มบทสนทนาใหม่กับ B → ถูกบล็อก, เห็นข้อความ "ระบบแชทปิดปรับปรุงชั่วคราว"
2. ผู้ใช้ทั่วไป (ไม่ใช่ 2 บัญชีนี้) พยายามแชทกับ @warren หรือ @wynos_online โดยตรง → ถูกบล็อกเหมือนกัน (ไม่ใช่ข้อยกเว้น)
3. ผู้ใช้ทั่วไปที่มีบทสนทนาเก่าอยู่แล้ว (จากก่อนปิดระบบ) → เปิดดูไม่ได้เลย เห็นข้อความปิดปรับปรุงแทน ไม่เห็นข้อความเก่าใดๆ
4. @warren เปิดแชทกับ @wynos_online → ใช้งานได้ปกติทุกอย่าง (ส่ง/รับ/ดูประวัติ/Share to Chat)
5. ข้อมูลบทสนทนา/ข้อความทั้งหมดในฐานข้อมูลยังอยู่ครบ ไม่มีการลบ/แก้ไขใดๆ — QA ต้องตรวจสอบด้วย query ตรงว่า row count ก่อน/หลัง deploy เท่ากัน
6. มีวิธี toggle ปิด/เปิด lockdown ได้โดยไม่ต้อง build/deploy client ใหม่ (ยืนยันด้วยการทดสอบ toggle จริงบน local Postgres)
7. เมื่อปลด lockdown (toggle ปิด) ผู้ใช้ทั่วไปกลับมาใช้แชทได้ตามปกติทุกอย่าง รวมถึงเห็นบทสนทนาเก่าที่เคยถูกซ่อนไว้ครบถ้วน (regression test ยืนยัน)
8. Push notification เกี่ยวกับข้อความใหม่/message request สำหรับผู้ใช้ที่ไม่อยู่ใน allowlist ไม่ควรเกิดขึ้นเลยในช่วง lockdown (เพราะส่งข้อความไม่ได้อยู่แล้ว — ตรวจสอบว่าไม่มี edge case ที่ notification ยังหลุดออกไป)

## Dependencies

- WYN-031 (1:1 Chat พื้นฐาน), WYN-032 (Message Request), WYN-033 (Share to Chat), WYN-045 (Privacy controls / dm_permission) — ต้องเข้าใจ flow เดิมทั้งหมดก่อนแก้ RLS
- ต้องรู้ `profiles.id` จริงของ @warren และ @wynos_online บน production (Coding/Deploy ต้อง query หา ไม่ hardcode username string ลง RLS policy โดยตรงเพราะ username เปลี่ยนได้)

## Priority

**สูง (Founder สั่งด่วน)** — แต่เป็นการเปลี่ยน RLS/เพิ่มกลไก config ใหม่บนตารางที่มีข้อมูลจริงอยู่แล้ว (`conversations`/`messages`) จึงต้องผ่าน QA อย่างรอบคอบก่อน deploy (ไม่ข้าม QA แม้จะด่วน — ตาม WORKFLOW.md "ห้ามข้าม QA สำหรับงานที่จะขึ้น production เด็ดขาด")

## Risks

- **False lockdown ผิดคู่**: ถ้า resolve `profiles.id` ของ @warren/@wynos_online ผิดพลาด (เช่น username พิมพ์ผิด/มีการเปลี่ยน username ภายหลัง) จะปิดแชทของ Founder เองไปด้วยโดยไม่ตั้งใจ — ต้อง verify id ให้ถูกต้อง 100% ก่อน deploy จริง (QA ต้องเทียบ id ตรงจาก `profiles` table)
- **RLS SELECT ที่เข้มงวดขึ้นกระทบ mark_conversation_read()/unread badge**: ฟังก์ชัน `mark_conversation_read()`/`count_unread_conversations()` ที่มีอยู่แล้วอาจพึ่งพาการเห็นบทสนทนาทุกอันของตัวเอง — ต้องตรวจสอบว่าไม่พังหรือ error แปลกๆ สำหรับผู้ใช้ที่ถูก lockdown (ควรจะแค่นับ 0 ไม่ error)
- **ลืม toggle กลับ**: เพราะเป็นเรื่องชั่วคราว มีความเสี่ยงที่จะลืมปลด lockdown ตอนเปิดใช้งานจริง — แนะนำบันทึกไว้ใน `.wyn/company/DECISIONS.md` และ/หรือสร้าง task ติดตามแยกเพื่อเตือนตอนใกล้ launch จริง
- **Performance**: การเพิ่มเงื่อนไข allowlist check ใน RLS policy ของตารางที่ query บ่อย (`messages`) ต้องมั่นใจว่าไม่ทำให้ query ช้าลงมาก (allowlist ควรเล็กมาก 2 แถว ผลกระทบต่ำ)

## Recommendation (Product)

แนะนำให้ AI Design (ถ้าจำเป็นต้องออกแบบหน้า "ระบบแชทปิดปรับปรุงชั่วคราว" ให้เข้ากับ design system เดิม) → AI Coding (เพิ่มตาราง/flag config + แก้ RLS/RPC 3 จุด + UI 1 หน้าจอ) → AI QA & Security (เน้นตรวจ RLS ให้ตรงตาม acceptance criteria ทุกข้อ + regression: ข้อมูลเก่าไม่หาย + toggle กลับได้จริง) → AI Deploy & DevOps (deploy พร้อม production verification query โดยตรงว่า allowlist ตรงกับ @warren/@wynos_online จริง)

เนื่องจากเป็นการเปลี่ยน RLS บนตารางที่มีข้อมูลผู้ใช้จริงอยู่แล้ว **ไม่ควรข้าม QA แม้ Founder จะเร่งด่วน** — ความเสี่ยงที่ resolve user id ผิดแล้วปิดแชทของ Founder เองมีจริงและตรวจสอบได้ง่ายด้วย QA ขั้นตอนเดียว

---

## AI Design Output (เสร็จแล้ว — ดูฉบับเต็มที่ `.wyn/docs/design/wyn-122-chat-lockdown-testers-only.md`)

**สรุปการตัดสินใจ**:
1. Reuse `EmptyStateBlock` (widget เดิมที่ Chat Inbox/Notifications ใช้อยู่แล้ว) — ไม่สร้าง component ใหม่
2. Icon `Icons.lock_clock_outlined` (เดียวกับ `RestrictionBanner`, สื่อ "ชั่วคราว" ไม่ใช่ "แบนถาวร"), title "ระบบแชทปิดปรับปรุงชั่วคราว", subtitle "จะเปิดให้ใช้งานได้เร็ว ๆ นี้"
3. State "Locked" เป็นลำดับความสำคัญสูงสุดในทั้ง 3 หน้าจอต่อเนื่อง (Chat Inbox, Conversation Screen, New Message Screen) — เหนือ Loading/Error/Empty/Blocked/Restricted ทั้งหมด
4. Chat entry points (ไอคอน Home, ปุ่ม "ส่งข้อความ" โปรไฟล์) **ไม่แตะ ไม่ซ่อน ไม่ disable** ตามที่ Founder ยืนยัน
5. ปุ่ม "ส่งข้อความ" (action ครั้งเดียว ไม่ใช่มุมมองต่อเนื่อง) ใช้ SnackBar แทน full-screen state เมื่อ RPC ปฏิเสธเพราะ lockdown — มิเรอร์ pattern WYN-121's delete-failure SnackBar

**หน้าจอที่แก้**: Chat Inbox (`ChatInboxScreen`), Conversation Screen (`ConversationScreen` — ซ่อนทั้ง message list และ composer ไม่ใช่แค่ composer), New Message Screen (`NewMessageScreen`, defense-in-depth), ปุ่ม "ส่งข้อความ" บน `ViewProfileScreen`

**Contract สำหรับ Coding**: client ต้องเช็คได้ว่า (ก) ผู้ใช้ปัจจุบันอยู่ใน allowlist ไหม (สำหรับ Screen A/C) และ (ข) ทั้งสองฝ่ายของบทสนทนานี้อยู่ใน allowlist ทั้งคู่ไหม (สำหรับ Screen B) — mechanism ฝั่ง backend เป็นของ Coding ตาม R2

## Handoff

ส่งต่อ **AI Coding** — ลำดับแนะนำเต็มอยู่ท้าย `.wyn/docs/design/wyn-122-chat-lockdown-testers-only.md`: (1) backend enforcement (allowlist + RLS/RPC 3 จุด + data-driven toggle) (2) `ChatRepository` เพิ่ม lockdown-check method (3)-(6) เพิ่ม state Locked ใน 4 จุด UI ตามที่ระบุ

---

## AI Coding Output (เสร็จแล้ว — ส่งต่อ AI QA & Security)

**Implementation**: Backend enforcement ที่ RLS/RPC layer ตาม R1 (allowlist ทั้งสองฝ่ายถึงจะใช้แชทได้) + data-driven toggle ตาม R2 (ไม่ต้อง deploy client ใหม่เพื่อเปิด/ปิด) + UI 4 จุดตาม Design spec (Locked state สำหรับ Chat Inbox/Conversation Screen/New Message Screen + SnackBar เฉพาะสำหรับปุ่ม "ส่งข้อความ")

**Files Changed**:
- `supabase/schema.sql` — ตาราง `chat_lockdown`/`chat_lockdown_allowlist` ใหม่, ฟังก์ชัน `internal.chat_pair_allowed()`/`public.chat_lockdown_status()` ใหม่, แก้ `get_or_create_conversation()`/`count_unread_conversations()`, แก้ RLS policy 4 จุด (conversations SELECT, messages SELECT/INSERT, chat-media storage INSERT)
- `.github/workflows/wyn122-apply-chat-lockdown-schema.yml` (ใหม่) — migration workflow ที่จะ apply เข้า production จริง (idempotent, resolve @warren/@wynos_online id จาก username ไม่ hardcode UUID, refuse ถ้าหาไม่ครบ 2 คน)
- `.github/workflows/wyn122-toggle-chat-lockdown.yml` (ใหม่) — สวิตช์เปิด/ปิด lockdown จริง (status/enable/disable) — คือกลไก R2 ตัวจริงที่ Founder จะใช้ตอนเปิดใช้งานจริง
- `supabase/tests/wyn_122_chat_lockdown_test.sh` (ใหม่) — regression test 15 checks
- `app/lib/features/chat/data/chat_repository.dart` — `isChatAllowed({otherUserId})`
- `app/lib/features/chat/presentation/{chat_inbox_screen,conversation_screen,new_message_screen}.dart` — state "Locked" ใหม่
- `app/lib/features/profile/presentation/view_profile_screen.dart` — SnackBar เฉพาะสำหรับ lockdown rejection
- Dart tests: `chat_inbox_screen_test.dart`, `conversation_screen_test.dart`, `new_message_screen_test.dart`, `view_profile_screen_test.dart`, `support/recording_chat_repository.dart`

**Reason**: ตรงตาม Product/Design spec ทุกข้อ — ดูเหตุผลละเอียดในแต่ละไฟล์ (doc comment อธิบาย "ทำไม" ไว้ตรงจุดที่แก้)

**Tests**:
- SQL/RLS: `bash supabase/tests/wyn_122_chat_lockdown_test.sh` — **15/15 PASS** จริงกับ local PostgreSQL 16 + schema.sql (ไม่ใช่แค่ syntax check) — ครอบคลุมทุก Acceptance Criteria ของ Product spec (AC1-AC7, AC8 ยืนยันเชิงโครงสร้างว่า notification ไม่มีทางเกิดเพราะ message insert ถูกบล็อกที่ RLS ก่อน trigger ใดๆ จะทำงาน)
- Regression: รัน `wyn_031_chat_test.sh`, `wyn_032_message_request_test.sh`, `wyn_033_share_to_chat_test.sh`, `wyn_037_edit_delete_drop_test.sh`, `wyn_120_*_test.sh` ซ้ำ — **ทุกตัวยัง PASS ครบ** ไม่มี regression จากการแก้ RLS
- Migration workflow: ทดสอบ dry-run จริงกับ local Postgres (จำลอง production ก่อน/หลัง migrate) — apply ได้สำเร็จ, idempotent (รันซ้ำ 2 ครั้งไม่มี error/ไม่มี duplicate), resolve username→id ถูกต้อง
- Dart/Flutter: ไม่มี Flutter SDK ใน sandbox นี้ให้รัน `flutter analyze`/`flutter test` จริง — พึ่งพา CI ตามที่ทำมาตลอด session — เขียน test ใหม่ 7 เคสครอบคลุม Locked state ทั้ง 3 หน้าจอ + SnackBar behavior ทั้ง 2 เคส (lockdown vs. ล้มเหลวจริง) โดยตรวจสอบ syntax/API เทียบกับ `RecordingChatRepository`/`PostgrestException` ที่มีอยู่แล้วในโปรเจกต์อย่างละเอียด

**Build**: ไม่สามารถรัน `flutter build`/`flutter analyze` ใน sandbox นี้ได้ (ไม่มี Flutter SDK) — SQL migration ยืนยันโหลดสำเร็จ 100% (`psql` โหลด `schema.sql` เต็มไฟล์ผ่านไม่มี error หลังแก้)

**Known Issues**:
1. `accept_message_request()` ไม่ได้เพิ่ม lockdown check (มีแค่ใน `get_or_create_conversation()`/messages SELECT/INSERT) — เป็น edge case ที่ต้องมี pending request ที่สร้างไว้ *ก่อน* lockdown เปิดจากคู่ที่ไม่ผ่าน allowlist ถึงจะเกิดได้ แม้ accept สำเร็จก็ยังคุยกันไม่ได้จริง (messages SELECT/INSERT ยังบล็อกอยู่ดี) จึงไม่กระทบ security แต่ตัดสินใจไม่แก้ในรอบนี้เพื่อคุมขอบเขตการเปลี่ยนแปลงให้เล็กที่สุด
2. `storage.objects` SELECT policy (ดูรูปในแชท) ไม่ได้เพิ่ม lockdown check — เพราะ `messages` SELECT ที่ถูกบล็อกไปแล้วทำให้ client ไม่มีทางได้ `image_url` ของบทสนทนาที่ถูกล็อกมาขอดูตั้งแต่แรกอยู่แล้ว (ไม่มี attack surface ใหม่)
3. Pattern เดียวกันนี้ (catch-all error message) ยังพบใน Club post screens อีก 4 จุดจากงาน WYN-121 ก่อนหน้า — ไม่เกี่ยวกับ WYN-122 โดยตรง ไม่ได้แตะในรอบนี้

**Handoff**: ส่งต่อ **AI QA & Security** — เน้นตรวจ: (1) resolve @warren/@wynos_online id ถูกต้องจริงบน production ก่อน deploy จริง (ความเสี่ยงหลักตาม Risks section) (2) ยืนยัน RLS policy ทั้ง 4 จุดครอบคลุมตรงตาม Acceptance Criteria ทุกข้อ (3) ทดสอบ toggle เปิด-ปิดจริงว่าทำงานตามคาด (4) ตรวจสอบว่า UI 4 จุดไม่มี regression กับ flow ปกติที่ไม่ถูก lockdown

---

## AI QA & Security Output — Round 1

**Feature**: WYN-122 (Chat Lockdown — เหลือเฉพาะ @warren ↔ @wynos_online)
**Environment**: Local PostgreSQL 16 + `schema.sql` จริง (ไม่ใช่ mock), role-switching เป็น `authenticated` จริงผ่าน JWT claim GUC, สร้าง/ทำลาย database ทดสอบแยกจาก production 100% — CI ของ PR #279 (เขียวแล้ว, `flutter analyze`/`flutter test` ผ่านหมด)

**Test Cases**:
1. รัน `supabase/tests/wyn_122_chat_lockdown_test.sh` ซ้ำเองอิสระ (ไม่เชื่อรายงานของ Coding เฉยๆ) — 15/15 PASS
2. รัน `wyn_031/032/033/037/120_*_test.sh` ซ้ำ — regression ทั้งหมด PASS ไม่มีอะไรพัง
3. **Adversarial**: ทดสอบว่าผู้ใช้ทั่วไปสามารถ INSERT ตัวเองลง `chat_lockdown_allowlist` ตรงๆ ได้ไหม (bypass ผ่าน raw insert) — บล็อกถูกต้อง (RLS ปฏิเสธ, ไม่มี insert policy)
4. **Adversarial**: ทดสอบว่าผู้ใช้ทั่วไปสามารถ UPDATE `chat_lockdown.enabled` ตรงๆ ได้ไหม — บล็อกถูกต้อง (0 rows affected, ไม่มี update policy)
5. **Edge case**: lockdown เปิดอยู่แต่ allowlist ว่างเปล่า (เช่น migration รันแต่ populate ล้มเหลว) — ยืนยันว่า fail-safe (ล็อกทุกคนออกหมด ไม่มีใครหลุดผ่านไปได้) ไม่ใช่ fail-open
6. ยืนยัน `chat_inbox`/`message_requests` view (security_invoker) สะท้อน lockdown ถูกต้องจริงด้วย query ตรง ไม่ใช่แค่เชื่อ comment ในโค้ด
7. **พยายาม break ตาม role หน้าที่ ("พยายาม break implementation อย่างจริงจัง")**: ตรวจสอบ `internal.chat_pair_allowed()`'s privilege model เทียบกับ helper function อื่นทุกตัวในไฟล์เดียวกัน (grep หา `grant execute on function internal.*` ทั้งหมด 10 จุด) พบว่า**ทุกจุดมี grant ยกเว้นตัวใหม่นี้ตัวเดียว** — ทดสอบจริงด้วยการ `revoke execute ... from public` แล้วยืนยันว่า RLS policy ที่เรียกใช้ฟังก์ชันนี้ (conversations SELECT, messages SELECT/INSERT, storage.objects INSERT) **แตกจริง** ("permission denied for function chat_pair_allowed") ขณะที่ฟังก์ชัน SECURITY DEFINER (get_or_create_conversation/count_unread_conversations/chat_lockdown_status) ไม่กระทบเพราะรันในบริบทของ owner

**Passed**: 1, 2, 3, 4, 5, 6 (6/7 test areas)

**Failed**: 7 — ดูรายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-122-chat-pair-allowed-missing-execute-grant.md`

**Severity**: **สูง (Critical ถ้า deploy โดยไม่แก้)** — ไม่ใช่แค่ edge case เล็กน้อย: ถ้า production Supabase project เคยหรือจะมีการ revoke default execute privilege ใดๆ (เป็น hardening practice ที่พบได้จริง) ฟีเจอร์แชททั้งระบบจะพังสำหรับ**ทุกคนรวมถึง @warren/@wynos_online เอง** ไม่ใช่แค่ปิดแบบตั้งใจ

**Reproduction Steps**: ดู `.wyn/tasks/bugs/WYN-122-chat-pair-allowed-missing-execute-grant.md`'s "Reproduction" section — ยืนยันได้จริงด้วย local Postgres ไม่ใช่การเดา

**Expected**: `internal.chat_pair_allowed(uuid, uuid)` ควรมี `grant execute on function internal.chat_pair_allowed(uuid, uuid) to authenticated;` ตรงตาม convention 100% ของทุก internal helper function อื่นในไฟล์เดียวกัน

**Actual**: ไม่มี grant statement เลย — ทำงานได้ตอนนี้เพราะพึ่งพา Postgres default (EXECUTE granted to PUBLIC ตอนสร้าง function) ที่ยังไม่ถูก revoke เท่านั้น ซึ่งเป็นสมมติฐานที่ไฟล์นี้เองมี comment เตือนไว้ชัดเจนแล้วว่าห้ามพึ่งพา (บรรทัด 2080-2096)

**Security Findings**: ไม่พบช่องโหว่ privilege escalation อื่นเพิ่มเติม (ตรวจแล้วว่า insert เข้า allowlist / update toggle ตรงๆ ถูกบล็อกถูกต้อง) — finding เดียวคือเรื่อง missing grant ข้างต้น ซึ่งเป็นความเสี่ยง "จะพังทั้งระบบ" มากกว่า "รั่วข้อมูล"

**Recommendation**: ส่งกลับ AI Debug Engineer เพิ่ม `grant execute ... to authenticated` 1 บรรทัดใน `supabase/schema.sql` และ `.github/workflows/wyn122-apply-chat-lockdown-schema.yml` (2 จุด, statement เดียวกัน) แนะนำเพิ่มเป็น regression check ถาวรใน `wyn_122_chat_lockdown_test.sh` ด้วย (revoke แล้วยืนยัน error, grant แล้วยืนยันหาย) กันไม่ให้ใครลืม grant นี้อีกในอนาคตถ้ามีการแก้ฟังก์ชันนี้ซ้ำ

**Final Status: FAIL**
