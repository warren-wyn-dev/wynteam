# Feature Request — WYN-084

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 22/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: แก้บั๊กช่องพิมพ์ข้อความ (แชท) เด้งขึ้นสูงผิดปกติเมื่อโฟกัส
Goal: ให้ประสบการณ์พิมพ์แชทลื่นไหล ไม่กระโดดแปลกๆ เวลาคีย์บอร์ดเปิด
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ช่องพิมพ์ข้อความ… กดแล้ว ทำไมเด้งไปอยู่สูงจัง ระบบไม่ค่อยเรียบร้อยเลย"
Requirements:
- reproduce บั๊กบนทั้ง iOS/Android แล้วหา root cause (มักเกิดจาก SafeArea/resize behavior ตอนคีย์บอร์ดเปิดในหน้าแชท)
- แก้ให้ช่องพิมพ์อยู่ตำแหน่งติดขอบล่างเหนือคีย์บอร์ดพอดี ไม่กระโดดไปสูงเกินจำเป็น
Acceptance Criteria:
- [ ] เปิดหน้าแชทแล้วแตะช่องพิมพ์ ข้อความ/คีย์บอร์ดขึ้นมาในตำแหน่งที่ถูกต้อง ไม่กระโดดสูงผิดปกติ บนทั้ง iOS และ Android
Dependencies: ไม่มี
Priority: สูง (บั๊กกระทบการใช้งานจริงชัดเจน)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | แก้แล้วกระทบ layout อื่นของหน้าแชท | ต่ำ | เทสหลายขนาดจอ/keyboard type |
Recommendation: อนุมัติ ส่งเข้า AI Debug Engineer เพื่อ reproduce ก่อนแก้
Handoff: AI Debug Engineer หา root cause → AI Coding → AI QA

---

## Coding Output (2026-09-02)

Root cause (reproduce จากอ่านโค้ด ไม่ต้องรันบนเครื่องจริง เพราะ bug เห็นชัดจากโครงสร้าง widget tree): `ConversationScreen`'s `Scaffold` ไม่เคยตั้งค่า `resizeToAvoidBottomInset` เลย ค่า default ของ Flutter คือ `true` — แปลว่า Scaffold ย่อ body ลงตาม `viewInsets.bottom` (ความสูงคีย์บอร์ด) ให้อัตโนมัติอยู่แล้ว แต่ `_buildComposerArea()`'s return เดิมยังห่อด้วย `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: Column(...))` ซ้ำอีกชั้น — เป็นการชดเชยคีย์บอร์ด **สองรอบซ้อนกัน**: Scaffold หด body ไปแล้ว 1 เท่าของความสูงคีย์บอร์ด แล้ว Padding ก็เพิ่ม bottom อีก 1 เท่าของความสูงคีย์บอร์ดทับเข้าไปอีก ผลคือช่องพิมพ์ข้อความเด้งขึ้นสูงเกินจริงไปเกือบสองเท่าของความสูงคีย์บอร์ด ตรงกับที่ Founder บอกว่า "เด้งไปอยู่สูงจัง"

แก้: เอา `Padding` wrapper ออกทั้งหมด คืนค่า `Column(...)` ตรงๆ ให้ Scaffold's `resizeToAvoidBottomInset` (default `true`, ไม่ได้แตะ) เป็นตัวจัดการชดเชยคีย์บอร์ดแค่ชั้นเดียวพอ — เนื้อหาข้างในไม่เปลี่ยน (ปุ่มแนบรูป, ช่องพิมพ์, ปุ่มส่ง, reply/image preview bar, awaiting-response label เหมือนเดิมทุกอย่าง)

Files Changed:
- `app/lib/features/chat/presentation/conversation_screen.dart` — `_buildComposerArea()` เอา `Padding(bottom: MediaQuery.of(context).viewInsets.bottom)` wrapper ออก คืน `Column` ตรงๆ พร้อม comment อธิบาย root cause กันใครใส่กลับเข้ามาซ้ำ
- `app/test/conversation_screen_test.dart` — เพิ่มเทสใหม่ 1 เทส จำลองคีย์บอร์ดเปิด (`tester.view.viewInsets = FakeViewPadding(bottom: 300)`) แล้วยืนยันว่าช่องพิมพ์ (`TextField`) อยู่ตำแหน่ง `screenHeight - keyboardHeight` (ชิดขอบล่างเหนือคีย์บอร์ดพอดี) ไม่ใช่สูงกว่านั้นอีกเกือบเท่าคีย์บอร์ด

