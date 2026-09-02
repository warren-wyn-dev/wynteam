# Feature Request — WYN-078

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 5 (ส่วนพื้นหลัง)/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: แก้พื้นหลัง WYNOS ให้เต็มจอ (ไม่มีขอบเหลือด้านบน)
Goal: หน้าจอดูสะอาด เต็มพื้นที่ ไม่มี gap สีที่ผิดเพี้ยนด้านบน
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "สีพื้นหลังของ WYNOS ไม่เป็นจอ เหลือด้านบน" (ดูภาพหน้าโปรไฟล์ในเอกสารประกอบ)
Requirements:
- หา root cause ของช่องว่าง/สีที่โผล่เหนือ SafeArea หรือ AppBar ในหน้าโปรไฟล์ (และเช็คหน้าอื่นที่ใช้ layout เดียวกัน)
- แก้ให้สีพื้นหลังคลุมเต็มจอสม่ำเสมอทุกหน้า
Acceptance Criteria:
- [ ] หน้าโปรไฟล์และหน้าหลักอื่นๆ ไม่มีขอบ/ช่องว่างสีผิดปกติด้านบนอีก บนอุปกรณ์หลายขนาดจอ (รวม notch/dynamic island)
Dependencies: ไม่มี
Priority: สูง (bug กระทบภาพรวมทั้งแอป)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | แก้แล้วกระทบ SafeArea ของหน้าอื่นที่ไม่ได้ตั้งใจ | ต่ำ | เทสทุกหน้าหลักหลังแก้ |
Recommendation: อนุมัติ ทำเป็น bug fix ตรง ไม่ต้อง Design spec
Handoff: AI Coding → AI QA ตรวจซ้ำหลายขนาดจอ

---

## Coding Output (2026-09-02)

