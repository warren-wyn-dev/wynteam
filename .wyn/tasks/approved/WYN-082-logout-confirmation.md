# Feature Request — WYN-082

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 17/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่ม dialog ยืนยันก่อนออกจากระบบ
Goal: ป้องกันผู้ใช้กดออกจากระบบโดยไม่ตั้งใจ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "หน้าการตั้งค่า เรากดออกจากระบบง่ายเกิน กดปุบ ออกปับ ควรถามก่อนดีไหม — ออกจากระบบบัญชีของคุณใช่ไหม / ยกเลิก | ออกจากระบบ"
Requirements:
- กดปุ่ม "ออกจากระบบ" แล้วแสดง dialog ยืนยันตามข้อความที่ Founder ระบุพอดี: หัวข้อ "ออกจากระบบบัญชีของคุณใช่ไหม" ปุ่ม "ยกเลิก" และ "ออกจากระบบ"
- กด "ยกเลิก" ปิด dialog ไม่ทำอะไร, กด "ออกจากระบบ" ค่อย sign out จริง
Acceptance Criteria:
- [ ] กดปุ่มออกจากระบบแล้วต้องเห็น dialog ยืนยันก่อนเสมอ ไม่ sign out ทันที
Dependencies: ไม่มี
Priority: สูง (ง่าย เสี่ยงต่ำ กระทบ UX ปลอดภัยของผู้ใช้ทันที)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ไม่มีความเสี่ยงนัย | ต่ำ | - |
Recommendation: อนุมัติ ทำได้ทันที
Handoff: AI Coding ทำตรงได้เลย

---

## Coding Output (2026-09-02)

Implementation: พบจุดเดียวที่มี `signOut()` จริงที่ผู้ใช้กดเอง — `settings_screen.dart`'s `_signOut()` (โค้ดเดิม comment บอกไว้แล้วว่า WYN-016 ย้าย logout icon จากหน้าโปรไฟล์มารวมไว้ที่นี่ที่เดียว) — เพิ่ม `_confirmSignOut(BuildContext context)` ใหม่ แสดง `AlertDialog` ด้วยข้อความที่ Founder ระบุตรงตัวอักษร (หัวข้อ "ออกจากระบบบัญชีของคุณใช่ไหม" ปุ่ม "ยกเลิก"/"ออกจากระบบ") แล้วเรียก `_signOut()` เดิมเฉพาะกด "ออกจากระบบ" ยืนยันเท่านั้น — เปลี่ยน `onTap` ของแถว "ออกจากระบบ" จาก `_signOut` ตรงๆ เป็น `() => _confirmSignOut(context)`

**ไม่แตะ** `guest_gate.dart`'s `signOut()` (คนละจุด คนละความหมาย — เป็น flow ที่ guest กดฟีเจอร์ที่ต้องมีบัญชีจริงแล้วเลือก "สมัคร/เข้าสู่ระบบ" ซึ่งมี dialog ยืนยันของตัวเองอยู่แล้วชัดเจน ไม่ใช่ log out จากบัญชีจริง)

Files Changed:
- `app/lib/features/settings/presentation/settings_screen.dart`
- `app/test/settings_screen_test.dart` — เพิ่ม 2 เทสใหม่ (กดแล้วเห็น dialog ข้อความตรงตามที่ Founder ระบุ ไม่ sign out ทันที, กด "ยกเลิก" แล้ว dialog หายไปไม่มีอะไรเกิดขึ้น)

Reason: Founder ข้อ 17/28 — "หน้าการตั้งค่า เรากดออกจากระบบง่ายเกิน กดปุบ ออกปับ ควรถามก่อนดีไหม"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **881/881 ผ่านหมด** (879 baseline + 2 ใหม่)

Build: ไม่ได้รัน `flutter build` เต็มรูปแบบ (UI-only change)

