# Design — WYN-037 (Edit / Delete Drop)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-037-edit-delete-drop.md` — อ่านก่อนเริ่ม
> ต่อยอดโดยตรงจาก `DropDetailScreen` (WYN-005) และ Settings screen pattern ที่มีอยู่แล้ว (`BlockedListScreen`/`MutedListScreen` เข้าจาก `SettingsScreen`)
> Design system: Cyan `#00C8FF` เป็น primary ตาม DS-001–008 — ไม่มี Rainbow (DS-009) จุดไหนใน task นี้

## ภาพรวม — 3 การตัดสินใจเชิง scope

1. **ไม่มี raw client UPDATE/DELETE บน `drops` เลย — ทุกอย่างผ่าน RPC 3 ตัว** (`edit_drop`/`soft_delete_drop`/`restore_drop`) มิเรอร์ pattern เดียวกับ `create_poll_drop()`/`apply_moderation_action()` — Product ตัดสินใจไว้แล้วเพราะกฎ (กรอบเวลา 30 นาที/30 วัน, เจ้าของเท่านั้น) ซับซ้อนกว่าที่ RLS ตรงๆ ทำได้สะอาด
2. **แก้ไขแคปชันใช้ plain `TextField` ธรรมดา ไม่ใช่ `MentionInput`** — ตัดใจเรื่อง mention resolution ใหม่ตอนแก้ไขออกไปเลย (Product ยอมรับเป็น scope reduction แล้ว มิเรอร์ WYN-036) ทำให้หน้าจอแก้ไขเรียบง่ายมาก ไม่ต้องมี dependency กับ `ProfileRepository` สำหรับ autocomplete
3. **RLS ที่ table เดียว (`drops`) พอสำหรับซ่อน Drop ที่ถูกลบทุกที่** — ไม่ต้องแก้ `home_feed`/`saved_feed` view เลยแม้แต่บรรทัดเดียว เพราะทั้งสอง view เป็น `security_invoker = true` และ join ตรงกับ `public.drops`/`public.redrops` — ขยาย SELECT policy จุดเดียวก็ครอบคลุม Home Feed, Search, Profile grid, และ ReDrop's join ไปพร้อมกันหมด

---

## Screen 1 — เมนู "เพิ่มเติม" ของ Drop ตัวเอง (ใน `DropDetailScreen`)

**Purpose**: จุดเข้าเดียวของ Edit/Delete แทนที่ปุ่มลบเดี่ยวๆ เดิม

**เดิม**: `isOwnDrop` แสดง `IconButton(Icons.delete_outline)` เดี่ยวๆ เรียก `_deleteDrop()` ตรง — คนอื่นแสดง `IconButton(Icons.more_vert)` เรียก `_openDropMoreMenu()` (มีแค่ "รายงานโพสต์")

**ใหม่**: `isOwnDrop` เปลี่ยนเป็น `IconButton(Icons.more_vert)` เรียก `_openOwnDropMoreMenu()` ใหม่ — `showModalBottomSheet` แบบเดียวกับ `_openDropMoreMenu()` เดิม มี:
- `ListTile("แก้ไข", Icons.edit_outlined)` — **แสดงเฉพาะเมื่อ `_drop.createdAt` ยังอยู่ในกรอบ 30 นาที** (`DateTime.now().difference(_drop.createdAt) < Duration(minutes: 30)`) — เกินเวลาแล้วเมนูมีแค่ "ลบ" อย่างเดียว
- `ListTile("ลบ", Icons.delete_outline, สีแดง)` — เสมอ

**Interactions**: "แก้ไข" → ปิด bottom sheet → เปิด Screen 2 — "ลบ" → ปิด bottom sheet → เรียก `_deleteDrop()` เดิม (แค่เปลี่ยน RPC ข้างในจาก `deleteDrop()` เป็น `softDeleteDrop()`, ข้อความ dialog เปลี่ยนตาม Screen 3)

---

## Screen 2 — แก้ไขแคปชัน (`EditDropCaptionScreen`)