Reason: Founder ข้อ 22/28 — "ช่องพิมพ์ข้อความ… กดแล้ว ทำไมเด้งไปอยู่สูงจัง ระบบไม่ค่อยเรียบร้อยเลย"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **882/882 ผ่านหมด** (881 เดิม + 1 เทสใหม่)
- Red→green พิสูจน์จริง: ใส่ `Padding(bottom: viewInsets.bottom)` wrapper กลับเข้าไปชั่วคราว รันเทสใหม่ → **fail ตรงตามคาด** คืนค่ากลับเป็นโค้ดที่แก้แล้ว รันซ้ำ → ผ่าน
- ไม่ได้ทดสอบบนอุปกรณ์จริง (iOS/Android) เพราะ sandbox นี้รัน Flutter app จริงไม่ได้ (ไม่มี simulator/emulator) — ยืนยัน fix ด้วย widget test ที่จำลอง `viewInsets` แทน ตาม acceptance criteria เดิมที่ระบุทั้ง iOS/Android ควรให้ QA ทดสอบบนเครื่องจริงอีกชั้นก่อนปิดงาน

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema ไม่มี migration ที่เกี่ยวข้อง

Known Issues:
- ยังไม่ได้ยืนยันบนอุปกรณ์จริง (เฉพาะ widget test ในนี้) — ขอให้ AI QA & Security ทดสอบบนเครื่องจริงทั้ง iOS/Android ตาม acceptance criteria ก่อนปิดงาน

Handoff: ส่งต่อ AI QA & Security — ทดสอบเปิดหน้าแชทแตะช่องพิมพ์บนอุปกรณ์จริง (iOS + Android) ยืนยันว่าคีย์บอร์ดกับช่องพิมพ์อยู่ตำแหน่งถูกต้อง ไม่กระโดดสูงผิดปกติ ตาม acceptance criteria

---

## QA Report (2026-09-02)

Feature: แก้บั๊กช่องพิมพ์แชทเด้งสูงผิดปกติเมื่อคีย์บอร์ดเปิด (double bottom-inset compensation) (Wynos V1.0.0 Beta2, ข้อ 22/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง — ไม่มี emulator/device จริง ยืนยันความ "ลื่นไหล"/ภาพจริงบนคีย์บอร์ด iOS/Android จริงไม่ได้ในสภาพแวดล้อมนี้

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917 รวมเทสใหม่ของ task นี้)
3. อ่าน `conversation_screen.dart`'s `_buildComposerArea()` — ยืนยัน `Padding(bottom: MediaQuery.of(context).viewInsets.bottom)` wrapper ถูกเอาออกจริง คืน `Column(...)` ตรงๆ, `Scaffold`'s `resizeToAvoidBottomInset` ไม่ถูก override ที่ใดในไฟล์นี้ (default `true`) — root cause "double compensation" ตรงตามที่อธิบาย
4. รันเทสใหม่ `conversation_screen_test.dart`'s "WYN-084: opening the keyboard does not push the composer up by a second keyboard-height" เอง — ผ่าน จำลอง `viewInsets.bottom=300` แล้วยืนยัน `TextField`'s bottom-left อยู่ในช่วง `screenHeight - keyboardHeight` ถึง `screenHeight - keyboardHeight - 200` (ไม่กระโดดเกิน 1 เท่าของความสูงคีย์บอร์ด)
5. พยายามพิสูจน์ red→green ด้วยตัวเองอีกครั้ง (ใส่ `Padding(bottom: viewInsets.bottom)` กลับเข้าไปชั่วคราว) — เทสล้มเหลวจริงตามคาด (`textFieldBottom` หลุดช่วงที่คาดไว้) ยืนยัน fix มีผลจริง ไม่ใช่ assertion หลวมเกินไปจนผ่านได้ทั้งสองแบบ — คืนค่ากลับเป็นโค้ดที่แก้แล้ว
6. เช็คว่าอีก 3 state ของ `_buildComposerArea()` (blocked/suspended/restricted/pending-as-recipient) ไม่ถูกกระทบ — ทั้ง 4 branch ก่อนหน้า `Column` ที่แก้ไม่มีการเปลี่ยนแปลง ยังคง return ตามเดิม

Passed: 1, 2, 3, 4, 5, 6

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — UI layout fix ล้วน ไม่แตะ auth/data/network

Recommendation: อนุมัติ PASS ในระดับ logic (widget test พิสูจน์ red→green ชัดเจน) — **แต่ต้องมีคนทดสอบบนอุปกรณ์จริงทั้ง iOS และ Android ก่อนปิดงานสมบูรณ์ 100%** ตามที่ acceptance criteria ระบุไว้ทั้งสองแพลตฟอร์ม เพราะ `SystemUiOverlayStyle`/keyboard resize behavior มีความต่างจริงระหว่างแพลตฟอร์ม/เวอร์ชัน OS ที่ widget test มองไม่เห็น (เฉพาะ `viewInsets` ที่จำลองขึ้นเอง ไม่ใช่ keyboard event จริง) — ไม่มี emulator ในสภาพแวดล้อมนี้ให้ตรวจเพิ่มได้

Final Status: PASS
