# Product Task — WYN-126

Status: active (Design เสร็จแล้ว — handoff ให้ AI Coding)
Owner: AI Product Manager (spec) → AI Design (spec เสร็จ) → AI Coding (ถัดไป)

Feature: แสดงหมายเลขเวอร์ชัน WYNOS ที่ล่างสุดของหน้าการตั้งค่า (Settings) — ต่างกันตามสถานะบัญชี

Goal: ให้ทุกคนเช็คได้จากในแอปเองว่าเครื่องตัวเองกำลังรัน WYNOS เวอร์ชันไหน และให้ทีมภายในเห็นชัดเจนว่าตัวเองอยู่ในโหมด "ทดสอบ build ใหม่" (ตาม policy staged rollout ที่เพิ่งประกาศเป็น default เมื่อ 2026-09-06 — ดู `.wyn/company/WORKFLOW.md` หัวข้อ "Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่")

Target User: ผู้ใช้ทุกคนเห็น label นี้ (ไม่ gate ตัวมันเองด้วย developer flag — ดู Risks) แต่ข้อความต่างกันตามว่าเป็นบัญชีนักพัฒนาหรือไม่

Problem: ตอนนี้ไม่มีทางเช็ค version ของแอปจากในตัวแอปเองเลย — Founder อยากเห็นเลขเวอร์ชันในหน้า Settings และอยากให้ต่างกันระหว่างบัญชีนักพัฒนา (เห็น build ที่กำลังพัฒนาอยู่) กับผู้ใช้ทั่วไป (เห็น build เสถียรปัจจุบัน) เพื่อให้เห็นภาพตรงกับนโยบาย staged rollout ที่เพิ่งตั้งเป็นค่าเริ่มต้น

Requirements:
1. เพิ่มข้อความเวอร์ชันที่ตำแหน่ง**ล่างสุด**ของหน้า Settings (`app/lib/features/settings/presentation/settings_screen.dart`) — ต่อจากแถว "ออกจากระบบ" ที่เป็นรายการสุดท้ายของ `ListView` ในปัจจุบัน (ดูโค้ดจริง บรรทัด ~250-266)
2. ข้อความขึ้นกับสถานะบัญชี โดยเช็คผ่าน `DeveloperAccessService.isDeveloperAccount()` (WYN-125, deploy แล้วบน production):
   - ผู้ใช้ทั่วไป (`false`, ค่าเริ่มต้นของทุกคนวันนี้): **"V1.0.0 Beta4"**
   - บัญชีนักพัฒนา (`true` — ตอนนี้คือ `@warren`, `@wynos_online`): **"V1.0.0 Beta5 [พัฒนาอยู่]"**
3. ตัวเลขเวอร์ชันทั้งสอง (Beta4/Beta5) ต้องอยู่เป็น constant เดียวที่จุดเดียวในโค้ด (ไม่ hardcode ซ้ำหลายที่) เพื่อให้รอบถัดไปที่ Owner ประกาศ version ใหม่ (ตาม `.wyn/company/VERSION_CONTROL.md`) แก้ที่เดียวจบ
4. Fail-closed: ถ้าเช็ค `isDeveloperAccount()` error/timeout ต้องแสดงเป็นข้อความของผู้ใช้ทั่วไป ("V1.0.0 Beta4") เสมอ ห้ามค้าง/ห้าม error/ห้าม blank

Acceptance Criteria:
- [ ] เปิดหน้า Settings ด้วยบัญชีทั่วไป → เห็น "V1.0.0 Beta4" เป็นบรรทัดสุดท้ายของหน้า ใต้ "ออกจากระบบ"
- [ ] เปิดหน้า Settings ด้วยบัญชี `@warren` หรือ `@wynos_online` → เห็น "V1.0.0 Beta5 [พัฒนาอยู่]" แทน
- [ ] ปิด/พัง RPC เช็ค flag ชั่วคราว (จำลอง error) → ยังเห็น "V1.0.0 Beta4" ไม่ crash ไม่ blank
- [ ] ไม่กระทบ layout/สไตล์ของ Settings เดิมส่วนอื่น (regression: ทุกแถวก่อนหน้ายังทำงานเหมือนเดิม)