Implementation: root cause คือ **ทั้งแอปไม่เคยเรียก `SystemChrome.setSystemUIOverlayStyle` เลยแม้แต่ครั้งเดียว** (grep ยืนยันแล้ว, ไม่มี `AppBarTheme`/`systemOverlayStyle` ใน `wyn_theme.dart` ด้วย) — โดยปริยาย OS จะวาด status bar (และบน Android ยุค edge-to-edge บังคับ อาจรวม navigation bar) ด้วยสีของตัวเอง (มักเป็นขาว/ดำ ขึ้นกับแพลตฟอร์ม/เวอร์ชัน) ทับอยู่เหนือพื้นหลัง `WynColors.paper` (#FAF9F6 สีครีม) ของแอป ทำให้เห็นเป็นแถบสีเพี้ยนไม่กลืนกับพื้นหลังที่ขอบบนจอ (และขอบล่างบน Android) ตรงกับที่ Founder อธิบาย "สีพื้นหลังของ WYNOS ไม่เป็นจอ เหลือด้านบน" — Scaffold's background เองถูกต้องอยู่แล้วทุกหน้า (ไม่มี `scaffoldBackgroundColor` explicit แต่ Material 3 ThemeData default ไปที่ `colorScheme.surface` ซึ่งตั้งเป็น `WynColors.paper` อยู่แล้วใน `wyn_colors.dart`)

Files Changed:
- `app/lib/main.dart` — เพิ่ม `SystemChrome.setSystemUIOverlayStyle(...)` ก่อน `runApp()`: status bar โปร่งใส + ไอคอนสีเข้ม (เพราะพื้นหลังสว่าง), Android navigation bar สี `WynColors.paper` + ไอคอนสีเข้ม เรียกครั้งเดียวระดับแอป ครอบคลุมทุกหน้าจอไม่ต้องแก้ทีละ Scaffold

Reason: Founder ข้อ 5 (ส่วนพื้นหลัง)/28 — "สีพื้นหลังของ WYNOS ไม่เป็นจอ เหลือด้านบน"

Tests:
- `flutter analyze`: สะอาด ไม่มี issue
- `flutter test test/widget_test.dart` (app-level smoke test ที่ build `WynApp`/`MaterialApp` จริง): 3/3 ผ่าน
- `flutter test` เต็ม suite: **871/871 ผ่านหมด** ไม่มี regression

Build: ไม่ได้รัน `flutter build` จริง (ไม่มี Android SDK/Xcode ใน sandbox นี้) — การเปลี่ยนแปลงจำกัดอยู่ที่ system UI overlay call เดียว ความเสี่ยง build-break ต่ำมาก แต่ **ควรตรวจบนอุปกรณ์จริงทั้ง iOS/Android เพราะ SystemUiOverlayStyle behavior ต่างกันบางจุดระหว่างแพลตฟอร์ม/เวอร์ชัน OS และ widget test เห็นผลนี้ไม่ได้ (เป็น platform channel call ล้วนๆ)**

Known Issues:
- **ไม่ได้แก้ `seller_app/`** (ZOKY Sellers by WYN) แม้จะมี main.dart แยกที่ไม่มี SystemChrome เรียกเหมือนกันทุกประการ (พบระหว่างตรวจ) — Founder's PDF พูดถึงเฉพาะแอป WYNOS consumer social เท่านั้น ไม่ได้กล่าวถึง seller app เลย จึงไม่แตะตามหลัก "เปลี่ยนแปลงเฉพาะส่วนที่จำเป็น" — ถ้า Founder อยากให้แก้ seller_app ด้วย เป็นงาน follow-up เล็กๆ ที่ mirror โค้ดเดียวกันได้ทันที
- ไม่สามารถ verify ภาพจริงบนอุปกรณ์ได้ในสภาพแวดล้อมนี้ (ไม่มี emulator/device) — QA ควรตรวจภาพจริงเทียบกับภาพที่ Founder แนบมาก่อนปิดงาน

Handoff: ส่งต่อ AI QA & Security — ตรวจภาพจริงบนอุปกรณ์/emulator ทั้ง iOS และ Android (โดยเฉพาะ Android เวอร์ชันใหม่ที่บังคับ edge-to-edge) ว่าแถบสีที่ขอบบน/ล่างจอกลืนกับ `WynColors.paper` แล้วจริง ไม่ใช่แค่ analyze/test สะอาด

---

## QA Report (2026-09-02)

Feature: แก้พื้นหลัง WYNOS ให้เต็มจอ ไม่มีขอบ/แถบสีเพี้ยนด้านบน (Wynos V1.0.0 Beta2, ข้อ 5/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` (Flutter 3.47.2) จริงในเครื่อง sandbox — **ไม่มี emulator/device จริง** ในสภาพแวดล้อมนี้ ยืนยันภาพจริงบนหน้าจอไม่ได้ (ตามที่ทุก task บันทึกไว้แล้ว, `SystemChrome.setSystemUIOverlayStyle` เป็น platform channel call ล้วนๆ ที่ widget test มองไม่เห็นผลจริง)

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. อ่าน `app/lib/main.dart` — ยืนยันมีการเรียก `SystemChrome.setSystemUIOverlayStyle(...)` ก่อน `runApp()` จริง ค่าที่ตั้ง (`statusBarColor: Colors.transparent`, `statusBarIconBrightness: Brightness.dark`, `systemNavigationBarColor: WynColors.paper`, `systemNavigationBarIconBrightness: Brightness.dark`) สอดคล้องกับพื้นหลังสว่าง (`paper` #FAF9F6) ถูกต้องตามหลักการที่อธิบายไว้
4. `grep` ยืนยันว่าไม่มีการเรียก `SystemChrome`/`AppBarTheme.systemOverlayStyle` ซ้ำซ้อนที่อื่นในแอปที่อาจ override ค่านี้ทับ
5. ยืนยัน `Scaffold`s ทุกหน้าหลักไม่ตั้ง `scaffoldBackgroundColor` เอง (ปล่อยให้ Material 3's `colorScheme.surface` = `WynColors.paper` ทำงาน) — ตรงตามคำอธิบาย root cause

Passed: 1, 2, 3, 4, 5

Failed: ไม่มี (ในขอบเขตที่ตรวจได้จริงในสภาพแวดล้อมนี้)

Severity: N/A (PASS พร้อม residual)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — UI-only change ระดับแอป ไม่แตะ auth/data

Recommendation: อนุมัติ PASS ในระดับโค้ด/logic แต่**ยังไม่สามารถยืนยันภาพจริงบนอุปกรณ์ได้ในสภาพแวดล้อมนี้เด็ดขาด** — นี่คือ platform channel behavior ล้วนๆ ที่ต่างกันจริงระหว่าง iOS/Android เวอร์ชัน (โดยเฉพาะ Android edge-to-edge บังคับใน Android 15+) ต้องมีมนุษย์ตรวจบนอุปกรณ์จริงเทียบกับภาพที่ Founder แนบมาก่อนถือว่าปิดงานสมบูรณ์ 100% ตามที่ Coding Output เองระบุไว้แล้ว — แนะนำให้ AI Deploy & DevOps/Founder ยืนยันภาพจริงในขั้นถัดไปก่อน sign-off เต็มรูปแบบ ไม่ควรถือว่า "เสร็จสมบูรณ์" จนกว่าจะมีคนเห็นหน้าจอจริง

Final Status: PASS
