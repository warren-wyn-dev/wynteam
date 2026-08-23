# Design Spec — WYN-043: Notification Types (ReDrop bug fix + System)

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (ไม่มีทิศทาง visual ใหม่ในรอบนี้ — task นี้เติมจุดที่ขาดหายไปในโครงสร้างที่มีอยู่แล้วทั้งหมด)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-043-notification-types.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ): `notification_list_screen.dart`'s `_messageFor()`/`_openNotification()`/`_hidesActorIdentity()` (WYN-012, ต่อยอดโดย WYN-015/021/029/030/032/039), `internal.current_platform_role()` (WYN-029)

## ภาพรวม — ไม่มีหน้าจอใหม่ เติมจุดที่ขาดหายไปในโครงสร้างเดิม

Requirement 1 (บั๊ก `redrop`) ไม่มีการออกแบบใหม่เลย — เป็นการเติม case ที่ควรมีอยู่แล้วตั้งแต่ WYN-034 เข้าไปใน 3 จุดของไฟล์เดิม (enum/parsing/message/tap-navigation) ให้ตรงกับ pattern ของ `like_drop`/`mention_drop` ที่มีอยู่แล้วทุกประการ (ทั้งคู่ก็ใช้ `drop_id` เปิด `DropDetailScreen` เหมือนกัน)

Requirement 2 (`system` type) มีจุดตัดสินใจเดียวที่ต้องออกแบบจริง: **ไอคอนที่ใช้แสดงแทน avatar** เมื่อไม่มี actor (เหมือน 4 moderation types เดิม) — ตัดสินใจว่าไม่ควรใช้ `Icons.shield_outlined` ตัวเดียวกับ moderation ซ้ำ เพราะความหมายต่างกันชัดเจน (moderation = การกระทำต่อบัญชีคุณ, system = ประกาศทั่วไป) ผู้ใช้ควรแยกความรู้สึกออกจากกันได้ตั้งแต่เห็นไอคอนแรก

---

## Requirement 1: แก้บั๊ก `redrop` — 3 จุดในไฟล์เดิม ไม่มี UI ใหม่

### จุดที่ 1 — `notification.dart`
- เพิ่ม `redrop` เข้า `NotificationType` enum (วางถัดจาก `mentionClubPost` ก่อนกลุ่ม moderation ตามลำดับเวลาที่ WYN-034 เกิดขึ้นจริงในสคีมา — ไม่มีนัยสำคัญเชิงพฤติกรรม แค่ให้ enum อ่านง่ายตามลำดับ WYN ที่เพิ่ม)
- เพิ่ม case `'redrop' → NotificationType.redrop` ใน `_typeFromString()`
- **ไม่ต้องเพิ่ม field ใหม่ใน `WynNotification`** — `notify_redrop()` insert เข้า `drop_id` เดิมอยู่แล้ว (มิเรอร์ `like_drop`/`mention_drop`) field นี้มีอยู่แล้วในโมเดล

