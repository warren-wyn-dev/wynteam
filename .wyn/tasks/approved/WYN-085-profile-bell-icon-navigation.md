# Feature Request — WYN-085

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 23/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: แก้บั๊กปุ่มแจ้งเตือน (bell icon) โผล่ผิดที่บนหน้าโปรไฟล์คนอื่น และกดแล้วนำทางไม่ได้
Goal: หน้าโปรไฟล์คนอื่นไม่ควรมีปุ่มแจ้งเตือนของเราเอง และปุ่ม/การนำทางในหน้านั้นต้องใช้งานได้ปกติ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "หน้าโปรไฟล์คนอื่น มีปุ่มแจ้งเตือนได้ไง กดแล้ว ออกไปหน้าอื่นก็ไม่ได้" (ดูภาพ: วงกลมสีแดงล้อมไอคอนกระดิ่งบนหน้าโปรไฟล์ @wynos_club)
Requirements:
- หา root cause ว่าไอคอนกระดิ่งหลุดมาแสดงบนหน้าโปรไฟล์คนอื่นได้อย่างไร (widget ผิด/reuse component จากหน้า Home ผิดจุด)
- เอาไอคอนกระดิ่งออกจากหน้าโปรไฟล์คนอื่น (ไม่ควรอยู่ตรงนั้นตั้งแต่แรก)
- ตรวจ navigation stack ในหน้านั้นว่าทำไมกดปุ่มอื่นแล้วออกไปหน้าอื่นไม่ได้ (ปุ่ม back/tab เด้งไม่ทำงาน) แล้วแก้ให้กลับมาปกติ
Acceptance Criteria:
- [ ] เปิดโปรไฟล์คนอื่นแล้วไม่มีไอคอนกระดิ่งอีก
- [ ] กดปุ่ม/tab อื่นจากหน้าโปรไฟล์คนอื่นแล้วนำทางออกไปหน้าอื่นได้ปกติ
Dependencies: ไม่มี
Priority: สูง (บั๊ก navigation ตัน กระทบการใช้งานจริง)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | จุดที่ navigation ค้าง อาจกระทบหน้าอื่นที่ใช้ widget เดียวกัน | กลาง | เช็คทุกจุดที่ reuse component เดียวกันหลังแก้ |
Recommendation: อนุมัติ ส่งเข้า AI Debug Engineer
Handoff: AI Debug Engineer หา root cause → AI Coding → AI QA

---

## Coding Output (2026-09-02)

Root cause (พบทั้ง 2 อาการจากจุดเดียวกัน — ไม่ใช่ widget หลุด/reuse ผิดจุด แต่เป็นการเลือก entry point ผิดตอนสร้าง WYN-071):

`ViewProfileScreen` (หน้าโปรไฟล์คนอื่น) มีปุ่มลัด 2 ปุ่มบน AppBar เฉพาะตอนดูโปรไฟล์คนอื่น (`_openSearch`/`_openNotifications`, คอมเมนต์เดิมอ้าง WYN-071 Design Screen 8) — เหตุผลคือหน้านี้ถูก push ทับ stack เดิม ซึ่งซ่อน Bottom Nav ไป เลยใส่ทางลัดเข้าถึง Search/Notifications ไว้แทน

ปัญหาคือ `_openNotifications` push ไปยัง `NotificationListScreen` (02-notifications.tsx) ตรงๆ ซึ่งหน้านั้นถูกออกแบบไว้เฉพาะเป็น **Bottom Nav root destination** เท่านั้น — header เป็น hamburger (☰ เปิด SideMenu drawer) แทนที่จะเป็น AppBar+ปุ่มย้อนกลับ (ดู comment เดิมในไฟล์นั้น: "this screen (like Home) no longer has a use for [an AppBar] now that Search/Notifications are their own Bottom Nav destinations") เพราะฉะนั้นหน้านี้พึ่งพา Bottom Nav ล้วนๆในการนำทางออกไปหน้าอื่น

