# Product Task — WYN-128

Status: **QA รอบ 2: PASS (2026-09-07) — พร้อม Deploy** — ตรวจซ้ำทั้ง 2 fix อิสระด้วย live PostgreSQL 16.13: (1) member รายงานข้อความคนอื่นได้จริง, เจ้าของรายงานตัวเองไม่ได้, non-member รายงานไม่ได้, admin สั่ง remove_content ลบข้อความจริง+แจ้งเตือนผู้เขียน (2) staged-rollout gate ปิดช่องจริง — `flutter analyze`/`flutter test` (1377/1377) ผ่านหมด
Owner: AI Product Manager → AI Design (เสร็จ) → Founder อนุมัติสถาปัตยกรรม (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ, FAIL) → AI Debug Engineer (เสร็จ) → AI QA & Security (เสร็จ, PASS) → AI Deploy & DevOps (ถัดไป)

Feature: Club Group Chat — ห้องแชทสด (real-time) **ต่อห้อง (channel)** แยกจากฟีดโพสต์ของห้องนั้น

Goal: เติมแกนที่สำคัญที่สุดของความเป็น Discord ให้ WYN Club — การพูดคุยสดต่อเนื่อง ไม่ใช่แค่โพสต์แล้วรอคนมา like/comment ทีหลัง ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 2 (ระบุไว้ตั้งแต่ founder brief ต้นฉบับ WYN-014 แล้วว่า "Club Chat" เป็นทิศทางที่ตั้งใจต่อยอด)

Target User: สมาชิกที่ approved แล้วของ Club ทุกคน (สิทธิ์เดียวกับการเห็นโพสต์ใน Club)

Problem: WYN มีระบบแชทอยู่แล้ว (WYN-031/032/033) แต่เป็น**การสนทนา 1-ต่อ-1 เท่านั้น** — ไม่มีทางให้สมาชิก Club หลายคนคุยกันสดๆ พร้อมกันในที่เดียวเลย ทำให้ Club รู้สึกเป็น "บอร์ดประกาศ" มากกว่า "ห้องพูดคุยที่มีชีวิต" แบบ Discord

Requirements:
1. **Founder ยืนยันแล้ว (2026-09-07, "แยกตามห้อง เหมือนดิส")**: แชทผูกกับแต่ละ **channel** (WYN-127) ไม่ใช่ผูกกับ Club ทั้งก้อน — ทุก channel ที่มีอยู่มีห้องแชทของตัวเอง สลับ channel = สลับห้องแชทไปด้วยในตัว (ใช้แถบ channel switcher เดียวกับ WYN-127 เป๊ะ ไม่ต้องออกแบบ navigation ใหม่แยก) — สมาชิก approved ของ Club เห็นและพิมพ์ในทุกห้องแชทของทุก channel ได้ (สิทธิ์เดียวกับสิทธิ์เข้าดู Club)
2. ข้อความในห้องแชทเรียงตามเวลาจริง อัปเดตแบบ real-time (เห็นข้อความใหม่ทันทีไม่ต้อง refresh) — ใช้ Supabase Realtime เหมือนที่ 1-ต่อ-1 chat ใช้อยู่แล้ว
3. รองรับ: ข้อความตัวอักษร, รูปภาพ (ระดับเดียวกับที่ 1-ต่อ-1 chat รองรับวันนี้), reply-quote ข้อความก่อนหน้า
4. Owner/Admin/Moderator ลบข้อความของคนอื่นได้ (moderation — สอดคล้องกับสิทธิ์ที่มีอยู่แล้วสำหรับลบโพสต์)
5. คนที่ถูก ban/remove ออกจาก Club ต้องไม่เห็น/พิมพ์ในห้องแชทได้อีกทันที
6. Badge แจ้งเตือนข้อความใหม่ที่ยังไม่อ่าน (unread) บนปุ่ม/แท็บเข้าห้องแชทของ Club — เหมือน unread badge ที่ระบบแชท 1-ต่อ-1 มีอยู่แล้ว

Acceptance Criteria:
- สมาชิก 2 คนขึ้นไปที่ approved ใน Club เดียวกัน พิมพ์ข้อความในห้องแชทเห็นกันแบบ real-time โดยไม่ต้อง refresh
- คนที่ยังไม่ join หรือถูก ban ออกจาก Club เข้าห้องแชทไม่ได้เลย (ทั้ง read และ write)
- Owner ลบข้อความของสมาชิกคนอื่นได้ สมาชิกทั่วไปลบได้แค่ข้อความตัวเอง
- ออกจาก Club แล้วกลับเข้ามาใหม่ (ถ้า Public) ยังอ่านประวัติแชทเก่าได้ (ไม่ลบประวัติตอนออก)
- unread badge อัปเดตถูกต้องเมื่อมีข้อความใหม่ระหว่างที่ไม่ได้เปิดหน้าแชทอยู่

