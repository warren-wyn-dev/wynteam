# Design Spec — WYN-045: Settings — Interaction Privacy Controls

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (ไม่มีทิศทาง visual ใหม่ในรอบนี้)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-045-settings-privacy-controls.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ): `report_sheet.dart`'s pseudo-radio `ListTile` list (`Icons.radio_button_checked`/`unchecked`, ไม่ใช้ `RadioListTile` เพราะ Flutter เวอร์ชันนี้ deprecate `groupValue`/`onChanged` แบบเดิมไปแล้ว ตามที่ comment ในไฟล์นั้นระบุไว้ตรงๆ — มิเรอร์เป๊ะ ไม่คิด pattern เลือก 1-จาก-N ใหม่), `settings_screen.dart`'s Private Account `SwitchListTile` (optimistic + revert-on-fail + SnackBar ข้อความ "เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง")

## ภาพรวม

3 การตั้งค่าใหม่ (DM/Mention/Comment Permission) รูปร่างหน้าตาเดียวกันทุกจุด ต่างกันแค่ label/คำอธิบาย — ออกแบบเป็น **widget เดียวที่ reuse ซ้ำ 3 ครั้ง** (รับ label/ค่าปัจจุบัน/callback เป็น parameter) แทนที่จะ copy โค้ดหน้าตาเดียวกัน 3 รอบ ไม่มีหน้าจอใหม่แบบเต็มจอ — ใช้ `ListTile` (แถวสรุปค่าปัจจุบัน) + `showModalBottomSheet` (ตัวเลือก 3 ระดับ) ตรงจุดเดียวกับที่ `report_sheet.dart` ทำอยู่แล้ว

---

## Screen: `SettingsScreen` (แก้ไขไฟล์เดิม) — เพิ่ม 3 แถวใน section "ความเป็นส่วนตัว"

Purpose: ให้ผู้ใช้ตั้งค่าว่าใครทัก DM / กล่าวถึง / คอมเมนต์ตนเองได้บ้าง

User Flow:
1. ผู้ใช้เปิด `SettingsScreen` → เห็น section "ความเป็นส่วนตัว" (มี Private Account toggle เดิม + 3 แถวใหม่ต่อท้าย)
2. แตะแถว "ใครทักข้อความคุณได้" (หรือ Mention/Comment) → เปิด bottom sheet 3 ตัวเลือก พร้อม checkmark ที่ค่าปัจจุบัน
3. แตะตัวเลือกใหม่ → เปลี่ยนค่าทันที (optimistic) → sheet ปิดตัวเอง → กลับมาที่ `SettingsScreen` เห็นค่าปัจจุบันอัปเดตในแถวสรุปแล้ว
4. ถ้า save ล้มเหลว → แถวสรุปกลับไปค่าเดิม + SnackBar "เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง" (sheet ปิดไปแล้วก่อนหน้านี้ ต่างจาก Private Account toggle ที่ error โผล่ในหน้าเดิมทันที เพราะ sheet เป็น modal แยก ไม่รอผล save ก่อนปิด — ดู Interactions)