Dependencies: WYN-125 (`DeveloperAccessService`, deploy แล้ว) — ไม่มี schema/RLS ใหม่ (เป็น client-side UI ล้วนๆ ใช้ RPC ที่มีอยู่แล้ว)

Priority: Low-medium — ไม่ใช่ P0 แต่ทำได้เร็ว (ไม่มี schema เปลี่ยน ไม่มี flow ใหม่) และมีประโยชน์ทันทีในการ verify staged rollout policy ที่เพิ่งประกาศ

Risks:
- **งานนี้เองไม่ gate ด้วย developer flag** (ตัดสินใจโดย AI Product Manager ไม่ได้ถาม Founder ตรงๆ) เพราะเป็นเครื่องมือ "บอกสถานะ" ไม่ใช่ฟีเจอร์ผลิตภัณฑ์ใหม่ — ถ้า gate ตัวมันเองจะกลายเป็นวนซ้ำ (ต้องเช็ค flag เพื่อรู้ว่าจะโชว์ผลของการเช็ค flag) และขัดจุดประสงค์ที่อยากให้ทุกคนเช็คได้ว่าตัวเองอยู่ build ไหน — ถ้า Founder ไม่เห็นด้วยแจ้งแก้ไขได้
- ถ้า hardcode ข้อความเวอร์ชันหลายจุดแทนที่จะรวมเป็น constant เดียว จะลืมแก้ไม่ครบตอน Owner ประกาศ version ใหม่รอบหน้า — Requirement 3 ป้องกันจุดนี้ไว้แล้ว
- เอกสาร version ที่มีอยู่ (`VERSION_CONTROL.md`, `VERSION.md`, `RELEASE_NOTES.md`) เก่าค้างที่ Beta1 ทั้งที่ production จริงเป็น Beta4 มาตั้งแต่ 2026-09-03 (ดู `.wyn/logs/deployments/2026-09-03-wynos-beta4-real-deploy.md`) — ได้แก้ให้ตรงกับความจริงแล้วเป็นงานเอกสารแยก (ดู DECISIONS.md entry เดียวกันวันที่นี้) ไม่ใช่ scope ของ task coding นี้

Recommendation: งานเล็ก ไม่ต้องผ่าน Design step เต็มรูปแบบ (ไม่มี UX flow ใหม่ ไม่มี state ใหม่ที่ซับซ้อน) — ส่งตรงให้ AI Coding ได้เลย แต่ยังต้องมี design decision สั้นๆ เรื่อง text style (ขนาด/สี/ระยะห่าง) ให้เข้ากับ pattern เดิมของหน้า Settings เพื่อความสม่ำเสมอ ให้ AI Design ทำ spec สั้นๆ ก่อนส่ง Coding

Handoff: ส่งต่อ AI Design ออกแบบ text style + ตำแหน่งที่แน่นอน แล้วส่งต่อ AI Coding implement ตาม Requirement 1-4 → AI QA & Security ตรวจทั้ง 2 state (`true`/`false`) + fail-closed → AI Deploy & DevOps (ไม่มี schema ใหม่ ไม่ต้องมี apply workflow แยก เป็น client-only เหมือนงาน WYN-123 เดิม)

---

## Design เสร็จแล้ว (2026-09-06) — handoff ให้ AI Coding

Design spec เต็มอยู่ที่ `.wyn/docs/design/wyn-126-settings-version-label.md` สรุป decision สำหรับ AI Coding:

