# Product Task — WYN-044

Status: approved (Independent QA PASS 2026-08-24 — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: Notification Settings — เปิด/ปิดการแจ้งเตือนเป็นรายหมวดหมู่

Goal: task ที่สองของ Phase 5 (Notification & Settings Expansion) ต่อจาก WYN-043 — ตาม Roadmap "Notification Settings (เปิด/ปิดรายประเภท)" และ Master Spec section 21 ("ผู้ใช้เปิด/ปิดได้เป็นรายประเภท เช่น Likes, Comments, Follows, Messages, Club, Trending, System") ให้ผู้ใช้ควบคุมได้ว่าอยากได้รับการแจ้งเตือนหมวดไหนบ้าง แทนที่จะได้รับทุกประเภทเสมอแบบตอนนี้ (WYN-012 เดิมไม่มีกลไก opt-out ใดๆ เลย)

Target User: ผู้ใช้ WYN Social ทุกคนที่อยากลดจำนวนการแจ้งเตือนที่ได้รับ (เช่น ปิด Like แต่เปิด Follow/Message ไว้) โดยไม่ต้องปิดการแจ้งเตือนทั้งหมดของแอป

Problem: ตรวจโค้ดจริงยืนยันแล้วว่า `NotificationType` enum (`app/lib/features/notification/data/notification.dart`) ตอนนี้มี 24 ค่า ถูก insert จาก trigger function 10+ ตัวใน `supabase/schema.sql` (บรรทัด 680–7713) โดย**ไม่มีจุดเช็ค preference ของผู้รับเลยแม้แต่จุดเดียว** — ทุก type ที่ trigger เงื่อนไขตรงจะ insert แถวแจ้งเตือนเสมอ ไม่มีทางให้ผู้ใช้ปิดหมวดใดหมวดหนึ่งได้เลยในปัจจุบัน

Requirements:

**1. กำหนด 6 หมวดหมู่ที่ผู้ใช้เปิด/ปิดได้ (mapping จาก 24 `NotificationType` ที่มีจริงในโค้ดตอนนี้)**
- **Likes**: `likeDrop`, `likePop`, `clubPostLike`, `redrop` — **[แก้ไขโดย Coding ก่อนเริ่มเขียนโค้ด, 2026-08-24]** ตรวจ mapping ซ้ำตอนไล่ trigger function จริงใน `schema.sql` พบว่า `redrop` หลุดไม่ถูกจัดเข้าหมวดไหนเลยใน draft แรก (รวม type ได้แค่ 23/24 ตัว ไม่ใช่ 24) — ตัดสินใจรวม `redrop` เข้าหมวด Likes (ทั้งคู่เป็น "engagement เบาๆ ต่อเนื้อหา" มิเรอร์รูปแบบที่แอปอื่นมักรวม Like+Repost ไว้ด้วยกัน) แทนที่จะเพิ่มหมวดที่ 7 ซึ่งขัดกับสโคปที่ Product ล็อกไว้ (6 หมวด) — คอลัมน์ DB ยังชื่อ `likes_enabled` เดิม ไม่เปลี่ยน
- **Comments & Mentions**: `commentDrop`, `commentPop`, `clubPostComment`, `mentionDrop`, `mentionClubPost`
- **Follows**: `follow`, `followRequest`, `followRequestAccepted`
- **Messages**: `messageRequest` (ตอนนี้ไม่มี notification type สำหรับ "ข้อความใหม่ในแชทที่เปิดอยู่แล้ว" เลยในระบบ — unread badge ของ Chat ไม่ใช่ notification row แยก จึงมีแค่ `messageRequest` ในหมวดนี้)
- **Club**: `clubJoinRequest`, `clubJoinApproved` (เฉพาะ lifecycle ของการขอ/ได้รับอนุมัติเข้า Club — Like/Comment ของ Club post ถูกจัดไปหมวด Likes/Comments แล้วด้านบน ป้องกันไม่ให้ type เดียวอยู่ใน toggle 2 อันพร้อมกัน ซึ่งจะสร้างความสับสนว่า "ปิดอันไหนถึงจะปิดจริง")
- **System**: `system` (WYN-043)

**2. Type ที่ตั้งใจไม่รวมอยู่ใน Settings นี้ (ยังคงส่งเสมอ ไม่มี toggle ให้ปิด)**
- `moderationWarning`/`moderationContentRemoved`/`appealApproved`/`appealRejected` — เป็นข้อมูลสถานะบัญชี/ความปลอดภัยที่ผู้ใช้ต้องรู้เสมอ (เช่น เนื้อหาถูกลบ/บัญชีโดนคำเตือน) ไม่ควรให้ปิดได้ ไม่มีฐานอำนาจจาก Master Spec ให้ทำเป็น opt-out ได้ และเสี่ยงเรื่อง safety หากผู้ใช้พลาดไม่เห็นการแจ้งเตือนที่มีผลต่อบัญชีตัวเอง
- `newOrder`/`orderShipped`/`orderCancelled`/`orderRefunded` (ZOKY) — Bottom Nav tab "ZOKY" ถูกถอดออกไปแล้วตั้งแต่ WYN-024 (Product Direction 2026-08-22 ยืนยัน WYN Shop/Marketplace ยังไม่เปิดใน V1.0 เลื่อนไป V2) ฟีเจอร์นี้ผู้ใช้ WYN Social ปกติเข้าไม่ถึงอยู่แล้วตอนนี้ อยู่นอกสโคป V1.0.0 ทั้งหมด ไม่รวมเข้ามาใน Settings screen
- **Trending/Top 100** (ระบุใน Master Spec section 21 เป็นตัวอย่างหมวดหนึ่งด้วย) — ยังไม่รวม เพราะ**ไม่มี notification type สำหรับเรื่องนี้อยู่จริงในระบบเลย** (WYN-043 เลื่อนออกไปแล้วเพราะไม่มี snapshot/diff mechanism + cron infrastructure) ใส่ toggle ที่ไม่มีอะไรให้ปิดจริงจะสร้างความเข้าใจผิดกับผู้ใช้ — ต้องรอ "Trending/Top 100 Notification Engine" (task ที่ WYN-043 เสนอไว้) เกิดขึ้นก่อน ค่อยเพิ่ม toggle นี้ทีหลัง

**3. Data model**: ต้องมีที่เก็บสถานะเปิด/ปิดต่อผู้ใช้ต่อหมวด (6 boolean) ที่ persist จริง ไม่ใช่แค่ local state ในแอป — รายละเอียด schema (ตารางใหม่ vs คอลัมน์ใน `profiles`) ให้ AI Design/AI Coding ตัดสินใจ แต่มีเงื่อนไขบังคับ 2 ข้อ:
   - **ค่าเริ่มต้นคือ "เปิดทั้งหมด" (opt-out model)** — ผู้ใช้เดิมที่ยังไม่เคยตั้งค่าต้องได้รับพฤติกรรมเดิมทุกประการ (ไม่มีอะไรหายไปโดยไม่ได้ตั้งใจ) — แนะนำให้ค่า "ไม่มีแถว/ไม่มีค่า" หมายถึง "เปิด" (`coalesce(..., true)`) แทนการรัน backfill migration ใส่ทุก row ให้ profiles ที่มีอยู่แล้วทุกบัญชี
   - ต้องมี unique constraint/mechanism กันไม่ให้ 1 ผู้ใช้มีมากกว่า 1 แถว config (ถ้าเลือกออกแบบเป็นตารางแยก)

**4. จุดบังคับใช้ (enforcement)**: ทุก trigger function ที่ insert เข้า `public.notifications` (10+ ฟังก์ชันตาม Problem) ต้องเช็ค preference ของ `recipient_id` สำหรับหมวดที่ type นั้นสังกัดอยู่ **ก่อน** insert — ถ้าปิดอยู่ ให้ skip การ insert แบบเงียบๆ ไม่ error กลับไปหา actor (มิเรอร์ pattern "เกินโควตาแล้ว no-op เงียบๆ" ของ WYN-038's rate-limit) แนะนำสร้าง helper function กลาง เช่น `internal.notification_category_enabled(p_recipient_id uuid, p_category text)` ให้ทุก trigger เรียกจุดเดียว (มิเรอร์ pattern ที่ `internal.is_blocked_either_way()`/`internal.is_drop_deleted()` ทำมาแล้วในหลาย task ก่อนหน้า) แทนที่จะเขียนเงื่อนไขซ้ำ 24 ครั้งกระจายทั่วไฟล์

**5. UI**: `SettingsScreen` (`app/lib/features/settings/presentation/settings_screen.dart`) เพิ่ม section ใหม่ "การแจ้งเตือน" (ตามรูปแบบ incremental ที่ตั้งใจไว้เดิม — ดู doc comment ของไฟล์นี้เอง "Each round adds only the one section it actually needs") มี entry เดียวเปิดหน้าใหม่ `NotificationSettingsScreen` ที่มี `SwitchListTile` 6 อัน (1 ต่อหมวด) พร้อม label ภาษาไทยที่สื่อความหมายชัดเจน ไม่ต้องมี master switch "ปิดทั้งหมด" ในรอบนี้ (ลดสโคป — ผู้ใช้ปิดทีละหมวดได้อยู่แล้ว)

Acceptance Criteria:
- [ ] ผู้ใช้ A ปิด "Likes" → ผู้ใช้ B กด Like Drop ของ A → A ไม่เห็นแถวแจ้งเตือนใหม่ในหน้า Notification (แถวไม่ถูก insert เลย ไม่ใช่แค่ซ่อนที่ client)
- [ ] ผู้ใช้ A ปิด "Likes" เท่านั้น (หมวดอื่นเปิดปกติ) → ผู้ใช้ B Follow/Comment/ReDrop A → A ยังได้รับแจ้งเตือนหมวดอื่นตามปกติ ไม่กระทบข้ามหมวด
- [ ] บัญชีที่ไม่เคยเปิดหน้า Notification Settings เลย (ไม่มีการตั้งค่าเอง) ต้องยังได้รับการแจ้งเตือนทุกหมวดเหมือนพฤติกรรมก่อนมี task นี้ (ค่าเริ่มต้น = เปิดทั้งหมด, ไม่มี regression กับ 665 เคสทดสอบเดิม/ไม่มี cross-task regression กับ 15 SQL suite เดิม)
- [ ] Moderation/Appeal notification (4 types) ยังส่งเสมอไม่ว่าจะตั้งค่าอะไรก็ตาม (ไม่มี toggle ให้ปิด ตรวจสอบว่าไม่มีช่องโหว่ปิดได้ผ่านทางอ้อม)
- [ ] เปิดหน้า Notification Settings → toggle แล้วปิดแอป/เปิดใหม่ → ค่าที่ตั้งไว้ยัง persist ถูกต้อง (ไม่ reset)
- [ ] Regression เต็มชุด: notification type เดิมทั้งหมดที่ "เปิด" อยู่ (ค่า default) ยังทำงานเหมือนเดิมทุกจุด — ไม่มี recipient คนไหนขาดการแจ้งเตือนที่ควรได้รับไปโดยไม่ได้ตั้งใจ

Dependencies: WYN-012 (Notification foundation), WYN-043 (24 notification type ปัจจุบันทั้งหมด, `internal.current_platform_role()` precedent), WYN-027 (`internal.is_blocked_either_way()` — pattern อ้างอิงสำหรับ helper function กลาง), WYN-045 (Settings screen เต็มรูปแบบ — งานนี้เพิ่มแค่ section เดียวไม่ทำทับซ้อน)

Priority: P1 (net-new capability ตาม roadmap Phase 5, ไม่ใช่ bug fix — แต่ enforcement ต้องแตะ trigger function 10+ ตัวที่ผ่าน production-integration แล้ว ต้องระวัง regression สูงกว่า WYN-043 ที่แค่เพิ่ม type ใหม่)

Risks:
- **Blast radius กว้างกว่า WYN-043 มาก** — WYN-043 แค่เพิ่ม type ใหม่ 1-2 ตัวไม่แตะของเดิม แต่ task นี้ต้องแก้ trigger function เดิม 10+ ตัวที่ notification type ทั้ง 20 ตัวที่มีอยู่แล้วพึ่งพาอยู่ — ความเสี่ยง regression สูง ต้องรัน SQL regression suite ทั้ง 15+ สคริปต์เดิมซ้ำทุกตัวหลังแก้ ไม่ใช่แค่เขียน suite ใหม่ของ task นี้เพิ่มเฉยๆ
- **ผลกระทบต่อ performance ของทุก insert path**: ทุก trigger ที่เคย insert ตรงๆ ตอนนี้ต้องมี lookup เพิ่ม 1 ครั้งก่อน insert — ควรออกแบบ helper function ให้ index-friendly (unique index บน `user_id` ถ้าเป็นตารางแยก) ไม่ให้กลายเป็น bottleneck โดยเฉพาะจุดที่มี fan-out สูงอย่าง Club post notification
- **ความเสี่ยงด้าน silent data loss ถ้า default ผิด**: ถ้า implementation พลาดให้ "ไม่มีแถว config" หมายถึง "ปิด" แทนที่จะเป็น "เปิด" ผู้ใช้เดิมทุกคนจะหยุดได้รับแจ้งเตือนทันทีโดยไม่รู้ตัว (เงียบกว่าและอันตรายกว่าบั๊ก `redrop` ของ WYN-043 ที่อย่างน้อยยัง error ให้เห็นชัดเจน) — เป็นจุดที่ QA ต้องทดสอบเจาะจงกับ "บัญชีที่ไม่เคยตั้งค่าเลย" ไม่ใช่แค่บัญชีที่เพิ่งเปิด/ปิด toggle เอง

Recommendation: ทำต่อจาก WYN-043 ทันทีในเซสชันเดียวกันตาม pattern ที่ WYN-038→039, WYN-040→041→042 วางไว้ (Phase 4/5 ทำต่อเนื่องในเซสชันเดียวเมื่อ Founder สั่ง "ทำต่อ") — เริ่ม Design จาก data model + helper function ก่อน (จุดที่กระทบกว้างสุด) แล้วค่อยไล่แก้ trigger function ทีละตัวพร้อม regression test กำกับทุกจุดที่แก้ ไม่ทำรวดเดียวแล้วเทสต์ทีเดียวท้ายสุด

Handoff: AI Design — ออกแบบ `NotificationSettingsScreen` (6 `SwitchListTile`, entry point จาก `SettingsScreen`'s "การแจ้งเตือน" section ใหม่) และตัดสินใจ schema เก็บค่า (ตารางใหม่ `notification_settings` แนะนำ เทียบกับเพิ่ม 6 คอลัมน์ใน `profiles`) พร้อม default-enabled semantics ตามข้อ 3 ที่ล็อกไว้ข้างต้น — ยืนยัน mapping type→หมวดหมู่ 6 กลุ่มตามข้อ 1 ตรงกับที่ AI Coding จะ implement จริงทุกจุด

## Coding Output (2026-08-24)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-043 ท้ายไฟล์, ส่วน "WYN-044: Notification Settings"): ตาราง `notification_settings` ใหม่ (`user_id` primary key อ้าง `profiles`, 6 boolean คอลัมน์ default `true` ทั้งหมด) RLS จำกัดเจ้าของแถวเท่านั้น (SELECT/INSERT/UPDATE) มิเรอร์ `drop_drafts` (WYN-036) เป๊ะ — helper function ใหม่ `internal.notification_category_enabled(p_recipient_id, p_category)` (`security definer`, `stable`) คืน `coalesce(<คอลัมน์ตาม category>, true)` มิเรอร์ pattern `internal.is_blocked_either_way()`/`internal.is_drop_deleted()` — RPC ใหม่ `public.set_notification_category_enabled(p_category, p_enabled)` (`security definer`) upsert เปลี่ยนแค่ 1 คอลัมน์ที่ระบุ ไม่แตะอีก 5 คอลัมน์ ปฏิเสธ category ที่ไม่รู้จักด้วย `raise exception` — **redefine ฟังก์ชัน trigger เดิม 15 ตัว + `accept_follow_request()`/`get_or_create_conversation()`/`send_system_notification()` ผ่าน `create or replace function`** (ตำแหน่งท้ายไฟล์ "wins" ตาม pattern เดิมของโปรเจกต์ที่ RLS policy history ของ `drops` ใช้อยู่แล้วข้าม WYN-027/037/039) เพิ่มแค่เงื่อนไข `internal.notification_category_enabled(...)` ก่อน insert แต่ละจุด ไม่แตะ logic อื่นเลย — `notify_club_join_request()` (fan-out แบบ `insert...select`) เพิ่มเงื่อนไขใน `where` clause แทน `if` เพราะมีหลาย recipient ต่อ 1 event

**ช่องว่างที่พบเองก่อนเริ่มเขียนโค้ด (ไม่ใช่ QA พบ)**: ตอนไล่ map 24 notification type เข้า 6 หมวดจริงจาก schema.sql พบว่า Product spec ฉบับแรกนับได้แค่ 23/24 type — **`redrop` หลุดไม่มีหมวดเลย** แก้โดยย้อนกลับไปแก้ทั้ง Product spec (Requirement 1) และ Design spec (Screen 2's ตาราง แถว Likes) ให้รวม `redrop` เข้าหมวด Likes (คอลัมน์ `likes_enabled` เดิม ไม่เพิ่มหมวดที่ 7) ก่อนเขียน SQL จริง — ดูรายละเอียดที่ note "[แก้ไขโดย Coding...]" ใน 2 ไฟล์นั้น

**SQL test ใหม่** (`supabase/tests/wyn_044_notification_settings_test.sh`, มิเรอร์ harness ของ `wyn_043_notification_types_test.sh`) — 20 checks ครอบ: บัญชีที่ไม่เคยตั้งค่าเลย (ไม่มีแถว) ยังได้รับแจ้งเตือนปกติ + ไม่มีแถวถูกสร้างขึ้นเองจากการแค่ notify (CHECK1), ปิด "likes" บล็อก `redrop` แต่ไม่กระทบ `comment_drop` (CHECK2-3), `set_notification_category_enabled` แก้แค่คอลัมน์เดียวจริง (CHECK4), `follow_request` gate ด้วย follows (CHECK5), `club_join_request`'s fan-out gate เป็นรายคนจริง (เจ้าของปิดไม่ได้รับ แต่ Admin อีกคนที่เปิดอยู่ยังได้รับ) (CHECK6), `message_request` gate ด้วย messages (CHECK7), `send_system_notification` ปิดแล้วยัง insert สำเร็จแบบไม่ error กลับ (CHECK8), category ที่ไม่รู้จักถูกปฏิเสธ (CHECK9), RLS ของ `notification_settings` เอง (คนอื่นอ่าน/แก้ไม่ได้) (CHECK10-11) — **20/20 PASS** — รันซ้ำครบทั้ง 16 สคริปต์เดิม (`wyn_021` ถึง `wyn_043`) **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน

**Flutter**: `notification_settings.dart` ใหม่ (`NotificationCategory` enum 6 ค่า + `wireValue` extension ตรงกับ SQL, `NotificationSettings` class มี `allEnabled` default, `operator[]`, `copyWith`, `fromMap`) — `notification_settings_repository.dart` ใหม่ (`fetchSettings()` คืน `allEnabled` เมื่อไม่มีแถว มิเรอร์ DB contract ที่ client, `updateCategory()` เรียก RPC) — `notification_settings_screen.dart` ใหม่ (`NotificationSettingsScreen`, 6 `SwitchListTile` ตาม Design spec's ตาราง, fail-open เมื่อโหลดพลาด, `Set<NotificationCategory> _saving` แยกสถานะ toggling ต่อแถวไม่ใช่ `bool` เดียว ตามที่ Design ระบุ) — `settings_screen.dart` เพิ่ม section "การแจ้งเตือน" (1 `ListTile`) ระหว่าง "ความเป็นส่วนตัว" กับ "ความปลอดภัย" ตามตำแหน่งที่ Design กำหนด

`flutter analyze` **0 issues**, `flutter test` **676/676 PASS** (665 baseline + 11 ใหม่: `notification_settings_test.dart` 6 เคส, `notification_settings_screen_test.dart` 5 เคส, `settings_screen_test.dart` +1 เคส) — ไม่มี regression กับเทสต์เดิมจุดใดเลย

**Known Issues**: ไม่มี — ทุก Acceptance Criteria ของ Product spec ตรวจสอบผ่านจาก SQL/Flutter test จริง

Handoff: AI QA & Security — ตรวจเน้นที่ (1) semantics "ไม่มีแถว = เปิด" ยังคงจริงทั้ง DB (`coalesce`) และ client (`fetchSettings` คืน `allEnabled`) ไม่มีจุดไหนพลาดกลายเป็น default ปิด (2) 15+1 จุด insert ที่ควรถูก gate ครบจริงตาม mapping รวม `redrop` ที่ Coding เพิ่งแก้ไข (3) Moderation/Appeal (4 types)/Order (4 types) ต้องไม่ถูก gate เลยแม้แต่จุดเดียว (4) RLS ของ `notification_settings` เอง (5) `club_join_request`'s fan-out gate เป็นรายคนจริงไม่ใช่ all-or-nothing

## Independent QA (2026-08-24)

Feature: WYN-044 Notification Settings — เปิด/ปิดการแจ้งเตือนเป็นรายหมวดหมู่ (6 หมวด)

Environment: local Postgres 16 (throwaway DB สดใหม่ต่อการรัน, role `authenticated` จริงไม่ใช่ superuser) + Flutter 3.47.1 stable (ติดตั้งเองในรอบนี้ sandbox ไม่มี SDK มาก่อน มิเรอร์ WYN-038's QA) — อ่าน diff ทั้งหมด (`git diff`) แบบ adversarial ก่อน แล้วรัน test ทุกชุดเองอิสระ ไม่เชื่อตัวเลขที่ Coding รายงานเฉยๆ

Test Cases:
1. รัน `supabase/tests/wyn_044_notification_settings_test.sh` เองอิสระ ครบ 20 checks
2. รันซ้ำทั้ง 16 สคริปต์เดิม (`wyn_021` ถึง `wyn_043`) ทุกตัว — ยืนยันไม่มี cross-task regression
3. รัน `check_schema_ordering.py` — ยืนยันไม่มี forward reference
4. รัน `flutter analyze`/`flutter test` เองอิสระทั้งชุด (ไม่ใช่แค่ diff ใหม่)
5. อ่าน diff `supabase/schema.sql` ทั้งหมดบรรทัดต่อบรรทัด ยืนยันว่า Moderation/Appeal/Order trigger function ทั้ง 8 ตัวไม่ถูกแตะเลยแม้แต่บรรทัดเดียว (`git diff | grep` ยืนยัน 0 matches)
6. Adversarial probe เพิ่มเติมนอกเหนือ regression suite (SQL ตรงผ่าน psql, ไม่ผ่าน RPC เท่านั้น):
   - `set_notification_category_enabled('likes', null)` — ต้องถูกปฏิเสธ ไม่ทำให้คอลัมน์กลายเป็น NULL (constraint ปกป้อง semantics "ไม่มีแถว/ไม่มีค่า = เปิด" ไม่ให้เพี้ยนเป็น NULL ที่ตีความผิดได้)
   - `set_notification_category_enabled('LIKES', false)` (ตัวพิมพ์ใหญ่) — ต้องถูกปฏิเสธ ไม่ match แบบ case-insensitive โดยไม่ตั้งใจ
   - insert ตรงเข้า `notification_settings` โดยระบุ `user_id` เป็นของคนอื่น (ไม่ใช่ `auth.uid()` ตัวเอง) ผ่าน role `authenticated` ตรงๆ (ไม่ผ่าน RPC) — ต้องถูก RLS ปฏิเสธ ไม่มีทาง insert แทนคนอื่นได้
7. ตรวจสอบเพิ่มเติมนอกเหนือ Product's Acceptance Criteria: มี Supabase Edge Function `supabase/functions/send-push-notification/` (WYN-016) ที่ทำงานผ่าน **Database Webhook บน `notifications` INSERT** จริง (ยืนยันจาก comment ใน `index.ts` เอง) — เพราะ WYN-044 gate อยู่ที่จุด insert ตรงๆ (ไม่ใช่แค่ query filter ฝั่ง read) การปิดหมวดใดหมวดหนึ่งจึงตัด **ทั้ง in-app notification list และ push notification (FCM)** พร้อมกันโดยอัตโนมัติ ไม่ต้องแก้ Edge Function เพิ่มเลย — เป็นข้อดีที่ยืนยันแล้วว่าไม่มี bypass path ที่สองหลุดรอด

Passed: 1, 2, 3, 4, 5, 6 (ทั้ง 3 adversarial probe), 7 — ทุกข้อ
Failed: ไม่มี

Severity: N/A (ไม่พบบั๊ก)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบช่องโหว่ — ตรวจสอบเฉพาะเจาะจงกับความเสี่ยงที่ Product ระบุไว้ล่วงหน้า ("silent data loss" จาก default ผิด) ยืนยันว่าไม่เกิดขึ้นจริงทั้ง DB layer (`coalesce(..., true)`) และ client layer (`fetchSettings()`/fail-open) — RLS ของ `notification_settings` ป้องกันการอ่าน/เขียนข้ามบัญชีได้จริง (ยืนยันด้วย probe ตรง ไม่ใช่แค่อ่านโค้ด) — RPC ปฏิเสธ input ผิดปกติ (NULL, category พิมพ์ผิด/ตัวพิมพ์ผิด) โดยไม่ทำให้ข้อมูลเพี้ยน

Recommendation: อนุมัติ — งานนี้ implement ตรงตาม Product/Design spec ทุกข้อ ไม่มี regression กับ 16 สคริปต์ SQL เดิมหรือ 665 เทสต์ Flutter เดิม เพิ่ม coverage ใหม่ 20 SQL checks + 11 Flutter test เคสของตัวเอง ครอบทั้ง functional/regression/security ตามที่ Product's Risks ระบุไว้ล่วงหน้าครบทุกข้อ

Final Status: **PASS**
