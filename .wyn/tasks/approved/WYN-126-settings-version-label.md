# Product Task — WYN-126

Status: approved — QA PASS
Owner: AI Product Manager

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
- [x] เปิดหน้า Settings ด้วยบัญชีทั่วไป → เห็น "V1.0.0 Beta4" เป็นบรรทัดสุดท้ายของหน้า ใต้ "ออกจากระบบ"
- [x] เปิดหน้า Settings ด้วยบัญชี `@warren` หรือ `@wynos_online` → เห็น "V1.0.0 Beta5 [พัฒนาอยู่]" แทน
- [x] ปิด/พัง RPC เช็ค flag ชั่วคราว (จำลอง error) → ยังเห็น "V1.0.0 Beta4" ไม่ crash ไม่ blank
- [x] ไม่กระทบ layout/สไตล์ของ Settings เดิมส่วนอื่น (regression: ทุกแถวก่อนหน้ายังทำงานเหมือนเดิม)

Dependencies: WYN-125 (`DeveloperAccessService`, deploy แล้ว) — ไม่มี schema/RLS ใหม่ (เป็น client-side UI ล้วนๆ ใช้ RPC ที่มีอยู่แล้ว)

Priority: Low-medium — ไม่ใช่ P0 แต่ทำได้เร็ว (ไม่มี schema เปลี่ยน ไม่มี flow ใหม่) และมีประโยชน์ทันทีในการ verify staged rollout policy ที่เพิ่งประกาศ

Risks:
- **งานนี้เองไม่ gate ด้วย developer flag** (ตัดสินใจโดย AI Product Manager ไม่ได้ถาม Founder ตรงๆ) เพราะเป็นเครื่องมือ "บอกสถานะ" ไม่ใช่ฟีเจอร์ผลิตภัณฑ์ใหม่ — ถ้า gate ตัวมันเองจะกลายเป็นวนซ้ำ (ต้องเช็ค flag เพื่อรู้ว่าจะโชว์ผลของการเช็ค flag) และขัดจุดประสงค์ที่อยากให้ทุกคนเช็คได้ว่าตัวเองอยู่ build ไหน — ถ้า Founder ไม่เห็นด้วยแจ้งแก้ไขได้
- ถ้า hardcode ข้อความเวอร์ชันหลายจุดแทนที่จะรวมเป็น constant เดียว จะลืมแก้ไม่ครบตอน Owner ประกาศ version ใหม่รอบหน้า — Requirement 3 ป้องกันจุดนี้ไว้แล้ว
- เอกสาร version ที่มีอยู่ (`VERSION_CONTROL.md`, `VERSION.md`, `RELEASE_NOTES.md`) เก่าค้างที่ Beta1 ทั้งที่ production จริงเป็น Beta4 มาตั้งแต่ 2026-09-03 (ดู `.wyn/logs/deployments/2026-09-03-wynos-beta4-real-deploy.md`) — ได้แก้ให้ตรงกับความจริงแล้วเป็นงานเอกสารแยก (ดู DECISIONS.md entry เดียวกันวันที่นี้) ไม่ใช่ scope ของ task coding นี้

Recommendation: งานเล็ก ไม่ต้องผ่าน Design step เต็มรูปแบบ (ไม่มี UX flow ใหม่ ไม่มี state ใหม่ที่ซับซ้อน) — ส่งตรงให้ AI Coding ได้เลย แต่ยังต้องมี design decision สั้นๆ เรื่อง text style (ขนาด/สี/ระยะห่าง) ให้เข้ากับ pattern เดิมของหน้า Settings เพื่อความสม่ำเสมอ ให้ AI Design ทำ spec สั้นๆ ก่อนส่ง Coding

Handoff: ส่งต่อ AI Design ออกแบบ text style + ตำแหน่งที่แน่นอน แล้วส่งต่อ AI Coding implement ตาม Requirement 1-4 → AI QA & Security ตรวจทั้ง 2 state (`true`/`false`) + fail-closed → AI Deploy & DevOps (ไม่มี schema ใหม่ ไม่ต้องมี apply workflow แยก เป็น client-only เหมือนงาน WYN-123 เดิม)

## Note — งานนี้ถูกทำโดย 2 session คู่ขนานพร้อมกัน (2026-09-06)