Known Issues:
- **ไม่มีเทสสำหรับ path "กดยืนยันแล้ว sign out จริง"** — `_signOut()` เรียก `Supabase.instance.client.auth.signOut()` ตรงๆ ไม่ผ่าน injectable repository (ต่างจาก `delete_account_screen.dart` ที่ใช้ `AuthRepository` แยกทำให้ mock ได้) ยิงเข้า fake test endpoint จริงจะ error/ไม่ปลอดภัยในเทส — ตรวจแค่ path "ยกเลิก" กับ "เห็น dialog" ซึ่งครอบคลุม acceptance criteria หลักที่ Founder ระบุ (ป้องกันกดพลาด) แต่ path ยืนยันจริงยังต้องพึ่งการทดสอบ manual/QA บนอุปกรณ์จริง

Handoff: ส่งต่อ AI QA & Security — ตรวจ manual ว่ากด "ออกจากระบบ" ยืนยันในหน้า dialog แล้ว sign out จริงและนำทางกลับไปหน้า Welcome ถูกต้อง (path ที่ automated test ยืนยันไม่ได้)

---

## QA Report (2026-09-02)

Feature: Dialog ยืนยันก่อนออกจากระบบ (Wynos V1.0.0 Beta2, ข้อ 17/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง — ไม่มี emulator/device จริง ยืนยัน sign-out path จริงปลายทาง (นำทางกลับ Welcome) ไม่ได้ในสภาพแวดล้อมนี้

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. อ่าน `settings_screen.dart`'s `_confirmSignOut` — ข้อความ `AlertDialog` ตรงตามที่ Founder ระบุคำต่อคำ: หัวข้อ "ออกจากระบบบัญชีของคุณใช่ไหม" ปุ่ม "ยกเลิก" / "ออกจากระบบ" — ยืนยันแล้ว **ตรงเป๊ะ** ไม่มีคำเพิ่ม/ขาด
4. ยืนยัน flow: `onTap` ของแถว "ออกจากระบบ" เรียก `_confirmSignOut(context)` เสมอ ไม่มีทางลัดที่ sign out ตรงๆ โดยไม่ผ่าน dialog อีกแล้ว (เทียบกับก่อนหน้าที่กดแล้วออกทันที)
5. กด "ยกเลิก" (`Navigator.pop(dialogContext, false)`) — `confirmed != true` → ไม่เรียก `_signOut()` เลย ถูกต้อง
6. กด "ออกจากระบบ" (`Navigator.pop(dialogContext, true)`) → `confirmed == true` → เรียก `_signOut()` จริง — โค้ดถูกต้องตาม logic แต่ path นี้ไม่มี automated test คุ้มครอง (ตามที่ Coding Output ระบุไว้แล้ว เพราะ `_signOut()` เรียก `Supabase.instance.client.auth.signOut()` ตรงๆ ไม่ผ่าน injectable repository)
7. `guest_gate.dart`'s `signOut()` แยกกันจริง ไม่ถูกแตะ ตรวจแล้วไม่ใช่ path เดียวกัน ไม่กระทบ

Passed: 1, 2, 3, 4, 5, 7

Failed: ไม่มี — 6 เป็น residual ที่ตรวจ logic ได้แต่ไม่มี automated coverage ไม่ใช่ failure

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — เป็นการเพิ่มขั้นตอนยืนยันก่อน sign-out (ลด accidental logout) ไม่ใช่การเปลี่ยน auth architecture ไม่แตะ token/session handling

Recommendation: อนุมัติ PASS — จุดที่ automated test คุ้มครองไม่ได้ (path "กดยืนยันแล้ว sign out จริง + นำทางกลับ Welcome") ต้องให้มนุษย์ทดสอบบนอุปกรณ์จริง/เชื่อมต่อ Supabase จริงอีกชั้นก่อนปิดงานสมบูรณ์ 100% ตามที่ Coding Output เองระบุไว้แล้ว — แนะนำ AI Coding พิจารณาย้าย `_signOut()` ให้ผ่าน injectable `AuthRepository` แบบเดียวกับ `delete_account_screen.dart` ในอนาคต (ไม่ใช่ blocker ของงานนี้) เพื่อให้ path นี้ทดสอบอัตโนมัติได้เต็มรูปแบบ

Final Status: PASS
