# Design Spec — WYN-046: Platform Documents + Acceptance Flow

อ้างอิง Design System: `.wyn/docs/design/ds-001-color-system.md` (ไม่มีทิศทาง visual ใหม่)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-046-platform-documents-acceptance.md`
อ้างอิง Pattern ที่มีอยู่แล้ว (reuse ตรงๆ): `welcome_screen.dart`'s onboarding layout (`Spacer` + `Padding(horizontal: space6)` + `FilledButton`), `settings_screen.dart`'s section heading + `ListTile` pattern (WYN-027/028/044/045), `report_sheet.dart`'s error/loading state shapes

## ภาพรวม

2 หน้าจอใหม่ (`DocumentAcceptanceScreen`, `DocumentViewerScreen` — generic ใช้ซ้ำได้ทุกประเภทเอกสาร) + แก้ `AuthGate` เพิ่ม gate ใหม่ + แก้ `settings_screen.dart` เพิ่ม section "กฎหมาย" — ไม่มี markdown renderer ในโปรเจกต์นี้ (ตรวจแล้วไม่มี package `markdown`/`flutter_markdown` ใน `pubspec.yaml`) เนื้อหาเอกสารแสดงเป็น plain text ธรรมดา (ย่อหน้าแยกด้วยบรรทัดว่าง) ไม่ต้องเพิ่ม dependency ใหม่

---

## Screen: `DocumentAcceptanceScreen`

Purpose: บังคับให้ผู้ใช้ยอมรับ 3 เอกสารหลัก (ToS/Privacy/Community Guidelines) ก่อนเข้าแอป

User Flow:
1. `AuthGate` ตรวจพบว่ายังไม่ยอมรับเอกสารเวอร์ชันปัจจุบันครบ 3 ฉบับ → แสดงหน้านี้แทนที่จะไปต่อ Username Setup/RootShell
2. เห็นข้อความสรุปสั้นๆ + ลิงก์ข้อความ 3 อัน ("ข้อกำหนดการใช้งาน", "นโยบายความเป็นส่วนตัว", "แนวทางชุมชน") แต่ละอันแตะแล้วเปิด `DocumentViewerScreen` (push ทับ ไม่ replace หน้านี้ — กลับมาหน้ายอมรับได้ปกติ)
3. Checkbox เดียว "ฉันได้อ่านและยอมรับข้อกำหนดการใช้งาน นโยบายความเป็นส่วนตัว และแนวทางชุมชนของ WYN" — ต้องกาถึงจะกดปุ่มยอมรับได้
4. ปุ่ม "ยอมรับและดำเนินการต่อ" (`FilledButton`, เต็มความกว้าง) — enabled เฉพาะ checkbox ติ๊กแล้ว — กด → insert/update 3 แถวใน `user_document_acceptances` พร้อมกัน → `AuthGate` rebuild ไปขั้นต่อไป (Username Setup หรือ RootShell แล้วแต่สถานะ)
5. **ไม่มีปุ่ม "ปฏิเสธ"/"ออกจากระบบ" แยกในหน้านี้** — ผู้ใช้ที่ไม่ยอมรับก็แค่ปิดแอปไป (ไม่มี route อื่นให้ไปจากหน้านี้ตาม intent ของ gate — เหมือน `AccountRestrictedScreen` ที่ไม่มีทางเลี่ยง แต่ต่างตรงที่หน้านี้ไม่มีปุ่ม "ตกลง" ออกจากระบบเพราะยังไม่มี session ให้ sign out แบบมีความหมาย ผู้ใช้ที่ปิดแอปแล้วเปิดใหม่ก็เจอหน้าเดิม)

Components:
- ไม่มี AppBar (มิเรอร์ `WelcomeScreen`/`AccountRestrictedScreen` ที่เป็น "จุดตัดสินใจบังคับ" ไม่มีปุ่ม back)
- Layout: `Spacer` + หัวข้อ + คำอธิบายสั้น + 3 ลิงก์เอกสาร (แนวตั้ง, `TextButton` สไตล์ลิงก์ ขีดเส้นใต้) + `CheckboxListTile` + `FilledButton` + `Spacer`

Interactions:
- Checkbox toggle ธรรมดา ไม่มี optimistic/async (แค่ local state)
- กดปุ่มยอมรับ: `_isSubmitting` guard กันกดซ้ำ, error → SnackBar "ยอมรับไม่สำเร็จ ลองใหม่อีกครั้ง" (ไม่ revert อะไรเพราะยังไม่มีอะไรให้ revert — แค่ retry ปุ่มเดิม)

States:
- Loading (ตอนโหลดว่าต้องยอมรับเอกสารไหนบ้าง — เกิดใน `AuthGate` ไม่ใช่ในหน้านี้เอง ดู Handoff)
- Error ตอนโหลด version ปัจจุบันของเอกสารล้มเหลว: **fail-open** ตาม Product's Risks — ให้ผ่านไปหน้าถัดไปเลยไม่ต้องค้างหน้านี้ (เหมือน moderation status check เดิมใน `AuthGate` ที่ fail-open เช่นกัน)
- Submitting: ปุ่มโชว์ `CircularProgressIndicator` เล็กแทนข้อความ (มิเรอร์ `ReportSheet`'s submit button)

Responsive Behavior: เนื้อหาสั้น ไม่มีความเสี่ยง overflow — `Spacer` ปรับตามความสูงจอเหมือน `WelcomeScreen`

Accessibility: `CheckboxListTile` มี Semantics มาตรฐานอยู่แล้ว, ปุ่มยอมรับที่ disabled ต้องมี label อธิบายเหตุผล (มิเรอร์ `ReportSheet`'s `_canSubmit` pattern: `Semantics(label: 'ยอมรับและดำเนินการต่อ ปิดใช้งานจนกว่าจะติ๊กยอมรับ')`)

Design Rules:
1. **ไม่มีทางเลี่ยง/ข้ามหน้านี้ได้** ถ้ายังไม่ยอมรับครบ 3 ฉบับ — ไม่มีปุ่ม "ข้าม"/"ภายหลัง"
2. **Checkbox เดียวครอบทั้ง 3 เอกสาร** ไม่ใช่ 3 checkbox แยก (Product's Requirement 3)

---

## Screen: `DocumentViewerScreen` (generic, ใช้ซ้ำ 6 ประเภท)

Purpose: แสดงเนื้อหาเอกสารฉบับปัจจุบัน อ่านอย่างเดียว

User Flow: เปิดจาก `DocumentAcceptanceScreen`'s ลิงก์ หรือจาก `SettingsScreen`'s "กฎหมาย" section → โหลดเอกสารประเภทที่ระบุ (เวอร์ชันล่าสุด) → แสดงเนื้อหาเต็ม → ปุ่ม back กลับที่เดิม

Components:
- `AppBar(title: Text(ชื่อเอกสาร))` — มี back button ปกติ (ต่างจาก `DocumentAcceptanceScreen` ที่ไม่มี AppBar เพราะหน้านั้นบังคับ ไม่ให้ย้อนกลับ แต่หน้านี้เป็นแค่หน้าอ่าน ย้อนกลับได้เสมอ)
- `SingleChildScrollView` + `Padding` + `Text(document.content)` (plain text, ใช้ `style: bodyMedium`, ไม่มี rich formatting เพราะไม่มี markdown renderer)
- แสดง `เวอร์ชัน ${version} · มีผลตั้งแต่ ${effective_at แบบวันที่ไทยสั้นๆ}` เป็น subtitle เล็กใต้หัวข้อ ให้ผู้ใช้เห็นว่าเอกสารมีการควบคุมเวอร์ชัน

States: Loading (`CircularProgressIndicator`), Error (ข้อความ + ปุ่ม "ลองใหม่" มิเรอร์ pattern มาตรฐานของแอปนี้ทุกจุด), Loaded

Design Rules:
1. **หน้าเดียวใช้ซ้ำทั้ง 6 ประเภทเอกสาร** ผ่าน parameter `documentType` — ห้ามสร้าง 6 หน้าแยก

## Component แก้ไข: `settings_screen.dart` — เพิ่ม section "กฎหมาย"

เพิ่ม section ใหม่ **ท้ายสุดของหน้า** (หลัง "เครื่องมือผู้ดูแล" conditional section หรือหลัง "ความปลอดภัย" ถ้าไม่ใช่ moderator/admin) — เอกสารกฎหมายเป็นข้อมูลอ้างอิงที่ไม่ค่อยมีคนกดบ่อย เหมาะเป็นรายการสุดท้ายมากกว่าปนกับ section ที่ใช้บ่อย (ความเป็นส่วนตัว/การแจ้งเตือน/ความปลอดภัย) — 6 `ListTile` (ToS/Privacy/Community Guidelines/Copyright/Report/Appeal Policy) เรียงตามลำดับเดียวกับ Master Spec section 27 ทุกอันเปิด `DocumentViewerScreen` ตรงๆ

## Components ที่แก้/สร้างใหม่ (สรุป)
1. **ใหม่**: `DocumentAcceptanceScreen` (`app/lib/features/legal/presentation/`)
2. **ใหม่**: `DocumentViewerScreen` (`app/lib/features/legal/presentation/`)
3. **ใหม่ (ให้ Coding)**: `PlatformDocumentRepository` (`app/lib/features/legal/data/`) — fetch เอกสารล่าสุดต่อประเภท, fetch สถานะการยอมรับของผู้ใช้, upsert การยอมรับ
4. **แก้**: `auth_gate.dart` เพิ่ม gate ใหม่ตามตำแหน่งที่ Product ระบุ (หลัง moderation check, ก่อน username check)
5. **แก้**: `settings_screen.dart` เพิ่ม section "กฎหมาย" ท้ายหน้า

## Non-goals รอบนี้
- ไม่มีหน้า Admin สำหรับแก้เนื้อหาเอกสาร (ยังไม่มี WYN Admin, Phase 7)
- ไม่เก็บประวัติการยอมรับทุกเวอร์ชัน (Product's Requirement 2 — เก็บแค่เวอร์ชันล่าสุดที่ยอมรับ)
- ไม่มี rich text/markdown rendering

## Handoff

ส่งต่อ AI Coding (`/code`):
1. SQL: ตาราง `platform_documents` (RLS select-all-authenticated, ไม่มี insert/update/delete policy ให้ client) + `user_document_acceptances` (RLS จำกัดเจ้าของแถว) ตาม Product spec's schema เป๊ะ — seed ข้อมูล placeholder 6 แถว (version 1 ทุกอัน) ตามเนื้อหาที่ Product กำหนดไว้ใน Requirement 1 (ข้อความ placeholder ที่ระบุชัดเจนว่ายังไม่ใช่ฉบับสมบูรณ์ — **ห้ามเขียนเนื้อหากฎหมายจริงเพิ่มเติมเอง**)
2. Flutter: `PlatformDocumentRepository`, `DocumentAcceptanceScreen`, `DocumentViewerScreen`, แก้ `auth_gate.dart`/`settings_screen.dart` ตามที่ระบุ
3. **AuthGate's gate ต้อง fail-open** เหมือน moderation check เดิม (Product's Risks) — เขียน regression test พิสูจน์ทั้ง fail-open และ gate-blocks-until-accepted
4. Regression: ยืนยัน Suspended/Banned account ยังเจอ `AccountRestrictedScreen` ก่อนเจอ Acceptance gate เสมอ (ลำดับ check ต้องถูกต้อง ไม่ใช่แค่เขียนโค้ดแล้วเดาว่าเรียงถูก)