Dependencies: **ต้อง WYN-127 (Club Channels) merge/deploy ก่อนเสมอ** — เพราะแชทผูกกับ `channel_id` ของ WYN-127 โดยตรง ไม่มี channel ก็ไม่มีที่ให้แชทผูกกับ — schema แชทเดิม (`conversations`/`messages` จาก WYN-031) ออกแบบไว้สำหรับคู่สนทนา 2 คนเท่านั้น (`conversation_participants` แบบ 1-1) ดู Recommendation ด้านล่างสำหรับแนวทาง schema ที่ AI Design เลือก

Priority: **สูง (คุณค่าที่สุด) แต่ทำทีหลัง WYN-127/WYN-129** — เป็นงานใหญ่ที่สุดในสามอัน ต้องแตะ schema แชทเดิมที่ sensitive (ระบบ 1-ต่อ-1 ที่ใช้งานจริงอยู่แล้วต้องไม่พัง) ควรพิสูจน์ demand จาก Channels ก่อนลงทุนหนัก

Risks:
- **ความเสี่ยงสูงสุด**: ถ้าออกแบบ schema ผิดพลาดจนกระทบระบบแชท 1-ต่อ-1 ที่มีอยู่แล้วและมีผู้ใช้จริงใช้งานอยู่ (regression ต่อฟีเจอร์ที่ทำงานดีอยู่แล้ว) — Design ต้องเลือกแนวทางที่แยกความเสี่ยงจากระบบเดิมให้ชัดเจน (แนะนำเบื้องต้น: ตารางใหม่แยกต่างหากสำหรับ Club chat แทนที่จะ modify ตารางเดิม จนกว่า Design จะยืนยันแนวทางที่ปลอดภัยกว่า)
- Club ขนาดใหญ่ (สมาชิกหลักพันคน) ในห้องแชทเดียวอาจข้อความไหลเร็วเกินจะติดตามได้ — ต้องพิจารณา pagination/loading เก่า-ใหม่ตั้งแต่ Design ไม่ใช่แก้ทีหลัง
- Moderation (WYN-026/027/028/029) ต้องขยายมาครอบคลุมข้อความในห้องแชท Club ด้วย ไม่ใช่แค่โพสต์ — ต้องเช็คกับระบบ report/block ที่มีอยู่แล้วว่าครอบคลุมหรือไม่

Recommendation: **APPROVED (2026-09-07, Founder: "ทำต่อให้เสร็จเลย")** — แนวทาง schema ที่ AI Design เลือก (ดูหัวข้อ "AI Design Output") คือสร้างตารางใหม่แยกต่างหากสำหรับ Club chat โดยเฉพาะ (`club_channel_messages` + ใช้ RLS ผูกกับ `club_role()`โดยตรง) **ไม่แตะตาราง `conversations`/`messages`เดิมของ WYN-031 เลยแม้แต่บรรทัดเดียว** เพื่อไม่ให้มีความเสี่ยงต่อระบบแชท 1-ต่อ-1 ที่ใช้งานจริงอยู่แล้ว — บันทึกการอนุมัติใน `.wyn/company/APPROVALS.md` แล้ว

Handoff: ส่งต่อ AI Coding → AI QA & Security (เน้นตรวจว่าไม่มีจุดใดแตะ/เปลี่ยนพฤติกรรม `conversations`/`messages` เดิมเลย, ตรวจ RLS ผูกกับ `club_role()` ถูกต้องตาม channel, ตรวจคนถูก ban เข้าห้องแชทไม่ได้ทันที)

## QA Output (2026-09-07) — FAIL