**Purpose**: หน้าจอเรียบง่ายแก้ไขแค่แคปชัน/คำถามโพล ไม่มีอะไรอื่นให้แก้

**Components**: `Scaffold` เล็กๆ — AppBar title "แก้ไข Drop" ปุ่ม "บันทึก" (`TextButton`, มุมขวา, disabled ถ้าข้อความไม่เปลี่ยนจากเดิมหรือกำลังบันทึกอยู่) — body มี `TextField` เดียว (multiline, maxLength 500 มิเรอร์ `drops_caption_length`) prefill ด้วยแคปชัน/คำถามปัจจุบัน

**Interactions**: กด "บันทึก" → เรียก `editDrop(dropId, caption)` → สำเร็จ `pop(true)` กลับไป `DropDetailScreen` (ซึ่งต้อง reload แคปชัน+`editedAt` ใหม่จาก return value) → ล้มเหลว snackbar error อยู่หน้าเดิมต่อ

**States**: กำลังบันทึกอยู่ → ปุ่ม "บันทึก" โชว์ spinner เล็ก กันกดซ้ำ (มิเรอร์ `_isSharing` pattern ของ `CreateDropScreen`)

---

## Screen 2b — ป้าย "แก้ไขแล้ว" (ใน `DropDetailScreen`/`HomeDropCard`)

**Purpose**: บอกผู้ดูตรงๆ ว่าเนื้อหาถูกแก้ไข ไม่ใช่ของเดิมทั้งหมด

**Components**: ถ้า `_drop.editedAt != null` แสดงข้อความเล็ก `"· แก้ไขแล้ว"` ต่อท้ายเวลาโพสต์ (สีเดียวกับ timestamp, `textTheme.bodySmall`/`outline` — ไม่เด่นเกินไป มิเรอร์ความสำคัญระดับเดียวกับ timestamp เอง)

---

## Screen 3 — Dialog ยืนยันลบ (ปรับข้อความ `confirmDeleteDrop`)

**Purpose**: สื่อสารว่ากู้คืนได้ ไม่ใช่ลบถาวรทันที — ต่างจาก `confirmDeletePost` ทั่วไปที่สื่อว่าลบถาวร

**Components**: ยังใช้ `AlertDialog` เดิม (`confirm_delete_dialog.dart`) แต่ `DropDetailScreen`'s `_deleteDrop()` เปลี่ยนไปเรียก dialog เฉพาะของ Drop ใหม่ (`confirmSoftDeleteDrop`) ที่มีข้อความรอง (subtitle) เพิ่มเติมสื่อว่า "กู้คืนได้ภายใน 30 วันจากรายการที่ลบใน การตั้งค่า" — ปุ่มยืนยัน/ยกเลิกเหมือนเดิมทุกจุด (ไม่เปลี่ยนโครง แค่เปลี่ยนคำ)

---

## Screen 4 — "รายการที่ลบ" (`RecentlyDeletedDropsScreen`)

**Purpose**: ที่เดียวที่เจ้าของเห็น Drop ที่ตัวเองลบไว้และยังกู้คืนได้

**ตำแหน่ง**: `ListTile` ใหม่ใน `SettingsScreen` ต่อจากกลุ่ม "ความปลอดภัย" เดิม (`บัญชีที่ถูกบล็อก`/`บัญชีที่ปิดเสียง`) — icon `Icons.restore_from_trash_outlined`, title "รายการที่ลบ" — เข้าถึงได้เฉพาะเจ้าของบัญชีเองอยู่แล้วโดยธรรมชาติ (Settings เป็นหน้าของตัวเองเท่านั้น ไม่ต้องเช็คเพิ่ม)

**Components**: List ธรรมดา (ไม่ใช่ grid — จำนวนที่ลบมักน้อย ไม่ต้อง 3 คอลัมน์) แต่ละแถวแสดง thumbnail เล็ก (รูปหรือ `PollPlaceholderTile` ย่อ) + แคปชันตัดคำ + "ลบเมื่อ [เวลา]" + ปุ่ม "กู้คืน" (`OutlinedButton`) ท้ายแถว

