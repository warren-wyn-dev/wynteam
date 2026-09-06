# Design — WYN-126 (Settings Version Label)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-126-settings-version-label.md`
> Design system: **ไม่มีทิศทาง visual ใหม่** — ใช้ token/pattern ที่มีอยู่แล้วในหน้า Settings เอง (`_GroupLabel`, `_SettingsRow`'s `_textStyle()` helper, `WynColors`, `WynSpacing`) งานนี้ไม่ผ่าน `.wyn/docs/design/ds-*` เพราะเป็น text-only addition ในหน้าเดิม ไม่ใช่ screen/pattern ใหม่
> Precedent ที่เกี่ยวข้อง: `.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md` ("ห้ามเพิ่ม indicator ว่าเป็นบัญชีนักพัฒนา") — ข้อห้ามนั้น scope เฉพาะงาน WYN-125 เอง (ไม่ใช่แบนถาวร) Product spec ของ WYN-126 (Risks section) ตัดสินใจแล้วว่างานนี้ตั้งใจไม่ gate ตัวเองด้วย developer flag เพราะเป็นเครื่องมือ "บอกสถานะ build" ไม่ใช่ฟีเจอร์ใหม่ — Design ยอมรับการตัดสินใจนี้ตามที่ PM ระบุไว้แล้ว ไม่ใช่การคิดใหม่

## สรุปการตัดสินใจหลัก

1. **ตำแหน่ง**: ข้อความ version วางเป็นบรรทัดสุดท้ายของ `ListView` จริง ต่อจาก block "ออกจากระบบ" (บรรทัด 250-265 ปัจจุบัน) — อยู่ **ใน** `Padding` เดียวกันกับ block นั้น ไม่ใช่ sibling ใหม่แยก เพื่อให้ระยะห่างด้านบนของทั้ง block (divider + "ออกจากระบบ" + version) นับจากรายการก่อนหน้าเท่าเดิม (`WynSpacing.space8`) และไม่ต้องเพิ่ม `SizedBox`/padding ใหม่ระดับ ListView
2. **ไม่มี divider คั่นระหว่าง "ออกจากระบบ" กับ version label** — มี divider เส้นเดียวที่มีอยู่แล้วด้านบนสุดของ block (คั่นจาก "ข้อกำหนดและความเป็นส่วนตัว") พอแล้ว การเพิ่ม divider ที่สองจะทำให้ block นี้ดูหนักเกินความจำเป็นสำหรับ metadata บรรทัดเดียว — ใช้ spacing (ข้อ 3) แยกความหมายแทน
3. **จัดกึ่งกลาง (centered), ระยะห่างจาก "ออกจากระบบ": `WynSpacing.space6` (24px)** ด้านบน — มากกว่าระยะห่างปกติระหว่างแถวใน list (14px vertical padding ของ `_SettingsRow`) อย่างชัดเจน เพื่อให้ตาแยกออกทันทีว่านี่ไม่ใช่แถว action/แถวที่กดได้ แต่เป็น metadata ปิดท้ายหน้า — mirror หลักการ "extra breathing room" เดียวกับที่ใช้แยก "ออกจากระบบ" ออกจากกลุ่มด้านบนอยู่แล้ว (ดู comment บรรทัด 246-249 ของไฟล์เดิม) ด้านล่างให้เว้น `WynSpacing.space6` เช่นกันก่อนจบ ListView (กัน label ไปติดขอบจอ/safe area บนอุปกรณ์ที่มี gesture bar)
4. **สี/ขนาด**: ใช้ `WynColors.faint` (ไม่ใช่ `mutedNeutral`) — เหตุผล: `mutedNeutral` (`#B7B4AC`) เป็น token ที่ระบบตั้งชื่อไว้เฉพาะสำหรับ "small uppercase eyebrow label" อย่าง `_GroupLabel` (ตัวหนา, ตัวพิมพ์ใหญ่ทั้งหมด, letter-spacing กว้าง, ทำหน้าที่เป็นหัวข้อ section) ส่วน `faint` (`#C7C4BC`) คือ token ที่ doc comment ของมันเองระบุไว้ตรงๆ ว่าใช้กับ "**footer text**" (ดู `wyn_colors.dart` บรรทัด 52-53) — ตรงกับบทบาทของ version label เป๊ะ (บรรทัดสุดท้ายของหน้า, จางกว่าทุกอย่างในหน้ารวมถึงจางกว่าแถว disabled อย่าง "ธีมเข้ม"/"ช่วยเหลือ" ที่ใช้ `faint` เหมือนกันสำหรับ icon+label ที่ยังพอมองเห็นได้ว่าเป็น element แต่ไม่ใช่ action) — font size `12` (เล็กกว่า `_GroupLabel`'s `13` และเล็กกว่า `_SettingsRow`'s `15` อย่างชัดเจน เพราะเป็นระดับความสำคัญต่ำสุดในหน้า), `FontWeight.w400` (ปกติ ไม่ bold แบบ `_GroupLabel` เพราะไม่ใช่หัวข้อ section), ไม่มี `letterSpacing` พิเศษ (ข้อความเป็นตัวอักษร/ตัวเลขผสม ไม่ใช่ uppercase label สั้นๆ แบบ `_GroupLabel`) — เรียกผ่าน `_textStyle()` helper เดิมของไฟล์ (บรรทัด 1159-1170) ไม่สร้าง `TextStyle` ใหม่แยก
5. **State ระหว่างรอผลเช็ค / error**: **ห้ามมี loading state ที่มองเห็นได้เลย** — แสดงข้อความ "V1.0.0 Beta4" (ค่า default ของผู้ใช้ทั่วไป) ทันทีตั้งแต่ frame แรกที่ widget build (ไม่ใช่ blank/spinner/skeleton) แล้วถ้า `isDeveloperAccount()` resolve เป็น `true` ภายหลัง ค่อย rebuild เปลี่ยนข้อความเป็น "V1.0.0 Beta5 [พัฒนาอยู่]" — เหตุผลที่เลือกวิธีนี้แทน placeholder ว่างๆ:
   - Requirement 4 ของ Product spec (fail-closed) บังคับอยู่แล้วว่า error ต้องจบที่ข้อความผู้ใช้ทั่วไป ดังนั้น "ค่าเริ่มต้นก่อนรู้ผล" กับ "ค่าเมื่อ error" เป็นข้อความเดียวกันพอดี ไม่ต้องออกแบบ 2 สถานะแยกกัน (ลด edge case ให้ AI Coding)
   - ข้อความ "V1.0.0 Beta4" ไม่มีวันผิดที่จะโชว์ชั่วขณะ แม้บัญชีนั้นจะกลายเป็นนักพัฒนาในอีกเสี้ยววินาทีถัดมา — ต่างจาก placeholder ว่าง/skeleton ที่จะทำให้ผู้ใช้เห็นบรรทัดว่างกระพริบก่อน (ซึ่งดูเหมือนบั๊กมากกว่า)
   - ในทางปฏิบัติ `DeveloperAccessService` มี static cache ต่อ session อยู่แล้ว (ดู `developer_access_service.dart` บรรทัด 47, 56-57) ดังนั้นถ้าเคยเรียกมาก่อนแล้วในเซสชันเดียวกัน ค่าจะพร้อมทันที ไม่มีการกระพริบเปลี่ยนข้อความเลยในเคสส่วนใหญ่ — เคส "เปลี่ยนข้อความหลัง frame แรก" จะเกิดเฉพาะครั้งแรกที่เปิดหน้า Settings ในเซสชันนั้นเท่านั้น
   - การเปลี่ยนความยาวข้อความ (Beta4 → Beta5 [พัฒนาอยู่]) ทำให้ความกว้างของบรรทัดนั้นเปลี่ยน แต่ **ไม่กระทบตำแหน่ง/ความสูงของ element อื่นในหน้า** เพราะ label นี้เป็นบรรทัดสุดท้ายของ ListView ที่ centered ในความกว้างเต็มจออยู่แล้ว (ไม่ใช่ inline กับข้อความอื่น) — ถือว่าไม่ใช่ "layout shift ที่สังเกตเห็นได้" ตามที่ Requirement/โจทย์กังวล เพราะไม่มีอะไรอื่นขยับ
6. **ไม่มี icon นำหน้า** — ต่างจากทุกแถวใน `_SettingsRow` (icon+label+chevron) เพราะ label นี้ไม่ใช่แถว list ที่กดได้ ไม่มี `onTap`, ไม่มี hairline border-bottom — เป็น plain `Text` ล้วนๆ ห่อด้วย `Center`

---

## Screen: Settings — Version Label (ส่วนต่อขยายท้ายหน้าเดิม)

**Purpose**: ให้ผู้ใช้ทุกคนเช็คได้จากในแอปเองว่าเครื่องตัวเองกำลังรัน WYNOS build ไหน และให้บัญชีนักพัฒนาเห็นชัดเจนว่ากำลังอยู่ใน build ที่ทดสอบอยู่ (ตาม staged rollout policy 2026-09-06) — ไม่มี user flow ใหม่ ไม่มี interaction ใหม่ เป็น metadata แสดงผลอย่างเดียว

**User Flow**: ผู้ใช้เปิดหน้า Settings แล้ว scroll ลงสุด → เห็นข้อความ version ใต้ "ออกจากระบบ" ทันที ไม่ต้องทำอะไรเพิ่ม ไม่มี interaction ใดๆ กับข้อความนี้

**Components**:

1. `_VersionLabel` (widget ใหม่ ชื่อแนะนำ ไม่บังคับเป๊ะ) — `StatelessWidget` หรือ `FutureBuilder<bool>` ที่ผูกกับ `DeveloperAccessService().isDeveloperAccount()`:
   ```
   Padding(
     padding: const EdgeInsets.only(top: WynSpacing.space6, bottom: WynSpacing.space6),
     child: Center(
       child: Text(
         versionText, // ดู Components ข้อ 2
         style: _textStyle(fontSize: 12, fontWeight: FontWeight.w400, color: WynColors.faint),
       ),
     ),
   )
   ```
   วางเป็น child ตัวสุดท้ายภายใน `Column` เดิมของ block "ออกจากระบบ" (บรรทัด 252-264 เดิม) ต่อจาก `_SettingsRow` ของ "ออกจากระบบ" — **ไม่ใช่** sibling ใหม่ของ `ListView.children`
2. Version string constants — ต้องมี **จุดเดียว** ในโค้ด (ตาม Product spec Requirement 3) เก็บเป็น 2 ค่าคงที่ เช่น
   ```
   static const _kStableVersionLabel = 'V1.0.0 Beta4';
   static const _kDeveloperVersionLabel = 'V1.0.0 Beta5 [พัฒนาอยู่]';
   ```
   ชื่อ/ตำแหน่งไฟล์เป็นข้อเสนอแนะให้ AI Coding ตัดสินใจเอง (เช่น อยู่บนสุดของ `settings_screen.dart` ใกล้ import หรือเป็น static field ของ `_VersionLabel` เอง) — ข้อบังคับคือห้าม literal ข้อความซ้ำสองจุด

**Interactions**: ไม่มี — ไม่ใช่ปุ่ม ไม่มี `onTap`, ไม่มี long-press, ไม่มี tooltip, ไม่ select ได้แบบพิเศษ (ปกติของ `Text` ทั่วไป)

**States**:
1. **เริ่มต้น/กำลังเช็ค flag (frame แรกก่อน `Future` resolve)**: แสดง `_kStableVersionLabel` ("V1.0.0 Beta4") ทันที — ไม่มี spinner/skeleton/blank ใดๆ
2. **`isDeveloperAccount() == false`** (ค่าเริ่มต้นของผู้ใช้ทั่วไปเกือบทั้งหมด): แสดง `_kStableVersionLabel` ("V1.0.0 Beta4") — เหมือนกับ state 1 เป๊ะ ดังนั้นในทางปฏิบัติผู้ใช้ทั่วไปจะไม่เห็นการเปลี่ยนแปลงข้อความเลยแม้แต่ครั้งเดียว
3. **`isDeveloperAccount() == true`** (`@warren`, `@wynos_online`): rebuild เปลี่ยนข้อความเป็น `_kDeveloperVersionLabel` ("V1.0.0 Beta5 [พัฒนาอยู่]") ทันทีที่ resolve — ไม่ต้องมี transition/animation พิเศษ (plain text swap ธรรมดา สอดคล้องกับความเรียบง่ายของหน้าที่ไม่มี animation อื่นในหน้านี้อยู่แล้ว)
4. **Error/timeout ระหว่างเช็ค flag**: ต้องปฏิบัติเหมือน state 2 เป๊ะ (`_kStableVersionLabel`) — ตรงกับ fail-closed ของ `DeveloperAccessService.isDeveloperAccount()` เองอยู่แล้ว (คืน `false` เสมอเมื่อ catch exception ใดๆ ตาม `developer_access_service.dart` บรรทัด 66-71) ดังนั้น AI Coding ไม่ต้องเขียน error-handling เพิ่มเติมเองในชั้น UI — แค่ใช้ผลลัพธ์ `bool` ที่ได้กลับมาตรงๆ (`false` → stable label) ก็ fail-closed โดยอัตโนมัติ

**Responsive Behavior**: ข้อความบรรทัดเดียว สั้น (ยาวสุด "V1.0.0 Beta5 [พัฒนาอยู่]" ~22 ตัวอักษร) ไม่มีทาง wrap 2 บรรทัดในความกว้างหน้าจอ mobile ใดๆ ที่ WYN รองรับ — ไม่ต้องจัดการ overflow พิเศษ, `Center` widget รองรับทุกความกว้างจออัตโนมัติ

**Accessibility**: `Text` ธรรมดาอ่านได้ปกติผ่าน screen reader (ไม่ต้อง custom `Semantics` เพราะไม่มี interaction ให้ประกาศ label พิเศษ) — สี `WynColors.faint` บนพื้น `WynColors.paper` (ขาว) ที่ font-size 12 มี contrast ต่ำตามเจตนา (metadata ระดับต่ำสุด เช่นเดียวกับที่ `faint` ถูกใช้กับ view count/disabled state อื่นในระบบอยู่แล้วซึ่งไม่เคยถูกตั้งเป็นข้อบังคับ WCAG AA เพราะเป็น non-essential text) — ไม่ใช่ข้อมูลที่จำเป็นต่อการใช้งานหลักของหน้า จึงยอมรับ contrast ระดับนี้ตาม precedent เดิมของ token นี้

**Design Rules**:
- ห้าม hardcode ข้อความ version มากกว่า 1 จุดในโค้ด (ตรงตาม Product spec Requirement 3)
- ห้ามมี loading indicator ที่มองเห็นได้ระหว่างเช็ค flag (ต่างจาก `_AccountManagementScreen._isExporting` ที่มี spinner ได้เพราะเป็น user-triggered action — อันนี้เป็น passive metadata โหลดอัตโนมัติ ต้องไม่รบกวนสายตา)
- ต้องใช้ `_textStyle()` helper และ `WynColors`/`WynSpacing` tokens ที่มีอยู่แล้วในไฟล์เท่านั้น ห้ามสร้าง `TextStyle`/สี/spacing literal ใหม่นอกระบบ
- Regression: ห้ามแก้ layout/style ของ `_SettingsRow`, `_GroupLabel`, หรือแถวอื่นใดก่อนหน้าเลย — เพิ่มเฉพาะ element ใหม่ต่อท้าย
- งานนี้ตั้งใจ**ไม่ gate** ด้วย `DeveloperAccessService` ในความหมายของ "ซ่อน/แสดงทั้ง element" (ต่างจาก policy staged-rollout ปกติที่ WORKFLOW.md กำหนด) — ทุกคนเห็น label เสมอ มีแค่**เนื้อข้อความ**ที่ต่างกัน ตามที่ Product spec ตัดสินใจไว้แล้ว (Risks section) ไม่ใช่การตีความใหม่ของ Design

## Handoff

ส่งต่อ **AI Coding** implement ตาม Requirement 1-4 ของ Product spec + spec นี้:

1. เพิ่ม `_VersionLabel` widget (หรือ inline เทียบเท่า) ต่อท้าย `_SettingsRow` ของ "ออกจากระบบ" ภายใน `Column` เดียวกัน (บรรทัด ~256-262 เดิม) ตาม Components ข้อ 1 ข้างบน — **ห้ามเพิ่ม element เป็น sibling ใหม่ของ `ListView.children`**
2. เพิ่ม version constants 2 ตัวที่จุดเดียว (Components ข้อ 2) แล้วเรียกใช้จาก `_VersionLabel`
3. เรียก `DeveloperAccessService().isDeveloperAccount()` ผ่าน `FutureBuilder<bool>` (หรือเทียบเท่า) — `initialData: false` (หรือเทียบเท่าที่ให้ผล default เป็น stable label ทันทีตั้งแต่ frame แรก ตาม States ข้อ 1) ไม่ต้องเขียน try/catch เพิ่มเองเพราะ service fail-closed อยู่แล้ว
4. Text style: `fontSize: 12, fontWeight: FontWeight.w400, color: WynColors.faint`, จัดกึ่งกลางด้วย `Center`, padding บน/ล่าง `WynSpacing.space6`
5. ส่งต่อ **AI QA & Security** ตรวจครบตาม Acceptance Criteria ของ Product spec ทั้ง 4 ข้อ โดยเฉพาะ: (ก) บัญชีทั่วไปเห็น "V1.0.0 Beta4", (ข) `@warren`/`@wynos_online` เห็น "V1.0.0 Beta5 [พัฒนาอยู่]", (ค) จำลอง RPC error → ยังเห็น "V1.0.0 Beta4" ไม่ crash ไม่ blank, (ง) ไม่มี layout/style regression กับแถวอื่นในหน้า Settings
6. **ไม่ต้องผ่าน AI Deploy แยก workflow ใดๆ** — เป็น client-only UI change ล้วนๆ (เหมือน WYN-123) deploy ปกติตาม release cycle ของแอป ไม่มี schema/RLS ใหม่
