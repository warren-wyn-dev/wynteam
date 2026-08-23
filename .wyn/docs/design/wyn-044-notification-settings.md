# Design Spec — WYN-044: Notification Settings

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (ไม่มีทิศทาง visual ใหม่ในรอบนี้ — reuse `SwitchListTile`/section-heading pattern ที่มีอยู่แล้วใน `settings_screen.dart` ตรงๆ ทั้งหมด)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-044-notification-settings.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ): `settings_screen.dart`'s section heading (`Padding` + `titleSmall` + `colorScheme.outline`) และ `SwitchListTile` ของ "บัญชีส่วนตัว (Private Account)" (WYN-039) เป๊ะทุกรายละเอียด (optimistic update + revert-on-error + disable-while-in-flight), `notification_list_screen.dart`'s ไอคอนต่อประเภท notification (reuse เพื่อให้ toggle แต่ละแถวจับคู่ไอคอนเดียวกับที่ผู้ใช้เห็นในลิสต์ notification จริงอยู่แล้ว ไม่คิดไอคอนใหม่)

## ภาพรวม

หน้าจอใหม่ 1 หน้า (`NotificationSettingsScreen`) + แก้ไฟล์เดิม 1 ไฟล์ (`settings_screen.dart` เพิ่ม section ใหม่) ไม่มีทิศทาง visual ใหม่ ไม่มี component ใหม่ — ทุกอย่าง reuse widget ที่มีอยู่แล้วในแอปนี้

---

## Screen: NotificationSettingsScreen