**Interactions**: กด "กู้คืน" → เรียก `restoreDrop(dropId)` optimistic-remove แถวนั้นออกจาก list ทันที (มิเรอร์ pattern เดียวกับ `ProfileDraftsTab._deleteDraft`) → ล้มเหลว revert + snackbar error

**States**: ว่างเปล่า → "ไม่มี Drop ที่ลบไว้" — Drop ที่เกิน 30 วันแล้วจะไม่โผล่ในนี้อีกต่อไป (query กรอง `deleted_at > now() - 30 days` ฝั่ง client เพื่อไม่โชว์ปุ่มกู้คืนที่กดแล้วจะ error แน่ๆ — RPC ฝั่ง server ก็ปฏิเสธซ้ำอีกชั้นอยู่ดี ไม่ใช่ trust ฝั่ง client อย่างเดียว)

---

## Handoff (ไปยัง AI Coding)

**Schema ที่แนะนำ**:
1. เพิ่ม 2 คอลัมน์บน `drops`: `edited_at timestamptz` (null จนกว่าจะแก้ไขครั้งแรก), `deleted_at timestamptz` (null = ยังไม่ถูกลบ)
2. RPC 3 ตัว (SECURITY DEFINER, ทุกตัวเช็คเจ้าของก่อนเสมอ): `edit_drop(p_drop_id, p_caption)` (เช็คยังไม่ถูกลบ + `created_at > now() - interval '30 minutes'`, ตั้ง `caption`/`edited_at`), `soft_delete_drop(p_drop_id)` (เช็คยังไม่เคยลบ, ตั้ง `deleted_at = now()`), `restore_drop(p_drop_id)` (เช็คลบไปแล้ว + `deleted_at > now() - interval '30 days'`, ตั้ง `deleted_at = null`)
3. **ลบ policy "Users can delete their own drops" (DELETE ตรง) ทิ้ง** — self-delete ต้องผ่าน `soft_delete_drop()` เท่านั้น — `apply_moderation_action()`'s hard-delete ของ moderator ไม่กระทบ (คนละ RPC, SECURITY DEFINER ข้าม RLS อยู่แล้ว)
4. ขยาย SELECT policy ของ `drops` (drop เดิม + create ใหม่): เพิ่ม `and (deleted_at is null or auth.uid() = author_id)` ต่อจาก `not internal.is_blocked_either_way(...)` เดิม
5. ขยาย SELECT policy ของ `drop_comments` เช่นกัน: เพิ่มเช็คว่า Drop แม่ยังมองเห็นได้อยู่ (`exists (select 1 from public.drops d where d.id = drop_comments.drop_id and (d.deleted_at is null or d.author_id = auth.uid()))`) — ปิดช่องทางอ้อมเห็น comment ของ Drop ที่ถูกซ่อนไปแล้ว
6. ไม่ต้องแก้ `home_feed`/`saved_feed` view, ไม่ต้องแก้ `redrops` table/policy ใดๆ เลย — ข้อ 4 ครอบคลุมหมดผ่าน RLS join

**Flutter ที่แนะนำ**: `Drop` model เพิ่ม field `editedAt`/`deletedAt` (nullable) — `DropRepository` เพิ่ม `editDrop()`/`softDeleteDrop()`/`restoreDrop()`/`fetchDeletedDrops()` (ตัว `deleteDrop()` เดิมลบทิ้งหรือเปลี่ยนไปเรียก `softDeleteDrop()` แทนก็ได้ ให้ Coding ตัดสินใจตามความสะดวกของ call site เดิม) — widget ใหม่: `EditDropCaptionScreen`, `RecentlyDeletedDropsScreen`, dialog ใหม่ `confirmSoftDeleteDrop` (หรือแก้ `confirm_delete_drop_dialog.dart` เดิมให้มี subtitle) — `DropDetailScreen` เปลี่ยนปุ่มลบเดี่ยวเป็นเมนู `more_vert` ใหม่ + แสดงป้าย "แก้ไขแล้ว" — `SettingsScreen` เพิ่ม `ListTile` ใหม่