1. **ตำแหน่ง**: เพิ่ม label เป็น child ตัวสุดท้าย **ภายใน `Column` เดียวกัน** ของ block "ออกจากระบบ" (บรรทัด ~252-264 เดิมของ `settings_screen.dart`) ต่อจาก `_SettingsRow` ของ "ออกจากระบบ" — ไม่ใช่ sibling ใหม่ของ `ListView.children`, ไม่มี divider คั่นเพิ่ม
2. **Style**: `_textStyle(fontSize: 12, fontWeight: FontWeight.w400, color: WynColors.faint)` (ใช้ helper เดิมของไฟล์) จัดกึ่งกลางด้วย `Center`, padding บน/ล่าง `WynSpacing.space6` (ทั้งบนและล่างจากแถว "ออกจากระบบ" และขอบล่างของ ListView)
3. **Constants**: เก็บ `_kStableVersionLabel = 'V1.0.0 Beta4'` และ `_kDeveloperVersionLabel = 'V1.0.0 Beta5 [พัฒนาอยู่]'` เป็นจุดเดียวในโค้ด (ห้าม hardcode ซ้ำ ตาม Requirement 3)
4. **State/loading**: เรียก `DeveloperAccessService().isDeveloperAccount()` ผ่าน `FutureBuilder<bool>` ที่มี default/initial เป็น `false` เพื่อแสดง `_kStableVersionLabel` ตั้งแต่ frame แรกเสมอ (ห้าม spinner/skeleton/blank) แล้ว rebuild เป็น `_kDeveloperVersionLabel` เมื่อ resolve เป็น `true` — error/timeout ให้ผลลัพธ์ตรงกับ `false` อยู่แล้วเพราะ service fail-closed เอง ไม่ต้องเขียน error-handling เพิ่มในชั้น UI
5. งานนี้ตั้งใจ**ไม่ gate การมองเห็นทั้ง element** ด้วย developer flag (ทุกคนเห็น label เสมอ ต่างแค่เนื้อข้อความ) — เป็นการตัดสินใจของ Product spec (Risks section) ที่ Design ยอมรับตามแล้ว ไม่ใช่ประเด็นที่ต้องออกแบบใหม่

ขั้นตอนถัดไป: **AI Coding** implement ตาม Requirement 1-4 ของ spec นี้ + design spec เต็ม → **AI QA & Security** ตรวจ 4 ข้อใน Acceptance Criteria ด้านบน (ครอบคลุมทั้ง `true`/`false`/error state + regression ของแถวอื่นในหน้า Settings) → **AI Deploy & DevOps** deploy ปกติ (client-only, ไม่มี schema/RLS ใหม่ ไม่ต้องมี apply workflow แยก)

---

## AI Coding เสร็จแล้ว (2026-09-06) — handoff ให้ AI QA & Security