ทดสอบจริงบน PostgreSQL 16.13 local (live RLS, `set role authenticated` + JWT claim GUC, ไม่ใช่แค่อ่าน SQL):
- `grep` ยืนยัน migration/schema section ของ WYN-128 ไม่มีคำสั่ง DDL/DML ใดแตะ `conversations`/`conversation_participants`/`messages` เลย (มีแค่ comment อ้างอิงถึง)
- อ่าน/เขียนข้อความถูกจำกัดด้วย `club_role(channel's club_id, auth.uid())` ถูกต้องจริง: approved member อ่าน/เขียนได้, pending/non-member ถูกบล็อกทั้งอ่านและเขียนจริง
- **Ban-mid-chat ยืนยันว่าบล็อกจริงที่ระดับ RLS ไม่ใช่แค่ UI**: ทดสอบจริงว่าหลังสมาชิกถูกเปลี่ยนสถานะเป็น `banned` กลางบทสนทนา ทั้ง SELECT (อ่านข้อความ) และ INSERT (ส่งข้อความ) ถูกปฏิเสธทันทีที่ database layer แม้จะจำลองกรณี "ปุ่มส่งข้อความยังทำงานอยู่จากฝั่ง UI ที่ค้าง" — RPC `mark_club_channel_read`/`get_unread_channel_counts` ก็ปฏิเสธ/คืนค่าว่างให้คนที่ถูก ban เช่นกัน — ประวัติแชทก่อนถูก ban ยังอยู่ให้สมาชิกคนอื่นเห็นตามปกติ (ไม่ถูกลบย้อนหลัง) ตรงตาม Acceptance Criteria; ในโค้ด Dart (`ClubPostsTab._onBanned`) การสลับ view กลับไป Posts tab ทำให้ `ClubChannelChatView` ถูก unmount จริง (ใช้ conditional widget swap ไม่ใช่ `IndexedStack`) จึง `dispose()`/unsubscribe realtime channel จริง ไม่ใช่แค่ซ่อนหน้าจอ
- ลบข้อความ: เจ้าของข้อความหรือ Owner/Admin/Moderator เท่านั้น ทดสอบจริงว่า pending member และสมาชิกอื่นลบข้อความคนอื่นไม่ได้, Moderator ลบของคนอื่นได้ (moderation), เจ้าของลบเองได้
- Storage: รูปแชทใช้ policy เดิมของ `club-media` จริงตามที่อ้าง (`array_length(...) > 1` + `club_role() is not null` ครอบคลุม path `{club_id}/chat/{channel_id}/...` แล้วโดยไม่ต้องเพิ่ม policy ใหม่) — ยืนยันโดยอ่าน policy จริงใน `schema.sql`

**เหตุผลที่ FAIL** (2 เรื่อง):
1. **พบช่องโหว่ moderation gap จริง**: ข้อความในห้องแชทกลุ่ม**ไม่มีทาง report ได้เลย** ทั้ง UI (`ClubChannelChatView._showMessageMenu` มีแค่ "ตอบกลับ"/"ลบข้อความ" ไม่มี "รายงาน") และ backend (`reports.target_type` CHECK constraint ไม่มีค่าไหนรองรับข้อความแชทเลย) — นี่คือ Risk ที่ task spec ของ WYN-128 เองระบุไว้ตรงๆ ว่าต้องเช็ค ("Moderation ต้องขยายมาครอบคลุมข้อความในห้องแชท Club ด้วย") แต่ Coding Notes ไม่มีร่องรอยว่าถูกตรวจสอบ/แก้ไข รายละเอียด/fix ที่แนะนำ: `.wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md`
2. ขาด developer-account staged-rollout gate ร่วมกับ WYN-127/129 — ดู `.wyn/tasks/bugs/WYN-127-128-129-missing-staged-rollout-gate.md`

Final Status: **FAIL** (สถาปัตยกรรม/RLS/ban-mid-chat/ไม่แตะระบบเดิม ปลอดภัยและถูกต้องตามที่ทดสอบจริงทั้งหมด — บล็อกเพราะขาดช่องทาง report ข้อความ + staged-rollout gate)

## QA Output รอบ 2 (2026-09-07) — PASS

ตรวจซ้ำหลัง AI Debug Engineer แก้ (commit `005708b`, `1bb6fa4`) ด้วยวิธีเดิม (live PostgreSQL 16.13 + `flutter analyze`/`flutter test`):
- รัน `supabase/tests/wyn_128_group_chat_report_test.sh` ที่ Debug เพิ่มมาเอง: 9/9 ผ่าน
- **เขียน SQL ทดสอบเองแยกต่างหาก (ไม่พึ่งแค่ test script ของ Debug)** ยืนยันซ้ำ: member ที่ approved รายงานข้อความคนอื่นได้จริง (`submit_report('club_channel_message', ...)`), เจ้าของข้อความรายงานข้อความตัวเองไม่ได้, non-member รายงานไม่ได้, เรียก `apply_moderation_action(..., 'remove_content', ...)` แล้วข้อความถูกลบจริง (`club_channel_messages` ไม่มีแถวนั้นอีก), status ของ report เปลี่ยนเป็น `actioned` จริง
- `flutter analyze`: no issues. `flutter test`: 1377/1377 ผ่านทั้งหมด
- Staged-rollout gate: ตรวจสอบร่วมกับ WYN-127 (ดู QA Output รอบ 2 ของ WYN-127) — `ClubChannelChatView`/"โพสต์ | แชท" toggle ถูกซ่อนสำหรับ non-developer account ผ่าน `ClubPostsTab`'s gate เดียวกัน ยืนยันแล้วว่า `_viewMode` ไม่มีทางออกจาก `.posts` เมื่อ toggle ไม่ถูก render เลย (อ่าน diff จริง)