### จุดที่ 2 — `_messageFor()` (`notification_list_screen.dart`)
```dart
case NotificationType.redrop:
  return '$name ReDrop โพสต์ของคุณ';
```
ใช้โทนเดียวกับ `likeDrop`/`commentDrop` ทุกประการ (`$name` + กริยา + "โพสต์ของคุณ") — ไม่ทับศัพท์เป็นไทยเพราะ "ReDrop" เป็นชื่อฟีเจอร์เฉพาะของระบบ (เหมือนที่ `like_drop`'s message คงคำว่า "Drop" ไว้ไม่แปล)

### จุดที่ 3 — `_openNotification()` (`notification_list_screen.dart`)
```dart
case NotificationType.redrop:
  await _openDrop(notification.dropId!);
```
มิเรอร์ `mentionDrop`/`likeDrop` เป๊ะ — `drop_id` การันตีไม่ null เสมอสำหรับ type นี้ (trigger เดียวกันกับ `like_drop` ที่ insert `drop_id` เสมอ)

### Regression test ที่ต้องมี (Product's Acceptance Criteria)
เขียน widget test ใหม่ใน `notification_list_screen_test.dart` (หรือไฟล์เทียบเท่าที่มีอยู่แล้ว) จำลอง `WynNotification` ที่ `type: 'redrop'` ปนกับแถวประเภทอื่นในลิสต์เดียวกัน → ยืนยัน render ได้ปกติทั้งหน้า ไม่ throw — **ต้องพิสูจน์ red→green จริงตามที่ Product กำหนด**: comment ในโค้ด test อธิบายว่าก่อนแก้ `NotificationType`/`_typeFromString` จะ throw `ArgumentError` ตรงนี้ (Coding พิสูจน์ด้วยการ revert ชั่วคราวแล้วรันดูจริงตามขั้นตอน ไม่ใช่แค่เขียน comment ลอยๆ)

---

## Requirement 2: `system` Notification Type

### การแสดงผลในแถว (`notification_list_screen.dart`'s row builder)

**เปลี่ยน `_hidesActorIdentity(type)`** ให้รวม `NotificationType.system` เข้าไปด้วย (คืน `true` เมื่อ type เป็น system เช่นกัน) — เหตุผลเดียวกับ 4 moderation types เดิม: `actor_id` เป็น `null` เสมอสำหรับ type นี้ ต้องไม่พยายามอ่าน `actorUsername`/`actorAvatarUrl` มาแสดง (จะได้ avatar ว่างเปล่าไม่มีความหมาย)

**เพิ่มไอคอนแยกสำหรับ `system`** (ไม่ใช้ `Icons.shield_outlined` ซ้ำกับ moderation) — เพิ่ม helper ใหม่แทนที่การ hardcode ไอคอนเดียวตรงจุด `CircleAvatar`:
```dart
IconData _noActorIconFor(NotificationType type) =>
    type == NotificationType.system
        ? Icons.campaign_outlined
        : Icons.shield_outlined;
```
เรียกแทนที่ `Icons.shield_outlined` ที่ hardcode อยู่ตรง `CircleAvatar`'s child (บรรทัดที่มี `_hidesActorIdentity(notification.type)` เป็นเงื่อนไข) — สีพื้นหลัง/สี icon เดิมคงไว้ทั้งหมด (ใช้ `colorScheme.surfaceContainerHigh`/`onSurfaceVariant` เดียวกัน ไม่ต้องคิดสีใหม่ ระบบไม่ได้ผูกความหมายสีกับประเภท notification ไว้อยู่แล้ว)

**เลือก `Icons.campaign_outlined`** เพราะสื่อถึง "ประกาศ" ตรงตามความหมาย Security/Policy/Announcement ของ Master Spec section 20 โดยไม่ต้องคิดไอคอนใหม่นอก Material Icons ที่มีอยู่แล้วในระบบ (ทุกไอคอนในแอปนี้ใช้ Material Icons ชุดเดียวกันทั้งหมด ไม่เคยนำเข้า icon pack อื่น)

### ข้อความ (`_messageFor()`)
```dart
case NotificationType.system:
  return notification.reason ?? 'มีประกาศจากระบบ WYN';
```
มิเรอร์ pattern เดียวกับ `moderationWarning`/`moderationContentRemoved` ที่ใช้ `notification.reason` เป็นเนื้อหาหลัก — ต่างกันตรงที่ system ไม่มี prefix อธิบายบริบทแบบ moderation (moderation ต้องบอกว่า "คุณได้รับคำเตือน..." เพื่อไม่ให้กำกวมกับข้อความทั่วไป แต่ system message ควรเป็นเนื้อความประกาศเต็มๆ ตรงๆ เพราะ admin เป็นคนพิมพ์ข้อความทั้งหมดเองอยู่แล้วผ่าน `p_message` — ไม่ต้องมี Design เติมคำนำหน้าซ้ำซ้อน) — fallback ข้อความเผื่อกรณี `reason` เป็น null (ไม่ควรเกิดขึ้นจริงถ้า Coding บังคับ `p_message` ไม่ให้ blank ที่ RPC แต่ใส่ fallback ไว้เป็น safety net เดียวกับ pattern `?? ''`/`?? 'ร้านค้า'` ที่ใช้อยู่แล้วทั่วไฟล์นี้)

### Tap behavior (`_openNotification()`)
```dart
case NotificationType.system:
  return; // no-op -- there's no destination screen for a system announcement
```
**ไม่มีปลายทางให้เปิด** — ต่างจากทุก type อื่นที่มีเนื้อหา/โปรไฟล์/ออเดอร์ให้กดเข้าไปดูต่อ System notification คือข้อความเต็มในตัวมันเองอยู่แล้ว (แสดงครบใน `_messageFor()` ที่เห็นในลิสต์) ไม่มีหน้าจอ "รายละเอียดประกาศ" แยกต่างหากในรอบนี้ (ไม่ใช่สโคปของ task นี้ตาม Product's "ไม่มีหน้า Admin UI ใหม่ในรอบนี้" — ฝั่งผู้รับก็เช่นกัน ไม่มีหน้าใหม่)

### RPC — ไม่มี UI ใหม่ แค่ต้องมีจริง (สำหรับ AI Coding)
`send_system_notification(p_recipient_id uuid, p_message text)` (SECURITY DEFINER) — reuse `internal.current_platform_role() = 'admin'` check ตรงๆ ตามที่ Product ระบุ ไม่มีจุดตัดสินใจ UX เพิ่มเติมจาก Design เพราะไม่มีหน้าจอเรียกใช้ในแอป (เรียกตรงผ่าน RPC เท่านั้นตามสโคปที่ Product ล็อกไว้)

---

## Screen: N/A — ไม่มี Screen ใหม่ในรอบนี้ (เติมโค้ดใน 2 ไฟล์เดิมทั้งหมด)

## Components ที่แก้ (สรุป)
1. `notification.dart`: enum + parsing (`redrop`, `system`)
2. `notification_list_screen.dart`: `_messageFor()` (+2 case), `_openNotification()` (+2 case, `redrop` เปิด Drop / `system` no-op), `_hidesActorIdentity()` (+1 case สำหรับ `system`), ไอคอนใน no-actor branch เปลี่ยนจาก hardcode เป็น `_noActorIconFor(type)`

## Design Rules
1. **ห้ามใช้ `Icons.shield_outlined` กับ `system`** — ต้องแยกไอคอนให้ผู้ใช้แยกความหมาย "moderation action ต่อบัญชีคุณ" กับ "ประกาศทั่วไป" ออกจากกันได้ทันทีที่เห็น
2. **ไม่เพิ่ม prefix คำอธิบายหน้าข้อความ system** (ต่างจาก moderation ที่มี "คุณได้รับคำเตือนจากทีมงาน WYN:") — admin พิมพ์ข้อความเองครบอยู่แล้ว
3. **ไม่สร้างหน้าจอใหม่ใดๆ** ทั้งฝั่งแอดมิน (ส่ง) และผู้รับ (ดูรายละเอียด) — RPC-only ตามสโคปที่ Product ล็อกไว้

## Non-goals รอบนี้
- ไม่มี broadcast-to-all UI/mechanism (Product's Requirement 2)
- ไม่มี Trending/Top 100 notification (Product's Requirement 3 — เลื่อนสโคปทั้งหมด)
- ไม่มีหน้า Admin ใหม่ใดๆ

## Handoff

ส่งต่อ AI Coding (`/code`):
1. **[P0]** แก้บั๊ก `redrop` ตาม Requirement 1 ข้างต้นทั้ง 3 จุด + regression test พิสูจน์ red→green จริง — ตรวจสอบซ้ำว่า `follow_request`/`follow_request_accepted`/`message_request` ครบทั้งหมดจริงตามที่ Product ตั้งข้อสังเกตไว้ (ไม่ต้องแก้ถ้าครบแล้ว แค่ยืนยัน)
2. เพิ่ม `system` type ตาม Requirement 2 ทั้ง SQL (`send_system_notification()` RPC ใหม่, `notifications_type_check` เพิ่ม `'system'`) และ Flutter (enum/parsing/message/no-op tap/`_hidesActorIdentity`/`_noActorIconFor`)
3. เขียน SQL regression test ใหม่ครอบ: admin เรียกสำเร็จ, non-admin (`user`/`moderator`) ถูกปฏิเสธ, `actor_id` เป็น `null` เสมอในแถวที่สร้าง, message ตรงกับที่ส่ง
4. เขียน Flutter regression test ครอบ: `system` notification แสดงไอคอน campaign ไม่ใช่ shield, ไม่แสดง actor avatar, tap ไม่ navigate ไปไหน (no-op), ข้อความตรงกับ `reason`