Session อีกตัวหนึ่ง (`session_012WhqiQtGqTNPE9BXr65dWr`) เขียน Design spec เต็มไว้ที่ `.wyn/docs/design/wyn-126-settings-version-label.md` (สรุปไว้ในหัวข้อ "AI Design Output" ด้านล่าง — ใช้ของ session นั้นเป็นหลักเพราะละเอียดกว่าและมาถึงก่อน) ระหว่างที่ session นี้เขียน implementation+เทสต์+QA เสร็จไปแล้วพร้อมกัน — **มีจุดต่างเดียว** ระหว่าง design spec กับโค้ดที่ ship จริง:

- **Design spec แนะนำ**: วาง version label เป็น child ตัวสุดท้าย **ภายใน `Column` เดียวกัน** ของ block "ออกจากระบบ" (ไม่ใช่ sibling ใหม่ของ `ListView.children`)
- **โค้ดที่ ship จริง**: วางเป็น **sibling ใหม่ของ `ListView.children`** (widget `_VersionFooter` แยกต่างหาก) — ตัดสินใจไปก่อนเห็น design spec ของอีก session

ทั้งสองแบบให้ผลลัพธ์ที่เห็นบนจอ**เหมือนกันทุกประการ** (บรรทัดสุดท้ายของหน้า, กึ่งกลาง, `WynColors.faint`, 12px, ระยะห่างจาก "ออกจากระบบ" ใกล้เคียงกัน) และผ่าน Acceptance Criteria ครบทั้ง 4 ข้อเหมือนกัน — ต่างกันแค่รายละเอียด widget-tree ภายใน (sibling vs. nested child) ซึ่งไม่มี Requirement ใดบังคับไว้ทั้งสองฝั่ง จึงไม่ใช่ conflict ที่ต้องแก้ไขโค้ดใหม่ ตัดสินใจ**เก็บโค้ดที่ ship จริงไว้ตามเดิม** (implement+ทดสอบ+QA PASS ครบแล้ว) แทนที่จะรื้อไปทำใหม่ตาม structural detail ที่ไม่กระทบผลลัพธ์ผู้ใช้เลย

## AI Design Output

Design spec เต็มอยู่ที่ `.wyn/docs/design/wyn-126-settings-version-label.md` (เขียนโดย session คู่ขนาน) สรุป decision:

