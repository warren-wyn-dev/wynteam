# Feature Request — WYN-105

Status: QA PASS (2026-09-03) — scope reduced by Founder to single token change, verified and approved, moved to `.wyn/tasks/approved/`
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

## QA Report (2026-09-03)

Feature: เปลี่ยนพื้นหลังแอปจาก off-white (`#FAF9F6`) เป็นสีขาวบริสุทธิ์ (`#FFFFFF`) — `WynColors.paper` (Wynos V1.0.0 Beta2, WYN-105, สโคปที่ Founder ตัดลงมาแล้ว)

Environment: อ่านโค้ดจริง + `git show`/`git log` ตรวจ diff จริง + grep ทวนซ้ำทั้ง repo อิสระจาก Coding + คำนวณ WCAG contrast ratio จริงด้วย Python + ติดตั้ง/พบ Flutter SDK (`/home/user/flutter`, Flutter 3.47.2 stable) แล้วรัน `flutter analyze`/`flutter test` เต็มจริงในเครื่อง (ไม่เชื่อรายงานเดิมเฉยๆ)

**หมายเหตุ worktree**: worktree นี้ spawn มาผิดสาขาเช่นเดียวกับที่เตือนไว้ล่วงหน้า (อยู่บน `c00e0db`/`origin/main` ไม่ใช่ descendant ของ `aad25ea`) — แก้แล้วด้วย `git fetch origin claude/wynos-beta2-phase2-handoff-w4mi5m && git reset --hard origin/claude/wynos-beta2-phase2-handoff-w4mi5m` ก่อนเริ่มตรวจ (ปลอดภัย ไม่มี commit ของตัวเองใน worktree ก่อนหน้า) ยืนยัน `git log --oneline -3` ว่า HEAD = `aad25ea` ตรงกับที่คาดไว้แล้ว

Test Cases:
1. ตรวจค่าสีจริงในโค้ด: `grep -n "static const Color paper"` → `Color(0xFFFFFFFF)` ตรงตาม spec (pure white) ✓
2. Grep อิสระทั้ง `app/` หา `FAF9F6`/`faf9f6` (ไม่สนตัวพิมพ์): พบ **เพียง 1 จุด** คือ doc comment ใน `wyn_colors.dart` ที่จงใจอ้างอิงค่าเดิมเป็นประวัติ ("off-white/cream `#FAF9F6` to pure white `#FFFFFF`") ไม่ใช่ hardcode ที่หลงเหลือ — ไม่มี `0xFFFAF9F6` literal เหลืออยู่ที่ไหนใน `app/` เลย ตรงกับที่ Coding Output อ้าง ✓
3. Grep ทั้ง repo (นอก `app/`): พบใน `design-reference/*.tsx` หลายไฟล์ (mockup source นอกสโคป Flutter app ตามที่ Coding Output ระบุ ถูกต้อง) และในเอกสาร decision log/spec เดิม (`DECISIONS.md`, `WYN-078-...md`, `wyn-097-099-...md`, `wyn-105-theme-system.md`) ซึ่งเป็นบันทึกประวัติศาสตร์ที่ถูกต้องตามบริบทตอนเขียน ไม่ควรแก้ย้อนหลัง — ไม่มีจุดใดที่ควรแก้แต่ตกหล่นไป ✓
4. ตรวจ `seller_app/lib/core/design/wyn_colors.dart`: ไม่มี token ชื่อ `paper` เลยจริง (ยืนยันคำอ้างว่าเป็นไฟล์คนละชุด token ไม่เกี่ยวกับงานนี้) ✓
5. คำนวณ WCAG 2.1 relative-luminance contrast ratio จริง (ไม่เชื่อคำอ้างเฉยๆ) เทียบพื้นหลังเดิม (`#FAF9F6`, luminance 0.94729) กับพื้นหลังใหม่ (`#FFFFFF`, luminance 1.0):
   - `hairline` (`#E8E6E0`, เส้นคั่น) : 1.1854:1 (เดิม) → **1.2480:1 (ใหม่, เพิ่มขึ้น)**
   - `faint` (`#C7C4BC`, ข้อความจาง) : 1.6552:1 (เดิม) → **1.7427:1 (ใหม่, เพิ่มขึ้น)**
   - `ink` (`#12120F`, ข้อความหลัก) : 17.8225:1 (เดิม) → **18.7644:1 (ใหม่, เพิ่มขึ้น)** — ผ่าน WCAG AAA สบายๆ ทั้งสองกรณี
   - `graphite` (`#8A8880`, ข้อความรอง) : 3.3726:1 (เดิม) → **3.5509:1 (ใหม่, เพิ่มขึ้น)**
   - สรุป: contrast เพิ่มขึ้นจริงทุกคู่สีที่ตรวจ ยืนยันคำกล่าวอ้างของ Design/Coding reasoning ว่าถูกต้อง ไม่ใช่แค่คำกล่าวอ้างเฉยๆ — ไม่มีความเสี่ยงด้าน accessibility จากการเปลี่ยนนี้
   - Observation (ไม่ block, ไม่ใช่ regression จากงานนี้): `hairline`/`faint` มี contrast ต่ำกว่ามาตรฐาน WCAG AA ทั่วไปทั้งก่อนและหลังเปลี่ยน (เป็นดีไซน์ที่ตั้งใจให้เส้นคั่น/ข้อความ tertiary ดูจางอยู่แล้ว) — ไม่ใช่สิ่งที่ WYN-105 ทำให้แย่ลง จึงไม่ fail แต่บันทึกไว้เป็นข้อสังเกตสำหรับ AI Design ในอนาคตถ้าต้องการปรับปรุง contrast ของ token เหล่านี้