```
Implementation:
เพิ่ม _VersionLabel (StatelessWidget ใหม่) เป็น child ตัวสุดท้ายใน Column
เดิมของ block "ออกจากระบบ" ใน SettingsScreen.build() (ไม่ใช่ sibling ใหม่
ของ ListView.children) ตาม Design spec ทุกข้อ:
- ใช้ FutureBuilder<bool> ผูกกับ DeveloperAccessService().isDeveloperAccount()
  (WYN-125) พร้อม initialData: false ทำให้ "V1.0.0 Beta4" แสดงตั้งแต่ frame
  แรกเสมอ ไม่มี loading state ที่มองเห็นได้ — ไม่เขียน try/catch เพิ่มเองใน
  UI เพราะ service fail-closed อยู่แล้ว (error/timeout ให้ผลเหมือน false)
- Version string 2 ค่าเป็น static const จุดเดียว: _kStableVersionLabel
  ('V1.0.0 Beta4') และ _kDeveloperVersionLabel ('V1.0.0 Beta5 [พัฒนาอยู่]')
  ใน _VersionLabel เอง
- Style: _textStyle(fontSize: 12, fontWeight: FontWeight.w400,
  color: WynColors.faint) ห่อด้วย Center, Padding บน/ล่าง WynSpacing.space6
  — ใช้ token/helper เดิมของไฟล์ทั้งหมด ไม่มี TextStyle/สี/spacing literal
  ใหม่ ไม่มี divider ใหม่ ไม่มี icon
- SettingsScreen รับ optional parameter ใหม่ `developerAccessService`
  (ทรง "optional/defaulted" เดียวกับ repository อื่นๆ ของหน้านี้ เช่น
  profileRepository/dataRightsRepository) เพื่อให้ test inject fake ได้
  โดยไม่แตะ network จริง — ไม่ใช่ requirement ของ Product/Design spec
  โดยตรง แต่จำเป็นสำหรับ testability ตาม pattern เดิมของ codebase
  (Recording*Repository)
- ไม่แก้ layout/style ของ _SettingsRow, _GroupLabel, หรือแถวอื่นก่อนหน้า
  เลย (additive only ตาม Design Rules ข้อสุดท้าย)

Files Changed:
- app/lib/features/settings/presentation/settings_screen.dart
  (+import DeveloperAccessService, +SettingsScreen.developerAccessService
  param, +_VersionLabel widget, +1 บรรทัดเรียกใช้ใน block "ออกจากระบบ")
- app/test/settings_screen_test.dart (+import + group ใหม่ "version label
  (WYN-126)" 5 tests)
- app/test/support/recording_developer_access_service.dart (ใหม่ — fake
  ตาม pattern RecordingDataRightsRepository/RecordingAuthRepository:
  extend DeveloperAccessService จริง override isDeveloperAccount() เอง
  ไม่แตะ static cache ของ base class)

Reason:
ตรงตาม Product spec Requirement 1-4 และ Design spec ทุกข้อ (ตำแหน่ง/
style/constant เดียว/fail-closed) แบบ smallest-safe-change — ไม่แตะ
DeveloperAccessService เดิม (WYN-125, deploy แล้ว) เลย ใช้ตรงๆ ตามที่มี
อยู่ เพิ่ม optional constructor param ให้ SettingsScreen เพื่อ dependency
injection ในการ test เท่านั้น (ไม่กระทบ production caller ใดๆ เพราะเป็น
optional + ค่า default เทียบเท่าของเดิมทุกประการ)

Tests:
เพิ่ม 5 tests ใน app/test/settings_screen_test.dart กลุ่ม "version label
(WYN-126)":
1. บัญชีทั่วไป (isDeveloperAccount == false) เห็น "V1.0.0 Beta4"
2. บัญชีนักพัฒนา (mock true) เห็น "V1.0.0 Beta5 [พัฒนาอยู่]"
3. แสดง "V1.0.0 Beta4" ตั้งแต่ frame แรกก่อน future resolve (ใช้ Completer
   ค้าง future ไว้ไม่ให้ resolve ระหว่างเช็ค) — ไม่มี CircularProgressIndicator
4. isDeveloperAccount() throw (จำลอง RPC error) → ยังเห็น "V1.0.0 Beta4"
   ไม่ crash (tester.takeException() เป็น null)
5. label อยู่ใน Column เดียวกับ "ออกจากระบบ" (last child ของ ListView
   เดิม ไม่ใช่ sibling ใหม่) และ "ออกจากระบบ" ยังกดเปิด confirm dialog ได้
   ปกติ (no regression)

รันจริงเอง (ไม่ใช่แค่รายงาน):
- `flutter analyze` (app/): No issues found!
- `flutter test test/settings_screen_test.dart`: 41/41 PASS
- `flutter test` (ทั้ง suite): 1345/1345 PASS, exit code 0 — regression
  0 รายการทั้งหน้า Settings และทั้งแอป

Build:
ไม่มี schema/RLS ใหม่ (client-side UI ล้วนๆ ใช้ RPC เดิมจาก WYN-125)
ไม่มี native/config change ใดๆ — ไม่ต้อง build/apply workflow แยก
Flutter SDK ที่ใช้ทดสอบ: 3.47.1 (ตรงกับ CI's flutter-version pin ใน
.github/workflows/ci.yml)

Known Issues:
- ไม่มี — ทุก Acceptance Criteria ของ Product spec (4 ข้อ) ครอบคลุมด้วย
  test ใหม่แล้ว
- เอกสาร VERSION_CONTROL.md/VERSION.md/RELEASE_NOTES.md ที่เคยค้างเลข
  Beta1 มีการแก้แยกเป็นงานเอกสารแล้วตามที่ Product spec ระบุไว้ (ไม่ใช่
  scope ของ commit นี้ ตรวจสอบแยก)

Handoff:
ส่งต่อ **AI QA & Security** ตรวจครบ 4 ข้อใน Acceptance Criteria ของ
Product spec ด้านบน (บัญชีทั่วไป/บัญชีนักพัฒนา/error state/regression)
ก่อนขึ้น production — **ห้ามข้าม QA**. งานนี้เป็น client-only UI change
ไม่มี schema/RLS ใหม่ ไม่ต้องมี apply workflow แยก (เหมือน WYN-123) —
เมื่อ QA ผ่านแล้วส่งต่อ AI Deploy & DevOps deploy ตาม release cycle ปกติ
ของแอปได้เลย ไม่ต้อง rollback ใดๆ (ไม่มีการแก้ auth architecture หรือ
ฟีเจอร์เดิมใดๆ ในงานนี้)
```
