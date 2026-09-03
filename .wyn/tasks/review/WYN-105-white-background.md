# Feature Request — WYN-105

Status: full spec complete, ready for AI Design — scope larger than originally estimated (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 5 (ส่วนธีมสี)/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มระบบเลือกธีมสีของ WYNOS ได้ 3 แบบ
Goal: ให้ผู้ใช้เลือกธีมที่ชอบได้เอง: ขาวนวล / ขาวบริสุทธิ์ / ดำ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "แล้วอยากให้เลือกสีธีมได้ 3 สี คือ 1.ขาวนวล 2.ขาวบริสุทธิ์ 3.ดำ"
Requirements:
- ออกแบบ 3 theme palette: ขาวนวล (ปัจจุบัน/off-white), ขาวบริสุทธิ์ (pure white), ดำ (dark mode)
- เพิ่มหน้าตั้งค่าให้เลือกธีม บันทึกค่าที่เลือกไว้ (local + sync บัญชีถ้าต้องการข้ามอุปกรณ์)
- ตรวจทุกหน้าจอหลักให้รองรับทั้ง 3 ธีมโดยไม่มีจุดที่ hardcode สีจนอ่านไม่ออกในธีมใดธีมหนึ่ง (โดยเฉพาะธีมดำ)
Acceptance Criteria:
- [ ] เปลี่ยนธีมในตั้งค่าแล้วทั้งแอปเปลี่ยนสีทันที
- [ ] ทุกหน้าจอหลักอ่านง่ายครบทั้ง 3 ธีม ไม่มีข้อความ/ไอคอนที่กลืนกับพื้นหลัง
Dependencies: ควรทำหลัง WYN-078 (แก้ bug พื้นหลังไม่เต็มจอ) เพราะเป็นเรื่อง background/theme เดียวกัน
Priority: กลาง (งานกว้าง กระทบทุกหน้าจอ ต้องทำท้ายๆ เพื่อลดการชนกับงาน UI อื่นที่ยังไม่นิ่ง)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ทำธีมตอนที่ UI อื่นยังเปลี่ยนอยู่ (Phase 2) อาจต้องไล่แก้ซ้ำ | กลาง | ทำเป็นงานสุดท้ายของรอบนี้ หลัง Phase 1-2 นิ่งแล้ว |
Recommendation: อนุมัติ แนะนำทำเป็นลำดับท้ายๆ ของรอบนี้
Handoff: AI Design (กำหนด palette แต่ละธีมให้ครบทุก component) → AI Coding → AI QA (เช็ค contrast/อ่านง่ายทั้ง 3 ธีม)

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-105-theme-system.md` — **พบความเสี่ยงสถาปัตยกรรมที่ backlog เดิมประเมินไว้ต่ำเกินไป**: โค้ดทั้งแอปอ้างอิงสีผ่าน `WynColors.ink`/`.paper`/ฯลฯ เป็น static const literal โดยตรง ไม่ผ่าน `Theme.of(context)` — แม้ `WynTheme.dark`/`themeMode` จะมีโครงอยู่แล้วใน `main.dart` แต่ comment ในโค้ดยืนยันตรงๆ ว่า dark ColorScheme "unused in production today" เพราะสลับ themeMode แล้วหน้าจอส่วนใหญ่จะไม่เปลี่ยนสีเลย — การทำธีมจริงต้องไล่แก้เกือบทุกไฟล์ UI ในโปรเจกต์ (ไม่ใช่แค่ "ชนกับงาน UI อื่น" ตามที่ Risk เดิมระบุ) เพิ่มคอลัมน์ `profiles.theme_preference` (3 ค่า) sync ข้ามอุปกรณ์ตามที่ระบุ

**ต้อง ping Founder**: แจ้งว่างานนี้ใหญ่กว่าที่ backlog เดิมประเมินไว้มาก (รีแฟกเตอร์สถาปัตยกรรมสีทั้งแอป ไม่ใช่แค่เพิ่มหน้าตั้งค่า) แนะนำทำเป็นลำดับท้ายสุดของทั้งรอบ Beta2 (ไม่ใช่แค่ท้าย Phase 3) และแบ่งเป็นหลาย PR ทยอยไล่ทีละ feature folder

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-105-theme-system.md`

Handoff: ส่งต่อ AI Design (`/design`) — ต้องตัดสินใจ Architecture Decision (วิธีทำให้สลับธีมได้จริง) ก่อนเริ่ม Coding

## Founder Scope Decision (2026-09-03)

Founder ตอบกลับหลังเห็นขนาดงานจริง (ดู `.wyn/company/DECISIONS.md` entry เดียวกันวันที่นี้): **ไม่ต้องทำระบบสลับธีม/หน้าตั้งค่าเลย** ต้องการแค่ "เปลี่ยนสีพื้นหลังแอปเป็นสีขาว เหมือนกับแอปอื่นๆ" เท่านั้น — คือธีม "ขาวบริสุทธิ์" ในสโคปเดิม แต่ตัดตัวเลือกสลับธีม/ธีมดำ/sync ข้ามอุปกรณ์ออกทั้งหมด

**สโคปจริงของ WYN-105 ในรอบ Beta2 นี้ (เล็กกว่ามาก):**
- เปลี่ยนค่า `WynColors.paper` จาก off-white/cream ปัจจุบัน (`0xFFFAF9F6`) เป็นสีขาวบริสุทธิ์ (`0xFFFFFFFF`) — ไม่ต้องแตะ token อื่นเลย เพราะทุกหน้าจอ (background/surface/card) อ้างอิง `paper` เป็น token กลางร่วมกันอยู่แล้ว
- ไม่ต้องมีหน้าตั้งค่าธีม ไม่ต้องมี dark mode ไม่ต้อง sync ข้ามอุปกรณ์ ไม่ต้องเพิ่มคอลัมน์ `profiles.theme_preference`
- Design check (ทำแล้วโดย orchestrating session ก่อนส่งต่อ Coding): เทียบ contrast `hairline` (`#E8E6E0`) และ `faint` (`#C7C4BC`) กับพื้นหลังใหม่ `0xFFFFFFFF` เทียบกับพื้นหลังเดิม `0xFFFAF9F6` — contrast **เพิ่มขึ้น** เล็กน้อยทั้งคู่ (เส้นคั่น/ข้อความจางเห็นชัดขึ้น ไม่จางลง) ไม่มีความเสี่ยงด้าน accessibility

**สิ่งที่ยังไม่ทำในรอบนี้** (เก็บไว้เป็นงานอนาคตแยกต่างหาก อ้างอิง `.wyn/docs/product/wyn-105-theme-system.md`): ระบบเลือกธีม 3 แบบเต็มรูปแบบ, dark mode ที่ใช้งานได้จริง, การ refactor ให้ทุกไฟล์ UI อ่านสีผ่าน `Theme.of(context)` แทน static const

Handoff: ส่งต่อ AI Coding โดยตรง (ไม่ต้องผ่าน AI Design เพิ่มเติม — Design check เบื้องต้นทำเสร็จแล้วข้างบน งานเป็นแค่เปลี่ยนค่า 1 token)

## Coding Output (2026-09-03)

Worktree base ยืนยันแล้วว่าอยู่บน `claude/wynos-beta2-phase2-handoff-w4mi5m` @ `228918a` ก่อนเริ่มงาน
(worktree เดิม spawn มาจาก `origin/main` ผิดสาขา — reset ด้วย `git reset --hard
origin/claude/wynos-beta2-phase2-handoff-w4mi5m` ก่อน เพราะยังไม่มี commit ของตัวเองอยู่ ปลอดภัย)

การเปลี่ยนแปลง:
1. **`app/lib/core/design/wyn_colors.dart`**: `WynColors.paper` เปลี่ยนจาก `Color(0xFFFAF9F6)`
   (off-white/cream) เป็น `Color(0xFFFFFFFF)` (ขาวบริสุทธิ์) ตาม Founder Scope Decision ข้างบน —
   เพิ่ม doc comment อธิบายที่มา (WYN-105) ไว้เหนือ token นี้ด้วย ดัง doc comment เดิม ("Page
   background, card background, text-on-dark.") ไม่ได้บรรยายสีว่าเป็น "off-white"/"cream"
   ตรงๆ อยู่แล้ว จึงไม่ต้องแก้ถ้อยคำส่วนนั้น — token นี้เป็นค่ากลางเดียวที่ `ColorScheme` ทั้งแอป
   (background/surface/card, light theme) อ้างอิงอยู่แล้ว (`surface`,
   `surfaceContainerLowest/Low/Container/High/Highest`, ฯลฯ ใน `lightColorScheme` ในไฟล์เดียวกัน)
   จึงเปลี่ยนจุดเดียวก็ครอบคลุมทั้งแอปตามที่ Design check ระบุไว้
2. **`app/lib/main.dart`**: comment ที่บรรยาย `paper (#FAF9F6)` (เขียนไว้ตอน WYN-078) อัปเดตเป็น
   `paper (#FFFFFF, WYN-105)` ให้ตรงกับค่าใหม่ — โค้ดจริงตรงนั้นอ้างอิง `WynColors.paper` symbol
   อยู่แล้ว (ไม่ได้ hardcode) จึงไม่มีผลต่อ behavior เปลี่ยนแค่ comment ให้ไม่ทำให้คนอ่านสับสน

Grep หา `FAF9F6`/`faf9f6` (ไม่สนตัวพิมพ์) ทั้ง repo เพื่อหา hardcode ค่าเดิมนอกเหนือจาก token:
- `app/`: พบ 2 จุดข้างบนเท่านั้น (`wyn_colors.dart` ตัว token เอง + comment ใน `main.dart`) —
  แก้ครบทั้งคู่แล้ว ไม่มี hardcode อื่นในโค้ด Dart ของ `app/`
- `seller_app/`: grep ไม่พบเลย — `seller_app/lib/core/design/wyn_colors.dart` เป็นไฟล์คนละชุด
  token (Cyan/Orange palette เดิม, ไม่มี token ชื่อ `paper`) ไม่เกี่ยวกับงานนี้ ไม่ต้องแก้
- `design-reference/*.tsx`: พบหลายจุด (มาจาก mockup/reference source ของ design-reference เดิม
  ที่อ้างอิง SPEC.md เวอร์ชันก่อนหน้า) — **ไม่แก้** เพราะเป็นไฟล์ reference/มaterials ต้นทาง ไม่ใช่
  แอปจริง อยู่นอกสโคปตามที่ Founder Scope Decision ระบุ (เปลี่ยนแค่ token เดียวใน Flutter app)
  ถ้าจะอัปเดต reference mockup ให้ตรงกับ production ต้องเป็นงาน AI Design แยกต่างหาก — flag ไว้
  ตรงนี้ ไม่ได้แก้เอง
- `.wyn/company/DECISIONS.md`, `.wyn/tasks/approved/WYN-078-...md`,
  `.wyn/docs/design/wyn-097-099-...md`, `.wyn/docs/product/wyn-105-theme-system.md`,
  `.wyn/tasks/review/WYN-105-...md` (ไฟล์นี้เอง): เป็นบันทึกประวัติศาสตร์ (decision log/spec เดิม)
  ที่อธิบายค่าที่ถูกต้อง ณ ตอนที่เขียน — ไม่แก้ย้อนหลัง เพราะจะทำให้ประวัติผิดเพี้ยน
  (ค่าถัดจากนี้ในเอกสารเหล่านั้นอ้างอิงถึงบริบทตอนนั้นตรงตามจริง)

`app/test/`: grep `FAF9F6` ไม่พบ hardcode ในเทสเลยแม้แต่จุดเดียว — ไม่มีเทสใดต้องแก้

Files Changed:
- `app/lib/core/design/wyn_colors.dart`
- `app/lib/main.dart` (comment only, ไม่กระทบ behavior)

Tests: รันเต็ม `flutter analyze` และ `flutter test` จริงในเครื่อง (Flutter 3.x, `app/`)
- `flutter analyze`: **"No issues found!"**
- `flutter test`: **1011/1011 ผ่านหมด** ตรงกับ baseline ของสาขานี้ ไม่มี regression ใหม่เลย

Build: ไม่ได้รัน platform build เต็ม (`flutter build ...`) เพราะเป็นการเปลี่ยนค่าสีคงที่ 1 ตัวใน
Dart source ล้วนๆ ไม่กระทบ build config/dependency ใดๆ — ความเสี่ยงต่ำมาก และ `flutter
analyze`/`flutter test` ครอบคลุมพอแล้วสำหรับขอบเขตงานนี้

Known Issues: ไม่มี — งานนี้ไม่แตะ token อื่นเลยตามสโคปที่ตัดลงมาแล้ว (ไม่มีหน้าตั้งค่าธีม, ไม่มี
dark mode, ไม่ sync ข้ามอุปกรณ์) ตรงตาม Founder Scope Decision ทุกประการ

Handoff: ส่งต่อ AI QA & Security (ไฟล์นี้อยู่ใน `.wyn/tasks/review/` ต่อ — ไม่ย้ายเอง)