Final Status: **PASS — พร้อม Deploy**

## AI Design Output

Screen: Club Page → Group Chat (เข้าถึงผ่านแถบ channel switcher เดียวกับ WYN-127 — ไม่มีแท็บ "แชท" แยกต่างหากในระดับ Club อีกต่อไป เพราะแชทอยู่ *ภายใน* แต่ละ channel)

Purpose: ให้สมาชิกในแต่ละห้องคุยกันสดๆ ได้ ไม่ใช่แค่โพสต์รอคนมาคอมเมนต์ทีหลัง — mockup เต็ม: https://claude.ai/code/artifact/d08fb9ad-0757-486b-9808-9c65cbe1d9b7 (แท็บ "WYN-128 Group Chat", Founder อนุมัติ 2026-09-07)

User Flow: เปิด Club Page → เลือก channel จากแถบด้านบน (เหมือน WYN-127) → เห็นห้องแชทของ channel นั้นทันที (ไม่ใช่ฟีดโพสต์ — ให้ Design ตัดสินใจว่า Posts กับ Chat ของ channel เดียวกันสลับด้วย toggle ย่อยภายใน หรือแยกเป็นคนละหน้าที่กดเข้าจาก channel — **แนะนำ**: toggle เล็กๆ "โพสต์ | แชท" ใต้แถบ channel เพื่อให้ channel หนึ่งมีทั้งสองแบบในที่เดียว ไม่ต้องสร้าง navigation ชั้นใหม่) → พิมพ์ข้อความ ส่งแบบ real-time

Components: ใช้ widget ชุดเดียวกับ conversation_screen.dart (WYN-031) ทุกจุดที่ไม่เกี่ยวกับ 1-1 โดยเฉพาะ — chat bubble (sent=sapphire, received=surfaceTint), input pill + ปุ่มส่งวงกลม, ต่างจากเดิมแค่ 2 จุด: (1) ชื่อผู้ส่งกำกับเหนือ bubble ที่ไม่ใช่ตัวเอง (จำเป็นเพราะเป็นกลุ่ม) (2) หัวห้องโชว์จำนวนสมาชิกออนไลน์แทนสถานะ "ออนไลน์/ออฟไลน์" ของคู่สนทนาคนเดียว

Interactions: พิมพ์+กดส่ง เหมือน 1-1 chat เป๊ะ, Owner/Admin/Moderator กด "..." บนข้อความคนอื่น → เมนู "ลบข้อความ" (เทียบเท่าสิทธิ์ลบโพสต์ที่มีอยู่แล้ว)

States: ห้องแชทว่าง (ยังไม่มีใครพิมพ์เลย) → empty state ข้อความสั้นๆ เชิญชวนเริ่มคุย, ถูก ban ระหว่างเปิดหน้าแชทอยู่ → เด้งออกจากหน้าทันที (เหมือน pattern ที่ AccountRestrictedScreen ใช้ตรวจ moderation status)

Responsive Behavior: รายการข้อความ scroll ได้ไม่จำกัด (pagination โหลดข้อความเก่าเมื่อเลื่อนขึ้นสุด เหมือน 1-1 chat)

Accessibility: เหมือน conversation_screen.dart เดิมทุกประการ (ผ่าน accessibility review มาแล้วในงานเดิม)

Design Rules: ห้ามสร้าง UI chat ใหม่ตั้งแต่ศูนย์ — reuse component จาก WYN-031 ให้มากที่สุด ต่างเฉพาะจุดที่จำเป็นจริงๆ (ชื่อผู้ส่ง, จำนวนออนไลน์)

**ข้อเสนอสถาปัตยกรรม schema (APPROVAL_REQUIRED)**: สร้างตารางใหม่ `club_channel_messages` (คอลัมน์คล้าย `messages` เดิม: id, channel_id, author_id, content, image_url, reply_to_message_id, created_at) + RLS policy อ่าน/เขียนผ่าน `club_role(channel's club_id, auth.uid()) is not null` โดยตรง — **ไม่แตะ `conversations`/`conversation_participants`/`messages` ของ WYN-031 เลย** เหตุผล: ระบบ 1-1 ออกแบบมาเฉพาะคู่สนทนา 2 คน (unique constraint/index หลายจุดสมมติฐานนี้) การบังคับให้รองรับ N คนจะเสี่ยงกระทบทุกจุดที่อ้างอิง "อีกฝ่าย" (เช่น unread count, online status ของคู่สนทนา) — แยกตารางใหม่ปลอดภัยกว่ามาก แลกกับโค้ด UI ซ้ำกันเล็กน้อยระหว่าง 2 ระบบ ซึ่งยอมรับได้

