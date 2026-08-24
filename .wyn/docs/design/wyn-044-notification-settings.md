# Design Spec — WYN-044 (Notification Settings)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-044-notification-settings.md`

## Screen 1 — `SettingsScreen` (แก้ไขไฟล์เดิม, ไม่ใช่หน้าจอใหม่)

Purpose: จุดเข้าถึงเดียวสู่ Notification Settings ตาม incremental-section pattern ที่ไฟล์นี้ตั้งใจไว้เอง (ดู doc comment ของ `SettingsScreen`: "Each round adds only the one section it actually needs")

User Flow: เปิด Settings → เห็น section ใหม่ "การแจ้งเตือน" (วางต่อจาก "ความเป็นส่วนตัว" เดิม ก่อน "ความปลอดภัย" — ลำดับเดิม: ความเป็นส่วนตัว → ความปลอดภัย → เครื่องมือผู้ดูแล เปลี่ยนเป็น: ความเป็นส่วนตัว → **การแจ้งเตือน** → ความปลอดภัย → เครื่องมือผู้ดูแล) → แตะ "ตั้งค่าการแจ้งเตือน" → เปิด `NotificationSettingsScreen`

Components:
- `Padding` + `Text` (titleSmall, `colorScheme.outline`) หัวข้อ section "การแจ้งเตือน" — **โค้ดเดิมเป๊ะ** (ก็อปรูปแบบจาก "ความเป็นส่วนตัว"/"ความปลอดภัย" ที่มีอยู่แล้ว ไม่ต้องคิด style ใหม่)
- `ListTile` เดียว: `leading: Icon(Icons.notifications_none)` (icon เดิมที่ใช้เป็น empty-state ของหน้า Notification list อยู่แล้ว, `notification_list_screen.dart:543` — reuse ไม่คิด icon ใหม่), `title: Text('ตั้งค่าการแจ้งเตือน')`, `trailing: Icon(Icons.chevron_right)`, `onTap` → `Navigator.push` เข้า `NotificationSettingsScreen` (มิเรอร์ `ListTile` ของ "บัญชีที่ถูกบล็อก"/"บัญชีที่ปิดเสียง" เป๊ะทุกจุด)

Interactions: แตะแถวเดียว → เปิดหน้าใหม่ ไม่มี interaction อื่นในหน้านี้

States: ไม่มี state พิเศษ (static entry point)

Responsive Behavior: N/A — mobile-first เท่านั้นตาม DS-008 (ยืนยันแล้วว่า WYN ไม่มีเป้าหมาย tablet/desktop breakpoint จริง ไม่สร้างใหม่ในรอบนี้)

Accessibility: `ListTile` มี tap target มาตรฐาน Material (≥48dp) อยู่แล้วจาก widget เดิม ไม่ต้องปรับ

