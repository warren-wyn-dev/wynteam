# Design Spec — WYN-047: Data Rights (Export + Account Deletion)

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (ไม่มีทิศทาง visual ใหม่ — ใช้ `colorScheme.error` มาตรฐานของ Material สำหรับปุ่มทำลายล้าง ซึ่งเป็น system color ไม่ใช่การคิดสีใหม่)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-047-data-rights.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ): `settings_screen.dart`'s section heading + `ListTile` pattern, `SharePlus.instance.share(...)` (API จริงที่ใช้อยู่แล้วหลายจุด เช่น `pop_clip_view.dart` — คนละ method จาก `Share.share()` เดิม), `core/widgets/confirm_delete_dialog.dart`'s dialog shape (ใช้เป็นฐานแต่ไม่พอสำหรับความเสี่ยงระดับบัญชี — ดู Screen 2)

## ภาพรวม

1 section ใหม่ใน `SettingsScreen` (2 แถว) + 1 หน้าจอใหม่เต็มจอสำหรับยืนยันลบบัญชี (ไม่ใช่ dialog ธรรมดา — ความเสี่ยงสูงกว่าการลบ Drop มาก ต้องใช้ friction สูงกว่า)

---

## Component แก้ไข: `settings_screen.dart` — section "ข้อมูลของฉัน"

ตำแหน่ง: **ก่อน section "กฎหมาย" (WYN-046) ทันที** (ยังคงเป็น section ท้ายๆ ของหน้า แต่ไม่ใช่ท้ายสุด — "กฎหมาย" ยังคงเป็น section สุดท้ายตามที่ WYN-046 กำหนดไว้)

```
Padding(...) → Text('ข้อมูลของฉัน', titleSmall, outline color)
ListTile(leading: Icons.download_outlined, title: Text('ดาวน์โหลดข้อมูลของฉัน'), trailing: chevron, onTap: _exportData)
ListTile(leading: Icons.delete_forever_outlined, title: Text('ลบบัญชี'), trailing: chevron, onTap: เปิด DeleteAccountScreen)
```

`_exportData` **ไม่เปิดหน้าใหม่** — เรียก RPC ตรงจากปุ่มนี้เลย (ต่างจาก "ลบบัญชี" ที่เปิดหน้ายืนยันเต็มจอ) เพราะ Export เป็น read-only ไม่มีความเสี่ยง ไม่ต้องมี friction เพิ่ม — แสดง `CircularProgressIndicator` เล็กแทนไอคอนระหว่างรอ (state ชั่วคราวใน `ListTile`'s `leading`), สำเร็จ → เปิด share sheet ของระบบทันที (`SharePlus.instance.share(ShareParams(files: [XFile...]))`), ล้มเหลว → SnackBar "ดาวน์โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง"

---

## Screen: `DeleteAccountScreen`

Purpose: บังคับให้ผู้ใช้เข้าใจและยืนยันความเสี่ยงก่อนลบบัญชีถาวร — friction สูงกว่าการลบเนื้อหาทั่วไปอย่างมีเจตนา เพราะ Account Deletion ไม่มีทางกู้คืน (ต่างจาก Drop ที่มี 30 วัน)

User Flow:
1. แตะ "ลบบัญชี" จาก Settings → เปิดหน้านี้ (push ปกติ มี AppBar + back button — ยังยกเลิกได้ตลอดจนกว่าจะกดปุ่มสุดท้าย ต่างจาก `DocumentAcceptanceScreen` ของ WYN-046 ที่บังคับไม่มีทางออก)
2. เห็นคำเตือนชัดเจน: หัวข้อ "ลบบัญชีถาวร" + รายการสิ่งที่จะหายไป (Drop/Pop/Comment ทั้งหมด, Follower/Following, ข้อความแชท, การเป็นสมาชิก Club) + ประโยคเน้นย้ำ "การลบบัญชีไม่สามารถย้อนกลับได้ ไม่มีระยะเวลาผ่อนผันเหมือนการลบ Drop"
3. ช่องพิมพ์ยืนยัน: label "พิมพ์ \"ลบบัญชี\" เพื่อยืนยัน" — ปุ่ม "ลบบัญชีถาวร" enabled เฉพาะข้อความที่พิมพ์ตรงกับ "ลบบัญชี" เป๊ะ (case-sensitive ตรงตัว ไม่ trim ยกเว้น whitespace หัวท้าย)
4. กดปุ่ม → `AlertDialog` ยืนยันอีกชั้นสุดท้าย (มิเรอร์ `confirmDeletePost` แต่ข้อความเข้มกว่า: "ยืนยันลบบัญชีถาวร?" / "บัญชีและข้อมูลทั้งหมดของคุณจะถูกลบทันที ไม่สามารถกู้คืนได้") — กด "ลบ" ในนี้จริงถึงจะเรียก RPC
5. สำเร็จ → เรียก `signOut()` ทันที → `AuthGate`'s auth-state listener กลับสู่ `WelcomeScreen` เอง (มิเรอร์ `_leaveBlockedScreen`'s pattern ใน `auth_gate.dart`)
6. ล้มเหลว → SnackBar "ลบบัญชีไม่สำเร็จ ลองใหม่อีกครั้ง" ยังอยู่หน้าเดิม ไม่ sign out (ผู้ใช้ยังใช้บัญชีต่อได้ปกติถ้าลบไม่สำเร็จ)