Handoff: สถาปัตยกรรมนี้ Founder อนุมัติแล้ว (2026-09-07) → ส่งต่อ AI Coding

## Coding Notes (2026-09-07)

- Migration SQL: `supabase/migrations_wyn128_club_channel_messages.sql` (Founder ต้องรันผ่าน Supabase Dashboard เอง — ยังไม่ได้ apply) + `supabase/schema.sql` อัปเดตให้ตรงกัน — ไม่แตะ `conversations`/`conversation_participants`/`messages` แม้แต่บรรทัดเดียวตามที่อนุมัติไว้
- เพิ่มตาราง `club_channel_message_reads` + RPC `mark_club_channel_read()`/`get_unread_channel_counts()` นอกเหนือจาก `club_channel_messages` ที่อนุมัติไว้ตรงๆ — จำเป็นสำหรับ Requirement 6/AC เรื่อง unread badge ซึ่งข้อความอนุมัติเดิมพูดถึงแต่ยังไม่มี schema รองรับ เป็นส่วนขยายตามธรรมชาติของฟีเจอร์เดียวกัน (ตารางใหม่ล้วน ไม่กระทบของเดิม)
- รูปแชทใช้ bucket `club-media` เดิม (path `{club_id}/chat/{channel_id}/...`) ไม่ต้องสร้าง storage policy ใหม่ เพราะ policy เดิมของ WYN-014 ครอบคลุมอยู่แล้ว (เช็คแค่ความลึกโฟลเดอร์ + `club_role()`)
- Dart: `ClubChannelMessage`/`ClubChannelChatRepository` (แยกจาก `ChatRepository` เดิมโดยสิ้นเชิงตามที่อนุมัติ), `ClubChannelChatView` ฝังอยู่ใน `ClubPostsTab` ผ่าน toggle "โพสต์ | แชท" (ไม่ใช่ route/tab แยก ตาม Design Rules) — reuse สไตล์ bubble/input จาก `conversation_screen.dart` แต่เป็น widget ใหม่ (`_ChatBubble`) เพราะ `_MessageBubble` เดิมเป็น private class และผูกกับ concept เฉพาะ 1-1 (View Once, shared-content) ที่ห้องนี้ไม่ต้องการ
- จำนวนสมาชิกออนไลน์ใช้ Supabase Realtime Presence (`channel.track`/`onPresenceSync`) บน channel เดียวกับข้อความ
- Unread badge: subscribe เบาๆ (`subscribeToNewMessagesOnly`) ขณะอยู่หน้าโพสต์ สลับไปใช้ subscription เต็มของหน้าแชทเองเมื่อสลับ toggle ไป "แชท" (กัน subscribe ซ้อนสอง channel)
- Ban-mid-chat: เพิ่ม `ClubRepository.subscribeToMyMembership()` (realtime บน `club_members`) — ฟังเฉพาะแถวของตัวเอง, banned/removed แล้ว callback `onBanned` กลับไปที่ `ClubPostsTab` (สลับกลับไปหน้าโพสต์ + reload Club) เพราะหน้าแชทฝังอยู่ใน tab ไม่มี route ของตัวเองให้ "เด้งออก" ตรงๆ ตามที่ Design เขียนไว้ (สมมติฐานเดิมของ Design คือหน้าแชทเป็น route แยก) — เป็น deviation เล็กน้อยจาก wording ของ spec ที่ยังคงเจตนาเดิมไว้ (ผู้ใช้ที่ถูก ban เห็นผลทันที ไม่ค้างอยู่ในห้องแชทที่ตัวเองไม่มีสิทธิ์แล้ว)
- Reply-quote preview ไม่ได้ใส่ชื่อผู้ส่งของข้อความต้นทาง (เหมือน `ChatMessage` เดิมที่ก็ไม่มี) เพื่อลดความซับซ้อนของ PostgREST embed ซ้อนสองชั้น
- `flutter analyze`: no issues. `flutter test`: ผ่านทั้งหมด รวม test ใหม่ `club_channel_chat_view_test.dart` (ส่ง/รับ realtime/reply/delete/ban-detection) และ test เพิ่มใน `club_posts_tab_test.dart` (toggle + unread badge)
