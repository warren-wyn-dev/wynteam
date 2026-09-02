# Feature Request — WYN-090

Status: QA PASS — approved (2026-09-02)
Phase: Phase 2 — UI redesign
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 12/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: ตัดแท็บ "ล่าสุด" ออกจากหน้า Home feed เหลือแค่ 3 แท็บ
Goal: ลดความซับซ้อนของหน้า Home ให้เหลือแค่ "สำหรับคุณ, ติดตาม, จาก Club ของคุณ" ตามที่ Founder ต้องการ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ตรงนี้ "สำหรับคุณ,ติดตาม,Club ของคุณ" อยากให้มีแค่นี้ ตัด "ล่าสุด" ออก"
Requirements:
- เอาแท็บ "ล่าสุด" ออกจาก TabBar หน้า Home
- ตรวจว่า route/state ที่ผูกกับแท็บ "ล่าสุด" (ถ้ามี deep-link ตรงมา) ไม่พังหลังตัดออก
Acceptance Criteria:
- [ ] หน้า Home เหลือแค่ 3 แท็บ: สำหรับคุณ / ติดตาม / จาก Club ของคุณ
Dependencies: ไม่มี
Priority: สูง (ง่าย เสี่ยงต่ำ)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ถ้ามี deep-link ตรงไปแท็บ "ล่าสุด" จากที่อื่นในแอป อาจพัง | ต่ำ | grep หา reference ก่อนลบ |
Recommendation: อนุมัติ ทำได้ทันที
Handoff: AI Coding ทำตรงได้เลย

---

## Design Output (2026-09-02)

Grep `_HomeFeedMode.latest` ทั้ง repo ยืนยันว่ามีแค่ 3 จุดในไฟล์เดียว (`home_feed_screen.dart`) ไม่มี deep-link จากที่อื่นเลย — ปิด Risk R1 ได้เลย ไม่พบความเสี่ยงจริง ลบ enum value + tab entry + label + switch case ได้ตรงๆ ลำดับ 3 แท็บที่เหลือ (สำหรับคุณ/ติดตาม/จาก Club ของคุณ) คงเดิม ไม่แตะสไตล์แท็บที่มีอยู่แล้ว

Design doc เต็ม: `.wyn/docs/design/wyn-090-home-tabs-remove-latest.md`

**ไม่มีอะไรบล็อก — พร้อมขึ้นโค้ดทันที**

---

## Coding Output (2026-09-02)

Root cause / สิ่งที่เปลี่ยน: ไม่ใช่บั๊ก — เป็นการลบ element ตามที่ Founder ระบุตรงๆ (ข้อ 12/28) ตรวจโค้ดตาม Design spec แล้วพบว่า `_HomeFeedMode.latest` มีอยู่ 3 จุดตรงตามที่ AI Design ตรวจไว้จริง (enum, `_fetchPage()`'s switch, `_buildFeedModeToggle()`'s `modes`/`labels`) — ลบทั้ง 3 จุด ไม่แตะ `HomeRepository.fetchFeed()` (repository method ที่ `latest` เคยเรียก) ตามคำแนะนำของ Design spec (เก็บไว้เป็น method ทั่วไปที่อาจมีประโยชน์ในอนาคต ไม่ใช่ dead code ที่ต้องลบ) ลำดับ 3 แท็บที่เหลือ (สำหรับคุณ → ติดตาม → จาก Club ของคุณ) คงเดิมเป๊ะ ไม่แตะสไตล์แท็บ

Files Changed:
- `app/lib/features/home/presentation/home_feed_screen.dart` — ลบ `_HomeFeedMode.latest` ออกจาก enum, `_fetchPage()`'s switch case, `_buildFeedModeToggle()`'s `modes` list และ `labels` map
- `app/test/home_feed_screen_test.dart` — ปรับเทสที่เคยแตะแท็บ "ล่าสุด": (1) แทนที่เทส "all 4 segments...are present" ด้วยเทสใหม่ "only 3 segments...are present -- ล่าสุด was removed" (ยืนยัน `findsNothing` สำหรับ "ล่าสุด") (2) ลบ 2 เทสที่ทดสอบพฤติกรรม tap แท็บ "ล่าสุด" โดยตรง ("switching to ล่าสุด shows the chronological feed", "switching back to สำหรับคุณ from ล่าสุด") เพราะพฤติกรรมนี้ถูกถอดออกตามที่ Founder สั่ง ไม่มีอะไรให้ทดสอบอีกต่อไป (3) เปลี่ยนจุดที่เคย tap "ล่าสุด" เพื่อทดสอบเรื่องอื่น (Rainbow accent dot / checkmark icon off) ให้ tap "ติดตาม" แทน — สาระของเทสเดิม (verify 1 accent dot, verify no checkmark icon) ไม่เปลี่ยน แค่เปลี่ยน tab ที่ใช้กระตุ้น (4) ลบ "ล่าสุด" ออกจาก label-legibility loop 2 จุด (5) fixture data (`_dropItem(id: 'latest-only', caption: 'จากล่าสุด')`) และ trivial `findsNothing` assertions ที่เหลืออยู่ไม่ต้องแก้ — ไม่ผูกกับแท็บที่ถูกลบ เป็นแค่ชื่อ fixture ของ `fetchFeed()`'s mock data ซึ่งยัง valid อยู่ (method ยังอยู่ ไม่ได้ลบ)

