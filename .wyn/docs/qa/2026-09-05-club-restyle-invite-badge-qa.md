# QA — Club feed/composer restyle, invite button, unread-badge fixes

วันที่: 2026-09-05
QA โดย: AI QA & Security (session `session_014LEtwe8NjiPLcc9cqJEkuq`)
ขอบเขต: งานทั้งหมดที่ merge เข้า `main` ผ่าน PR #244–#247 บน branch `claude/club-exploration-feature-71rl06`

```
Feature: (1) ฟีดโพสต์ใน Club หน้าตาเหมือน Home (ClubPostCard restyle)
         (2) ปุ่มโพสต์ในคลับเปิดหน้าเหมือนหน้าโพสต์ปกติ (CreateClubPostScreen restyle)
         (3) ปุ่ม "เชิญเพื่อน" ในแท็บ Members ของ Club
         (4) Badge ข้อความ/แจ้งเตือนที่ยังไม่อ่านเปลี่ยนเป็นสีแดง
         (5) แก้บั๊ก badge ข้อความค้าง (ไม่รีเฟรชหลังอ่านข้อความจากที่อื่น)
         (6) สำรวจ Club แทนที่ "โปรไฟล์" ใน side menu (PR #244)

Environment: Flutter 3.47.2 (stable), Dart 3.13.2 — SDK ถูก clone มาไว้ในเครื่อง
             sandbox นี้เองระหว่าง QA รอบนี้ (sandbox เดิมไม่มี Flutter SDK เลย
             ตลอด session ที่ผ่านมา นี่คือครั้งแรกที่รันได้จริงในเครื่อง แทนที่จะ
             พึ่ง CI ของ GitHub เพียงอย่างเดียว) — ทดสอบทั้งบน branch เดิมและบน
             `origin/main` ที่ merge แล้วจริง (ผ่าน git worktree แยกต่างหาก เพื่อ
             ยืนยันว่าสิ่งที่ทดสอบคือสิ่งที่อยู่บน production branch จริง ไม่ใช่แค่
             โค้ดใน branch ของตัวเอง)

Test Cases:
  A. flutter analyze บน main ที่ merge แล้ว
  B. flutter test เต็มชุดบน main ที่ merge แล้ว
  C. Regression: club_posts_tab_test.dart, create_club_post_screen_test.dart,
     club_members_tab_test.dart, club_page_test.dart, home_feed_screen_test.dart,
     side_menu_test.dart (ครอบคลุมทั้ง 6 งานข้างต้น)
  D. Ad-hoc "พยายาม break": ClubPostCard ที่ 320px (iPhone SE) พร้อมชื่อผู้โพสต์
     ยาวมาก + ยอดไลก์/คอมเมนต์ 4-5 หลัก
  E. Ad-hoc "พยายาม break": CreateClubPostScreen ที่ 320px พร้อมชื่อ Club ยาวมาก
     + พิมพ์ข้อความ 300 ตัวอักษร
  F. Ad-hoc "พยายาม break": ปุ่ม "เชิญเพื่อน" ในแท็บ Members ที่ 320px พร้อมมี
     pending request ที่ username ยาว
  G. Security: ตรวจ authorization ของปุ่มเชิญเพื่อน, ตรวจว่าไม่มี secret หลุดใน diff,
     ตรวจว่าไม่มีการแตะ RLS/backend ใหม่
  H. ตรวจสี badge ว่าเป็นสีแดงจริง (ไม่ใช่แค่ตั้งชื่อตัวแปรว่า error)

Passed: A, B (1199/1199), C, D, E, F, G, H — ทั้งหมด
Failed: (ไม่มี ณ จุดที่ QA รอบนี้เริ่ม — ดูหมายเหตุสำคัญด้านล่าง)

Severity: N/A (ไม่มีบั๊กเหลืออยู่ตอนสรุปผล)

Reproduction Steps / Expected / Actual:
  ดูรายละเอียดกรณีทดสอบแต่ละอันด้านบน — ทุกอันรันจริงด้วย flutter analyze /
  flutter test / ad-hoc widget test แล้วผลตรงตามคาด (ไม่มี exception, ไม่มี
  overflow, ปุ่ม/สี/ข้อความแสดงถูกต้อง)

  **หมายเหตุสำคัญ (พบและแก้ไปแล้วก่อนเริ่ม QA รอบนี้ ไม่ใช่ระหว่าง QA):**
  ระหว่างเตรียม deploy (ก่อนเรียก QA formal) พบว่า `main` มี CI แดงจริง 2 รอบ
  ติดกัน (PR #245, #246) เพราะ sandbox ของ Coding ไม่มี Flutter SDK ให้รัน
  `flutter analyze`/`flutter test` ก่อน push:
    1. `flutter analyze` fail: `prefer_const_constructors` ที่
       `create_club_post_screen.dart:238` — lint เฉยๆ ไม่กระทบผู้ใช้จริง
    2. **บั๊กจริง**: `ClubPostCard` ที่ restyle ใหม่ใช้ `Flexible` ผิดที่ (ใน
       `Column` ที่มีแค่ width constraint ไม่มี height constraint) ทำให้
       RenderFlex layout fail ทุกเฟรม จน semantics tree พังและ
       `pumpAndSettle` timeout จริง — reproduce ได้แน่นอนด้วย
       `club_posts_tab_test.dart` (3/6 tests แดง รวมถึง regression test
       เดิม DS-005) แก้แล้วโดยลบ `Flexible` ที่ไม่จำเป็นออก (Text ที่เหลือ
       ellipsize ถูกต้องอยู่แล้วเพราะ width ถูกจำกัดจาก Expanded ของ Row
       ข้างนอกอยู่แล้ว) ยืนยันด้วย flutter test เต็มชุดผ่าน 1199/1199 ก่อน
       push เป็น PR #247 และ merge เข้า main สำเร็จ (CI เขียวจริง, run #150)
  ทั้งสองจุดถูกแก้และ merge เข้า main **ก่อน** QA รอบนี้เริ่มทำงานจริง —
  บันทึกไว้ที่นี่เพื่อความโปร่งใสของกระบวนการ (ตาม WORKFLOW.md ข้อ
  "Regression Test Memory") ไม่ใช่ QA รอบนี้เป็นคนพบบั๊ก

Security Findings:
  - ปุ่ม "เชิญเพื่อน" gate ด้วย `widget.myRole != null` (ต้องเป็นสมาชิกที่
    approved แล้วเท่านั้น) ถูกต้องตรงกับที่ตั้งใจ — ไม่มีช่องให้ non-member
    เข้าถึงปุ่มนี้
  - ปุ่มเชิญใช้ flow `showShareSheet`/`ShareToChatScreen` เดิมที่มีอยู่แล้ว
    (ไม่ได้เพิ่ม backend/RPC/RLS ใหม่ใดๆ) — ไม่มี attack surface ใหม่
  - ตรวจ diff ทั้งหมดของ PR #244–#247 ด้วย grep หา API key/secret/token —
    ไม่พบสิ่งผิดปกติ
  - ไม่มีการแก้ไข authentication/authorization architecture หรือ database
    schema ใดๆ ในงานชุดนี้ (เป็น UI restyle + client-side lifecycle refresh
    + การเชื่อมปุ่มใหม่เข้ากับ flow เดิมล้วนๆ)

Recommendation:
  - PASS ให้ AI Deploy & DevOps ดำเนินการ deploy ต่อได้
  - งานนี้ไม่มี database migration ต้องรอ Founder รันเอง (ไม่แตะ schema เลย)
  - แนะนำให้ Coding role ในอนาคต **ยืนยันด้วย real Flutter SDK ก่อน push
    เสมอเมื่อทำได้** (sandbox เดิมไม่มี SDK ติดตั้งไว้ — ควร clone
    `flutter/flutter` (branch stable) มาไว้ใช้ทุกครั้งที่เริ่มงาน coding/QA
    เพื่อลดความเสี่ยงแบบเดียวกับ CI แดง 2 รอบที่เจอรอบนี้)

Final Status: PASS
```