เมื่อ push `NotificationListScreen` จากหน้าโปรไฟล์คนอื่น (ที่ Bottom Nav ถูกซ่อนไปแล้วจาก push เดิม) ผู้ใช้เลยติดอยู่บนหน้าที่ไม่มีทั้งปุ่มย้อนกลับและ Bottom Nav — ตรงกับอาการ "กดแล้ว ออกไปหน้าอื่นก็ไม่ได้" ทุกประการ ส่วนตัวไอคอนกระดิ่งเองก็ผิดที่อยู่แล้วตามที่ Founder ชี้ (ปุ่มแจ้งเตือนของ "เรา" ไม่ควรอยู่บนโปรไฟล์ "คนอื่น")

เทียบกับ `_openSearch` (ปุ่มค้นหาข้างๆกัน): push ไปยัง `SearchScreen` ซึ่งมี `Scaffold(appBar: AppBar(...))` จริง ได้ปุ่มย้อนกลับอัตโนมัติจาก Flutter เวลาถูก push บน stack ที่ pop ได้ — ปุ่มนี้ไม่มีปัญหา ไม่ได้แตะ

แก้: เอาปุ่มกระดิ่ง (`Icons.notifications_outlined` IconButton) และ `_openNotifications()` ออกจาก `ViewProfileScreen` ทั้งหมด แทนที่จะไปเพิ่มปุ่มย้อนกลับให้ `NotificationListScreen` (ซึ่งจะเป็นการเปลี่ยนดีไซน์หน้าแยกที่ยังใช้เป็น Bottom Nav root อยู่ปกติ กระทบสโคปกว้างกว่าที่ Founder ขอ) — เพราะปุ่มลัดไปหน้า "การแจ้งเตือนของเรา" ไม่ควรอยู่บนโปรไฟล์คนอื่นตั้งแต่แรกอยู่แล้วตามที่ Founder ระบุตรงๆ ("ไม่ควรอยู่ตรงนั้นตั้งแต่แรก")

Files Changed:
- `app/lib/features/profile/presentation/view_profile_screen.dart` — เอาปุ่มกระดิ่งใน AppBar actions (เฉพาะกรณีดูโปรไฟล์คนอื่น) และ method `_openNotifications()` ออก, ลบ import ที่ไม่ได้ใช้แล้ว (`notification_repository.dart`, `notification_list_screen.dart`, `appeal_repository.dart`, `zoky_repository.dart` — ทั้ง 4 ตัวถูกใช้เฉพาะใน `_openNotifications()` เดิมเท่านั้น), อัปเดต comment ที่อ้างถึง `_openNotifications`/"Search/Notifications shortcuts" ให้ตรงกับโค้ดปัจจุบัน
- `app/test/view_profile_screen_test.dart` — เพิ่มเทสใหม่ยืนยันว่าโปรไฟล์คนอื่นไม่มีไอคอนกระดิ่งอีกแล้ว (แต่ไอคอนค้นหายังอยู่ปกติ), อัปเดต comment ที่อ้างถึง `_openNotifications` เดิม

Reason: Founder ข้อ 23/28 — "หน้าโปรไฟล์คนอื่น มีปุ่มแจ้งเตือนได้ไง กดแล้ว ออกไปหน้าอื่นก็ไม่ได้"

Tests:
- `flutter analyze`: สะอาด (รวมถึงยืนยันว่า unused_import ทั้ง 4 ตัวถูกเอาออกครบ)
- `flutter test`: **883/883 ผ่านหมด** (882 เดิม + 1 เทสใหม่)
- Red→green พิสูจน์จริง: ใส่ IconButton กระดิ่งกลับเข้าไปชั่วคราว (onPressed เป็น no-op เพื่อไม่ต้องแก้ import คืนทั้งหมด) รันเทสใหม่ → **fail ตรงตามคาด** คืนค่ากลับเป็นโค้ดที่แก้แล้ว รันซ้ำ → ผ่าน

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- ไม่ได้แก้/แตะ `NotificationListScreen` เอง (ยังไม่มีปุ่มย้อนกลับ) — เพราะยังใช้งานถูกต้องปกติในฐานะ Bottom Nav root destination หน้า Home/Search/Notifications/Profile ปกติ ถ้าในอนาคตมีจุดอื่นอยากลิงก์เข้าหน้านี้แบบ push (ไม่ใช่ Bottom Nav tab) ต้องออกแบบปุ่มย้อนกลับให้หน้านั้นแยกเป็นงานของตัวเอง
- ไม่ได้ทดสอบบนอุปกรณ์จริง เฉพาะ widget test — ขอให้ AI QA & Security ยืนยันซ้ำบนเครื่องจริงตาม acceptance criteria