Purpose: ให้ผู้ใช้เปิด/ปิดการแจ้งเตือนได้เป็นรายหมวด (7 หมวดตาม Master Spec section 21 / Product's mapping)

User Flow:
1. ผู้ใช้เปิดโปรไฟล์ตัวเอง (`ViewProfileScreen`) → แตะไอคอน settings → `SettingsScreen`
2. แตะแถว "การแจ้งเตือน" (section ใหม่ที่เพิ่มใน `SettingsScreen`) → เปิด `NotificationSettingsScreen`
3. เห็นรายการ toggle 7 แถว ทุกแถวเปิดอยู่โดย default (ทั้งกรณีมีแถวใน DB อยู่แล้วและกรณีไม่เคยมีแถวเลย — ฝั่ง client อ่านค่าจาก DB ถ้ามี ไม่มีก็ default ทุกอย่างเป็น `true` เหมือนกันหมด ผู้ใช้แยกไม่ออกและไม่จำเป็นต้องรู้ความต่างนี้)
4. แตะ toggle หมวดใดหมวดหนึ่ง → เปลี่ยนค่าทันที (optimistic) → upsert ไป DB เบื้องหลัง → ถ้าสำเร็จไม่มีอะไรเกิดขึ้นเพิ่ม (เงียบ ๆ เหมือน Private Account toggle เดิม) ถ้า fail → revert กลับค่าเดิม + SnackBar "เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง" (ข้อความเดียวกับที่ `settings_screen.dart`'s `_setIsPrivate` ใช้อยู่แล้วเป๊ะ)
5. กลับไปหน้าเดิม (`SettingsScreen`) ด้วยปุ่ม back มาตรฐาน — ไม่มีปุ่ม "บันทึก" แยก (ทุก toggle บันทึกทันทีที่แตะ เหมือน Private Account toggle)

Components:
- `AppBar(title: Text('การแจ้งเตือน'))` — reuse ชื่อเดียวกับ `NotificationListScreen`'s AppBar ตรงๆ ได้เพราะ context ต่างกันชัดเจนอยู่แล้ว (คนละหน้าจอ ไม่ปรากฏพร้อมกัน)
- `ListView` เรียง `SwitchListTile` 7 แถว ไม่มี section heading ย่อยภายในหน้านี้ (ต่างจาก `SettingsScreen`'s หลาย section — หน้านี้มีแค่เนื้อหาเดียวคือ "การแจ้งเตือนรายหมวด" ทั้งหมด ไม่ต้องแบ่งกลุ่มซ้อนกลุ่ม)
- แต่ละแถวใช้โครงสร้างเดียวกับ Private Account toggle เป๊ะ: `secondary: Icon(...)`, `title: Text(ชื่อหมวดภาษาไทย)`, `subtitle: Text(คำอธิบายสั้น)`, `value`, `onChanged`

### รายการ 7 แถว (ชื่อ, ไอคอน, คำอธิบาย, mapping คอลัมน์ DB)

| # | คอลัมน์ DB | ชื่อที่แสดง | ไอคอน (reuse จาก UI ที่มีอยู่แล้ว) | คำอธิบายใต้ชื่อ |
|---|---|---|---|---|
| 1 | `likes` | ถูกใจ | `Icons.favorite_border` (ไอคอนเดียวกับปุ่ม Like ทั่วแอป — `DropDetailScreen`/`HomeDropCard`/`PopClipView`) | เมื่อมีคนถูกใจ Drop, Pop หรือ ReDrop โพสต์ของคุณ |
| 2 | `comments` | คอมเมนต์ | `Icons.mode_comment_outlined` (ไอคอนเดียวกับปุ่ม Comment ทั่วแอป) | เมื่อมีคนแสดงความคิดเห็นหรือกล่าวถึงคุณใน Drop |
| 3 | `follows` | ผู้ติดตาม | `Icons.person_add_outlined` (ไอคอนเดียวกับปุ่ม Follow ใน `DropDetailScreen`/`PopClipView`) | เมื่อมีคนติดตามคุณ หรือส่ง/ยอมรับคำขอติดตาม |
| 4 | `messages` | ข้อความ | `Icons.mail_outline` (ต่างจาก `Icons.chat_bubble_outline` ที่เป็นไอคอน Chat entry point เดิม — ตั้งใจใช้ไอคอนคนละแบบเพราะหมวดนี้ครอบเฉพาะ "คำขอข้อความ" ไม่ใช่ทางเข้า Chat ทั้งหมด) | เมื่อมีคนที่ไม่ได้ติดตามกันส่งคำขอข้อความถึงคุณ |
| 5 | `club` | Club | `Icons.groups_outlined` (ไอคอนเดียวกับ Club tab/`ClubPage`) | เมื่อมีความเคลื่อนไหวใน Club ที่คุณเป็นเจ้าของหรือเป็นสมาชิก (โพสต์, คำขอเข้าร่วม, การกล่าวถึง) |
| 6 | `trending` | กำลังนิยม | `Icons.trending_up` (ไอคอนเดียวกับที่ใช้ในหน้า Discovery/Trending, WYN-040/041) | เมื่อโพสต์ของคุณกำลังเป็นที่นิยมหรือติด WYN Top 100 *(ยังไม่มีการแจ้งเตือนประเภทนี้เกิดขึ้นจริงในระบบตอนนี้ — ดู Non-goals)* |
| 7 | `system` | ระบบ | `Icons.campaign_outlined` (ไอคอนเดียวกับที่ `notification_list_screen.dart` ใช้แสดง `system` notification อยู่แล้ว จาก WYN-043 — จับคู่กันตรงๆ ให้ผู้ใช้เชื่อมโยงได้ทันที) | ประกาศทั่วไปจากทีมงาน WYN |

Interactions:
- แตะที่ใดก็ได้บนแถว (ไม่ใช่แค่ตัว Switch เอง) สลับค่าได้ — พฤติกรรมมาตรฐานของ `SwitchListTile` อยู่แล้ว ไม่ต้อง custom
- ระหว่างรอ upsert ของแถวหนึ่งเสร็จ **แถวอื่นยัง toggle ได้อิสระ** (ต่างจาก Private Account toggle ที่มี flag เดียว `_isTogglingPrivate` ครอบทั้งหน้าเพราะมีแค่ 1 toggle) — ต้องใช้ flag แยกต่อแถว (เช่น `Map<String, bool> _isToggling` keyed ด้วยชื่อคอลัมน์ หรือ `Set<String> _togglingCategories`) ไม่ใช่ boolean เดียวครอบทั้งหน้า มิฉะนั้นแตะแถวหนึ่งจะ disable แถวอื่นทั้งหมดโดยไม่จำเป็น

States:
- **Loading**: ตอนเปิดหน้าครั้งแรก ระหว่างรอ fetch แถว `notification_settings` ของตัวเอง (ถ้ามี) → `Center(child: CircularProgressIndicator())` เต็มหน้า (มิเรอร์ `NotificationListScreen`'s `_isLoadingInitial` เป๊ะ)
- **Loaded (ไม่มีแถวใน DB เลย)**: ทุก toggle เป็น `true` (ไม่ใช่แสดง error/empty state ใดๆ — "ไม่มีแถว" เป็นสถานะปกติตามที่ Product กำหนดไว้ ไม่ใช่ error)
- **Loaded (มีแถวบางส่วน/ครบ)**: แสดงค่าจริงจาก DB ต่อคอลัมน์
- **Error (fetch ครั้งแรกล้มเหลว)**: ข้อความ error + ปุ่ม "ลองใหม่" กึ่งกลางหน้าจอ (มิเรอร์ `NotificationListScreen`'s error state เป๊ะ ใช้ข้อความ "โหลดการตั้งค่าไม่สำเร็จ" แทน "โหลดการแจ้งเตือนไม่สำเร็จ")
- **Toggle in-flight (ต่อแถว)**: แถวนั้น `onChanged` เป็น `null` ชั่วคราว (ป้องกันแตะซ้ำเร็วเกินระหว่างรอ network) แถวอื่นยัง interactive ปกติ
- **Toggle fail**: revert ค่าที่แถวนั้นกลับเป็นค่าก่อนแตะ + SnackBar

Responsive Behavior: `ListView` ยาวมาตรฐาน ไม่มีเนื้อหาที่ต้องจัดการ overflow พิเศษ (7 แถวสั้นๆ ไม่มี grid/card ที่ผูกกับความกว้างจอ) — ทำงานเหมือนกันทุกขนาดจอที่แอปนี้รองรับอยู่แล้ว ไม่ต้องออกแบบ breakpoint เพิ่ม

Accessibility:
- แต่ละ `SwitchListTile` มี `title`/`subtitle` เป็น string อ่านได้อยู่แล้ว (Flutter's `SwitchListTile` ประกาศ Semantics ให้อัตโนมัติ รวมสถานะ on/off เข้าไปด้วยเป็นค่า default — ไม่ต้องเขียน `Semantics` wrapper เองเหมือนที่ `notification_list_screen.dart`'s row ทำ เพราะ `SwitchListTile` ไม่ใช่ custom `InkWell`+`Row`)
- Contrast ของไอคอน/ข้อความ: ใช้ theme's default color เหมือนทุกหน้าจอ ไม่ custom สี

Design Rules:
1. **ห้ามใช้ flag `bool` เดียวครอบการ toggle ทั้ง 7 แถว** — ต้องแยก per-category ตามที่ระบุใน Interactions (ป้องกัน UX บั๊กที่แตะแถวหนึ่งแล้วแถวอื่น disable ไปด้วยทั้งที่ไม่เกี่ยวกัน)
2. **ไม่มีปุ่ม "บันทึก" แยก** — ทุก toggle บันทึกทันที มิเรอร์ Private Account toggle เดิมเป๊ะ ไม่สร้างรูปแบบใหม่ในแอปที่ต้องกด "บันทึก" หลัง toggle switch ใดๆ (ไม่เคยมี pattern นี้มาก่อนในแอปนี้เลย)
3. **ไอคอนของแต่ละแถวต้องจับคู่กับไอคอนที่ใช้จริงในจุดอื่นของแอปสำหรับ concept เดียวกัน** (ตามตารางด้านบน) ไม่คิดไอคอนใหม่ที่ไม่เคยปรากฏในแอปนี้มาก่อน

## Component แก้ไข: `settings_screen.dart` — เพิ่ม section "การแจ้งเตือน"

เพิ่ม section ใหม่ (heading + 1 `ListTile`) **ต่อจาก section "ความเป็นส่วนตัว" (Private Account toggle) และก่อน section "ความปลอดภัย"** (เรียงตามลำดับความถี่ที่ผู้ใช้ทั่วไปน่าจะต้องการปรับ: Privacy > Notifications > Security/Safety ที่เป็นของที่ไม่ค่อยต้องแตะบ่อย) — โครงสร้างเดียวกับ section heading เดิมทุกจุด (`Padding` + `titleSmall` + `colorScheme.outline`), ตามด้วย `ListTile` เดียว มิเรอร์ "บัญชีที่ถูกบล็อก"/"บัญชีที่ปิดเสียง" เป๊ะ (`leading: Icon`, `title: Text`, `trailing: Icon(Icons.chevron_right)`, `onTap` เปิดหน้าใหม่)

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(
    WynSpacing.space4, WynSpacing.space4, WynSpacing.space4, WynSpacing.space1,
  ),
  child: Text('การแจ้งเตือน', style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.outline,
      )),
),
ListTile(
  leading: const Icon(Icons.notifications_outlined),
  title: const Text('การแจ้งเตือน'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NotificationSettingsScreen(
        notificationSettingsRepository:
            NotificationSettingsRepository(Supabase.instance.client),
      ),
    ));
  },
),
```

section ใหม่นี้อยู่ตำแหน่งเดียวสำหรับทุก `platformRole` (ไม่ใช่ conditional เหมือน "เครื่องมือผู้ดูแล" — การตั้งค่าการแจ้งเตือนเป็นของทุกคนเสมอ ไม่เกี่ยวกับสิทธิ์)

## Components ที่แก้/สร้างใหม่ (สรุป)
1. **ใหม่**: `NotificationSettingsScreen` (`app/lib/features/settings/presentation/notification_settings_screen.dart` — วางในโฟลเดอร์ `settings` เดียวกับ `SettingsScreen` เพราะเป็นหน้าลูกของมันโดยตรง ไม่ใช่ของ feature `notification`)
2. **ใหม่ (ให้ Coding)**: `NotificationSettingsRepository` (`app/lib/features/settings/data/` — fetch + upsert แถวตัวเองของ `notification_settings`, mirror `SavedRepository`'s "ไม่มี `userId` param เพราะ RLS จำกัดอยู่แล้ว" pattern)
3. **แก้**: `settings_screen.dart` เพิ่ม 1 section (heading + 1 ListTile) ตามตำแหน่งที่ระบุ

## Non-goals รอบนี้
- ไม่มี broadcast/preview การแจ้งเตือนในหน้านี้ (แค่ toggle เปิด/ปิด)
- `trending` toggle แสดงอยู่ในหน้านี้ตาม Master Spec section 21 แต่**ไม่มีผลอะไรกับระบบจริงตอนนี้** (Product's Known Gap) — ไม่ต้องมี badge/label พิเศษบอกผู้ใช้ว่า "ยังไม่ทำงาน" เพราะจะสื่อสารสับสนกว่าไม่พูดอะไรเลย (ผู้ใช้ทั่วไปไม่มีทางรู้ว่ามันควรทำงานหรือไม่อยู่แล้ว ไม่ใช่ regression ที่มองเห็นได้)
- ไม่ต้องรวม/จัดหน้า `SettingsScreen` ใหม่ทั้งหมดเป็น Account/Privacy/Notifications/Security/Safety/Data/Legal ตาม Master Spec section 35 เต็มรูปแบบ — เป็นสโคปของ WYN-045

## Handoff

ส่งต่อ AI Coding (`/code`):
1. SQL: ตาราง `notification_settings` (7 boolean columns ตาม Product's mapping, `not null default true`, PK `user_id`, RLS จำกัดเจ้าของแถวเท่านั้นทั้ง select/insert/update) + helper function `internal.notification_enabled(p_user_id uuid, p_category text)` (ไม่มีแถว = `true` เสมอ) + gate การ insert ใน trigger function 13 ตัว + RPC 2 ตัว (`accept_follow_request()`, `send_system_notification()`) ตาม mapping ที่ Product ระบุไว้ในตาราง Requirement 2 ของ Product spec เป๊ะ — **ห้าม gate** 4 moderation/appeal types และ 4 order types ตามที่ Product ล็อกไว้ชัดเจน
2. Flutter: `NotificationSettingsRepository` ใหม่ + `NotificationSettingsScreen` ใหม่ (7 `SwitchListTile` ตามตารางในหัวข้อ Screen ด้านบน, per-category in-flight flag ตาม Design Rule #1) + แก้ `settings_screen.dart` เพิ่ม section ตามโค้ดตัวอย่างด้านบน
3. **ต้องมี regression test พิสูจน์ gate ทำงานจริง** (มิเรอร์ pattern red→green ที่ทุก task ก่อนหน้าทำ): ปิด toggle หมวดหนึ่ง → ยืนยันด้วย SQL ว่า insert ไม่เกิดขึ้นจริง (ไม่ใช่แค่เชื่อว่า logic ถูก) สำหรับอย่างน้อย 1 ตัวแทนต่อหมวดที่ gate จริงทั้ง 6 หมวด (`likes`/`comments`/`follows`/`messages`/`club`/`system` — `trending` ไม่มี producer ให้ทดสอบ)
4. ตรวจสอบว่า `moderation_warning`/`moderation_content_removed`/`appeal_approved`/`appeal_rejected`/order ทั้ง 4 ยัง insert ปกติแม้ปิด toggle ทุกหมวดหมดแล้ว (regression ตาม Product's Acceptance Criteria)