Reason: Founder ข้อ 12/28 — "สำหรับคุณ,ติดตาม,Club ของคุณ" อยากให้มีแค่นี้ ตัด "ล่าสุด" ออก"

Tests:
- `flutter analyze`: สะอาด (ไม่มี warning/error)
- `flutter test`: **885/885 ผ่านหมด** (887 เดิมจาก Phase 1 − 2 เทสที่ลบทิ้งเพราะพฤติกรรมถูกถอดออก = 885)
- Red→green พิสูจน์จริง: `git stash push -- app/lib/.../home_feed_screen.dart` (เก็บเฉพาะไฟล์โค้ด ไม่แตะไฟล์เทส) แล้วรันเทสใหม่ `only 3 segments...` ด้วย `--plain-name` → **fail ตรงตามคาด** (`find.text('ล่าสุด')` เจอ 1 widget ทั้งที่ expect `findsNothing`) แสดงว่า assertion ผูกกับโค้ดจริง ไม่ใช่ false-positive จากนั้น `git stash pop` คืนโค้ดที่แก้แล้ว รันซ้ำทั้งไฟล์ `home_feed_screen_test.dart` (61 เทส) และ `root_shell_test.dart` (7 เทส, เพราะแตะ Home tab) → ผ่านหมด

Build: ไม่ได้รัน `flutter build` จริง — เป็น UI-only fix ไม่แตะ backend/schema

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator ใน sandbox นี้) — ตรวจแค่ widget test ยืนยันตำแหน่ง/จำนวนแท็บและ label
- หมายเหตุ environment: sandbox นี้ไม่มี Flutter SDK ติดตั้งมาก่อน (ต่างจากที่ Phase 0/1 อาจสมมติไว้) ต้อง `git clone https://github.com/flutter/flutter.git -b stable --depth 1` เข้า `/home/user/flutter` เองก่อนจะรัน `flutter analyze`/`flutter test` ได้ (Flutter 3.47.2, Dart 3.13.2) — ไม่ได้แก้ไข repository ใดๆ เพื่อเรื่องนี้ แค่บันทึกไว้เผื่อ session ถัดไปต้องทำซ้ำ

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงที่หน้า Home ว่าเหลือ 3 แท็บ (สำหรับคุณ/ติดตาม/จาก Club ของคุณ) เรียงลำดับถูกต้อง ไม่มี "ล่าสุด" หลงเหลือ (2) ยืนยันว่าไม่มีจุดอื่นในแอป (เช่น analytics event name, deep-link) อ้างอิงโหมด "ล่าสุด" อยู่นอกเหนือจาก grep ที่ AI Design ตรวจไว้แล้ว

## QA Report (2026-09-02)

```
Feature: ตัดแท็บ "ล่าสุด" ออกจากหน้า Home feed เหลือ 3 แท็บ (สำหรับคุณ/ติดตาม/จาก Club ของคุณ)
Environment: อ่านโค้ดจริง (adversarial) + รัน `flutter analyze`/`flutter test` อิสระเองจาก app/ — ไม่มี simulator/emulator
Test Cases:
  1. grep `_HomeFeedMode.latest` ทั้ง `app/lib` อิสระเอง — ยืนยันไม่พบเหลืออยู่จุดใดเลย (ลบครบทั้ง enum/switch/toggle list)
  2. grep string `'ล่าสุด'`/`"latest"` ทั้ง `app/lib` (นอกเหนือจากไฟล์เทส) — ไม่พบจุดอื่นอ้างอิงเหลือ (ปิด Risk R1 จริง ไม่ใช่แค่คำกล่าวอ้าง)
  3. อ่าน home_feed_screen.dart ยืนยันลำดับแท็บที่เหลือ (forYou → following → fromYourClubs = สำหรับคุณ/ติดตาม/จาก Club ของคุณ) ตรงตาม Acceptance Criteria
  4. รัน `flutter analyze` อิสระ: สะอาด
  5. รัน `flutter test` อิสระเต็ม suite: 917/917 ผ่าน
Passed: ทั้ง 5 ข้อข้างต้น
Failed: ไม่มี
Severity: -
Reproduction Steps: -
Expected: -
Actual: -
Security Findings: ไม่พบ — UI-only removal ไม่แตะ backend/API
Recommendation: อนุมัติ — ต้องมีคนตรวจภาพจริงบนอุปกรณ์ก่อน sign-off production ขั้นสุดท้าย (residual, ไม่ block QA รอบนี้)
Final Status: PASS
```