Handoff: ส่งต่อ AI QA & Security — (1) เปิดโปรไฟล์คนอื่นยืนยันไม่มีไอคอนกระดิ่งอีก (2) ยืนยันปุ่ม/tab อื่นจากหน้าโปรไฟล์คนอื่นนำทางได้ปกติ (3) เช็คแล้วด้วย `grep -rln "NotificationListScreen(" app/lib/` — มีแค่ 2 จุดในโค้ดเบส คือตัวไฟล์ `notification_list_screen.dart` เอง กับ `root_shell.dart` (Bottom Nav root, ถูกต้องแล้ว) ไม่มีจุด push อื่นที่จะเจอบั๊กเดียวกันซ้ำ

---

## QA Report (2026-09-02)

Feature: เอาปุ่มแจ้งเตือน (bell icon) ออกจากหน้าโปรไฟล์คนอื่น แก้ navigation dead-end (Wynos V1.0.0 Beta2, ข้อ 23/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง

Test Cases:
1. `flutter analyze` สะอาดจริง (รวมยืนยันว่าไม่มี unused_import เหลือจาก import ที่ลบ)
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. อ่าน `view_profile_screen.dart`'s AppBar `actions` — ยืนยันกรณี `!isOwnProfile` (โปรไฟล์คนอื่น) เหลือแค่ปุ่มค้นหา (`Icons.search`) + `more_vert` เท่านั้น ไม่มีปุ่มกระดิ่ง/`_openNotifications()` เหลืออยู่แล้วจริง
4. รัน `grep -rln "NotificationListScreen(" app/lib/` เอง — ยืนยัน**ตรงกับที่ Coding Output อ้าง**: มีแค่ 2 จุด (`notification_list_screen.dart` ตัวเอง + `root_shell.dart`'s Bottom Nav root) ไม่มีจุด push อื่นที่จะเจอบั๊ก "ติดหน้าไม่มีทางออก" ซ้ำ
5. อ่าน `NotificationListScreen` เอง — ยืนยันยังใช้ hamburger/SideMenu header ปกติในฐานะ Bottom Nav root ไม่ถูกแตะ ตรงตามที่ Coding Output ไม่ได้เปลี่ยนดีไซน์หน้านั้น
6. ตรวจปุ่มค้นหา (`_openSearch`) ที่ยังอยู่ — push ไป `SearchScreen` ซึ่งมี `Scaffold(appBar: AppBar(...))` จริง ได้ปุ่มย้อนกลับอัตโนมัติจาก Flutter — ไม่มีปัญหาเดียวกัน ยืนยันแล้ว
7. Edge case ที่ลองพยายาม break: ตรวจว่าการลบ import (`notification_repository.dart`, `notification_list_screen.dart`, `appeal_repository.dart`, `zoky_repository.dart`) ไม่ได้ทำให้ field/method อื่นที่ยังต้องใช้ import เหล่านี้พังไปด้วย — `flutter analyze` สะอาดยืนยันแล้วว่าไม่มี broken reference เหลือ

Passed: 1, 2, 3, 4, 5, 6, 7

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — เป็นการลบ entry point ที่ผิดที่ผิดทาง (bell icon ของ "เรา" ไม่ควรอยู่บนโปรไฟล์ "คนอื่น") ไม่มีการเปลี่ยน RLS/auth ใดๆ

Recommendation: อนุมัติ PASS — งานนี้ตรวจได้ครบทั้งหมดด้วยโค้ด/เทสจริง ไม่มี residual ที่ต้องรอมนุษย์ตรวจอุปกรณ์จริงเพิ่มเติมนอกเหนือจากการยืนยันภาพหน้าจอมาตรฐานตามปกติ

Final Status: PASS