6. `git show aad25ea -- app/lib/core/design/wyn_colors.dart`: diff ยืนยันเป็น **1 บรรทัดเปลี่ยนค่า + doc comment เพิ่ม** เท่านั้น ไม่มี token อื่นถูกแตะเลย — อ่านทั้งไฟล์ (246 บรรทัด) ยืนยัน `ink`/`canvas`/`graphite`/`faint`/`hairline`/`sapphire`/`sapphireRing`/`mutedNeutral`/notification badges/ZOKY orange/dark-mode scaffolding/semantic colors/rainbow accent/scrim tokens/`socialLightScheme`/`socialDarkScheme` ทั้งหมดคงค่าเดิมไม่เปลี่ยน ✓
7. `git show aad25ea -- app/lib/main.dart`: diff ยืนยันเป็น comment-only เปลี่ยนจาก `paper (#FAF9F6)` เป็น `paper (#FFFFFF, WYN-105)` โค้ดจริงยังคงอ้างอิง `WynColors.paper` เป็น symbol เดิม ไม่กระทบ behavior ✓
8. Grep `WynColors.paper` usage ทั้งแอป: พบ 27 ไฟล์อ้างอิงผ่าน symbol เดียวกันหมด ไม่มีจุดใด hardcode ค่าสีตรงๆ แทนการอ้าง token — ยืนยันคำอ้างว่า "เปลี่ยนจุดเดียวครอบคลุมทั้งแอป" เป็นจริง ✓
9. `flutter analyze` (รันจริง, Flutter 3.47.2 stable): **"No issues found! (ran in 6.7s)"** ตรงกับที่ Coding Output อ้าง ✓
10. `flutter test` เต็ม suite (รันจริง): **"All tests passed!"** นับได้ **1011/1011** ตรงเป๊ะกับตัวเลขที่ Coding Output อ้าง ไม่มี test ใด fail/skip ผิดปกติ ✓

Passed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 (ทั้งหมด)

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: ไม่พบ — เปลี่ยนค่าคงที่สี 1 ตัวใน Dart source ล้วนๆ ไม่มี schema/RLS/auth/API/secret ใดเกี่ยวข้อง ไม่มีการเปิดเผยข้อมูลผู้ใช้หรือ credential ใดๆ ไม่มี attack surface ใหม่

**ข้อจำกัดที่ทราบและยอมรับได้ (ไม่ block PASS)**: sandbox นี้ไม่มี device/simulator จริงสำหรับตรวจ visual confirmation บนหน้าจอจริง (เช่น screenshot เทียบก่อน-หลัง) — ตรวจได้เฉพาะระดับโค้ด/ค่าคงที่/คำนวณ contrast/`flutter analyze`+`flutter test` เท่านั้น เป็นข้อจำกัดที่มีบันทึกเป็นแนวปฏิบัติมาก่อนแล้วในหลาย QA report ก่อนหน้า (เช่น WYN-056 "ไม่มี screenshot จริงของ Light mode") ไม่ใช่เหตุผลให้ FAIL เนื่องจากความเสี่ยงของการเปลี่ยนแปลงนี้ต่ำมาก (ค่าคงที่สีเดียว, ไม่กระทบ layout/logic)

Recommendation: อนุมัติ PASS — งานนี้เป็นการเปลี่ยนแปลงที่เล็ก ตรงสโคป และมีความเสี่ยงต่ำมาก diff surgical จริงตามที่อ้าง ไม่มี token/ไฟล์อื่นถูกแตะโดยไม่ตั้งใจ contrast เพิ่มขึ้นจริงตามการคำนวณอิสระ `flutter analyze`/`flutter test` เขียวจริง 1011/1011 — WYN-105 เป็น task สุดท้ายของ backlog Beta2 (29/29) พร้อมส่งต่อ AI Deploy & DevOps ได้ทันที เมื่อ Founder พร้อมสำหรับ visual sanity check บน device จริงครั้งเดียวหลัง deploy (ไม่ block deploy)

Final Status: PASS