Components:
- 3 แถวใหม่ ต่อจาก Private Account `SwitchListTile` เดิม ในลำดับ: "ใครทักข้อความคุณได้" (DM) → "ใครกล่าวถึงคุณได้" (Mention) → "ใครคอมเมนต์โพสต์ของคุณได้" (Comment) — เรียงตามลำดับที่ผู้ใช้เจอบ่อย/สำคัญมากไปน้อย (DM = ช่องทางที่คนแปลกหน้าเข้าถึงตัวตนได้ตรงที่สุด)
- แต่ละแถวเป็น `ListTile` (ไม่ใช่ `SwitchListTile` เพราะมี 3 ค่า ไม่ใช่ 2): `leading: Icon(...)`, `title: Text(ชื่อการตั้งค่า)`, `trailing: Text(ชื่อค่าปัจจุบัน) + Icon(Icons.chevron_right)` (โครงสร้าง trailing สองส่วนคู่กัน มิเรอร์ pattern "แสดงค่าปัจจุบันในแถวสรุป" ที่ไม่เคยมีมาก่อนในแอปนี้ แต่เป็นรูปแบบมาตรฐานของ Settings ทั่วไปที่ไม่ขัดกับ Design Rule ห้ามลอก Layout ของแอปคู่แข่งโดยตรง — เป็น pattern ระดับ OS/framework ไม่ใช่ layout เฉพาะของแอปใดแอปหนึ่ง)
- ไอคอนต่อแถว: DM = `Icons.mail_outline` (ตัวเดียวกับที่ WYN-044 ใช้กับหมวด "ข้อความ" — จับคู่ concept เดียวกันให้ผู้ใช้เชื่อมโยงได้), Mention = `Icons.alternate_email`, Comment = `Icons.mode_comment_outlined` (ตัวเดียวกับที่ WYN-044 ใช้กับหมวด "คอมเมนต์")
- Bottom sheet: reuse โครงสร้างของ `ReportSheet` เป๊ะ (drag handle, title + close button, `SafeArea`+`Padding`) แต่เนื้อหาเป็น pseudo-radio 3 แถวแทน 10 แถวของ Report — **ไม่มีปุ่ม "ยืนยัน" แยก** (ต่างจาก `ReportSheet` ที่มีปุ่ม "ส่งรายงาน" เพราะต้องรอกรอก detail text ก่อน) — แตะตัวเลือกในนี้คือ apply ทันที มิเรอร์ Private Account toggle's "ไม่มีปุ่มบันทึกแยก" เป๊ะ

### ตัวเลือก 3 ระดับ (ใช้ label ชุดเดียวกันทั้ง 3 การตั้งค่า)
| ค่า DB | Label ที่แสดง | คำอธิบายใต้ label ใน sheet |
|---|---|---|
| `everyone` | ทุกคน | ค่าเริ่มต้น — ทุกคนทำได้ ยกเว้นบัญชีที่บล็อกกัน |
| `people_i_follow` | คนที่ฉันติดตาม | เฉพาะบัญชีที่คุณติดตามอยู่เท่านั้น |
| `no_one` | ไม่มีใครเลย | ปิดทั้งหมด ไม่มีข้อยกเว้น |

คำอธิบายใต้ label ในแถวสรุปของ `SettingsScreen` เอง (ไม่ใช่ใน sheet) ใช้ประโยคเฉพาะต่อการตั้งค่า มิเรอร์ Private Account toggle's subtitle:
- DM: "ควบคุมว่าใครเริ่มบทสนทนาใหม่กับคุณได้"
- Mention: "ควบคุมว่าใครกล่าวถึงคุณใน Drop ได้"
- Comment: "ควบคุมว่าใครคอมเมนต์ Drop และ Pop ของคุณได้"