Components:
- `AppBar(title: Text('ลบบัญชี'))`
- คำเตือน: `Icon(Icons.warning_amber_rounded, color: colorScheme.error)` + หัวข้อ + bullet list สิ่งที่จะหาย + ประโยคเน้นย้ำ (ตัวหนา หรือสี `colorScheme.error`)
- `TextField` ยืนยันข้อความ
- ปุ่ม "ลบบัญชีถาวร": `FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError)` — สีแดงชัดเจนต่างจากปุ่มปกติของแอปทั้งหมด (ไม่เคยมีปุ่มสีนี้มาก่อนในแอป ยกเว้น error text ธรรมดา — เป็นจุดตัดสินใจ Design ที่ตั้งใจให้ปุ่มนี้ดู "อันตราย" ชัดเจนกว่าปุ่มไหนๆ ในแอป)

Interactions:
- `TextField.onChanged` → ตรวจ match แบบ real-time, ปุ่ม enable/disable ตาม
- กดปุ่ม → `AlertDialog` ชั้นที่ 2 → ยืนยันจริงถึงเรียก RPC → `_isDeleting` guard กันกดซ้ำระหว่างรอ

States:
- Idle → Confirming (dialog เปิด) → Deleting (`CircularProgressIndicator` แทนข้อความในปุ่ม, ทั้งหน้าปิด interaction อื่น) → Success (sign out, ออกจากหน้านี้ไปเลย ไม่ต้องมี success state ที่ค้างให้เห็น) / Error (SnackBar, กลับ Idle)

Responsive Behavior: `SingleChildScrollView` ครอบเนื้อหาทั้งหมด (คำเตือน+list อาจยาวบนจอเล็ก)

Accessibility: ปุ่มที่ disabled มี Semantics label อธิบายเหตุผล (มิเรอร์ pattern `ReportSheet`/WYN-044/045/046) เช่น "ลบบัญชีถาวร ปิดใช้งานจนกว่าจะพิมพ์ข้อความยืนยันให้ตรง"

Design Rules:
1. **ต้องพิมพ์ยืนยัน + AlertDialog สองชั้น** ก่อนเรียก RPC จริง — ไม่มีทางลบบัญชีได้ด้วยการกดปุ่มเดียว
2. **ปุ่มลบใช้สี `colorScheme.error` เป็นพื้นหลัง** ไม่ใช่แค่ข้อความสีแดงเหมือนจุดอื่นในแอป — สื่อความเสี่ยงระดับสูงสุดที่ไม่เคยมี action ไหนในแอปนี้ต้องการมาก่อน
3. **ไม่มีข้อความ "กู้คืนได้"/"ยกเลิกภายหลัง" ใดๆ ทั้งสิ้น** ต่างจาก `confirmDeletePost`'s เดิมที่บอก (ผิด) ว่า "ลบแล้วไม่สามารถกู้คืนได้" ทั้งที่ Drop กู้คืนได้จริงใน 30 วัน — หน้านี้ต้องพูดความจริง: ไม่มีทางกู้คืนจริงๆ

## Non-goals รอบนี้
- ไม่มี re-authentication (กรอกรหัสผ่าน/OTP ใหม่) ตามที่ Product ตัดสินใจไว้แล้วใน Risks
- ไม่มี grace period/undo

## Handoff

ส่งต่อ AI Coding (`/code`):
1. SQL: `export_my_data()` (SECURITY DEFINER, returns jsonb) รวมข้อมูลตามที่ Product ระบุ Requirement 1 + `delete_my_account()` (SECURITY DEFINER) ลบ `auth.users` ของ `auth.uid()` — **ตรวจสอบ `auth.identities`/`auth.sessions`/`auth.refresh_tokens` ว่า cascade ครบจริงหรือต้องลบเพิ่มเอง** ตามที่ Product ระบุไว้ชัดเจน
2. Flutter: แก้ `settings_screen.dart` เพิ่ม section, สร้าง `DeleteAccountScreen` ใหม่ตาม Screen section ข้างบนเป๊ะ, `AuthRepository` หรือ repository ใหม่ (`DataRightsRepository`?) เพิ่ม method เรียกทั้ง 2 RPC — ใช้ `SharePlus.instance.share(...)` ให้ตรง API ที่ใช้จริงในแอปนี้ (ไม่ใช่ `Share.share()` เก่า)
3. **ต้องมี regression test พิสูจน์ cascade delete ครบจริง** ที่ SQL layer — สร้าง user จำลองมีข้อมูลครบทุกประเภท (Drop/Pop/Comment/Follow/Save/Club membership/Chat message/Notification setting) แล้วเรียก `delete_my_account()` แล้วยืนยันทุกตารางที่เกี่ยวข้องไม่มีแถวเหลือเลย
4. **ต้องมี regression test พิสูจน์ RPC ทั้ง 2 ตัวผูกกับ `auth.uid()` เท่านั้น** ไม่รับ parameter ระบุ user อื่นได้เลย (function signature ไม่มี parameter สำหรับ user id — ตรวจสอบตรงๆ ว่าไม่มีช่องให้ inject)