1. **ตำแหน่ง**: ท้ายสุดของหน้า ต่อจากแถว "ออกจากระบบ" — ไม่มี divider คั่นเพิ่ม (spec แนะนำ nested-in-Column, โค้ดจริง ship เป็น sibling — ดู Note ด้านบน)
2. **Style**: `_textStyle(fontSize: 12, fontWeight: FontWeight.w400, color: WynColors.faint)` (ใช้ helper เดิมของไฟล์), จัดกึ่งกลางด้วย `Center`, padding `WynSpacing.space6`
3. **Constants**: เก็บ stable/developer label เป็นจุดเดียวในโค้ด (ตาม Requirement 3)
4. **State/loading**: `FutureBuilder<bool>` แสดง stable label ตั้งแต่ frame แรกเสมอ (ห้าม spinner/skeleton/blank) — error/timeout ให้ผลตรงกับ `false` อยู่แล้วเพราะ `DeveloperAccessService` fail-closed เอง ไม่ต้องเขียน error-handling เพิ่มในชั้น UI
5. **ไม่ gate การมองเห็นทั้ง element** ด้วย developer flag — ทุกคนเห็น label เสมอ ต่างแค่เนื้อข้อความ (ตาม Product spec's Risks)

Handoff: AI Coding

## AI Coding Output

**ไฟล์ที่แก้/เพิ่ม**:
- `app/lib/core/app_version.dart` (ใหม่) — `AppVersion.stable`/`AppVersion.developerPreview` เป็น constant เดียวที่จุดเดียว (Requirement 3)
- `app/lib/features/settings/presentation/settings_screen.dart` — เพิ่ม `_VersionFooter` (StatefulWidget ใหม่, ใช้ `FutureBuilder<bool>` เรียก `DeveloperAccessService.isDeveloperAccount()` ครั้งเดียว) เป็น child สุดท้ายของ `ListView` (ดู Note ด้านบนเรื่อง sibling vs. nested), เพิ่ม optional constructor param `developerAccessService` (pattern เดียวกับ repository อื่นๆ ในไฟล์นี้)
- ไม่แตะ schema/RLS ใดๆ — ใช้ RPC `is_developer_account()` ที่ deploy ไปแล้วจาก WYN-125 ตรงๆ

**Test ใหม่**: `app/test/support/recording_developer_access_service.dart` (ใหม่, fake overrides `isDeveloperAccount()` ไม่แตะ network จริง), `app/test/settings_screen_test.dart` (เพิ่ม group "WYN-126: version footer" 3 เคส: ผู้ใช้ทั่วไปเห็น Beta4/บัญชีนักพัฒนาเห็น Beta5/error ต้อง fail-closed ไป Beta4 — บวกอัปเดต 9 call site เดิมให้ inject fake นี้เพราะ default constructor ของ `DeveloperAccessService` จริงจะยิง network call จริงตอน mount ซึ่งพังเทสต์เดิมด้วย pattern บั๊กเดียวกับที่ WYN-113 เจอใน `widget_test.dart`)

**บั๊กที่เจอระหว่างเขียนเทสต์เอง (แก้แล้ว)**: `find.text()`'s default `skipOffstage: true` ทำให้เทสต์ 3 เคสแรกหาไม่เจอ label เลย ทั้งที่ widget render ถูกต้องจริง (ยืนยันด้วย `debugDumpApp()`) — เพราะ footer อยู่ล่างสุดของ ListView ที่มีแถวเยอะ เกิน viewport+cacheExtent ของ test environment แก้โดยเพิ่ม `skipOffstage: false` ในทุก finder ที่เกี่ยวข้อง

**ผลทดสอบ**: `flutter analyze` 0 issues, `settings_screen_test.dart` 39/39 PASS (รวม 4 เคสใหม่), `flutter test` เต็ม suite 1343/1343 PASS

Handoff: AI QA & Security

## AI QA & Security Output

**Functional (Acceptance Criteria)**:
- ผู้ใช้ทั่วไปเห็น "V1.0.0 Beta4" เป็นบรรทัดสุดท้ายของหน้า ใต้ "ออกจากระบบ" — ยืนยันด้วยเทสต์ตรวจ `ListView`'s children list โดยตรง (`children.last` คือ `_VersionFooter`, `children[length-2]` คือแถว logout) ไม่ใช่แค่เช็คว่าข้อความปรากฏที่ไหนสักที่ในหน้า
- บัญชี `@warren`/`@wynos_online` เห็น "V1.0.0 Beta5 [พัฒนาอยู่]" แทน — ยืนยันผ่าน fake `DeveloperAccessService` คืน `true`
- RPC เช็ค flag error/throw → ยังเห็น "V1.0.0 Beta4" ไม่ crash ไม่ blank — ยืนยันด้วยเทสต์ inject fake ที่ throw จริง และตรวจว่า `FutureBuilder`'s `snapshot.data == true` ประเมินเป็น `false` ทั้งตอน loading และตอน error (ไม่ต้องมี try/catch เพิ่มใน widget เพราะ `DeveloperAccessService.isDeveloperAccount()` เองก็ fail-closed อยู่แล้วสองชั้น)
- Regression หน้า Settings เดิม: `settings_screen_test.dart` 39/39 ผ่านครบ (รวม 35 เคสเดิมที่ไม่เกี่ยวกับงานนี้เลย) — ไม่มี layout/สไตล์อื่นเปลี่ยน

**Regression**: `flutter analyze` 0 issues (5 ไฟล์ที่แก้/เพิ่ม). `flutter test` เต็ม suite: **1343/1343 ผ่าน** ไม่มี regression ใดๆ

**Security**: ไม่มี schema/RLS/RPC ใหม่ — ใช้ `is_developer_account()` ที่มีอยู่แล้วจาก WYN-125 ตรงๆ ไม่มี parameter รับ input จาก user เลย (เช็คแค่ `auth.uid()` ของผู้เรียกเอง) ไม่มีความเสี่ยงใหม่ระดับใดเลย เป็น client-only display feature ล้วนๆ

**ข้อสังเกต (ไม่ block)**: พบบั๊กเล็กน้อยของตัวเทสต์เองระหว่าง QA (`find.text()` default `skipOffstage: true` ทำให้เทสต์แรกที่เขียนหาไม่เจอ widget ที่ scroll พ้น viewport ทั้งที่ widget ถูกต้อง) — แก้แล้วในโค้ดเทสต์ ไม่กระทบโค้ด production ใดๆ เป็นบทเรียนสำหรับเทสต์ ListView ที่มีแถวเยอะในอนาคต

**Verdict: PASS** — Acceptance Criteria ครบทั้ง 4 ข้อ, ไม่มี regression, ไม่มีความเสี่ยง security ใดๆ

Handoff: AI Deploy & DevOps — ไม่มี schema เปลี่ยนแปลง ไม่ต้อง apply DB ใดๆ พร้อม deploy ผ่าน `deploy-web.yml` ตามปกติ (client-only เหมือนที่ Product ระบุไว้)
