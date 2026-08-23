# Product Task — WYN-044

Status: backlog
Owner: AI Product Manager

Feature: Notification Settings — เปิด/ปิดการแจ้งเตือนรายประเภท

Goal: task ที่สองของ Phase 5 (Notification & Settings Expansion) ต่อจาก WYN-043 — ปิด gap ตาม Master Spec section 21 ("Notification Settings — ผู้ใช้เปิด/ปิดได้เป็นรายประเภท เช่น Likes, Comments, Follows, Messages, Club, Trending, System") ที่ยังไม่มีอยู่เลยในระบบตอนนี้ — ปัจจุบันผู้ใช้ไม่มีทางปิดการแจ้งเตือนประเภทใดๆ ได้เลยแม้แต่ประเภทเดียว ทุก `notify_*` trigger insert แถวเสมอไม่มีเงื่อนไข

Target User: ผู้ใช้ WYN ทุกคนที่ต้องการลดความถี่การแจ้งเตือนบางประเภท (เช่น ปิด Comment notification แต่ยังเปิด Follow notification) โดยไม่ต้องปิดการแจ้งเตือนทั้งหมด

Problem: ยืนยันจากการอ่านโค้ดจริง — schema.sql มี `notifications` table + trigger function 13 ตัวที่ insert แถวแบบไม่มีเงื่อนไขใดๆ เกี่ยวกับ preference ของผู้รับเลย (`notify_drop_like`, `notify_pop_like`, `notify_drop_comment`, `notify_pop_comment`, `notify_follow`, `notify_club_join_request`, `notify_club_join_approved`, `notify_club_post_like`, `notify_club_post_comment`, `notify_drop_mention`, `notify_club_post_mention`, `notify_redrop`, `internal.notify_follow_request`) บวก 2 RPC ที่ insert ตรง (`accept_follow_request()`'s `follow_request_accepted` insert, `send_system_notification()` จาก WYN-043) — ไม่มีตาราง/คอลัมน์ preference ใดๆ เลยในสคีมาทั้งหมด

Requirements:

**1. ตาราง `notification_settings` ใหม่ — เก็บ preference รายผู้ใช้ 7 หมวดตาม Master Spec section 21 เป๊ะ**
- คอลัมน์ boolean 7 ตัว ตรงชื่อ Master Spec: `likes`, `comments`, `follows`, `messages`, `club`, `trending`, `system` — ทุกตัว `not null default true` (default = เปิดหมด, opt-out model ไม่ใช่ opt-in — ผู้ใช้ใหม่ไม่ต้องตั้งค่าอะไรก็ได้รับการแจ้งเตือนปกติเหมือนวันนี้)
- ไม่มีแถวสำหรับผู้ใช้จนกว่าจะเปิดหน้า Settings ครั้งแรกแล้ว toggle อย่างน้อย 1 ครั้ง (lazy row creation ผ่าน upsert จาก client ตรงๆ — ไม่ต้องมี RPC/trigger สร้างแถว auto ตอน signup เพื่อลด blast radius ไม่แตะ `handle_new_user()` เดิม) — **ไม่มีแถว = ทุกหมวดถือว่าเปิดอยู่** (ค่า default เดียวกับที่ column default ระบุ) ต้องมี helper function กลาง (`internal.notification_enabled(p_user_id uuid, p_category text)`) ที่ trigger ทุกตัวเรียกใช้แทนการ query ตรง เพื่อรับประกัน "ไม่มีแถว = true" สอดคล้องกันทุกจุด ไม่ใช่ต่างจุดต่างเขียน logic เอง
- RLS: จำกัดแค่เจ้าของแถวเท่านั้น (`auth.uid() = user_id`) ทั้ง select/insert/update — ไม่มี policy ให้เห็น/แก้ preference ของคนอื่นเลย (คนอื่นไม่มีความจำเป็นต้องรู้ว่าใครปิดการแจ้งเตือนประเภทไหน)

**2. Gate การ insert notification ทุกจุดด้วย preference ของ "ผู้รับ" (`recipient_id`) ผ่าน `internal.notification_enabled()`**
- แม็ปประเภท notification ที่มีอยู่จริง 21 ตัวเข้า 7 หมวดของ Master Spec ตามการตัดสินใจนี้ (ทำเองได้ตามอำนาจ Product ไม่ใช่ Major Architecture — Master Spec ให้แค่ตัวอย่างหมวดกว้างๆ ไม่ได้ระบุ mapping ละเอียดถึงระดับ type):
  | หมวด (Master Spec) | notification type ที่ gate ด้วยหมวดนี้ | เหตุผล |
  |---|---|---|
  | `likes` | `like_drop`, `like_pop`, `redrop` | ReDrop เป็น engagement action ที่ใกล้เคียง Like มากที่สุด (repost แบบ one-tap ไม่มีข้อความ) — Master Spec section 20 จัดกลุ่ม ReDrop ไว้ใน "Social" เดียวกับ Like อยู่แล้ว ไม่มีหมวดแยกสำหรับ ReDrop โดยเฉพาะใน section 21 |
  | `comments` | `comment_drop`, `comment_pop`, `mention_drop` | Mention บน Drop เกิดจากการพิมพ์ในแคปชัน/คอมเมนต์ ใกล้เคียง Comment มากที่สุด — section 20 จัดกลุ่ม Mention ไว้ใน "Social" เดียวกับ Comment เช่นกัน ไม่มีหมวด Mention แยก |
  | `follows` | `follow`, `follow_request`, `follow_request_accepted` | ตรงชื่อหมวดตรงๆ ไม่ต้องตีความ |
  | `messages` | `message_request` | เป็น notification type เดียวที่เกี่ยวกับ Chat ที่มีอยู่จริงในตาราง `notifications` ตอนนี้ — ข้อความใหม่ใน 1:1 Chat ของจริง (WYN-031) ไม่ได้แจ้งผ่านระบบ Notification bell เลย (ใช้ unread-count + realtime ของตัวเอง) จึงไม่มีอะไรให้ gate เพิ่มในหมวดนี้ |
  | `club` | `club_join_request`, `club_join_approved`, `club_post_like`, `club_post_comment`, `mention_club_post` | ทุกประเภทที่เกี่ยวกับ Club ถูกจัดเป็นหมวดเดียวตาม section 20 ("Club: Club Post, Club Mention, Club Announcement, Join Request") โดยไม่แยกย่อยเป็น Like/Comment ซ้ำกับหมวด Drop/Pop ด้านบน — ผู้ใช้ที่อยากปิด "การแจ้งเตือนทุกอย่างจาก Club" ควรทำได้ด้วย toggle เดียว ไม่ต้องไล่ปิดทีละ sub-type |
  | `trending` | *(ยังไม่มี producer จริง)* | Trending/Top 100 notification ถูกเลื่อนสโคปออกจาก WYN-043 แล้ว (ไม่มี cron/snapshot infra) — เก็บคอลัมน์นี้ไว้ล่วงหน้าตาม Master Spec section 21 ที่ระบุชื่อหมวดตรงๆ เพื่อไม่ต้อง migrate schema เพิ่มตอน "Trending Notification Engine" task ในอนาคตทำจริง (มิเรอร์แนวทางเดียวกับที่ WYN-032 เพิ่ม `message_request` type ล่วงหน้าก่อน WYN-043 ใช้งานจริง) — **ตอนนี้ toggle นี้ไม่มีผลอะไรกับระบบเลยเพราะไม่มี insert จุดไหนอ้างถึง** ต้องบันทึกเป็น Known Gap ให้ QA ทราบตรงๆ ไม่ใช่บั๊ก |
  | `system` | `system` | ตรงชื่อหมวดตรงๆ — **หมายเหตุความเสี่ยง**: Master Spec section 20 อธิบาย System ว่าคือ "Security, Policy, Announcement" ซึ่งบางเนื้อหาอาจสำคัญมาก (เช่น แจ้งเตือนความปลอดภัยบัญชี) แต่ section 21 ระบุชัดเจนว่า System เป็นหนึ่งใน 7 หมวดที่ผู้ใช้ "เปิด/ปิดได้" — ทำตาม Master Spec ตรงๆ ตามที่ Founder เขียนไว้เอง ไม่ตีความเพิ่มเป็นข้อยกเว้น แต่บันทึกไว้ใน Risks ให้ Founder ทราบชัดเจน |
- **ไม่ gate 2 กลุ่มนี้โดยเจตนา (ตัดสินใจ Product, ไม่ใช่ bug/ไม่ใช่ oversight)**:
  1. `moderation_warning`/`moderation_content_removed`/`appeal_approved`/`appeal_rejected` — แจ้งเตือนเกี่ยวกับสถานะบัญชี/ผลการฝ่าฝืนกติกา/ผลอุทธรณ์ ไม่มีอยู่ในหมวดใดของ Master Spec section 20/21 เลย (ไม่ใช่ Social/Chat/Club/Discovery/System ทั่วไป) และเป็นข้อมูลที่ผู้ใช้ต้องรับรู้เสมอเพื่อรักษาความปลอดภัย/สิทธิ์ในการอุทธรณ์ของตัวเอง — ปล่อยให้ปิดได้จะเปิดช่องให้ผู้ใช้ "ซ่อน" หลักฐานการฝ่าฝืนกติกาจากตัวเอง ขัดกับเป้าหมายของระบบ Safety (section 22-26) โดยตรง — คงพฤติกรรมเดิม (insert เสมอไม่มีเงื่อนไข) เหมือนก่อน task นี้ทุกประการ
  2. `new_order`/`order_shipped`/`order_cancelled`/`order_refunded` (ZOKY) — ZOKY/Marketplace ถูกถอดออกจาก WYN App's Bottom Nav ไปแล้วตั้งแต่ WYN-024 (พักไว้ ไม่ใช่ V1.0.0) ไม่มีผู้ใช้จริงคนไหนสร้าง order ผ่าน WYN App ได้อีกต่อไป — อยู่นอกสโคป WYN-044 โดยสมบูรณ์ ไม่แตะ ไม่เพิ่มเข้า mapping ใดๆ

**3. หน้าจอ `NotificationSettingsScreen` ใหม่ — 7 toggle ตรงตาม 7 หมวด**
- แสดงชื่อหมวดภาษาไทยที่เข้าใจง่าย (เช่น "ถูกใจ", "คอมเมนต์", "ผู้ติดตาม", "ข้อความ", "Club", "กำลังนิยม", "ระบบ") ไม่ใช่ raw column name ภาษาอังกฤษ
- Toggle เปลี่ยนค่าทันที (optimistic update + upsert ไป `notification_settings` โดยตรงจาก client — ไม่ต้องมี RPC เพราะเป็นแค่ toggle boolean ของแถวตัวเอง RLS อนุญาตอยู่แล้ว ไม่มี business logic ซับซ้อนเหมือน `create_poll_drop()`/`edit_drop()`)
- **จุดเข้าหน้านี้ (ตัดสินใจ Product เพราะ WYN-045 "Settings screen เต็มรูปแบบ" ยังไม่ถูกสร้าง)**: เพิ่มไอคอน settings (⚙️) ใน AppBar ของ `NotificationListScreen` (WYN-012) เปิดหน้านี้ตรงๆ เป็น standalone route ชั่วคราว — เมื่อ WYN-045 สร้าง Settings screen รวมจริงแล้ว ให้ AI Design/Coding ของ WYN-045 ย้ายจุดเข้าไปอยู่ใต้เมนู "Notifications" ของ Settings รวม แล้วเอาไอคอนนี้ออกจาก `NotificationListScreen` (ไม่ต้องสร้างหน้า Settings เปล่าๆ ล่วงหน้าตอนนี้เพราะยังไม่มีเนื้อหาอื่นให้ใส่)

Acceptance Criteria:
- [ ] ผู้ใช้เปิดหน้า Notification Settings ครั้งแรก (ไม่เคยมีแถวใน `notification_settings`) เห็นทุก toggle เปิดอยู่ (default true ทุกหมวด)
- [ ] ผู้ใช้ปิด toggle "คอมเมนต์" → มีคนอื่นคอมเมนต์ Drop ของผู้ใช้ → ไม่มีแถว `notifications` type `comment_drop` ถูก insert เลย (ตรวจตรงจาก DB ไม่ใช่แค่ UI ไม่แสดง)
- [ ] ผู้ใช้ปิด toggle "คอมเมนต์" แต่ toggle อื่นยังเปิดอยู่ → มีคนอื่น Like Drop เดียวกัน → แถว `notifications` type `like_drop` ยัง insert ปกติ (พิสูจน์ว่า gate แยกหมวดจริง ไม่ใช่ปิดทั้งหมดพร้อมกัน)
- [ ] ปิด toggle "Club" → มีคนคอมเมนต์ใน Club Post ของผู้ใช้ (`club_post_comment`) → ไม่ insert — พิสูจน์ว่า mapping "ทุก Club type รวมหมวดเดียว" ทำงานจริง ไม่ใช่แค่ Like/Comment ปกติของ Drop/Pop
- [ ] ปิด toggle "ผู้ติดตาม" → มีคน Follow → ไม่มีแถว `notifications` type `follow` ถูก insert
- [ ] เปิด toggle กลับมาใหม่ → เหตุการณ์เดิมเกิดซ้ำ → กลับมา insert ปกติ (พิสูจน์ two-way ไม่ใช่แค่ปิดได้ทางเดียว)
- [ ] บัญชี Moderator/Admin ส่ง `apply_moderation_action()`/`decide_appeal()` ให้ผู้ใช้ที่ปิด toggle ทุกหมวดหมดแล้ว → แถว moderation/appeal ยัง insert ปกติเสมอ (ไม่ถูก gate เลยตามที่ตั้งใจ)
- [ ] Regression เต็มชุด: notification type เดิมทั้งหมดที่ "ไม่ถูก gate" (moderation ×2, appeal ×2, order ×4) ยัง insert ปกติทุกกรณีไม่มีการเปลี่ยนแปลงพฤติกรรม
- [ ] ผู้ใช้ A ไม่มีทางเห็น/แก้ไข `notification_settings` ของผู้ใช้ B ได้เลยไม่ว่าจะพยายามด้วยวิธีใด (RLS probe)

Dependencies: WYN-012 (Notification foundation), WYN-043 (notification type ล่าสุดที่ผ่าน QA, `system` type ที่ต้อง gate), WYN-039 (`follow_request`/`follow_request_accepted`), WYN-015 (Club notification types), WYN-021 (mention types), WYN-034 (`redrop`) — ทุกจุดที่ต้อง gate ต้องมีอยู่แล้วครบก่อนหน้านี้

Priority: P2 — เป็น net-new capability ไม่ใช่บั๊ก แต่ปิด gap ที่ Master Spec ระบุไว้ชัดเจนและ WYN-043 (task แรกของ Phase 5) เพิ่งเสร็จ ทำต่อเนื่องตาม roadmap ได้ทันที

Risks:
- **`system` toggle ปิดได้ตาม Master Spec ตรงๆ แม้เนื้อหาอาจรวม Security notice** — ถ้า Founder ต้องการแยก "Security" ออกมาเป็นหมวดที่ปิดไม่ได้ในอนาคต (ต่างจาก Policy/Announcement ทั่วไป) ต้องเพิ่ม notification type ใหม่แยก (เช่น `security_alert`) และปรับ mapping — ไม่ทำเองตอนนี้เพราะ Master Spec ปัจจุบันไม่ได้แยกไว้ และ RPC `send_system_notification()` (WYN-043) ก็เป็น single-type ตาม design เดิม
- **`trending` toggle ยังไม่มีผลจริงกับระบบ** จนกว่าจะมี Trending Notification Engine (เสนอเป็น WYN-04X แยกตาม WYN-043's deployment log's Next Steps) — เก็บ column ไว้ล่วงหน้าตาม Master Spec แต่ QA/Founder ต้องเข้าใจว่าไม่ใช่บั๊กที่ toggle "ไม่ทำอะไร" ตอนนี้
- **Gate ต้องแก้ trigger function ที่มีอยู่แล้ว 13 ตัว + RPC 2 ตัว** — ความเสี่ยงหลักคือ regression ต่อ notification เดิมที่เคย PASS QA มาแล้วทุก task ตั้งแต่ WYN-012 — ต้องรัน SQL regression ทั้ง 16 สคริปต์เดิมซ้ำ (`wyn_021` ถึง `wyn_043`) ยืนยันไม่มีอะไรพังก่อนอนุมัติ

Recommendation: ทำต่อเนื่องตาม roadmap Phase 5 ทันที (Founder อนุมัติให้ทีมทำงานต่อเนื่องอัตโนมัติไว้แล้วตั้งแต่ 2026-08-14 — DECISIONS.md) — ส่งต่อ AI Design ออกแบบ `NotificationSettingsScreen` (7 toggle + entry point จาก NotificationListScreen ตามที่ระบุใน Requirement 3) จากนั้น AI Coding implement gate ทั้ง 13+2 จุดพร้อม SQL regression test ใหม่ แล้วส่ง QA อิสระตรวจ mapping ครบทุกหมวด + regression เต็มชุดตามธรรมเนียมเดิมของโปรเจกต์

Handoff: AI Design — ออกแบบ `NotificationSettingsScreen` (layout รายการ toggle 7 แถว, label ภาษาไทย, ไอคอน settings ใน `NotificationListScreen`'s AppBar) — ไม่ต้องออกแบบหน้า Settings รวมของ WYN-045 ล่วงหน้า เป็นแค่ standalone entry point ชั่วคราวตามที่ Product ระบุไว้ใน Requirement 3