Interactions:
- แถวสรุปใน `SettingsScreen`: แตะเปิด sheet เสมอ (ไม่มี disable state ระหว่างโหลดค่าเริ่มต้น เพราะค่าเริ่มต้นมาจาก `Profile` ที่ `SettingsScreen` โหลดมาแล้วตั้งแต่ `ViewProfileScreen` ก่อนเปิดหน้านี้ เหมือน `isPrivate`/`platformRole` เดิม — ไม่ query ใหม่)
- Sheet: แตะตัวเลือก → ปิด sheet ทันที (`Navigator.pop(context, newValue)`) → `SettingsScreen` รับค่าใหม่มา optimistic update แถวสรุป + เรียก repository update เบื้องหลัง — **ไม่รอผล API ก่อนปิด sheet** (ต่างจาก `ReportSheet` ที่รอ `_isSubmitting` เพราะมี validation/detail text ให้กรอกก่อน แต่ตรงนี้เป็นแค่เลือก 1 ใน 3 ไม่มีอะไรให้ผิดพลาดฝั่ง client) — ปิด sheet ไว-responsive กว่า รอ error handling ที่ layer `SettingsScreen` แทน (มิเรอร์ Private Account toggle's optimistic pattern ตรงๆ แค่ triger จาก sheet แทน switch)
- ระหว่าง API call ค้างอยู่ (หายาก เพราะปิด sheet ไปแล้ว) แถวสรุปแตะซ้ำได้ปกติไม่ disable (ต่างจาก WYN-044's per-category in-flight flag เพราะที่นี่มีแค่ 1 แถวต่อการตั้งค่า ไม่ใช่ 7 แถวพร้อมกัน ความเสี่ยง race แทบไม่มี — ถ้าผู้ใช้แตะเปลี่ยนซ้ำเร็วมากๆ ระหว่างรอ API เดิมยังไม่จบ ให้ค่าล่าสุดที่ผู้ใช้เลือกชนะเสมอ ไม่ต้อง queue/lock เพราะเป็นแค่ upsert ค่าเดียว)

States:
- **Sheet เปิดใหม่**: highlight ตัวเลือกที่ตรงกับค่าปัจจุบัน (`Icons.radio_button_checked` + สี primary) มิเรอร์ `ReportSheet`'s `_category == category` เป๊ะ
- **Update fail**: แถวสรุปกลับไปค่าเดิม + SnackBar ข้อความเดียวกับ Private Account toggle
- ไม่มี Loading/Error state แยกสำหรับ 3 แถวนี้เอง (ใช้ค่าที่ `SettingsScreen` มีอยู่แล้วจาก parent เสมอ ไม่มี fetch เพิ่มเติมของตัวเอง — ต่างจาก WYN-044's `NotificationSettingsScreen` ที่เป็นหน้าเต็มแยกต้อง fetch เอง)

Responsive Behavior: Bottom sheet 3 แถวสั้นมาก ไม่มีความเสี่ยง overflow บนจอเล็ก/แนวนอน (ต่างจาก `ReportSheet`'s 10 แถว + text field ที่ต้องกำหนด `constraints.maxHeight` ชัดเจน) — ไม่ต้องกำหนด `constraints` เพิ่มเติม ปล่อยให้ sheet สูงตามเนื้อหาได้ตามปกติ

Accessibility:
- แต่ละตัวเลือกใน sheet ใช้ `Semantics(label: ..., selected: ...)` มิเรอร์ `ReportSheet`'s pseudo-radio แถวเป๊ะ (ประกาศทั้ง label และสถานะเลือกอยู่หรือไม่ให้ screen reader)
- แถวสรุปใน `SettingsScreen`: `ListTile`'s default semantics ก็เพียงพอ (title + trailing text ถูกอ่านรวมกันเป็นค่าปัจจุบันอยู่แล้วโดยไม่ต้อง custom Semantics)

Design Rules:
1. **Widget เดียว reuse 3 ครั้ง** ไม่ copy 3 ชุด — รับ `label`/`currentValue`/`onChanged` (หรือเทียบเท่า) เป็น parameter
2. **ไม่มีปุ่มยืนยันแยกใน sheet** — แตะตัวเลือกคือ apply ทันที ปิด sheet ทันที (เหมือน Private Account toggle ไม่มีปุ่ม "บันทึก")
3. **ห้ามใช้ `RadioListTile`** (deprecated ในเวอร์ชัน Flutter นี้ตามที่ `report_sheet.dart` บันทึกไว้แล้ว) — ใช้ pseudo-radio `ListTile` + `Icons.radio_button_checked/unchecked` แบบเดียวกัน

## Component แก้ไข: `settings_screen.dart`

เพิ่ม 3 `ListTile` ใหม่ **ต่อท้าย Private Account `SwitchListTile` เดิมทันที ภายใน section heading "ความเป็นส่วนตัว" เดียวกัน** (ไม่สร้าง heading ใหม่ — ทั้ง 4 แถว คือ Private Account + DM + Mention + Comment เป็น "ความเป็นส่วนตัว" กลุ่มเดียวกันตาม Master Spec section 35) ก่อนถึง section "การแจ้งเตือน" ที่ WYN-044 เพิ่งเพิ่มไว้

```dart
_PermissionSettingTile(
  icon: Icons.mail_outline,
  title: 'ใครทักข้อความคุณได้',
  subtitle: 'ควบคุมว่าใครเริ่มบทสนทนาใหม่กับคุณได้',
  value: _dmPermission,
  onChanged: (v) => _setPermission('dm_permission', v, (p) => _dmPermission = p),
),
// Mention/Comment มิเรอร์เป๊ะ ต่างแค่ icon/title/subtitle/state field/category key
```

## Components ที่แก้/สร้างใหม่ (สรุป)
1. **ใหม่**: `_PermissionSettingTile` (private widget ภายใน `settings_screen.dart` เอง — ไม่ต้องแยกไฟล์ใหม่เพราะใช้เฉพาะในไฟล์นี้ 3 ครั้ง ไม่มี caller อื่น มิเรอร์ที่ `_SettingsScreenState`'s helper methods อื่นๆ ก็เป็น private ในไฟล์เดียวกันหมด)
2. **ใหม่**: `_showPermissionPicker` (helper function เปิด bottom sheet 3 ตัวเลือก, คืนค่าที่เลือกหรือ `null` ถ้าปิดโดยไม่เลือก)
3. **แก้**: `settings_screen.dart` เพิ่ม state fields `_dmPermission`/`_mentionPermission`/`_commentPermission` (รับค่าเริ่มต้นจาก `Profile` ที่ widget parent ส่งเข้ามา คู่กับ `isPrivate` เดิม) + `_setPermission()` helper (optimistic + revert + SnackBar, มิเรอร์ `_setIsPrivate` เป๊ะแต่รับ category key เป็น parameter เพื่อ reuse กับทั้ง 3 การตั้งค่า)

## Non-goals รอบนี้
- ไม่มี custom permission แบบ "เลือกรายคน/รายกลุ่มยกเว้น" (Instagram's "Hide story from" style) — 3 ระดับตายตัวตาม Product spec เท่านั้น
- ไม่ย้อนหลังผลกับเนื้อหา/บทสนทนาที่มีอยู่ก่อนตั้งค่า (Product's Risks ระบุไว้แล้ว)

## Handoff

ส่งต่อ AI Coding (`/code`):
1. SQL: คอลัมน์ใหม่ 3 ตัวบน `profiles` (`dm_permission`/`mention_permission`/`comment_permission`, `text not null default 'everyone' check (... in ('everyone','people_i_follow','no_one'))`) + gate ตาม Product spec's 3 จุด (`get_or_create_conversation`, `drop_mentions`/`club_post_mentions` INSERT policy + `create_poll_drop()`, `drop_comments`/`pop_comments` INSERT policy เวอร์ชันล่าสุด) — ใช้ helper function 2 ตัวใหม่ตามที่ Product ระบุ (`internal.mention_allowed`, `internal.comment_allowed`) บวก inline check ใน `get_or_create_conversation()` (ไม่ต้องมี helper แยกเพราะ logic ผูกกับ active/pending เดิมของฟังก์ชันนั้นโดยเฉพาะ ดึงออกมาเป็นฟังก์ชันแยกจะทำให้อ่านยากกว่าเดิม)
2. Flutter: `_PermissionSettingTile` + `_showPermissionPicker` ใหม่ใน `settings_screen.dart`, `ProfileRepository` เพิ่ม method update permission (มิเรอร์ `updateIsPrivate` เป๊ะ, 1 method รับ column name + value หรือ 3 method แยกก็ได้ตามที่ Coding เห็นว่าอ่านง่ายกว่า)
3. **ต้องมี regression test พิสูจน์ gate ทำงานจริงทั้ง 3 จุด** ที่ SQL layer (มิเรอร์ pattern ทุก task ก่อนหน้า) — โดยเฉพาะ Mention permission ต้องทดสอบทั้ง 2 เส้นทาง (RLS policy ปกติ + `create_poll_drop()` RPC) ตามที่ Product's Acceptance Criteria ระบุไว้ชัดเจน ห้ามลืมเส้นทาง RPC เหมือนที่เกือบเกิดขึ้นกับ WYN-044's `get_or_create_conversation()`
4. ยืนยัน Club Post comment ไม่ถูกกระทบ (Comment Permission ไม่แตะ `club_post_comments` เลย) เป็น regression check ที่ต้องมีชัดเจน