Design Rules: ไม่มี Rainbow ring/สี พิเศษใดๆ เกี่ยวข้อง (DS-009's 2-point rule ใช้กับ Trending content เท่านั้น ไม่เกี่ยวกับหน้า Settings)

Handoff: AI Coding แก้ `settings_screen.dart` เพิ่ม section + ListTile 1 จุดตามตำแหน่งที่ระบุ ไม่ต้องแก้ widget อื่นในไฟล์

---

## Screen 2 — `NotificationSettingsScreen` (หน้าจอใหม่)

Purpose: ให้ผู้ใช้เปิด/ปิดการแจ้งเตือนได้ 6 หมวดหมู่ตาม Product spec's mapping (Likes/Comments & Mentions/Follows/Messages/Club/System)

User Flow: เข้าจาก `SettingsScreen` → เห็นรายการ 6 แถว toggle พร้อมค่าปัจจุบัน (โหลดจาก server) → แตะ toggle แถวใดแถวหนึ่ง → เปลี่ยนค่าทันที (optimistic) + บันทึกขึ้น server เบื้องหลัง → กลับ (back) เมื่อไหร่ก็ได้ ไม่มีปุ่ม "บันทึก" แยก (auto-save ทันทีที่ toggle มิเรอร์ pattern `_setIsPrivate` ของ `SettingsScreen` เดิมเป๊ะ)

Components:
- `AppBar(title: Text('ตั้งค่าการแจ้งเตือน'))`
- `ListView` มี `SwitchListTile` 6 อัน เรียงตามลำดับนี้ (Social ก่อน จากนั้น Chat/Club แล้วปิดท้าย System — มิเรอร์ลำดับ "Social → Chat → Club → Discovery → System" ที่ Master Spec section 20 ใช้อยู่แล้ว):

| # | หมวด | `secondary` icon | `title` | `subtitle` |
|---|---|---|---|---|
| 1 | Likes | `Icons.favorite_border` (ใช้ทั่วแอปแล้วสำหรับ Like ทุกจุด — `drop_detail_screen.dart`/`club_post_card.dart` ฯลฯ) | "ถูกใจและ ReDrop" | "เมื่อมีคนถูกใจหรือ ReDrop เนื้อหาของคุณ" — **[แก้ไขโดย Coding, 2026-08-24]** เดิม Design เขียนแค่ "ถูกใจ (Like)" แต่ Product แก้ mapping ให้รวม `redrop` เข้าหมวดนี้ด้วยหลังพบว่า type นี้หลุดไม่มีหมวดใน draft แรก (ดู Product spec's Requirement 1) — เปลี่ยน label/subtitle ให้ตรงกับ scope จริง ไม่ต้องเปลี่ยน icon |
| 2 | Comments & Mentions | `Icons.comment_outlined` (reuse จาก `moderation_queue_screen.dart`) | "คอมเมนต์และการกล่าวถึง" | "เมื่อมีคนคอมเมนต์หรือกล่าวถึง (@mention) คุณ" |
| 3 | Follows | `Icons.person_add_alt` (reuse จาก `view_profile_screen.dart`) | "การติดตาม" | "เมื่อมีคนติดตามคุณ หรือขอ/ตอบรับการติดตาม" |
| 4 | Messages | `Icons.mail_outline` (reuse จาก `chat_inbox_screen.dart`/`message_request_list_screen.dart` — ใช้กับ Message Request อยู่แล้วพอดี) | "ข้อความ" | "เมื่อมีคำขอส่งข้อความใหม่" |
| 5 | Club | `Icons.groups_outlined` (reuse ทั่วแอปสำหรับ Club) | "Club" | "เมื่อมีคำขอเข้าร่วมหรือได้รับอนุมัติเข้า Club" |
| 6 | System | `Icons.campaign_outlined` (icon เดียวกับที่ `notification_list_screen.dart` ใช้แสดงแถว System notification อยู่แล้ว — WYN-043) | "ประกาศจากระบบ" | "ประกาศด้านความปลอดภัยหรือนโยบายจากทีมงาน WYN" |

- `CircularProgressIndicator` กลางจอระหว่างโหลดค่าปัจจุบันครั้งแรก

Interactions:
- โหลดหน้าจอ → เรียก `NotificationSettingsRepository.fetchSettings()` ครั้งเดียวตอน `initState` — ถ้าไม่มีแถว config อยู่ใน DB เลย (ผู้ใช้ไม่เคยตั้งค่า) ให้ repository คืนค่า **ทั้ง 6 หมวดเป็น `true` ทั้งหมด** ที่ฝั่ง client ตรง (ไม่ใช่แค่ default ที่ DB เพียงอย่างเดียว — client ต้อง mirror semantics เดียวกันเป๊ะ ป้องกันไม่ให้ UI เพี้ยนจาก DB จริงแม้แต่ตอน loading)
- แตะ `SwitchListTile` ใดๆ → `setState` เปลี่ยนค่าทันที (optimistic, มิเรอร์ `_setIsPrivate` เป๊ะ) → เรียก `updateCategory(category, value)` → ถ้า throw → revert ค่าเดิม + `SnackBar('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง')` (ข้อความเดียวกับที่ `SettingsScreen._setIsPrivate` ใช้อยู่แล้ว เพื่อความสม่ำเสมอของ error copy ทั้งแอป)
- ถ้า `fetchSettings()` เอง throw (โหลดครั้งแรกไม่สำเร็จ) → **fail-open**: แสดงทุก toggle เป็น "เปิด" (ค่า default ปลอดภัยกว่า ไม่เสี่ยง silent-off ตามที่ Product's Risks ระบุไว้) พร้อม `SnackBar` แจ้งว่าโหลดค่าปัจจุบันไม่สำเร็จ ให้ลองรีเฟรชหน้าใหม่ (pull-to-refresh หรือกลับเข้าใหม่) ก่อนเชื่อค่าที่แสดง

States:
- **Loading**: `CircularProgressIndicator` เต็มจอ
- **Loaded (มีค่าที่ตั้งไว้แล้ว)**: 6 toggle แสดงค่าจริงจาก DB
- **Loaded (ไม่เคยตั้งค่ามาก่อน)**: 6 toggle แสดง "เปิด" ทั้งหมด (ค่า default)
- **Toggling**: switch เปลี่ยนทันที (optimistic) — ไม่ disable switch อื่นระหว่างรอ (การ toggle แต่ละแถวเป็น request อิสระต่อกัน ไม่ต้องรอกัน ต่างจาก `_isTogglingPrivate` ที่มีแค่ toggle เดียวในหน้านั้น หน้านี้มี 6 toggle จึงต้อง track สถานะ "กำลังบันทึก" แยกเป็นต่อแถว เช่น `Set<String> _savingCategories` ไม่ใช่ `bool` ตัวเดียว เพื่อไม่ให้แตะแถวหนึ่งแล้วแถวอื่นถูก disable ไปด้วยทั้งที่ไม่เกี่ยวกัน)
- **Error (บันทึกไม่สำเร็จ)**: revert ค่า + `SnackBar`

Responsive Behavior: N/A — เหมือน Screen 1 (mobile-first ตาม DS-008)

Accessibility: `SwitchListTile` ประกาศ label+state ให้ screen reader อัตโนมัติจาก Material widget (title สื่อความหมายชัดเจนอยู่แล้ว ไม่ต้องเพิ่ม `Semantics` wrapper) — สี icon/switch ใช้ theme เดิมทั้งหมด ไม่มีสีใหม่ที่ต้องตรวจ contrast เพิ่ม

Design Rules:
- **ไม่มี master switch "ปิดทั้งหมด"** ตามที่ Product ล็อกสโคปไว้ (ลดความซับซ้อนรอบนี้)
- **ไม่มี Rainbow ring/สี พิเศษ** เกี่ยวข้องกับหน้านี้เลย (ไม่ใช่ content ที่ Trending ตัดสิน)
- Layout/spacing ใช้ `WynSpacing` tokens เดิมทั้งหมด (`WynSpacing.space4`/`space1` ตามที่ section header เดิมใช้) ไม่เพิ่ม spacing scale ใหม่
- Copy ภาษาไทยทุกจุดสั้น กระชับ สื่อความหมายตรงตัว มิเรอร์โทนของ label เดิมในแอป (เช่น "บัญชีที่ถูกบล็อก"/"บัญชีที่ปิดเสียง")

## Data Model (ข้อเสนอให้ AI Coding — Design ตัดสินใจแทน Product ตามที่ Product spec เปิดช่องให้เลือก)

**เลือกตารางใหม่ `notification_settings`** (ไม่ใช่เพิ่ม 6 คอลัมน์ใน `profiles`) เพราะ:
- `profiles` โตมากแล้วจากหลาย task ก่อนหน้า (`is_private` ของ WYN-039 ฯลฯ) — 6 boolean เพิ่มอีกจะทำให้ table นั้นรกและปนกับข้อมูลคนละ concern (profile ≠ notification preference)
- มิเรอร์ pattern ตารางแยกที่ project นี้ใช้มาตลอดสำหรับข้อมูลที่เป็นชุด/เฉพาะทาง (`drop_drafts` ของ WYN-036, `follow_requests` ของ WYN-039) ต่างจาก `is_private` ที่เป็น flag เดี่ยวๆ ตัวเดียว

Schema (ให้ AI Coding เขียนจริงใน `supabase/schema.sql`):
- `notification_settings` — `user_id uuid primary key references public.profiles(id) on delete cascade`, `likes_enabled boolean not null default true`, `comments_enabled boolean not null default true`, `follows_enabled boolean not null default true`, `messages_enabled boolean not null default true`, `club_enabled boolean not null default true`, `system_enabled boolean not null default true`
- RLS: เจ้าของแถวเท่านั้น (`auth.uid() = user_id`) ทั้ง SELECT/INSERT/UPDATE — ไม่มี exception ให้ใครเห็น/แก้ของคนอื่นเลย (มิเรอร์ `drop_drafts` ของ WYN-036 เป๊ะ — เป็นข้อมูลส่วนตัวล้วนๆ ไม่มีใครอื่นต้องเห็น)
- **ไม่มีแถวจนกว่าผู้ใช้จะ toggle ครั้งแรก** (lazy upsert, ไม่ backfill ให้ทุกบัญชีเดิม) — `updateCategory()` ใช้ `upsert` (insert ถ้ายังไม่มีแถว, update ถ้ามีแล้ว) ตั้งค่าคอลัมน์อื่นๆ ที่ไม่ได้แตะเป็น default `true` ตอน insert ครั้งแรก
- Helper function กลาง: `internal.notification_category_enabled(p_recipient_id uuid, p_category text) returns boolean` (`security definer`, `stable`) — `coalesce()` คืนค่าคอลัมน์ที่ตรงกับ `p_category` ('likes'/'comments'/'follows'/'messages'/'club'/'system') จากแถวของ `p_recipient_id` ถ้าไม่มีแถวเลยคืน `true` เสมอ — ทุก trigger ที่ insert เข้า `notifications` สำหรับ 15 type ที่อยู่ใน scope เรียกฟังก์ชันนี้ก่อน insert เสมอ (ระบุ category ตาม mapping ของ Product) type ที่ไม่อยู่ใน scope (Moderation/Appeal/Order) **ไม่เรียกฟังก์ชันนี้เลย** insert ตรงเหมือนเดิมทุกประการ

Handoff: AI Coding — implement schema ข้างบนตรงๆ, เขียน `internal.notification_category_enabled()`, แก้ trigger function 10+ ตัวให้เรียกก่อน insert สำหรับ 15 type ที่อยู่ใน scope เท่านั้น, สร้าง `NotificationSettingsRepository`/`NotificationSettingsScreen` ตาม Component table ข้างบน, แก้ `settings_screen.dart` ตาม Screen 1 — ทุกจุดต้องมี regression test ยืนยัน (1) type เดิมทั้งหมดที่ default เปิดอยู่ยังทำงานเหมือนเดิม (2) ปิดหมวดหนึ่งแล้วแถวไม่ถูก insert จริง (3) บัญชีที่ไม่เคยตั้งค่าเลยยังได้รับแจ้งเตือนครบ (ตรวจ "ไม่มีแถว" ไม่ใช่แค่ "มีแถวค่า true")
